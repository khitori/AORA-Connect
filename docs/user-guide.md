# User guide

[← Back to AORA Connect](../README.md)

Detailed Windows controls, connection settings, subscriptions, and data storage. For Android-specific behavior, see [Android development](android.md).

## Window and tray controls

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

Close the running application before installing a newer Setup EXE, or use **Settings → Updates**.

## Application updates and uninstalling

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

See [the update guide](updates.md) for signing-key storage, release publishing,
installer builds, mirrors, and offline updates.

## Subscriptions

Use the saved-subscription selector to switch providers. Each subscription has
its own server selection, last update time, and expiry information. The two
cards above the provider description show **Last updated** and **Expires**.
Dates and times follow your selected language and local time zone; the expiry card also shows days left
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

## Connection modes

- **VPN (TUN):** routes system traffic through a virtual network interface, subject to your routing rules.
- **Local proxy:** listens on `127.0.0.1:17890`. Only applications explicitly configured to use that proxy send traffic through it; this mode does not configure a system proxy for you.

Disconnect before changing the core, connection mode, or routing rules.

## DNS

Choose **Settings → DNS** while disconnected. Cloudflare is the default;
Google and Quad9 are also available. The choice is saved with your settings.
In TUN mode, sing-box uses the selected provider's DNS-over-HTTPS endpoint,
including its direct/VPN split-routing resolvers. Xray assigns that provider's
DNS address to the TUN interface; DNS traffic follows Xray's routing policy.
Local-proxy mode does not configure system-wide DNS. This selection does not
change Windows' physical-interface DNS settings or the initial system lookup
of the VPN server. It is not a fix
for all Xray split-routing DNS privacy limitations.

## Routing

One selector controls the entire list:

| Mode | Listed applications and addresses | Everything else |
| --- | --- | --- |
| Through tunnel | VPN | Normal connection |
| Bypassing tunnel | Normal connection | VPN |

Routing is enabled by default with **Bypassing tunnel** selected. An empty list therefore keeps traffic through the VPN. Turning routing off also restores ordinary VPN routing.

There is no Block routing action. Use TUN mode for system-wide application routing; local proxy rules only affect traffic sent to that proxy.

## Kill Switch

The setting named **Kill Switch** enables the selected core's connection-scoped DNS/TUN leak-protection options. It is enabled by default and applies in TUN mode.

It is not a persistent internet lockout while disconnected. Its intended behavior is to protect the active tunnel session and allow normal internet access after disconnecting. Routing exceptions deliberately sent through the normal connection remain part of your routing policy. Verify the behavior with your network and both cores before relying on it.

## Server checks and statistics

The header's ping button checks the selected server when the server dropdown is closed, or all servers in the active subscription when it is open.

Choose the global check method in **Settings → Server checks**. Proxy GET/HEAD checks measure an HTTP request through the selected node, not ICMP round-trip time. TCP checks cannot assess UDP-only nodes.

Statistics is separate from that setting: it uses live ICMP while connected and is disabled by default. A server can reject ICMP even when its VPN service is available.

## Storage and privacy

The packaged Windows client uses one app-managed root:

```text
%ProgramFiles%\AORAConnect\
├── app\         Application, DLLs, assets, native helpers, license notices
├── cores\windows\  Bundled Windows networking cores and their companion files
├── settings\    app-state.json: settings, subscriptions, routing rules; language.json: language
└── runtime\     Generated connection, ping, and unpacking session files
```

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

Updating from `%LOCALAPPDATA%\AORAConnect` migrates the installation automatically,
including through the existing in-app updater. A temporary launcher handles the
old restart path and is removed after the new client renders its first frame.
Settings, subscriptions, routing rules, language and update preferences migrate
into the Program Files root. Conflicting
settings and unrelated files are retained for recovery. Windows installation and
installing updates require administrator approval; the app itself runs with
your ordinary rights. Update downloads are kept in `updates`, the only folder
your account may write to. Development builds
use the same installed settings and service; changes in development affect the installed app's configuration too.

Older settings in `%APPDATA%\AORAVPN\app-state.json` migrate when the new settings file does not already exist. The old file is removed only after verifying its replacement; unrelated files and the old folder are left untouched.

Network activity includes subscription requests to your provider, DNS resolution, and VPN traffic. Connection tests request `https://www.gstatic.com/generate_204` with `https://cp.cloudflare.com/generate_204` as a fallback; proxy server checks also use gstatic. These checks contact third-party services. Live ICMP statistics target the selected server.
