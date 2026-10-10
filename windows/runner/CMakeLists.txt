cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Only the Flutter runner is C++; custom Windows helpers are built with Cargo.
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
foreach(HELPER aoravpn_core_host aoravpn_core_console aoravpn_server_ping aoravpn_kill_switch)
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

# Match the linker-generated UAC fragment to the application manifest.
target_link_options(${BINARY_NAME} PRIVATE
  "/MANIFESTUAC:level='requireAdministrator' uiAccess='false'"
)

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
