// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
use aora_windows_helpers::{owned, updates::*, wide};
use std::{
    io::Read,
    os::windows::{
        fs::{MetadataExt, OpenOptionsExt},
        io::AsRawHandle,
        process::CommandExt,
    },
    path::{Path, PathBuf},
    process::Command,
    ptr::null_mut,
    time::{Duration, Instant},
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Authorization::*, Cryptography::*, SECURITY_ATTRIBUTES},
    Storage::FileSystem::*,
    System::Threading::*,
    UI::WindowsAndMessaging::*,
};

const PACKAGE: &str = "AORAConnect-Setup.exe";
const HELPER: &str = "aoravpn_update.exe";
// Every name an update session has used, including sessions created by
// earlier elevated interfaces inside the protected runtime directory.
const SESSION_NAMES: [&str; 8] = [
    PACKAGE,
    HELPER,
    "AORAConnect.apk",
    "aora-update.json",
    ".update.lock",
    ".installer.lock",
    "installing.json",
    "staged.lock",
];

/// A staging failure the interface reports with a specific message.
#[derive(Debug)]
struct Rejected(i32, &'static str);
impl std::fmt::Display for Rejected {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter.write_str(self.1)
    }
}
impl std::error::Error for Rejected {}

fn app_root() -> Result<PathBuf> {
    Ok(aora_windows_helpers::installation_root()?)
}

fn installer_lease(directory: &Path) -> std::io::Result<std::fs::File> {
    std::fs::OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .share_mode(0)
        .open(directory.join(".installer.lock"))
}

fn plain_directory(path: &Path) -> Result<()> {
    let metadata = std::fs::symlink_metadata(path)?;
    if !metadata.is_dir() || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err("Application storage must not contain links".into());
    }
    Ok(())
}

fn random_id() -> Result<String> {
    let mut random = [0u8; 16];
    if unsafe {
        BCryptGenRandom(
            null_mut(),
            random.as_mut_ptr(),
            random.len() as u32,
            BCRYPT_USE_SYSTEM_PREFERRED_RNG,
        )
    } < 0
    {
        return Err("Update random source failed".into());
    }
    Ok(random.iter().map(|b| format!("{b:02x}")).collect())
}

fn create_private_directory(path: &Path) -> Result<()> {
    unsafe {
        let mut descriptor = null_mut();
        if ConvertStringSecurityDescriptorToSecurityDescriptorW(
            wide("D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)").as_ptr(),
            1,
            &mut descriptor,
            null_mut(),
        ) == 0
        {
            return Err(std::io::Error::last_os_error().into());
        }
        let security = SECURITY_ATTRIBUTES {
            nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
            lpSecurityDescriptor: descriptor,
            bInheritHandle: 0,
        };
        let created = CreateDirectoryW(wide(path).as_ptr(), &security);
        let error = std::io::Error::last_os_error();
        LocalFree(descriptor);
        if created == 0 {
            return Err(error.into());
        }
    }
    Ok(())
}

/// Removes earlier staging sessions. Links, unknown files and files that are
/// still in use (such as a running staged helper) leave their session intact.
fn sweep(runtime: &Path) {
    let Ok(entries) = std::fs::read_dir(runtime) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if !path
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| name.starts_with("update-"))
            || plain_directory(&path).is_err()
            || (path.join(".installer.lock").exists() && installer_lease(&path).is_err())
        {
            continue;
        }
        let Ok(children) = std::fs::read_dir(&path) else {
            continue;
        };
        let mut clean = true;
        for child in children.flatten() {
            let child = child.path();
            let known = child
                .file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| SESSION_NAMES.contains(&name));
            match std::fs::symlink_metadata(&child) {
                Ok(metadata) if known && metadata.is_file() => {
                    if std::fs::remove_file(&child).is_err() {
                        clean = false;
                    }
                }
                _ => clean = false,
            }
        }
        if clean {
            let _ = std::fs::remove_dir(&path);
        }
    }
}

/// Copies the user's package while preventing other writers, so the protected
/// copy is exactly the bytes that were opened.
fn copy_locked(source: &Path, target: &Path) -> Result<()> {
    let limit = MAX_INSTALLER_SIZE + 65536 + 24;
    let input = std::fs::OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ)
        .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
        .open(source)?;
    let metadata = input.metadata()?;
    if !metadata.is_file()
        || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0
        || metadata.len() > limit
    {
        return Err(Rejected(2, "Invalid update package").into());
    }
    let mut output = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(target)?;
    let copied = std::io::copy(&mut input.take(limit + 1), &mut output)?;
    if copied != metadata.len() {
        return Err(Rejected(2, "Update package changed while it was copied").into());
    }
    output.sync_all()?;
    Ok(())
}

