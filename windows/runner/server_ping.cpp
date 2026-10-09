// SPDX-License-Identifier: GPL-3.0-or-later
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <icmpapi.h>
#include <netioapi.h>
#include <limits>
#include <iostream>
#include <vector>
#include <chrono>

// Bind echo requests to the physical internet interface. A TUN stack may
// answer ICMP locally, so the default VPN route is not a server RTT test.
bool PhysicalSource(const SOCKADDR_INET& destination, SOCKADDR_INET& source) {
  ULONG size = 0;
  const ULONG flags = GAA_FLAG_INCLUDE_GATEWAYS;
  if (GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, nullptr, &size) !=
      ERROR_BUFFER_OVERFLOW) return false;
  std::vector<BYTE> adapters_buffer(size);
  auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(adapters_buffer.data());
  if (GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, adapters, &size) !=
      NO_ERROR) return false;
  ULONG64 best_metric = std::numeric_limits<ULONG64>::max();
  bool found = false;
  for (auto* adapter = adapters; adapter; adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp ||
        (adapter->IfType != IF_TYPE_ETHERNET_CSMACD &&
         adapter->IfType != IF_TYPE_IEEE80211) ||
        !adapter->FirstGatewayAddress ||
        (adapter->FriendlyName && wcsstr(adapter->FriendlyName, L"AORA"))) continue;
    bool has_gateway = false;
    for (auto* gateway = adapter->FirstGatewayAddress; gateway;
         gateway = gateway->Next) {
      if (gateway->Address.lpSockaddr &&
          gateway->Address.lpSockaddr->sa_family == destination.si_family) {
        has_gateway = true;
      }
    }
    if (!has_gateway) continue;
    MIB_IPFORWARD_ROW2 route{};
    SOCKADDR_INET candidate{};
    if (GetBestRoute2(&adapter->Luid, 0, nullptr, &destination, 0,
                     &route, &candidate) != NO_ERROR) continue;
    const ULONG64 metric = static_cast<ULONG64>(route.Metric) +
        (destination.si_family == AF_INET ? adapter->Ipv4Metric : adapter->Ipv6Metric);
    if (metric < best_metric) {
      best_metric = metric;
      source = candidate;
      found = true;
    }
  }
  return found;
}

