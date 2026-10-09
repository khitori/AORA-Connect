# AORA VPN

An open-source, universal VPN client built with Flutter.

The current development targets are Windows, Linux, and Android. The project
uses sing-box and Xray as separate networking cores. The Windows client imports
plain or base64 URI-list subscriptions with supported Hysteria2, VLESS, Trojan,
Shadowsocks, and VMess links. Pinned VLESS TLS/gRPC links are assigned to Xray;
the other currently supported links use sing-box. VPN (TUN) is the default
connection mode; local proxy mode is available as an explicit alternative.

## Development

The Flutter source is organized by responsibility:

- `lib/main.dart`: application entry point.
- `lib/app.dart`: app theme, navigation shell, and lifecycle.
- `lib/pages/`: complete Connection and Settings screens.
- `lib/components/`: subscription input, server selection, connection controls,
  logs, and the animated menu.
- `lib/controllers/`: connection state and actions, subscription loading, and
  session cleanup.
- `lib/core/`: platform/core integration and configuration modes.
- `lib/profiles/`: subscription parsing and profile configuration.
- `lib/theme/app_colors.dart`: named website colours in CSS-style HSL values.
- `lib/theme/app_theme.dart`: global colour mapping and widget defaults.

To change colours, edit the named values in `AppColors`. For example,
`hsl(2.7, 78.5, 49.2)` is the same colour as CSS `hsl(2.7 78.5% 49.2%)`.
The theme applies these colours to backgrounds, menus, text, buttons, input
borders, and feedback. The fonts are unchanged.

To customise one widget, import `theme/app_colors.dart` (using the relative path
from that file) and use `AppColors.card`, `AppColors.ink`, or another named
colour in its style. To change defaults for all widgets of a type, edit their
theme in `AppTheme.light`. Existing explicit component styles take precedence.

Check the local Flutter toolchain:

```sh
flutter doctor
```

Run the desktop client on Windows from an ordinary terminal. This launcher
requests UAC first and starts Flutter in the elevated terminal:

```sh
powershell -ExecutionPolicy Bypass -File .\tool\run_windows.ps1
```

The Windows application requires administrator privileges from startup. Opening
the executable normally lets Windows show its UAC prompt before the window
appears. For Flutter debugging, run the terminal or IDE elevated before using
`flutter run -d windows`; Flutter's direct process launch cannot display UAC.
Administrator approval is controlled by Windows and is not a permanent grant
for subsequent launches.

For development, extract the official sing-box 1.14.2 Windows amd64 archive into
`cores/sing-box-1.14.2-windows-amd64/`, keeping its DLL and license beside the
executable. For Xray, extract the official v26.9.30 Windows 64-bit archive into
`cores/xray-v26.9.30-windows-64/`, keeping `wintun.dll`, `LICENSE`, and
`LICENSE-Wintun` beside `xray.exe`. The `cores/` directory is ignored by Git.
The Xray archive for this development checkout was verified against GitHub's
SHA-256 digest `b17a619343c11b89d8faf36278298856749b15c52277d875d32051b33dcda617`.
This Xray release is tagged as a prerelease; it was chosen because the latest
non-prerelease is affected by the upstream certificate-pinning advisory. Recheck
upstream security status before any release.

Open the compact Add subscription row, paste an HTTPS subscription URL, press
Add, select a server, and press Connect. The Subscriptions page lists each
imported node and its required core. Select sing-box or Xray manually in
Settings; this choice is saved. If
the selected node needs another core, Connect stays unavailable until the
matching core is selected. VPN (TUN) creates the Windows tunnel with IPv4/IPv6 automatic
routing and tunneled DNS. The server address is resolved before TUN starts to
avoid DNS bootstrap loops; TLS still uses the original server name.

