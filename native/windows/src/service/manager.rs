// SPDX-License-Identifier: GPL-3.0-or-later
use super::{transport::SecurityDescriptor, SERVICE_NAME};
use crate::{owned, wide};
use std::{
    io,
    mem::{size_of, zeroed},
    os::windows::io::AsRawHandle,
    path::Path,
    ptr::{null, null_mut},
    time::{Duration, Instant},
};
use windows_sys::Win32::{
    Foundation::*,
    Security::DACL_SECURITY_INFORMATION,
    Storage::FileSystem::{DELETE, WRITE_DAC},
    System::{
        Services::*,
        Threading::{OpenProcess, WaitForSingleObject, PROCESS_SYNCHRONIZE},
    },
};

struct ServiceHandle(SC_HANDLE);

impl ServiceHandle {
    unsafe fn new(handle: SC_HANDLE) -> io::Result<Self> {
        if handle.is_null() {
            Err(io::Error::last_os_error())
        } else {
            Ok(Self(handle))
        }
    }
}

impl Drop for ServiceHandle {
    fn drop(&mut self) {
        unsafe {
            CloseServiceHandle(self.0);
        }
    }
}

fn command_line(executable: &Path) -> io::Result<String> {
    let mut quoted =
        String::from_utf16(&crate::quote(executable.as_os_str())).map_err(io::Error::other)?;
    quoted.push_str(" run");
    Ok(quoted)
}

unsafe fn string_at(value: *const u16) -> String {
    if value.is_null() {
        return String::new();
    }
    let mut length = 0;
    while *value.add(length) != 0 {
        length += 1;
    }
    String::from_utf16_lossy(std::slice::from_raw_parts(value, length))
}

fn verify_configuration(service: SC_HANDLE, executable: &Path) -> io::Result<()> {
    unsafe {
        let mut size = 0;
        QueryServiceConfigW(service, null_mut(), 0, &mut size);
        if GetLastError() != ERROR_INSUFFICIENT_BUFFER {
            return Err(io::Error::last_os_error());
        }
        if size as usize > 65536 {
            return Err(io::Error::other(
                "Service configuration exceeds its size limit",
            ));
        }
        let mut storage = vec![0usize; (size as usize).div_ceil(size_of::<usize>())];
        let config = storage.as_mut_ptr().cast::<QUERY_SERVICE_CONFIGW>();
        if QueryServiceConfigW(service, config, size, &mut size) == 0 {
            return Err(io::Error::last_os_error());
        }
        if !string_at((*config).lpBinaryPathName).eq_ignore_ascii_case(&command_line(executable)?)
            || (*config).dwServiceType != SERVICE_WIN32_OWN_PROCESS
            || !string_at((*config).lpServiceStartName).eq_ignore_ascii_case("LocalSystem")
        {
            return Err(io::Error::other(
                "An unexpected service configuration exists; it was left untouched",
            ));
        }
    }
    Ok(())
}

fn status(service: SC_HANDLE) -> io::Result<SERVICE_STATUS_PROCESS> {
    unsafe {
        let mut status: SERVICE_STATUS_PROCESS = zeroed();
        let mut size = 0;
        if QueryServiceStatusEx(
            service,
            SC_STATUS_PROCESS_INFO,
            (&mut status as *mut SERVICE_STATUS_PROCESS).cast(),
            size_of::<SERVICE_STATUS_PROCESS>() as u32,
            &mut size,
        ) == 0
        {
            return Err(io::Error::last_os_error());
        }
        Ok(status)
    }
}

fn state(service: SC_HANDLE) -> io::Result<u32> {
    Ok(status(service)?.dwCurrentState)
}

pub(super) fn is_stopped() -> Option<bool> {
    (|| -> io::Result<bool> {
        unsafe {
            let manager = ServiceHandle::new(OpenSCManagerW(null(), null(), SC_MANAGER_CONNECT))?;
            let handle = OpenServiceW(manager.0, wide(SERVICE_NAME).as_ptr(), SERVICE_QUERY_STATUS);
            if handle.is_null() && GetLastError() == ERROR_SERVICE_DOES_NOT_EXIST {
                return Ok(true);
            }
            let service = ServiceHandle::new(handle)?;
            Ok(state(service.0)? == SERVICE_STOPPED)
        }
    })()
    .ok()
}

