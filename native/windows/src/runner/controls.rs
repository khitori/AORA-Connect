// SPDX-License-Identifier: GPL-3.0-or-later
use super::*;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::ReleaseCapture;
use windows_sys::Win32::UI::Shell::*;

const CHANNEL: &[u8] = b"aora/window\0";
const TRAY_MESSAGE: u32 = WM_APP + 40;
const DRAG_MESSAGE: u32 = WM_APP + 41;
const DESTROY_MESSAGE: u32 = WM_APP + 42;

#[derive(serde::Deserialize)]
struct TrayLabels {
    show: String,
    disconnect: String,
    exit: String,
    #[serde(default)]
    rtl: bool,
}

#[derive(Default)]
pub(super) struct Controls {
    messenger: *mut c_void,
    taskbar_created: u32,
    tray_added: bool,
    pub ready: bool,
    can_disconnect: bool,
    labels: Option<TrayLabels>,
}

impl Controls {
    unsafe fn tray_data(&self, hwnd: HWND) -> NOTIFYICONDATAW {
        let mut data: NOTIFYICONDATAW = zeroed();
        data.cbSize = size_of::<NOTIFYICONDATAW>() as u32;
        data.hWnd = hwnd;
        data.uID = 1;
        data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
        data.uCallbackMessage = TRAY_MESSAGE;
        data.hIcon = GetClassLongPtrW(hwnd, GCLP_HICON) as HICON;
        let tip = wide("AORA Connect");
        data.szTip[..tip.len()].copy_from_slice(&tip);
        data
    }

    pub unsafe fn add_tray(&mut self, hwnd: HWND) -> bool {
        if self.tray_added {
            return true;
        }
        let mut data = self.tray_data(hwnd);
        if Shell_NotifyIconW(NIM_ADD, &data) == 0 {
            return false;
        }
        data.Anonymous.uVersion = NOTIFYICON_VERSION_4;
        if Shell_NotifyIconW(NIM_SETVERSION, &data) == 0 {
            Shell_NotifyIconW(NIM_DELETE, &data);
            return false;
        }
        self.tray_added = true;
        true
    }

    pub unsafe fn remove_tray(&mut self, hwnd: HWND) {
        if self.tray_added {
            Shell_NotifyIconW(NIM_DELETE, &self.tray_data(hwnd));
            self.tray_added = false;
        }
    }

    pub unsafe fn uninstall(&mut self, hwnd: HWND) {
        self.remove_tray(hwnd);
        if !self.messenger.is_null() {
            FlutterDesktopMessengerSetCallback(
                self.messenger,
                CHANNEL.as_ptr().cast(),
                None,
                null_mut(),
            );
            self.messenger = null_mut();
        }
    }

    unsafe fn event(&self, message: &[u8]) -> bool {
        !self.messenger.is_null()
            && FlutterDesktopMessengerSend(
                self.messenger,
                CHANNEL.as_ptr().cast(),
                message.as_ptr(),
                message.len(),
            )
    }
}

pub(super) unsafe fn install(state: *mut Window, engine: *mut c_void) {
    let controls = &mut (*state).controls;
    controls.messenger = FlutterDesktopEngineGetMessenger(engine);
    controls.taskbar_created = RegisterWindowMessageW(wide("TaskbarCreated").as_ptr());
    // The runner is elevated; Explorer must still be able to deliver tray and
    // taskbar-restart notifications. No arbitrary channel commands are exposed.
    ChangeWindowMessageFilterEx((*state).hwnd, TRAY_MESSAGE, MSGFLT_ALLOW, null_mut());
    if controls.taskbar_created != 0 {
        ChangeWindowMessageFilterEx(
            (*state).hwnd,
            controls.taskbar_created,
            MSGFLT_ALLOW,
            null_mut(),
        );
    }
    FlutterDesktopMessengerSetCallback(
        controls.messenger,
        CHANNEL.as_ptr().cast(),
        Some(command),
        state.cast(),
    );
}

unsafe fn show(state: *mut Window) {
    if !(*state).smoke {
        ShowWindow((*state).hwnd, SW_RESTORE);
        SetForegroundWindow((*state).hwnd);
        if !(*state).child.is_null() {
            SetFocus((*state).child);
        }
    }
}

