// SPDX-License-Identifier: GPL-3.0-or-later
use super::{connection_plan::Plan, process::Child, runtime};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::VecDeque,
    ffi::OsStr,
    fs::{self, OpenOptions},
    io::{self, Read, Write},
    os::windows::{
        fs::{MetadataExt, OpenOptionsExt},
        io::{AsRawHandle, OwnedHandle},
    },
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, Ordering},
        mpsc::{self, SyncSender},
        Arc, Mutex,
    },
    thread::{self, JoinHandle},
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use windows_sys::Win32::{
    Foundation::WAIT_OBJECT_0, Storage::FileSystem::FILE_SHARE_READ,
    System::Threading::WaitForSingleObject,
};

const MAX_CONFIG: u64 = 4 * 1024 * 1024;
const VERIFICATION_LEASE: Duration = if cfg!(feature = "service-scm-fixture") {
    Duration::from_secs(10)
} else {
    Duration::from_secs(150)
};
#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq)]
pub enum Core {
    #[serde(rename = "singBox")]
    SingBox,
    #[serde(rename = "xray")]
    Xray,
}
impl Core {
    pub(super) fn path(self, root: &Path) -> PathBuf {
        let (folder, file) = match self {
            Self::SingBox => ("sing-box-1.14.2-windows-amd64", "sing-box.exe"),
            Self::Xray => ("xray-v26.9.30-windows-64", "xray.exe"),
        };
        root.join("cores").join("windows").join(folder).join(file)
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    protocol: u32,
    command: String,
    core: Option<Core>,
    config: Option<String>,
    plan: Option<Plan>,
    session: Option<String>,
    cursor: Option<u64>,
}

#[derive(Serialize)]
struct Snapshot {
    state: String,
    core: Option<Core>,
    mode: Option<String>,
    session: Option<String>,
    ready: bool,
    instance: String,
    revision: u64,
    issued: u64,
    completed: u64,
    error: Option<String>,
    #[serde(skip)]
    logs: VecDeque<(u64, String)>,
    #[serde(skip)]
    sequence: u64,
    #[serde(skip)]
    process: Option<OwnedHandle>,
}
impl Default for Snapshot {
    fn default() -> Self {
        Self {
            state: "stopped".into(),
            core: None,
            mode: None,
            session: None,
            ready: false,
            instance: format!(
                "{:x}-{:x}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ),
            revision: 0,
            issued: 0,
            completed: 0,
            error: None,
            logs: VecDeque::new(),
            sequence: 0,
            process: None,
        }
    }
}
type Shared = Arc<Mutex<Snapshot>>;
fn log(shared: &Shared, line: String) {
    let mut state = shared.lock().unwrap();
    state.sequence += 1;
    let sequence = state.sequence;
    state
        .logs
        .push_back((sequence, line.chars().take(1024).collect()));
    while state.logs.len() > 500 {
        state.logs.pop_front();
    }
}
pub(super) fn no_links(root: &Path, path: &Path) -> io::Result<()> {
    let relative = path.strip_prefix(root).map_err(io::Error::other)?;
    let mut current = root.to_path_buf();
    for part in std::iter::once(None).chain(relative.components().map(Some)) {
        if let Some(part) = part {
            if !matches!(part, std::path::Component::Normal(_)) {
                return Err(io::Error::other("Invalid installation path"));
            }
            current.push(part);
        }
        if fs::symlink_metadata(&current)?.file_attributes() & 0x400 != 0 {
            return Err(io::Error::other("Service paths must not contain links"));
        }
    }
    Ok(())
}

fn config_path(root: &Path, reference: &str) -> io::Result<PathBuf> {
    let parts: Vec<_> = reference.split('/').collect();
    if reference.len() > 128
        || parts.len() != 2
        || !parts[0].starts_with("profile-")
        || parts[0].len() <= 8
        || !parts[0]
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
        || parts[1] != "config.json"
    {
        return Err(io::Error::other(
            "Only a profile configuration reference is accepted",
        ));
    }
    Ok(root.join("runtime").join(parts[0]).join(parts[1]))
}

fn inspect_config(core: Core, value: &Value) -> io::Result<String> {
    let allowed: &[&str] = match core {
        Core::SingBox => &["log", "dns", "inbounds", "outbounds", "route"],
        Core::Xray => &["log", "dns", "inbounds", "outbounds", "routing"],
    };
    let object = value
        .as_object()
        .ok_or_else(|| io::Error::other("Configuration must be an object"))?;
    if object.keys().any(|key| !allowed.contains(&key.as_str())) {
        return Err(io::Error::other("Unsupported configuration section"));
    }
    #[derive(Clone, Copy)]
    enum Scope {
        Root,
        Dns,
        DnsServers,
        DnsServer,
        Transport,
        Other,
    }
    fn inspect(core: Core, value: &Value, depth: usize, scope: Scope) -> io::Result<()> {
        if depth > 32 {
            return Err(io::Error::other("Configuration nesting limit exceeded"));
        }
        match value {
            Value::Object(map) => {
                let network_path = matches!(scope, Scope::Transport)
                    || (matches!(scope, Scope::DnsServer)
                        && matches!(core, Core::SingBox)
                        && map.get("type").and_then(Value::as_str) == Some("https"));
                for (key, value) in map {
                    let key = key.to_ascii_lowercase();
                    if matches!(
                        key.as_str(),
                        "output"
                            | "access"
                            | "error"
                            | "rule_set"
                            | "certificatefile"
                            | "keyfile"
                            | "exec"
                            | "command"
                            | "plugin"
                    ) || (key == "path" && !network_path)
                        || (key.ends_with("_path") && key != "process_path")
                    {
                        return Err(io::Error::other(
                            format!("External files and executable configuration hooks are unsupported (field: {key})"),
                        ));
                    }
                    let transport = matches!(
                        key.as_str(),
                        "wssettings" | "httpupgradesettings" | "httpsettings"
                    ) || (key == "transport"
                        && matches!(value["type"].as_str(), Some("ws" | "http" | "httpupgrade")));
                    let next = if matches!(scope, Scope::Root) && key == "dns" {
                        Scope::Dns
                    } else if matches!(scope, Scope::Dns) && key == "servers" {
                        Scope::DnsServers
                    } else if transport {
                        Scope::Transport
                    } else {
                        Scope::Other
                    };
                    inspect(core, value, depth + 1, next)?;
                }
            }
            Value::Array(values) => {
                for value in values {
                    let next = if matches!(scope, Scope::DnsServers) {
                        Scope::DnsServer
                    } else {
                        Scope::Other
                    };
                    inspect(core, value, depth + 1, next)?;
                }
            }
            _ => {}
        }
        Ok(())
    }
    inspect(core, value, 0, Scope::Root)?;
    let inbounds = value["inbounds"]
        .as_array()
        .filter(|v| v.len() == 1)
        .ok_or_else(|| io::Error::other("Exactly one application inbound is required"))?;
    let inbound = &inbounds[0];
    let kind = inbound[if core == Core::SingBox {
        "type"
    } else {
        "protocol"
    }]
    .as_str()
    .unwrap_or("");
    if kind == "tun" {
        let name = if core == Core::SingBox {
            &inbound["interface_name"]
        } else {
            &inbound["settings"]["name"]
        };
        if name != "AORA VPN" {
            return Err(io::Error::other("Unexpected TUN interface"));
        }
        #[cfg(feature = "service-scm-fixture")]
        return Err(io::Error::other("TUN is disabled in SCM fixtures"));
        #[cfg(not(feature = "service-scm-fixture"))]
        return Ok("tun".into());
    }
    if kind
        != (if core == Core::SingBox {
            "mixed"
        } else {
            "http"
        })
        || inbound["listen"] != "127.0.0.1"
        || inbound[if core == Core::SingBox {
            "listen_port"
        } else {
            "port"
        }] != 17890
    {
        return Err(io::Error::other(
            "Only the application's loopback proxy is accepted",
        ));
    }
    Ok("proxy".into())
}

struct Config {
    directory: PathBuf,
    file: PathBuf,
    mode: String,
    private: Option<runtime::Config>,
}
impl Drop for Config {
    fn drop(&mut self) {
        if self.private.is_none() {
            let _ = fs::remove_file(&self.file);
            let _ = fs::remove_dir(&self.directory);
        }
    }
}
fn snapshot_config(root: &Path, core: Core, reference: &str) -> io::Result<Config> {
    let source = config_path(root, reference)?;
    no_links(root, &source)?;
    let mut file = OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ)
        .open(source)?;
    if file.metadata()?.len() > MAX_CONFIG {
        return Err(io::Error::other("Configuration size limit exceeded"));
    }
    let mut bytes = Vec::new();
    Read::by_ref(&mut file)
        .take(MAX_CONFIG + 1)
        .read_to_end(&mut bytes)?;
    if bytes.len() as u64 > MAX_CONFIG {
        return Err(io::Error::other("Configuration size limit exceeded"));
    }
    let mode = inspect_config(core, &serde_json::from_slice(&bytes)?)?;
    let name = format!(
        "service-{:x}-{:x}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    );
    let directory = root.join("runtime").join(name);
    no_links(root, &root.join("runtime"))?;
    fs::create_dir(&directory)?;
    let config = Config {
        file: directory.join("config.json"),
        directory,
        mode,
        private: None,
    };
    OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&config.file)?
        .write_all(&bytes)?;
    Ok(config)
}

enum Source {
    Reference(String),
    Plan(Plan),
}
impl Source {
    fn config(self, root: &Path, core: Core) -> io::Result<Config> {
        match self {
            Self::Reference(reference) => snapshot_config(root, core, &reference),
            Self::Plan(plan) => {
                let value = plan.build()?;
                let mode = inspect_config(core, &value)?;
                let private = runtime::create(root, &serde_json::to_vec(&value)?)?;
                Ok(Config {
                    directory: private.file.parent().unwrap().to_path_buf(),
                    file: private.file.clone(),
                    mode,
                    private: Some(private),
                })
            }
        }
    }
}
enum Action {
    Validate(Core, Source),
    Start(Core, Source),
    Stop,
    Recover,
}
struct Work {
    ticket: u64,
    action: Action,
}
pub struct Control {
    shared: Shared,
    sender: SyncSender<Work>,
    cancel: Arc<AtomicBool>,
    shutdown: Arc<AtomicBool>,
    worker: Option<JoinHandle<()>>,
}
struct Running {
    child: Child,
    reader: JoinHandle<()>,
    _config: Config,
    pending_since: Instant,
}
impl Running {
    fn stop(mut self) -> io::Result<()> {
        self.child.stop()?;
        self.reader
            .join()
            .map_err(|_| io::Error::other("Core log reader failed"))?;
        Ok(())
    }
}

fn spawn(
    root: &Path,
    core: Core,
    config: &Config,
    checking: bool,
    shared: Shared,
) -> io::Result<(Child, JoinHandle<()>)> {
    let executable = core.path(root);
    no_links(root, &executable)?;
    let host = root.join("app").join("aoravpn_core_host.exe");
    if !checking {
        no_links(root, &host)?;
        no_links(root, &root.join("app").join("aoravpn_core_console.exe"))?;
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
    } else if core == Core::SingBox {
        vec![executable.as_os_str(), config.file.as_os_str()]
    } else {
        vec![
            executable.as_os_str(),
            config.file.as_os_str(),
            OsStr::new("xray"),
        ]
    };
    let (child, mut output) = Child::spawn(
        if checking { &executable } else { &host },
        &args,
        executable.parent().unwrap(),
    )?;
    let reader = thread::spawn(move || {
        let mut buffer = [0; 4096];
        let mut line = Vec::new();
        while let Ok(count) = output.read(&mut buffer) {
            if count == 0 {
                break;
            }
            for &byte in &buffer[..count] {
                if byte == b'\n' {
                    let text = String::from_utf8_lossy(&line).trim().to_owned();
                    if !checking
                        && ((core == Core::SingBox && text.contains("sing-box started"))
                            || (core == Core::Xray
                                && text.contains("Xray")
                                && text.contains("started")))
                    {
                        shared.lock().unwrap().ready = true;
                    }
                    if !text.is_empty() {
                        log(&shared, text);
                    }
                    line.clear();
                } else if line.len() < 4096 {
                    line.push(byte);
                }
            }
        }
        if !line.is_empty() {
            log(&shared, String::from_utf8_lossy(&line).into_owned());
        }
    });
    Ok((child, reader))
}

impl Control {
    pub fn new(root: PathBuf, stop: OwnedHandle) -> Self {
        let shared = Shared::default();
        let cancel = Arc::new(AtomicBool::new(false));
        let shutdown = Arc::new(AtomicBool::new(false));
        let (sender, receiver) = mpsc::sync_channel::<Work>(2);
        let (state, cancelled, quitting) = (shared.clone(), cancel.clone(), shutdown.clone());
        let worker = thread::spawn(move || {
            let stopping = || {
                quitting.load(Ordering::Acquire)
                    || unsafe { WaitForSingleObject(stop.as_raw_handle(), 0) } == WAIT_OBJECT_0
            };
            let mut running: Option<Running> = None;
            while !stopping() {
                if let Some(active) = &running {
                    let expired = state.lock().unwrap().state == "starting"
                        && active.pending_since.elapsed() > VERIFICATION_LEASE;
                    if active.child.exited().unwrap_or(true) || expired {
                        if let Err(error) = running.take().unwrap().stop() {
                            log(&state, format!("Core cleanup failed: {error}"));
                        }
                        let mut snapshot = state.lock().unwrap();
                        snapshot.state = "stopped".into();
                        snapshot.ready = false;
                        snapshot.process = None;
                        snapshot.error = Some(
                            if expired {
                                "Connection verification acknowledgement timed out"
                            } else {
                                "Core exited unexpectedly"
                            }
                            .into(),
                        );
                    }
                }
                let Ok(work) = receiver.recv_timeout(Duration::from_millis(50)) else {
                    continue;
                };
                let result = (|| -> io::Result<()> {
                    let starting = matches!(&work.action, Action::Start(..));
                    match work.action {
                        Action::Recover => super::leak_recovery::clear_legacy_policy()?,
                        Action::Stop => {
                            if let Some(active) = running.take() {
                                active.stop()?;
                            }
                            let mut snapshot = state.lock().unwrap();
                            snapshot.state = "stopped".into();
                            snapshot.ready = false;
                            snapshot.process = None;
                        }
                        Action::Start(core, source) | Action::Validate(core, source) => {
                            let config = source.config(&root, core)?;
                            if starting {
                                super::leak_recovery::clear_legacy_policy()?;
                                state.lock().unwrap().mode = Some(config.mode.clone());
                            }
                            let (mut child, reader) =
                                spawn(&root, core, &config, true, state.clone())?;
                            let deadline = Instant::now() + Duration::from_secs(20);
                            while !child.exited()? {
                                if stopping()
                                    || cancelled.load(Ordering::Acquire)
                                    || Instant::now() >= deadline
                                {
                                    child.stop()?;
                                    reader.join().ok();
                                    return Err(io::Error::other(
                                        "Core validation cancelled or timed out",
                                    ));
                                }
                                thread::sleep(Duration::from_millis(25));
                            }
                            let code = child.process.wait()?;
                            child.stop()?;
                            reader.join().ok();
                            if code != 0 {
                                return Err(io::Error::other(
                                    "Configuration rejected by the core; see connection logs",
                                ));
                            }
                            if !starting {
                                return Ok(());
                            }
                            if stopping() || cancelled.load(Ordering::Acquire) {
                                return Err(io::Error::other("Start cancelled"));
                            }
                            let (child, reader) =
                                spawn(&root, core, &config, false, state.clone())?;
                            state.lock().unwrap().process = Some(child.process.handle.try_clone()?);
                            running = Some(Running {
                                child,
                                reader,
                                _config: config,
                                pending_since: Instant::now(),
                            });
                            let deadline = Instant::now() + Duration::from_secs(20);
                            while !state.lock().unwrap().ready {
                                if stopping()
                                    || cancelled.load(Ordering::Acquire)
                                    || Instant::now() >= deadline
                                    || running.as_ref().unwrap().child.exited()?
                                {
                                    running.take().unwrap().stop()?;
                                    return Err(io::Error::other(
                                        "Core exited, was cancelled, or did not become ready",
                                    ));
                                }
                                thread::sleep(Duration::from_millis(25));
                            }
                        }
                    }
                    Ok(())
                })();
                let mut snapshot = state.lock().unwrap();
                snapshot.completed = work.ticket;
                snapshot.error = result.as_ref().err().map(ToString::to_string);
                if result.is_err() {
                    if running.is_none() {
                        snapshot.state = "stopped".into();
                        snapshot.ready = false;
                        snapshot.process = None;
                    }
                }
            }
            if let Some(active) = running {
                let _ = active.stop();
            }
        });
        Self {
            shared,
            sender,
            cancel,
            shutdown,
            worker: Some(worker),
        }
    }

