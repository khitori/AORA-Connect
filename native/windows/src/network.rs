// SPDX-License-Identifier: GPL-3.0-or-later
use std::io;
use std::mem::{size_of, zeroed};
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};
use std::ptr::{null, null_mut};
use windows_sys::Win32::Foundation::{ERROR_BUFFER_OVERFLOW, INVALID_HANDLE_VALUE};
use windows_sys::Win32::NetworkManagement::IpHelper::*;
use windows_sys::Win32::NetworkManagement::Ndis::IfOperStatusUp;
use windows_sys::Win32::Networking::WinSock::*;

pub struct Winsock;
impl Winsock {
    pub fn start() -> io::Result<Self> {
        unsafe {
            let mut data = zeroed();
            let code = WSAStartup(0x0202, &mut data);
            if code != 0 {
                return Err(io::Error::from_raw_os_error(code));
            }
            Ok(Self)
        }
    }
}
impl Drop for Winsock {
    fn drop(&mut self) {
        unsafe {
            WSACleanup();
        }
    }
}

pub fn socket_address(ip: IpAddr) -> SOCKADDR_INET {
    unsafe {
        let mut address: SOCKADDR_INET = zeroed();
        match ip {
            IpAddr::V4(value) => {
                address.Ipv4.sin_family = AF_INET;
                address.Ipv4.sin_addr.S_un.S_addr = u32::from_ne_bytes(value.octets());
            }
            IpAddr::V6(value) => {
                address.Ipv6.sin6_family = AF_INET6;
                address.Ipv6.sin6_addr.u.Byte = value.octets();
            }
        }
        address
    }
}

pub fn address_ip(address: &SOCKADDR_INET) -> IpAddr {
    unsafe {
        if address.si_family == AF_INET {
            IpAddr::V4(Ipv4Addr::from(
                address.Ipv4.sin_addr.S_un.S_addr.to_ne_bytes(),
            ))
        } else {
            IpAddr::V6(Ipv6Addr::from(address.Ipv6.sin6_addr.u.Byte))
        }
    }
}

pub fn sockaddr_len(address: &SOCKADDR_INET) -> i32 {
    unsafe {
        if address.si_family == AF_INET {
            size_of::<SOCKADDR_IN>() as i32
        } else {
            size_of::<SOCKADDR_IN6>() as i32
        }
    }
}

pub struct Adapters(Vec<u64>);
impl Adapters {
    pub fn load() -> io::Result<Self> {
        let mut size = 0;
        unsafe {
            let code = GetAdaptersAddresses(
                AF_UNSPEC as u32,
                GAA_FLAG_INCLUDE_GATEWAYS,
                null(),
                null_mut(),
                &mut size,
            );
            if code != ERROR_BUFFER_OVERFLOW {
                return Err(io::Error::from_raw_os_error(code as i32));
            }
            for _ in 0..3 {
                let mut buffer = vec![0u64; (size as usize).div_ceil(8)];
                let code = GetAdaptersAddresses(
                    AF_UNSPEC as u32,
                    GAA_FLAG_INCLUDE_GATEWAYS,
                    null(),
                    buffer.as_mut_ptr().cast(),
                    &mut size,
                );
                if code == 0 {
                    return Ok(Self(buffer));
                }
                if code != ERROR_BUFFER_OVERFLOW {
                    return Err(io::Error::from_raw_os_error(code as i32));
                }
            }
        }
        Err(io::Error::other(
            "Network adapters changed during enumeration",
        ))
    }

    pub fn first(&self) -> *const IP_ADAPTER_ADDRESSES_LH {
        self.0.as_ptr().cast()
    }
}

unsafe fn is_aora_name(name: *const u16) -> bool {
    if name.is_null() {
        return false;
    }
    let mut length = 0;
    while *name.add(length) != 0 {
        length += 1;
    }
    String::from_utf16_lossy(std::slice::from_raw_parts(name, length)).contains("AORA")
}

pub fn physical_source(target: &SOCKADDR_INET) -> io::Result<Option<SOCKADDR_INET>> {
    let adapters = Adapters::load()?;
    let mut best = u64::MAX;
    let mut result = None;
    unsafe {
        let mut pointer = adapters.first();
        while !pointer.is_null() {
            let adapter = &*pointer;
            pointer = adapter.Next;
            if adapter.OperStatus != IfOperStatusUp
                || ![IF_TYPE_ETHERNET_CSMACD, IF_TYPE_IEEE80211].contains(&adapter.IfType)
                || is_aora_name(adapter.FriendlyName)
            {
                continue;
            }
            let mut gateway = adapter.FirstGatewayAddress;
            let mut matching_gateway = false;
            while !gateway.is_null() {
                let entry = &*gateway;
                if !entry.Address.lpSockaddr.is_null()
                    && (*entry.Address.lpSockaddr).sa_family == target.si_family
                {
                    matching_gateway = true;
                }
                gateway = entry.Next;
            }
            if !matching_gateway {
                continue;
            }
            let mut route: MIB_IPFORWARD_ROW2 = zeroed();
            let mut candidate: SOCKADDR_INET = zeroed();
            if GetBestRoute2(
                &adapter.Luid,
                0,
                null(),
                target,
                0,
                &mut route,
                &mut candidate,
            ) != 0
            {
                continue;
            }
            let metric = route.Metric as u64
                + if target.si_family == AF_INET {
                    adapter.Ipv4Metric as u64
                } else {
                    adapter.Ipv6Metric as u64
                };
            if metric < best {
                best = metric;
                result = Some(candidate);
            }
        }
    }
    Ok(result)
}

