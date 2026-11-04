# FlSteamLua Agent Rules

## 1. Scope

- These rules apply to the whole repository.
- Read and write source files as UTF-8.
- Preserve unrelated user changes. Never revert a dirty file merely to simplify an implementation.
- Do not commit, amend, push, create a branch, or rewrite history unless explicitly requested.

## 2. Project Direction

- FlSteamLua is a Windows Flutter desktop application, not a generic Material demo.
- FlClash is the visual and interaction reference. Inspect source before changing UI.
- Primary FlClash source: `.git/references/FlClash`.
- Default reference commit: `7fd417fb9a9a277c6a9339a8ac87f907df7c25f7`.
- Port or adapt FlClash source and the local components under `lib/ui` before creating a new widget.
- Screenshots are acceptance material, not implementation instructions. Use source code to determine layout, animation, spacing, surfaces, and interaction.
- If FlClash lacks a required business component, build the smallest FlClash-style adapter from existing source patterns and record why it was necessary.
- Ported GPL-3.0 source files retain their source and SPDX headers.
- Do not replace a source-backed component with a defensive or independently invented approximation.

## 3. Page Creation Workflow

Before writing a page:

1. Identify the page type in Section 4.
2. Search FlClash and `lib/ui` for an existing page frame, row, button, sheet, search field, empty state, editor, or status component.
3. Read the upstream source and its dependencies. Do not infer behavior from a name or screenshot.
4. State which source component or page pattern is being reused.
5. Implement the business data adapter without forking the shared presentation layer.
6. Run targeted checks and verify the real rendered page for UI changes.

## 4. Page Types

Choose a layout based on what the page does. Do not force every page into a settings form.

- **Tool index:** Use multi-section grouped rows, matching FlClash `ToolsView`. Do not use category pills plus an unrelated card grid.
- **Resource browser:** Use toolbar search, a FlClash segmented control or tonal button group for modes, grouped rows or content cards, `NullStatus`, and side sheets for secondary details.
- **Library:** Keep the required two tabs: Lua library first, Steam game library second. Preserve Lua import, drag/drop, context actions, save management, and game actions.
- **Form:** Use `showFormSheet` with `FormPage`, `FormRow`, inline trailing fields, grouped sections, and bottom cancel/save actions.
- **Detail:** Use a detail page or side sheet according to information depth. Media/cover detail may be richer; transient details use `showModalSideSheet` plus `SideSheetScaffold`.
- **Editor:** Use a full-height editor page with a unified toolbar, code or text viewport, and side-sheet confirmations. JS source card clicks open configuration; code editing is an explicit action.
- **Logs/runtime output:** Use `CommonScaffold` search/actions, `NullStatusSwitcher`, `CommonScrollBar`, follow-end behavior, and the shared log/status presentation.
- **Settings:** Use grouped FlClash setting rows. Settings styling is only for actual settings, not for every tool or feature page.
- **Status/diagnostics:** Use grouped status rows, `MetaChip`/`TonalChip`, and concise actions. Avoid decorative fake metrics.

## 5. Page Chrome and Layout

- Every page uses `CommonScaffold` unless an upstream route or sheet intentionally owns its frame.
- The toolbar floats over the body with the shared gradient scrim.
- Content must start below the toolbar inset. Do not place content partially under the app bar.
- Search belongs in the app bar unless the upstream page pattern explicitly docks it.
- Mode and list-layout switches belong in the toolbar or a FlClash segmented control, not in ad hoc page controls.
- Do not add page-title headings, introductory paragraphs, or descriptive marketing copy below the app bar.
- Use shared status and empty-state components instead of centered raw text.
- List layouts should use `DecorationListItem`, `generateSection`, `CommonCard`, `CommonScrollBar`, and the shared spacing metrics.
- When a list item is removed, layout must close the gap with the shared animation component; do not leave placeholder holes.

## 6. Component Rules

