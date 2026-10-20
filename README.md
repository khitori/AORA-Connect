# AORA Connect

An open-source VPN client built with Flutter, with sing-box and Xray networking cores.

AORA Connect is being developed as a universal client for subscriptions from different providers. It does not provide a VPN service: you need your own supported subscription or server link.

## Project status

**Early beta — Windows x64 is the current working target.**

The application-owned Windows runner, helpers, and portable launcher are Rust.
Debug/Release runner smoke tests, Rust unit/lint checks, loopback core lifecycle/ping tests, and unpack-only package
checks have passed; real-provider TUN and clean-machine checks remain separate.
See [native/windows/README.md](native/windows/README.md).

Android ARM64 has development sing-box and Xray VPN backends using Android's VPN
permission and a foreground service. Both cores have passed IPv4, IPv6,
HTTPS/DNS and repeated connect/disconnect on a physical Android 13 phone through
controlled Shadowsocks and pinned-TLS VLESS/gRPC gateways. ICMP, TCP and
Proxy GET/HEAD checks are available, including scans while connected. Android
supports release signing and verified APK updates from GitHub or a local file.
Linux networking is not implemented.
See [docs/android.md](docs/android.md) for Android setup, builds and limitations.

Android release build (after restoring/configuring the private signing files):

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_android_release.ps1 -ReleaseNotes "Describe changes here"
```

See [Android signing and updates](docs/updates.md#android-signing-and-updates) for
portable key storage, Google Drive backups and custom signing-file paths.

The application and portable Windows package can be built from source. Clean-machine and real-provider testing are still required before treating a build as production-ready. This project does not claim an independent security audit or guaranteed protection against every traffic leak.

## Features

The following list describes the Windows client; Android support is a subset
documented above.

- Multiple saved subscriptions with provider descriptions, Website/Support links, and server selection.
- Subscription cards showing the last successful update, expiry date, and days remaining when supplied by the provider.
- Import of supported Hysteria2, VLESS, Trojan, Shadowsocks, and VMess links.
- HTTPS subscriptions containing plain-text or base64-encoded URI lists.
- VPN (TUN) mode by default, plus an optional local proxy mode.
- Manual core selection, with each server showing its required core.
- Saved TUN DNS provider selection: Cloudflare (default), Google, or Quad9.
- Application, domain, exact-domain, and IP/CIDR routing rules.
- A searchable running-application picker and manual executable-name/path entry.
- One-time server checks using ICMP, TCP, Via Proxy GET, or Via Proxy HEAD.
- Optional live ICMP statistics in Settings: one sample slot per second, up to 30 samples.
- Diagnostics for configuration validation, connection checks, and core logs.
- Persistent settings and a single Windows storage root.
- Custom Windows header, circular app icon, and tray controls.
- Windows installer/uninstaller, signed in-app updates from GitHub, optional mirrors, and offline update imports.

Support depends on the link's options and the implemented profile adapters, not only its protocol name. Unsupported entries in a multi-node subscription are skipped and counted; an entirely unsupported subscription fails to import. Arbitrary Clash YAML and full sing-box/Xray configuration imports are not currently supported.

## Getting started on Windows

For a published build, download `AORAConnect-Setup.exe` from [GitHub Releases](https://github.com/khitori/AORA-Connect/releases). It installs the app and both cores, creates shortcuts, and registers AORA Connect in Windows Installed Apps. A newer Setup EXE upgrades the installation while retaining settings and subscriptions. Close the app (including its tray instance) before installing or uninstalling.

The existing `AORAConnect-windows-x64.exe` is still available as a portable alternative. If no package has been published, follow the build instructions below. The following extraction steps apply to the portable package:

1. Open the downloaded executable. It contains the application, both cores, native helpers, assets, and companion DLLs.
2. On first launch, the package extracts into `%LOCALAPPDATA%\AORAConnect`. Later launches reuse the extracted files unless the package changes or essential files are missing.
3. Approve the Windows administrator prompt. The current application requires elevation at startup for TUN mode.
4. Open **Subscriptions**, add your subscription URL or supported server link, then choose a server on **Connection**.
5. If that server requires a different core, select it in **Settings → Core**, then connect.

No separate Flutter installation or manual core download is needed to use the packaged executable. Opening the app does not automatically start a VPN connection.

Current locally built packages are unsigned. Do not disable Windows security protections to run an unfamiliar executable; use only a build whose source and origin you trust.

### Window and tray controls

Windows uses an app-designed header instead of the native title bar. Drag the
logo/title area to move the fixed-size window. The header buttons are ordered
Settings, Hide to tray, and Close app. The app logo appears beside the title on
every page. The bottom navigation opens Connection, Subscriptions, and Routing;
Settings opens from the header.
**Hide to tray** keeps the app
and its connection running; click the tray icon to reopen it. Right-click the
icon for **Show AORA Connect**, **Disconnect**, or **Exit**. Disconnect is enabled
when the connection can be stopped. **Close app**, tray **Exit**, and Alt+F4 await
ping/core cleanup before closing the window. The app stays visible if adding
the tray icon fails, and attempts to restore it after Explorer restarts.

Close the running application before opening a different package. For an installed copy, use a newer Setup EXE or **Settings → Updates**. For a portable copy, replacing the downloaded launcher retains settings; the signed Setup EXE can also install into that existing storage root.

### Application updates and uninstalling

**Settings → Updates** checks GitHub automatically at startup by default. Users
approve downloads and installation; installing requires the VPN to be disconnected
and server checks to be idle. Additional HTTPS update sources are optional.
**Update from file** verifies the same Setup EXE locally, without GitHub access.
The updater checks the release signature, SHA-256, application/platform, and
version before launching the installer. It rejects older or modified packages.

The Windows uninstaller removes app/core files and shortcuts. Saved data is kept
by default; the interactive uninstaller offers a checkbox to delete it.
Update signing is separate from Windows code signing and does not eliminate
SmartScreen or administrator prompts.

See [docs/updates.md](docs/updates.md) for signing-key storage, release publishing,
installer builds, mirrors, and offline updates.

### Subscriptions

Use the saved-subscription selector to switch providers. Each subscription has
its own server selection, last update time, and expiry information. The two
cards above the provider description show **Last updated** and **Expires**.
Dates use `DD.MM.YYYY` in your local time; the expiry card also shows days left
or **Expired**. If the provider does not supply a usable expiry date, it shows
**Not provided**.

Expiry is read from the provider's `subscription-userinfo` metadata (`expire`
in Unix seconds), either in the HTTP response headers or URI-list comments.
The last update records a successful subscription fetch; switching to an
already loaded subscription does not reset it. Failed refreshes keep the
previous dates, and both dates are saved with the subscription.

Refresh the active subscription from Connection or Subscriptions. If the VPN
is connected, clicking Refresh shows a dismissible notification asking you to
disconnect first. Provider descriptions and Website/Support buttons appear
below the timing cards; links are enabled when the provider supplies them.

### Connection modes

- **VPN (TUN):** routes system traffic through a virtual network interface, subject to your routing rules.
- **Local proxy:** listens on `127.0.0.1:17890`. Only applications explicitly configured to use that proxy send traffic through it; this mode does not configure a system proxy for you.

Disconnect before changing the core, connection mode, or routing rules.

### DNS

Choose **Settings → DNS** while disconnected. Cloudflare is the default;
Google and Quad9 are also available. The choice is saved with your settings.
In TUN mode, sing-box uses the selected provider's DNS-over-HTTPS endpoint,
including its direct/VPN split-routing resolvers. Xray assigns that provider's
DNS address to the TUN interface; DNS traffic follows Xray's routing policy.
Local-proxy mode does not configure system-wide DNS. This selection does not
change Windows' physical-interface DNS settings or the initial system lookup
of the VPN server. It is not a fix
for all Xray split-routing DNS privacy limitations.

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
├── cores\windows\  Bundled Windows networking cores and their companion files
├── settings\    app-state.json: settings, subscription links/dates, routing rules
└── runtime\     Generated connection, ping, and unpacking session files
```