    pub fn reply(&self, bytes: &[u8]) -> Vec<u8> {
        let result = (|| -> io::Result<Value> {
            let request: Request = serde_json::from_slice(bytes)
                .map_err(|_| io::Error::other("Invalid service request fields"))?;
            if request.protocol != 1 {
                return Err(io::Error::other("unsupported_protocol"));
            }
            let typed = request.command.starts_with("connection.");
            let command = request
                .command
                .strip_prefix("connection.")
                .unwrap_or(&request.command);
            if (typed && bytes.len() > 256 * 1024)
                || (!typed && request.plan.is_some())
                || (!matches!(command, "start" | "validate") && request.plan.is_some())
            {
                return Err(io::Error::other("Invalid connection request"));
            }
            let mut state = self.shared.lock().unwrap();
            match command {
                "status"
                    if request.core.is_none()
                        && request.config.is_none()
                        && request.session.is_none() => {}
                "recover"
                    if request.core.is_none()
                        && request.config.is_none()
                        && request.session.is_none()
                        && request.cursor.is_none() =>
                {
                    if state.state == "stopped" {
                        if state.issued != state.completed {
                            return Err(io::Error::other("The service is busy"));
                        }
                        let ticket = state.issued + 1;
                        self.sender
                            .try_send(Work {
                                ticket,
                                action: Action::Recover,
                            })
                            .map_err(io::Error::other)?;
                        state.issued = ticket;
                        state.error = None;
                    }
                }
                "confirm"
                    if request.core.is_none()
                        && request.config.is_none()
                        && request.cursor.is_none() =>
                {
                    if request.session.is_none()
                        || request.session != state.session
                        || !state.ready
                        || state.state != "starting"
                        || state.issued != state.completed
                        || !state.process.as_ref().is_some_and(|process| unsafe { WaitForSingleObject(process.as_raw_handle(), 0) } == windows_sys::Win32::Foundation::WAIT_TIMEOUT)
                    {
                        return Err(io::Error::other("Stale or unready connection session"));
                    }
                    state.state = "running".into();
                }
                "start" | "validate" if request.session.is_none() && request.cursor.is_none() => {
                    if state.issued != state.completed
                        || (command == "start" && state.state != "stopped")
                    {
                        return Err(io::Error::other("The service is busy or already connected"));
                    }
                    let (core, source) = if typed {
                        if request.core.is_some() || request.config.is_some() {
                            return Err(io::Error::other(
                                "Typed connections do not accept configuration paths",
                            ));
                        }
                        let plan = request
                            .plan
                            .ok_or_else(|| io::Error::other("Missing connection plan"))?;
                        (plan.core, Source::Plan(plan))
                    } else {
                        let core = request
                            .core
                            .ok_or_else(|| io::Error::other("Missing core"))?;
                        let reference = request
                            .config
                            .ok_or_else(|| io::Error::other("Missing profile reference"))?;
                        config_path(Path::new("root"), &reference)?;
                        (core, Source::Reference(reference))
                    };
                    let ticket = state.issued + 1;
                    self.cancel.store(false, Ordering::Release);
                    let action = if command == "start" {
                        Action::Start(core, source)
                    } else {
                        Action::Validate(core, source)
                    };
                    self.sender
                        .try_send(Work { ticket, action })
                        .map_err(io::Error::other)?;
                    state.issued = ticket;
                    state.error = None;
                    if command == "start" {
                        state.session = Some(format!(
                            "{:x}-{:x}-{:x}",
                            std::process::id(),
                            SystemTime::now()
                                .duration_since(UNIX_EPOCH)
                                .unwrap()
                                .as_nanos(),
                            ticket
                        ));
                        state.core = Some(core);
                        state.state = "starting".into();
                        state.ready = false;
                    }
                }
                "stop"
                    if request.core.is_none()
                        && request.config.is_none()
                        && request.cursor.is_none() =>
                {
                    if request.session.is_none() || request.session != state.session {
                        return Err(io::Error::other("Stale connection session"));
                    }
                    if state.state == "stopped" {
                        state.error = None;
                    }
                    if state.state != "stopped" && state.state != "stopping" {
                        let ticket = state.issued + 1;
                        self.cancel.store(true, Ordering::Release);
                        self.sender
                            .try_send(Work {
                                ticket,
                                action: Action::Stop,
                            })
                            .map_err(io::Error::other)?;
                        state.issued = ticket;
                        state.state = "stopping".into();
                        state.error = None;
                    }
                }
                _ => return Err(io::Error::other("Invalid service command or fields")),
            }
            state.revision += 1;
            let cursor = request.cursor.unwrap_or(state.sequence);
            let mut logs = Vec::new();
            let mut budget = 20000usize;
            for entry in state
                .logs
                .iter()
                .filter(|(sequence, _)| *sequence > cursor)
                .take(16)
            {
                let size = serde_json::to_vec(entry).unwrap().len();
                if size > budget {
                    break;
                }
                budget -= size;
                logs.push(entry.clone());
            }
            let next = logs
                .last()
                .map(|(sequence, _)| *sequence)
                .unwrap_or(state.sequence);
            Ok(json!({ "protocol":1, "ok":true, "snapshot":*state, "logs":logs, "cursor":next }))
        })();
        serde_json::to_vec(
            &result
                .unwrap_or_else(|error| json!({"protocol":1,"ok":false,"error":error.to_string().chars().take(512).collect::<String>()})),
        )
        .unwrap()
    }
}
impl Drop for Control {
    fn drop(&mut self) {
        self.shutdown.store(true, Ordering::Release);
        self.cancel.store(true, Ordering::Release);
        if let Some(worker) = self.worker.take() {
            let _ = worker.join();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn typed_core_requests_cannot_supply_config_paths_or_extra_fields() {
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
        for request in [
            json!({"protocol":1,"command":"connection.start","core":"singBox","config":"profile-x/config.json"}),
            json!({"protocol":1,"command":"connection.validate"}),
            json!({"protocol":1,"command":"connection.status","config":"C:/secret"}),
            json!({"protocol":1,"command":"connection.recover","user_sid":"S-1-5-18"}),
            json!({"protocol":1,"command":"start","plan":{}}),
        ] {
            let reply: Value =
                serde_json::from_slice(&controller.reply(&serde_json::to_vec(&request).unwrap()))
                    .unwrap();
            assert_eq!(reply["ok"], false);
        }
        let snapshot: Value = serde_json::from_slice(
            &controller.reply(br#"{"protocol":1,"command":"connection.status"}"#),
        )
        .unwrap();
        assert_eq!(snapshot["snapshot"]["issued"], 0);
    }
    #[test]
    fn the_running_configuration_is_a_private_copy_of_the_validated_bytes() {
        let root = std::env::temp_dir().join(format!(
            "aora-core-copy-{}-{:x}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let profile = root.join("runtime").join("profile-test");
        fs::create_dir_all(&profile).unwrap();
        let source = profile.join("config.json");
        let bytes = serde_json::to_vec(&json!({"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":17890}],"outbounds":[{"type":"direct"}]})).unwrap();
        fs::write(&source, &bytes).unwrap();
        let config = snapshot_config(&root, Core::SingBox, "profile-test/config.json").unwrap();
        let copied = config.file.clone();
        fs::write(&source, b"changed source").unwrap();
        assert_eq!(fs::read(&copied).unwrap(), bytes);
        drop(config);
        assert!(!copied.exists());
        fs::remove_file(source).unwrap();
        fs::remove_dir(profile).unwrap();
        fs::remove_dir(root.join("runtime")).unwrap();
        fs::remove_dir(root).unwrap();
    }

    #[test]
    fn escaped_log_messages_cannot_exceed_the_response_frame_budget() {
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
        for _ in 0..20 {
            log(&controller.shared, "\0".repeat(1024));
        }
        let bytes = controller.reply(br#"{"protocol":1,"command":"status","cursor":0}"#);
        assert!(bytes.len() < 32768);
        let reply: Value = serde_json::from_slice(&bytes).unwrap();
        assert!(reply["logs"].as_array().unwrap().len() > 0);
        assert!(reply["cursor"].as_u64().unwrap() < 20);
    }
    #[test]
    fn configuration_references_cannot_escape_profile_storage() {
        for value in [
            "../secret",
            "profile-a/../../x",
            "C:/secret.json",
            "profile-a\\config.json",
            "profile-a/other.json",
            "profile-a/secret/config.json",
        ] {
            assert!(config_path(Path::new("root"), value).is_err());
        }
        assert!(config_path(Path::new("root"), "profile-abc123/config.json").is_ok());
    }
    #[test]
    fn config_policy_rejects_external_files_and_public_listeners() {
        let good = json!({"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":17890}],"outbounds":[{"type":"direct"}]});
        assert_eq!(inspect_config(Core::SingBox, &good).unwrap(), "proxy");
        let mut bad = good.clone();
        bad["inbounds"][0]["listen"] = json!("0.0.0.0");
        assert!(inspect_config(Core::SingBox, &bad).is_err());
        let mut bad = good.clone();
        bad["outbounds"][0]["tls"] = json!({"certificate_path":"C:/secret"});
        assert!(inspect_config(Core::SingBox, &bad).is_err());
        let mut bad = good;
        bad["experimental"] = json!({});
        assert!(inspect_config(Core::SingBox, &bad).is_err());
    }

    #[test]
    fn websocket_and_http_transport_paths_are_not_treated_as_filesystem_paths() {
        for transport in ["ws", "http", "httpupgrade"] {
            let mut config = json!({"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":17890}],"outbounds":[{"type":"vless","transport":{"type":transport,"path":"/connection"}}]});
            assert!(inspect_config(Core::SingBox, &config).is_ok());
            config["outbounds"][0]["tls"] = json!({"path":"C:/private"});
            assert!(inspect_config(Core::SingBox, &config).is_err());
        }
    }

