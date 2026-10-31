// SPDX-License-Identifier: GPL-3.0-or-later
use crate::{owned, wide};
use std::{
    io,
    mem::{size_of, zeroed},
    os::windows::io::{AsRawHandle, OwnedHandle},
    path::Path,
    ptr::{null, null_mut},
    time::{Duration, Instant},
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Authorization::*, *},
    Storage::FileSystem::*,
    System::{Pipes::*, Threading::*, IO::*},
};

#[cfg(test)]
pub const SERVICE_PIPE_ACL: &str = "D:P(A;;FA;;;SY)(A;;FA;;;BA)";
pub(super) const MAX_FRAME: usize = 512 * 1024;
const TIMEOUT: Duration = Duration::from_secs(2);

pub(super) struct SecurityDescriptor(PSECURITY_DESCRIPTOR);

impl SecurityDescriptor {
    pub fn new(sddl: &str) -> io::Result<Self> {
        let mut descriptor = null_mut();
        if unsafe {
            ConvertStringSecurityDescriptorToSecurityDescriptorW(
                wide(sddl).as_ptr(),
                1,
                &mut descriptor,
                null_mut(),
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        Ok(Self(descriptor))
    }

    pub fn as_ptr(&self) -> PSECURITY_DESCRIPTOR {
        self.0
    }
}

impl Drop for SecurityDescriptor {
    fn drop(&mut self) {
        unsafe {
            LocalFree(self.0);
        }
    }
}

fn transfer(
    pipe: HANDLE,
    stop: HANDLE,
    deadline: Instant,
    operation: impl FnOnce(*mut u32, *mut OVERLAPPED) -> BOOL,
) -> io::Result<u32> {
    unsafe {
        if WaitForSingleObject(stop, 0) == WAIT_OBJECT_0 {
            return Err(io::Error::new(
                io::ErrorKind::Interrupted,
                "Service is stopping",
            ));
        }
        let event = owned(CreateEventW(null(), 1, 0, null()))?;
        let mut overlapped: OVERLAPPED = zeroed();
        overlapped.hEvent = event.as_raw_handle();
        let mut bytes = 0;
        if operation(&mut bytes, &mut overlapped) != 0 {
            return Ok(bytes);
        }
        let error = GetLastError();
        if error != ERROR_IO_PENDING {
            return Err(io::Error::from_raw_os_error(error as i32));
        }
        let remaining = deadline
            .saturating_duration_since(Instant::now())
            .as_millis()
            .min(u32::MAX as u128) as u32;
        let handles = [stop, event.as_raw_handle()];
        let wait = WaitForMultipleObjects(2, handles.as_ptr(), 0, remaining);
        if wait == WAIT_OBJECT_0 + 1 {
            if GetOverlappedResult(pipe, &overlapped, &mut bytes, 0) == 0 {
                return Err(io::Error::last_os_error());
            }
            return Ok(bytes);
        }
        CancelIoEx(pipe, &overlapped);
        let _ = GetOverlappedResult(pipe, &overlapped, &mut bytes, 1);
        Err(io::Error::new(
            if wait == WAIT_OBJECT_0 {
                io::ErrorKind::Interrupted
            } else {
                io::ErrorKind::TimedOut
            },
            "Service communication was cancelled or timed out",
        ))
    }
}

fn read_exact(
    pipe: HANDLE,
    stop: HANDLE,
    deadline: Instant,
    mut bytes: &mut [u8],
) -> io::Result<()> {
    while !bytes.is_empty() {
        let read = transfer(pipe, stop, deadline, |count, overlapped| unsafe {
            ReadFile(
                pipe,
                bytes.as_mut_ptr(),
                bytes.len() as u32,
                count,
                overlapped,
            )
        })? as usize;
        if read == 0 {
            return Err(io::Error::new(
                io::ErrorKind::UnexpectedEof,
                "Service channel closed",
            ));
        }
        bytes = &mut bytes[read..];
    }
    Ok(())
}

fn read_frame(pipe: HANDLE, stop: HANDLE, deadline: Instant) -> io::Result<Vec<u8>> {
    let mut length = [0; 4];
    read_exact(pipe, stop, deadline, &mut length)?;
    let length = u32::from_le_bytes(length) as usize;
    if length == 0 || length > MAX_FRAME {
        return Err(io::Error::other("Service frame exceeds its size limit"));
    }
    let mut frame = vec![0; length];
    read_exact(pipe, stop, deadline, &mut frame)?;
    Ok(frame)
}

fn write_bytes(pipe: HANDLE, stop: HANDLE, deadline: Instant, mut bytes: &[u8]) -> io::Result<()> {
    while !bytes.is_empty() {
        let written = transfer(pipe, stop, deadline, |count, overlapped| unsafe {
            WriteFile(pipe, bytes.as_ptr(), bytes.len() as u32, count, overlapped)
        })? as usize;
        if written == 0 {
            return Err(io::Error::new(
                io::ErrorKind::WriteZero,
                "Service channel closed",
            ));
        }
        bytes = &bytes[written..];
    }
    Ok(())
}

fn write_frame(pipe: HANDLE, stop: HANDLE, deadline: Instant, bytes: &[u8]) -> io::Result<()> {
    if bytes.is_empty() || bytes.len() > MAX_FRAME {
        return Err(io::Error::other("Service frame exceeds its size limit"));
    }
    let mut frame = (bytes.len() as u32).to_le_bytes().to_vec();
    frame.extend(bytes);
    write_bytes(pipe, stop, deadline, &frame)
}

pub(super) struct Server {
    pipe: OwnedHandle,
}

impl Server {
    pub fn new(name: &str, sddl: &str) -> io::Result<Self> {
        let descriptor = SecurityDescriptor::new(sddl)?;
        let security = SECURITY_ATTRIBUTES {
            nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
            lpSecurityDescriptor: descriptor.as_ptr(),
            bInheritHandle: 0,
        };
        let pipe = unsafe {
            owned(CreateNamedPipeW(
                wide(name).as_ptr(),
                PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED | FILE_FLAG_FIRST_PIPE_INSTANCE,
                PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT | PIPE_REJECT_REMOTE_CLIENTS,
                1,
                MAX_FRAME as u32 + 4,
                MAX_FRAME as u32 + 4,
                2000,
                &security,
            ))?
        };
        Ok(Self { pipe })
    }

    #[cfg(any(test, feature = "service-fixture"))]
    pub fn serve(self, stop: HANDLE) -> io::Result<()> {
        self.serve_with(stop, super::reply)
    }

    #[cfg(any(test, feature = "service-fixture"))]
    pub fn serve_with(
        self,
        stop: HANDLE,
        mut reply: impl FnMut(&[u8]) -> Vec<u8>,
    ) -> io::Result<()> {
        self.serve_authenticated(stop, |_, bytes| reply(bytes))
    }

    pub fn serve_authenticated(
        self,
        stop: HANDLE,
        mut reply: impl FnMut(&super::identity::Peer, &[u8]) -> Vec<u8>,
    ) -> io::Result<()> {
        let pipe = self.pipe.as_raw_handle();
        loop {
            let connected = transfer(
                pipe,
                stop,
                Instant::now() + Duration::from_secs(60),
                |_, overlapped| unsafe {
                    let result = ConnectNamedPipe(pipe, overlapped);
                    if result == 0 && GetLastError() == ERROR_PIPE_CONNECTED {
                        1
                    } else {
                        result
                    }
                },
            );
            match connected {
                Err(error) if error.kind() == io::ErrorKind::Interrupted => return Ok(()),
                Err(error)
                    if error.kind() == io::ErrorKind::TimedOut
                        || matches!(error.raw_os_error(), Some(109 | 232 | 233)) =>
                {
                    unsafe {
                        DisconnectNamedPipe(pipe);
                    }
                    continue;
                }
                Err(error) => return Err(error),
                Ok(_) => {}
            }
            let deadline = Instant::now() + TIMEOUT;
            let result = (|| {
                let request = read_frame(pipe, stop, deadline)?;
                let response = match super::identity::client(pipe) {
                    Ok(peer) => reply(&peer, &request),
                    Err(error) => {
                        #[cfg(test)]
                        eprintln!("Pipe client identification failed: {error}");
                        let _ = error;
                        br#"{"protocol":1,"ok":false,"error":"access_denied"}"#.to_vec()
                    }
                };
                write_frame(pipe, stop, deadline, &response)?;
                let mut acknowledgement = [0];
                read_exact(pipe, stop, deadline, &mut acknowledgement)
            })();
            unsafe {
                DisconnectNamedPipe(pipe);
            }
            if result.is_err() && unsafe { WaitForSingleObject(stop, 0) } == WAIT_OBJECT_0 {
                return Ok(());
            }
        }
    }
}

fn verify_server(pipe: HANDLE, expected: &Path) -> io::Result<()> {
    unsafe {
        let mut pid = 0;
        if GetNamedPipeServerProcessId(pipe, &mut pid) == 0 {
            return Err(io::Error::last_os_error());
        }
        let process = match owned(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid)) {
            Ok(process) => process,
            Err(error) => {
                #[cfg(not(feature = "service-fixture"))]
                if error.raw_os_error() == Some(ERROR_ACCESS_DENIED as i32)
                    && expected.canonicalize()? == super::installed_executable()?.canonicalize()?
                {
                    return verify_system_pipe(pipe);
                }
                return Err(error);
            }
        };
        let mut name = vec![0; 32768];
        let mut length = name.len() as u32;
        if QueryFullProcessImageNameW(process.as_raw_handle(), 0, name.as_mut_ptr(), &mut length)
            == 0
        {
            return Err(io::Error::last_os_error());
        }
        let actual = std::path::PathBuf::from(String::from_utf16_lossy(&name[..length as usize]));
        if actual.canonicalize()? != expected.canonicalize()? {
            return Err(io::Error::other(
                "The service channel belongs to an unexpected executable",
            ));
        }
        Ok(())
    }
}

#[cfg(any(test, not(feature = "service-fixture")))]
fn verify_system_pipe(pipe: HANDLE) -> io::Result<()> {
    use windows_sys::Win32::System::SystemServices::{
        ACCESS_ALLOWED_ACE_TYPE, ACCESS_DENIED_ACE_TYPE,
    };
    unsafe {
        let mut session = u32::MAX;
        if GetNamedPipeServerSessionId(pipe, &mut session) == 0 || session != 0 {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "The service pipe is not in the system session",
            ));
        }
        let mut owner = null_mut();
        let mut dacl = null_mut();
        let mut descriptor = null_mut();
        let code = GetSecurityInfo(
            pipe,
            SE_KERNEL_OBJECT,
            OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
            &mut owner,
            null_mut(),
            &mut dacl,
            null_mut(),
            &mut descriptor,
        );
        if code != ERROR_SUCCESS {
            return Err(io::Error::from_raw_os_error(code as i32));
        }
        let result = (|| {
            if IsWellKnownSid(owner, WinLocalSystemSid) == 0 || dacl.is_null() {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    "The service pipe is not owned by SYSTEM",
                ));
            }
            for index in 0..(*dacl).AceCount as u32 {
                let mut ace = null_mut();
                if GetAce(dacl, index, &mut ace) == 0 {
                    return Err(io::Error::last_os_error());
                }
                let header = &*(ace as *const ACE_HEADER);
                if header.AceType == ACCESS_DENIED_ACE_TYPE as u8 {
                    continue;
                }
                if header.AceType != ACCESS_ALLOWED_ACE_TYPE as u8
                    || header.AceFlags & INHERIT_ONLY_ACE as u8 != 0
                {
                    return Err(io::Error::new(
                        io::ErrorKind::PermissionDenied,
                        "Unexpected service pipe access rule",
                    ));
                }
                let entry = &*(ace as *const ACCESS_ALLOWED_ACE);
                let sid = (&entry.SidStart as *const u32).cast_mut().cast();
                let trusted = IsWellKnownSid(sid, WinLocalSystemSid) != 0
                    || IsWellKnownSid(sid, WinBuiltinAdministratorsSid) != 0;
                if !trusted && entry.Mask & !super::identity::CLIENT_RIGHTS != 0 {
                    return Err(io::Error::new(
                        io::ErrorKind::PermissionDenied,
                        "The service pipe can be replaced by an ordinary account",
                    ));
                }
            }
            Ok(())
        })();
        LocalFree(descriptor);
        result
    }
}

