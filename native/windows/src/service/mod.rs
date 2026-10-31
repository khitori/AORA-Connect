// SPDX-License-Identifier: GPL-3.0-or-later
#[cfg(not(feature = "service-fixture"))]
mod authorization;
#[cfg(not(feature = "service-fixture"))]
mod checks;
#[cfg(not(feature = "service-fixture"))]
mod connection_plan;
#[cfg(not(feature = "service-fixture"))]
mod core;
mod identity;
#[cfg(not(feature = "service-fixture"))]
mod leak_recovery;
#[cfg(not(feature = "service-fixture"))]
mod manager;
#[cfg(not(feature = "service-fixture"))]
mod process;
#[cfg(not(feature = "service-fixture"))]
mod runtime;
#[cfg(not(feature = "service-fixture"))]
mod settings;
mod transport;

use crate::owned;
#[cfg(not(feature = "service-fixture"))]
use crate::wide;
use serde::{Deserialize, Serialize};
use std::{io, os::windows::io::AsRawHandle};
#[cfg(not(feature = "service-fixture"))]
use std::{os::windows::io::OwnedHandle, path::PathBuf, ptr::null_mut, sync::OnceLock};
use windows_sys::Win32::System::Threading::*;
#[cfg(not(feature = "service-fixture"))]
use windows_sys::Win32::{
    Foundation::*, Storage::FileSystem::FILE_ATTRIBUTE_REPARSE_POINT, System::Services::*,
};

