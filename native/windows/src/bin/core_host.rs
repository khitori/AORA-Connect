// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]

use aora_windows_helpers::spawn;
use std::io;
use windows_sys::Win32::System::Console::*;
use windows_sys::Win32::System::Threading::CREATE_NEW_CONSOLE;

fn run() -> io::Result<u32> {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if !(args.len() == 2 || args.len() == 3) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Expected core and config paths",
        ));
    }
    let worker = std::env::current_exe()?.with_file_name("aoravpn_core_console.exe");
    let refs: Vec<_> = args.iter().map(|arg| arg.as_os_str()).collect();
    unsafe {
        spawn(
            &worker,
            &refs,
            CREATE_NEW_CONSOLE,
            GetStdHandle(STD_INPUT_HANDLE),
            GetStdHandle(STD_OUTPUT_HANDLE),
            GetStdHandle(STD_ERROR_HANDLE),
        )?
        .wait()
    }
}

fn main() {
    let code = match run() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("Unable to launch hidden core console: {error}");
            1
        }
    };
    std::process::exit(code as i32);
}
