// SPDX-License-Identifier: GPL-3.0-or-later
use super::{
    identity::{self, Peer, CLIENT_RIGHTS},
    transport::SecurityDescriptor,
};
use crate::{owned, wide};
use serde::{Deserialize, Serialize};
use std::{
    fs,
    io::{self, Read, Write},
    mem::size_of,
    os::windows::fs::{MetadataExt, OpenOptionsExt},
    path::{Path, PathBuf},
    ptr::{null, null_mut},
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Authorization::*, *},
    Storage::FileSystem::*,
    System::{RemoteDesktop::*, SystemServices::*},
};

const FILE_NAME: &str = "service-access.json";

#[derive(Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub(super) struct Policy {
    version: u32,
    user_sid: String,
}

impl Policy {
    pub fn pipe_acl(&self) -> String {
        format!(
            "O:SYG:SYD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;0x{CLIENT_RIGHTS:08x};;;{})",
            self.user_sid
        )
    }
    pub fn permits(&self, peer: &Peer, command: &str) -> bool {
        if matches!(
            command,
            "settings.read"
                | "checks.open"
                | "checks.status"
                | "checks.close"
                | "settings.write"
                | "connection.status"
                | "connection.recover"
                | "connection.validate"
                | "connection.start"
                | "connection.confirm"
                | "connection.stop"
        ) {
            return peer.eligible() && (peer.sid == self.user_sid || peer.sid == "S-1-5-18");
        }
        peer.privileged()
            || (peer.eligible()
                && peer.sid == self.user_sid
                && matches!(command, "health" | "access"))
    }
    pub fn access_reply(&self, peer: &Peer, bytes: &[u8]) -> Vec<u8> {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct Request {
            protocol: u32,
            command: String,
        }
        let valid = serde_json::from_slice::<Request>(bytes)
            .is_ok_and(|r| r.protocol == 1 && r.command == "access");
        serde_json::to_vec(&serde_json::json!({
            "protocol": 1, "ok": valid,
            "access": { "owner": peer.sid == self.user_sid, "privileged": peer.privileged(),
                "settings": peer.eligible() && (peer.sid == self.user_sid || peer.sid == "S-1-5-18"), "runtime": peer.eligible() && (peer.sid == self.user_sid || peer.sid == "S-1-5-18") },
            "error": if valid { None } else { Some("invalid_request") }
        }))
        .unwrap()
    }
}

fn denied(message: &str) -> io::Error {
    io::Error::new(io::ErrorKind::PermissionDenied, message)
}

pub(super) fn protected(path: &Path) -> io::Result<()> {
    if fs::symlink_metadata(path)?.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(denied("Authorization storage must not contain links"));
    }
    unsafe {
        let mut owner = null_mut();
        let mut dacl = null_mut();
        let mut descriptor = null_mut();
        let code = GetNamedSecurityInfoW(
            wide(path).as_ptr(),
            SE_FILE_OBJECT,
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
        let check = (|| {
            let owner = identity::sid_text(owner)?;
            if !matches!(
                owner.as_str(),
                "S-1-5-18"
                    | "S-1-5-32-544"
                    | "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"
            ) || dacl.is_null()
            {
                return Err(denied(
                    "Authorization storage has an untrusted owner or access list",
                ));
            }
            for index in 0..(*dacl).AceCount as u32 {
                let mut ace = null_mut();
                if GetAce(dacl, index, &mut ace) == 0 {
                    return Err(io::Error::last_os_error());
                }
                let header = &*(ace as *const ACE_HEADER);
                if header.AceFlags & INHERIT_ONLY_ACE as u8 != 0
                    || header.AceType == ACCESS_DENIED_ACE_TYPE as u8
                {
                    continue;
                }
                if header.AceType != ACCESS_ALLOWED_ACE_TYPE as u8 {
                    return Err(denied("Unsupported authorization storage access rule"));
                }
                let allowed = &*(ace as *const ACCESS_ALLOWED_ACE);
                let sid = (&allowed.SidStart as *const u32).cast_mut().cast();
                let trusted = matches!(
                    identity::sid_text(sid)?.as_str(),
                    "S-1-5-18"
                        | "S-1-5-32-544"
                        | "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464"
                );
                let writes = FILE_WRITE_DATA
                    | FILE_APPEND_DATA
                    | FILE_WRITE_EA
                    | FILE_WRITE_ATTRIBUTES
                    | FILE_DELETE_CHILD
                    | DELETE
                    | WRITE_DAC
                    | WRITE_OWNER
                    | GENERIC_ALL
                    | GENERIC_WRITE;
                if !trusted && allowed.Mask & writes != 0 {
                    return Err(denied(
                        "An ordinary account can modify authorization storage",
                    ));
                }
            }
            Ok(())
        })();
        LocalFree(descriptor);
        check
    }
}

