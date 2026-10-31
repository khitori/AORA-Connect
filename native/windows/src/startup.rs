// SPDX-License-Identifier: GPL-3.0-or-later
use crate::{owned, wide};
use serde::{Deserialize, Serialize};
use std::{
    fs, io,
    mem::size_of,
    os::windows::{fs::MetadataExt, io::AsRawHandle},
    path::{Path, PathBuf},
    ptr::null_mut,
};
use windows::{
    core::{Interface, BSTR, VARIANT},
    Win32::System::{Com::*, TaskScheduler::*},
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{
        Authorization::{
            ConvertSidToStringSidW, ConvertStringSecurityDescriptorToSecurityDescriptorW,
            ConvertStringSidToSidW,
        },
        *,
    },
    Storage::FileSystem::*,
    System::Threading::*,
};

const PREFIX: &str = "AORAConnect-Startup-";

struct SettingsLock(std::os::windows::io::OwnedHandle);
impl SettingsLock {
    fn acquire() -> io::Result<Self> {
        unsafe {
            let handle = owned(CreateMutexW(
                std::ptr::null(),
                0,
                wide("Global\\AORAConnectStartupSettings").as_ptr(),
            ))?;
            let result = WaitForSingleObject(handle.as_raw_handle(), 10000);
            if !matches!(result, WAIT_OBJECT_0 | WAIT_ABANDONED) {
                return Err(io::Error::other("Startup settings are busy. Try again."));
            }
            Ok(Self(handle))
        }
    }
}
impl Drop for SettingsLock {
    fn drop(&mut self) {
        unsafe {
            ReleaseMutex(self.0.as_raw_handle());
        }
    }
}

#[derive(Default, Clone, Copy, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Preferences {
    pub start_with_windows: bool,
    pub start_minimized: bool,
}

#[derive(Default, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Saved {
    start_minimized: bool,
}

fn native(error: windows::core::Error) -> io::Error {
    io::Error::other(error.to_string())
}

fn same_user(account: &str, expected: &str) -> io::Result<bool> {
    if account == expected {
        return Ok(true);
    }
    if account.contains('\0') {
        return Ok(false);
    }
    unsafe {
        let mut sid_size = 0;
        let mut domain_size = 0;
        let mut kind = 0;
        LookupAccountNameW(
            std::ptr::null(),
            wide(account).as_ptr(),
            null_mut(),
            &mut sid_size,
            null_mut(),
            &mut domain_size,
            &mut kind,
        );
        if GetLastError() != ERROR_INSUFFICIENT_BUFFER {
            return Ok(false);
        }
        let mut actual = vec![0usize; (sid_size as usize).div_ceil(size_of::<usize>())];
        let mut domain = vec![0u16; domain_size as usize];
        if LookupAccountNameW(
            std::ptr::null(),
            wide(account).as_ptr(),
            actual.as_mut_ptr().cast(),
            &mut sid_size,
            domain.as_mut_ptr(),
            &mut domain_size,
            &mut kind,
        ) == 0
        {
            return Err(io::Error::last_os_error());
        }
        let mut wanted = null_mut();
        if ConvertStringSidToSidW(wide(expected).as_ptr(), &mut wanted) == 0 {
            return Err(io::Error::last_os_error());
        }
        let matches = EqualSid(actual.as_mut_ptr().cast(), wanted) != 0;
        LocalFree(wanted);
        Ok(matches)
    }
}

fn sid() -> io::Result<String> {
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
        let result = String::from_utf16_lossy(std::slice::from_raw_parts(text, length));
        LocalFree(text.cast());
        Ok(result)
    }
}

fn no_link(path: &Path) -> io::Result<()> {
    if fs::symlink_metadata(path)?.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(io::Error::other("Startup storage must not contain links"));
    }
    Ok(())
}

fn storage(user: &str) -> io::Result<(PathBuf, PathBuf)> {
    if !user.starts_with("S-1-")
        || user.len() > 184
        || !user.bytes().all(|b| b == b'S' || b == b'-' || b.is_ascii_digit())
    {
        return Err(io::Error::other("Invalid startup account"));
    }
    let root = crate::installation_root()?;
    let settings = root.join("settings");
    no_link(&root)?;
    no_link(&settings)?;
    let file = settings.join(format!("startup-{user}.json"));
    if file.try_exists()? {
        no_link(&file)?;
    }
    Ok((root, file))
}

