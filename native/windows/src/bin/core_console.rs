// SPDX-License-Identifier: GPL-3.0-or-later
use aora_windows_helpers::{owned, spawn, wide};
use std::ffi::OsStr;
use std::io::{self, Read};
use std::os::windows::io::AsRawHandle;
use std::path::Path;
use windows_sys::Win32::Foundation::{GENERIC_READ, WAIT_TIMEOUT};
use windows_sys::Win32::Security::SECURITY_ATTRIBUTES;
use windows_sys::Win32::Storage::FileSystem::*;
use windows_sys::Win32::System::Console::*;
use windows_sys::Win32::System::Threading::*;
use windows_sys::Win32::UI::WindowsAndMessaging::IsWindowVisible;

fn run() -> io::Result<u32> {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if !(args.len() == 2 || args.len() == 3) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Expected core and config paths",
        ));
    }
    unsafe {
        let window = GetConsoleWindow();
        if window.is_null() || IsWindowVisible(window) != 0 {
            return Err(io::Error::other(
                "Core console requires the hidden host launcher",
            ));
        }
        let security = SECURITY_ATTRIBUTES {
            nLength: std::mem::size_of::<SECURITY_ATTRIBUTES>() as u32,
            lpSecurityDescriptor: std::ptr::null_mut(),
            bInheritHandle: 1,
        };
        let input = owned(CreateFileW(
            wide("NUL").as_ptr(),
            GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            &security,
            OPEN_EXISTING,
            0,
            std::ptr::null_mut(),
        ))?;
        let xray = args.get(2).map(|value| value == "xray").unwrap_or(false);
        let mut arguments = vec![OsStr::new("run"), OsStr::new("-c"), args[1].as_os_str()];
        if !xray {
            arguments.push(OsStr::new("--disable-color"));
        }
        let started = std::time::Instant::now();
        let child = spawn(
            Path::new(&args[0]),
            &arguments,
            CREATE_NEW_PROCESS_GROUP,
            input.as_raw_handle(),
            GetStdHandle(STD_OUTPUT_HANDLE),
            GetStdHandle(STD_ERROR_HANDLE),
        )?;
        let process = child.handle.try_clone()?;
        let id = child.id;
        std::thread::spawn(move || {
            let mut byte = [0u8; 1];
            let stdin = io::stdin();
            let mut control = stdin.lock();
            while control.read(&mut byte).ok() == Some(1) {
                if byte[0] == b'\n' {
                    break;
                }
            }
            if xray {
                let remaining =
                    std::time::Duration::from_millis(500).saturating_sub(started.elapsed());
                if WaitForSingleObject(process.as_raw_handle(), remaining.as_millis() as u32) == 0 {
                    return;
                }
            }
            if WaitForSingleObject(process.as_raw_handle(), 0) != 0 {
                GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT, id);
                if WaitForSingleObject(process.as_raw_handle(), 8000) == WAIT_TIMEOUT {
                    eprintln!("Graceful shutdown timed out; terminating core.");
                    TerminateProcess(process.as_raw_handle(), 1);
                }
            }
        });
        child.wait()
    }
}

fn main() {
    let code = match run() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("Core host: {error}");
            1
        }
    };
    std::process::exit(code as i32);
}