fn location(root: &Path) -> io::Result<PathBuf> {
    protected(root)?;
    protected(&root.join("settings"))?;
    Ok(root.join("settings").join(FILE_NAME))
}

pub(super) fn private_directory(root: &Path, name: &str) -> io::Result<fs::File> {
    use std::os::windows::io::AsRawHandle;
    if !matches!(name, "settings" | "runtime") {
        return Err(denied("Invalid protected directory"));
    }
    protected(root)?;
    let path = root.join(name);
    let handle = unsafe {
        CreateFileW(
            wide(&path).as_ptr(),
            READ_CONTROL | WRITE_DAC | FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            null(),
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT,
            null_mut(),
        )
    };
    let file = fs::File::from(unsafe { owned(handle)? });
    let metadata = file.metadata()?;
    if !metadata.is_dir() || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(denied("The protected directory must not be a link"));
    }
    unsafe {
        let mut owner = null_mut();
        let mut descriptor = null_mut();
        let code = GetSecurityInfo(
            file.as_raw_handle(),
            SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION,
            &mut owner,
            null_mut(),
            null_mut(),
            null_mut(),
            &mut descriptor,
        );
        if code != ERROR_SUCCESS {
            return Err(io::Error::from_raw_os_error(code as i32));
        }
        let owner = identity::sid_text(owner);
        LocalFree(descriptor);
        if !matches!(owner?.as_str(), "S-1-5-18" | "S-1-5-32-544") {
            return Err(denied(
                "The protected directory is not owned by the installation administrator",
            ));
        }
        let descriptor = SecurityDescriptor::new("D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)")?;
        let mut present = 0;
        let mut dacl = null_mut();
        let mut defaulted = 0;
        if GetSecurityDescriptorDacl(descriptor.as_ptr(), &mut present, &mut dacl, &mut defaulted)
            == 0
            || present == 0
            || dacl.is_null()
        {
            return Err(denied("Could not construct the directory access list"));
        }
        let code = SetSecurityInfo(
            file.as_raw_handle(),
            SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
            null_mut(),
            null_mut(),
            dacl,
            null_mut(),
        );
        if code != ERROR_SUCCESS {
            return Err(io::Error::from_raw_os_error(code as i32));
        }
    }
    Ok(file)
}

fn validate_sid(sid: &str) -> io::Result<()> {
    if !(sid.starts_with("S-1-5-21-") || sid.starts_with("S-1-12-1-"))
        || sid.len() > 184
        || !sid
            .bytes()
            .all(|v| v == b'S' || v == b'-' || v.is_ascii_digit())
    {
        return Err(denied(
            "The authorization owner must be a Windows user account",
        ));
    }
    unsafe {
        let mut value = null_mut();
        if ConvertStringSidToSidW(wide(sid).as_ptr(), &mut value) == 0 {
            return Err(io::Error::last_os_error());
        }
        let valid = identity::sid_text(value).is_ok_and(|canonical| canonical == sid);
        LocalFree(value);
        if !valid {
            return Err(denied("Invalid authorization owner"));
        }
    }
    Ok(())
}

