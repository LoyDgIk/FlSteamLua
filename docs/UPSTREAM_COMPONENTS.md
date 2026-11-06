# FlClash Upstream Components

Source: `chen08209/FlClash` commit `7fd417fb9a9a277c6a9339a8ac87f907df7c25f7`.

## Migrated

- `activate_box.dart`
- `animated_entries.dart`
- `animated_visibility.dart`
- `builder.dart`
- `button.dart`
- `caret_popup.dart`
- `chip.dart`
- `collapsible_section.dart`
- `disabled_mask.dart`
- `effect.dart`
- `foot_bar.dart`
- `form_page.dart`
- `form_row.dart`
- `form_sheet.dart`
- `keyed_animated_list.dart`
- `line_chart.dart`
- `loading.dart`
- `measure.dart`
- `pop_scope.dart`
- `record.dart` record headers, labels and list rows adapted for application logs
- `selection_mark.dart`
- `setting.dart`
- `sheet_header.dart`
- `skeleton.dart`
- `scroll.dart`
- `scroll_behavior.dart`
- `table_layout.dart`
- `text.dart` helpers added to the existing emoji text implementation
- `theme.dart` compact button themes added to the existing app theme builder

## Integrated

- `CommonScaffold` toolbar actions use `TonalButtonGroup`.
- `CommonDialogAction` keeps alert actions inside the shared FlClash dialog
  styling instead of rebuilding Material buttons in business pages.
- `FadeEdge` masks scrolling content at fixed header and footer boundaries.
- `AppImage` centralizes network image caching, placeholders and full-size
  preview sheets.
- `FormPage` uses `FloatingHeader` and `CommonCircleLoading`.
- `NullStatusSwitcher` uses `CommonCircleLoading.page`.
- `FormRowTextField` explicitly suppresses input and parent-row focus outlines.
- `ThemePreview` uses the shared `SelectionCheck`.
- `FormRow` labels use `TooltipLabel`.
- `ReleaseNotes` uses `flutter_markdown_plus` for complete GitHub-flavored
  Markdown in bundled changelogs, application updates and kernel confirmations.
  It shares existing typography, surfaces and dialog frames. The fixed FlClash
  reference has no generic Markdown renderer, so this is a small data adapter.

## Not Ported

- Business widgets under FlClash `lib/widgets` remain business-specific.
- Paged, snap, nested, and standalone sheet routing remain outside this
  project's current navigator and shell ownership.
- `navigation_dock.dart` and `sidebar.dart` remain represented by the
  existing FlSteamLua shell and its already-adapted elastic interaction code.
- `qr_code.dart` is deferred because it adds a rendering dependency without a
  current product surface.
- `super_reorderable_list.dart` is deferred because it depends on
  `super_sliver_list`, which this project does not use.
# Lua directory ordering

`LuaDirectoriesPage` adapts `ReorderableProfilesSheet` from FlClash
`7fd417fb9a9a277c6a9339a8ac87f907df7c25f7`, using `DecorationListItem`,
`ItemPositionProvider`, `ReorderableDelayedDragStartListener` and the existing
`commonProxyDecorator`. The shared `lib/ui/sort_handle.dart` is ported from
upstream `lib/ui/sortable.dart`, including keyboard lift and arrow-key ordering.
The page shows the fixed directory first and editable custom paths below it.
Sorting opens `showModalSideSheet` with `SideSheetScaffold`, a close action and
a save action; cancelling leaves the page and stored order untouched. The first
custom path is the default write target; without custom paths, the fixed
directory is used. Add/remove transitions use the existing `AnimatedEntries`.

## LAN optional files

The LAN transfer file picker adapts FlClash `features/form/selection_sheet.dart`
and `ui/list.dart` at the reference commit. It composes the existing
`SideSheetScaffold`, app-bar search, `CommonScrollBar`, `ItemPositionProvider`,
and `ListItem.toggle`. The business adapter stores a set of selected file IDs;
Flutter's `ListView.builder` keeps only visible rows mounted when a game has
thousands of optional files. A separate shared visual component was not needed.

## Sidebar animation and page retention

The shell now follows FlClash `pages/home.dart` (`PageView` plus retained nested
navigators) and the original `ui/keep_scope.dart`. It no longer substitutes an
Offstage stack that lays out every visited page during sidebar resizing.
`_PageSizeHold` adapts `ui/keyboard_inset_hold.dart`'s inactive-page hold to desktop
window size changes. `ui/theme.dart` uses the input-keyed cache from
`manager/theme_manager.dart`; `main.dart` follows `application.dart` by disabling
MaterialApp theme interpolation while retaining ThemeCrossFade.

## Storage overview and row alignment

`DataManagementPage` retains `CommonCard`, `generateSection` and
`DecorationListItem`. Its storage painter fills the card's available content
width. Each row reserves the same `kMinInteractiveDimension` action slot, as in
FlClash `ui/sortable.dart`'s `DetailButton`, so numeric values align even when a
directory has no management menu. No additional presentation component is needed.

