# Windows service development

[← Installation and updates](updates.md)

## Current behavior: checkpoint 3

Windows development and release builds use the same installed service for the main sing-box/Xray connection.
The existing Connect interface remains elevated until update storage and
startup operations finish moving behind the service. Windows proxy-based
server checks now use separate service-owned core sessions. ICMP/TCP probes
remain in the ordinary client helper.
Windows Settings includes a Startup card with Start with Windows and Start
minimized. Both default to off. They do not start a VPN connection.

## Removing interface elevation: authorization checkpoint

The interface remains elevated. Service enrollment records the intended
Windows sign-in account in `settings/service-access.json`, using the session
identity reported by Windows rather than a SID supplied by the client. An
existing owner is retained on repair and upgrade. First enrollment requires
an interactive Windows session; existing enrollment can be retained by a
non-interactive administrator update.

During first enrollment, a handle to the administrator-owned settings directory
prevents directory replacement while stale ordinary-account grants are replaced
with SYSTEM/Administrators access. Preference contents are preserved. Existing
authorization records with unsafe permissions, links, malformed data or an
unsupported version are rejected. They are never silently rebound to a new user.

Each pipe request is identified through its Windows token. The service reads
the user SID, session, enabled administrator membership, elevation, integrity,
restricted-token and AppContainer status. It restores its own thread identity
before dispatch; failure to restore terminates the process. Restricted,
AppContainer, low-integrity and non-interactive ordinary callers are denied.

The enrolled ordinary account can request `health`, `access`, `settings.read`
and `settings.write`, plus the restricted `connection.*` and `checks.*` commands described below.
Raw core configuration commands remain privileged. The `access`
handshake reports `owner`, `privileged`, `settings` and `runtime`; settings are
enabled for the enrolled account and SYSTEM. Runtime now reports access to
the typed connection API, not arbitrary runtime files.
Other elevated administrators retain core maintenance access but cannot use
the settings API on behalf of another enrolled account.

The ordinary account receives pipe data access, attributes and access-list read
permission, without permission to create pipe instances or change ownership or
permissions. Clients verify the service executable when process-query access
is available. For the fixed installed endpoint when Windows denies that query,
clients require a kernel-reported system-session pipe owned by SYSTEM, with an
access list allowing ordinary accounts only the bounded client rights. This
does not change the service process permissions. An ordinary process cannot
create a pipe owned by SYSTEM.

Remaining work before switching the manifest to ordinary-user execution:
update-cache access, ordinary-user service startup, followed
by startup-task migration and
an unelevated end-to-end test. Never expose the existing privileged raw-core
configuration interface to ordinary clients as a shortcut.

## Removing interface elevation: settings checkpoint

Windows application preferences, language and update preferences use shared
storage interfaces backed by the installed service. Android and Linux keep
their file stores. Explicit test directories use isolated file stores.
Development and release read the same installed settings; there is no fallback
to a second Windows settings folder when service access fails.

`settings.read` and `settings.write` accept only the document enum `app`,
`language` or `updates`, mapped to three fixed filenames in `settings`.
Requests cannot specify a path, executable, account or authorization policy.
Writes validate known fields, enums, collection sizes, string lengths and
depth. Each document is limited to 256 KiB. Writes preserve existing unknown
metadata, including matching subscription/routing-rule metadata, while
honoring explicit removals.

Reads return a SHA-256 revision of the original bytes, or `missing`. A save
must supply that revision; stale saves fail rather than overwrite a newer
session. The client requires a successful typed read before saving and
invalidates its revision after a storage error. It does not reset malformed
files or automatically retry stale data. Language restoration failures leave
the interface available with a retry control.

The service checks the protected installation/settings directories and holds
the settings directory open against replacement. It reads through a bounded
handle without following links and rejects directories, reparse points and
multiply linked files. Only after validation and revision comparison does it
close its read handle, flush a randomly named private temporary file and
replace the fixed settings filename. Requests are dispatched serially. A
failed replacement retains the existing document and cleans the temporary
file. Temporary and newly saved files allow SYSTEM/Administrators only.

