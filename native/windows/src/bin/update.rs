// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
use aora_windows_helpers::{owned, updates::*, wide};
use std::{
    os::windows::{io::AsRawHandle, process::CommandExt},
    path::{Path, PathBuf},
    process::Command,
    time::{Duration, Instant},
};
use windows_sys::Win32::{Foundation::*, System::Threading::*, UI::WindowsAndMessaging::*};

fn app_root() -> Result<PathBuf> {
    Ok(
        PathBuf::from(std::env::var_os("LOCALAPPDATA").ok_or("Missing application storage")?)
            .join("AORAConnect"),
    )
}

fn run(args: &[String]) -> Result<()> {
    match args {
        [operation] if operation == "info" => {
            println!(
                "{}",
                serde_json::json!({"version": env!("AORA_APP_VERSION")})
            );
        }
        [operation, file] if operation == "verify-manifest" => {
            if std::fs::metadata(file)?.len() > 65536 {
                return Err("Release metadata is too large".into());
            }
            let release = verify_manifest(&std::fs::read(file)?)?;
            println!("{}", serde_json::to_string(&release)?);
        }
        [operation, file] if operation == "verify-package" => {
            let release = verify_package(Path::new(file))?;
            println!("{}", serde_json::to_string(&release)?);
        }
        [operation, file, pid] if operation == "install" => {
            let root = app_root()?;
            let package = Path::new(file).canonicalize()?;
            let runtime = root.join("runtime").canonicalize()?;
            if !package.starts_with(&runtime)
                || package.file_name().and_then(|v| v.to_str()) != Some("AORAConnect-Setup.exe")
            {
                return Err("Update must be staged in application storage".into());
            }
            let release = verify_package(&package)?;
            if version(&release.version)? <= version(env!("AORA_APP_VERSION"))? {
                return Err("Update must be newer than the installed application".into());
            }
            unsafe {
                let handle = OpenProcess(PROCESS_SYNCHRONIZE, 0, pid.parse()?);
                if !handle.is_null() {
                    let parent = owned(handle)?;
                    if WaitForSingleObject(parent.as_raw_handle(), 30000) != WAIT_OBJECT_0 {
                        return Err("Application did not close; update cancelled".into());
                    }
                } else if GetLastError() != ERROR_INVALID_PARAMETER {
                    return Err(std::io::Error::last_os_error().into());
                }
            }
            // The portable launcher may retain its mutex briefly after the app exits.
            let deadline = Instant::now() + Duration::from_secs(10);
            loop {
                let handle = unsafe {
                    OpenMutexW(
                        SYNCHRONIZATION_SYNCHRONIZE,
                        0,
                        wide("Local\\AORAConnectPortableLaunch").as_ptr(),
                    )
                };
                if handle.is_null() {
                    break;
                }
                drop(unsafe { owned(handle)? });
                if Instant::now() >= deadline {
                    return Err("Close the portable launcher before updating".into());
                }
                std::thread::sleep(Duration::from_millis(100));
            }
            // Recheck after shutdown; never run a package swapped since staging.
            verify_package(&package)?;
            let status = Command::new(&package)
                .args(["/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART"])
                .creation_flags(CREATE_NO_WINDOW)
                .status()?;
            if !status.success() {
                return Err(format!(
                    "Installer failed (exit {:?}); your settings have been retained",
                    status.code()
                )
                .into());
            }
            Command::new(root.join("app/aoravpn.exe"))
                .current_dir(root.join("app"))
                .spawn()?;
        }
        _ => return Err("Invalid update helper arguments".into()),
    }
    Ok(())
}

fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if let Err(error) = run(&args) {
        if args.first().map(String::as_str) == Some("install") {
            unsafe {
                MessageBoxW(
                    std::ptr::null_mut(),
                    wide(error.to_string()).as_ptr(),
                    wide("AORA Connect update").as_ptr(),
                    MB_OK | MB_ICONERROR,
                );
            }
        } else {
            eprintln!("{error}");
        }
        std::process::exit(1);
    }
}