## Loading and failure layout (2026-11-06)

Page operations use the existing `CommonScaffold.isLoading` overlay and
`CommonProgressBar`, following FlClash's separate body/header presentation.
The Lua/JS editors, preferences, achievements, account manager, ticket/Goldberg
tools, extraction, verification and library pages no longer insert temporary
progress rows into their content. Task cards retain their measured progress.

`generateSection` continues to receive rows only, as upstream `ui/list.dart`
expects. Update, Steam-path and background-task failures sit outside those row
groups with 12 logical pixels of separation. Passive error cards use
`CommonCard.inert` from upstream `ui/card.dart` so messages retain readable colors.
Kernel repository metadata has a stable row, and warnings follow the existing
sections rather than being inserted before the controls during a refresh.

## Quick start (2026-11-06)

The first-run guide uses a dedicated responsive introduction layout authorized
for this flow: a short introduction beside the configuration on wide windows,
one column on compact windows, and a fixed navigation footer. Step changes use
opacity/translation only and respect reduced motion. Language is the first
configuration control. `ThemeColorSwatches` is shared with the full theme page;
theme modes and sidebar styles use the existing segmented control.

Configuration links retain the existing Steam files, Lua directories, kernel,
content source and network pages. The initial route owns a nested Navigator
under the desktop caption so opening configuration keeps the guide and window
controls alive. Skip and finish persist one dismissal flag; Settings opens the
same guide as a normal secondary route. No configuration operation is treated
as proof that a game or core is running.

## LAN transfer activity card

`TransferHero` reuses FlClash's `ui/line_chart.dart` and dashboard
`views/dashboard/widgets/traffic.dart` sampling pattern, with `CommonCard`,
`DashboardIconButton`, `AppGlyphs`, theme surfaces and `CommonProgressBar`.
FlClash has no combined bar-and-line chart; the shared `LineChart` accepts an
optional bar series while retaining its original line renderer. The card plots
the native network and disk samples on one scale. `CommonProgressBar` accepts an
optional theme color so network and installation use their matching series.
The media/metrics arrangement adapts the requested Steam card layout; its
transfer/installation values and actions remain business data adapters.


## Cloud browser, storage profiles and backups (2026-11-05)

Cloud pages compose the existing CommonScaffold, DecorationListItem,
AnimatedEntries, SegmentedControl, NullStatus and SideSheetScaffold. Storage
editing follows FlClash `views/profiles/edit.dart` through local FormPage/FormRow;
advanced settings reuse CollapsibleSection. Storage sorting adapts FlClash
`ReorderableProfilesSheet` and the migrated Lua directory sorting sheet, retaining
SortHandle and commonProxyDecorator. Draft close confirmation uses CommonPopScope.

FlClash has no save-repository, backup-identity or Steam-stop business workflow.
CloudFilesSheet, CloudBackupsSheet and confirmCloudOperation are small data/action
adapters over shared side-sheet and row components. They add no independent
surfaces, animations, controls or modal implementations. One operation sheet
contains account, destination, backup and Steam-stop information. No rendered
visual parity is claimed; this round used interaction tests and a release build.


The cloud overview's status rows both provide a shared GlyphIcon leading slot.
Account filtering uses DashboardIconButton.selected in the toolbar and the
existing account side sheet; it no longer renders an ungrouped rectangular row
between the location segments and the animated game list.

Cloud account filtering reuses SteamAvatar and LibraryService.avatarPath from
the existing sidebar/account manager. DashboardIconButton accepts an optional
icon widget and size while retaining its original button surface and animation.
Avatar paths are resolved when the account list changes, not on each filter or
page rebuild; all-account mode keeps the shared account glyph.


## Steam client versions (2026-11-06)

The tool index adds a maintenance row; SteamVersionsPage reuses CommonScaffold,
AnimatedEntries, DecorationListItem, SegmentedControl, MetaChip and NullStatus.
History and Wayback settings use showFormSheet/FormPage/FormRow; package details,
backups and install confirmation use the shared side-sheet frame. This adapts
FlClash `views/profiles/profiles.dart` browsing and `views/profiles/edit.dart` form
patterns; no new presentation layer was copied or independently recreated.

The version browser now places its header and list in a single CustomScrollView.
The existing NullStatus uses scrollable:false inside SliverFillRemaining instead
of a fixed-height nested viewport. Historical rows exist on the initial offline
load, while details fetch only the selected manifest. Steam update switches were
removed from both this page and installation confirmation; the settings page
continues to own them.


## Author support (2026-11-06)

About links adapt FlClash `views/about.dart` through existing ListItem and
generateSection. Dashboard and library reuse DashboardIconButton. The support
and feedback workflows use showModalSideSheet/SideSheetScaffold, TonalButton
and SegmentedControl. FlClash has no bundled payment-code business workflow,
so support_sheet.dart only adapts the supplied local images and QQ group number;
it adds no independent presentation layer. The coffee glyph extends the shared
AppGlyphs system using its existing path primitives.