Legacy roaming application preferences are imported only if installed app
preferences are missing. The client reads its own legacy file and submits
the typed document using the `missing` revision, preserving the original
legacy file as a recovery copy. The service never accepts arbitrary profile
paths to perform this import.

A running service can be used without requesting SCM start rights. Starting
a stopped service still requires elevation at this checkpoint. The UI manifest
remains elevated; update-cache operations and startup tasks have not yet been
migrated.

## Removing interface elevation: connection runtime checkpoint

The Windows connection controller no longer creates a profile directory or
writes a core configuration when selecting a server. It sends a `ConnectionPlan`
through the shared `PlannedTunnelEngine` interface. Android and file-based
engines retain their existing configuration path. Subscription fetching,
parsing and endpoint resolution stay in the client.

`connection.validate` and `connection.start` accept only a plan containing a
core enum, mode, DNS provider, leak-protection boolean, routing policy and
restricted outbound protocol parameters. The service builds the complete
configuration from fixed templates. The outbound schema rejects unknown
fields at every level, requires a resolved IP/valid port and permits only the
client's supported protocols/transports. Transport URL paths remain network
parameters; local certificate paths, executable hooks, plugins, custom
listeners, log destinations and raw core configurations cannot be supplied.
Routing rules have bounded counts/lengths and validated domains, IP/CIDR and
process match strings. Process paths are match values and are never executed.
Plans are capped at 256 KiB and generated configurations at 1 MiB.

The enrolled eligible account and SYSTEM can also request `connection.status`,
`connection.recover`, `connection.confirm` and `connection.stop`. These use the
existing bounded worker, validation, session checks, verification lease and
job-based core cleanup. Unknown accounts, restricted/low-integrity callers and
ordinary raw-core commands remain denied. Session confirmation still follows
the client's connection verification; core readiness alone is not Connected.

Generated files live under randomly named `runtime/service-<32 hex digits>`
directories. Both directory and file have explicit SYSTEM ownership and a
protected SYSTEM/Administrators-only access list. The service checks protected
paths and guards the runtime directory against replacement while creating
files. It writes and flushes the configuration before passing its fixed filename
to the fixed installed core. Validation deletes its configuration on completion;
a running connection retains its own configuration until stop/failure. On
service restart, only this exact generated-name pattern is swept, with owner,
permissions, link and hard-link checks and non-recursive deletion. Unexpected
contents or unsafe paths cause startup to fail closed instead of being followed
or recursively removed.

The administrative reference-based API remains available for old elevated
interfaces and isolated maintenance tests. It is separate from the ordinary
connection API and keeps its existing path/configuration checks. Do not grant
ordinary callers access to it.

Installation/repair tightens an existing administrator-owned runtime directory
through a held no-delete-sharing handle, removing stale ordinary-account
grants while preserving existing file contents. Links and untrusted owners
are refused. This migration is needed for older installations whose runtime
directory explicitly allowed the signed-in account to write there.

`tool/generate_connection_plan_fixture.dart` generates 720 dummy cases using
the existing Dart configuration builders. Set `AORA_TEST_PLAN_PARITY` to the
generated `.buildlog/connection-plan-fixtures.json` when running native service
tests to compare service output with those complete configurations. This covers
both cores, supported transports, modes, DNS providers, leak settings and routing.
The SCM fixture additionally tests typed validation/start, actual local proxy
traffic with each core, SYSTEM-only runtime permissions, stop cleanup and
crash-orphan cleanup. It never starts a real TUN connection.

With the installed service running and the app closed, set
`AORA_TEST_CONNECTION_PLANS=1` and run
`flutter test test/windows_service_integration_test.dart` without elevation to
validate 84 dummy configurations through the installed service and both cores.
No client configuration files are written and no VPN is started.

