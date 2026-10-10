// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
// Compatibility/recovery only. Never install persistent blocking filters.
use aora_windows_helpers::{network::tun_luid, wide};
use std::mem::zeroed;
use std::ptr::{null, null_mut};
use windows_sys::core::GUID;
use windows_sys::Win32::Foundation::*;
use windows_sys::Win32::NetworkManagement::WindowsFilteringPlatform::*;

const SUBLAYER: GUID = GUID {
    data1: 0x87f23d52,
    data2: 0xc094,
    data3: 0x4e5f,
    data4: [0x9e, 0x7e, 0xb7, 0xea, 0x19, 0xb9, 0x67, 0x60],
};
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;

fn key(index: u32) -> GUID {
    GUID {
        data1: SUBLAYER.data1 + index,
        ..SUBLAYER
    }
}

fn check(code: u32, action: &str) -> Result<()> {
    if code == 0 {
        Ok(())
    } else {
        Err(format!("{action} failed (Windows error {code})").into())
    }
}

struct Engine(HANDLE);
impl Engine {
    fn open() -> Result<Self> {
        let mut handle = null_mut();
        unsafe {
            check(
                FwpmEngineOpen0(null(), 10, null(), null(), &mut handle),
                "Open filtering engine",
            )?;
        }
        Ok(Self(handle))
    }
    fn delete_filter(&self, index: u32) -> Result<()> {
        let code = unsafe { FwpmFilterDeleteByKey0(self.0, &key(index)) };
        if code == FWP_E_FILTER_NOT_FOUND as u32 {
            Ok(())
        } else {
            check(code, "Delete firewall filter")
        }
    }
    fn has_filter(&self, index: u32) -> Result<bool> {
        let mut filter = null_mut();
        unsafe {
            let code = FwpmFilterGetByKey0(self.0, &key(index), &mut filter);
            if code == FWP_E_FILTER_NOT_FOUND as u32 {
                return Ok(false);
            }
            check(code, "Read firewall filter")?;
            FwpmFreeMemory0((&mut filter as *mut *mut FWPM_FILTER0).cast());
        }
        Ok(true)
    }
    fn transaction(&self, action: impl FnOnce() -> Result<()>) -> Result<()> {
        unsafe {
            check(
                FwpmTransactionBegin0(self.0, 0),
                "Begin firewall transaction",
            )?;
        }
        let mut transaction = Transaction {
            engine: self,
            active: true,
        };
        action()?;
        unsafe {
            check(
                FwpmTransactionCommit0(self.0),
                "Commit firewall transaction",
            )?;
        }
        transaction.active = false;
        Ok(())
    }
    fn revoke_tun(&self) -> Result<()> {
        for index in [5, 6, 13, 14] {
            self.delete_filter(index)?;
        }
        Ok(())
    }
    // Retains the old permit-only command for compatibility with recovery tools.
    // This does not create a sublayer or any blocking policy.
    fn allow_tun(&self) -> Result<()> {
        let mut luid = tun_luid()?;
        self.transaction(|| {
            self.revoke_tun()?;
            for (index, layer) in [
                (5, FWPM_LAYER_ALE_AUTH_CONNECT_V4),
                (6, FWPM_LAYER_ALE_AUTH_CONNECT_V6),
                (13, FWPM_LAYER_OUTBOUND_TRANSPORT_V4),
                (14, FWPM_LAYER_OUTBOUND_TRANSPORT_V6),
            ] {
                unsafe {
                    let mut condition: FWPM_FILTER_CONDITION0 = zeroed();
                    condition.fieldKey = FWPM_CONDITION_IP_LOCAL_INTERFACE;
                    condition.matchType = FWP_MATCH_EQUAL;
                    condition.conditionValue.r#type = FWP_UINT64;
                    condition.conditionValue.Anonymous.uint64 = &mut luid;
                    let mut name = wide("AORA Connect Kill Switch");
                    let mut filter: FWPM_FILTER0 = zeroed();
                    filter.filterKey = key(index);
                    filter.displayData.name = name.as_mut_ptr();
                    filter.flags = FWPM_FILTER_FLAG_PERSISTENT;
                    filter.layerKey = layer;
                    filter.subLayerKey = SUBLAYER;
                    filter.weight.r#type = FWP_UINT8;
                    filter.weight.Anonymous.uint8 = 15;
                    filter.action.r#type = FWP_ACTION_PERMIT;
                    filter.numFilterConditions = 1;
                    filter.filterCondition = &mut condition;
                    check(
                        FwpmFilterAdd0(self.0, &filter, null_mut(), null_mut()),
                        "Add TUN permit filter",
                    )?;
                }
            }
            Ok(())
        })
    }
}
impl Drop for Engine {
    fn drop(&mut self) {
        unsafe {
            FwpmEngineClose0(self.0);
        }
    }
}

struct Transaction<'a> {
    engine: &'a Engine,
    active: bool,
}
impl Drop for Transaction<'_> {
    fn drop(&mut self) {
        if self.active {
            unsafe {
                FwpmTransactionAbort0(self.engine.0);
            }
        }
    }
}

fn run() -> Result<()> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let command = args.first().ok_or("Missing Kill Switch command")?.as_str();
    if command == "arm" {
        return Err("Persistent Kill Switch arming is disabled. Restart the updated app.".into());
    }
    if args.len() != 1 {
        return Err("Invalid Kill Switch command".into());
    }
    if !["status", "disarm", "allow-tun", "revoke-tun"].contains(&command) {
        return Err("Invalid Kill Switch command".into());
    }
    let engine = Engine::open()?;
    match command {
        "status" => {
            let states: Vec<_> = [7, 8, 15, 16]
                .into_iter()
                .map(|index| engine.has_filter(index))
                .collect::<Result<_>>()?;
            if states.iter().any(|value| *value != states[0]) {
                return Err("Incomplete Kill Switch policy".into());
            }
            println!("{}", if states[0] { "armed" } else { "disarmed" });
            Ok(())
        }
        "disarm" => engine.transaction(|| {
            for index in 1..=16 {
                engine.delete_filter(index)?;
            }
            let code = unsafe { FwpmSubLayerDeleteByKey0(engine.0, &SUBLAYER) };
            if code == FWP_E_SUBLAYER_NOT_FOUND as u32 {
                Ok(())
            } else {
                check(code, "Delete firewall sublayer")
            }
        }),
        "revoke-tun" => engine.transaction(|| engine.revoke_tun()),
        "allow-tun" => engine.allow_tun(),
        _ => unreachable!(),
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn recovery_keys_match_the_original_cpp_namespace() {
        assert_eq!(key(1).data1, 0x87f23d53);
        assert_eq!(key(16).data1, 0x87f23d62);
        assert_eq!(key(7).data4, SUBLAYER.data4);
    }
}
