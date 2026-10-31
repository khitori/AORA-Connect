// SPDX-License-Identifier: GPL-3.0-or-later
use super::{authorization, transport::SecurityDescriptor};
use crate::{owned, wide};
use std::{
    fs::{self, File, OpenOptions},
    io::{self, Write},
    mem::{size_of, zeroed},
    os::windows::{
        fs::{MetadataExt, OpenOptionsExt},
        io::AsRawHandle,
    },
    path::{Path, PathBuf},
    ptr::null_mut,
};
use windows_sys::Win32::{
    Foundation::*,
    Security::{Cryptography::*, *},
    Storage::FileSystem::*,
};

fn private_descriptor() -> io::Result<SecurityDescriptor> {
    SecurityDescriptor::new("O:SYG:SYD:P(A;;FA;;;SY)(A;;FA;;;BA)")
}
pub(super) fn enroll(root: &Path) -> io::Result<()> {
    authorization::protected(root)?;
    let path = root.join("runtime");
    if !path.try_exists()? {
        fs::create_dir(&path)?;
    }
    let _guard = authorization::private_directory(root, "runtime")?;
    authorization::protected(&path)
}
fn guard(root: &Path) -> io::Result<File> {
    authorization::protected(root)?;
    let runtime = root.join("runtime");
    authorization::protected(&runtime)?;
    let file = OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES | READ_CONTROL)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT)
        .open(runtime)?;
    if !file.metadata()?.is_dir()
        || file.metadata()?.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0
    {
        return Err(io::Error::other("Unsafe runtime directory"));
    }
    Ok(file)
}
pub(super) struct Config {
    pub file: PathBuf,
    directory: PathBuf,
}
impl Drop for Config {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.file);
        let _ = fs::remove_dir(&self.directory);
    }
}
pub(super) fn create(root: &Path, bytes: &[u8]) -> io::Result<Config> {
    let _guard = guard(root)?;
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
        return Err(io::Error::other("Runtime random source failed"));
    }
    let id = random
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect::<String>();
    let directory = root.join("runtime").join(format!("service-{id}"));
    let descriptor = private_descriptor()?;
    let security = SECURITY_ATTRIBUTES {
        nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
        lpSecurityDescriptor: descriptor.as_ptr(),
        bInheritHandle: 0,
    };
    if unsafe { CreateDirectoryW(wide(&directory).as_ptr(), &security) } == 0 {
        return Err(io::Error::last_os_error());
    }
    let config = Config {
        file: directory.join("config.json"),
        directory,
    };
    let handle = unsafe {
        CreateFileW(
            wide(&config.file).as_ptr(),
            GENERIC_WRITE,
            0,
            &security,
            CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT,
            null_mut(),
        )
    };
    let mut output = File::from(unsafe { owned(handle)? });
    output.write_all(bytes)?;
    output.sync_all()?;
    drop(output);
    Ok(config)
}
pub(super) fn sweep(root: &Path) -> io::Result<()> {
    let _guard = guard(root)?;
    for entry in fs::read_dir(root.join("runtime"))? {
        let entry = entry?;
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        let Some(id) = name.strip_prefix("service-") else {
            continue;
        };
        if id.len() != 32 || !id.bytes().all(|b| b.is_ascii_hexdigit()) {
            continue;
        }
        let directory = entry.path();
        authorization::protected(&directory)?;
        let metadata = fs::symlink_metadata(&directory)?;
        if !metadata.is_dir() || metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
            return Err(io::Error::other("Unsafe stale runtime directory"));
        }
        for child in fs::read_dir(&directory)? {
            if child?.file_name() != "config.json" {
                return Err(io::Error::other("Unexpected stale runtime contents"));
            }
        }
        let path = directory.join("config.json");
        if path.try_exists()? {
            authorization::protected(&path)?;
            let file = OpenOptions::new()
                .read(true)
                .share_mode(FILE_SHARE_READ | FILE_SHARE_DELETE)
                .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT)
                .open(&path)?;
            let mut info: BY_HANDLE_FILE_INFORMATION = unsafe { zeroed() };
            if unsafe { GetFileInformationByHandle(file.as_raw_handle(), &mut info) } == 0 {
                return Err(io::Error::last_os_error());
            }
            if info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)
                != 0
                || info.nNumberOfLinks != 1
            {
                return Err(io::Error::other("Unsafe stale runtime file"));
            }
            drop(file);
            fs::remove_file(path)?;
        }
        fs::remove_dir(directory)?;
    }
    Ok(())
}
