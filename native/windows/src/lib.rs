// SPDX-License-Identifier: GPL-3.0-or-later
#![cfg(windows)]

pub mod network;

use std::ffi::OsStr;
use std::io;
use std::mem::{size_of, zeroed};
use std::os::windows::ffi::OsStrExt;
use std::os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle};
use std::path::Path;
use std::ptr::null;
use windows_sys::Win32::Foundation::{HANDLE, INVALID_HANDLE_VALUE};
use windows_sys::Win32::System::Threading::*;
use windows_sys::Win32::UI::WindowsAndMessaging::SW_HIDE;

pub fn wide(value: impl AsRef<OsStr>) -> Vec<u16> {
    value.as_ref().encode_wide().chain(Some(0)).collect()
}

/// Quote one argument using the Windows CRT command-line parsing rules.
pub fn quote(value: &OsStr) -> Vec<u16> {
    let mut result = vec![b'"' as u16];
    let mut slashes = 0;
    for unit in value.encode_wide() {
        if unit == b'\\' as u16 {
            slashes += 1;
            continue;
        }
        let count = if unit == b'"' as u16 {
            slashes * 2 + 1
        } else {
            slashes
        };
        result.extend(std::iter::repeat(b'\\' as u16).take(count));
        result.push(unit);
        slashes = 0;
    }
    result.extend(std::iter::repeat(b'\\' as u16).take(slashes * 2));
    result.push(b'"' as u16);
    result
}

pub struct Process {
    pub handle: OwnedHandle,
    pub id: u32,
}

impl Process {
    pub fn wait(&self) -> io::Result<u32> {
        unsafe {
            if WaitForSingleObject(self.handle.as_raw_handle(), INFINITE) != 0 {
                return Err(io::Error::last_os_error());
            }
            let mut code = 1;
            if GetExitCodeProcess(self.handle.as_raw_handle(), &mut code) == 0 {
                return Err(io::Error::last_os_error());
            }
            Ok(code)
        }
    }
}

/// The returned handles are exclusively owned; no raw HANDLE escapes the owner.
///
/// # Safety
/// `handle` must be an exclusively owned, valid kernel handle returned by a
/// Windows creation API, and must not be closed elsewhere after this call.
pub unsafe fn owned(handle: HANDLE) -> io::Result<OwnedHandle> {
    if handle.is_null() || handle == INVALID_HANDLE_VALUE {
        Err(io::Error::last_os_error())
    } else {
        Ok(OwnedHandle::from_raw_handle(handle))
    }
}

/// Launch either a hidden console or a process inside the existing hidden one.
pub fn spawn(
    executable: &Path,
    args: &[&OsStr],
    flags: u32,
    input: HANDLE,
    output: HANDLE,
    error: HANDLE,
) -> io::Result<Process> {
    let application = wide(executable.as_os_str());
    let mut command = quote(executable.as_os_str());
    for argument in args {
        command.push(b' ' as u16);
        command.extend(quote(argument));
    }
    command.push(0);
    unsafe {
        for handle in [input, output, error] {
            if windows_sys::Win32::Foundation::SetHandleInformation(handle, 1, 1) == 0 {
                return Err(io::Error::last_os_error());
            }
        }
        let mut startup: STARTUPINFOW = zeroed();
        startup.cb = size_of::<STARTUPINFOW>() as u32;
        startup.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW | STARTF_FORCEOFFFEEDBACK;
        startup.wShowWindow = SW_HIDE as u16;
        startup.hStdInput = input;
        startup.hStdOutput = output;
        startup.hStdError = error;
        let mut process: PROCESS_INFORMATION = zeroed();
        if CreateProcessW(
            application.as_ptr(),
            command.as_mut_ptr(),
            null(),
            null(),
            1,
            flags,
            null(),
            null(),
            &startup,
            &mut process,
        ) == 0
        {
            return Err(io::Error::last_os_error());
        }
        let _thread = owned(process.hThread)?;
        Ok(Process {
            handle: owned(process.hProcess)?,
            id: process.dwProcessId,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quotes_empty_spaces_quotes_and_trailing_slashes() {
        for (input, expected) in [
            ("", "\"\""),
            ("a b", "\"a b\""),
            ("a\"b", "\"a\\\"b\""),
            ("C:\\Apps\\", "\"C:\\Apps\\\\\""),
        ] {
            assert_eq!(
                String::from_utf16(&quote(OsStr::new(input))).unwrap(),
                expected
            );
        }
    }
}
