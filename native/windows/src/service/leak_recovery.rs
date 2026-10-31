// SPDX-License-Identifier: GPL-3.0-or-later
#[cfg(not(feature = "service-scm-fixture"))]
use std::{
    io,
    ptr::{null, null_mut},
};
#[cfg(not(feature = "service-scm-fixture"))]
use windows_sys::{
    core::GUID,
    Win32::{Foundation::*, NetworkManagement::WindowsFilteringPlatform::*},
};

pub fn clear_legacy_policy() -> std::io::Result<()> {
    #[cfg(feature = "service-scm-fixture")]
    return Ok(());
    #[cfg(not(feature = "service-scm-fixture"))]
    unsafe {
        fn check(code: u32) -> io::Result<()> {
            if code == 0 {
                Ok(())
            } else {
                Err(io::Error::from_raw_os_error(code as i32))
            }
        }
        let key = GUID {
            data1: 0x87f23d52,
            data2: 0xc094,
            data3: 0x4e5f,
            data4: [0x9e, 0x7e, 0xb7, 0xea, 0x19, 0xb9, 0x67, 0x60],
        };
        let mut engine = null_mut();
        check(FwpmEngineOpen0(null(), 10, null(), null(), &mut engine))?;
        let result = (|| {
            check(FwpmTransactionBegin0(engine, 0))?;
            for index in 1..=16 {
                let filter = GUID {
                    data1: key.data1 + index,
                    ..key
                };
                let code = FwpmFilterDeleteByKey0(engine, &filter);
                if code != FWP_E_FILTER_NOT_FOUND as u32 {
                    check(code)?;
                }
            }
            let code = FwpmSubLayerDeleteByKey0(engine, &key);
            if code != FWP_E_SUBLAYER_NOT_FOUND as u32 {
                check(code)?;
            }
            check(FwpmTransactionCommit0(engine))
        })();
        if result.is_err() {
            FwpmTransactionAbort0(engine);
        }
        FwpmEngineClose0(engine);
        result
    }
}