fn active_process_id(status: &SERVICE_STATUS_PROCESS) -> Option<u32> {
    (status.dwProcessId != 0
        && matches!(
            status.dwCurrentState,
            SERVICE_RUNNING | SERVICE_PAUSE_PENDING | SERVICE_PAUSED | SERVICE_CONTINUE_PENDING
        ))
    .then_some(status.dwProcessId)
}

fn wait_state(service: SC_HANDLE, expected: u32) -> io::Result<()> {
    let deadline = Instant::now() + Duration::from_secs(15);
    loop {
        let actual = state(service)?;
        if actual == expected {
            return Ok(());
        }
        if expected == SERVICE_RUNNING && actual == SERVICE_STOPPED {
            return Err(io::Error::other(
                "The service stopped before becoming ready",
            ));
        }
        if Instant::now() >= deadline {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                "Timed out waiting for the service",
            ));
        }
        std::thread::sleep(Duration::from_millis(100));
    }
}

fn stop(service: SC_HANDLE) -> io::Result<()> {
    let before = status(service)?;
    if before.dwCurrentState == SERVICE_STOPPED {
        return Ok(());
    }
    let process = if let Some(pid) = active_process_id(&before) {
        let handle = unsafe { OpenProcess(PROCESS_SYNCHRONIZE, 0, pid) };
        if handle.is_null() {
            let error = io::Error::last_os_error();
            if error.raw_os_error() != Some(ERROR_INVALID_PARAMETER as i32) {
                return Err(error);
            }
            None
        } else {
            Some(unsafe { owned(handle)? })
        }
    } else {
        None
    };
    match before.dwCurrentState {
        SERVICE_STOP_PENDING => {}
        _ => unsafe {
            let mut status = zeroed();
            if ControlService(service, SERVICE_CONTROL_STOP, &mut status) == 0
                && GetLastError() != ERROR_SERVICE_NOT_ACTIVE
            {
                return Err(io::Error::last_os_error());
            }
        },
    }
    wait_state(service, SERVICE_STOPPED)?;
    if let Some(process) = process {
        if unsafe { WaitForSingleObject(process.as_raw_handle(), 15000) } != WAIT_OBJECT_0 {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                "The service reported stopped but its process has not exited",
            ));
        }
    }
    Ok(())
}

