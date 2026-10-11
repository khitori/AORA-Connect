# Windows installation and updates

The default update source is the `khitori/AORA-Connect` GitHub repository.
Users may add optional HTTPS metadata mirrors in **Settings → Updates**.
No mirror is required or configured by default.

## User workflows

- Download `AORAConnect-Setup.exe` and run it to install or upgrade. Close the
  existing app first, including its tray instance. The installer waits for the
  app/portable launcher to close and does not forcibly terminate the VPN core.
- The installer registers AORA Connect in Windows Installed Apps and creates
  a Start Menu shortcut; a desktop shortcut is optional.
- Application files and both cores use `%LOCALAPPDATA%\AORAConnect`, alongside
  the existing settings and runtime folders. The uninstall files are under
  `uninstall/` in the same root.
- Installing a newer release preserves subscriptions, settings, routing rules,
  and update preferences. Running an older installer is rejected once an
  installer version has been recorded. Running the same version can repair it.
- Uninstall from Windows Installed Apps. Data is kept by default. The
  interactive uninstaller offers a checkbox to delete settings/subscriptions
  and runtime files. Silent uninstall always retains user data.
- In the app, startup update checks are enabled by default and can be disabled.
  Downloading and installing require user action. Installation requires an idle,
  disconnected VPN and no active server-check batch.
- **Update from file** accepts the same signed Setup EXE downloaded anywhere,
  without contacting GitHub. It verifies the package and requires a newer build.

## Release signing key

Update verification uses Ed25519 and SHA-256 independently of Windows
Authenticode certificates. This signature does not remove SmartScreen or UAC
prompts. Direct execution of a downloaded EXE still depends on trusting its
source/Windows publisher verification; the app's import path independently
checks the pinned release key before executing it.

The public key is in `release/update-public-key.txt` and is compiled into the
Rust verification helper. The private key is **outside the repository**, at
`%USERPROFILE%\.aora-connect\release-private.json` on this development PC.
Back it up securely. Never publish the private file or replace this key for
an existing release channel without arranging a trusted key transition.

For a new, separate channel, create a key once, from the project directory:

```powershell
dart run tool/sign_release.dart init C:/Private/AORA/release-private.json
```

This command refuses to overwrite existing private keys. Restrict access to
the private file. Only the public key belongs in version control.

## Build and publish

1. Increase `version: major.minor.patch+build` in `pubspec.yaml`. The updater
   compares all four numbers; published versions must increase.
2. Install Inno Setup 6 and the normal Flutter/Rust Windows prerequisites.
   If Windows Developer Mode is disabled, run builds from an elevated terminal,
   or run `tool/prepare_windows_plugins.ps1` elevated to prepare plugin links.
3. Build the release:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_installer.ps1 -ReleaseNotes "Describe changes here"
```

Use `-SigningKey C:/Private/AORA/release-private.json` for a custom key location.
`-SkipBuild` reuses the most recent complete portable staging bundle. Rebuild
after changing source or the version; the script verifies the finished package.

4. Create a GitHub release with tag **`v<version+build>`**, for example
   `v1.0.1+2`, and attach both files from `build/installer/`:

   - `AORAConnect-Setup.exe`
   - `aora-update.json`

The build script generates and signs the JSON automatically, including the
version, installer URL, SHA-256, byte length, and release notes. No JSON editing
is needed. GitHub's `releases/latest/download/aora-update.json` endpoint serves
the stable channel; prereleases are not part of that endpoint. Do not publish
unfinished builds to the stable channel.

Mirrors can host copies of these same two files. Metadata and payload must not
be modified; any invalid signature or altered installer is rejected. Metadata
is limited to 64 KiB, installer payloads to 512 MiB, redirects to HTTPS, and
downloads are staged before installation. The helper rechecks the staged file
after app shutdown. Download/verification failure never launches an installer.

The portable executable remains a separate distribution option. Prefer the
Setup EXE for future updates after creating an installed copy.

## Verification

`flutter test --no-pub test/update_controller_test.dart` covers version ordering,
offline import, verification gates, connection gates, and saved preferences.
`cargo test --locked --lib` in `native/windows` tests signature validation.
`tool/test_update_package.ps1` checks the built installer and rejects unsigned
and modified copies without executing any installer.
`tool/test_installer.ps1` uses a temporary directory and a test-only installer
without Start Menu/Desktop shortcuts or an Installed Apps registration.
It checks fresh install, upgrade, data retention, and silent uninstall.

Neither release creation nor these checks publishes anything to GitHub.
