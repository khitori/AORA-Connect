// SPDX-License-Identifier: GPL-3.0-or-later
// Legacy WFP rules are retained here for recovery. Arming is disabled until
// the implementation is repaired; disarm removes only this app's own rules.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <fwpmu.h>
#include <iphlpapi.h>
#include <array>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#pragma comment(lib, "fwpuclnt.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")

namespace {
// Private namespace for this application's WFP objects.
constexpr GUID kSublayer = {0x87f23d52, 0xc094, 0x4e5f,
                           {0x9e, 0x7e, 0xb7, 0xea, 0x19, 0xb9, 0x67, 0x60}};

GUID Key(unsigned index) {
  GUID key = kSublayer;
  key.Data1 += index;
  return key;
}

void Check(DWORD code, const char* action) {
  if (code != ERROR_SUCCESS) {
    throw std::runtime_error(std::string(action) + " failed (Windows error " +
                             std::to_string(code) + ")");
  }
}

struct Engine {
  HANDLE handle = nullptr;
  Engine() { Check(FwpmEngineOpen0(nullptr, RPC_C_AUTHN_WINNT, nullptr, nullptr,
                                  &handle), "Open filtering engine"); }
  ~Engine() { if (handle) FwpmEngineClose0(handle); }
};

struct Transaction {
  HANDLE engine;
  bool active = true;
  explicit Transaction(HANDLE handle) : engine(handle) {
    Check(FwpmTransactionBegin0(engine, 0), "Begin firewall transaction");
  }
  ~Transaction() { if (active) FwpmTransactionAbort0(engine); }
  void Commit() {
    Check(FwpmTransactionCommit0(engine), "Commit firewall transaction");
    active = false;
  }
};

void DeleteFilter(HANDLE engine, unsigned index) {
  GUID key = Key(index);
  DWORD result = FwpmFilterDeleteByKey0(engine, &key);
  if (result != FWP_E_FILTER_NOT_FOUND) Check(result, "Delete firewall filter");
}

void EnsureSublayer(HANDLE engine) {
  FWPM_SUBLAYER0 sublayer{};
  sublayer.subLayerKey = kSublayer;
  sublayer.displayData.name = const_cast<wchar_t*>(L"AORA Connect Kill Switch");
  sublayer.displayData.description = const_cast<wchar_t*>(
      L"Persistent outbound traffic guard for AORA Connect");
  sublayer.flags = FWPM_SUBLAYER_FLAG_PERSISTENT;
  sublayer.weight = 0x8000;
  DWORD result = FwpmSubLayerAdd0(engine, &sublayer, nullptr);
  if (result != FWP_E_ALREADY_EXISTS) Check(result, "Create firewall sublayer");
}

void AddFilter(HANDLE engine, unsigned index, bool ipv6, bool permit,
               FWPM_FILTER_CONDITION0* conditions, UINT32 count,
               bool transport = false) {
  FWPM_FILTER0 filter{};
  filter.filterKey = Key(index);
  filter.displayData.name = const_cast<wchar_t*>(L"AORA Connect Kill Switch");
  filter.flags = FWPM_FILTER_FLAG_PERSISTENT;
  filter.layerKey = transport
      ? (ipv6 ? FWPM_LAYER_OUTBOUND_TRANSPORT_V6
              : FWPM_LAYER_OUTBOUND_TRANSPORT_V4)
      : (ipv6 ? FWPM_LAYER_ALE_AUTH_CONNECT_V6
              : FWPM_LAYER_ALE_AUTH_CONNECT_V4);
  filter.subLayerKey = kSublayer;
  filter.weight.type = FWP_UINT8;
  filter.weight.uint8 = permit ? 15 : 1;
  filter.action.type = permit ? FWP_ACTION_PERMIT : FWP_ACTION_BLOCK;
  filter.numFilterConditions = count;
  filter.filterCondition = conditions;
  Check(FwpmFilterAdd0(engine, &filter, nullptr, nullptr), "Add firewall filter");
}

void AddLoopback(HANDLE engine, bool transport) {
  FWPM_FILTER_CONDITION0 v4{};
  FWP_V4_ADDR_AND_MASK loopback4{0x7f000000, 0xff000000};
  v4.fieldKey = FWPM_CONDITION_IP_REMOTE_ADDRESS;
  v4.matchType = FWP_MATCH_EQUAL;
  v4.conditionValue.type = FWP_V4_ADDR_MASK;
  v4.conditionValue.v4AddrMask = &loopback4;
  AddFilter(engine, transport ? 9 : 1, false, true, &v4, 1, transport);

  FWPM_FILTER_CONDITION0 v6{};
  FWP_V6_ADDR_AND_MASK loopback6{};
  loopback6.addr[15] = 1;
  loopback6.prefixLength = 128;
  v6.fieldKey = FWPM_CONDITION_IP_REMOTE_ADDRESS;
  v6.matchType = FWP_MATCH_EQUAL;
  v6.conditionValue.type = FWP_V6_ADDR_MASK;
  v6.conditionValue.v6AddrMask = &loopback6;
  AddFilter(engine, transport ? 10 : 2, true, true, &v6, 1, transport);
}

void AddCoreEndpoint(HANDLE engine, const wchar_t* path,
                     const wchar_t* ip, unsigned port, bool transport) {
  FWP_BYTE_BLOB* app_id = nullptr;
  if (!transport) {
    Check(FwpmGetAppIdFromFileName0(path, &app_id), "Identify core executable");
  }
  try {
    IN_ADDR ipv4{};
    IN6_ADDR ipv6{};
    const bool is_v4 = InetPtonW(AF_INET, ip, &ipv4) == 1;
    const bool is_v6 = !is_v4 && InetPtonW(AF_INET6, ip, &ipv6) == 1;
    if (!is_v4 && !is_v6) throw std::runtime_error("Invalid server IP address");
    FWPM_FILTER_CONDITION0 conditions[3]{};
    unsigned offset = transport ? 0 : 1;
    if (!transport) {
      conditions[0].fieldKey = FWPM_CONDITION_ALE_APP_ID;
      conditions[0].matchType = FWP_MATCH_EQUAL;
      conditions[0].conditionValue.type = FWP_BYTE_BLOB_TYPE;
      conditions[0].conditionValue.byteBlob = app_id;
    }
    conditions[offset].fieldKey = FWPM_CONDITION_IP_REMOTE_ADDRESS;
    conditions[offset].matchType = FWP_MATCH_EQUAL;
    FWP_BYTE_ARRAY16 address6{};
    if (is_v4) {
      conditions[offset].conditionValue.type = FWP_UINT32;
      conditions[offset].conditionValue.uint32 = ntohl(ipv4.S_un.S_addr);
    } else {
      memcpy(address6.byteArray16, &ipv6, 16);
      conditions[offset].conditionValue.type = FWP_BYTE_ARRAY16_TYPE;
      conditions[offset].conditionValue.byteArray16 = &address6;
    }
    conditions[offset + 1].fieldKey = FWPM_CONDITION_IP_REMOTE_PORT;
    conditions[offset + 1].matchType = FWP_MATCH_EQUAL;
    conditions[offset + 1].conditionValue.type = FWP_UINT16;
    conditions[offset + 1].conditionValue.uint16 = static_cast<UINT16>(port);
    AddFilter(engine, transport ? (is_v4 ? 11 : 12) : (is_v4 ? 3 : 4),
              is_v6, true, conditions, offset + 2, transport);
  } catch (...) {
    if (app_id) FwpmFreeMemory0(reinterpret_cast<void**>(&app_id));
    throw;
  }
  if (app_id) FwpmFreeMemory0(reinterpret_cast<void**>(&app_id));
}

void AddBlocks(HANDLE engine) {
  AddFilter(engine, 7, false, false, nullptr, 0);
  AddFilter(engine, 8, true, false, nullptr, 0);
  AddFilter(engine, 15, false, false, nullptr, 0, true);
  AddFilter(engine, 16, true, false, nullptr, 0, true);
}

bool HasFilter(HANDLE engine, unsigned index) {
  GUID key = Key(index);
  FWPM_FILTER0* filter = nullptr;
  DWORD result = FwpmFilterGetByKey0(engine, &key, &filter);
  if (result == FWP_E_FILTER_NOT_FOUND) return false;
  Check(result, "Read firewall filter");
  FwpmFreeMemory0(reinterpret_cast<void**>(&filter));
  return true;
}

UINT64 FindTunLuid() {
  ULONG size = 0;
  ULONG flags = GAA_FLAG_INCLUDE_PREFIX;
  DWORD result = GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, nullptr, &size);
  if (result != ERROR_BUFFER_OVERFLOW) Check(result, "Enumerate network adapters");
  std::vector<BYTE> buffer(size);
  auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  Check(GetAdaptersAddresses(AF_UNSPEC, flags, nullptr, adapters, &size),
        "Enumerate network adapters");
  for (auto* adapter = adapters; adapter; adapter = adapter->Next) {
    for (auto* address = adapter->FirstUnicastAddress; address;
         address = address->Next) {
      auto* socket_address = address->Address.lpSockaddr;
      if (!socket_address || socket_address->sa_family != AF_INET) continue;
      auto* ipv4 = reinterpret_cast<sockaddr_in*>(socket_address);
      if (ntohl(ipv4->sin_addr.S_un.S_addr) == 0xac1d0001) {
        return adapter->Luid.Value; // 172.29.0.1, the configured TUN address.
      }
    }
  }
  throw std::runtime_error("TUN adapter was not found; traffic remains blocked");
}

