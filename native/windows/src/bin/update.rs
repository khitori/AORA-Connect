// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
use aora_windows_helpers::{owned, updates::*, wide};
use std::{
    os::windows::{fs::OpenOptionsExt, io::AsRawHandle, process::CommandExt},
    path::{Path, PathBuf},
    process::Command,
    time::{Duration, Instant},
};
use windows_sys::Win32::{Foundation::*, System::Threading::*, UI::WindowsAndMessaging::*};

fn app_root() -> Result<PathBuf> {
    Ok(aora_windows_helpers::installation_root()?)
}

fn installer_lease(directory: &Path) -> std::io::Result<std::fs::File> {
    std::fs::OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .share_mode(0)
        .open(directory.join(".installer.lock"))
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
        [operation, file] if operation == "verify-package" || operation == "inspect-package" => {
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
            let _installer_lease =
                installer_lease(package.parent().ok_or("Missing update directory")?)?;
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn installer_lease_blocks_cleanup_until_helper_exits() {
        let directory =
            std::env::temp_dir().join(format!("aora-update-lease-{}", std::process::id()));
        std::fs::create_dir(&directory).unwrap();
        let path = directory.join(".installer.lock");
        let lease = installer_lease(&directory).unwrap();
        assert!(std::fs::OpenOptions::new().write(true).open(&path).is_err());
        assert!(std::fs::remove_file(&path).is_err());
        drop(lease);
        std::fs::remove_file(path).unwrap();
        std::fs::remove_dir(directory).unwrap();
    }
}