pub fn tun_luid() -> io::Result<u64> {
    let adapters = Adapters::load()?;
    unsafe {
        let mut pointer = adapters.first();
        while !pointer.is_null() {
            let adapter = &*pointer;
            let mut address = adapter.FirstUnicastAddress;
            while !address.is_null() {
                let value = (*address).Address.lpSockaddr;
                if !value.is_null() && (*value).sa_family == AF_INET {
                    let value = &*value.cast::<SOCKADDR_IN>();
                    if value.sin_addr.S_un.S_addr.to_ne_bytes() == [172, 29, 0, 1] {
                        return Ok(adapter.Luid.Value);
                    }
                }
                address = (*address).Next;
            }
            pointer = adapter.Next;
        }
    }
    Err(io::Error::other("TUN adapter was not found"))
}

struct Icmp(windows_sys::Win32::Foundation::HANDLE);
impl Drop for Icmp {
    fn drop(&mut self) {
        unsafe {
            IcmpCloseHandle(self.0);
        }
    }
}

pub fn echo(
    target: &SOCKADDR_INET,
    source: &SOCKADDR_INET,
    loopback: bool,
) -> io::Result<Option<u32>> {
    unsafe {
        let v4 = target.si_family == AF_INET;
        let raw = if v4 {
            IcmpCreateFile()
        } else {
            Icmp6CreateFile()
        };
        if raw == INVALID_HANDLE_VALUE {
            return Err(io::Error::last_os_error());
        }
        let icmp = Icmp(raw);
        let payload = b"AORA Connect\0";
        let mut buffer = [0u64; 64];
        let replies = if v4 {
            IcmpSendEcho2Ex(
                icmp.0,
                null_mut(),
                None,
                null(),
                if loopback {
                    0
                } else {
                    source.Ipv4.sin_addr.S_un.S_addr
                },
                target.Ipv4.sin_addr.S_un.S_addr,
                payload.as_ptr().cast(),
                payload.len() as u16,
                null(),
                buffer.as_mut_ptr().cast(),
                512,
                2000,
            )
        } else {
            let mut local: SOCKADDR_IN6 = zeroed();
            local.sin6_family = AF_INET6;
            if !loopback {
                local = source.Ipv6;
            }
            Icmp6SendEcho2(
                icmp.0,
                null_mut(),
                None,
                null(),
                &local,
                &target.Ipv6,
                payload.as_ptr().cast(),
                payload.len() as u16,
                null(),
                buffer.as_mut_ptr().cast(),
                512,
                2000,
            )
        };
        if replies == 0 {
            return Ok(None);
        }
        let (status, latency) = if v4 {
            let reply = &*buffer.as_ptr().cast::<ICMP_ECHO_REPLY>();
            (reply.Status, reply.RoundTripTime)
        } else {
            let reply = &*buffer.as_ptr().cast::<ICMPV6_ECHO_REPLY_LH>();
            (reply.Status, reply.RoundTripTime)
        };
        Ok(if status == 0 { Some(latency) } else { None })
    }
}

struct Socket(SOCKET);
impl Drop for Socket {
    fn drop(&mut self) {
        unsafe {
            closesocket(self.0);
        }
    }
}

pub fn tcp(
    target: &SOCKADDR_INET,
    source: &SOCKADDR_INET,
    loopback: bool,
    port: u16,
) -> io::Result<Option<u128>> {
    unsafe {
        let mut target = *target;
        if target.si_family == AF_INET {
            target.Ipv4.sin_port = port.to_be();
        } else {
            target.Ipv6.sin6_port = port.to_be();
        }
        let raw = WSASocketW(
            target.si_family as i32,
            SOCK_STREAM,
            IPPROTO_TCP,
            null(),
            0,
            0,
        );
        if raw == INVALID_SOCKET {
            return Err(io::Error::from_raw_os_error(WSAGetLastError()));
        }
        let socket = Socket(raw);
        let length = sockaddr_len(&target);
        if !loopback && bind(socket.0, (source as *const SOCKADDR_INET).cast(), length) != 0 {
            return Ok(None);
        }
        let mut nonblocking = 1;
        if ioctlsocket(socket.0, FIONBIO, &mut nonblocking) != 0 {
            return Ok(None);
        }
        let start = std::time::Instant::now();
        if connect(socket.0, (&target as *const SOCKADDR_INET).cast(), length) == SOCKET_ERROR {
            if WSAGetLastError() != WSAEWOULDBLOCK {
                return Ok(None);
            }
            let mut poll = WSAPOLLFD {
                fd: socket.0,
                events: POLLWRNORM,
                revents: 0,
            };
            if WSAPoll(&mut poll, 1, 3000) <= 0 {
                return Ok(None);
            }
            let mut error = 0i32;
            let mut size = size_of::<i32>() as i32;
            if getsockopt(
                socket.0,
                SOL_SOCKET,
                SO_ERROR,
                (&mut error as *mut i32).cast(),
                &mut size,
            ) != 0
                || error != 0
                || poll.revents & POLLWRNORM == 0
            {
                return Ok(None);
            }
        }
        Ok(Some(start.elapsed().as_millis()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ip_conversion_preserves_network_byte_order() {
        for text in ["127.0.0.1", "192.0.2.123", "::1", "2001:db8::123"] {
            let address: IpAddr = text.parse().unwrap();
            assert_eq!(address_ip(&socket_address(address)), address);
        }
    }
}
