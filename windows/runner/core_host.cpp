// SPDX-License-Identifier: GPL-3.0-or-later
#include <windows.h>
#include <iostream>
#include <string>
#include <thread>

// A private console lets us deliver CTRL_BREAK to the core without signalling
// Flutter or the developer's terminal. Core output remains on Dart's pipes.
int wmain(int argc, wchar_t* argv[]) {
  if (argc != 3 && argc != 4) {
    std::cerr << "Core host requires executable and config paths.\n";
    return 1;
  }
  HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
  HANDLE error = GetStdHandle(STD_ERROR_HANDLE);
  HANDLE control = GetStdHandle(STD_INPUT_HANDLE);
  // Some launchers give the helper an inherited console even when its window
  // is hidden. Detach before allocating a private one; keep the pipe handles.
  FreeConsole();
  if (!AllocConsole()) {
    std::cerr << "Unable to allocate a private core console.\n";
    return 1;
  }
  ShowWindow(GetConsoleWindow(), SW_HIDE);
  SetStdHandle(STD_OUTPUT_HANDLE, output);
  SetStdHandle(STD_ERROR_HANDLE, error);
  SECURITY_ATTRIBUTES security = {sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
  HANDLE input = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                            &security, OPEN_EXISTING, 0, nullptr);
  if (input == INVALID_HANDLE_VALUE) return 1;
  SetHandleInformation(output, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
  SetHandleInformation(error, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
  STARTUPINFOW startup = {};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESTDHANDLES;
  startup.hStdInput = input;
  startup.hStdOutput = output;
  startup.hStdError = error;
  PROCESS_INFORMATION child = {};
  // Windows file names cannot contain quotes; both supplied arguments are paths.
  const bool xray = argc == 4 && std::wstring(argv[3]) == L"xray";
  std::wstring command = L"\"" + std::wstring(argv[1]) +
      L"\" run -c \"" + std::wstring(argv[2]) + L"\"" +
      (xray ? L"" : L" --disable-color");
  if (!CreateProcessW(argv[1], command.data(), nullptr, nullptr, TRUE,
                      CREATE_NEW_PROCESS_GROUP, nullptr, nullptr, &startup, &child)) {
    std::cerr << "Unable to launch core (Windows error " << GetLastError() << ").\n";
    CloseHandle(input);
    return 1;
  }
  CloseHandle(input);
  CloseHandle(child.hThread);
  std::thread([control, process = child.hProcess, pid = child.dwProcessId]() {
    char byte = 0;
    DWORD read = 0;
    // Either a stop command or a closed control pipe initiates cleanup.
    while (ReadFile(control, &byte, 1, &read, nullptr) && read != 0) {
      if (byte == '\n') break;
    }
    if (WaitForSingleObject(process, 0) != WAIT_OBJECT_0) {
      GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT, pid);
      if (WaitForSingleObject(process, 8000) == WAIT_TIMEOUT) {
        std::cerr << "Graceful shutdown timed out; terminating core.\n";
        TerminateProcess(process, 1);
      }
    }
  }).detach();
  WaitForSingleObject(child.hProcess, INFINITE);
  DWORD exit_code = 1;
  GetExitCodeProcess(child.hProcess, &exit_code);
  // The control thread may still be blocked on stdin. Process exit closes all
  // remaining handles and stops that thread.
  return static_cast<int>(exit_code);
}
