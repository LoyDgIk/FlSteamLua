# Third-party notices

FlSteamLua is a modified Flutter desktop project distributed under GNU GPL
version 3. Its UI and business implementation have distinct upstream sources.
The original authors retain ownership of their work. This project is not an
official release of either upstream project.

## FlClash UI

- Source: https://github.com/chen08209/FlClash
- Reference: `7fd417fb9a9a277c6a9339a8ac87f907df7c25f7` on `main`.
- License: GNU GPL version 3; full text is in `LICENSE` and
  `assets/licenses/FlClash-GPL-3.0.txt`.
- Attribution: chen08209 and the FlClash contributors.
- Adapted material: upstream sidebar, cards, grouped rows, shape, surface,
  typography, popup and context menus, spring dialogs, liquid-glass rendering,
  custom container/page transition renderers, drag-back, theme cross-fade,
  theme preview, color palette, tools-page settings structure, theme view and
  font-selection sheet, status-message feedback manager, dialog facade and
  license browser.
  File mappings and SDK adaptations are recorded in `docs/UPSTREAMS.md`.
- Changes: application providers are replaced by Steam presentation inputs;
  upstream `material_ui` imports bind to Flutter Material for this SDK.
  The Clash engine and VPN/proxy business implementation are not included.
- Unmodified fonts: JetBrains Mono (SIL OFL 1.1) and Twemoji Mozilla
  (the upstream license describes Apache 2.0 code and CC BY 4.0 artwork).
  Full notices are retained under `assets/fonts` and available in-app.

## Fluent-Steam-Lua

- Source: https://github.com/huanyuejue/Fluent-Steam-Lua
- Baseline: local source at `aeec310a536506304bdd16420bbe1601595abad3`, together
  with the local functional changes explicitly used during the Dart rewrite.
- Copyright (c) 2024 SteamLuaManager.
- License: zlib; the unaltered notice is included in
  `assets/licenses/Fluent-Steam-Lua-zlib.txt`.
- Usage: functional reference and any adapted source material for the Steam
  library, Lua, achievements, manifests, cloud-save and utility workflows.
- This is a modified Dart implementation; the original WPF application is not
  included or represented as the work of the new project.

## SteamAchievementManager

- Source: https://github.com/gibbed/SteamAchievementManager
- Copyright (c) 2024 Rick (rick 'at' gibbed 'dot' us).
- License: zlib; full text is in
  `assets/licenses/SteamAchievementManager-zlib.txt`.
- Usage: reference for native Steam achievement interfaces. The SAM GUI and
  its C# runtime are not included in the Flutter UI.

## SteamKit2

- Source: https://github.com/SteamRE/SteamKit
- License: GNU Lesser General Public License version 2.1; upstream text is
  retained in `assets/licenses/SteamKit2-LGPL-2.1.txt`.
- Usage: reference for the Dart Steam protocol implementation. SteamKit2 is
  not shipped as a .NET executable or assembly. See the protocol implementation
  source and upstream record for the actual adapted protocol material.

## Go runtime

- Source: https://go.dev/
- Copyright (c) 2009 The Go Authors.
- License: BSD 3-Clause; the notice is included in
  `assets/licenses/Go-BSD-3-Clause.txt`.
- Usage: the standalone `lan_transfer_engine.exe` contains the Go runtime and
  standard library. FlSteamLua's Go transport implementation is original code
  and does not interoperate with Steam's private LAN content protocol.

## CloudRedirect

- Source: https://github.com/huanyuejue/CloudRedirect (preserved upstream fork).
- Copyright (c) 2026 Selectively11.
- License: MIT; the full notice is retained in
  `assets/licenses/CloudRedirect-MIT.txt`.
- Usage: the native save-redirection DLL, downloaded and SHA256-checked only
  when the user enables redirection. Its companion frontend is not included.
- Configuration, OAuth, cloud requests, deployment and backup management are
  reimplemented in Dart. The native DLL retains its original license.

## Excluded Steamless unpackers

The Steamless unpackers encountered in the functional upstream use
CC BY-NC-ND 4.0. They are not treated as MIT-licensed code and are not ported
or included in this GPL project. No Steamless binary is bundled.

## Flutter dependencies and external data

The Flutter framework, `animations` and other resolved packages retain their
individual licenses. Their notices are available through Flutter's generated
license registry and the application's open-source license page. New assets
must retain their own attribution; the project license does not relicense
external game covers, Steam artwork, or independently distributed native tools.

For GPL-covered modifications, redistribution must include the applicable
notices and provide the corresponding source as required by the license.
