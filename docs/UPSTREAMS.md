# Upstream sources and UI adaptations

## UI reference

FlClash: https://github.com/chen08209/FlClash

Pinned source: `7fd417fb9a9a277c6a9339a8ac87f907df7c25f7` (`main`),
inspected on 2026-11-01. The upstream package reports `0.9.2+2026102401`.
Use this fixed commit when comparing changes; do not silently replace the
reference with the current moving branch.

The reference checkout is kept in `.git/references/FlClash`. The UI now ports
actual upstream presentation implementations instead of matching timings alone.

| Local presentation | Upstream source | Adaptation |
| --- | --- | --- |
| Sidebar | `lib/ui/sidebar.dart` | Original layout, indicators and expansion; Steam destinations and footer inputs replace application providers. |
| Theme, shape, surfaces and typography | `lib/ui/shape.dart`, `surface.dart`, `color.dart`, `typography.dart`, `font.dart` | Original presentation composition bound to this project's Flutter SDK. |
| Cards and grouped lists | `lib/ui/card.dart`, `list.dart`, list selection and separator parts | Original surface levels, selection and grouped row geometry. |
| Dialogs and menus | `lib/ui/dialog.dart`, `popup.dart`, `context_menu.dart`, `elastic_press.dart` | Original spring route, press response, popup and context-menu implementations. |
| Feedback and modal facade | `lib/manager/status_manager.dart`, `lib/common/dialog.dart`, `lib/ui/input.dart` | Original queued status messages, swipe dismissal, spring dialogs and field dialog, exposed through one application facade. |
| Liquid glass | `lib/ui/liquid_glass.dart`, capture helpers and shader | Original rendering and shader, wired through `LiquidGlassScope` and `LiquidGlassHost`. |
| Container and page transitions | `lib/ui/open_container.dart`, `page_transition.dart`, `drag_back.dart`, `deferred_push.dart` | Actual custom container renderer and shared page-motion implementation; local wrapper APIs preserve current callers. |
| Theme changes | `lib/ui/theme_cross_fade.dart` | Original frame capture and cross-fade behavior with explicit reduced-motion input. |
| Theme settings | `lib/views/theme.dart`, `lib/views/theme_preview.dart`, `lib/widgets/palette.dart`, `lib/views/font_family.dart` | Theme groups, live miniature preview, color palette, font picker and tool-style settings sections are ported to `SettingsStore`. |

Upstream `material_ui` 1.5.0 requires a newer Flutter/Dart SDK than this
project's Flutter 3.44.4 / Dart 3.12.2. Presentation imports bind to Flutter
Material while retaining the upstream implementations. Proxy/VPN business
providers and backend code are not included.

`JetBrainsMono-Regular.ttf` and `Twemoji.Mozilla.ttf` are copied without
modification. Their original licenses are retained in
`assets/fonts/JetBrainsMono-OFL.txt` and
`assets/fonts/Twemoji-Mozilla-LICENSE.md`, and registered in the application
license page. The glass shader is registered as
`assets/fonts/liquid_glass.frag`.

## Functional reference

Fluent-Steam-Lua: https://github.com/huanyuejue/Fluent-Steam-Lua

Local baseline: `aeec310a536506304bdd16420bbe1601595abad3` (2026-11-01).
The baseline working copy contained local functional modifications. Rewriting
these behaviors must not reset or overwrite that original working copy.
The new application targets Windows 10/11 x64 and implements its business
logic in Dart. The WPF/XAML UI is not the visual reference.

The original zlib notice remains in `assets/licenses/Fluent-Steam-Lua-zlib.txt`.
For any subsequently imported upstream source, record its source commit and
preserve its specific notices before distributing the result.

## Native and protocol references

- SteamAchievementManager supplies the native achievement interface reference;
  its zlib text is preserved separately.
- SteamKit2 supplies protocol references under LGPL 2.1. The retained license
  text was retrieved from `https://raw.githubusercontent.com/SteamRE/SteamKit/master/LICENSE`.
  Record exact protocol source revisions next to any copied definitions.
- Steamless unpackers are CC BY-NC-ND 4.0 and are excluded from this port.
  Do not inherit the old blanket description of the entire cracking tool tree
  as MIT when documenting dependencies.

## Updating references

Review functional and UI upstream changes independently. Compare against the
recorded commit, adapt only the needed behavior, retain notices and update
this record when the actual reference changes. Primary navigation stays
`面板主页 / 库 / 商店 / 成就 / 云存档`; secondary utilities live in game actions,
the tools entry or settings.
