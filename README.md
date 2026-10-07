# AORA VPN

An open-source, universal VPN client built with Flutter.

The current development targets are Windows, Linux, and Android. The project
uses sing-box as its networking core. The Windows client can import Hysteria2
subscriptions. VPN (TUN) is the default connection mode; local proxy mode is
available as an explicit alternative.

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
executable. The `cores/` directory is ignored by Git.

Paste an HTTPS subscription URL, press Load subscription, select a server, and
press Connect. VPN (TUN) creates the Windows tunnel with IPv4/IPv6 automatic
routing and tunneled DNS. The server address is resolved before TUN starts to
avoid DNS bootstrap loops; TLS still uses the original server name.

Local proxy mode listens on `127.0.0.1:17890` and leaves system routing unchanged.
Mode and server selection are disabled while connected. Connect checks
`https://example.com/` using the selected mode and stops the core if the check
fails. Test connection repeats that check. Validate checks the configuration.

The importer currently supports plain or base64 URI lists containing
`hysteria2://` or `hy2://` entries with a single port, SNI, optional insecure TLS,
and salamander/gecko obfuscation. Other URI parameters and subscription formats
are rejected explicitly.

URLs are entered at runtime and are not saved in the repository. Generated
credential-bearing configs are stored in a temporary session directory and
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
`aoravpn_core_host.exe` launches sing-box in a private console and forwards its
logs. Stop sends CTRL_BREAK to the core and waits for it to close its tunnel,
routes, and DNS resources. The host uses forced termination only if graceful
shutdown exceeds eight seconds. TUN cannot start without this helper.

Core paths are resolved from the development project directory. Release
packaging and Linux/Android engine implementations remain future work.

Run static analysis and tests:

```sh
flutter analyze
flutter test
```

## License

AORA VPN is licensed under the GNU General Public License, version 3 or any
later version. See [LICENSE](LICENSE).

sing-box is a separate upstream project distributed under its own
GPL-3.0-or-later terms and copyright notices. This project is not affiliated
with or endorsed by SagerNet or the sing-box project.