fn read(file: &Path) -> io::Result<Saved> {
    if !file.try_exists()? {
        return Ok(Saved::default());
    }
    if fs::metadata(file)?.len() > 4096 {
        return Err(io::Error::other("Invalid startup preferences"));
    }
    serde_json::from_slice(&fs::read(file)?).map_err(io::Error::other)
}

pub fn minimized() -> io::Result<bool> {
    let (_, file) = storage(&sid()?)?;
    Ok(read(&file)?.start_minimized)
}

struct Com;
impl Drop for Com {
    fn drop(&mut self) {
        unsafe {
            CoUninitialize();
        }
    }
}

fn scheduler() -> io::Result<(Com, ITaskFolder)> {
    unsafe {
        CoInitializeEx(None, COINIT_APARTMENTTHREADED)
            .ok()
            .map_err(native)?;
        let com = Com;
        let service: ITaskService =
            CoCreateInstance(&TaskScheduler, None, CLSCTX_INPROC_SERVER).map_err(native)?;
        let empty = VARIANT::default();
        service
            .Connect(&empty, &empty, &empty, &empty)
            .map_err(native)?;
        let folder = service.GetFolder(&BSTR::from("\\")).map_err(native)?;
        Ok((com, folder))
    }
}

fn text(call: impl FnOnce(*mut BSTR) -> windows::core::Result<()>) -> io::Result<String> {
    let mut value = BSTR::new();
    call(&mut value).map_err(native)?;
    Ok(value.to_string())
}

unsafe fn existing(
    folder: &ITaskFolder,
    name: &str,
    user: &str,
    executable: &Path,
) -> io::Result<Option<IRegisteredTask>> {
    let task = match folder.GetTask(&BSTR::from(name)) {
        Ok(task) => task,
        Err(error) if error.code().0 as u32 == 0x80070002 => return Ok(None),
        Err(error) => return Err(native(error)),
    };
    let definition = task.Definition().map_err(native)?;
    let principal = definition.Principal().map_err(native)?;
    let mut logon = TASK_LOGON_TYPE::default();
    let mut level = TASK_RUNLEVEL_TYPE::default();
    principal.LogonType(&mut logon).map_err(native)?;
    principal.RunLevel(&mut level).map_err(native)?;
    let actions = definition.Actions().map_err(native)?;
    let mut count = 0;
    actions.Count(&mut count).map_err(native)?;
    if count != 1 {
        return Err(io::Error::other("Unexpected startup task actions"));
    }
    let action: IExecAction = actions
        .get_Item(1)
        .map_err(native)?
        .cast()
        .map_err(native)?;
    let triggers = definition.Triggers().map_err(native)?;
    let mut trigger_count = 0;
    triggers.Count(&mut trigger_count).map_err(native)?;
    if trigger_count != 1 {
        return Err(io::Error::other("Unexpected startup task triggers"));
    }
    let trigger: ILogonTrigger = triggers
        .get_Item(1)
        .map_err(native)?
        .cast()
        .map_err(native)?;
    if !same_user(&text(|out| principal.UserId(out))?, user)?
        || logon != TASK_LOGON_INTERACTIVE_TOKEN
        // Tasks from elevated interfaces used the highest level; migrate() lowers them.
        || (level != TASK_RUNLEVEL_LUA && level != TASK_RUNLEVEL_HIGHEST)
        || !text(|out| action.Path(out))?.eq_ignore_ascii_case(&executable.to_string_lossy())
        || text(|out| action.Arguments(out))? != "--startup"
        || !text(|out| action.WorkingDirectory(out))?
            .eq_ignore_ascii_case(&executable.parent().unwrap().to_string_lossy())
        || !same_user(&text(|out| trigger.UserId(out))?, user)?
    {
        return Err(io::Error::other(
            "The startup task has an unexpected configuration. It was left unchanged.",
        ));
    }
    Ok(Some(task))
}

