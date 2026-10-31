// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]

use aora_windows_helpers::{owned, wide};
#[cfg(not(feature = "migration-fixture"))]
use aora_windows_helpers::installation_root;
use sha2::{Digest, Sha256};
use std::{
    fs, io,
    os::windows::{
        fs::{MetadataExt, OpenOptionsExt},
        io::AsRawHandle,
        process::CommandExt,
    },
    path::{Path, PathBuf},
    process::Command,
    time::{Duration, Instant},
};
use windows_sys::Win32::{
    Foundation::*,
    System::Threading::*,
};
#[cfg(not(feature = "migration-fixture"))]
use windows_sys::Win32::{System::Com::CoTaskMemFree, UI::{Shell::{FOLDERID_LocalAppData, SHGetKnownFolderPath}, WindowsAndMessaging::*}};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const SETTINGS: [&str; 3] = ["app-state.json", "language.json", "updates.json"];

fn roots() -> Result<(PathBuf, PathBuf)> {
    #[cfg(feature = "migration-fixture")]
    {
        let fixture = PathBuf::from(env!("AORA_MIGRATION_FIXTURE_ROOT"));
        return Ok((
            fixture.join("installed"),
            fixture.join("profile/Local/AORAConnect"),
        ));
    }
    #[cfg(not(feature = "migration-fixture"))]
    unsafe {
        let mut value = std::ptr::null_mut();
        if SHGetKnownFolderPath(&FOLDERID_LocalAppData, 0, std::ptr::null_mut(), &mut value) < 0 {
            return Err("Could not locate legacy user storage".into());
        }
        let mut length = 0;
        while *value.add(length) != 0 {
            length += 1;
        }
        let local = PathBuf::from(
            <std::ffi::OsString as std::os::windows::ffi::OsStringExt>::from_wide(
                std::slice::from_raw_parts(value, length),
            ),
        );
        CoTaskMemFree(value.cast());
        Ok((installation_root()?, local.join("AORAConnect")))
    }
}

fn reject_link(path: &Path) -> io::Result<()> {
    if fs::symlink_metadata(path)?.file_attributes() & 0x400 != 0 {
        return Err(io::Error::other(
            "Migration will not follow directory or file links",
        ));
    }
    Ok(())
}

fn remove_tree(path: &Path) -> io::Result<()> {
    if !path.try_exists()? {
        return Ok(());
    }
    reject_link(path)?;
    for entry in fs::read_dir(path)? {
        let path = entry?.path();
        reject_link(&path)?;
        if path.is_dir() {
            remove_tree(&path)?;
        } else {
            let metadata = fs::symlink_metadata(&path)?;
            if metadata.permissions().readonly() {
                let mut permissions = metadata.permissions();
                permissions.set_readonly(false);
                fs::set_permissions(&path, permissions)?;
            }
            fs::remove_file(path)?;
        }
    }
    fs::remove_dir(path)
}

fn runtime_idle(path: &Path) -> io::Result<bool> {
    if !path.try_exists()? {
        return Ok(true);
    }
    reject_link(path)?;
    for entry in fs::read_dir(path)? {
        let path = entry?.path();
        reject_link(&path)?;
        if path.is_dir() {
            if !runtime_idle(&path)? {
                return Ok(false);
            }
        } else if path
            .file_name()
            .is_some_and(|name| name == ".installer.lock")
        {
            match fs::OpenOptions::new()
                .read(true)
                .write(true)
                .share_mode(0)
                .open(&path)
            {
                Ok(lock) => drop(lock),
                Err(error) if matches!(error.raw_os_error(), Some(32 | 33)) => return Ok(false),
                Err(error) => return Err(error),
            }
        }
    }
    Ok(true)
}

fn wait_launcher(pid: u32) -> Result<()> {
    unsafe {
        let handle = OpenProcess(PROCESS_SYNCHRONIZE, 0, pid);
        if handle.is_null() {
            if GetLastError() == ERROR_INVALID_PARAMETER {
                return Ok(());
            }
            return Err(io::Error::last_os_error().into());
        }
        let process = owned(handle)?;
        if WaitForSingleObject(process.as_raw_handle(), 30000) != WAIT_OBJECT_0 {
            return Err("Legacy launcher did not exit; previous files were retained".into());
        }
    }
    Ok(())
}