fn connect(name: &str, deadline: Instant) -> io::Result<OwnedHandle> {
    loop {
        let handle = unsafe {
            CreateFileW(
                wide(name).as_ptr(),
                super::identity::CLIENT_RIGHTS,
                0,
                null(),
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED | SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION,
                null_mut(),
            )
        };
        if handle != INVALID_HANDLE_VALUE {
            return unsafe { owned(handle) };
        }
        let error = io::Error::last_os_error();
        if error.raw_os_error() != Some(ERROR_PIPE_BUSY as i32) || Instant::now() >= deadline {
            return Err(error);
        }
        std::thread::sleep(Duration::from_millis(10));
    }
}

pub(super) fn request(name: &str, expected: &Path, bytes: &[u8]) -> io::Result<Vec<u8>> {
    let deadline = Instant::now() + TIMEOUT;
    let pipe = connect(name, deadline)?;
    verify_server(pipe.as_raw_handle(), expected)?;
    let stop = unsafe { owned(CreateEventW(null(), 1, 0, null()))? };
    write_frame(pipe.as_raw_handle(), stop.as_raw_handle(), deadline, bytes)?;
    let reply = read_frame(pipe.as_raw_handle(), stop.as_raw_handle(), deadline)?;
    write_bytes(pipe.as_raw_handle(), stop.as_raw_handle(), deadline, &[1])?;
    Ok(reply)
}

