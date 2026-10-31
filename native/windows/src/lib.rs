// SPDX-License-Identifier: GPL-3.0-or-later
#![cfg(windows)]

pub mod network;
#[cfg(feature = "runner")]
pub mod runner;
pub mod updates;

pub fn installation_root() -> std::io::Result<std::path::PathBuf> {
    #[cfg(feature = "migration-fixture")]
    { return Ok(std::path::PathBuf::from(env!("AORA_MIGRATION_FIXTURE_ROOT")).join("installed")); }
    #[cfg(not(feature = "migration-fixture"))]
    {
    use windows_sys::Win32::{System::Com::CoTaskMemFree, UI::Shell::{SHGetKnownFolderPath, FOLDERID_ProgramFiles}};
    unsafe {
        let mut value = std::ptr::null_mut();
        let code = SHGetKnownFolderPath(&FOLDERID_ProgramFiles, 0, std::ptr::null_mut(), &mut value);
        if code < 0 { return Err(std::io::Error::from_raw_os_error(code)); }
        let mut length = 0;
        while *value.add(length) != 0 { length += 1; }
        let path = std::path::PathBuf::from(<std::ffi::OsString as std::os::windows::ffi::OsStringExt>::from_wide(std::slice::from_raw_parts(value, length)));
        CoTaskMemFree(value.cast());
        Ok(path.join("AORAConnect"))
    }
    }
}

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
        result.extend(std::iter::repeat_n(b'\\' as u16, count));
        result.push(unit);
        slashes = 0;
    }
    result.extend(std::iter::repeat_n(b'\\' as u16, slashes * 2));
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

pub unsafe fn owned(handle: HANDLE) -> io::Result<OwnedHandle> {
    if handle.is_null() || handle == INVALID_HANDLE_VALUE {
        Err(io::Error::last_os_error())
    } else {
        Ok(OwnedHandle::from_raw_handle(handle))
    }
}

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
