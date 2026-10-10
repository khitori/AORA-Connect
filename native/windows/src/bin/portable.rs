// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
use aora_windows_helpers::{owned, wide, Process};
use std::fs;
use std::mem::{size_of, zeroed};
use std::os::windows::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::ptr::{null, null_mut};
use windows_sys::Win32::Foundation::{GetLastError, ERROR_ALREADY_EXISTS};
use windows_sys::Win32::System::Com::{CoCreateGuid, CoTaskMemFree};
use windows_sys::Win32::System::Threading::{CreateMutexW, CREATE_NO_WINDOW};
use windows_sys::Win32::UI::Shell::*;
use windows_sys::Win32::UI::WindowsAndMessaging::*;

const PAYLOAD: &[u8] = include_bytes!(env!("AORA_PAYLOAD_ZIP"));
const PACKAGE_ID: &str = env!("AORA_PACKAGE_ID");
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

fn literal(value: &str) -> String {
    format!("'{}'", value.replace('\'', "''"))
}

fn root() -> Result<PathBuf> {
    unsafe {
        let mut value = null_mut();
        let code = SHGetKnownFolderPath(&FOLDERID_LocalAppData, 0, null_mut(), &mut value);
        if code < 0 {
            return Err(format!("Could not find local app storage ({code})").into());
        }
        let mut length = 0;
        while *value.add(length) != 0 {
            length += 1;
        }
        use std::os::windows::ffi::OsStringExt;
        let path = std::ffi::OsString::from_wide(std::slice::from_raw_parts(value, length));
        CoTaskMemFree(value.cast());
        Ok(PathBuf::from(path).join("AORAConnect"))
    }
}

fn unpack(root: &Path) -> Result<()> {
    let mut id = unsafe { zeroed() };
    if unsafe { CoCreateGuid(&mut id) } < 0 {
        return Err("Could not create an unpacking session".into());
    }
    let name = format!(
        "package-{:08x}-{:04x}-{:04x}-{:02x?}",
        id.data1, id.data2, id.data3, id.data4
    )
    .replace(['[', ']', ',', ' '], "");
    let session = root.join("runtime").join(name);
    fs::create_dir_all(session.parent().ok_or("Invalid runtime directory")?)?;
    // create_dir fails rather than reusing a previous or unrelated directory.
    fs::create_dir(&session)?;
    let result = (|| -> Result<()> {
        fs::write(session.join("payload.zip"), PAYLOAD)?;
        let root_text = root.to_str().ok_or("Storage path is not valid Unicode")?;
        let session_text = session
            .to_str()
            .ok_or("Session path is not valid Unicode")?;
        let script = format!(
            "$ErrorActionPreference='Stop'; $root={}; $session={}; \
             $stage=Join-Path $session 'stage'; \
             Expand-Archive -LiteralPath (Join-Path $session 'payload.zip') -DestinationPath $stage; \
             foreach($name in @('app','cores')) {{ \
             $source=Join-Path $stage $name; if(!(Test-Path -LiteralPath $source)){{throw 'Incomplete package'}}; \
             $destination=Join-Path $root $name; \
             New-Item -ItemType Directory -Force -Path $destination | Out-Null; \
             Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force }}",
            literal(root_text), literal(session_text));
        // A private UTF-8-BOM script avoids shell-quoting paths and command-length
        // limits. No commands from subscriptions or other external inputs enter it.
        let script_path = session.join("unpack.ps1");
        let mut script_bytes = vec![0xef, 0xbb, 0xbf];
        script_bytes.extend(script.as_bytes());
        fs::write(&script_path, script_bytes)?;
        let powershell = std::env::var_os("SystemRoot").ok_or("Missing Windows directory")?;
        let status = Command::new(
            PathBuf::from(powershell).join("System32/WindowsPowerShell/v1.0/powershell.exe"),
        )
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
        ])
        .arg(script_path)
        .creation_flags(CREATE_NO_WINDOW)
        .status()?;
        if !status.success() {
            return Err(
                "Unpacking failed. Close the running app and check free disk space.".into(),
            );
        }
        fs::write(root.join("app/package-id.txt"), PACKAGE_ID)?;
        Ok(())
    })();
    // Delete only the fresh directory created above, never the application root.
    let cleanup = fs::remove_dir_all(&session);
    result?;
    cleanup?;
    Ok(())
}

fn run() -> Result<()> {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    let extract_only = match args.as_slice() {
        [] => false,
        [arg] if arg == "--extract-only" => true,
        _ => return Err("Unsupported launcher argument".into()),
    };
    let _mutex = unsafe {
        let handle = CreateMutexW(null(), 1, wide("Local\\AORAConnectPortableLaunch").as_ptr());
        let existing = GetLastError() == ERROR_ALREADY_EXISTS;
        let handle = owned(handle)?;
        if existing {
            return Err(
                "AORA Connect is already running or being unpacked. Close it first.".into(),
            );
        }
        handle
    };
    let root = root()?;
    fs::create_dir_all(&root)?;
    let required = [
        "app/aoravpn.exe",
        "app/flutter_windows.dll",
        "app/data/app.so",
        "app/aoravpn_core_host.exe",
        "app/aoravpn_core_console.exe",
        "app/aoravpn_server_ping.exe",
        "app/aoravpn_kill_switch.exe",
        "app/vcruntime140.dll",
        "cores/sing-box-1.14.2-windows-amd64/sing-box.exe",
        "cores/sing-box-1.14.2-windows-amd64/libcronet.dll",
        "cores/xray-v26.9.30-windows-64/xray.exe",
        "cores/xray-v26.9.30-windows-64/wintun.dll",
    ];
    if fs::read_to_string(root.join("app/package-id.txt")).unwrap_or_default() != PACKAGE_ID
        || required.iter().any(|path| !root.join(path).is_file())
    {
        unpack(&root)?;
    }
    if extract_only {
        return Ok(());
    }
    let exe = wide(root.join("app/aoravpn.exe"));
    let directory = wide(root.join("app"));
    let verb = wide("runas");
    unsafe {
        let mut launch: SHELLEXECUTEINFOW = zeroed();
        launch.cbSize = size_of::<SHELLEXECUTEINFOW>() as u32;
        launch.fMask = SEE_MASK_NOCLOSEPROCESS;
        launch.lpVerb = verb.as_ptr();
        launch.lpFile = exe.as_ptr();
        launch.lpDirectory = directory.as_ptr();
        launch.nShow = SW_SHOWNORMAL;
        if ShellExecuteExW(&mut launch) == 0 {
            return Err(std::io::Error::last_os_error().into());
        }
        if !launch.hProcess.is_null() {
            Process {
                handle: owned(launch.hProcess)?,
                id: 0,
            }
            .wait()?;
        }
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        let message = wide(error.to_string());
        unsafe {
            MessageBoxW(
                null_mut(),
                message.as_ptr(),
                wide("AORA Connect").as_ptr(),
                MB_OK | MB_ICONERROR,
            );
        }
        std::process::exit(1);
    }
}