unsafe extern "C" fn command(
    messenger: *mut c_void,
    message: *const DesktopMessage,
    data: *mut c_void,
) {
    let state = data.cast::<Window>();
    let message = &*message;
    let bytes = if message.message.is_null() || message.message_size > 16384 {
        &[][..]
    } else {
        std::slice::from_raw_parts(message.message, message.message_size)
    };
    let hwnd = (*state).hwnd;
    let reply: &[u8] = match bytes {
        message if message.starts_with(b"localize:") => {
            match serde_json::from_slice::<TrayLabels>(&message[9..]) {
                Ok(labels) if [&labels.show, &labels.disconnect, &labels.exit]
                    .iter().all(|text| !text.is_empty() && text.len() <= 512 && !text.contains('\0')) => {
                    (*state).controls.labels = Some(labels);
                    b"ok"
                }
                _ => b"Invalid tray labels",
            }
        }
        b"ready" => {
            (*state).controls.ready = true;
            b"ok"
        }
        b"connected" => {
            (*state).controls.can_disconnect = true;
            b"ok"
        }
        b"disconnected" => {
            (*state).controls.can_disconnect = false;
            b"ok"
        }
        b"tray" => {
            // Never hide the user's only way back into the app if the shell
            // rejects the icon (for example when Explorer is unavailable).
            if (*state).controls.add_tray(hwnd) {
                ShowWindow(hwnd, SW_HIDE);
                b"ok"
            } else {
                b"Could not add the tray icon. The window remains open."
            }
        }
        b"show" => {
            show(state);
            b"ok"
        }
        b"drag" if !(*state).smoke => {
            PostMessageW(hwnd, DRAG_MESSAGE, 0, 0);
            b"ok"
        }
        b"close" => {
            PostMessageW(hwnd, WM_CLOSE, 0, 0);
            b"ok"
        }
        b"destroy" => {
            PostMessageW(hwnd, DESTROY_MESSAGE, 0, 0);
            b"ok"
        }
        _ if bytes.starts_with(b"install-update:") => {
            use std::os::windows::process::CommandExt;
            let result = (|| -> std::io::Result<()> {
                let path = std::str::from_utf8(&bytes[15..])
                    .map_err(|_| std::io::Error::other("Invalid update path"))?;
                let package = std::path::Path::new(path).canonicalize()?;
                let root = std::path::PathBuf::from(
                    std::env::var_os("LOCALAPPDATA")
                        .ok_or_else(|| std::io::Error::other("Missing application storage"))?,
                )
                .join("AORAConnect/runtime")
                .canonicalize()?;
                if !package.starts_with(root) {
                    return Err(std::io::Error::other(
                        "Update is outside application storage",
                    ));
                }
                let helper = package.parent().unwrap().join("aoravpn_update.exe");
                std::process::Command::new(helper)
                    .arg("install")
                    .arg(package)
                    .arg(std::process::id().to_string())
                    .creation_flags(CREATE_BREAKAWAY_FROM_JOB | CREATE_NO_WINDOW)
                    .spawn()?;
                Ok(())
            })();
            if result.is_ok() {
                b"ok"
            } else {
                b"Could not start update installer"
            }
        }
        _ => b"Unsupported window command",
    };
    if !message.response_handle.is_null() {
        FlutterDesktopMessengerSendResponse(
            messenger,
            message.response_handle,
            reply.as_ptr(),
            reply.len(),
        );
    }
}

unsafe fn tray_menu(state: *mut Window) {
    let hwnd = (*state).hwnd;
    let menu = CreatePopupMenu();
    if menu.is_null() {
        show(state);
        return;
    }
    let labels = (*state).controls.labels.as_ref();
    AppendMenuW(menu, MF_STRING, 1, wide(labels.map_or("Show AORA Connect", |labels| labels.show.as_str())).as_ptr());
    AppendMenuW(
        menu,
        MF_STRING
            | if (*state).controls.can_disconnect {
                0
            } else {
                MF_GRAYED
            },
        2,
        wide(labels.map_or("Disconnect", |labels| labels.disconnect.as_str())).as_ptr(),
    );
    AppendMenuW(menu, MF_SEPARATOR, 0, null());
    AppendMenuW(menu, MF_STRING, 3, wide(labels.map_or("Exit", |labels| labels.exit.as_str())).as_ptr());
    let mut cursor = zeroed();
    GetCursorPos(&mut cursor);
    SetForegroundWindow(hwnd);
    let selected = TrackPopupMenu(
        menu,
        TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON
            | if labels.is_some_and(|labels| labels.rtl) { TPM_LAYOUTRTL } else { 0 },
        cursor.x,
        cursor.y,
        0,
        hwnd,
        null(),
    );
    DestroyMenu(menu);
    PostMessageW(hwnd, WM_NULL, 0, 0);
    match selected {
        1 => show(state),
        2 => {
            if !(*state).controls.event(b"disconnect") {
                show(state);
            }
        }
        3 => {
            PostMessageW(hwnd, WM_CLOSE, 0, 0);
        }
        _ => {
            Shell_NotifyIconW(NIM_SETFOCUS, &(*state).controls.tray_data(hwnd));
        }
    }
}

pub(super) unsafe fn handle(state: *mut Window, message: u32, lparam: LPARAM) -> Option<LRESULT> {
    let hwnd = (*state).hwnd;
    if message != 0 && message == (*state).controls.taskbar_created && (*state).controls.tray_added
    {
        (*state).controls.tray_added = false;
        if !(*state).controls.add_tray(hwnd) {
            show(state);
        }
        return Some(0);
    }
    match message {
        WM_CLOSE if !(*state).controls.messenger.is_null() => {
            // Dart performs the same awaited core/ping cleanup for the custom
            // button, Alt+F4 and tray Exit, then sends "destroy" back.
            if !(*state).controls.event(b"exit") {
                show(state);
            }
            Some(0)
        }
        DESTROY_MESSAGE => {
            DestroyWindow(hwnd);
            Some(0)
        }
        DRAG_MESSAGE => {
            ReleaseCapture();
            let mut cursor = zeroed();
            GetCursorPos(&mut cursor);
            let position = (cursor.x as u16 as u32 | ((cursor.y as u16 as u32) << 16)) as isize;
            SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION as usize, position);
            Some(0)
        }
        TRAY_MESSAGE => {
            match (lparam as u32) & 0xffff {
                WM_LBUTTONUP | WM_LBUTTONDBLCLK | NIN_SELECT | 1025 => show(state),
                WM_RBUTTONUP | WM_CONTEXTMENU => tray_menu(state),
                _ => {}
            }
            Some(0)
        }
        _ => None,
    }
}
