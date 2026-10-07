#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Children inherit the job, so a crash or immediate close cannot leave the
  // core running. Keep this handle open until the OS closes it on app exit.
  HANDLE child_job = ::CreateJobObject(nullptr, nullptr);
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION job_limits = {};
  job_limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!child_job ||
      !::SetInformationJobObject(child_job, JobObjectExtendedLimitInformation,
                                &job_limits, sizeof(job_limits)) ||
      !::AssignProcessToJobObject(child_job, ::GetCurrentProcess())) {
    ::MessageBox(nullptr, L"Unable to initialize core process cleanup.",
                 L"AORA VPN", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(420, 740);
  if (!window.Create(L"aoravpn", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
