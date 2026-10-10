# AORA Connect

An open-source VPN client built with Flutter, with sing-box and Xray networking cores.

AORA Connect is being developed as a universal client for subscriptions from different providers. It does not provide a VPN service: you need your own supported subscription or server link.

## Project status

**Early beta — Windows x64 is the current working target.**

Custom Windows helpers and the portable launcher are implemented in Rust.
Rust unit/lint checks, loopback core lifecycle/ping tests, and unpack-only package
checks have passed; real-provider TUN and clean-machine checks remain separate.
See [native/windows/README.md](native/windows/README.md).

Linux and Android are planned targets, but their networking engines are not implemented yet. Platform folders in this repository do not mean those platforms are ready to use.

The application and portable Windows package can be built from source. Clean-machine and real-provider testing are still required before treating a build as production-ready. This project does not claim an independent security audit or guaranteed protection against every traffic leak.

## Features

- Multiple saved subscriptions, provider metadata, and server selection.
- Import of supported Hysteria2, VLESS, Trojan, Shadowsocks, and VMess links.
- HTTPS subscriptions containing plain-text or base64-encoded URI lists.
- VPN (TUN) mode by default, plus an optional local proxy mode.
- Manual core selection, with each server showing its required core.
- Application, domain, exact-domain, and IP/CIDR routing rules.
- A searchable running-application picker and manual executable-name/path entry.
- One-time server checks using ICMP, TCP, Via Proxy GET, or Via Proxy HEAD.
- Optional live ICMP statistics in Settings: one sample slot per second, up to 30 samples.
- Diagnostics for configuration validation, connection checks, and core logs.
- Persistent settings and a single Windows storage root.

Support depends on the link's options and the implemented profile adapters, not only its protocol name. Unsupported entries in a multi-node subscription are skipped and counted; an entirely unsupported subscription fails to import. Arbitrary Clash YAML and full sing-box/Xray configuration imports are not currently supported.

## Getting started on Windows

For a published build, use the repository's Releases page and download `AORAConnect-windows-x64.exe`. If no package has been published, follow the build instructions below.

1. Open the downloaded executable. It contains the application, both cores, native helpers, assets, and companion DLLs.
2. On first launch, the package extracts into `%LOCALAPPDATA%\AORAConnect`. Later launches reuse the extracted files unless the package changes or essential files are missing.
3. Approve the Windows administrator prompt. The current application requires elevation at startup for TUN mode.
4. Open **Subscriptions**, add your subscription URL or supported server link, then choose a server on **Connection**.
5. If that server requires a different core, select it in **Settings → Core**, then connect.

No separate Flutter installation or manual core download is needed to use the packaged executable. Opening the app does not automatically start a VPN connection.

Current locally built packages are unsigned. Do not disable Windows security protections to run an unfamiliar executable; use only a build whose source and origin you trust.

Close the running application before opening a different package. Replace the downloaded launcher to update; settings remain separate from the application files. There is no automatic update system.

### Connection modes

- **VPN (TUN):** routes system traffic through a virtual network interface, subject to your routing rules.
- **Local proxy:** listens on `127.0.0.1:17890`. Only applications explicitly configured to use that proxy send traffic through it; this mode does not configure a system proxy for you.

Disconnect before changing the core, connection mode, or routing rules.

### Routing

One selector controls the entire list:

| Mode | Listed applications and addresses | Everything else |
| --- | --- | --- |
| Through tunnel | VPN | Normal connection |
| Bypassing tunnel | Normal connection | VPN |

Routing is enabled by default with **Bypassing tunnel** selected. An empty list therefore keeps traffic through the VPN. Turning routing off also restores ordinary VPN routing.

There is no Block routing action. Use TUN mode for system-wide application routing; local proxy rules only affect traffic sent to that proxy.

### Kill Switch

The setting named **Kill Switch** enables the selected core's connection-scoped DNS/TUN leak-protection options. It is enabled by default and applies in TUN mode.

It is not a persistent internet lockout while disconnected. Its intended behavior is to protect the active tunnel session and allow normal internet access after disconnecting. Routing exceptions deliberately sent through the normal connection remain part of your routing policy. Verify the behavior with your network and both cores before relying on it.

### Server checks and statistics

The header's ping button checks the selected server when the server dropdown is closed, or all servers in the active subscription when it is open.

Choose the global check method in **Settings → Server checks**. Proxy GET/HEAD checks measure an HTTP request through the selected node, not ICMP round-trip time. TCP checks cannot assess UDP-only nodes.

Statistics is separate from that setting: it uses live ICMP while connected and is disabled by default. A server can reject ICMP even when its VPN service is available.

## Storage and privacy

The packaged Windows client uses one app-managed root:

```text
%LOCALAPPDATA%\AORAConnect\
├── app\         Application, DLLs, assets, native helpers, license notices
├── cores\       Bundled networking cores and their companion files
├── settings\    app-state.json: settings, subscription links, routing rules
└── runtime\     Generated connection, ping, and unpacking session files
```

The downloaded launcher stays wherever you save it.

Subscription links and settings are stored as **unencrypted JSON**. Generated core configurations can contain server credentials. Do not publish these files or include them in public issue reports.