fn xml_escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

fn definition(user: &str, executable: &Path) -> String {
    let exe = xml_escape(&executable.to_string_lossy());
    let directory = xml_escape(&executable.parent().unwrap().to_string_lossy());
    format!(
        r#"<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Author>AORA Connect</Author><Description>Open AORA Connect when this user signs in.</Description></RegistrationInfo>
<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>{user}</UserId></LogonTrigger></Triggers>
<Principals><Principal id="User"><UserId>{user}</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>false</StartWhenAvailable><Enabled>true</Enabled><ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>
<Actions Context="User"><Exec><Command>{exe}</Command><Arguments>--startup</Arguments><WorkingDirectory>{directory}</WorkingDirectory></Exec></Actions></Task>"#
    )
}

unsafe fn register(folder: &ITaskFolder, name: &str, user: &str, xml: &str) -> io::Result<()> {
    folder
        .RegisterTask(
            &BSTR::from(name),
            &BSTR::from(xml),
            TASK_CREATE_OR_UPDATE.0,
            &VARIANT::from(user),
            &VARIANT::default(),
            TASK_LOGON_INTERACTIVE_TOKEN,
            &VARIANT::from("D:P(A;;GA;;;SY)(A;;GA;;;BA)"),
        )
        .map_err(native)?;
    Ok(())
}

fn executable(root: &Path) -> io::Result<PathBuf> {
    no_link(&root.join("app"))?;
    let executable = root.join("app").join("aoravpn.exe");
    no_link(&executable)?;
    Ok(executable)
}

/// Reads the startup task and preference of the enrolled account `user`.
pub fn status(user: &str) -> io::Result<Preferences> {
    let (root, file) = storage(user)?;
    let saved = read(&file)?;
    let (_com, folder) = scheduler()?;
    let task = unsafe {
        existing(
            &folder,
            &format!("{PREFIX}{user}"),
            user,
            &executable(&root)?,
        )?
    };
    let enabled = task
        .map(|task| unsafe { task.Enabled().map(|value| value.as_bool()).map_err(native) })
        .transpose()?
        .unwrap_or(false);
    Ok(Preferences {
        start_with_windows: enabled,
        start_minimized: saved.start_minimized,
    })
}

