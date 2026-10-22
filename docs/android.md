# Android development

[← Back to AORA Connect](../README.md) · [Release signing and updates](updates.md#android-signing-and-updates)

The ARM64 Android app includes sing-box 1.14.2 and Xray 26.9.30 through a shared
native library and Android's `VpnService`. Android ARM64 is a beta target with
signed APK packaging. It uses the shared subscription interface and
DNS/routing settings. One-time server checks and optional live ICMP statistics
are available. Android supports verified in-app and offline APK updates;
local-proxy connection mode is not implemented.

## Build and run

Install Flutter, Android SDK Platform 36, SDK command-line tools, NDK
`28.2.13676358`, Git and a JDK (the build script defaults to Android Studio's
bundled JDK). Enable USB debugging on the phone and authorize the PC.

Run from the directory containing `pubspec.yaml`:

```powershell
flutter doctor -v
flutter devices
flutter pub get
powershell -ExecutionPolicy Bypass -File .\tool\build_android_core.ps1
flutter run -d <device-id>
```

The core build script downloads a checksum-verified portable Go toolchain into
`build/android-core/`, uses Go 1.27.2, gomobile `v0.1.12` and pinned source:

- sing-box: `af6e64c3b69e6132ebaee0e1a3d24e93903f6709`.
- Xray: `b26a91de4f3294e26a0ad0a970b81a386a41f789`.

Both cores and the app-owned Go bridge are linked into one Go runtime in
`cores/android/sing-box-1.14.2/libbox.aar`. The script applies the checked-in
Xray gRPC lifecycle patch and copies its extension from `native/android/xray/`.
The extension tracks gRPC connections by outbound tag so scans release only
their own connections; stopping Xray releases the remaining pool. This does
not change certificate verification or protocol configuration. Keep the patch,
extension and source pins together when reproducing a build.

The script copies both upstream license notices into the APK. Downloaded source,
toolchains and binaries are
ignored by Git. The first core build can take considerable time and disk space.
Pass `-SdkRoot` or `-JavaHome` if your SDK/JDK is installed elsewhere.

While Flutter is running, `r` hot reloads Dart changes, `R` restarts Flutter and
`q` stops the debugging session. Kotlin, manifest, Gradle and libbox changes
require a full rebuild.

To build a debug APK separately:

```powershell
flutter build apk --debug --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. The current core build is
ARM64 only. Release builds require a private release keystore and never fall
back to the development signing key. See [updates.md](updates.md#android-signing-and-updates)
for key backup/restore and the release build command. Broader device testing
is still required before treating an Android build as production-ready.

## Connection lifecycle

Choose a server and its required core, then tap Connect. Android asks for notification permission
and VPN approval as needed. A foreground notification shows the connection and
provides a Disconnect action. The native service owns the VPN, so leaving the
Flutter screen or restarting Flutter does not intentionally disconnect it.
Startup waits for Android's default-network callback to report the VPN with
link properties and unblocked access before returning success. This prevents
the immediate HTTPS check from racing the physical-to-VPN network switch.

Outbound core sockets are protected from re-entering the VPN and bound to one
shared physical-network selection. A single process-owned Android network request
tracks the best INTERNET/NOT_VPN network; service routing, both cores, native
server resolution and ping checks use that same selection. Capabilities, link
properties and (on Android 10+) unblocked access must arrive before it is usable.
There is no fallback to the first network in `allNetworks`. Handover and loss
invalidate old readiness; late callbacks for an old network cannot replace the
new selection. Server addresses are resolved again before an Android connection.
Failure to protect an Xray socket aborts that dial;
it does not silently fall back to an unprotected socket. The service
installs the TUN addresses, DNS and IPv4/IPv6 routes from the selected core's profile. Disconnect
closes the core instance, TUN file descriptors, command server and service's
network observer. The shared network request lasts until the application process
exits so disconnected server checks can use it too. It does not leave a persistent
firewall block. Always-on/lockdown and automatic recovery after process death are
not implemented.

Application routing uses Android package names, such as `com.android.chrome`,
not Windows executable paths. Application-rule device testing remains necessary.
The Android rule editor offers a searchable installed-app picker with names,
icons and package IDs. It lists launcher-visible applications in the current
Android profile without requesting visibility of every system package. Manual
package entry remains available for other apps. The Windows running-process
picker is unchanged. DNS provider choices
and domain/IP rules use the shared sing-box configuration generator.

Xray application rules use Android's connection-owner lookup and package names;
this requires Android 10 or later. Its Windows-specific automatic routing and
WFP settings are omitted because Android owns the TUN routes and DNS settings.

## Server checks and statistics

Diagnostics receives sing-box's daemon logs, including DNS and connection
errors, rather than only service lifecycle messages. Logs are bounded, retained
across Flutter reconnections and stripped of terminal color escapes. Validate
reports configuration success/failure; it does not test resolver or server
reachability. Startup logs report the physical transport/interface/network ID,
address families, core/protocol and numeric VPN server IP/port. These added
summaries do not dump configurations, subscription URLs, credentials or SNI.
The connection check logs DNS/connection (including TLS), HTTPS request and body
stages, and timeouts name the stage. On failure, endpoint/network context and the
latest core error are repeated after noisy traffic logs, before stopping the VPN.

The existing header behavior is unchanged: with the server selector closed,
check the selected node; with it open, check the active subscription's nodes.
The controller runs up to 32 checks concurrently.

- ICMP uses Android ICMP datagram sockets, protected and bound to the normal
  network, with matched echo replies and measured elapsed time. Blocked ICMP is
  an error, not a fabricated zero-millisecond result.
- TCP uses the physical network and the node's port. UDP-only nodes remain N/A.
- Proxy GET/HEAD sends the test request through that node, with no direct
  fallback. sing-box checks use a separate loopback-only session and cache;
  Xray checks attach uniquely tagged temporary outbounds to its managed
  instance. They do not open a second TUN or replace the active VPN. Invalid
  profiles are isolated from healthy nodes. Cancelling a scan releases its
  resources, not the VPN.

Live Statistics still uses ICMP independently of the global check method, one
sample slot per second, retaining 30 slots. It is off by default. ICMP measures
the server endpoint over the physical network, not end-to-end application
latency through a proxy.

## Storage

Settings, subscription credentials and runtime files are stored in the app's
private files directory through the `aoravpn/app_data` channel. Native core data
is under `runtime/android-core`; temporary native files use Android's private
cache directory. Android backup is disabled for these credential-bearing files.
No Windows helpers are launched. Normal uninstall removes private app data.
Do not publish private settings or core configurations in issue reports.

## Verification

Static analysis and targeted bridge/controller/routing tests cover state
restoration, explicit stop behavior, permission-error cleanup and Android
package-name rule generation. Native Go tests cover scan ownership, protection
failures, malformed-node isolation and non-destructive validation. A real
Android 13 ARM64 phone passed repeated connect/disconnect cycles through
controlled Shadowsocks 2022 and pinned-TLS VLESS/gRPC gateways: encrypted IPv4
and IPv6 requests, HTTPS with DNS resolution, and normal internet access after
disconnecting. Mixed-core checks run both disconnected and alongside each core.

The optional device harness is isolated from `lib/main.dart` and does not change
saved subscriptions. To reproduce with the Windows development sing-box core:

1. Install OpenSSL (the Windows harness defaults to Git's bundled OpenSSL), run
   `dart run tool/android_vpn_gateway.dart` and keep it running. It creates
   a short-lived self-signed test certificate and
   temporary test credentials/configurations under `build/android-vpn-smoke/`
   and listens only on PC loopback port 18080.
2. In another terminal, start the loopback-only gateway:

   ```powershell
   .\cores\windows\sing-box-1.14.2-windows-amd64\sing-box.exe run -c .\build\android-vpn-smoke\gateway.json
   adb -s <device-id> reverse tcp:17991 tcp:17991
   adb -s <device-id> reverse tcp:17992 tcp:17992
   flutter run -d <device-id> -t test_driver/android_vpn_smoke.dart --dart-define-from-file=build/android-vpn-smoke/defines.json
   ```

3. Approve Android's VPN request. The harness prints
   `AORA_ANDROID_VPN_SMOKE_OK` after two cycles per core and disconnects automatically.
4. Stop the test processes, remove the specific reverse mapping with
   `adb -s <device-id> reverse --remove tcp:17991` and
   `adb -s <device-id> reverse --remove tcp:17992`, then rebuild/run the normal
   app with `flutter run -d <device-id> -t lib/main.dart`.

This proves the tested packet path and cleanup, not universal leak protection.
The proxy test resource is a controlled gateway-only address; public HTTPS/DNS
is checked separately. Loopback ICMP confirms the implementation but does not
prove that an arbitrary remote server accepts ICMP.
Real-provider protocols, split routing, DNS/IPv6 leaks, Wi-Fi/mobile handover,
battery restrictions and process-death behavior still need broader testing.
