import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('surface hierarchy and shapes retain upstream roles', () {
    for (final brightness in Brightness.values) {
      final theme = ui.buildAppTheme(brightness: brightness);
      expect(
        theme.scaffoldBackgroundColor,
        ui.SurfaceLevel.page.colorOf(theme.colorScheme),
      );
      expect(
        theme.cardTheme.color,
        ui.SurfaceLevel.card.colorOf(theme.colorScheme),
      );
      expect(theme.dialogTheme.shape, ui.AppShape.all(ui.AppCorner.alert));
      expect(ui.SurfaceLevel.card.next, ui.SurfaceLevel.block);
      expect(ui.SurfaceLevel.block.next, ui.SurfaceLevel.inset);
    }
  });

  testWidgets('upstream card action and nested surface remain interactive', (
    tester,
  ) async {
    var presses = 0;
    late ui.SurfaceLevel innerLevel;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: ui.CommonCard(
            onPressed: () => presses++,
            child: Builder(
              builder: (context) {
                innerLevel = ui.SurfaceScope.of(context);
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Manage Lua'),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(innerLevel, ui.SurfaceLevel.card);
    await tester.tap(find.text('Manage Lua'));
    await tester.pumpAndSettle();
    expect(presses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source container restores its card after close', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 100,
            child: ui.OpenContainer(
              closedBuilder: (_, open) => ui.CommonCard(
                onPressed: open,
                child: const Text('Open library item'),
              ),
              openBuilder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close detail'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open library item'));
    await tester.pumpAndSettle();
    expect(find.text('Close detail'), findsOneWidget);
    await tester.tap(find.text('Close detail'));
    await tester.pumpAndSettle();
    expect(find.text('Open library item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form row select keeps its row visible while the menu is open', (
    tester,
  ) async {
    String? selected = 'en';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 440,
                child: ui.generateGroup([
                  ui.FormRowSelect<String>(
                    title: 'Preferred language',
                    value: selected,
                    options: const [
                      ('system', 'System'),
                      ('en', 'English'),
                      ('zh', '简体中文'),
                    ],
                    onChanged: (value) => setState(() => selected = value),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Preferred language'));
    await tester.pumpAndSettle();

    expect(find.text('Preferred language'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Preferred language'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0,
        ),
      ),
      findsNothing,
    );

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(selected, 'zh');

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(find.text('Preferred language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list item options use the picker and keep their row', (
    tester,
  ) async {
    String selected = 'default';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 440,
              child: ui.generateGroup([
                ui.ListItem<String>.options(
                  key: const ValueKey('options-row'),
                  title: const Text('Proxy user agent'),
                  options: const ['default', 'custom'],
                  value: selected,
                  textBuilder: (value) => value == 'default' ? '默认' : '自定义',
                  onChanged: (value) => setState(() => selected = value),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    final picker = tester.widget<ui.GlyphIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('options-row')),
        matching: find.byType(ui.GlyphIcon),
      ),
    );
    expect(picker.glyph, same(ui.AppGlyphs.picker));

    await tester.tap(find.text('Proxy user agent'));
    await tester.pumpAndSettle();
    expect(find.text('Proxy user agent'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Proxy user agent'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0,
        ),
      ),
      findsNothing,
    );

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    expect(selected, 'custom');
    expect(tester.takeException(), isNull);
  });

  testWidgets('list item toggle and input share FlClash row behavior', (
    tester,
  ) async {
    var enabled = false;
    String value = '';
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 440,
              child: ui.generateGroup([
                ui.ListItem.toggle(
                  key: const ValueKey('toggle-row'),
                  title: const Text('Certificate check'),
                  value: enabled,
                  onChanged: (next) => setState(() => enabled = next),
                ),
                ui.ListItem<String>.input(
                  key: const ValueKey('input-row'),
                  title: const Text('User agent'),
                  subtitle: Text(value.isEmpty ? '默认' : value),
                  dialogTitle: 'User agent',
                  value: value,
                  onChanged: (next) {
                    if (next == null) return;
                    setState(() => value = next);
                  },
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Certificate check'));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);

    await tester.tap(find.text('User agent'));
    await tester.pumpAndSettle();
    expect(find.byType(ui.InputDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'FlSteamLua');
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();

    expect(value, 'FlSteamLua');
    expect(find.text('FlSteamLua'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source alert preserves its action result', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await ui.showFlDialog<bool>(
                  context: context,
                  builder: (context) => ui.CommonDialog(
                    title: 'Save changes',
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save'),
                      ),
                    ],
                    child: const Text('Three achievements are pending.'),
                  ),
                );
              },
              child: const Text('Show preview'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show preview'));
    await tester.pumpAndSettle();
    expect(find.text('Three achievements are pending.'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source right click menu executes the same management action', (
    tester,
  ) async {
    var openedSaves = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: ui.ContextMenuRegion(
            menuItems: [
              ui.CommonPopupMenuItem(
                label: 'Manage saves',
                onPressed: () => openedSaves++,
              ),
            ],
            child: const SizedBox(
              width: 240,
              height: 100,
              child: Center(child: Text('Lua game')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lua game'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage saves'));
    await tester.pumpAndSettle();
    expect(openedSaves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('common scaffold keeps a floating toolbar over its page scrim', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        theme: ui.buildAppTheme(),
        home: ui.CommonScaffold(
          title: '配置',
          actions: [
            IconButton(
              key: const ValueKey('toolbar-action'),
              onPressed: () => pressed++,
              icon: const Icon(Icons.add),
            ),
          ],
          body: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.text('配置'), findsOneWidget);
    expect(tester.getCenter(find.text('配置')).dx, lessThan(400));
    final scrim = find.byKey(const ValueKey('common-scaffold-header-scrim'));
    expect(scrim, findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(
      find.descendant(of: scrim, matching: find.byType(DecoratedBox)).first,
    );
    final gradient =
        (decorated.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.first.a, closeTo(.9, .001));
    expect(gradient.colors.last.a, 0);

    await tester.tap(find.byKey(const ValueKey('toolbar-action')));
    expect(pressed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fade edge masks a scrolling boundary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ui.buildAppTheme(),
        home: const Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ui.FadeEdge(
              extent: 24,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
    expect(mask.blendMode, BlendMode.dstIn);
    expect(tester.takeException(), isNull);
  });
}