/// Saves startup preferences for the enrolled account `user`. The task runs the
/// installed interface with the user's ordinary rights at sign-in.
pub fn configure(user: &str, preferences: Preferences) -> io::Result<Preferences> {
    let _lock = SettingsLock::acquire()?;
    let (root, file) = storage(user)?;
    let _ = read(&file)?;
    let executable = executable(&root)?;
    let (_com, folder) = scheduler()?;
    let name = format!("{PREFIX}{user}");
    let task = unsafe { existing(&folder, &name, user, &executable)? };
    let previous_xml = task
        .as_ref()
        .map(|task| unsafe { task.Xml().map(|xml| xml.to_string()).map_err(native) })
        .transpose()?;
    unsafe {
        if preferences.start_with_windows {
            register(&folder, &name, user, &definition(user, &executable))?;
        } else if task.is_some() {
            folder.DeleteTask(&BSTR::from(&name), 0).map_err(native)?;
        }
    }
    let temporary = file.with_extension(format!("{}.tmp", std::process::id()));
    let result = (|| {
        use std::io::Write;
        let mut output = private_file(&temporary, user)?;
        output.write_all(&serde_json::to_vec(&Saved {
            start_minimized: preferences.start_minimized,
        })?)?;
        output.sync_all()?;
        drop(output);
        if unsafe {
            MoveFileExW(
                wide(&temporary).as_ptr(),
                wide(&file).as_ptr(),
                MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        Ok(())
    })();
    if let Err(error) = result {
        let _ = fs::remove_file(&temporary);
        let rollback = unsafe {
            if let Some(xml) = previous_xml {
                register(&folder, &name, user, &xml)
            } else if preferences.start_with_windows {
                folder.DeleteTask(&BSTR::from(&name), 0).map_err(native)
            } else {
                Ok(())
            }
        };
        if rollback.is_err() {
            return Err(io::Error::other(
                "Startup preferences could not be saved or restored. Check Windows Task Scheduler.",
            ));
        }
        return Err(error);
    }
    Ok(preferences)
}

/// Lowers a task created by an elevated interface to ordinary rights and lets
/// the interface read its own minimized preference. Safe to repeat.
pub fn migrate(user: &str) -> io::Result<()> {
    configure(user, status(user)?).map(|_| ())
}

/// Creates the preference file readable, but not writable, by its account so
/// an unelevated interface can honor Start minimized at launch.
fn private_file(path: &Path, user: &str) -> io::Result<fs::File> {
    unsafe {
        let mut descriptor = null_mut();
        if ConvertStringSecurityDescriptorToSecurityDescriptorW(
            wide(format!("D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;{user})")).as_ptr(),
            1,
            &mut descriptor,
            null_mut(),
        ) == 0
        {
            return Err(io::Error::last_os_error());
        }
        let security = SECURITY_ATTRIBUTES {
            nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
            lpSecurityDescriptor: descriptor,
            bInheritHandle: 0,
        };
        let handle = CreateFileW(
            wide(path).as_ptr(),
            GENERIC_WRITE,
            0,
            &security,
            CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT,
            null_mut(),
        );
        let file = owned(handle);
        LocalFree(descriptor);
        Ok(fs::File::from(file?))
    }
}

pub fn remove_all() -> io::Result<()> {
    let _lock = SettingsLock::acquire()?;
    let root = crate::installation_root()?;
    let executable = executable(&root)?;
    let (_com, folder) = scheduler()?;
    unsafe {
        let tasks = folder.GetTasks(TASK_ENUM_HIDDEN.0).map_err(native)?;
        let mut names = Vec::new();
        for index in 1..=tasks.Count().map_err(native)? {
            let task = tasks.get_Item(&VARIANT::from(index)).map_err(native)?;
            let name = task.Name().map_err(native)?.to_string();
            if let Some(user) = name.strip_prefix(PREFIX) {
                existing(&folder, &name, user, &executable)?;
                names.push(name);
            }
        }
        for name in names {
            folder.DeleteTask(&BSTR::from(name), 0).map_err(native)?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn task_targets_only_the_installed_ui_at_interactive_sign_in() {
        let xml = definition(
            "S-1-5-21-123",
            Path::new("C:/Program Files/AORA & Test/app/aoravpn.exe"),
        );
        assert!(xml.contains("AORA &amp; Test"));
        assert!(xml.contains("<LogonType>InteractiveToken</LogonType>"));
        assert!(xml.contains("<RunLevel>LeastPrivilege</RunLevel>"));
        assert!(!xml.contains("HighestAvailable"));
        assert!(xml.contains("<ExecutionTimeLimit>PT0S</ExecutionTimeLimit>"));
        assert!(xml.contains("<Arguments>--startup</Arguments>"));
        assert!(!xml.contains("BootTrigger"));
    }

    #[test]
    fn real_scheduler_registration_rejects_foreign_actions_and_cleans_up() {
        if std::env::var("AORA_TEST_STARTUP_SCHEDULER").as_deref() != Ok("1") {
            return;
        }
        let user = sid().unwrap();
        let executable = executable(&crate::installation_root().unwrap()).unwrap();
        let (_com, folder) = scheduler().unwrap();
        let name = format!(
            "AORAConnect-StartupTest-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );
        let xml = definition(&user, &executable)
            .replace("<Enabled>true</Enabled>", "<Enabled>false</Enabled>");
        unsafe {
            register(&folder, &name, &user, &xml).unwrap();
            let result = (|| -> io::Result<()> {
                let task = existing(&folder, &name, &user, &executable)?.unwrap();
                assert!(!task.Enabled().map_err(native)?.as_bool());
                assert!(existing(&folder, &name, &user, Path::new("C:/unexpected.exe")).is_err());
                assert!(existing(&folder, &name, &user, &executable)?.is_some());
                Ok(())
            })();
            folder.DeleteTask(&BSTR::from(&name), 0).unwrap();
            result.unwrap();
            assert!(existing(&folder, &name, &user, &executable)
                .unwrap()
                .is_none());
        }
    }
}
