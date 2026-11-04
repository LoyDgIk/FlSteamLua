# Data Management

The Settings page opens a shared data-management page that reports the size and
file count of each application-owned directory:

- `cache`: cover images, key-subscription metadata and other disposable files.
- `backups`: Lua, cloud-save, kernel and other recoverable backups.
- `downloads`: downloaded trainers, online fixes, updates and generated files.
- `logs`: diagnostic and runtime logs.
- `data`: application state, including content-source configuration and the LAN
  transfer engine state.

The cache, backups, downloads and logs locations can be changed independently.
Existing contents are copied first and the old directory is removed only after
the copy succeeds. The data directory remains alongside the application state so
the running LAN engine keeps one stable data location. Lua continues to be
managed from Steam and game files.

Location overrides are stored in `settings.json` under `storageLocations`.
`AppPaths` resolves the first path segment against those overrides, so existing
services continue to use relative paths such as `backups/cloud` or
`cache/covers` without business-specific branching.

Clearing the cache removes the configured cache directory, key-cache memory,
Flutter's image cache and LAN transfer chunk caches. Backups, downloads,
settings and save data are retained.