Local proxy mode listens on `127.0.0.1:17890` and leaves system routing unchanged.
Mode and server selection are disabled while connected. Connect checks
`https://example.com/` using the selected mode and stops the core if the check
fails. Test connection repeats that check. Validate checks the configuration.
The Connection page also has Statistics: while connected it sends ICMP echo
requests to the selected server every five seconds, showing the last 30 results
and missed replies as gaps. One-time checks are beside the main server selector:
the button checks all nodes in the active subscription, showing each node's
required core and result in the dropdown and on the Subscriptions page. Checks
can be cancelled and results update progressively. Dropdown rows build lazily.
Settings saves a global server ping method: ICMP, TCP, Via Proxy GET (default),
or Via Proxy HEAD. Statistics remains an independent live ICMP graph.
Proxy checks share one isolated local proxy session per required core,
bound to the physical network, and request `https://www.gstatic.com/generate_204`.
The measured time runs from request initiation to response headers, excluding
local core startup. Each node has its own loopback inbound routed to its own
outbound. A scan starts at most two core sessions (one sing-box and one Xray)
and runs up to 32 requests or direct probes concurrently. DNS and physical-source
lookups are shared for nodes on the same host. Malformed configurations are
isolated if the core rejects the group. Changing subscriptions or ping method cancels stale checks and clears
their results. TCP checks are unavailable for UDP-only Hysteria/TUIC nodes.
The Windows build includes `aoravpn_server_ping.exe` for IPv4/IPv6 ICMP round-trip
measurements. A server may block ICMP while its VPN service works normally;
missing replies are not proof of a failed VPN connection.
Ping requests are bound to the source address of the physical internet adapter
so the TUN stack cannot substitute a local echo response for server latency.
Statistics shows the resolved target IP. `tool/verify_ping_route.ps1 -ConfigPath
<existing-runtime-config>` compares default-route and physical-source ping in a
controlled elevated sing-box TUN session and closes its core afterward.

Leak protection is enabled by default in VPN (TUN) mode and belongs to the active
core session. sing-box uses `strict_route`; Xray uses `autoSystemWfpBlockLeak`
with `dns` and `misconfigtun`. These options protect the cores' documented DNS
and TUN routing cases; they do not install a persistent disconnected lockout.
The setting is saved as `connectionLeakProtectionEnabled`, independently of the
old Kill Switch setting. The Windows build retains `aoravpn_kill_switch.exe`
only to remove persistent rules left by older builds before loading subscriptions
or starting a connection. The old helper's `arm` command remains disabled.

The Routing bottom tab stores applications and addresses shared by both cores.
One mode applies to the whole list: Through tunnel sends listed items through
the selected VPN server and everything else directly; Bypassing tunnel sends
listed items directly and everything else through the selected VPN server.
Routing has no blocking action. Older saved per-rule actions, including Block,
are discarded when loaded; their applications/addresses are retained. Routing
starts ON with Bypassing tunnel selected for new settings, so an empty list
keeps all traffic through the VPN; turning it OFF restores ordinary VPN routing.
The application rule editor includes a searchable running-process picker on
desktop, as well as manual process-name or executable-path entry.
Disconnect before editing rules; changes regenerate and validate the selected
profile's configuration. Use TUN mode to capture system traffic. Routing in
proxy mode only applies to traffic sent to the local proxy. Application paths
are normalized for the selected core, and Xray enables routing-only sniffing
for domain matching. sing-box DNS rules follow the list mode for domain and
application matches, with the opposite DNS route as the fallback.
Core configuration checks do not replace live tests of
process identification and domain detection on the user's system.
If the UI cannot open, run `aoravpn_kill_switch.exe disarm` from an elevated
terminal in the built application's directory to remove its rules.

The importer supports plain or base64 URI lists. It routes VLESS TLS/gRPC
links with a `pcs` full-certificate SHA-256 pin to Xray without disabling TLS
verification. Unsupported URI parameters and subscription formats are rejected
explicitly. Xray support does not yet cover every Xray protocol or every
subscription encoding; additional profile adapters can be added separately.