## Removing interface elevation: server-check checkpoint

The default Windows `NodePingService` opens a service batch instead of writing
check configurations or launching cores in the client. Its public scan/batch
interface is unchanged. Android keeps its native batch implementation, and
explicit test engine/session factories retain isolated local test execution.
A service failure is reported; it never silently falls back to local core
execution. Ordinary ICMP/TCP checks stay in the existing client helper.

`checks.open` accepts a random 128-bit client session ID and up to 1024 indexed
nodes, each with a fixed core enum and restricted outbound parameters. Input
uses the 512 KiB frame limit. The service rejects duplicate/out-of-range indices,
unknown request fields, paths and raw configurations. Outbounds use the same
closed protocol schema as connection plans. Caller-supplied source/interface
bindings are rejected; the service chooses physical sources through Windows
network APIs, independently of TUN routes. It assigns outbound tags, reserves
ephemeral loopback ports and builds fixed proxy-only configurations. TUN,
custom listeners, file hooks and update/install operations are not part of
this API. Responses contain only indices, loopback ports and bounded generic
errors, without raw core logs or configuration credentials.

One batch runs at a time, sharing at most one core per kind. Its dedicated
worker does not occupy the main VPN worker. Structurally invalid profiles are
isolated individually; core validation splits rejected groups to keep accepted
profiles usable. Validation is bounded by time and attempt count. Core startup
checks readiness and loopback listeners. The client retains the scan UI,
32-request concurrency limit and GET/HEAD latency requests. It does not ask
the privileged service to fetch arbitrary test URLs.

`checks.status` renews a 30-second lease; the client polls during preparation
and sends a heartbeat every five seconds once ready. Batches also have a
ten-minute absolute lifetime. `checks.close` cancels only its exact session;
stale closes are harmless, duplicate opens with identical bytes are idempotent,
and a closed session cannot restart through replay. Client requests are
serialized so cancellation during open still closes that same session. Disposal
stops heartbeats and sends a close. If communication fails, the service lease
still bounds abandoned work. A stopped/crashed core invalidates the batch.

Check cores have their own kill-on-close jobs and private SYSTEM-owned runtime
configurations, using the existing runtime cleanup rules. Cancellation, expiry
and service shutdown remove the check cores and their files without stopping
the main VPN session. A service crash kills all its core jobs; restart sweeps
the private orphaned configurations. The SCM fixture uses a three-second lease
to test abandonment without lengthy sleeps.

The isolated SCM test verifies a 72-node mixed-core batch with two bad profiles,
real local HTTP proxy traffic, exactly two shared check cores beside an active
main proxy connection, stale close, idempotent open, cancellation during
preparation, lease expiry and service crash/restart cleanup. Its direct outbound
is a compile-time fixture exception and is absent from production builds.

Set `AORA_TEST_SERVICE_CHECKS=1` and run
`flutter test test/windows_service_integration_test.dart` from the ordinary
enrolled account with the service running. This prepares 70 dummy loopback
profiles across both cores, verifies their listeners and cleanup, rejects the
fixture-only direct outbounds, and confirms main-connection tickets do not
change. It neither starts a VPN nor accesses saved providers. Real scans through
TUN/physical networks remain part of the disposable Windows/VM release checks.

## Startup settings

Start with Windows registers one Task Scheduler logon task for the current
Windows user. It uses the installed `app/aoravpn.exe`, an interactive user token
and the elevated privileges still required by the interface. It does not run
the interface as SYSTEM, store an account password or execute a project/build
path. Start minimized opens the interface in its tray at launch, with a visible
window fallback if tray registration fails. `--show` overrides that preference
for a single launch.

The minimized preference is stored in `settings/startup-<Windows SID>.json`;
startup registration is read from Task Scheduler. Development and release use
the same preference and task. Native changes are serialized, refuse foreign
task actions/owners and attempt task rollback if saving preferences fails.
Uninstall removes verified AORA startup tasks before removing the service.
An upgraded installer is required to put these controls and the new tray startup
behavior into an older installed interface; development builds do not replace
the installed interface executable.