type SettingsSnapshot = Option<Vec<(&'static str, Vec<u8>)>>;

fn matching_settings(root: &Path, legacy: &Path) -> Result<SettingsSnapshot> {
    reject_link(legacy)?;
    let old_settings = legacy.join("settings");
    let mut snapshot = Vec::new();
    if old_settings.try_exists()? {
        reject_link(&old_settings)?;
        for name in SETTINGS {
            let old = old_settings.join(name);
            if old.try_exists()? {
                reject_link(&old)?;
                let new = root.join("settings").join(name);
                let hash = Sha256::digest(fs::read(old)?).to_vec();
                if !new.try_exists()? || hash != Sha256::digest(fs::read(new)?).to_vec() {
                    return Ok(None);
                }
                snapshot.push((name, hash));
            }
        }
    }
    Ok(Some(snapshot))
}

fn cleanup(legacy: &Path, snapshot: SettingsSnapshot) -> Result<()> {
    if !legacy.try_exists()? {
        return Ok(());
    }
    reject_link(legacy)?;
    let old_settings = legacy.join("settings");
    for name in ["app", "cores", "runtime", "uninstall"] {
        remove_tree(&legacy.join(name))?;
    }
    if let Some(snapshot) = snapshot {
        for (name, expected_hash) in snapshot {
            let path = old_settings.join(name);
            if path.try_exists()? {
                reject_link(&path)?;
                if Sha256::digest(fs::read(&path)?).to_vec() == expected_hash {
                    fs::remove_file(path)?;
                }
            }
        }
        let _ = fs::remove_dir(old_settings);
    }
    let version = legacy.join("installed-version.txt");
    if version.try_exists()? {
        reject_link(&version)?;
        fs::remove_file(version)?;
    }
    let _ = fs::remove_dir(legacy);
    Ok(())
}

#[cfg(not(feature = "migration-fixture"))]
fn cleanup_registration(legacy: &Path) -> Result<()> {
    use windows_sys::Win32::System::Registry::*;
    use windows_sys::Win32::UI::Shell::FOLDERID_Programs;
    unsafe {
        let key = wide("Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{C9DE0FA9-DB41-4D08-B236-D7747D54C844}_is1");
        let value = wide("InstallLocation");
        let mut size = 0;
        if RegGetValueW(
            HKEY_CURRENT_USER,
            key.as_ptr(),
            value.as_ptr(),
            RRF_RT_REG_SZ,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            &mut size,
        ) != ERROR_SUCCESS
        {
            return Ok(());
        }
        let mut location = vec![0u16; size as usize / 2];
        if RegGetValueW(
            HKEY_CURRENT_USER,
            key.as_ptr(),
            value.as_ptr(),
            RRF_RT_REG_SZ,
            std::ptr::null_mut(),
            location.as_mut_ptr().cast(),
            &mut size,
        ) != ERROR_SUCCESS
        {
            return Ok(());
        }
        let length = location
            .iter()
            .position(|c| *c == 0)
            .unwrap_or(location.len());
        let location = String::from_utf16_lossy(&location[..length]);
        if !location
            .trim_end_matches('\\')
            .eq_ignore_ascii_case(&legacy.to_string_lossy())
        {
            return Ok(());
        }
        let result = RegDeleteTreeW(HKEY_CURRENT_USER, key.as_ptr());
        if result != ERROR_SUCCESS {
            return Err(io::Error::from_raw_os_error(result as i32).into());
        }
        let _ = RegDeleteTreeW(HKEY_CURRENT_USER, wide("Software\\AORAConnect").as_ptr());
        let mut programs = std::ptr::null_mut();
        if SHGetKnownFolderPath(&FOLDERID_Programs, 0, std::ptr::null_mut(), &mut programs) >= 0 {
            let mut length = 0;
            while *programs.add(length) != 0 {
                length += 1;
            }
            let path = PathBuf::from(
                <std::ffi::OsString as std::os::windows::ffi::OsStringExt>::from_wide(
                    std::slice::from_raw_parts(programs, length),
                ),
            );
            CoTaskMemFree(programs.cast());
            let shortcut = path.join("AORA Connect.lnk");
            if shortcut.try_exists()? {
                fs::remove_file(shortcut)?;
            }
        }
    }
    Ok(())
}

#[cfg(feature = "migration-fixture")]
fn cleanup_registration(_: &Path) -> Result<()> {
    Ok(())
}

fn start_verified_client(root: &Path) -> Result<()> {
    let name = format!(
        "Local\\AORAConnectMigrationReady-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_nanos()
    );
    let event = unsafe { owned(CreateEventW(std::ptr::null(), 1, 0, wide(&name).as_ptr()))? };
    let mut client = Command::new(root.join("app/aoravpn.exe"))
        .arg(format!("--migration-ready={name}"))
        .current_dir(root.join("app"))
        .creation_flags(CREATE_NO_WINDOW)
        .spawn()
        .map_err(|error| format!("New client launch failed: {error}"))?;
    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        if unsafe { WaitForSingleObject(event.as_raw_handle(), 100) } == WAIT_OBJECT_0 {
            return Ok(());
        }
        if client.try_wait()?.is_some() {
            return Err("The new client exited before its first frame".into());
        }
        if Instant::now() >= deadline {
            let _ = client.kill();
            let _ = client.wait();
            return Err(
                "The new client did not finish starting; restoring the previous client".into(),
            );
        }
    }
}