#[cfg(any(test, feature = "service-fixture"))]
pub(super) fn fixture_acl() -> io::Result<String> {
    unsafe {
        let mut token = null_mut();
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token) == 0 {
            return Err(io::Error::last_os_error());
        }
        let token = owned(token)?;
        let mut size = 0;
        GetTokenInformation(token.as_raw_handle(), TokenUser, null_mut(), 0, &mut size);
        let mut storage = vec![0usize; (size as usize).div_ceil(size_of::<usize>())];
        if GetTokenInformation(
            token.as_raw_handle(),
            TokenUser,
            storage.as_mut_ptr().cast(),
            size,
            &mut size,
        ) == 0
        {
            return Err(io::Error::last_os_error());
        }
        let user = &*(storage.as_ptr() as *const TOKEN_USER);
        let mut text = null_mut();
        if ConvertSidToStringSidW(user.User.Sid, &mut text) == 0 {
            return Err(io::Error::last_os_error());
        }
        let mut length = 0;
        while *text.add(length) != 0 {
            length += 1;
        }
        let sid = String::from_utf16_lossy(std::slice::from_raw_parts(text, length));
        LocalFree(text.cast());
        Ok(format!("D:P(A;;FA;;;SY)(A;;FA;;;{sid})"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    static SERIAL: AtomicUsize = AtomicUsize::new(0);

    fn fixture() -> (String, OwnedHandle, std::thread::JoinHandle<io::Result<()>>) {
        let name = format!(
            r"\\.\pipe\AORAConnectService-Unit-{}-{}",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        );
        let server = Server::new(&name, &fixture_acl().unwrap()).unwrap();
        let stop = unsafe { owned(CreateEventW(null(), 1, 0, null())).unwrap() };
        let signal = stop.try_clone().unwrap();
        let thread = std::thread::spawn(move || server.serve(signal.as_raw_handle()));
        (name, stop, thread)
    }

    #[test]
    fn authenticated_requests_use_the_windows_token_and_revert_before_dispatch() {
        let expected = super::super::identity::current().unwrap();
        let name = format!(
            r"\\.\pipe\AORAConnectService-Identity-{}-{}",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        );
        let server = Server::new(&name, &fixture_acl().unwrap()).unwrap();
        let stop = unsafe { owned(CreateEventW(null(), 1, 0, null())).unwrap() };
        let signal = stop.try_clone().unwrap();
        let thread = std::thread::spawn(move || {
            server.serve_authenticated(signal.as_raw_handle(), |peer, _| {
                assert_eq!(peer.sid, expected.sid);
                assert_eq!(peer.session, expected.session);
                assert_eq!(peer.elevated_admin, expected.elevated_admin);
                unsafe {
                    let mut token = null_mut();
                    assert_eq!(
                        OpenThreadToken(GetCurrentThread(), TOKEN_QUERY, 1, &mut token),
                        0
                    );
                    assert_eq!(GetLastError(), ERROR_NO_TOKEN);
                }
                br#"{"authenticated":true}"#.to_vec()
            })
        });
        let result = request(
            &name,
            &std::env::current_exe().unwrap(),
            br#"{"user_sid":"S-1-5-18","elevated_admin":true}"#,
        );
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
        assert_eq!(result.unwrap(), br#"{"authenticated":true}"#);
    }

    #[test]
    fn restricted_clients_are_denied_by_windows_or_by_the_service() {
        let expected = super::super::identity::current().unwrap();
        let name = format!(
            r"\\.\pipe\AORAConnectService-Restricted-{}-{}",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        );
        let server = Server::new(&name, &fixture_acl().unwrap()).unwrap();
        let stop = unsafe { owned(CreateEventW(null(), 1, 0, null())).unwrap() };
        let signal = stop.try_clone().unwrap();
        let thread = std::thread::spawn(move || {
            server.serve_authenticated(signal.as_raw_handle(), |peer, _| {
                assert_eq!(peer.sid, expected.sid);
                assert!(peer.restricted);
                assert!(!peer.eligible());
                br#"{"denied":true}"#.to_vec()
            })
        });
        let result = unsafe {
            let mut token = null_mut();
            assert_ne!(
                OpenProcessToken(
                    GetCurrentProcess(),
                    TOKEN_QUERY | TOKEN_DUPLICATE | TOKEN_IMPERSONATE,
                    &mut token
                ),
                0
            );
            let token = owned(token).unwrap();
            let mut size = 0;
            GetTokenInformation(token.as_raw_handle(), TokenUser, null_mut(), 0, &mut size);
            let mut user = vec![0usize; (size as usize).div_ceil(size_of::<usize>())];
            assert_ne!(
                GetTokenInformation(
                    token.as_raw_handle(),
                    TokenUser,
                    user.as_mut_ptr().cast(),
                    size,
                    &mut size
                ),
                0
            );
            let user = &*(user.as_ptr() as *const TOKEN_USER);
            let sid = SID_AND_ATTRIBUTES {
                Sid: user.User.Sid,
                Attributes: 0,
            };
            let mut restricted = null_mut();
            assert_ne!(
                CreateRestrictedToken(
                    token.as_raw_handle(),
                    0,
                    0,
                    null(),
                    0,
                    null(),
                    1,
                    &sid,
                    &mut restricted
                ),
                0
            );
            let restricted = owned(restricted).unwrap();
            assert_ne!(ImpersonateLoggedOnUser(restricted.as_raw_handle()), 0);
            let result = request(&name, &std::env::current_exe().unwrap(), b"{}");
            assert_ne!(RevertToSelf(), 0);
            SetEvent(stop.as_raw_handle());
            result
        };
        thread.join().unwrap().unwrap();
        match result {
            Ok(reply) => assert_eq!(reply, br#"{"denied":true}"#),
            Err(error) => assert_eq!(error.kind(), io::ErrorKind::PermissionDenied),
        }
    }

    #[test]
    fn pipe_round_trip_validates_server_and_recovers_after_bad_requests() {
        let (name, stop, thread) = fixture();
        let executable = std::env::current_exe().unwrap();
        for bytes in [
            b"not json".as_slice(),
            br#"{"protocol":1,"command":"health"}"#,
        ] {
            let result = request(&name, &executable, bytes).unwrap();
            let health: super::super::Health = serde_json::from_slice(&result).unwrap();
            assert_eq!(health.error.is_some(), bytes == b"not json");
        }
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
    }

    #[test]
    fn stop_cancels_idle_and_incomplete_client_io() {
        for connect_client in [false, true] {
            let (name, stop, thread) = fixture();
            let _client = connect_client.then(|| connect(&name, Instant::now() + TIMEOUT).unwrap());
            std::thread::sleep(Duration::from_millis(30));
            let began = Instant::now();
            unsafe {
                SetEvent(stop.as_raw_handle());
            }
            thread.join().unwrap().unwrap();
            assert!(began.elapsed() < Duration::from_secs(1));
        }
    }

    #[test]
    fn wrong_server_identity_is_rejected() {
        let (name, stop, thread) = fixture();
        let error =
            request(&name, Path::new(r"C:\Windows\System32\notepad.exe"), b"{}").unwrap_err();
        assert!(error.to_string().contains("unexpected executable"));
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
    }

    #[test]
    fn first_instance_reservation_blocks_duplicate_servers() {
        let (name, stop, thread) = fixture();
        assert!(Server::new(&name, &fixture_acl().unwrap()).is_err());
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
    }

    #[test]
    fn an_ordinary_process_cannot_forge_a_system_owned_service_pipe() {
        if super::super::identity::current().unwrap().privileged() {
            return;
        }
        let name = format!(
            r"\\.\pipe\AORAConnectService-Forged-{}-{}",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        );
        let acl = format!("O:SYG:SY{}", fixture_acl().unwrap());
        assert!(Server::new(&name, &acl).is_err());
        let (name, stop, thread) = fixture();
        let pipe = connect(&name, Instant::now() + TIMEOUT).unwrap();
        assert!(verify_system_pipe(pipe.as_raw_handle()).is_err());
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
    }

    #[test]
    fn anonymous_clients_are_denied_by_the_production_acl() {
        let name = format!(
            r"\\.\pipe\AORAConnectService-Acl-{}-{}",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        );
        let server = Server::new(&name, SERVICE_PIPE_ACL).unwrap();
        let stop = unsafe { owned(CreateEventW(null(), 1, 0, null())).unwrap() };
        let signal = stop.try_clone().unwrap();
        let thread = std::thread::spawn(move || server.serve(signal.as_raw_handle()));
        unsafe {
            assert_ne!(ImpersonateAnonymousToken(GetCurrentThread()), 0);
            let client = CreateFileW(
                wide(&name).as_ptr(),
                GENERIC_READ | GENERIC_WRITE,
                0,
                null(),
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                null_mut(),
            );
            let code = GetLastError();
            let reverted = RevertToSelf();
            if client != INVALID_HANDLE_VALUE {
                CloseHandle(client);
            }
            SetEvent(stop.as_raw_handle());
            thread.join().unwrap().unwrap();
            assert_ne!(reverted, 0);
            assert_eq!(client, INVALID_HANDLE_VALUE);
            assert_eq!(code, ERROR_ACCESS_DENIED);
        }
    }

    #[test]
    fn stalled_clients_time_out_without_blocking_the_next_health_check() {
        let (name, stop, thread) = fixture();
        let client = connect(&name, Instant::now() + TIMEOUT).unwrap();
        write_bytes(
            client.as_raw_handle(),
            stop.as_raw_handle(),
            Instant::now() + TIMEOUT,
            &[64, 0, 0, 0, b'{'],
        )
        .unwrap();
        std::thread::sleep(TIMEOUT + Duration::from_millis(100));
        assert!(request(
            &name,
            &std::env::current_exe().unwrap(),
            br#"{"protocol":1,"command":"health"}"#
        )
        .is_ok());
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
    }

    #[test]
    fn oversized_frames_are_disconnected_and_next_client_still_works() {
        let (name, stop, thread) = fixture();
        {
            let pipe = connect(&name, Instant::now() + TIMEOUT).unwrap();
            write_bytes(
                pipe.as_raw_handle(),
                stop.as_raw_handle(),
                Instant::now() + TIMEOUT,
                &((MAX_FRAME + 1) as u32).to_le_bytes(),
            )
            .unwrap();
            assert!(read_frame(
                pipe.as_raw_handle(),
                stop.as_raw_handle(),
                Instant::now() + TIMEOUT
            )
            .is_err());
        }
        assert!(request(
            &name,
            &std::env::current_exe().unwrap(),
            br#"{"protocol":1,"command":"health"}"#
        )
        .is_ok());
        unsafe {
            SetEvent(stop.as_raw_handle());
        }
        thread.join().unwrap().unwrap();
    }
}