The scheduled-task test is opt-in: set `AORA_TEST_STARTUP_SCHEDULER=1` and run
`cargo test --locked --manifest-path native/windows/Cargo.toml --lib startup::`
from an elevated terminal. It creates a unique disabled task, checks account
normalization and action validation, and deletes it without running the app.

## Shared development installation

Both builds use `Program Files\AORAConnect\settings`, the installed cores and
the same `AORAConnectService`. Debug/profile storage is resolved through the
Windows Program Files known-folder API, independently of the source directory
or environment-variable overrides. The development interface stays in the
project build directory for Flutter debugging and hot reload; its main VPN
requests run through `app/aoravpn_service.exe` in the installed application.
There is no second development service or settings copy. Changes made in
development affect the same preferences, subscriptions and routing rules.

Install the application once before developing. A normal Windows debug/profile
build runs `tool/prepare_windows_service.ps1` after compiling the helpers.
Unchanged helpers need no administrator preparation. Changed helpers request
elevation, reserve the app's existing single-instance locks, verify hashes,
check installed-path permissions and refuse an active connection. The worker
stops the existing service before replacing the three service/core-host helpers,
then registers/starts and checks that same service. Failed replacement attempts
restore the previous helper bytes and previous running/stopped state. The
worker never copies, imports, deletes or rewrites user settings. Do not run an
installer concurrently with a development build.

Close the installed interface, including its tray icon, before the first build
or a native helper change. Subsequent Flutter hot reload/restart uses the
existing service without redeploying it. The public updater is not created in
Windows debug/profile interfaces. Release packaging skips development
preparation and continues to use the installer's service hooks.

The service owns core validation, execution, graceful shutdown, bounded logs,
the active configuration copy and cleanup of legacy Windows firewall rules.
The existing leak protection is unchanged: sing-box strict routing and Xray's
core-managed WFP protection. Persistent firewall arming remains disabled.

An old elevated UI can request a fixed core enum and a reference such as
`profile-abc/config.json` inside the protected runtime directory. It cannot
supply an executable or arbitrary configuration path. Links, external file
references/hooks, unsupported top-level sections and non-loopback proxy
listeners are rejected. Input configurations are capped at 4 MiB, copied from
locked validated source bytes and retained independently of the UI's source
file. This administrative API is not suitable for ordinary-user access yet;
do not relax its ACL before moving configuration construction/authorization
behind the service boundary.

Operations are serialized by a bounded worker queue. Status requests remain
responsive during validation/start/stop. Connections have unique session IDs;
stale confirmation/stop requests cannot affect a newer connection. A ready core
stays in `starting` until the UI's existing HTTPS check succeeds and acknowledges
that exact session. An unverified connection expires after 150 seconds. The SCM
fixture shortens that lease to 10 seconds for testing.

Verified connections survive UI-process loss and can be restored without
restarting a core. Reopening the UI cancels an abandoned unverified connection.
Explicit application exit still requests disconnection. Service errors are
shown as unconfirmed state unless SCM confirms that it stopped; an authoritative
stopped response clears the previous connected state. Manual connection or
profile validation can demand-start an installed stopped service. There is no
fallback that launches a replacement VPN core from the release UI.

Each validation/core host and its descendants are assigned to a kill-on-close
Windows job at process creation. Only the intended standard I/O handles are
inherited. Graceful stop is attempted first, with bounded process-tree cleanup.
Crashing the service therefore closes the job and removes its core process tree.

## Checkpoint 1: original idle service foundation

`app/aoravpn_service.exe` hosts `AORAConnectService` as a Windows service under
LocalSystem. The service is demand-start at this checkpoint: installation starts
it for a health check, but it does not automatically start after reboot. The
desktop client demand-starts it when opened. It does not write user settings.