Runtime session folders are removed during normal cleanup. A crash or forced termination can leave files behind. Diagnostic logs and ping history are held in memory rather than a dedicated log archive.

Older settings in `%APPDATA%\AORAVPN\app-state.json` migrate when the new settings file does not already exist. The old file is removed only after verifying its replacement; unrelated files and the old folder are left untouched.

Network activity includes subscription requests to your provider, DNS resolution, and VPN traffic. Connection tests request `https://example.com/`; proxy server checks request `https://www.gstatic.com/generate_204`. These checks contact third-party services. Live ICMP statistics target the selected server.

## Build from source

### Prerequisites

- Windows x64 for the current networking implementation and portable build.
- Flutter with Dart satisfying the constraint in [pubspec.yaml](pubspec.yaml).
- Visual Studio or Build Tools with the C++ desktop toolchain, Windows SDK, CMake, and x64 Visual C++ redistributable files.
- PowerShell.
- Rust with Cargo and the MSVC toolchain for the custom Windows helpers.
- The core archives matching the versions configured in [lib/core/core_kind.dart](lib/core/core_kind.dart).

Check your environment:

```powershell
flutter doctor
flutter pub get
```

### Prepare the development cores

The current configured versions are:

| Core | Upstream release | Expected development folder |
| --- | --- | --- |
| sing-box | [1.14.2](https://github.com/SagerNet/sing-box/releases/tag/v1.14.2) | `cores/sing-box-1.14.2-windows-amd64/` |
| Xray | [26.9.30](https://github.com/XTLS/Xray-core/releases/tag/v26.9.30) | `cores/xray-v26.9.30-windows-64/` |

Download the Windows amd64/x64 archives from the linked upstream releases and extract their contents into those folders. Keep companion DLLs, data files, and license notices beside each executable. Xray 26.9.30 is marked as an upstream prerelease; review upstream release and security information before publishing packages.

The `cores/` and `build/` directories are ignored by Git. Do not commit downloaded core binaries, real subscription URLs, credentials, or runtime configurations.

### Run for development

Run this command from the project directory:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\run_windows.ps1
```

The script requests elevation and runs Flutter. Alternatively, run `flutter run -d windows` from an elevated terminal or IDE.

Development builds resolve core binaries from the project directory. Windows release builds use the unified app storage root instead.

### Build the single executable

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_portable.ps1
```

Output:

```text
build/portable/AORAConnect-windows-x64.exe
```

To package an existing release build, add `-SkipFlutterBuild`. The script prints the executable's SHA-256 hash.

Distribute the packaged executable, **not** the raw `aoravpn.exe` from the Flutter build folder. The portable package includes the Flutter bundle, both cores, native helpers, and app-local C++ runtime DLLs.

To check extraction without launching the app or starting a VPN:

```powershell
.\build\portable\AORAConnect-windows-x64.exe --extract-only
```

### Checks

```powershell
flutter analyze
flutter test
```

Some core integration tests require the development binaries to be present. Automated configuration validation and proxy tests do not replace real TUN, DNS/IPv6, split-routing, disconnect, crash-recovery, and clean-machine tests.

## Source layout

```text
lib/
├── components/     Shared controls and dialogs
├── controllers/    Connection, server checks, and statistics state
├── core/           Core processes, network checks, and connection modes
├── pages/          Connection, Subscriptions, Routing, and Settings
├── profiles/       Link parsing and core configuration generation
├── routing/        Shared routing policy and core adapters
├── storage/        App paths, settings, and migration
└── theme/          Global palette and widget styles

windows/runner/     Flutter's C++ Windows runner and Cargo build integration
native/windows/    Rust core-host, ping, legacy recovery, and portable launcher
tool/               Development and packaging tools
test/               Automated tests
```

For visual changes, start with [lib/theme/app_colors.dart](lib/theme/app_colors.dart) and [lib/theme/app_theme.dart](lib/theme/app_theme.dart).

Our custom native helper sources are Rust; Flutter's Windows runner remains C++.
See [native/windows/README.md](native/windows/README.md) for the migration status,
Cargo prerequisites, and verification steps. Rebuild older packages to use the
Rust helpers; replacing source files alone does not update an existing EXE.

The core host uses a windowless launcher and a private console worker created
hidden from startup. That console is used for graceful core shutdown, not as a
user-facing terminal. Both helper executables are included in the portable build.

## Contributing and reporting issues

Bug reports and focused contributions are welcome. Include the app/core versions, Windows version, connection mode, steps to reproduce, and sanitized diagnostic output.

Remove subscription tokens, server credentials, personal paths, and other private information before posting. Do not submit live credentials as reproduction examples. Report potential security issues privately to the maintainer rather than disclosing credentials or exploit details in a public issue.

## License and third-party components

AORA Connect's source is licensed under **GPL-3.0-or-later**. See [LICENSE](LICENSE).

Bundled cores, DLLs, assets, and runtime components retain their own licenses and notices; the application's license does not replace them. In particular, the Xray archive includes a separate `LICENSE-Wintun` for its prebuilt `wintun.dll`.

Review all dependency terms and applicable source-distribution requirements before publishing binary packages. Include the relevant notices with redistributed components.

AORA Connect is an independent client and is not affiliated with or endorsed by the upstream core projects.