// A single ICMP echo to a literal server address. No configuration, routes,
// firewall rules, or core processes are changed by this helper.
int wmain(int argc, wchar_t* argv[]) {
  if (argc != 2 && argc != 3 && argc != 4) {
    std::cerr << "Expected a server IP address";
    return 1;
  }
  WSADATA winsock{};
  if (WSAStartup(MAKEWORD(2, 2), &winsock) != 0) return 1;
  IN_ADDR ipv4{};
  sockaddr_in6 destination{};
  destination.sin6_family = AF_INET6;
  const bool v4 = InetPtonW(AF_INET, argv[1], &ipv4) == 1;
  if (!v4 && InetPtonW(AF_INET6, argv[1], &destination.sin6_addr) != 1) {
    WSACleanup();
    std::cerr << "Invalid server IP address";
    return 1;
  }
  SOCKADDR_INET target{};
  target.si_family = v4 ? AF_INET : AF_INET6;
  if (v4) target.Ipv4.sin_addr = ipv4;
  else target.Ipv6 = destination;
  SOCKADDR_INET bound_source{};
  const bool loopback = v4
      ? (ntohl(ipv4.S_un.S_addr) >> 24) == 127
      : IN6_IS_ADDR_LOOPBACK(&destination.sin6_addr) != 0;
  if (!loopback && !PhysicalSource(target, bound_source)) {
    WSACleanup();
    std::cerr << "No physical network route to this server";
    return 3;
  }
  if (argc == 3 && wcscmp(argv[2], L"source") == 0) {
    wchar_t text[INET6_ADDRSTRLEN]{};
    if (loopback) bound_source = target;
    const void* address = v4
        ? static_cast<const void*>(&bound_source.Ipv4.sin_addr)
        : static_cast<const void*>(&bound_source.Ipv6.sin6_addr);
    if (!InetNtopW(target.si_family, const_cast<void*>(address), text,
                   INET6_ADDRSTRLEN)) {
      WSACleanup();
      return 1;
    }
    std::wcout << text << std::endl;
    WSACleanup();
    return 0;
  }
  if (argc == 4 && wcscmp(argv[2], L"tcp") == 0) {
    wchar_t* end = nullptr;
    const long port = wcstol(argv[3], &end, 10);
    if (!end || *end || port < 1 || port > 65535) {
      WSACleanup();
      return 1;
    }
    if (v4) target.Ipv4.sin_port = htons(static_cast<u_short>(port));
    else target.Ipv6.sin6_port = htons(static_cast<u_short>(port));
    SOCKET socket = WSASocketW(target.si_family, SOCK_STREAM, IPPROTO_TCP,
                               nullptr, 0, 0);
    const int size = v4 ? sizeof(sockaddr_in) : sizeof(sockaddr_in6);
    bool ok = socket != INVALID_SOCKET;
    if (ok && !loopback) {
      ok = bind(socket, reinterpret_cast<sockaddr*>(&bound_source), size) == 0;
    }
    u_long nonblocking = 1;
    if (ok) ok = ioctlsocket(socket, FIONBIO, &nonblocking) == 0;
    const auto start = std::chrono::steady_clock::now();
    if (ok) {
      const int connected = connect(socket, reinterpret_cast<sockaddr*>(&target), size);
      if (connected == SOCKET_ERROR && WSAGetLastError() != WSAEWOULDBLOCK) {
        ok = false;
      } else if (connected == SOCKET_ERROR) {
        WSAPOLLFD poll{socket, POLLWRNORM, 0};
        ok = WSAPoll(&poll, 1, 3000) > 0;
        int error = 0;
        int length = sizeof(error);
        ok = ok && getsockopt(socket, SOL_SOCKET, SO_ERROR,
            reinterpret_cast<char*>(&error), &length) == 0 && error == 0 &&
            (poll.revents & POLLWRNORM) != 0;
      }
    }
    const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - start).count();
    if (socket != INVALID_SOCKET) closesocket(socket);
    WSACleanup();
    if (!ok) return 2;
    std::cout << elapsed << std::endl;
    return 0;
  }
  if (argc != 2) {
    WSACleanup();
    return 1;
  }
  HANDLE icmp = v4 ? IcmpCreateFile() : Icmp6CreateFile();
  if (icmp == INVALID_HANDLE_VALUE) {
    WSACleanup();
    std::cerr << "Could not open ICMP session";
    return 1;
  }
  char payload[] = "AORA Connect";
  std::vector<BYTE> buffer(512);
  sockaddr_in6 source{};
  source.sin6_family = AF_INET6;
  if (!v4 && !loopback) source = bound_source.Ipv6;
  DWORD replies = v4
      ? IcmpSendEcho2Ex(icmp, nullptr, nullptr, nullptr,
                      loopback ? 0 : bound_source.Ipv4.sin_addr.S_un.S_addr,
                      ipv4.S_un.S_addr,
                      payload, sizeof(payload), nullptr, buffer.data(),
                      static_cast<DWORD>(buffer.size()), 2000)
      : Icmp6SendEcho2(icmp, nullptr, nullptr, nullptr, &source, &destination,
                       payload, sizeof(payload), nullptr, buffer.data(),
                       static_cast<DWORD>(buffer.size()), 2000);
  DWORD status = IP_REQ_TIMED_OUT;
  DWORD milliseconds = 0;
  if (replies != 0) {
    if (v4) {
      auto* reply = reinterpret_cast<ICMP_ECHO_REPLY*>(buffer.data());
      status = reply->Status;
      milliseconds = reply->RoundTripTime;
    } else {
      auto* reply = reinterpret_cast<ICMPV6_ECHO_REPLY*>(buffer.data());
      status = reply->Status;
      milliseconds = reply->RoundTripTime;
    }
  }
  IcmpCloseHandle(icmp);
  WSACleanup();
  if (status != IP_SUCCESS) {
    std::cerr << "No ICMP reply";
    return 2;
  }
  std::cout << milliseconds << std::endl;
  return 0;
}