pub(super) fn load(root: &Path) -> io::Result<Policy> {
    let path = location(root)?;
    protected(&path)?;
    let mut file = fs::OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(path)?;
    if file.metadata()?.len() > 4096
        || file.metadata()?.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0
    {
        return Err(denied("Invalid authorization file"));
    }
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)?;
    let policy: Policy = serde_json::from_slice(&bytes).map_err(io::Error::other)?;
    if policy.version != 1 {
        return Err(denied("Unsupported service authorization version"));
    }
    validate_sid(&policy.user_sid)?;
    Ok(policy)
}

fn session_text(session: u32, kind: WTS_INFO_CLASS) -> io::Result<String> {
    unsafe {
        let mut value = null_mut();
        let mut bytes = 0;
        if WTSQuerySessionInformationW(null_mut(), session, kind, &mut value, &mut bytes) == 0 {
            return Err(io::Error::last_os_error());
        }
        let result = if bytes < 2 || bytes > 65536 || bytes % 2 != 0 {
            Err(denied("Invalid interactive Windows session"))
        } else {
            let data = std::slice::from_raw_parts(value, bytes as usize / 2);
            let length = data.iter().position(|v| *v == 0).unwrap_or(data.len());
            Ok(String::from_utf16_lossy(&data[..length]))
        };
        WTSFreeMemory(value.cast());
        result
    }
}

fn session_user(session: u32) -> io::Result<String> {
    if session == 0 {
        return Err(denied(
            "Enroll the application from the intended user's signed-in Windows session",
        ));
    }
    let name = session_text(session, WTSUserName)?;
    let domain = session_text(session, WTSDomainName)?;
    if name.is_empty() {
        return Err(denied(
            "No signed-in Windows user is available for enrollment",
        ));
    }
    let account = if domain.is_empty() {
        name
    } else {
        format!("{domain}\\{name}")
    };
    unsafe {
        let mut size = 0;
        let mut domain_size = 0;
        let mut kind = 0;
        LookupAccountNameW(
            null(),
            wide(&account).as_ptr(),
            null_mut(),
            &mut size,
            null_mut(),
            &mut domain_size,
            &mut kind,
        );
        if GetLastError() != ERROR_INSUFFICIENT_BUFFER
            || size == 0
            || size > 65536
            || domain_size > 32768
        {
            return Err(denied("Could not resolve the signed-in Windows account"));
        }
        let mut sid = vec![0usize; (size as usize).div_ceil(size_of::<usize>())];
        let mut domain = vec![0u16; domain_size as usize];
        if LookupAccountNameW(
            null(),
            wide(&account).as_ptr(),
            sid.as_mut_ptr().cast(),
            &mut size,
            domain.as_mut_ptr(),
            &mut domain_size,
            &mut kind,
        ) == 0
        {
            return Err(io::Error::last_os_error());
        }
        if kind != SidTypeUser {
            return Err(denied(
                "The signed-in identity is not a Windows user account",
            ));
        }
        identity::sid_text(sid.as_mut_ptr().cast())
    }
}

