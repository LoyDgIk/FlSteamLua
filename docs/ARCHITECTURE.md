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

Each sidebar destination has its own Navigator, retained in a PageView with
FlClash's AutomaticKeepAliveClientMixin-based KeepScope. Hidden pages keep their
state without participating in sidebar-width layout. Their MediaQuery size stays
at the last visible size until reactivated; TickerMode and ExcludeFocus stop their
animations and focus participation. Secondary pages stay inside that navigation
stack, leaving the global task entry available.

App themes are cached by appearance inputs, matching FlClash's theme manager.
Saving unrelated settings such as sidebar expansion does not recreate ThemeData
or trigger ThemeCrossFade's full-window snapshot. MaterialApp theme interpolation
is disabled because ThemeCrossFade already owns the theme transition. Sidebar
avatar lookup is prepared outside animation frame builders.

On first entry, `quickStartDismissed=false` routes to `QuickStartWindow` before
the application shell. Its nested navigator holds the guide and existing setup
pages beneath one desktop caption. Skip or finish persists the flag and mounts
the shell; closing without either action leaves the guide pending. Settings can
open `QuickStartPage` later without replacing the shell or its navigation state.
Language and appearance choices use the same settings keys as normal settings.

## Game identity

`GameEntry.appId` is the catalogue key. Steam installation and Lua records merge
into one entry, but `ownership`, `isInstalled` and `hasLua` remain independent.
The catalogue does not infer ownership from files or a successful import.
Selection and pending edits belong to page/controller state, not GameEntry.

Playtime and last-played timestamps come from the selected Steam account's
`userdata/<accountId>/config/localconfig.vdf`. Account selection follows
`loginusers.vdf`'s MostRecent, AutoLogin and login timestamp. Missing values remain
unknown. The application does not accumulate session time, write last-played
timestamps, or merge its former local counters into Steam history. Process
observation updates running state only. A library refresh rereads Steam history;
the detail and library views share its minutes/hours formatter.

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

Lua directories have one source of truth: `[lua].paths` in the Steam root's
`opensteamtool.toml`. Settings owns their ordered editor; element zero is the
default destination for new imports and LAN receives. The fixed directory is
shown above custom paths and used when the custom list is empty. Existing Lua files keep
their paths when edited. `LuaDirectories` also includes the core's permanent
`config/lua` load directory, and scans direct files plus the client's `Disable`
folder rather than treating arbitrary nested folders as core-loaded scripts.
Saving or reordering paths does not move existing files. No legacy single-path
application setting overrides the core configuration.

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

Manifest monitoring and the core's loopback Lua bridge use the same request-code
resolver. Code-capable JS sources receive the requested AppID, DepotID and exact
decimal GID. Custom HTTP and script proxy modes require the application to remain
running; the core can fall back to its built-in providers when the bridge fails.
The metadata channel editor writes the core's `[remote].url_template` as well as
the client download preferences. `KernelConfig` edits individual TOML expressions
using a parser, retaining other keys, comments and line endings.

Cloud save rows distinguish the folder-provider repository, the native cache at
`Steam/cloud_redirect/storage`, and remote repository objects. Row backups and
deletions carry account and location scope. Direct exports preserve CloudRedirect
objects; native cache files are not directly uploaded as a remote repository.
The plugin inside Steam owns automatic game synchronization. Explicit single-game pulls invoke its exported CLI in `cloud_sync_worker.exe`; Flutter never loads the hook DLL into its own process. Plugin install/update and
configuration enable/disable are separate actions; configuration state is never
presented as proof of a successful native load or synchronization. Achievement
and playtime sync are separately configured and ordinary storage changes preserve
their existing values.

Cloud storage profiles have stable IDs and independent DPAPI credential files in
`%APPDATA%/CloudRedirect/profiles`. The active native target and the target being
browsed are separate. Activation writes native `provider`, `token_path`,
`token_paths` and (for folder storage) `sync_path`; an existing native configuration
is retained as a profile when the user switches away from it. Configuration
snapshots precede activation. OAuth authorization and read/write probes operate
on form drafts, and saving a new profile does not activate it.

The browser groups by account and AppID. Initial refresh lists only account/game
directories; recursive file inventory is loaded in a detail sheet. Status reads
do not replace save lists, and failed remote refreshes preserve the last results.
The page uses configuration/restart/core-file states without claiming a verified
runtime hook. Repository manifest comparison is distinct from sync confirmation.

Backup manifests bind remote/folder operations to a profile, provider and target
fingerprint, record account/location scope and SHA-256 file checksums, and retain
notes, pinned state, reason and verification time. Restore validates the entire
backup before writing, snapshots existing destinations, stages local directories,
and rolls back partially applied targets on failure. Remote rollback can itself
fail when the provider is unavailable; the complete local snapshot remains for
recovery. S3 deletion enumerates keys rather than treating DELETE as a prefix
operation. Retention is an explicit, previewed per-game count/size cleanup that
excludes pinned backups. Successful local restores remove transient adjacent
rollback directories; pre-restore copies remain in managed backup history.

