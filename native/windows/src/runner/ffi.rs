// SPDX-License-Identifier: GPL-3.0-or-later
#![allow(non_snake_case)]
use std::ffi::c_void;
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows_sys::Win32::Graphics::Gdi::HMONITOR;

include!(concat!(env!("OUT_DIR"), "/flutter_generated.rs"));

extern "C" {
    pub fn FlutterDesktopEngineCreate(properties: *const EngineProperties) -> *mut c_void;
    pub fn FlutterDesktopViewControllerCreate(
        width: i32,
        height: i32,
        engine: *mut c_void,
    ) -> *mut c_void;
    pub fn FlutterDesktopViewControllerDestroy(controller: *mut c_void);
    pub fn FlutterDesktopViewControllerGetEngine(controller: *mut c_void) -> *mut c_void;
    pub fn FlutterDesktopViewControllerGetView(controller: *mut c_void) -> *mut c_void;
    pub fn FlutterDesktopViewGetHWND(view: *mut c_void) -> HWND;
    pub fn FlutterDesktopViewControllerForceRedraw(controller: *mut c_void);
    pub fn FlutterDesktopViewControllerHandleTopLevelWindowProc(
        controller: *mut c_void,
        hwnd: HWND,
        message: u32,
        wparam: WPARAM,
        lparam: LPARAM,
        result: *mut LRESULT,
    ) -> bool;
    pub fn FlutterDesktopEngineGetPluginRegistrar(
        engine: *mut c_void,
        name: *const std::ffi::c_char,
    ) -> *mut c_void;
    pub fn FlutterDesktopEngineReloadSystemFonts(engine: *mut c_void);
    pub fn FlutterDesktopEngineSetNextFrameCallback(
        engine: *mut c_void,
        callback: Option<unsafe extern "C" fn(*mut c_void)>,
        data: *mut c_void,
    );
    pub fn FlutterDesktopGetDpiForMonitor(monitor: HMONITOR) -> u32;
}

pub unsafe fn register(engine: *mut c_void) {
    register_plugins(engine);
}
