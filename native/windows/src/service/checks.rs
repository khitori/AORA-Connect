// SPDX-License-Identifier: GPL-3.0-or-later
use super::{
    connection_plan,
    core::{self, Core},
    process::Child,
    runtime,
};
use crate::network::{address_ip, physical_source, socket_address, Winsock};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{
    collections::{HashMap, HashSet},
    ffi::OsStr,
    io::{self, Read},
    net::{IpAddr, SocketAddr, TcpListener, TcpStream},
    os::windows::io::{AsRawHandle, OwnedHandle},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc::{self, SyncSender},
        Arc, Mutex,
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant},
};
use windows_sys::Win32::{Foundation::WAIT_OBJECT_0, System::Threading::WaitForSingleObject};

const MAX_NODES: usize = 1024;
const LEASE: Duration = if cfg!(feature = "service-scm-fixture") {
    Duration::from_secs(3)
} else {
    Duration::from_secs(30)
};
const LIFETIME: Duration = Duration::from_secs(600);
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Node {
    index: usize,
    core: Core,
    outbound: Value,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    protocol: u32,
    command: String,
    id: String,
    nodes: Option<Vec<Node>>,
}
#[derive(Clone, Serialize)]
struct Item {
    index: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    port: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}
struct State {
    id: String,
    digest: String,
    phase: &'static str,
    items: Vec<Item>,
    touched: Instant,
    created: Instant,
    cancel: Arc<AtomicBool>,
    error: Option<&'static str>,
}
impl Default for State {
    fn default() -> Self {
        Self {
            id: String::new(),
            digest: String::new(),
            phase: "closed",
            items: Vec::new(),
            touched: Instant::now(),
            created: Instant::now(),
            cancel: Arc::new(AtomicBool::new(false)),
            error: None,
        }
    }
}
type Shared = Arc<Mutex<State>>;
struct Work {
    nodes: Vec<Node>,
    cancel: Arc<AtomicBool>,
}
pub(super) struct Control {
    state: Shared,
    sender: SyncSender<Work>,
    shutdown: Arc<AtomicBool>,
    worker: Option<JoinHandle<()>>,
}
struct Prepared {
    index: usize,
    core: Core,
    outbound: Value,
    _reservation: TcpListener,
    port: u16,
}
struct Running {
    child: Child,
    reader: Option<JoinHandle<()>>,
    _config: runtime::Config,
}
impl Drop for Running {
    fn drop(&mut self) {
        let _ = self.child.abort();
        if let Some(reader) = self.reader.take() {
            let _ = reader.join();
        }
    }
}
fn invalid() -> io::Error {
    io::Error::other("Invalid server-check request")
}
fn validate(request: &Request) -> io::Result<()> {
    if request.protocol != 1
        || request.id.len() != 32
        || !request.id.bytes().all(|b| b.is_ascii_hexdigit())
    {
        return Err(invalid());
    }
    if request.command == "checks.open" {
        let nodes = request.nodes.as_ref().ok_or_else(invalid)?;
        let mut indices = HashSet::new();
        if nodes.is_empty()
            || nodes.len() > MAX_NODES
            || nodes
                .iter()
                .any(|n| n.index >= MAX_NODES || !indices.insert(n.index))
        {
            return Err(invalid());
        }
    } else if !matches!(request.command.as_str(), "checks.status" | "checks.close")
        || request.nodes.is_some()
    {
        return Err(invalid());
    }
    Ok(())
}
fn source(core: Core, outbound: &Value) -> io::Result<IpAddr> {
    let address = if core == Core::SingBox {
        &outbound["server"]
    } else {
        &outbound["settings"]["address"]
    };
    #[cfg(feature = "service-scm-fixture")]
    if matches!(outbound["type"].as_str(), Some("direct"))
        || matches!(outbound["protocol"].as_str(), Some("freedom"))
    {
        return Ok("127.0.0.1".parse().unwrap());
    }
    address
        .as_str()
        .ok_or_else(invalid)?
        .parse()
        .map_err(|_| invalid())
}
fn validate_outbound(core: Core, value: &Value) -> io::Result<()> {
    #[cfg(feature = "service-scm-fixture")]
    if value == &json!({"type":"direct","tag":"proxy"}) && core == Core::SingBox
        || value == &json!({"protocol":"freedom","tag":"proxy"}) && core == Core::Xray
    {
        return Ok(());
    }
    connection_plan::outbound(core, value)
}
fn configuration(core: Core, nodes: &[&Prepared]) -> Value {
    let inbounds:Vec<_>=nodes.iter().map(|n| if core==Core::SingBox {json!({"tag":format!("check-{}",n.index),"type":"mixed","listen":"127.0.0.1","listen_port":n.port})}else{json!({"tag":format!("check-{}",n.index),"protocol":"http","listen":"127.0.0.1","port":n.port})}).collect();
    let outbounds: Vec<_> = nodes.iter().map(|n| n.outbound.clone()).collect();
    if core == Core::SingBox {
        json!({"log":{"level":"info"},"dns":{"servers":[{"type":"local","tag":"local-dns"}],"final":"local-dns"},"inbounds":inbounds,"outbounds":outbounds,"route":{"final":nodes[0].outbound["tag"],"auto_detect_interface":true,"default_domain_resolver":"local-dns","rules":nodes.iter().map(|n|json!({"inbound":[format!("check-{}",n.index)],"action":"route","outbound":n.outbound["tag"]})).collect::<Vec<_>>()}})
    } else {
        json!({"log":{"loglevel":"warning"},"inbounds":inbounds,"outbounds":outbounds,"routing":{"domainStrategy":"IPIfNonMatch","rules":nodes.iter().map(|n|json!({"type":"field","inboundTag":[format!("check-{}",n.index)],"outboundTag":n.outbound["tag"]})).collect::<Vec<_>>()}})
    }
}
fn spawn(
    root: &Path,
    core: Core,
    config: &runtime::Config,
    checking: bool,
) -> io::Result<(Child, JoinHandle<()>, Arc<AtomicBool>)> {
    let executable = core.path(root);
    core::no_links(root, &executable)?;
    let host = root.join("app/aoravpn_core_host.exe");
    if !checking {
        core::no_links(root, &host)?;
        core::no_links(root, &root.join("app/aoravpn_core_console.exe"))?;
    }
    let args: Vec<&OsStr> = if checking {
        if core == Core::SingBox {
            vec![
                OsStr::new("check"),
                OsStr::new("-c"),
                config.file.as_os_str(),
                OsStr::new("--disable-color"),
            ]
        } else {
            vec![
                OsStr::new("run"),
                OsStr::new("-test"),
                OsStr::new("-c"),
                config.file.as_os_str(),
            ]
        }
    } else {
        let mut args = vec![executable.as_os_str(), config.file.as_os_str()];
        if core == Core::Xray {
            args.push(OsStr::new("xray"));
        }
        args
    };
    let (child, mut output) = Child::spawn(
        if checking { &executable } else { &host },
        &args,
        executable.parent().unwrap(),
    )?;
    let ready = Arc::new(AtomicBool::new(false));
    let flag = ready.clone();
    let reader = thread::spawn(move || {
        let mut buffer = [0u8; 4096];
        let mut line = Vec::new();
        while let Ok(count) = output.read(&mut buffer) {
            if count == 0 {
                break;
            }
            for &byte in &buffer[..count] {
                if byte == b'\n' {
                    let text = String::from_utf8_lossy(&line);
                    if text.contains("sing-box started")
                        || text.contains("Xray") && text.contains("started")
                    {
                        flag.store(true, Ordering::Release);
                    }
                    line.clear();
                } else if line.len() < 4096 {
                    line.push(byte);
                }
            }
        }
    });
    Ok((child, reader, ready))
}
fn failed(state: &Shared, index: usize, error: &str) {
    state.lock().unwrap().items.push(Item {
        index,
        port: None,
        error: Some(error.into()),
    });
}
fn validate_group(
    root: &Path,
    core: Core,
    nodes: &[&Prepared],
    cancelled: &impl Fn() -> bool,
    budget: &mut usize,
    deadline: Instant,
) -> io::Result<bool> {
    if cancelled() || Instant::now() >= deadline || *budget == 0 {
        return Err(io::Error::other(
            "Server-check preparation cancelled or timed out",
        ));
    }
    *budget -= 1;
    let bytes = serde_json::to_vec(&configuration(core, nodes))?;
    if bytes.len() > 4 * 1024 * 1024 {
        return Err(invalid());
    }
    let config = runtime::create(root, &bytes)?;
    let (mut child, reader, _) = spawn(root, core, &config, true)?;
    let limit = std::cmp::min(deadline, Instant::now() + Duration::from_secs(15));
    while !child.exited()? {
        if cancelled() || Instant::now() >= limit {
            child.abort()?;
            let _ = reader.join();
            return Err(io::Error::other(
                "Server-check validation cancelled or timed out",
            ));
        }
        thread::sleep(Duration::from_millis(20));
    }
    let code = child.process.wait()?;
    child.abort()?;
    let _ = reader.join();
    Ok(code == 0)
}
fn accepted<'a>(
    root: &Path,
    core: Core,
    nodes: &[&'a Prepared],
    state: &Shared,
    cancelled: &impl Fn() -> bool,
    budget: &mut usize,
    deadline: Instant,
) -> io::Result<Vec<&'a Prepared>> {
    if validate_group(root, core, nodes, cancelled, budget, deadline)? {
        return Ok(nodes.to_vec());
    }
    if nodes.len() == 1 {
        failed(state, nodes[0].index, "Core rejected this profile.");
        return Ok(Vec::new());
    }
    let middle = nodes.len() / 2;
    let mut good = accepted(
        root,
        core,
        &nodes[..middle],
        state,
        cancelled,
        budget,
        deadline,
    )?;
    good.extend(accepted(
        root,
        core,
        &nodes[middle..],
        state,
        cancelled,
        budget,
        deadline,
    )?);
    Ok(good)
}
fn open(
    root: &Path,
    work: &Work,
    state: &Shared,
    cancelled: &impl Fn() -> bool,
) -> io::Result<Vec<Running>> {
    let _winsock = Winsock::start()?;
    let mut prepared = Vec::new();
    let mut sources: HashMap<IpAddr, Option<IpAddr>> = HashMap::new();
    for node in &work.nodes {
        if cancelled() {
            return Err(io::Error::other("Cancelled"));
        }
        let prepare = (|| -> io::Result<Prepared> {
            validate_outbound(node.core, &node.outbound)?;
            let target = source(node.core, &node.outbound)?;
            let source = *sources.entry(target).or_insert_with(|| {
                if target.is_loopback() {
                    Some(target)
                } else {
                    physical_source(&socket_address(target))
                        .ok()
                        .flatten()
                        .map(|a| address_ip(&a))
                }
            });
            let source = source.ok_or_else(|| io::Error::other("No physical network route"))?;
            let reservation = TcpListener::bind((std::net::Ipv4Addr::LOCALHOST, 0))?;
            let port = reservation.local_addr()?.port();
            let mut outbound = node.outbound.clone();
            outbound["tag"] = format!("node-{}", node.index).into();
            if node.core == Core::Xray {
                outbound["sendThrough"] = source.to_string().into();
            } else {
                outbound[if source.is_ipv4() {
                    "inet4_bind_address"
                } else {
                    "inet6_bind_address"
                }] = source.to_string().into();
            }
            Ok(Prepared {
                index: node.index,
                core: node.core,
                outbound,
                _reservation: reservation,
                port,
            })
        })();
        match prepare {
            Ok(node) => prepared.push(node),
            Err(_) => failed(
                state,
                node.index,
                "Invalid profile or no physical network route.",
            ),
        }
    }
    let mut running = Vec::new();
    for core in [Core::SingBox, Core::Xray] {
        let nodes: Vec<_> = prepared.iter().filter(|n| n.core == core).collect();
        if nodes.is_empty() {
            continue;
        }
        let mut budget = 128;
        let good = match accepted(
            root,
            core,
            &nodes,
            state,
            cancelled,
            &mut budget,
            Instant::now() + Duration::from_secs(45),
        ) {
            Ok(good) => good,
            Err(_) => {
                if cancelled() {
                    return Err(io::Error::other("Cancelled"));
                }
                for node in nodes {
                    if !state
                        .lock()
                        .unwrap()
                        .items
                        .iter()
                        .any(|n| n.index == node.index)
                    {
                        failed(
                            state,
                            node.index,
                            "Core could not prepare the server checks.",
                        );
                    }
                }
                continue;
            }
        };
        if good.is_empty() {
            continue;
        }
        let config = runtime::create(root, &serde_json::to_vec(&configuration(core, &good))?)?;
        let members: Vec<_> = good.iter().map(|n| (n.index, n.port)).collect();
        drop(good);
        prepared.retain(|n| n.core != core);
        let launch = (|| -> io::Result<Running> {
            let (child, reader, ready) = spawn(root, core, &config, false)?;
            let active = Running {
                child,
                reader: Some(reader),
                _config: config,
            };
            let deadline = Instant::now() + Duration::from_secs(15);
            loop {
                if cancelled() || Instant::now() >= deadline || active.child.exited()? {
                    return Err(io::Error::other("Server-check core did not become ready"));
                }
                if ready.load(Ordering::Acquire) {
                    let mut available = true;
                    for (_, port) in &members {
                        if cancelled() || Instant::now() >= deadline {
                            return Err(io::Error::other("Server checks cancelled or timed out"));
                        }
                        if TcpStream::connect_timeout(
                            &SocketAddr::from(([127, 0, 0, 1], *port)),
                            Duration::from_millis(50),
                        )
                        .is_err()
                        {
                            available = false;
                            break;
                        }
                    }
                    if available {
                        break;
                    }
                }
                thread::sleep(Duration::from_millis(20));
            }
            Ok(active)
        })();
        let active = match launch {
            Ok(active) => active,
            Err(_) => {
                if cancelled() {
                    return Err(io::Error::other("Cancelled"));
                }
                for (index, _) in members {
                    failed(state, index, "Core could not start the server checks.");
                }
                continue;
            }
        };
        state
            .lock()
            .unwrap()
            .items
            .extend(members.into_iter().map(|(index, port)| Item {
                index,
                port: Some(port),
                error: None,
            }));
        running.push(active);
    }
    Ok(running)
}
impl Control {
    pub fn new(root: PathBuf, stop: OwnedHandle) -> Self {
        let state = Shared::default();
        let shared = state.clone();
        let shutdown = Arc::new(AtomicBool::new(false));
        let quitting = shutdown.clone();
        let (sender, receiver) = mpsc::sync_channel::<Work>(1);
        let worker = thread::spawn(move || {
            let stopping = || {
                quitting.load(Ordering::Acquire)
                    || unsafe { WaitForSingleObject(stop.as_raw_handle(), 0) } == WAIT_OBJECT_0
            };
            while !stopping() {
                let Ok(work) = receiver.recv_timeout(Duration::from_millis(50)) else {
                    continue;
                };
                let cancelled = || {
                    let state = shared.lock().unwrap();
                    stopping()
                        || work.cancel.load(Ordering::Acquire)
                        || state.touched.elapsed() > LEASE
                        || state.created.elapsed() > LIFETIME
                };
                let mut result = open(&root, &work, &shared, &cancelled);
                if result.is_ok() && !cancelled() {
                    shared.lock().unwrap().phase = "ready";
                    while !cancelled() {
                        if result
                            .as_ref()
                            .unwrap()
                            .iter()
                            .any(|r| r.child.exited().unwrap_or(true))
                        {
                            shared.lock().unwrap().error = Some("A server-check core stopped.");
                            break;
                        }
                        thread::sleep(Duration::from_millis(50));
                    }
                }
                {
                    let mut state = shared.lock().unwrap();
                    state.phase = "closing";
                    if result.is_err() && !work.cancel.load(Ordering::Acquire) {
                        state.error = Some("Server-check preparation failed or timed out.");
                    }
                }
                if let Ok(running) = &mut result {
                    running.clear();
                }
                let mut state = shared.lock().unwrap();
                state.phase = "closed";
                for item in &mut state.items {
                    item.port = None;
                }
            }
        });
        Self {
            state,
            sender,
            shutdown,
            worker: Some(worker),
        }
    }
    pub fn reply(&self, bytes: &[u8]) -> Vec<u8> {
        let result = (|| -> io::Result<Value> {
            let request: Request = serde_json::from_slice(bytes).map_err(|_| invalid())?;
            validate(&request)?;
            let mut state = self.state.lock().unwrap();
            if request.command == "checks.open" {
                let digest = format!("{:x}", Sha256::digest(bytes));
                if state.id == request.id {
                    if state.digest != digest {
                        return Err(invalid());
                    }
                } else {
                    if state.phase != "closed" {
                        return Err(io::Error::other("Server checks are already running."));
                    }
                    let cancel = Arc::new(AtomicBool::new(false));
                    self.sender
                        .try_send(Work {
                            nodes: request.nodes.unwrap(),
                            cancel: cancel.clone(),
                        })
                        .map_err(|_| io::Error::other("Server-check worker is busy."))?;
                    *state = State {
                        id: request.id.clone(),
                        digest,
                        phase: "preparing",
                        items: Vec::new(),
                        touched: Instant::now(),
                        created: Instant::now(),
                        cancel,
                        error: None,
                    };
                }
            } else if state.id != request.id {
                if request.command == "checks.close" {
                    return Ok(
                        json!({"protocol":1,"ok":true,"id":request.id,"phase":"closed","nodes":[]}),
                    );
                }
                return Err(io::Error::other("Stale server-check session."));
            }
            state.touched = Instant::now();
            if request.command == "checks.close" && state.phase != "closed" {
                state.cancel.store(true, Ordering::Release);
                state.phase = "closing";
            }
            Ok(
                json!({"protocol":1,"ok":true,"id":state.id,"phase":state.phase,"nodes":state.items,"error":state.error}),
            )
        })();
        serde_json::to_vec(
            &result.unwrap_or_else(|e| json!({"protocol":1,"ok":false,"error":e.to_string()})),
        )
        .unwrap()
    }
}
impl Drop for Control {
    fn drop(&mut self) {
        self.shutdown.store(true, Ordering::Release);
        self.state
            .lock()
            .unwrap()
            .cancel
            .store(true, Ordering::Release);
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn id() -> String {
        "a".repeat(32)
    }
    #[test]
    fn check_requests_have_fixed_commands_unique_indices_and_no_caller_paths() {
        for value in [
            json!({"protocol":1,"command":"checks.open","id":id(),"nodes":[]}),
            json!({"protocol":1,"command":"checks.open","id":id(),"config":"C:/secret","nodes":[]}),
            json!({"protocol":1,"command":"checks.open","id":"../folder","nodes":[]}),
            json!({"protocol":1,"command":"checks.open","id":id(),"nodes":[{"index":0,"core":"singBox","outbound":{}},{"index":0,"core":"xray","outbound":{}}]}),
            json!({"protocol":1,"command":"checks.open","id":id(),"nodes":[{"index":1024,"core":"singBox","outbound":{}}]}),
            json!({"protocol":1,"command":"checks.status","id":id(),"nodes":[]}),
            json!({"protocol":1,"command":"checks.start","id":id()}),
        ] {
            assert!(serde_json::from_value::<Request>(value)
                .ok()
                .is_none_or(|request| validate(&request).is_err()));
        }
        let mut value = json!({"type":"hysteria2","tag":"proxy","server":"127.0.0.1","server_port":443,"password":"dummy","tls":{"enabled":true,"server_name":"example.com","insecure":false}});
        assert!(validate_outbound(Core::SingBox, &value).is_ok());
        for key in [
            "source",
            "inet4_bind_address",
            "bind_interface",
            "sendThrough",
            "config",
            "path",
            "exec",
        ] {
            value[key] = json!("C:/private");
            assert!(validate_outbound(Core::SingBox, &value).is_err());
            value.as_object_mut().unwrap().remove(key);
        }
    }
    #[test]
    fn invalid_nodes_stay_local_to_the_batch_and_stale_close_cannot_change_its_identity() {
        let stop = unsafe {
            crate::owned(windows_sys::Win32::System::Threading::CreateEventW(
                std::ptr::null(),
                1,
                0,
                std::ptr::null(),
            ))
            .unwrap()
        };
        let controller = Control::new(PathBuf::new(), stop);
        let request = json!({"protocol":1,"command":"checks.open","id":id(),"nodes":[{"index":0,"core":"singBox","outbound":{"exec":"NEVER-ECHO-THIS"}}]});
        let open = serde_json::to_vec(&request).unwrap();
        let reply: Value = serde_json::from_slice(&controller.reply(&open)).unwrap();
        assert_eq!(reply["phase"], "preparing");
        let deadline = Instant::now() + Duration::from_secs(3);
        loop {
            let reply: Value = serde_json::from_slice(
                &controller.reply(
                    &serde_json::to_vec(&json!({"protocol":1,"command":"checks.status","id":id()}))
                        .unwrap(),
                ),
            )
            .unwrap();
            if reply["phase"] == "ready" {
                assert_eq!(reply["nodes"][0]["index"], 0);
                assert!(reply["nodes"][0]["error"].is_string());
                assert!(!reply.to_string().contains("NEVER-ECHO"));
                break;
            }
            assert!(Instant::now() < deadline);
            thread::sleep(Duration::from_millis(20));
        }
        let stale: Value = serde_json::from_slice(
            &controller.reply(
                &serde_json::to_vec(
                    &json!({"protocol":1,"command":"checks.close","id":"b".repeat(32)}),
                )
                .unwrap(),
            ),
        )
        .unwrap();
        assert_eq!(stale["phase"], "closed");
        assert_eq!(controller.state.lock().unwrap().phase, "ready");
        let reply: Value = serde_json::from_slice(&controller.reply(&open)).unwrap();
        assert_eq!(reply["phase"], "ready");
        let close =
            serde_json::to_vec(&json!({"protocol":1,"command":"checks.close","id":id()})).unwrap();
        controller.reply(&close);
        let deadline = Instant::now() + Duration::from_secs(3);
        while controller.state.lock().unwrap().phase != "closed" {
            assert!(Instant::now() < deadline);
            thread::sleep(Duration::from_millis(20));
        }
        let reply: Value = serde_json::from_slice(&controller.reply(&open)).unwrap();
        assert_eq!(reply["phase"], "closed");
    }
}