pub(super) fn enroll(root: &Path) -> io::Result<Policy> {
    let peer = identity::current()?;
    if !peer.privileged() {
        return Err(denied(
            "Service enrollment requires administrator privileges",
        ));
    }
    protected(root)?;
    let settings = root.join("settings");
    if !settings.try_exists()? {
        fs::create_dir(&settings)?;
    }
    let candidate = settings.join(FILE_NAME);
    if candidate.try_exists()? {
        return load(root);
    }
    let _directory_guard = private_directory(root, "settings")?;
    let path = location(root)?;
    let user_sid = session_user(peer.session)?;
    validate_sid(&user_sid)?;
    let policy = Policy {
        version: 1,
        user_sid,
    };
    let descriptor = SecurityDescriptor::new("O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)")?;
    let security = SECURITY_ATTRIBUTES {
        nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
        lpSecurityDescriptor: descriptor.as_ptr(),
        bInheritHandle: 0,
    };
    let handle = unsafe {
        CreateFileW(
            wide(&path).as_ptr(),
            GENERIC_WRITE,
            0,
            &security,
            CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT,
            null_mut(),
        )
    };
    if handle == INVALID_HANDLE_VALUE {
        return Err(io::Error::last_os_error());
    }
    let mut file = fs::File::from(unsafe { owned(handle)? });
    let result = file
        .write_all(&serde_json::to_vec(&policy)?)
        .and_then(|_| file.sync_all());
    drop(file);
    if let Err(error) = result {
        let _ = fs::remove_file(&path);
        return Err(error);
    }
    load(root)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn owner() -> Peer {
        Peer {
            sid: "S-1-5-21-1-2-3-1001".into(),
            session: 1,
            elevated_admin: false,
            restricted: false,
            app_container: false,
            integrity: 8192,
        }
    }
    fn policy() -> Policy {
        Policy {
            version: 1,
            user_sid: owner().sid,
        }
    }

    #[test]
    fn ordinary_owner_gets_typed_connections_but_not_raw_core_commands() {
        let policy = policy();
        let owner = owner();
        for command in [
            "health",
            "access",
            "settings.read",
            "settings.write",
            "checks.open",
            "checks.status",
            "checks.close",
            "connection.status",
            "connection.recover",
            "connection.start",
            "connection.validate",
            "connection.confirm",
            "connection.stop",
        ] {
            assert!(policy.permits(&owner, command));
        }
        for command in [
            "status", "start", "validate", "recover", "stop", "confirm", "settings", "",
        ] {
            assert!(!policy.permits(&owner, command));
        }
        let mut other = owner.clone();
        other.sid = "S-1-5-21-1-2-3-1002".into();
        assert!(!policy.permits(&other, "health"));
        for elevated in [false, true] {
            other.elevated_admin = elevated;
            assert!(!policy.permits(&other, "settings.read"));
            assert!(!policy.permits(&other, "settings.write"));
            assert!(!policy.permits(&other, "connection.start"));
            assert!(!policy.permits(&other, "connection.status"));
            assert!(!policy.permits(&other, "checks.open"));
            assert!(!policy.permits(&other, "checks.close"));
        }
        let reply: serde_json::Value = serde_json::from_slice(&policy.access_reply(
            &owner,
            br#"{"protocol":1,"command":"access","user_sid":"S-1-5-18"}"#,
        ))
        .unwrap();
        assert_eq!(reply["ok"], false);
    }

    #[test]
    fn sandboxed_low_integrity_and_session_zero_clients_are_denied() {
        let policy = policy();
        for mutation in 0..4 {
            let mut peer = owner();
            peer.elevated_admin = true;
            match mutation {
                0 => peer.restricted = true,
                1 => peer.app_container = true,
                2 => peer.integrity = 4096,
                _ => peer.session = 0,
            }
            assert!(!policy.permits(&peer, "health"));
            assert!(!policy.permits(&peer, "start"));
            assert!(!policy.permits(&peer, "settings.read"));
            assert!(!policy.permits(&peer, "settings.write"));
            assert!(!policy.permits(&peer, "connection.start"));
            assert!(!policy.permits(&peer, "connection.status"));
            assert!(!policy.permits(&peer, "checks.open"));
        }
        let mut administrator = owner();
        administrator.elevated_admin = true;
        assert!(policy.permits(&administrator, "start"));
        administrator.sid = "S-1-5-18".into();
        administrator.session = 0;
        assert!(policy.permits(&administrator, "status"));
        assert!(policy.permits(&administrator, "settings.write"));
    }

    #[test]
    fn owner_cannot_create_pipe_instances_or_supply_an_acl_fragment() {
        assert_eq!(CLIENT_RIGHTS & FILE_CREATE_PIPE_INSTANCE, 0);
        for sid in [
            "S-1-1-0",
            "S-1-5-18",
            "S-1-5-32-544",
            "S-1-5-21-1)(A;;FA;;;WD)",
        ] {
            assert!(validate_sid(sid).is_err());
        }
        assert!(validate_sid(&owner().sid).is_ok());
    }
}
