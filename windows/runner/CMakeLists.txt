cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

add_executable(${BINARY_NAME} WIN32
  "Runner.rc"
  "runner.exe.manifest"
)
set_target_properties(${BINARY_NAME} PROPERTIES LINKER_LANGUAGE CXX)

apply_standard_settings(${BINARY_NAME})

find_program(CARGO_EXECUTABLE NAMES cargo HINTS "$ENV{USERPROFILE}/.cargo/bin")
if(NOT CARGO_EXECUTABLE)
  message(FATAL_ERROR "Rust/Cargo is required for the Windows helpers. Install the Rust MSVC toolchain, then rebuild.")
endif()
set(RUST_HELPERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../native/windows")
set(RUST_TARGET_DIR "${CMAKE_BINARY_DIR}/rust")
set(RUST_PROFILE "$<IF:$<CONFIG:Debug>,dev,release>")
set(RUST_OUTPUT_PROFILE "$<IF:$<CONFIG:Debug>,debug,release>")
set(RUST_RUNNER_DIR "${CMAKE_CURRENT_BINARY_DIR}/$<CONFIG>")
add_custom_target(aoravpn_windows_helpers ALL
  COMMAND "${CARGO_EXECUTABLE}" build --locked --manifest-path "${RUST_HELPERS_DIR}/Cargo.toml"
    --target x86_64-pc-windows-msvc --target-dir "${RUST_TARGET_DIR}"
    --profile "${RUST_PROFILE}" --bins
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${RUST_RUNNER_DIR}"
  WORKING_DIRECTORY "${RUST_HELPERS_DIR}"
  COMMENT "Building Rust Windows helpers"
  VERBATIM
)
foreach(HELPER aoravpn_core_host aoravpn_core_console aoravpn_server_ping aoravpn_kill_switch aoravpn_update aoravpn_service)
  add_custom_command(TARGET aoravpn_windows_helpers POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      "${RUST_TARGET_DIR}/x86_64-pc-windows-msvc/${RUST_OUTPUT_PROFILE}/${HELPER}.exe"
      "${RUST_RUNNER_DIR}/${HELPER}.exe"
    VERBATIM
  )
  install(FILES "${RUST_RUNNER_DIR}/${HELPER}.exe"
    DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endforeach()
add_dependencies(${BINARY_NAME} aoravpn_windows_helpers)

add_custom_target(aoravpn_prepare_shared_service
  COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass -File
    "${CMAKE_CURRENT_SOURCE_DIR}/../../tool/prepare_windows_service.ps1"
    -SourceDirectory "${RUST_TARGET_DIR}/x86_64-pc-windows-msvc/${RUST_OUTPUT_PROFILE}"
    -Configuration "$<CONFIG>"
  DEPENDS aoravpn_windows_helpers
  COMMENT "Checking the shared installed Windows service"
  VERBATIM
)
add_dependencies(${BINARY_NAME} aoravpn_prepare_shared_service)

add_custom_target(aoravpn_rust_runner ALL
  COMMAND "${CMAKE_COMMAND}" -E env
    "AORA_FLUTTER_HEADER=${FLUTTER_MANAGED_DIR}/ephemeral/flutter_windows.h"
    "AORA_PLUGIN_REGISTRANT=${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
    "${CARGO_EXECUTABLE}" build --locked --manifest-path "${RUST_HELPERS_DIR}/Cargo.toml"
      --target x86_64-pc-windows-msvc --target-dir "${RUST_TARGET_DIR}"
      --profile "${RUST_PROFILE}" --lib --features runner
  WORKING_DIRECTORY "${RUST_HELPERS_DIR}"
  DEPENDS flutter_assemble aoravpn_windows_helpers
  COMMENT "Building Rust Flutter Windows runner"
  VERBATIM
)
add_dependencies(${BINARY_NAME} aoravpn_rust_runner)
set(RUST_RUNNER_LIBRARY "${RUST_TARGET_DIR}/x86_64-pc-windows-msvc/${RUST_OUTPUT_PROFILE}/aora_windows_helpers.lib")
target_link_libraries(${BINARY_NAME} PRIVATE "${RUST_RUNNER_LIBRARY}"
  kernel32 user32 advapi32 bcrypt userenv ntdll ws2_32 iphlpapi fwpuclnt
  shell32 ole32 oleaut32 propsys runtimeobject wtsapi32 rpcrt4 crypt32 gdi32 dwmapi
  libcmt libvcruntime libucrt)

target_link_options(${BINARY_NAME} PRIVATE
  "/MANIFESTUAC:level='requireAdministrator' uiAccess='false'"
  "/ENTRY:wWinMainCRTStartup" "/INCLUDE:wWinMain"
)

target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

add_dependencies(${BINARY_NAME} flutter_assemble)
