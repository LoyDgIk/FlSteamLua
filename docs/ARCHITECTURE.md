# Architecture

FlSteamLua targets Windows 10/11 x64. Flutter owns presentation; Dart owns
application services, filesystem changes, protocol handling and tasks. The
original WPF application is a separate source reference, not a runtime dependency.

## Application lifetime

`AppServices` constructs the shared services. Riverpod exposes that instance at
the root. `SettingsStore` serializes JSON writes, while `AppPaths` resolves the
application's new local data directory and per-category storage overrides.
Credentials and secret caches cross a Windows DPAPI boundary before being
persisted. See `DATA_MANAGEMENT.md`.

`TaskCenter` retains progress, cancellation requests, results and errors across
navigation. Shutdown requests cancellation before joining background work and
closing the native achievement worker. Preferences own timers and filesystem
watchers; they stop before service disposal.

Each of the five primary destinations has its own Navigator. Offstage pages
retain scroll/filter/detail state while TickerMode and ExcludeFocus stop their
animations and focus participation. Secondary pages stay inside that navigation
stack, leaving the global task entry available.

## Game identity

`GameEntry.appId` is the catalogue key. Steam installation and Lua records merge
into one entry, but `ownership`, `isInstalled` and `hasLua` remain independent.
The catalogue does not infer ownership from files or a successful import.
Selection and pending edits belong to page/controller state, not GameEntry.

Windows process observation matches complete executable paths discovered from
the installation or configured trainer bindings. `TrainerLifecycle` translates
observed game transitions into one trainer start/stop operation. Native process
stops verify the image path through the same process handle before termination.

## External boundaries

- Steam CM/authentication/PICS/depot protocols: Dart wire codecs and service APIs.
- Achievements and tickets: an isolated `steam_worker.exe` per AppID, named-pipe
  messages and the thin C ABI `steam_bridge.dll`.
- Manifest scripts: QuickJS isolate with Promise-based HTTP; network and file
  writes remain in the Dart host.
- Cloud storage: Dart provider implementations; Windows WinHTTP handles explicit
  NTLM/Negotiate credentials in an isolate. CloudRedirect remains a native DLL.
- LAN transfer: a standalone Go engine owns discovery, mutual TLS, manifest
  plans, chunk scheduling, resume state, staging and installation. Dart only
  invokes the engine through JSON-RPC and renders sessions. See
  `LAN_TRANSFER.md`.
- Mutating file operations: previews/backups and temporary paths protect imports,
  patches, kernel switches, cloud restores and save-directory changes.

The test suite injects HTTP clients, native adapters and temporary paths at these
boundaries. Native loopback/DPAPI tests exercise local Windows ABI behavior;
they do not stand in for real account or remote-provider acceptance tests.

## Content sources and import

`ContentSourceRegistry` exposes script and subscription implementations through
explicit Lua, manifest-ID and manifest-file capabilities. Each import plan
selects its own sources. Subscriptions have no global active state; cached
keys and app metadata are isolated by source ID.

`ContentResolver` prepares and validates source artifacts, merges manifest pins
and constructs final Lua without executing it. `ContentImportService` previews
targets, backs up and stages changes, commits the bundle, rolls back failures
and scans the library. Local drag-and-drop uses the same path with one
transaction per detected game. Manifest request monitoring remains an optional
log-based supplement rather than download-failure recovery.

UI strings live in ARB resources and use generated `AppLocalizations` members.
The generated supported locale list drives the application and language picker.

## LAN transfer

`lan_transfer_engine.exe` owns discovery, trusted-device identity, manifest
parsing, chunk bitmaps, transfer scheduling and installation. Flutter keeps only
the existing session/peer presentation models and launches the engine over
inherited stdio. Official chunks use depot-manifest SHA-1 and are written
directly into same-volume staging files; existing installed chunks seed the
missing-block bitmap for delta transfers. No Steam process or Steam LAN protocol
is used.
