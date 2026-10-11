# Windows native helpers

This Cargo package contains all application-owned Windows native code: the
window runner, helpers, and portable launcher. UI and application state remain
in Dart. The networking cores remain separate Go executables. Upstream Flutter
and plugin C++ code is not rewritten; their toolchain dependencies remain.

## Migration status

The Rust runner builds in Debug and Release. Hidden first-frame smoke tests pass
in both configurations, including plugin registration and fixed-size window
checks. The Rust helpers and portable launcher have also been compiled. Unit
tests and Clippy with warnings treated as errors pass. Loopback tests cover both core lifecycles,
including ten rapid Xray start/stop cycles, TCP success/failure, and IPv4/IPv6
ICMP. Unpack-only checks cover package extraction, reuse, and settings preservation.
Real-provider TUN and second-PC validation remain manual checks.

## Binaries

| Binary | Purpose |
| --- | --- |
| `aoravpn.exe` | Resource-only Windows target linked to the Rust runner static library |
| `aoravpn_core_host.exe` | Windowless entry point that starts a hidden private console worker |
| `aoravpn_core_console.exe` | Starts the selected core, forwards logs, and sends CTRL_BREAK on stop/closed stdin |
| `aoravpn_server_ping.exe` | ICMP, physical-source lookup, and TCP checks for IPv4/IPv6 |
| `aoravpn_kill_switch.exe` | Recovery of legacy WFP rules; persistent arming is disabled |
| `AORAConnect.exe` | Single-EXE launcher with an embedded package, built with the `portable` feature |

The helper executable names and the Dart-facing command-line contracts stay the
same. The ping helper prints an integer latency in milliseconds, or a source IP
for `source`. Its exit codes remain 0 (success), 1 (invalid/internal failure),
2 (no reply/failed TCP check), and 3 (no physical route).

The core console checks that it was created hidden. It keeps an eight-second
graceful-shutdown deadline before forced termination. Handles and sockets use
owned wrappers so they close on error paths. Unsafe code is confined to Windows
API interactions and the generated bindings' pointer/union boundaries.

Xray can report startup before completing GC and registering its signal handler.
An immediate stop gets a brief 500 ms minimum process-age grace period before
CTRL_BREAK is sent. This is a bounded startup safeguard, not a guarantee about
upstream readiness under every load condition.

The firewall recovery helper uses the original application-specific GUID and
filter keys. `status`, `disarm`, and the old permit-only `allow-tun`/`revoke-tun`
commands are retained. It does not create new blocking filters or re-enable the
old persistent Kill Switch. The application currently calls only `disarm`.

## Build prerequisites

Install the Rust MSVC toolchain with Cargo and the existing Visual Studio C++
build tools/Windows SDK. The current target is `x86_64-pc-windows-msvc`.
Rust's standard library is linked with a static CRT for these helpers; Flutter's
runner and plugins still require their own runtime DLLs.

Run commands from this directory so Cargo reads `.cargo/config.toml`:

```powershell
cargo build --locked --target x86_64-pc-windows-msvc --bins
cargo test --locked --target x86_64-pc-windows-msvc --bins --lib
cargo fmt --check
cargo clippy --locked --target x86_64-pc-windows-msvc --bins --lib -- -D warnings
```

`Cargo.lock` is included and builds use `--locked` so dependency resolution is
reproducible. Review and commit lockfile updates when updating dependencies.
The Windows API dependency is pinned to `windows-sys` 0.59.0; it is not a claim
that this is the newest upstream release.

Flutter's Windows CMake build calls Cargo and places the four helpers beside the
runner. Debug Flutter builds use Cargo's `dev` profile; Profile/Release builds
use its `release` profile. Cargo outputs go under Flutter's ignored `build/`
directory when built through CMake.

The portable package is built by `tool/build_portable.ps1`, which supplies
`AORA_PAYLOAD_ZIP` and `AORA_PACKAGE_ID` only while compiling the launcher. The
`portable` feature is intentionally not enabled for ordinary helper builds or
tests, because those do not have a payload to embed.

## Rust Flutter window runner

`src/runner/` replaces the former `windows/runner/*.cpp` sources. CMake links the
Rust static library to Flutter's C API and the existing plugin import libraries,
using the existing resource file and administrator/DPI manifest. No maintained
C++ bridge is used. Generated C++ registration files are build inputs only;
`build.rs` generates the Rust registration calls from them and fails on unknown
formats instead of silently omitting a plugin.

The engine-properties structure is generated from the installed SDK header.
Centered portrait sizing, monitor-work-area fitting, DPI updates,
first-frame display, font/theme changes, message delegation, command-
line forwarding, and kill-on-exit child-process handling are retained.

The runner now creates a fixed-size frameless window. `controls.rs` owns the
notification-area icon, Explorer restart handling, drag dispatch, and the
`aora/window` UTF-8 channel. Native close requests are sent to Dart for awaited
session cleanup; only Dart's subsequent destroy command ends the window. Tray
registration must succeed before hiding. The UI retains keyboard-accessible
Close/Tray controls and the native tray menu supports reopening and disconnect.

The `runner` Cargo feature must be built through CMake, which supplies
`AORA_FLUTTER_HEADER` and `AORA_PLUGIN_REGISTRANT`. The normal standalone Cargo
helper tests do not enable it.

After building Flutter Debug or Release, run from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File tool/test_windows_runner.ps1 -Configuration Release
powershell -ExecutionPolicy Bypass -File tool/test_windows_runner.ps1 -Configuration Debug
```

The optional smoke target is outside the distributable bundle, uses an asInvoker
manifest, isolated LOCALAPPDATA/APPDATA, and no network helpers. It renders the
first Flutter frame hidden, registers plugins, checks hidden/fixed-size window
invariants, and exits. It does not test opening a browser or a real VPN tunnel.
It also checks caption removal, channel readiness, tray registration/removal,
and the native-close/Dart-cleanup/native-destroy round trip.
Test folders remain under ignored `build/` for inspection. The driver enables
`AORA_BUILD_RUNNER_SMOKE` in the local CMake cache; set it OFF to omit that target
from normal builds.

## Verification after installing Rust

1. Run the Cargo commands above and resolve any compiler/Clippy findings.
2. Build the Windows app in Debug and Release.
3. From the Flutter project root, run:

   ```powershell
   flutter test test/windows_sing_box_engine_test.dart test/node_ping_test.dart
   flutter analyze
   ```

4. Check ICMP to `127.0.0.1` and `::1`, physical-source selection, and TCP success
   and failure over loopback. Core tests should confirm clean exit for both cores.
5. Rebuild the portable package, test `--extract-only`, repeated launch reuse and
   preservation of settings, then test on a second PC.
6. Verify real-provider TUN connect/disconnect and app-exit recovery separately.

Do not test recovery by installing blocking WFP rules on a development machine.
The migration does not authorize or require that action.
