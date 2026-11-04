# Kernel Management Migration

## Upstream Sources

- `Services/IOpenSteamToolService.cs`
- `Services/IKernelPackageService.cs`
- `Services/IKernelManagerService.cs`
- `Views/OpenSteamToolWindow.xaml`
- `Views/OpenSteamToolWindow.xaml.cs`

## Migrated Behavior

- Official and local kernel package inventory, cache, download, import, switch,
  delete, and active-package state.
- Install or update to the newest official package.
- Enable and disable the installed kernel with a pre-change snapshot.
- Switch the injection entry between `dwmapi.dll` and `version.dll`.
- Uninstall with an exact on-disk file preview and automatic backup.
- Restore switch, enable, disable, entry, and uninstall snapshots.
- Detect Steam DLL SHA256 fingerprints and optional build ID before fetching
  the three OpenSteamTool TOML signature files.
- Scan residual OpenSteamTool, SteamTools, TB/BIAO, GreenLuma, and Steam config
  files or directories.
- Show residual category, severity, size, file count, cleanup eligibility, and
  directory/file type.
- Back up selected residual files and directories before recursive removal.
- Reject residual cleanup paths outside the configured Steam root and reject
  directory links during backup or deletion.
- Persist the startup kernel-update check preference and surface an update in
  the dashboard kernel card.

## Page Structure

The Flutter page uses FlClash grouped rows and side sheets rather than the old
button wall:

- Kernel overview and startup update preference.
- Injection entry selection.
- Kernel actions.
- Package cache and official release list.
- Snapshot restore list.
- Residual scan side sheet.
- TOML fingerprint preview and result side sheets.

## Safety

- No kernel file mutation runs while Steam is active.
- Package ZIP entries are allow-listed and path traversal is rejected.
- Package archives and expanded data have size limits.
- Every destructive kernel operation creates a backup first.
- Residual cleanup only accepts fresh scan IDs and revalidates paths.