All application files remain under `Program Files\AORAConnect`. Windows also
stores its normal service registration in the system registry. The installer
stops an existing service before replacing files, registers/starts the new
service and verifies its health/version. Uninstall removes the service before
deleting its executable. A service with an unexpected executable, account or
service type is rejected rather than reconfigured or removed. A failed new
service installation attempts to stop/remove its registration.

Service management commands run only from the fixed installed executable, with
directory/file links rejected:

| Command | Purpose |
| --- | --- |
| `install` | Register/repair a demand-start service, start it and verify health |
| `start` | Start an existing installation without reconfiguring its registration |
| `stop` | Wait for a registered service to stop before replacing files |
| `remove` | Stop and delete the service registration |
| `run` | Enter the Windows service dispatcher; not a standalone server |
| `probe` | Return versioned JSON health information |
| `request` | Exchange a bounded JSON control request through standard input |
| `installation-info` | Identify the helper's compiled installation, service and fixture status |
| `startup-status` | Read the current user's startup task and minimized preference |
| `startup-set` | Save typed startup preferences from standard input |
| `startup-remove` | Remove verified AORA startup tasks during uninstall |

The versioned local named-pipe protocol accepts `health`, `access`, `settings.read`,
`settings.write`, the typed `connection.*` and `checks.*` commands, `status`, `recover`,
`validate`, `start`, `confirm` and `stop`.
Requests have a little-endian 32-bit byte length followed by UTF-8 JSON. Each
frame is limited to 512 KiB. The CLI and service retain a 4 KiB limit for core
control requests; settings messages and check-batch opens use the frame limit,
and typed connection plans have a 256 KiB limit. Log pages have
an additional serialized byte budget. Unknown commands/fields, malformed requests and
unsupported protocol versions are rejected. The client acknowledges receipt
before disconnection. Each exchange has a two-second deadline, and service stop
cancels pending connection/read/write operations.

The pipe rejects remote clients. Its protected access list permits SYSTEM,
elevated administrators and the enrolled account with bounded client rights.
Command authorization is checked separately as described above. The client
requests identification level; the service uses that token only to establish
the caller's identity and restores its own identity before handling commands.
The first pipe instance is reserved for the lifetime of the service.

## Verification

Run `tool/test_windows_service.ps1` for native protocol/security tests and a
cross-process smoke test. Its `service-fixture` Cargo feature has a compile-time
unique pipe name, explicitly grants the test user's identity access and exposes
no service registration/dispatcher commands. It does not register a Windows
service or change application settings, networking or the installed client.
This feature is excluded from normal builds.

Automated checks cover health/version/server identity, protocol rejection,
anonymous-client denial under the production access list, duplicate endpoints,
oversized frames, stalled clients, shutdown cancellation and fixture isolation.
`tool/test_installer.ps1` verifies existing isolated migration/upgrade/uninstall
behavior; its `TestInstall` define skips actual service registration.

With the installed app closed and the service already running, an elevated
terminal can run the additional local integration checks:

```powershell
$env:AORA_TEST_INSTALLED_SERVICE = '1'
flutter test test/windows_service_integration_test.dart
Remove-Item Env:AORA_TEST_INSTALLED_SERVICE
```

These checks validate complete client-generated configurations through the
installed service and both real cores, including VPN/proxy modes, each DNS
provider and routing. They never start a VPN. The preferences check reads the
installed settings and language, injects a dummy loopback server instead of
contacting a subscription provider, and disables persistence. It verifies the
settings file is unchanged. Set `AORA_TEST_SERVICE_SETTINGS=1` to run only
the ordinary enrolled-account settings check, without elevation. It reads all
three documents through the real Dart stores, verifies unchanged revisions
and confirms that privileged core status is still denied. It neither saves
preferences nor contacts providers. Ordinary test runs skip these opt-in checks.