The downloaded launcher stays wherever you save it.

Installed copies also have an `uninstall/` folder and `installed-version.txt`
under that root. Update preferences are in `settings/updates.json`; downloaded
update sessions are staged in `runtime/`. On startup, the updater scans all of
its `update-*` sessions and removes obsolete packages, metadata and staged
helpers. One verified newer package is retained for retry. Active installer
handoffs are protected; installed APK copies in Android's private cache are
also cleaned up. Settings, cores and manually downloaded originals are never
part of this cleanup.

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
- Rust with Cargo and the MSVC toolchain for the Windows runner, helpers, and launcher.
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
| sing-box | [1.14.2](https://github.com/SagerNet/sing-box/releases/tag/v1.14.2) | `cores/windows/sing-box-1.14.2-windows-amd64/` |
| Xray | [26.9.30](https://github.com/XTLS/Xray-core/releases/tag/v26.9.30) | `cores/windows/xray-v26.9.30-windows-64/` |

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

### Build the installer and update metadata

Install Inno Setup 6 and configure the private release key as described in
[docs/updates.md](docs/updates.md). Before a new release, increase the version in
`pubspec.yaml` (for example, `version: 1.0.5+1`).

Run the following command from the project directory containing `pubspec.yaml`.
Flutter and Rust must be on PATH. If Windows Developer Mode is disabled, open
PowerShell **as administrator** for the build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_installer.ps1 -ReleaseNotes "Describe this release"
```

The script stages the Windows app and cores, compiles the installer, and generates a
signed `build/installer/AORAConnect-Setup.exe` and `aora-update.json`. Publish both
as assets of the GitHub release matching `v<major.minor.patch>` from `pubspec.yaml`
(for example, `v1.0.5` for `1.0.5+1`). No portable executable is generated by the
installer build; its staging files are under `build/installer/`.
Release metadata is generated automatically; the private key is never bundled.

Verify the generated installer without running it:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\test_update_package.ps1
```

Rebuild after changing source or the version; do not reuse an older installer or
manually edit the signed JSON. Test installation and upgrade on a second PC
before publishing.

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

Routing checks include actual local-proxy startup of both bundled cores with
application, domain, and IP rules in both routing directions. These checks do
not change system routes or start a system-wide VPN. Startup failures include
the core's diagnostic output so an exit code alone does not hide the cause.

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

windows/runner/     Window resources, administrator manifest, and Cargo integration
native/windows/    Rust window runner, core-host, ping, recovery, and launcher
tool/               Development and packaging tools
test/               Automated tests
```

For visual changes, start with [lib/theme/app_colors.dart](lib/theme/app_colors.dart) and [lib/theme/app_theme.dart](lib/theme/app_theme.dart).

The header logo is `lib/assets/logo.png`. After replacing that image, run
`powershell -ExecutionPolicy Bypass -File tool/update_app_icon.ps1` to regenerate
the multi-resolution Windows icon. The generator renders the artwork at 4x
resolution and applies a symmetric circular alpha mask with a smooth two-pixel
edge and a 4% transparent margin (at least one pixel). The ICO includes twelve
sizes from 16px to 256px, including 40px, 72px, and 96px frames for scaled desktops.
Small frames use native 32-bit icon bitmaps; the 256px frame uses PNG compression.
Run `powershell -ExecutionPolicy Bypass -File tool/test_app_icon.ps1` to verify
partial edge transparency and the encoded icon masks.
Installer builds regenerate and validate this icon before compiling the Windows app.
The source logo is not cropped or modified. Both the app runner and portable launcher
use that icon; rebuild the package to include it. The launcher build uses the
Windows SDK resource compiler already supplied with the build tools.

Our application-owned Windows native sources, including the window runner, are Rust.
Flutter's generated files, engine, and upstream Windows plugins may still use C++;
the Windows C++ build tools remain required for those dependencies.
See [native/windows/README.md](native/windows/README.md) for the migration status,
Cargo prerequisites, and verification steps. Rebuild older packages to use the
Rust helpers; replacing source files alone does not update an existing EXE.

The runner generates its engine-properties layout and plugin registrations from
the installed Flutter SDK and plugin registrant during the Cargo build. Its
hidden, isolated first-frame check is available through
`powershell -ExecutionPolicy Bypass -File tool/test_windows_runner.ps1` after a
Release build. This test does not copy networking helpers or real app data.

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