/// Elevated step 1, started from the installed application folder: stage a
/// protected copy of the package and helper, verify it, then hand off.
fn stage(source: &Path, pid: &str) -> Result<()> {
    pid.parse::<u32>()?;
    let root = app_root()?;
    let installed = root.join("app").join(HELPER);
    for path in [&root, &root.join("app")] {
        plain_directory(path)?;
    }
    if std::env::current_exe()?.canonicalize()? != installed.canonicalize()? {
        return Err("Updates must be started by the installed application".into());
    }
    let runtime = root.join("runtime");
    plain_directory(&runtime)?;
    sweep(&runtime);
    let directory = runtime.join(format!("update-{}", random_id()?));
    create_private_directory(&directory)?;
    let result = (|| -> Result<()> {
        let package = directory.join(PACKAGE);
        copy_locked(source, &package)?;
        std::fs::copy(&installed, directory.join(HELPER))?;
        let release =
            verify_package(&package).map_err(|_| Rejected(2, "Update verification failed"))?;
        if version(&release.version)? <= version(env!("AORA_APP_VERSION"))? {
            return Err(Rejected(3, "Update is not newer").into());
        }
        let mut command = Command::new(directory.join(HELPER));
        command
            .arg("run")
            .arg(&package)
            .arg(pid)
            .current_dir(&directory);
        // The interface's job allows breakaway; outside a job the flag is not needed.
        if command
            .creation_flags(CREATE_BREAKAWAY_FROM_JOB | CREATE_NO_WINDOW)
            .spawn()
            .is_err()
        {
            command.creation_flags(CREATE_NO_WINDOW).spawn()?;
        }
        Ok(())
    })();
    if result.is_err() {
        sweep(&runtime);
    }
    result
}