Encrypted DNS request paths are accepted only in sing-box HTTPS DNS server
entries. They remain distinct from local file paths; certificate files, log
files and executable hooks stay rejected.

## Checkpoint 2: actual Windows service lifecycle

`tool/test_windows_service_scm.ps1` builds two different versions of a uniquely
named SCM fixture and requests Windows administrator approval. It uses the same
service dispatcher, lifecycle manager and production pipe permissions. Only its
compile-time service/pipe name, protected installation root and version differ.
The `service-scm-fixture` feature cannot be combined with the other fixtures,
portable launcher or Flutter runner, and is excluded from normal builds.

The administrator worker verifies hashes of the already-built helper bytes,
then creates a new `Program Files\AORAConnect-ServiceTest-<id>` directory with
Administrators ownership, SYSTEM/Administrators full control and Users read and
execute access. It refuses existing test roots/registrations. The worker itself
is checked against a captured SHA-256 before execution. It sends its report
through a local pipe; it does not write elevated output into the user-writable
workspace. The unelevated driver saves `report.json` in its build fixture.

The real SCM test passed on 2026-10-31:

- LocalSystem registration and startup, with demand-start configuration.
- Typed settings saves/reads, documents larger than 32 KiB, stale revision
  rejection and preservation of unknown metadata. Locked files retain their
  previous bytes and temporary files are removed. Corrupt files, hard links
  and arbitrary paths are rejected.
- Typed plans run through both real cores with local proxy traffic and no
  client-created configuration files. Runtime directory/file permissions are
  SYSTEM/Administrators-only; stop and crash/restart clean generated files.
- Idempotent repair without an additional service process.
- Stop with a stalled pipe client, process exit and repeated stop.
- Rejection of an unexpected executable, account and service type, without
  changing or deleting those unexpected registrations.
- Replacement of the stopped executable and startup of a different version.
- Removal, repeated removal, missing endpoint and complete test-root cleanup.
- Both bundled real cores validate configurations and relay local HTTP proxy
  traffic while running under LocalSystem. Invalid configurations are rejected.
- Cancellation, stale-session rejection, readiness/verification acknowledgement,
  source-file removal while connected and graceful core stop.
- Killing only the test service removes each core process tree and proxy
  listener; the restarted service reports stopped instead of a stale connection.
- An acknowledgement lease expires and stops an unverified connection.

The SCM fixture refuses TUN configurations and skips the real legacy firewall
namespace. Its traffic is loopback only; it does not verify remote VPN servers,
external IP changes, DNS/leak behavior or TUN route restoration.

The stop command now holds a handle to an active service process and waits for
its exit as well as the SCM stopped status before returning. It does not trust
process IDs from start-pending, stop-pending or stopped SCM statuses.

Use `-PrepareOnly` to build without requesting administrator access, or
`-PreparedFixture <build fixture directory>` to run already-prepared binaries.
This test never changes the real `AORAConnectService`, installed application,
VPN settings, routing or network adapters.

**Remaining before release:** test real TUN connections, external IP, DNS/leak
protection, crash recovery and routing with both cores on a disposable Windows
installation/VM. Also exercise the complete production installer's
service hooks together with legacy migration on a disposable Windows
installation or VM. The actual SCM test covers the service manager lifecycle;
the existing installer fixtures skip service registration. Existing release
packages are not rebuilt or published by these checkpoints.

## Next checkpoints

1. Complete the real TUN and installer verification described above.
2. Move the remaining update runtime operations into the service using the
   enrolled-user authorization before removing UI elevation. Do not grant
   ordinary processes write access to executable/core folders or allow arbitrary
   executable paths, file paths or raw privileged core configurations over IPC.
3. Verify actual sign-in and minimized launch using the updated installed interface.
4. Add opt-in automatic connection after sign-in, with network readiness and
   bounded retries. Connection before sign-in is a separate future feature.

Keep legacy installation migration in future installers so users can skip this
and other intermediate releases.
