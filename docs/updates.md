# Installation and updates

[← Back to AORA Connect](../README.md)

## Release files at a glance

Build both platforms from the same version in `pubspec.yaml`, then attach these
four files to the matching GitHub release:

| Platform | Application package | Signed update metadata | Output folder |
| --- | --- | --- | --- |
| Windows x64 | `AORAConnect-Setup.exe` | `aora-update.json` | `build/installer/` |
| Android ARM64 | `AORAConnect.apk` | `aora-update-android.json` | `build/android-release/` |

For example, `1.1.6+10` uses release tag `v1.1.6` and internal build counter `10`.
Increase both the public version and build counter for each new release. Rebuild
both packages after changing the version; never edit signed metadata by hand.
Portable executables are not part of the current release workflow.

## Update sources

The default update source is the `khitori/AORA-Connect` GitHub repository.
Users may add optional HTTPS metadata mirrors in **Settings → Updates**.
No mirror is required or configured by default.

## User workflows

Windows service work is staged separately; see
[Windows service development](windows-service.md) for its current checkpoint and
verification limits. Windows release builds now use the service for VPN core
control; startup controls and removal of UI elevation are later checkpoints.

- Download `AORAConnect-Setup.exe` and run it to install or upgrade. Close the
  existing app first, including its tray instance. The installer waits for the
  app/portable launcher to close and does not forcibly terminate the VPN core.
- The installer registers AORA Connect in Windows Installed Apps and creates
  a Start Menu shortcut; a desktop shortcut is optional.
- Windows installs under `%ProgramFiles%\AORAConnect` and requires administrator
  approval. Application files, both cores, settings and runtime files share this
  protected root. The uninstall files are under
  `uninstall/` in the same root.
- The existing in-app updater can migrate a LocalAppData installation. The
  installer copies `app-state.json`, `language.json` and `updates.json` and places
  a temporary launcher at the restart path expected by the old updater. That
  launcher starts a worker from Program Files. The worker waits for the old
  updater to release its files, starts the new client, and waits for its first
  rendered frame before removing the legacy application and verified settings
  copies. A failed startup restores the previous executable and retains its data.
  Conflicting settings and unrelated files stay in the old directory for recovery;
  directory links are not followed. Subsequent updates use the new root directly
  and do not recreate a legacy launcher.
- The compatibility payload remains bundled as `app/aoravpn_migrate.exe` for
  users skipping releases. Its fixture-only Cargo feature is excluded from release
  builds. `tool/test_legacy_migration.ps1` tests the actual 1.1.9 updater against
  isolated signed packages, including restart, cleanup, a subsequent update and
  failed-startup rollback (`-FailStartup`).
- Settings and runtime folders are restricted to Administrators and SYSTEM while
  the Windows client requires elevation. The installation root is not made writable
  to ordinary processes. Uninstall keeps user data unless deletion is selected.
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
`-SkipBuild` reuses the most recent complete installer staging bundle in
`build/installer/`. The installer build does not generate a portable executable. Rebuild
after changing source or the version; the script verifies the finished package.

4. Create a GitHub release with tag **`v<major.minor.patch>`**, for example
   `v1.1.6`, and attach both files from `build/installer/`:

   - `AORAConnect-Setup.exe`
   - `aora-update.json`

The build script generates and signs the JSON automatically, including the
version, installer URL, SHA-256, byte length, and release notes. No JSON editing
is needed. The public version is `1.1.6`; `+10` in `pubspec.yaml` is an internal
build number used for update ordering. The installer and app display the public
version, while Windows file-version resources retain a numeric build component.
GitHub's `releases/latest/download/aora-update.json` endpoint serves
the stable channel; prereleases are not part of that endpoint. Do not publish
unfinished builds to the stable channel.

Mirrors can host copies of these same two files. Metadata and payload must not
be modified; any invalid signature or altered installer is rejected. Metadata
is limited to 64 KiB, installer payloads to 512 MiB, redirects to HTTPS, and
downloads are staged before installation. The helper rechecks the staged file
after app shutdown. Download/verification failure never launches an installer.

Use the Setup EXE for the Windows release workflow. Older portable installations
can migrate through the installer while retaining the existing storage root.

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

## Android signing and updates