void AllowTun(HANDLE engine) {
  const UINT64 luid = FindTunLuid();
  Transaction transaction(engine);
  DeleteFilter(engine, 5);
  DeleteFilter(engine, 6);
  DeleteFilter(engine, 13);
  DeleteFilter(engine, 14);
  for (unsigned family = 0; family != 2; ++family) {
    FWPM_FILTER_CONDITION0 condition{};
    condition.fieldKey = FWPM_CONDITION_IP_LOCAL_INTERFACE;
    condition.matchType = FWP_MATCH_EQUAL;
    condition.conditionValue.type = FWP_UINT64;
    condition.conditionValue.uint64 = const_cast<UINT64*>(&luid);
    AddFilter(engine, family == 0 ? 5 : 6, family == 1, true,
              &condition, 1);
    AddFilter(engine, family == 0 ? 13 : 14, family == 1, true,
              &condition, 1, true);
  }
  transaction.Commit();
}

void RevokeTun(HANDLE engine) {
  Transaction transaction(engine);
  DeleteFilter(engine, 5);
  DeleteFilter(engine, 6);
  DeleteFilter(engine, 13);
  DeleteFilter(engine, 14);
  transaction.Commit();
}

[[maybe_unused]] void Arm(HANDLE engine, const wchar_t* path, const wchar_t* ip, unsigned port) {
  Transaction transaction(engine);
  EnsureSublayer(engine);
  for (unsigned index = 1; index <= 16; ++index) DeleteFilter(engine, index);
  AddLoopback(engine, false);
  AddLoopback(engine, true);
  AddCoreEndpoint(engine, path, ip, port, false);
  AddCoreEndpoint(engine, path, ip, port, true);
  AddBlocks(engine);
  transaction.Commit();
}

