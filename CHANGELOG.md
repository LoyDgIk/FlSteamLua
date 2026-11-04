# Changelog

All notable user-facing changes are recorded here. Release workflow notes are
generated from the matching version section.

## [Unreleased]

## [0.1.0] - 2026-11-04

### Added

- Windows Flutter desktop app for Steam libraries, Lua management, achievements,
  cloud saves, store browsing and game tools.
- FlClash-based shared UI framework, side sheets, grouped lists, search,
  transitions and theme controls.
- Unified content-source architecture for subscriptions, JavaScript sources,
  Lua, manifests and local imports.
- Native OpenSteamTool kernel management, package repository, local packages,
  injection entries, snapshots and residual cleanup.
- Go LAN transfer engine with TLS, discovery, delta chunks, resumable staging,
  manifest verification and Steam library installation.
- D encryption authorization tool with ticket extraction, `tickets.txt` import,
  DPAPI backups and explicit registry application.
- DLC management, game file verification, patch tools, trainers, online fixes,
  cloud-save backups and data/cache management.
- Checksum-verified GitHub release updates and this automated release workflow.

### Changed

- Replaced legacy Material and native dialogs with the shared FlClash-style
  presentation layer.
- All visible strings use generated ARB localization.
- Cloud saves use a single searchable save list while backup history is grouped
  by game in a side sheet.

### Fixed

- Game verification searches all Steam libraries and falls back to an explicit
  unverified inventory when exact depot manifests are unavailable.
- Indeterminate progress bars show a full track with a moving sweep.
- Cloud-save folders open through a detached Explorer process.