Android release APKs use their own RSA signing keystore. The shared Ed25519
release key signs download metadata; it is not a replacement for the APK's
Android signature. Both private keys must be retained for future releases.

### Portable private files and Google Drive backups

The Android signing folder on this checkout is `.release-keys/android/`:

- `release.jks`: private Android signing keystore.
- `signing.properties`: alias/passwords and `storeFile=release.jks`, relative
  to this file, not an absolute PC-specific keystore path.

These files are ignored by Git. Back up **both together**, preferably in an
encrypted archive before storing it in a private Google Drive folder. Keep the
archive password separately. This task never uploads private keys or credentials.
Also retain the existing Windows/metadata key at
`%USERPROFILE%/.aora-connect/release-private.json`; do not regenerate it.

On another PC, restore the files anywhere and pass their paths to the build:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_android_release.ps1 -SigningProperties "D:/Private/AORA/android/signing.properties" -UpdateSigningKey "D:/Private/AORA/release-private.json" -ReleaseNotes "Describe changes here"
```

Without overrides, the build uses `.release-keys/android/signing.properties`
and the existing metadata key in the user profile. Direct Flutter/Gradle
release builds accept `AORA_ANDROID_SIGNING_PROPERTIES` as the properties-file
path. Public certificates/keys may be published; private keys and passwords
must not be committed or attached to a release.

For a new application/channel only, create the Android folder once with
`dart run tool/create_android_signing.dart`. The tool refuses to overwrite
existing signing files. Restoring the same folder preserves the signing identity.

### Build and publish Android

1. Increase the version in `pubspec.yaml`. **The number after `+` must increase
   for every Android release, including changes to the public version name.**
   For example, `1.0.5+1` → `1.0.6+2`. Android orders upgrades by that build number.
2. Build with `tool/build_android_release.ps1` as shown above. It signs the APK,
   verifies its signature/application/version, then generates signed metadata.
3. Attach both files from `build/android-release/` to the GitHub release:
   `AORAConnect.apk` and `aora-update-android.json`. Windows assets may share
   the same release. Do not replace Windows `aora-update.json` with Android metadata.

No JSON editing is needed. The metadata generator leaves APK bytes unchanged:
appending the Windows update footer would invalidate an APK signature.

### Android user workflow and verification

Settings → Updates supports automatic startup checks, user-approved downloads,
optional HTTPS mirrors and offline **Update from file** imports. GitHub is the
default, using `releases/latest/download/aora-update-android.json`. An APK
downloaded elsewhere can also be opened directly in Android's package installer.

Metadata is verified against the pinned Ed25519 public key before its URLs or
hash are trusted. APK imports/downloads undergo full APK signature verification,
must match the installed app's signer and application ID, and require a higher
Android build number. A downloaded APK must additionally match the selected
signed metadata's SHA-256, size and version. Limits are 64 KiB for metadata and
512 MiB for APKs. No unsigned fallback is provided.

Installation requires a disconnected VPN and idle server checks. A private
verified copy is shared read-only with Android's installer using a scoped
FileProvider. Android may ask the user to allow installations from AORA Connect;
the system installation confirmation is still required. Cancelling returns to
the app without deleting user settings. Nothing installs silently.

Development and release builds use different signing keys and application IDs.
Normal debug runs install **AORA Connect Dev** (`aora.aoranet.aoravpn.dev`)
alongside the release (`aora.aoranet.aoravpn`), with independent app data.
Production APK updates cannot replace the Dev app. Update verification tests
keep the isolated `.updatetest` identity. Existing release installations and
their data do not need to be removed for development runs. Subsequent
release-to-release upgrades with the same signing key preserve private app data.

The signature comparison intentionally rejects key rotation until an explicit
trusted migration is implemented. Publishing to Google Play with a different
Play signing key would require a separate distribution/update strategy.

Android verification: 111 automated Flutter tests pass. On the Android 13 phone,
the isolated release-signed test application accepted the correct APK and signed
metadata, rejected altered/wrong-app/wrong-key APKs, and retained its synthetic
saved data after an ADB-driven signed upgrade. The test package and USB mapping
were removed afterward; the normal development app was refreshed in place.
The unknown-source permission and installer confirmation/cancellation screens
still need a manual end-to-end UI check; the ADB upgrade does not exercise them.