- Reuse `lib/ui` first. `docs/UPSTREAM_COMPONENTS.md` lists migrated generic components.
- Use `AppGlyphs`/`GlyphIcon`; do not introduce raw Material icons when a shared glyph exists.
- Use `TonalButton`, `TonalButtonGroup`, `SegmentedControl`, `CommonChip`, `TonalChip`, `MetaChip`, `CommonSwitch`, `FormRow`, and `NullStatus` instead of one-off controls.
- Use `CommonDialog`/`AppDialogs` for FlClash alerts and confirmations.
- Use `showFormSheet`/`FormPage` for forms with multiple fields.
- Use `showModalSideSheet`/`SideSheetScaffold` for details, probes, task panels, and secondary workflows.
- Use `CommonCircleLoading`, `SkeletonPill`, and `NullStatusSwitcher` instead of raw progress or empty widgets when applicable.
- Business code may compose shared components but must not copy their visuals into local private variants.

## 7. Internationalization

- Every new visible string is added to `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`.
- Access strings through generated `AppLocalizations`/`context.l10n`.
- Never add `text(zh, en)`, `localeText`, or equivalent per-page bilingual helpers.
- Use ARB placeholders for counts, IDs, names, and errors.
- Do not hardcode Chinese or English UI copy in widgets or services.

## 8. Architecture and Data Boundaries

- Validate untrusted input only at system boundaries: files, network payloads, process arguments, persisted data, and user input.
- Internal calls receive typed, trusted data. Do not repeat defensive null/range/type checks across internal layers.
- Do not add speculative fallback paths, catch-all wrappers, or compatibility branches without a concrete requirement.
- No legacy-data migration work before the first release unless explicitly requested.
- Content sources are the single concept: subscriptions, JS scripts, and local content are source types.
- There is no globally selected subscription. Selection and configuration belong to each source.
- A JS source click opens that source's configuration; the editor opens only from an explicit edit action.
- Keep feature parity with Fluent-Steam-Lua where requested. A visual migration must not delete working management functions.
- Separate operational instructions from deliverable content. Do not restate implementation instructions in the final output unless the user asks for them.

## 9. Prohibited Pages and Patterns

Do not create or preserve these patterns in new work:

- A tool center made of unrelated category chips and card grids when FlClash uses grouped rows.
- A page with a large title and explanatory paragraph below the app bar.
- A page where content is initially hidden behind or overlaps the app bar.
- A settings form used as the default layout for browsing, logs, media, tools, or management pages.
- Stacked filled Material text fields inside a dialog or narrow side sheet for a multi-field form.
- Raw `AlertDialog`, default Material modal sheets, default `TextField` forms, or native OS dialogs for in-app presentation.
- Material `TabBar`/`TabBarView` or `ChoiceChip` when a FlClash segmented control or tonal group is the correct pattern.
- A custom one-off modal, popup, input, picker, status chip, empty state, or feedback layer.
- A page filled with decorative cards, fake metrics, or non-actionable dashboard panels.
- A library that only displays the Steam catalogue and omits Lua import, drag/drop, context management, and save actions.
- Separate top-level subscription and JS-source tabs, or a global active-subscription control.
- A JS source card that opens the code editor on ordinary click.
- A task panel or secondary workflow that does not use the unified side-sheet framework.
- Raw hardcoded bilingual strings or duplicated locale conditionals.
- Legacy migration paths, compatibility aliases, or fallback implementations added only “just in case”.
- Reimplementing an upstream component defensively after it has already been identified in `.git/references/FlClash`.

## 10. Validation

- Run `dart analyze --fatal-infos` after code changes.
- Run only the targeted tests affected by the change. Avoid repeated full suites and unnecessary screenshot loops.
- For a UI change, build the Windows release and inspect the actual rendered page when feasible.
- Live Steam/game testing is low-frequency. Use one isolated smoke when necessary; do not repeat live runs without a new reason.
- Do not claim FlClash parity based only on source inspection or tests. Verify the rendered result.
- Report any unverified area explicitly and stop when the requested scope is complete.
