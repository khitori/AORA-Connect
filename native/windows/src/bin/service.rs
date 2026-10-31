// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
use aora_windows_helpers::service;

fn main() {
    if let Err(error) = service::run(std::env::args().skip(1).collect()) {
        eprintln!("AORA Connect service: {error}");
        std::process::exit(1);
    }
}