fn restore_previous_client(legacy: &Path) -> Result<()> {
    reject_link(legacy)?;
    let app = legacy.join("app");
    reject_link(&app)?;
    let backup = app.join("aoravpn.migration-backup.exe");
    reject_link(&backup)?;
    fs::copy(backup, app.join("aoravpn.exe"))?;
    Command::new(app.join("aoravpn.exe"))
        .current_dir(app)
        .creation_flags(CREATE_NO_WINDOW)
        .spawn()
        .map_err(|error| format!("Previous client restart failed: {error}"))?;
    Ok(())
}

fn run() -> Result<()> {
    let (root, legacy) = roots()?;
    let own = std::env::current_exe()?.canonicalize()?;
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.as_slice() {
        [] if own == legacy.join("app/aoravpn.exe").canonicalize()? => {
            let helper = root.join("app/aoravpn_migrate.exe");
            if !root.join("installed-version.txt").is_file()
                || !root.join("app/aoravpn.exe").is_file()
            {
                return Err(
                    "New installation is not ready. Your previous settings were retained.".into(),
                );
            }
            Command::new(helper)
                .args(["finish", &std::process::id().to_string()])
                .current_dir(root.join("app"))
                .creation_flags(CREATE_BREAKAWAY_FROM_JOB | CREATE_NO_WINDOW)
                .spawn()?;
        }
        [operation, pid]
            if operation == "finish"
                && own == root.join("app/aoravpn_migrate.exe").canonicalize()? =>
        {
            let guard = unsafe {
                owned(CreateMutexW(
                    std::ptr::null(),
                    0,
                    wide("Local\\AORAConnectMigration").as_ptr(),
                ))?
            };
            if unsafe { GetLastError() } == ERROR_ALREADY_EXISTS {
                return Ok(());
            }
            let _guard = guard;
            wait_launcher(pid.parse()?)?;
            let deadline = Instant::now() + Duration::from_secs(30);
            while !runtime_idle(&legacy.join("runtime"))? {
                if Instant::now() >= deadline {
                    return Err(
                        "Legacy updater is still active; previous files were retained".into(),
                    );
                }
                std::thread::sleep(Duration::from_millis(100));
            }
            let snapshot = matching_settings(&root, &legacy)?;
            if let Err(error) = start_verified_client(&root) {
                if let Err(rollback) = restore_previous_client(&legacy) {
                    return Err(format!("{error}; {rollback}").into());
                }
                return Err(error);
            }
            let cleanup_deadline = Instant::now() + Duration::from_secs(10);
            loop {
                match cleanup(&legacy, snapshot.clone()) {
                    Ok(()) => {
                        cleanup_registration(&legacy)?;
                        break;
                    }
                    Err(error)
                        if error
                            .downcast_ref::<io::Error>()
                            .is_some_and(|error| matches!(error.raw_os_error(), Some(32 | 33)))
                            && Instant::now() < cleanup_deadline =>
                    {
                        std::thread::sleep(Duration::from_millis(100));
                    }
                    Err(error) => return Err(error),
                }
            }
        }
        _ => return Err("Invalid migration handoff".into()),
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        #[cfg(feature = "migration-fixture")]
        {
            let _ = fs::write(
                PathBuf::from(env!("AORA_MIGRATION_FIXTURE_ROOT")).join("migration-error.txt"),
                error.to_string(),
            );
            eprintln!("{error}");
        }
        #[cfg(not(feature = "migration-fixture"))]
        unsafe {
            MessageBoxW(
                std::ptr::null_mut(),
                wide(error.to_string()).as_ptr(),
                wide("AORA Connect migration").as_ptr(),
                MB_OK | MB_ICONERROR,
            );
        }
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Fixture {
        base: PathBuf,
        root: PathBuf,
        legacy: PathBuf,
    }
    impl Fixture {
        fn new() -> Self {
            let base = std::env::temp_dir().join(format!(
                "aora-migration-native-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            let root = base.join("installed");
            let legacy = base.join("legacy");
            fs::create_dir_all(root.join("settings")).unwrap();
            for name in ["app", "cores", "runtime", "uninstall", "settings"] {
                fs::create_dir_all(legacy.join(name)).unwrap();
            }
            for name in SETTINGS {
                fs::write(root.join("settings").join(name), name).unwrap();
                fs::write(legacy.join("settings").join(name), name).unwrap();
            }
            Self { base, root, legacy }
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.base);
        }
    }
    #[test]
    fn verified_settings_are_kept_in_the_new_root_and_legacy_is_removed() {
        let f = Fixture::new();
        let snapshot = matching_settings(&f.root, &f.legacy).unwrap();
        cleanup(&f.legacy, snapshot).unwrap();
        assert!(!f.legacy.exists());
        for name in SETTINGS {
            assert_eq!(
                fs::read_to_string(f.root.join("settings").join(name)).unwrap(),
                name
            );
        }
    }
    #[test]
    fn conflicting_settings_remain_available_for_recovery() {
        let f = Fixture::new();
        fs::write(f.root.join("settings/app-state.json"), "newer state").unwrap();
        let snapshot = matching_settings(&f.root, &f.legacy).unwrap();
        assert!(snapshot.is_none());
        cleanup(&f.legacy, snapshot).unwrap();
        for name in SETTINGS {
            assert!(f.legacy.join("settings").join(name).exists());
        }
        assert_eq!(
            fs::read_to_string(f.root.join("settings/app-state.json")).unwrap(),
            "newer state"
        );
    }
    #[test]
    fn settings_changed_after_snapshot_are_not_deleted() {
        let f = Fixture::new();
        let snapshot = matching_settings(&f.root, &f.legacy).unwrap();
        fs::write(f.legacy.join("settings/language.json"), "changed language").unwrap();
        cleanup(&f.legacy, snapshot).unwrap();
        assert_eq!(
            fs::read_to_string(f.legacy.join("settings/language.json")).unwrap(),
            "changed language"
        );
    }
    #[test]
    fn active_installer_lease_prevents_cleanup() {
        let f = Fixture::new();
        let path = f.legacy.join("runtime/.installer.lock");
        let lease = fs::OpenOptions::new()
            .create(true)
            .truncate(false)
            .read(true)
            .write(true)
            .share_mode(0)
            .open(path)
            .unwrap();
        assert!(!runtime_idle(&f.legacy.join("runtime")).unwrap());
        drop(lease);
        assert!(runtime_idle(&f.legacy.join("runtime")).unwrap());
    }
    #[test]
    fn unrelated_files_are_preserved() {
        let f = Fixture::new();
        fs::write(f.legacy.join("unrelated.txt"), "keep").unwrap();
        let snapshot = matching_settings(&f.root, &f.legacy).unwrap();
        cleanup(&f.legacy, snapshot).unwrap();
        assert_eq!(
            fs::read_to_string(f.legacy.join("unrelated.txt")).unwrap(),
            "keep"
        );
    }
}
