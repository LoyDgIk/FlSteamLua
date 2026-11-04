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