#[cfg(not(feature = "service-scm-fixture"))]
pub const SERVICE_NAME: &str = "AORAConnectService";
#[cfg(feature = "service-scm-fixture")]
pub const SERVICE_NAME: &str = concat!("AORAConnectServiceTest-", env!("AORA_SERVICE_FIXTURE_ID"));
const PROTOCOL: u32 = 1;
const VERSION: &str = env!("AORA_APP_VERSION");
#[cfg(not(feature = "service-fixture"))]
static STOP: OnceLock<OwnedHandle> = OnceLock::new();

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
struct Request {
    protocol: u32,
    command: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Health {
    pub protocol: u32,
    pub version: String,
    pub pid: u32,
    pub phase: String,
    pub vpn_control: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

fn reply(bytes: &[u8]) -> Vec<u8> {
    let error = match serde_json::from_slice::<Request>(bytes) {
        Err(_) => Some("invalid_request"),
        Ok(request) if request.protocol != PROTOCOL => Some("unsupported_protocol"),
        Ok(request) if request.command != "health" => Some("unsupported_command"),
        Ok(_) => None,
    };
    serde_json::to_vec(&Health {
        protocol: PROTOCOL,
        version: VERSION.into(),
        pid: std::process::id(),
        phase: "foundation".into(),
        vpn_control: false,
        error: error.map(str::to_owned),
    })
    .unwrap()
}

fn pipe_name() -> String {
    #[cfg(feature = "service-fixture")]
    return format!(
        r"\\.\pipe\AORAConnectService-Test-{}",
        env!("AORA_SERVICE_FIXTURE_ID")
    );
    #[cfg(feature = "service-scm-fixture")]
    return format!(
        r"\\.\pipe\AORAConnectService-ScmTest-{}",
        env!("AORA_SERVICE_FIXTURE_ID")
    );
    #[cfg(not(any(feature = "service-fixture", feature = "service-scm-fixture")))]
    return r"\\.\pipe\AORAConnectService-v1".into();
}

#[cfg(not(feature = "service-fixture"))]
fn service_root() -> io::Result<PathBuf> {
    let root = crate::installation_root()?;
    #[cfg(feature = "service-scm-fixture")]
    return Ok(root
        .parent()
        .ok_or_else(|| io::Error::other("Missing Program Files directory"))?
        .join(format!(
            "AORAConnect-ServiceTest-{}",
            env!("AORA_SERVICE_FIXTURE_ID")
        )));
    #[cfg(not(feature = "service-scm-fixture"))]
    Ok(root)
}

#[cfg(not(feature = "service-fixture"))]
fn installed_executable() -> io::Result<PathBuf> {
    Ok(service_root()?.join("app").join("aoravpn_service.exe"))
}

#[cfg(not(feature = "service-fixture"))]
fn require_installed_executable() -> io::Result<PathBuf> {
    let expected = installed_executable()?;
    let root = service_root()?;
    for path in [&root, &root.join("app"), &expected] {
        use std::os::windows::fs::MetadataExt;
        if std::fs::symlink_metadata(path)?.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
            return Err(io::Error::other(
                "The service installation must not contain links",
            ));
        }
    }
    if std::env::current_exe()?.canonicalize()? != expected.canonicalize()? {
        return Err(io::Error::other(
            "Service management must run from Program Files\\AORAConnect\\app",
        ));
    }
    Ok(expected)
}

pub fn probe() -> io::Result<Health> {
    #[cfg(feature = "service-fixture")]
    let expected = std::env::current_exe()?;
    #[cfg(not(feature = "service-fixture"))]
    let expected = installed_executable()?;
    let request = serde_json::to_vec(&Request {
        protocol: PROTOCOL,
        command: "health".into(),
    })?;
    let bytes = transport::request(&pipe_name(), &expected, &request)?;
    let health: Health = serde_json::from_slice(&bytes)?;
    if health.protocol != PROTOCOL
        || health.error.is_some()
        || health.phase
            != if cfg!(feature = "service-fixture") {
                "foundation"
            } else {
                "core-control"
            }
        || health.vpn_control == cfg!(feature = "service-fixture")
    {
        return Err(io::Error::other("The service protocol is incompatible"));
    }
    Ok(health)
}

#[cfg(not(feature = "service-fixture"))]
fn report(handle: SERVICE_STATUS_HANDLE, state: u32, error: u32) -> io::Result<()> {
    let status = SERVICE_STATUS {
        dwServiceType: SERVICE_WIN32_OWN_PROCESS,
        dwCurrentState: state,
        dwControlsAccepted: if state == SERVICE_RUNNING {
            SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN
        } else {
            0
        },
        dwWin32ExitCode: error,
        dwServiceSpecificExitCode: 0,
        dwCheckPoint: u32::from(state == SERVICE_START_PENDING || state == SERVICE_STOP_PENDING),
        dwWaitHint: if state == SERVICE_START_PENDING || state == SERVICE_STOP_PENDING {
            20000
        } else {
            0
        },
    };
    if unsafe { SetServiceStatus(handle, &status) } == 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

#[cfg(not(feature = "service-fixture"))]
unsafe extern "system" fn control(
    code: u32,
    _: u32,
    _: *mut std::ffi::c_void,
    _: *mut std::ffi::c_void,
) -> u32 {
    match code {
        SERVICE_CONTROL_STOP | SERVICE_CONTROL_SHUTDOWN => {
            if let Some(stop) = STOP.get() {
                SetEvent(stop.as_raw_handle());
            }
            NO_ERROR
        }
        SERVICE_CONTROL_INTERROGATE => NO_ERROR,
        _ => ERROR_CALL_NOT_IMPLEMENTED,
    }
}

#[cfg(not(feature = "service-fixture"))]
unsafe extern "system" fn service_main(_: u32, _: *mut *mut u16) {
    let handle =
        RegisterServiceCtrlHandlerExW(wide(SERVICE_NAME).as_ptr(), Some(control), std::ptr::null());
    if handle.is_null() {
        return;
    }
    let result = (|| -> io::Result<()> {
        report(handle, SERVICE_START_PENDING, NO_ERROR)?;
        require_installed_executable()?;
        let stop = owned(CreateEventW(std::ptr::null(), 1, 0, std::ptr::null()))?;
        STOP.set(stop)
            .map_err(|_| io::Error::other("The service was already initialized"))?;
        let result = (|| {
            let policy = authorization::load(&service_root()?)?;
            let server = transport::Server::new(&pipe_name(), &policy.pipe_acl())?;
            runtime::sweep(&service_root()?)?;
            let controller = core::Control::new(service_root()?, STOP.get().unwrap().try_clone()?);
            let settings = settings::Store::new(service_root()?);
            let checks = checks::Control::new(service_root()?, STOP.get().unwrap().try_clone()?);
            report(handle, SERVICE_RUNNING, NO_ERROR)?;
            let result =
                server.serve_authenticated(STOP.get().unwrap().as_raw_handle(), |peer, bytes| {
                    let request = serde_json::from_slice::<serde_json::Value>(bytes).ok();
                    let command = request
                        .as_ref()
                        .and_then(|request| request["command"].as_str())
                        .unwrap_or("");
                    if !policy.permits(peer, command) {
                        return br#"{"protocol":1,"ok":false,"error":"access_denied"}"#.to_vec();
                    }
                    if matches!(command, "settings.read" | "settings.write") {
                        return settings.reply(bytes);
                    }
                    if matches!(command, "checks.open" | "checks.status" | "checks.close") {
                        return checks.reply(bytes);
                    }
                    if bytes.len() > 4096 && !command.starts_with("connection.") {
                        return br#"{"protocol":1,"ok":false,"error":"request_too_large"}"#
                            .to_vec();
                    }
                    if command == "access" {
                        return policy.access_reply(peer, bytes);
                    }
                    if command == "health" {
                        let mut health: serde_json::Value =
                            serde_json::from_slice(&reply(bytes)).unwrap();
                        health["phase"] = "core-control".into();
                        health["vpn_control"] = true.into();
                        serde_json::to_vec(&health).unwrap()
                    } else {
                        controller.reply(bytes)
                    }
                });
            let _ = report(handle, SERVICE_STOP_PENDING, NO_ERROR);
            drop(controller);
            drop(checks);
            result
        })();
        result
    })();
    let code = match result {
        Ok(()) => NO_ERROR,
        Err(error) => error
            .raw_os_error()
            .map(|c| c as u32)
            .unwrap_or(ERROR_GEN_FAILURE),
    };
    let _ = report(handle, SERVICE_STOPPED, code);
}

pub fn run(arguments: Vec<String>) -> io::Result<()> {
    match arguments.as_slice() {
        #[cfg(not(any(
            feature = "service-fixture",
            feature = "service-scm-fixture",
            feature = "migration-fixture"
        )))]
        [command] if command.starts_with("startup-") => {
            require_installed_executable()?;
            let result = match command.as_str() {
                "startup-status" => crate::startup::status()?,
                "startup-set" => {
                    use std::io::Read;
                    let mut bytes = Vec::new();
                    io::stdin().take(1025).read_to_end(&mut bytes)?;
                    if bytes.len() > 1024 {
                        return Err(io::Error::other("Invalid startup request"));
                    }
                    crate::startup::configure(serde_json::from_slice(&bytes)?)?
                }
                "startup-remove" => {
                    crate::startup::remove_all()?;
                    return Ok(());
                }
                _ => return Err(io::Error::other("Unknown startup command")),
            };
            println!("{}", serde_json::to_string(&result)?);
            Ok(())
        }
        #[cfg(not(feature = "service-fixture"))]
        [command] if command == "installation-info" => {
            println!(
                "{}",
                serde_json::json!({
                    "root": service_root()?, "service": SERVICE_NAME,
                    "protocol": PROTOCOL, "version": VERSION,
                    "fixture": cfg!(any(feature = "service-scm-fixture", feature = "migration-fixture"))
                })
            );
            Ok(())
        }
        [command] if command == "probe" => {
            println!("{}", serde_json::to_string(&probe()?)?);
            Ok(())
        }
        #[cfg(not(feature = "service-fixture"))]
        [command] if command == "request" => {
            use std::io::Read;
            let mut bytes = Vec::new();
            io::stdin()
                .take(transport::MAX_FRAME as u64 + 1)
                .read_to_end(&mut bytes)?;
            if bytes.is_empty() || bytes.len() > transport::MAX_FRAME {
                return Err(io::Error::other("Service request size limit exceeded"));
            }
            if bytes.len() > 4096
                && !serde_json::from_slice::<serde_json::Value>(&bytes)
                    .ok()
                    .is_some_and(|r| {
                        matches!(
                            r["command"].as_str(),
                            Some(
                                "settings.read"
                                    | "settings.write"
                                    | "connection.start"
                                    | "connection.validate"
                                    | "checks.open"
                            )
                        )
                    })
            {
                return Err(io::Error::other("Service request size limit exceeded"));
            }
            let response = match transport::request(&pipe_name(), &installed_executable()?, &bytes)
            {
                Ok(response) => response,
                Err(error) => serde_json::to_vec(
                    &serde_json::json!({"protocol":1,"ok":false,"error":format!("Windows service communication failed: {error}"),"service_stopped":manager::is_stopped()}),
                )?,
            };
            println!("{}", String::from_utf8(response).map_err(io::Error::other)?);
            Ok(())
        }
        #[cfg(feature = "service-scm-fixture")]
        [command] if command == "fixture-info" => {
            println!(
                "{}",
                serde_json::json!({ "root": service_root()?, "service": SERVICE_NAME, "pipe": pipe_name(), "version": VERSION })
            );
            Ok(())
        }
        #[cfg(feature = "service-fixture")]
        [command] if command == "fixture" => {
            use std::io::Read;
            let stop = unsafe { owned(CreateEventW(std::ptr::null(), 1, 0, std::ptr::null()))? };
            let signal = stop.try_clone()?;
            std::thread::spawn(move || {
                let _ = io::stdin().read(&mut [0]);
                unsafe {
                    SetEvent(signal.as_raw_handle());
                }
            });
            transport::Server::new(&pipe_name(), &transport::fixture_acl()?)?
                .serve(stop.as_raw_handle())
        }
        #[cfg(not(feature = "service-fixture"))]
        [command] if command == "run" => {
            require_installed_executable()?;
            let mut name = wide(SERVICE_NAME);
            let mut table = [
                SERVICE_TABLE_ENTRYW {
                    lpServiceName: name.as_mut_ptr(),
                    lpServiceProc: Some(service_main),
                },
                SERVICE_TABLE_ENTRYW {
                    lpServiceName: null_mut(),
                    lpServiceProc: None,
                },
            ];
            if unsafe { StartServiceCtrlDispatcherW(table.as_mut_ptr()) } == 0 {
                return Err(io::Error::last_os_error());
            }
            Ok(())
        }
        #[cfg(not(feature = "service-fixture"))]
        [command] if ["install", "start", "stop", "remove"].contains(&command.as_str()) => {
            let executable = require_installed_executable()?;
            manager::manage(command, &executable)
        }
        _ => Err(io::Error::other(
            "Expected run, probe, install, stop or remove",
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn foundation_only_accepts_versioned_health_requests() {
        for (request, expected) in [
            (r#"{"protocol":1,"command":"health"}"#, None),
            (
                r#"{"protocol":2,"command":"health"}"#,
                Some("unsupported_protocol"),
            ),
            (
                r#"{"protocol":1,"command":"start"}"#,
                Some("unsupported_command"),
            ),
            (
                r#"{"protocol":1,"command":"health","path":"evil.exe"}"#,
                Some("invalid_request"),
            ),
            ("not json", Some("invalid_request")),
        ] {
            let health: Health = serde_json::from_slice(&reply(request.as_bytes())).unwrap();
            assert_eq!(health.error.as_deref(), expected);
            assert!(!health.vpn_control);
            assert_eq!(health.phase, "foundation");
        }
    }
}