URLs are entered at runtime and are not saved in the repository. Generated
credential-bearing configs are stored in a private runtime session directory and
removed on normal session cleanup. Abrupt termination can leave temporary files.
The current proxy mode does not change system routing. The Windows application
requires administrator rights at startup for default TUN mode.

For a command-line connection check, run `dart run tool/check_connection.dart`
from the project directory and enter the subscription URL on stdin. The tool
stops the core and deletes its temporary configuration when it finishes.
Use `--tun` from an administrator terminal for the system-wide test, or
`--tun --validate-only` to check the generated config without changing routing.

The Windows runner places its process and children in a kill-on-close Job
Object, so exiting the application also terminates the core. The bundled
`aoravpn_core_host.exe` launches the selected core in a private console and forwards its
logs. Stop sends CTRL_BREAK to the core and waits for it to close its tunnel,
routes, and DNS resources. The host uses forced termination only if graceful
shutdown exceeds eight seconds. TUN cannot start without this helper.

Windows writable storage has one root: `%LOCALAPPDATA%/AORAConnect`.
Settings and subscriptions are in `settings/app-state.json`; generated connection
and proxy-ping configs are in `runtime/profile-*` and `runtime/ping-*` respectively.
Existing `%APPDATA%/AORAVPN/app-state.json` is validated and migrated on first read
when no new settings file exists. Only the old settings file is removed after
the replacement is verified; unrelated files and the old folder are retained.
Session folders are removed during normal cleanup; abrupt exit can leave them.
Linux uses `${XDG_CONFIG_HOME:-$HOME/.config}/AORAConnect`, and Android uses its
private files directory, with the same settings/runtime separation.
Windows release builds resolve core paths under `AORAConnect/cores`, while
development builds still use the project directory. The launcher places
the app, DLLs, assets and helpers under `AORAConnect/app`. The portable
Windows launcher now implements this packaging. Linux/Android engine implementations remain
future work. The
current Xray integration has been checked with Xray's `run -test` for TUN and
proxy configuration, and a local proxy process lifecycle test. A real elevated
TUN connection to a provider still needs end-to-end testing.

Run static analysis and tests:

```sh
flutter analyze
flutter test
```

## Windows portable build

Run `powershell -ExecutionPolicy Bypass -File tool/build_portable.ps1` from the
project directory with Flutter on PATH and the two development cores present.
Use `-SkipFlutterBuild` to package an existing release build. The result is
`build/portable/AORAConnect-windows-x64.exe`; distribute this file, not the raw
Flutter runner executable. The package includes both cores, their companion
DLLs and notices, Flutter assets, native helpers and app-local Visual C++ runtime
DLLs. Review the included dependency licenses before public distribution.

The launcher unpacks into `%LOCALAPPDATA%/AORAConnect/app` and `cores`, keeping
`settings` untouched. It uses a temporary `runtime/package-*` staging folder
under the same root and removes that folder after extraction. A package hash
marker avoids repeating extraction on subsequent runs; a different package or
missing essential files triggers extraction again. Close the running app before
opening a different package. Launching the application requests Windows UAC
approval for TUN; it does not automatically connect to a VPN.

`AORAConnect-windows-x64.exe --extract-only` tests unpacking without starting the
app, requesting elevation, or changing network routing. The current package is
unsigned; clean-machine launch and live connection checks remain manual tests.

## License

AORA VPN is licensed under the GNU General Public License, version 3 or any
later version. See [LICENSE](LICENSE).

sing-box is a separate upstream project distributed under its own
GPL-3.0-or-later terms and copyright notices. This project is not affiliated
with or endorsed by SagerNet or the sing-box project.

Xray-core is a separate upstream project under MPL-2.0. The prebuilt
`wintun.dll` in its Windows release has a separate, restrictive binary license;
do not treat that DLL as part of this project's open-source code or redistribute
it without reviewing its included `LICENSE-Wintun` terms. All development core
binaries remain ignored by Git.