The native pull worker rejects a running Steam process. The client snapshots the
local game cache, requires the CLI's success/drained receipt, checks persisted
change numbers and verifies downloaded files against remote manifest SHA-1/size.
A failed or cancelled pull restores the cache snapshot. This confirms core/cache
synchronization, not game-level save loading. The CLI uses the Windows roaming
configuration path, so pulls are restricted to the active native storage profile.

UI strings live in ARB resources and use generated `AppLocalizations` members.
The generated supported locale list drives the application and language picker.

## Ticket credentials

Ticket application preserves the cached SteamID by default. The confirmation
side sheet shows the active Steam account, ticket owner, and cached authorization
identity separately. A mismatch between the last two produces a persistent
warning; a different active account never blocks import. Only the explicit
identity switch writes SteamID. Feedback confirms a verified credential write,
not game authorization.

Every application stores the previous AppTicket, ETicket, SteamID and their
absence states in a DPAPI-encrypted snapshot under `backups/tickets`. Lua files
containing matching stand-alone `setAppTicket`/`setETicket` statements are included
in that encrypted snapshot before those statements are removed. The preview
shows function names and line numbers without exposing ticket payloads. When Lua
cleanup is necessary and Steam is running, the same confirmation authorizes
closing Steam before cleanup and credential writes, preventing hot reload from
reinstating old tickets. Comments, strings, unrelated games, BOM and line endings
are preserved.

A failed write restores all values and Lua files changed by that transaction.
The restore action applies both tickets and SteamID together, including deletion
of originally absent values, and restores associated Lua only when its contents
still match the recorded before/after snapshot. Restoring creates a new encrypted
snapshot of the current set so it is reversible too.

## LAN transfer

`lan_transfer_engine.exe` owns discovery, trusted-device identity, manifest
parsing, chunk bitmaps, transfer scheduling and installation. Flutter keeps only
the existing session/peer presentation models and launches the engine over
inherited stdio. Official chunks use depot-manifest SHA-1 and are written
directly into same-volume staging files; existing installed chunks seed the
missing-block bitmap for delta transfers. No Steam process or Steam LAN protocol
is used.


## Steam client versions

`SteamVersionService` owns the version catalogue, package inventory, resumable
HTTP downloads and installation snapshots. Its tool page follows the existing
resource-browser pattern, with architecture filtering, searchable build IDs,
version details, history/settings forms and a single install confirmation.
Steam update controls remain exclusively in the existing settings page. Version
installation and restoration preserve Steam.cfg and never change those settings.

Official manifests come from `https://media.steampowered.com/client`. The parser
retains both parent packages and nested conditional branches, prefers the `.vz`
variant, and includes the verified bootstrap ZIP for executable extraction.
Package paths, length, SHA-256 and PE architecture are checked at input boundaries.
The tool does not distribute SteamVault's executable or bundled Steam binaries.

Wayback defaults to `https://web.archive.org`. The user can set a custom HTTPS
base for CDX history, manifest replay and historical package replay. There is
one configured archive endpoint; an archive error is surfaced without changing
hosts. Package downloads try Valve's CDN and then the configured archive for
historical objects no longer on the CDN.

`assets/steam_versions/catalog.json` seeds 59 known historical choices offline.
`data/steam-client-versions.json` merges seed metadata, parsed manifests, newly
discovered archive snapshots and snapshot-to-build mappings. Refresh version
library fetches the latest official manifests and both architectures' CDX indexes;
it never requires a new application release to discover new client versions.
Index entries without build metadata are labelled as dated snapshots until a
selected manifest supplies the real build number. Duplicate snapshots collapse
by architecture/build after resolution, and those mappings persist across runs.

`cache/steam-client-history/index` caches architecture/date query results for
24 hours; the primary refresh reuses this cache. The history form offers a force
index refresh. Opening a historical detail resolves only that selected manifest,
and successful manifest results are cached indefinitely. gzip archive payloads
are decoded before KeyValues validation. No startup network scan is needed to
show historical choices. The page uses one CustomScrollView; its empty/search
state fills the remaining sliver area with NullStatus.scrollable disabled.

Downloads retain partial files and validate resumed Content-Range responses.
Installation verifies every package, extracts steam.exe from its matching ZIP,
and runs Steam's updater against a loopback allowlist server in a temporary
client directory. The server aliases win32/win64 manifest requests for old-client
installation. The selected manifest plus the actual `.installed` file index,
indexed file sizes and bootstrap exit are checked before promotion. `.installed`
is a line-based file inventory, not KeyValues; it identifies which manifest is
active when multiple architectures remain in the package folder.

Only staged client files and obsolete paths named by the old installed inventory
are changed. Games, userdata, config/Lua, ssfn files, registry.vdf and known core/
cloud plugin paths are excluded. Before promotion, the snapshot stores old bytes,
checksums and absent-file states. Failed promotion rolls back the whole set;
manual restore first snapshots the current state. A stopped-Steam check is
repeated after staging and after backup. Native bootstrap execution and actual
upgrade/downgrade behavior are not established by the injected fixture tests.