    #[test]
    fn encrypted_dns_request_paths_are_not_local_file_paths() {
        let mut config = json!({
            "log":{"level":"info","timestamp":true},
            "dns":{"servers":[{"type":"local","tag":"local-dns"},
                {"type":"https","tag":"vpn-dns","server":"1.1.1.1","path":"/dns-query",
                 "tls":{"enabled":true,"server_name":"cloudflare-dns.com"},"detour":"proxy"}],
                "final":"vpn-dns"},
            "inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":17890}],
            "outbounds":[{"type":"direct","tag":"proxy"}],
            "route":{"final":"proxy","default_domain_resolver":"local-dns","auto_detect_interface":true}
        });
        assert!(inspect_config(Core::SingBox, &config).is_ok());
        config["dns"]["servers"][1]["tls"]["certificate_path"] = json!("C:/private.pem");
        assert!(inspect_config(Core::SingBox, &config).is_err());
        config["dns"]["servers"][1]["tls"]
            .as_object_mut()
            .unwrap()
            .remove("certificate_path");
        config["dns"]["servers"][1]["type"] = json!("hosts");
        assert!(inspect_config(Core::SingBox, &config).is_err());
        config["dns"]["servers"][1]["type"] = json!("https");
        config["log"]["output"] = json!("C:/private.log");
        assert!(inspect_config(Core::SingBox, &config).is_err());
    }
}