pub(super) fn manage(action: &str, executable: &Path) -> io::Result<()> {
    let installing = action == "install";
    let starting = action == "start";
    unsafe {
        let manager = ServiceHandle::new(OpenSCManagerW(
            null(),
            null(),
            SC_MANAGER_CONNECT
                | if installing {
                    SC_MANAGER_CREATE_SERVICE
                } else {
                    0
                },
        ))?;
        let name = wide(SERVICE_NAME);
        let rights = SERVICE_QUERY_CONFIG
            | SERVICE_QUERY_STATUS
            | SERVICE_STOP
            | if starting { SERVICE_START } else { 0 }
            | if installing {
                SERVICE_START | SERVICE_CHANGE_CONFIG | WRITE_DAC
            } else if action == "remove" {
                DELETE
            } else {
                0
            };
        let mut created = false;
        let mut service = OpenServiceW(manager.0, name.as_ptr(), rights);
        if service.is_null() {
            if GetLastError() != ERROR_SERVICE_DOES_NOT_EXIST {
                return Err(io::Error::last_os_error());
            }
            if starting {
                return Err(io::Error::other(
                    "The Windows service is missing. Repair the installation.",
                ));
            }
            if !installing {
                return Ok(());
            }
            service = CreateServiceW(
                manager.0,
                name.as_ptr(),
                wide(display_name()).as_ptr(),
                rights | DELETE,
                SERVICE_WIN32_OWN_PROCESS,
                SERVICE_DEMAND_START,
                SERVICE_ERROR_NORMAL,
                wide(command_line(executable)?).as_ptr(),
                null(),
                null_mut(),
                null(),
                null(),
                null(),
            );
            created = true;
        }
        let service = ServiceHandle::new(service)?;
        verify_configuration(service.0, executable)?;
        if starting {
            if state(service.0)? == SERVICE_STOP_PENDING {
                wait_state(service.0, SERVICE_STOPPED)?;
            }
            if StartServiceW(service.0, 0, null()) == 0
                && GetLastError() != ERROR_SERVICE_ALREADY_RUNNING
            {
                return Err(io::Error::last_os_error());
            }
            wait_state(service.0, SERVICE_RUNNING)?;
            if super::probe()?.version != super::VERSION {
                return Err(io::Error::other(
                    "Service version does not match the client. Repair the installation.",
                ));
            }
            return Ok(());
        }
        if !installing {
            stop(service.0)?;
            if action == "remove" && DeleteService(service.0) == 0 {
                return Err(io::Error::last_os_error());
            }
            return Ok(());
        }
        let result = (|| {
            super::authorization::enroll(&super::service_root()?)?;
            super::runtime::enroll(&super::service_root()?)?;
            let acl = SecurityDescriptor::new("D:P(A;;GA;;;SY)(A;;GA;;;BA)")?;
            if SetServiceObjectSecurity(service.0, DACL_SECURITY_INFORMATION, acl.as_ptr()) == 0 {
                return Err(io::Error::last_os_error());
            }
            if ChangeServiceConfigW(
                service.0,
                SERVICE_NO_CHANGE,
                SERVICE_DEMAND_START,
                SERVICE_NO_CHANGE,
                null(),
                null(),
                null_mut(),
                null(),
                null(),
                null(),
                null(),
            ) == 0
            {
                return Err(io::Error::last_os_error());
            }
            let mut description_text =
                wide("AORA Connect service foundation. VPN control remains in the desktop client.");
            let mut description = SERVICE_DESCRIPTIONW {
                lpDescription: description_text.as_mut_ptr(),
            };
            if ChangeServiceConfig2W(
                service.0,
                SERVICE_CONFIG_DESCRIPTION,
                (&mut description as *mut SERVICE_DESCRIPTIONW).cast(),
            ) == 0
            {
                return Err(io::Error::last_os_error());
            }
            if state(service.0)? == SERVICE_STOP_PENDING {
                wait_state(service.0, SERVICE_STOPPED)?;
            }
            if StartServiceW(service.0, 0, null()) == 0
                && GetLastError() != ERROR_SERVICE_ALREADY_RUNNING
            {
                return Err(io::Error::last_os_error());
            }
            wait_state(service.0, SERVICE_RUNNING)?;
            let health = super::probe()?;
            if health.version != super::VERSION {
                return Err(io::Error::other(
                    "The running service version does not match the installer",
                ));
            }
            Ok(())
        })();
        if created && result.is_err() {
            let _ = stop(service.0);
            let _ = DeleteService(service.0);
        }
        result
    }
}

fn display_name() -> String {
    #[cfg(feature = "service-scm-fixture")]
    return format!(
        "AORA Connect Service Test {}",
        env!("AORA_SERVICE_FIXTURE_ID")
    );
    #[cfg(not(feature = "service-scm-fixture"))]
    return "AORA Connect Service".into();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn service_image_path_quotes_spaces_and_has_one_fixed_argument() {
        assert_eq!(
            command_line(Path::new(
                r"C:\Program Files\AORAConnect\app\aoravpn_service.exe"
            ))
            .unwrap(),
            "\"C:\\Program Files\\AORAConnect\\app\\aoravpn_service.exe\" run"
        );
    }

    #[test]
    fn pending_and_stopped_statuses_do_not_supply_a_process_identity() {
        for state in [SERVICE_START_PENDING, SERVICE_STOP_PENDING, SERVICE_STOPPED] {
            let status = SERVICE_STATUS_PROCESS {
                dwCurrentState: state,
                dwProcessId: 123,
                ..unsafe { zeroed() }
            };
            assert_eq!(active_process_id(&status), None);
        }
        let mut status = SERVICE_STATUS_PROCESS {
            dwCurrentState: SERVICE_RUNNING,
            dwProcessId: 123,
            ..unsafe { zeroed() }
        };
        assert_eq!(active_process_id(&status), Some(123));
        status.dwProcessId = 0;
        assert_eq!(active_process_id(&status), None);
    }
}
