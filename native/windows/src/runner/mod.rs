// SPDX-License-Identifier: GPL-3.0-or-later
// Window-host behavior adapted from Flutter's Windows runner template.
// Copyright 2014 The Flutter Authors. Upstream notice is retained in
// native/windows/LICENSE-FlutterWindowsRunner.txt.
mod controls;
mod ffi;

use crate::{owned, wide};
use ffi::*;
use std::ffi::{c_void, CString};
use std::io;
use std::mem::{size_of, zeroed};
use std::os::windows::io::AsRawHandle;
use std::ptr::{null, null_mut};
use windows_sys::Win32::Foundation::*;
use windows_sys::Win32::Graphics::{Dwm::*, Gdi::*};
use windows_sys::Win32::System::{Com::*, Console::*, JobObjects::*, Registry::*, Threading::*};
use windows_sys::Win32::UI::{HiDpi::*, Input::KeyboardAndMouse::SetFocus, WindowsAndMessaging::*};

struct Com;
impl Drop for Com {
    fn drop(&mut self) {
        unsafe {
            CoUninitialize();
        }
    }
}

struct Window {
    hwnd: HWND,
    child: HWND,
    controller: *mut c_void,
    smoke: bool,
    first_frame: bool,
    controls: controls::Controls,
}
impl Drop for Window {
    fn drop(&mut self) {
        unsafe {
            self.controls.uninstall(self.hwnd);
            let controller = self.controller;
            self.controller = null_mut();
            self.child = null_mut();
            if !controller.is_null() {
                FlutterDesktopViewControllerDestroy(controller);
            }
            if !self.hwnd.is_null() && IsWindow(self.hwnd) != 0 {
                DestroyWindow(self.hwnd);
            }
        }
    }
}

unsafe fn update_theme(hwnd: HWND) {
    let mut light = 1u32;
    let mut size = size_of::<u32>() as u32;
    if RegGetValueW(
        HKEY_CURRENT_USER,
        wide("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize").as_ptr(),
        wide("AppsUseLightTheme").as_ptr(),
        RRF_RT_REG_DWORD,
        null_mut(),
        (&mut light as *mut u32).cast(),
        &mut size,
    ) == 0
    {
        let dark: i32 = i32::from(light == 0);
        DwmSetWindowAttribute(
            hwnd,
            DWMWA_USE_IMMERSIVE_DARK_MODE as u32,
            (&dark as *const i32).cast(),
            size_of::<i32>() as u32,
        );
    }
}

unsafe extern "C" fn first_frame(data: *mut c_void) {
    let state = data.cast::<Window>();
    (*state).first_frame = true;
    if (*state).smoke {
        // Smoke mode never shows a window or connects a VPN. It allows the first
        // Flutter frame and event dispatch to complete before closing normally.
        SetTimer((*state).hwnd, 1, 250, None);
    } else {
        ShowWindow((*state).hwnd, SW_SHOWNORMAL);
    }
}

unsafe extern "system" fn window_proc(
    hwnd: HWND,
    message: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    if message == WM_NCCREATE {
        let create = &*(lparam as *const CREATESTRUCTW);
        let state = create.lpCreateParams.cast::<Window>();
        (*state).hwnd = hwnd;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, state as isize);
        EnableNonClientDpiScaling(hwnd);
    }
    let state = GetWindowLongPtrW(hwnd, GWLP_USERDATA) as *mut Window;
    if !state.is_null() {
        if let Some(result) = controls::handle(state, message, lparam) {
            return result;
        }
        let controller = (*state).controller;
        if !controller.is_null() {
            let mut result = 0;
            if FlutterDesktopViewControllerHandleTopLevelWindowProc(
                controller,
                hwnd,
                message,
                wparam,
                lparam,
                &mut result,
            ) {
                return result;
            }
        }
        match message {
            WM_SYSCOMMAND
                if [SC_SIZE as usize, SC_MAXIMIZE as usize].contains(&(wparam & 0xfff0)) =>
            {
                return 0
            }
            WM_DPICHANGED => {
                let rect = &*(lparam as *const RECT);
                SetWindowPos(
                    hwnd,
                    null_mut(),
                    rect.left,
                    rect.top,
                    rect.right - rect.left,
                    rect.bottom - rect.top,
                    SWP_NOZORDER | SWP_NOACTIVATE,
                );
                return 0;
            }
            WM_SIZE if !(*state).child.is_null() => {
                let mut rect = zeroed();
                GetClientRect(hwnd, &mut rect);
                MoveWindow((*state).child, 0, 0, rect.right, rect.bottom, 1);
                return 0;
            }
            WM_ACTIVATE if !(*state).child.is_null() => {
                SetFocus((*state).child);
                return 0;
            }
            WM_FONTCHANGE if !controller.is_null() => {
                FlutterDesktopEngineReloadSystemFonts(FlutterDesktopViewControllerGetEngine(
                    controller,
                ));
                return 0;
            }
            WM_DWMCOLORIZATIONCOLORCHANGED => {
                update_theme(hwnd);
                return 0;
            }
            WM_TIMER if (*state).smoke && wparam == 1 => {
                KillTimer(hwnd, 1);
                let style = GetWindowLongPtrW(hwnd, GWL_STYLE) as u32;
                if IsWindowVisible(hwnd) != 0
                    || style & (WS_CAPTION | WS_THICKFRAME | WS_MAXIMIZEBOX) != 0
                    || !(*state).controls.ready
                {
                    eprintln!("Rust runner smoke: hidden/fixed-size window invariant failed");
                    (*state).first_frame = false;
                }
                if !(*state).controls.add_tray(hwnd) {
                    eprintln!("Rust runner smoke: tray registration failed");
                    (*state).first_frame = false;
                }
                (*state).controls.remove_tray(hwnd);
                // Exercise the real native -> Dart cleanup -> native destroy
                // round trip. The fixture contains no core or firewall helpers.
                PostMessageW(hwnd, WM_CLOSE, 0, 0);
                return 0;
            }
            WM_DESTROY => {
                (*state).controls.remove_tray(hwnd);
                (*state).hwnd = null_mut();
                PostQuitMessage(0);
                return 0;
            }
            WM_NCDESTROY => {
                SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
            }
            _ => {}
        }
    }
    DefWindowProcW(hwnd, message, wparam, lparam)
}

