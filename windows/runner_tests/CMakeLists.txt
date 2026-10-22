cmake_minimum_required(VERSION 3.14)
add_executable(aora_runner_smoke WIN32 "../runner/Runner.rc" "smoke.manifest")
set_target_properties(aora_runner_smoke PROPERTIES LINKER_LANGUAGE CXX
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/runner-tests/$<CONFIG>")
get_target_property(RUNNER_LIBRARIES ${BINARY_NAME} LINK_LIBRARIES)
target_link_libraries(aora_runner_smoke PRIVATE ${RUNNER_LIBRARIES})
target_link_options(aora_runner_smoke PRIVATE "/ENTRY:wWinMainCRTStartup"
  "/INCLUDE:wWinMain" "/MANIFESTUAC:level='asInvoker' uiAccess='false'")
target_include_directories(aora_runner_smoke PRIVATE "../runner")
add_dependencies(aora_runner_smoke aoravpn_rust_runner)
