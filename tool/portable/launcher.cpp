// SPDX-License-Identifier: GPL-3.0-or-later
#include <windows.h>
#include <shlobj.h>
#include <shellapi.h>
#include <wincrypt.h>
#include <fstream>
#include <string>
#include <vector>

std::wstring Literal(const std::wstring& value) {
  std::wstring result = L"'";
  for (wchar_t c : value) result += c == L'\'' ? L"''" : std::wstring(1, c);
  return result + L"'";
}

bool RunScript(const std::wstring& script) {
  DWORD length = 0;
  const auto bytes = reinterpret_cast<const BYTE*>(script.data());
  const DWORD size = static_cast<DWORD>(script.size() * sizeof(wchar_t));
  if (!CryptBinaryToStringW(bytes, size, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, nullptr, &length)) return false;
  std::wstring encoded(length, L'\0');
  if (!CryptBinaryToStringW(bytes, size, CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF, encoded.data(), &length)) return false;
  encoded.resize(wcslen(encoded.c_str()));
  wchar_t system[MAX_PATH];
  if (!GetSystemDirectoryW(system, MAX_PATH)) return false;
  const std::wstring powershell = std::wstring(system) + L"\\WindowsPowerShell\\v1.0\\powershell.exe";
  std::wstring command = L"\"" + powershell + L"\" -NoProfile -NonInteractive -EncodedCommand " + encoded;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(powershell.c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) return false;
  CloseHandle(process.hThread);
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(process.hProcess, &code);
  CloseHandle(process.hProcess);
  return code == 0;
}

int Fail(const wchar_t* message) {
  MessageBoxW(nullptr, message, L"AORA Connect", MB_OK | MB_ICONERROR);
  return 1;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR arguments, int) {
  // Non-network diagnostic option: unpack only, without launching/elevating the app.
  const bool extract_only = std::wstring(arguments) == L"--extract-only";
  HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\AORAConnectPortableLaunch");
  if (!mutex || GetLastError() == ERROR_ALREADY_EXISTS) {
    if (mutex) CloseHandle(mutex);
    return Fail(L"AORA Connect is already running or being unpacked. Close it before opening another version.");
  }
  PWSTR local = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local))) return Fail(L"Could not find local app storage.");
  const std::wstring root = std::wstring(local) + L"\\AORAConnect";
  CoTaskMemFree(local);
  const int root_result = SHCreateDirectoryExW(nullptr, root.c_str(), nullptr);
  if (root_result != ERROR_SUCCESS && root_result != ERROR_ALREADY_EXISTS && root_result != ERROR_FILE_EXISTS) return Fail(L"Could not create app storage.");
  const std::wstring runtime = root + L"\\runtime";
  SHCreateDirectoryExW(nullptr, runtime.c_str(), nullptr);
  const std::wstring marker = root + L"\\app\\package-id.txt";
  std::wifstream marker_file(marker);
  std::wstring installed;
  std::getline(marker_file, installed);
  marker_file.close();
  bool missing = false;
  for (const auto* required : {
      L"\\app\\aoravpn.exe", L"\\app\\flutter_windows.dll", L"\\app\\data\\app.so",
      L"\\app\\aoravpn_core_host.exe", L"\\app\\aoravpn_server_ping.exe",
      L"\\app\\aoravpn_kill_switch.exe", L"\\app\\vcruntime140.dll",
      L"\\cores\\sing-box-1.14.2-windows-amd64\\sing-box.exe",
      L"\\cores\\sing-box-1.14.2-windows-amd64\\libcronet.dll",
      L"\\cores\\xray-v26.9.30-windows-64\\xray.exe",
      L"\\cores\\xray-v26.9.30-windows-64\\wintun.dll"}) {
    if (GetFileAttributesW((root + required).c_str()) == INVALID_FILE_ATTRIBUTES) missing = true;
  }
  if (installed != PACKAGE_ID || missing) {
    GUID guid{};
    if (FAILED(CoCreateGuid(&guid))) return Fail(L"Could not create an unpacking session.");
    wchar_t id[40];
    StringFromGUID2(guid, id, 40);
    const std::wstring session = runtime + L"\\package-" + id;
    if (!CreateDirectoryW(session.c_str(), nullptr)) return Fail(L"Could not create an unpacking folder.");
    HRSRC resource = FindResourceW(instance, MAKEINTRESOURCEW(101), RT_RCDATA);
    HGLOBAL loaded = resource ? LoadResource(instance, resource) : nullptr;
    const void* payload = loaded ? LockResource(loaded) : nullptr;
    if (!payload) return Fail(L"The bundled application is missing.");
    const std::wstring archive = session + L"\\payload.zip";
    std::ofstream file(archive, std::ios::binary);
    file.write(static_cast<const char*>(payload), SizeofResource(instance, resource));
    file.close();
    if (!file) return Fail(L"Could not write the bundled application.");
    const std::wstring script =
      L"$ErrorActionPreference='Stop'; $root=" + Literal(root) + L"; $session=" + Literal(session) +
      L"; try { $stage=Join-Path $session 'stage'; Expand-Archive -LiteralPath (Join-Path $session 'payload.zip') -DestinationPath $stage; "
      L"foreach($name in @('app','cores')) { $source=Join-Path $stage $name; if(!(Test-Path -LiteralPath $source)){throw 'Incomplete package'}; "
      L"$destination=Join-Path $root $name; New-Item -ItemType Directory -Force -Path $destination | Out-Null; "
      L"Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force }; "
      L"[IO.File]::WriteAllText((Join-Path $root 'app\\package-id.txt')," + Literal(PACKAGE_ID) +
      L",[Text.Encoding]::ASCII) } finally { Remove-Item -LiteralPath $session -Recurse -Force }";
    if (!RunScript(script)) return Fail(L"Could not unpack AORA Connect. Check free disk space and close any running copy, then try again.");
  }
  if (!extract_only) {
    const std::wstring exe = root + L"\\app\\aoravpn.exe";
    const std::wstring working = root + L"\\app";
    SHELLEXECUTEINFOW launch{};
    launch.cbSize = sizeof(launch);
    launch.fMask = SEE_MASK_NOCLOSEPROCESS;
    launch.lpVerb = L"runas";
    launch.lpFile = exe.c_str();
    launch.lpDirectory = working.c_str();
    launch.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&launch)) return Fail(L"Could not start AORA Connect. Administrator approval is required for TUN mode.");
    if (launch.hProcess) {
      WaitForSingleObject(launch.hProcess, INFINITE);
      CloseHandle(launch.hProcess);
    }
  }
  ReleaseMutex(mutex);
  CloseHandle(mutex);
  return 0;
}
