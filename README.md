# AORA Connect

An open-source VPN client for **Windows and Android**, built with Flutter and powered by **sing-box** and **Xray**.

**Beta.** Bring your own subscription or supported server link. AORA Connect does not provide a VPN service.

[Download](https://github.com/khitori/AORA-Connect/releases) · [User guide](docs/user-guide.md) · [Build from source](docs/development.md) · [Report an issue](https://github.com/khitori/AORA-Connect/issues)

## Screenshots

<p>
  <img width="190" alt="1" src="https://github.com/user-attachments/assets/97738fac-d301-4a4d-8311-55f262b960e3" />
  <img width="190" alt="2" src="https://github.com/user-attachments/assets/de5ec378-aa36-4d5e-bdb0-86346022ebbf" />
  <img width="190" alt="3" src="https://github.com/user-attachments/assets/ceb98dde-1144-48d6-acc5-81b4ba432a71" />
  <img width="190" alt="4" src="https://github.com/user-attachments/assets/65353e1b-7ff8-4bcd-8ed3-0e7d2bbe3b4a" />
  <img width="190" alt="5" src="https://github.com/user-attachments/assets/6b684b3f-0c08-4bda-8eab-dbb49a2bfbfe" />
  <img width="190" alt="6" src="https://github.com/user-attachments/assets/26ffdcd0-6af6-4903-8739-ee23b7c9a15b" />
  <img width="190" alt="7" src="https://github.com/user-attachments/assets/58ffb8ca-f046-4c0b-bdfd-b5008db77fe4" />
</p>

## Platforms and downloads

| Platform | Status | Release file |
| --- | --- | --- |
| Windows x64 | Beta | `AORAConnect-Setup.exe` |
| Android ARM64 | Beta | `AORAConnect.apk` |
| Linux, macOS, iOS | Not supported yet | — |

Get the installer or APK from [GitHub Releases](https://github.com/khitori/AORA-Connect/releases). Windows packages include the app, networking cores, and required helpers. Portable builds are not part of the current release workflow.

## Quick start

1. Install the Windows Setup EXE or Android APK. Close any running Windows instance before upgrading.
2. Open **Subscriptions → Add subscription**, paste your subscription or server link, and press **Add**.
3. Choose a server. If it requires a different core, select it in **Settings → Core**.
4. Open **Connection** and connect. On Android, approve the VPN permission when requested.

Opening the app does not start a VPN connection automatically. Disconnect before changing subscriptions, cores, or routing rules.

## Features

- **Subscriptions:** save multiple providers, switch servers, refresh links, and view expiry details when supplied.
- **Two networking cores:** select sing-box or Xray according to the server's requirements.
- **Connection modes:** VPN (TUN), plus local proxy mode on Windows.
- **Routing:** application, domain, exact-domain, and IP/CIDR rules.
- **DNS:** Cloudflare, Google, or Quad9 in TUN mode.
- **Server checks:** ICMP, TCP, and HTTP GET/HEAD through a node, with optional live ICMP statistics.
- **Diagnostics:** configuration validation, connection tests, and core logs.
- **Updates:** verified in-app downloads, optional HTTPS mirrors, and updates from a local file.
- **Platform controls:** Windows tray actions and an Android Quick Settings tile.

Platform-specific behavior and limitations are covered in the [user guide](docs/user-guide.md) and [Android guide](docs/android.md).

### Supported links

Import supported **Hysteria2, VLESS, Trojan, Shadowsocks, and VMess** links, or HTTPS subscriptions containing plain-text or base64 URI lists.

Compatibility depends on each link's options and its profile adapter. Unsupported entries are skipped and counted; an entirely unsupported subscription cannot be imported. Arbitrary Clash YAML and full sing-box/Xray configurations are not supported.

## Languages

Choose **Settings → Language → Interface language**. The selection is remembered after restarting; **System default** follows supported device languages and falls back to English.

| Language | Name in the app |
| --- | --- |
| English | English |
| Russian | Русский |
| Simplified Chinese | 中文（简体） |
| German | Deutsch |
| French | Français |
| Spanish | Español |
| Arabic | العربية |
| Persian | فارسی |
| Hebrew | עברית |

Arabic, Persian, and Hebrew use right-to-left layouts. Connection links and technical values remain left to right. Provider content and raw diagnostic messages remain as supplied.

## Updates

Use **Settings → Updates** to check, download, or import an update. Installation requires the VPN to be disconnected. Updates preserve settings, subscriptions, and routing rules.

Release maintainers should follow the [signing and publishing guide](docs/updates.md). Every new release must increase both the public version and build counter in `pubspec.yaml`.

## Privacy and limitations

Subscription links and settings are stored as **unencrypted JSON**. Generated core configurations can contain credentials. Remove tokens, credentials, and personal information before sharing files or diagnostics.

The Kill Switch applies during the active tunnel session; it does not block normal internet access after disconnecting. This beta has not undergone an independent security audit. Real-provider behavior, DNS/IPv6 leaks, network changes, and clean-device installation require further testing.

See [storage and privacy](docs/user-guide.md#storage-and-privacy) for file locations, cleanup, and network requests made by diagnostics.

## Documentation

| Guide | Contents |
| --- | --- |
| [User guide](docs/user-guide.md) | Controls, subscriptions, DNS, routing, statistics, and storage |
| [Build from source](docs/development.md) | Windows prerequisites, core setup, builds, and source layout |
| [Android](docs/android.md) | Android development, VPN lifecycle, testing, and limitations |
| [Installation and updates](docs/updates.md) | Signing keys, release files, publishing, and verification |
| [Localization](docs/localization.md) | Translation catalogs, saved language settings, and RTL behavior |
| [Windows native components](native/windows/README.md) | Rust runner, native helpers, and smoke tests |

## Contributing

For bug reports, include the app and core versions, operating system, connection mode, reproduction steps, and sanitized diagnostics. Never post live subscription links or credentials. Report potential security issues privately to the maintainer.

## License

Application source: **GPL-3.0-or-later**. See [LICENSE](LICENSE).

Networking cores and bundled dependencies retain their own licenses and notices. Review their redistribution requirements before publishing binaries. AORA Connect is independent of the upstream core projects.
