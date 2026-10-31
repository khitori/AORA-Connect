// SPDX-License-Identifier: GPL-3.0-or-later
use crate::owned;
use std::{io, mem::size_of, os::windows::io::AsRawHandle, ptr::null_mut};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Authorization::*, *},
    Storage::FileSystem::{
        FILE_READ_ATTRIBUTES, FILE_READ_DATA, FILE_WRITE_DATA, READ_CONTROL, SYNCHRONIZE,
    },
    System::{Pipes::ImpersonateNamedPipeClient, SystemServices::*, Threading::*},
};

pub(super) const CLIENT_RIGHTS: u32 =
    FILE_READ_DATA | FILE_WRITE_DATA | FILE_READ_ATTRIBUTES | READ_CONTROL | SYNCHRONIZE;

#[derive(Clone, Debug)]
#[cfg_attr(feature = "service-fixture", allow(dead_code))]
pub(super) struct Peer {
    pub sid: String,
    pub session: u32,
    pub elevated_admin: bool,
    pub restricted: bool,
    pub app_container: bool,
    pub integrity: u32,
}

#[cfg(not(feature = "service-fixture"))]
impl Peer {
    pub fn eligible(&self) -> bool {
        !self.restricted
            && !self.app_container
            && self.integrity >= SECURITY_MANDATORY_MEDIUM_RID as u32
            && (self.session != 0 || self.sid == "S-1-5-18")
    }
    pub fn privileged(&self) -> bool {
        self.eligible() && (self.elevated_admin || self.sid == "S-1-5-18")
    }
}

fn information(token: HANDLE, kind: TOKEN_INFORMATION_CLASS) -> io::Result<Vec<usize>> {
    unsafe {
        let mut size = 0;
        GetTokenInformation(token, kind, null_mut(), 0, &mut size);
        if !matches!(GetLastError(), ERROR_INSUFFICIENT_BUFFER | ERROR_BAD_LENGTH)
            || size == 0
            || size > 262144
        {
            return Err(io::Error::other(format!(
                "Could not query the Windows client token (class {kind}, size {size}, error {})",
                GetLastError()
            )));
        }
        let mut result = vec![0usize; (size as usize).div_ceil(size_of::<usize>())];
        if GetTokenInformation(token, kind, result.as_mut_ptr().cast(), size, &mut size) == 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(result)
    }
}

pub(super) unsafe fn sid_text(sid: PSID) -> io::Result<String> {
    if IsValidSid(sid) == 0 {
        return Err(io::Error::other("Invalid Windows user identity"));
    }
    let mut text = null_mut();
    if ConvertSidToStringSidW(sid, &mut text) == 0 {
        return Err(io::Error::last_os_error());
    }
    let mut length = 0;
    while *text.add(length) != 0 {
        length += 1;
    }
    let result = String::from_utf16_lossy(std::slice::from_raw_parts(text, length));
    LocalFree(text.cast());
    Ok(result)
}

fn from_token(token: HANDLE) -> io::Result<Peer> {
    unsafe {
        let user = information(token, TokenUser)?;
        let sid = sid_text((*(user.as_ptr() as *const TOKEN_USER)).User.Sid)?;
        let session = information(token, TokenSessionId)?;
        let elevation = information(token, TokenElevation)?;
        let groups = information(token, TokenGroups)?;
        let groups = &*(groups.as_ptr() as *const TOKEN_GROUPS);
        let groups = std::slice::from_raw_parts(groups.Groups.as_ptr(), groups.GroupCount as usize);
        let admin = groups.iter().any(|group| {
            group.Attributes & SE_GROUP_ENABLED as u32 != 0
                && group.Attributes & SE_GROUP_USE_FOR_DENY_ONLY as u32 == 0
                && IsWellKnownSid(group.Sid, WinBuiltinAdministratorsSid) != 0
        });
        let app_container = information(token, TokenIsAppContainer)?;
        let integrity = information(token, TokenIntegrityLevel)?;
        let label = &*(integrity.as_ptr() as *const TOKEN_MANDATORY_LABEL);
        let count = *GetSidSubAuthorityCount(label.Label.Sid);
        if count == 0 {
            return Err(io::Error::other("Invalid Windows integrity label"));
        }
        Ok(Peer {
            sid,
            session: *(session.as_ptr() as *const u32),
            elevated_admin: admin
                && (*(elevation.as_ptr() as *const TOKEN_ELEVATION)).TokenIsElevated != 0,
            restricted: IsTokenRestricted(token) != 0,
            app_container: *(app_container.as_ptr() as *const u32) != 0,
            integrity: *GetSidSubAuthority(label.Label.Sid, (count - 1) as u32),
        })
    }
}

#[cfg_attr(feature = "service-fixture", allow(dead_code))]
pub(super) fn current() -> io::Result<Peer> {
    unsafe {
        let mut token = null_mut();
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token) == 0 {
            return Err(io::Error::last_os_error());
        }
        let token = owned(token)?;
        from_token(token.as_raw_handle())
    }
}

struct Revert;
impl Drop for Revert {
    fn drop(&mut self) {
        if unsafe { RevertToSelf() } == 0 {
            std::process::abort();
        }
    }
}

pub(super) fn client(pipe: HANDLE) -> io::Result<Peer> {
    unsafe {
        if ImpersonateNamedPipeClient(pipe) == 0 {
            return Err(io::Error::last_os_error());
        }
        let revert = Revert;
        let mut token = null_mut();
        if OpenThreadToken(GetCurrentThread(), TOKEN_QUERY, 1, &mut token) == 0 {
            return Err(io::Error::last_os_error());
        }
        let token = owned(token)?;
        let peer = from_token(token.as_raw_handle());
        drop(token);
        drop(revert);
        peer
    }
}