/// Elevated step 2, running from the protected staging copy so the installer
/// can replace the installed helper.
fn install(file: &str, pid: &str) -> Result<()> {
    let root = app_root()?;
    let runtime = root.join("runtime").canonicalize()?;
    let package = Path::new(file).canonicalize()?;
    let directory = package.parent().ok_or("Missing update directory")?;
    if directory.parent() != Some(runtime.as_path())
        || !directory
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| name.starts_with("update-"))
        || package.file_name().and_then(|name| name.to_str()) != Some(PACKAGE)
        || std::env::current_exe()?.canonicalize()? != directory.join(HELPER)
    {
        return Err("Update must be staged in protected application storage".into());
    }
    let _installer_lease = installer_lease(directory)?;
    unsafe {
        let handle = OpenProcess(PROCESS_SYNCHRONIZE, 0, pid.parse()?);
        if !handle.is_null() {
            let parent = owned(handle)?;
            if WaitForSingleObject(parent.as_raw_handle(), 30000) != WAIT_OBJECT_0 {
                return Err("Application did not close; update cancelled".into());
            }
        } else if GetLastError() != ERROR_INVALID_PARAMETER {
            return Err(std::io::Error::last_os_error().into());
        }
    }
    let deadline = Instant::now() + Duration::from_secs(10);
    loop {
        let handle = unsafe {
            OpenMutexW(
                SYNCHRONIZATION_SYNCHRONIZE,
                0,
                wide("Local\\AORAConnectPortableLaunch").as_ptr(),
            )
        };
        if handle.is_null() {
            break;
        }
        drop(unsafe { owned(handle)? });
        if Instant::now() >= deadline {
            return Err("Close the portable launcher before updating".into());
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    let release = verify_package(&package)?;
    if version(&release.version)? <= version(env!("AORA_APP_VERSION"))? {
        return Err("Update must be newer than the installed application".into());
    }
    let status = Command::new(&package)
        .args(["/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART"])
        .creation_flags(CREATE_NO_WINDOW)
        .status()?;
    if !status.success() {
        relaunch(&root);
        return Err(format!(
            "Installer failed (exit {:?}); your settings have been retained",
            status.code()
        )
        .into());
    }
    relaunch(&root);
    Ok(())
}

/// Reopens the interface through Explorer so it runs with the signed-in
/// user's ordinary token rather than this helper's administrator token.
fn relaunch(root: &Path) {
    let app = root.join("app");
    let executable = app.join("aoravpn.exe");
    if shell_execute(&executable, &app).is_err() {
        let _ = Command::new(&executable).current_dir(&app).spawn();
    }
}

fn shell_execute(executable: &Path, directory: &Path) -> windows::core::Result<()> {
    use windows::{
        core::{Interface, BSTR, VARIANT},
        Win32::{System::Com::*, UI::Shell::*},
    };
    unsafe {
        CoInitializeEx(None, COINIT_APARTMENTTHREADED).ok()?;
        let result = (|| {
            let shell_windows: IShellWindows =
                CoCreateInstance(&ShellWindows, None, CLSCTX_LOCAL_SERVER)?;
            let location = VARIANT::from(CSIDL_DESKTOP as i32);
            let root = VARIANT::default();
            let mut hwnd = 0;
            let desktop = shell_windows.FindWindowSW(
                &location,
                &root,
                SWC_DESKTOP,
                &mut hwnd,
                SWFO_NEEDDISPATCH,
            )?;
            let browser: IShellBrowser = desktop
                .cast::<IServiceProvider>()?
                .QueryService(&SID_STopLevelBrowser)?;
            let background: IDispatch = browser
                .QueryActiveShellView()?
                .GetItemObject(SVGIO_BACKGROUND)?;
            let shell: IShellDispatch2 = background
                .cast::<IShellFolderViewDual>()?
                .Application()?
                .cast()?;
            shell.ShellExecute(
                &BSTR::from(executable.to_string_lossy().as_ref()),
                &VARIANT::from(""),
                &VARIANT::from(directory.to_string_lossy().as_ref()),
                &VARIANT::from("open"),
                &VARIANT::from(1i32),
            )
        })();
        CoUninitialize();
        result
    }
}

fn run(args: &[String]) -> Result<()> {
    match args {
        [operation] if operation == "info" => {
            println!(
                "{}",
                serde_json::json!({"version": env!("AORA_APP_VERSION")})
            );
        }
        [operation, file] if operation == "verify-manifest" => {
            if std::fs::metadata(file)?.len() > 65536 {
                return Err("Release metadata is too large".into());
            }
            let release = verify_manifest(&std::fs::read(file)?)?;
            println!("{}", serde_json::to_string(&release)?);
        }
        [operation, file] if operation == "verify-package" || operation == "inspect-package" => {
            let release = verify_package(Path::new(file))?;
            println!("{}", serde_json::to_string(&release)?);
        }
        [operation, file, pid] if operation == "install" => stage(Path::new(file), pid)?,
        [operation, file, pid] if operation == "run" => install(file, pid)?,
        _ => return Err("Invalid update helper arguments".into()),
    }
    Ok(())
}

fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if let Err(error) = run(&args) {
        match args.first().map(String::as_str) {
            // The interface waits for this step and reports its exit code.
            Some("install") => {
                std::process::exit(error.downcast_ref::<Rejected>().map_or(1, |r| r.0))
            }
            Some("run") => unsafe {
                MessageBoxW(
                    std::ptr::null_mut(),
                    wide(error.to_string()).as_ptr(),
                    wide("AORA Connect update").as_ptr(),
                    MB_OK | MB_ICONERROR,
                );
            },
            _ => eprintln!("{error}"),
        }
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temporary(name: &str) -> PathBuf {
        let directory =
            std::env::temp_dir().join(format!("aora-update-{name}-{}", std::process::id()));
        std::fs::create_dir(&directory).unwrap();
        directory
    }

    #[test]
    fn installer_lease_blocks_cleanup_until_helper_exits() {
        let directory = temporary("lease");
        let path = directory.join(".installer.lock");
        let lease = installer_lease(&directory).unwrap();
        assert!(std::fs::OpenOptions::new().write(true).open(&path).is_err());
        assert!(std::fs::remove_file(&path).is_err());
        drop(lease);
        std::fs::remove_file(path).unwrap();
        std::fs::remove_dir(directory).unwrap();
    }

    #[test]
    fn sweep_keeps_sessions_in_use_or_with_unknown_files() {
        let runtime = temporary("sweep");
        let session = |name: &str, files: &[&str]| {
            let path = runtime.join(name);
            std::fs::create_dir(&path).unwrap();
            for file in files {
                std::fs::write(path.join(file), b"x").unwrap();
            }
            path
        };
        let old = session("update-old", &[PACKAGE, HELPER, ".update.lock"]);
        let unknown = session("update-unknown", &[PACKAGE, "notes.txt"]);
        let busy = session("update-busy", &[PACKAGE]);
        let other = session("service-0123", &["config.json"]);
        let lease = installer_lease(&busy).unwrap();
        sweep(&runtime);
        assert!(!old.exists());
        assert!(unknown.join("notes.txt").exists());
        assert!(busy.join(".installer.lock").exists());
        assert!(other.join("config.json").exists());
        drop(lease);
        sweep(&runtime);
        assert!(!busy.exists());
        std::fs::remove_dir_all(runtime).unwrap();
    }

    #[test]
    #[ignore = "starts a process through the signed-in user's Explorer"]
    fn explorer_launch_is_available() {
        let system = PathBuf::from(std::env::var_os("SystemRoot").unwrap()).join("System32");
        shell_execute(&system.join("rundll32.exe"), &system).unwrap();
    }

    #[test]
    fn locked_copy_rejects_links_and_changes() {
        let directory = temporary("copy");
        let source = directory.join("source.exe");
        std::fs::write(&source, b"package").unwrap();
        copy_locked(&source, &directory.join("copy.exe")).unwrap();
        assert_eq!(std::fs::read(directory.join("copy.exe")).unwrap(), b"package");
        assert!(copy_locked(&source, &directory.join("copy.exe")).is_err());
        let held = std::fs::OpenOptions::new().write(true).open(&source).unwrap();
        assert!(copy_locked(&source, &directory.join("second.exe")).is_err());
        drop(held);
        assert!(copy_locked(&directory, &directory.join("third.exe")).is_err());
        std::fs::remove_dir_all(directory).unwrap();
    }
}
