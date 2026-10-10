// SPDX-License-Identifier: GPL-3.0-or-later
#![windows_subsystem = "windows"]
use aora_windows_helpers::network::*;
use std::net::IpAddr;

fn run() -> Result<i32, Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let ip: IpAddr = args
        .first()
        .ok_or("Expected a server IP address")?
        .parse()?;
    let mode = match args.as_slice() {
        [_] => "icmp",
        [_, mode] if mode == "source" => "source",
        [_, mode, _] if mode == "tcp" => "tcp",
        _ => return Err("Invalid ping command".into()),
    };
    let _winsock = Winsock::start()?;
    let target = socket_address(ip);
    let loopback = ip.is_loopback();
    let source = if loopback {
        target
    } else {
        match physical_source(&target)? {
            Some(source) => source,
            None => {
                eprintln!("No physical network route to this server");
                return Ok(3);
            }
        }
    };
    if mode == "source" {
        println!("{}", address_ip(&source));
        return Ok(0);
    }
    if mode == "tcp" {
        let port: u16 = args[2].parse()?;
        if port == 0 {
            return Err("Invalid server port".into());
        }
        return Ok(match tcp(&target, &source, loopback, port)? {
            Some(latency) => {
                println!("{latency}");
                0
            }
            None => 2,
        });
    }
    Ok(match echo(&target, &source, loopback)? {
        Some(latency) => {
            println!("{latency}");
            0
        }
        None => {
            eprintln!("No ICMP reply");
            2
        }
    })
}

fn main() {
    let code = match run() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("{error}");
            1
        }
    };
    std::process::exit(code);
}
