# Core, Cloud Plugin, and Store Review

## OpenSteamTool core

The reviewed upstream is `huanyuejue/OpenSteamTool` at
`522b768fa0e93e5d21aeba1698b952702a308edb`.

Core responsibilities that should stay together:

- DLL package installation and one active injection entry (`dwmapi.dll` or `version.dll`).
- Lua loading and hot reload for app, depot, manifest, ticket, stat, and key configuration.
- Manifest code lookup with provider selection, failover, timeouts, and local pattern caches.
- Steam build compatibility through external pattern/TOML metadata.
- Ticket, DRM, family-sharing, stats, presence, online-fix, and optional game injection behavior.
- Hosting optional native plugins. CloudRedirect is loaded through `[cloud]` in `opensteamtool.toml`.

These are not all "settings". Package lifecycle, runtime entry, compatibility, and
maintenance should be separate groups even when they share one kernel service.

## CloudRedirect plugin

OpenSteamTool loads `cloud_redirect.dll` inside Steam and resolves the CloudRedirect
ABI directly. The host:

- Initializes the plugin with the Steam root.
- Registers the current Lua app set.
- Routes cloud RPC and account/stat/running notifications.
- Optionally installs vtable hooks.
- Shuts the plugin down with the core.

The plugin therefore has its own lifecycle:

- installed, enabled, updateable, and removable;
- configured DLL path in the core TOML;
- requires a restart of Steam after changes;
- should remain separate from save browsing, provider credentials, backups, and upload/download actions.

## HM-STEAM-TOOLS store

The inspected HM catalog contains 74,083 Steam entries and marks 6,177 as NSFW.
Its store combines a broad app index with explicit mature-content preferences and
local metadata. It does not rely on the default Steam search session alone.

The official Steam search endpoint still supports both requirements without
copying HM's private cache:

- Omitting the category filter returns the broad catalog (over 300,000 search rows).
- Mature-content cookies return adult results while preserving the selected store language and region.

FlSteamLua should expose this as:

- an explicit `All games` store category;
- an explicit `Show adult content` preference;
- the same mature-content session applied consistently to search and app details.

## Kernel management direction

Keep these layers distinct:

1. Core package: install, update, cache, switch, uninstall, backups.
2. Runtime entry: `dwmapi.dll` vs `version.dll`, process-running checks, active-state validation.
3. Compatibility and repair: TOML/signature fetch, residual scan, restore.
4. Plugins: CloudRedirect and future native modules, each with install/version/enable/remove state.
5. Cloud save business: providers, folders, games, uploads, downloads, deletion, backups.

The existing kernel service already does package integrity and file backups well.
The main architectural gap was that CloudRedirect's native DLL lifecycle lived
inside the cloud save page and service instead of a plugin-management surface.