void Disarm(HANDLE engine) {
  Transaction transaction(engine);
  for (unsigned index = 1; index <= 16; ++index) DeleteFilter(engine, index);
  DWORD result = FwpmSubLayerDeleteByKey0(engine, &kSublayer);
  if (result != FWP_E_SUBLAYER_NOT_FOUND) Check(result, "Delete firewall sublayer");
  transaction.Commit();
}
} // namespace

int wmain(int argc, wchar_t* argv[]) {
  try {
    if (argc < 2) throw std::runtime_error("Missing Kill Switch command");
    Engine engine;
    std::wstring command = argv[1];
    if (command == L"arm" && argc == 5) {
      wchar_t* end = nullptr;
      unsigned long port = wcstoul(argv[4], &end, 10);
      if (!end || *end || port == 0 || port > 65535) {
        throw std::runtime_error("Invalid server port");
      }
      throw std::runtime_error("Kill Switch is temporarily disabled. Restart the updated app.");
    } else if (command == L"allow-tun" && argc == 2) {
      AllowTun(engine.handle);
    } else if (command == L"revoke-tun" && argc == 2) {
      RevokeTun(engine.handle);
    } else if (command == L"disarm" && argc == 2) {
      Disarm(engine.handle);
    } else if (command == L"status" && argc == 2) {
      const bool v4 = HasFilter(engine.handle, 7);
      const bool v6 = HasFilter(engine.handle, 8);
      const bool packet4 = HasFilter(engine.handle, 15);
      const bool packet6 = HasFilter(engine.handle, 16);
      if (v4 != v6 || v4 != packet4 || v4 != packet6) {
        throw std::runtime_error("Incomplete Kill Switch policy");
      }
      std::wcout << (v4 ? L"armed" : L"disarmed") << std::endl;
    } else {
      throw std::runtime_error("Invalid Kill Switch command");
    }
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << std::endl;
    return 1;
  }
}