fn run(instance: HINSTANCE) -> Result<i32, Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let smoke = args.iter().any(|arg| arg == "--runner-smoke-test");
    unsafe {
        let app_mutex = owned(CreateMutexW(
            null(),
            0,
            wide("Local\\AORAConnectApp").as_ptr(),
        ))?;
        if GetLastError() == ERROR_ALREADY_EXISTS && !smoke {
            return Err("AORA Connect is already running. Open it from the tray.".into());
        }
        // Keep Flutter debug output on the parent's terminal without creating a
        // visible console when launched from Explorer.
        if !smoke {
            AttachConsole(ATTACH_PARENT_PROCESS);
        }
        let com_result = CoInitializeEx(null(), COINIT_APARTMENTTHREADED as u32);
        if com_result < 0 {
            return Err(format!("COM initialization failed ({com_result})").into());
        }
        let _com = Com;
        let job = owned(CreateJobObjectW(null(), null()))?;
        let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = zeroed();
        limits.BasicLimitInformation.LimitFlags =
            JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE | JOB_OBJECT_LIMIT_BREAKAWAY_OK;
        if SetInformationJobObject(
            job.as_raw_handle(),
            JobObjectExtendedLimitInformation,
            (&limits as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
            size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
        ) == 0
            || AssignProcessToJobObject(job.as_raw_handle(), GetCurrentProcess()) == 0
        {
            return Err(io::Error::last_os_error().into());
        }
        let class = wide("AORA_CONNECT_RUST_WINDOW");
        let mut window_class: WNDCLASSW = zeroed();
        window_class.lpfnWndProc = Some(window_proc);
        window_class.hInstance = instance;
        window_class.hCursor = LoadCursorW(null_mut(), IDC_ARROW);
        window_class.hIcon = LoadIconW(instance, 101usize as *const u16);
        window_class.lpszClassName = class.as_ptr();
        window_class.style = CS_HREDRAW | CS_VREDRAW;
        if RegisterClassW(&window_class) == 0 {
            return Err(io::Error::last_os_error().into());
        }
        let monitor = MonitorFromPoint(POINT { x: 10, y: 10 }, MONITOR_DEFAULTTONEAREST);
        let dpi = FlutterDesktopGetDpiForMonitor(monitor).max(96);
        let style = WS_POPUP | WS_SYSMENU | WS_MINIMIZEBOX;
        let mut frame = RECT {
            left: 0,
            top: 0,
            right: (420 * dpi / 96) as i32,
            bottom: (740 * dpi / 96) as i32,
        };
        if AdjustWindowRectExForDpi(&mut frame, style, 0, 0, dpi) == 0 {
            return Err(io::Error::last_os_error().into());
        }
        let mut width = frame.right - frame.left;
        let mut height = frame.bottom - frame.top;
        let (mut left, mut top) = (10, 10);
        let mut monitor_info: MONITORINFO = zeroed();
        monitor_info.cbSize = size_of::<MONITORINFO>() as u32;
        if GetMonitorInfoW(monitor, &mut monitor_info) != 0 {
            let work = monitor_info.rcWork;
            width = width.min(work.right - work.left);
            height = height.min(work.bottom - work.top);
            left = work.left + (work.right - work.left - width) / 2;
            top = work.top + (work.bottom - work.top - height) / 2;
        }
        let mut state = Box::new(Window {
            hwnd: null_mut(),
            child: null_mut(),
            controller: null_mut(),
            smoke,
            first_frame: false,
            controls: controls::Controls::default(),
        });
        let hwnd = CreateWindowExW(
            0,
            class.as_ptr(),
            wide("AORA Connect").as_ptr(),
            style,
            left,
            top,
            width,
            height,
            null_mut(),
            null_mut(),
            instance,
            (&mut *state as *mut Window).cast(),
        );
        if hwnd.is_null() {
            return Err(io::Error::last_os_error().into());
        }
        update_theme(hwnd);
        let corners: i32 = 2; // DWMWCP_ROUND; ignored on older Windows versions.
        DwmSetWindowAttribute(
            hwnd,
            DWMWA_WINDOW_CORNER_PREFERENCE as u32,
            (&corners as *const i32).cast(),
            size_of::<i32>() as u32,
        );
        let data = std::env::current_exe()?
            .parent()
            .ok_or("Missing executable directory")?
            .join("data");
        let assets = wide(data.join("flutter_assets"));
        let icu = wide(data.join("icudtl.dat"));
        let aot = wide(data.join("app.so"));
        let dart_args: Vec<_> = args
            .iter()
            .filter(|arg| *arg != "--runner-smoke-test")
            .map(|arg| CString::new(arg.as_str()))
            .collect::<Result<_, _>>()?;
        let pointers: Vec<_> = dart_args.iter().map(|arg| arg.as_ptr()).collect();
        let mut properties: EngineProperties = zeroed();
        properties.assets_path = assets.as_ptr();
        properties.icu_data_path = icu.as_ptr();
        properties.aot_library_path = if data.join("app.so").exists() {
            aot.as_ptr()
        } else {
            null()
        };
        properties.dart_entrypoint_argc = pointers.len() as i32;
        properties.dart_entrypoint_argv = pointers.as_ptr();
        let engine = FlutterDesktopEngineCreate(&properties);
        if engine.is_null() {
            return Err("Could not create Flutter engine".into());
        }
        let mut client: RECT = zeroed();
        GetClientRect(hwnd, &mut client);
        state.controller = FlutterDesktopViewControllerCreate(client.right, client.bottom, engine);
        // The view controller takes engine ownership even when creation fails.
        if state.controller.is_null() {
            return Err("Could not create Flutter view".into());
        }
        controls::install((&mut *state) as *mut Window, engine);
        register(FlutterDesktopViewControllerGetEngine(state.controller));
        state.child =
            FlutterDesktopViewGetHWND(FlutterDesktopViewControllerGetView(state.controller));
        if state.child.is_null() {
            return Err("Flutter returned no native view".into());
        }
        SetParent(state.child, hwnd);
        MoveWindow(state.child, 0, 0, client.right, client.bottom, 1);
        if !smoke {
            SetFocus(state.child);
        }
        FlutterDesktopEngineSetNextFrameCallback(
            FlutterDesktopViewControllerGetEngine(state.controller),
            Some(first_frame),
            (&mut *state as *mut Window).cast(),
        );
        FlutterDesktopViewControllerForceRedraw(state.controller);
        let mut message: MSG = zeroed();
        loop {
            let status = GetMessageW(&mut message, null_mut(), 0, 0);
            if status == -1 {
                return Err(io::Error::last_os_error().into());
            }
            if status == 0 {
                break;
            }
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        if smoke {
            if !state.first_frame {
                return Err("Flutter did not render a first frame".into());
            }
            println!("AORA_RUNNER_SMOKE_OK: first frame, plugin registration, window dispatch");
        }
        drop(state);
        UnregisterClassW(class.as_ptr(), instance);
        // The job handle remains owned until process exit, matching the old
        // runner. Closing it while this process is alive would terminate us too.
        std::mem::forget(job);
        std::mem::forget(app_mutex);
        Ok(0)
    }
}

/// Entry point called by the Windows CRT. No application-owned C++ shim is used.
#[no_mangle]
pub extern "system" fn wWinMain(instance: HINSTANCE, _: HINSTANCE, _: *mut u16, _: i32) -> i32 {
    match std::panic::catch_unwind(|| run(instance)) {
        Ok(Ok(code)) => code,
        result => {
            let error = match result {
                Ok(Err(error)) => error.to_string(),
                _ => "Rust runner panicked".into(),
            };
            unsafe {
                MessageBoxW(
                    null_mut(),
                    wide(error).as_ptr(),
                    wide("AORA Connect").as_ptr(),
                    MB_OK | MB_ICONERROR,
                );
            }
            1
        }
    }
}
