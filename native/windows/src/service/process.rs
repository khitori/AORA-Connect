// SPDX-License-Identifier: GPL-3.0-or-later
use crate::{owned, quote, wide, Process};
use std::{
    ffi::OsStr,
    fs::File,
    io::{self, Write},
    mem::{size_of, zeroed},
    os::windows::io::{AsRawHandle, OwnedHandle},
    path::Path,
    ptr::{null, null_mut},
    time::{Duration, Instant},
};
use windows_sys::Win32::{
    Foundation::*,
    Security::SECURITY_ATTRIBUTES,
    System::{JobObjects::*, Pipes::CreatePipe, Threading::*},
    UI::WindowsAndMessaging::SW_HIDE,
};

pub struct Child {
    pub process: Process,
    job: OwnedHandle,
    input: File,
}

struct Attributes {
    storage: Vec<usize>,
}
impl Attributes {
    fn pointer(&mut self) -> LPPROC_THREAD_ATTRIBUTE_LIST {
        self.storage.as_mut_ptr().cast()
    }
}
impl Drop for Attributes {
    fn drop(&mut self) {
        unsafe {
            DeleteProcThreadAttributeList(self.pointer());
        }
    }
}

fn pipe() -> io::Result<(OwnedHandle, OwnedHandle)> {
    let security = SECURITY_ATTRIBUTES {
        nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
        lpSecurityDescriptor: null_mut(),
        bInheritHandle: 1,
    };
    let (mut read, mut write) = (null_mut(), null_mut());
    if unsafe { CreatePipe(&mut read, &mut write, &security, 0) } == 0 {
        return Err(io::Error::last_os_error());
    }
    unsafe { Ok((owned(read)?, owned(write)?)) }
}

impl Child {
    pub fn spawn(executable: &Path, args: &[&OsStr], cwd: &Path) -> io::Result<(Self, File)> {
        unsafe {
            let job = owned(CreateJobObjectW(null(), null()))?;
            let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = zeroed();
            limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            if SetInformationJobObject(
                job.as_raw_handle(),
                JobObjectExtendedLimitInformation,
                (&limits as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
                size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            ) == 0
            {
                return Err(io::Error::last_os_error());
            }
            let (input_read, input_write) = pipe()?;
            let (output_read, output_write) = pipe()?;
            for handle in [&input_write, &output_read] {
                if SetHandleInformation(handle.as_raw_handle(), HANDLE_FLAG_INHERIT, 0) == 0 {
                    return Err(io::Error::last_os_error());
                }
            }
            let mut size = 0;
            InitializeProcThreadAttributeList(null_mut(), 2, 0, &mut size);
            let mut storage = vec![0usize; size.div_ceil(size_of::<usize>())];
            if InitializeProcThreadAttributeList(storage.as_mut_ptr().cast(), 2, 0, &mut size) == 0
            {
                return Err(io::Error::last_os_error());
            }
            let mut attributes = Attributes { storage };
            let handles = [input_read.as_raw_handle(), output_write.as_raw_handle()];
            let jobs = [job.as_raw_handle()];
            for (kind, values) in [
                (PROC_THREAD_ATTRIBUTE_HANDLE_LIST, handles.as_slice()),
                (PROC_THREAD_ATTRIBUTE_JOB_LIST, jobs.as_slice()),
            ] {
                if UpdateProcThreadAttribute(
                    attributes.pointer(),
                    0,
                    kind as usize,
                    values.as_ptr().cast(),
                    std::mem::size_of_val(values),
                    null_mut(),
                    null(),
                ) == 0
                {
                    return Err(io::Error::last_os_error());
                }
            }
            let mut startup: STARTUPINFOEXW = zeroed();
            startup.StartupInfo.cb = size_of::<STARTUPINFOEXW>() as u32;
            startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
            startup.StartupInfo.wShowWindow = SW_HIDE as u16;
            startup.StartupInfo.hStdInput = input_read.as_raw_handle();
            startup.StartupInfo.hStdOutput = output_write.as_raw_handle();
            startup.StartupInfo.hStdError = output_write.as_raw_handle();
            startup.lpAttributeList = attributes.pointer();
            let mut command = quote(executable.as_os_str());
            for arg in args {
                command.push(b' ' as u16);
                command.extend(quote(arg));
            }
            command.push(0);
            let mut information: PROCESS_INFORMATION = zeroed();
            if CreateProcessW(
                wide(executable).as_ptr(),
                command.as_mut_ptr(),
                null(),
                null(),
                1,
                EXTENDED_STARTUPINFO_PRESENT | CREATE_NO_WINDOW,
                null(),
                wide(cwd).as_ptr(),
                &startup.StartupInfo,
                &mut information,
            ) == 0
            {
                return Err(io::Error::last_os_error());
            }
            let _thread = owned(information.hThread)?;
            let child = Self {
                process: Process {
                    handle: owned(information.hProcess)?,
                    id: information.dwProcessId,
                },
                job,
                input: File::from(input_write),
            };
            Ok((child, File::from(output_read)))
        }
    }

    pub fn exited(&self) -> io::Result<bool> {
        match unsafe { WaitForSingleObject(self.process.handle.as_raw_handle(), 0) } {
            WAIT_OBJECT_0 => Ok(true),
            WAIT_TIMEOUT => Ok(false),
            _ => Err(io::Error::last_os_error()),
        }
    }

    pub fn stop(&mut self) -> io::Result<()> {
        let _ = self.input.write_all(b"stop\n");
        let _ = self.input.flush();
        unsafe {
            if WaitForSingleObject(self.process.handle.as_raw_handle(), 11000) != WAIT_OBJECT_0 {
                if TerminateJobObject(self.job.as_raw_handle(), 1) == 0 {
                    return Err(io::Error::last_os_error());
                }
            }
            if TerminateJobObject(self.job.as_raw_handle(), 0) == 0 {
                return Err(io::Error::last_os_error());
            }
            let deadline = Instant::now() + Duration::from_secs(3);
            loop {
                let mut accounting: JOBOBJECT_BASIC_ACCOUNTING_INFORMATION = zeroed();
                if QueryInformationJobObject(
                    self.job.as_raw_handle(),
                    JobObjectBasicAccountingInformation,
                    (&mut accounting as *mut JOBOBJECT_BASIC_ACCOUNTING_INFORMATION).cast(),
                    size_of::<JOBOBJECT_BASIC_ACCOUNTING_INFORMATION>() as u32,
                    null_mut(),
                ) == 0
                {
                    return Err(io::Error::last_os_error());
                }
                if accounting.ActiveProcesses == 0 {
                    return Ok(());
                }
                if Instant::now() > deadline {
                    return Err(io::Error::new(
                        io::ErrorKind::TimedOut,
                        "Core process tree has not exited",
                    ));
                }
                std::thread::sleep(Duration::from_millis(20));
            }
        }
    }

    pub fn abort(&mut self) -> io::Result<()> {
        if unsafe { TerminateJobObject(self.job.as_raw_handle(), 1) } == 0 {
            return Err(io::Error::last_os_error());
        }
        self.stop()
    }
}
