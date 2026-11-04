import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_source_registry.dart';
import 'package:fl_steam_lua/features/content_sources/content_sources_page.dart';
import 'package:fl_steam_lua/features/content_sources/script_source_editor_page.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/manifests/manifest_source_service.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Registry extends ContentSourceRegistry {
  _Registry({
    required super.manifests,
    required super.keyCache,
    required super.settings,
  });
  @override
  Future<void> initialize() async {}
  @override
  List<ContentSourceDefinition> get sources => const [
    ContentSourceDefinition(
      id: 'subscription:first',
      name: 'Subscription One',
      kind: ContentSourceKind.subscription,
      capabilities: {ContentCapability.lua},
    ),
    ContentSourceDefinition(
      id: 'script:second',
      name: 'Manifest Two',
      kind: ContentSourceKind.script,
      capabilities: {ContentCapability.manifestFiles},
    ),
    ContentSourceDefinition(
      id: 'script:third',
      name: 'Disabled Three',
      kind: ContentSourceKind.script,
      capabilities: {ContentCapability.lua},
      enabled: false,
      configurationComplete: false,
    ),
  ];
}

class _ScriptRegistry extends _Registry {
  _ScriptRegistry({
    required super.manifests,
    required super.keyCache,
    required super.settings,
  });

  @override
  List<ContentSourceDefinition> get sources {
    final definition = manifests.sources.first;
    return [
      ContentSourceDefinition(
        id: 'script:${definition.id}',
        name: definition.name,
        kind: ContentSourceKind.script,
        capabilities: const {ContentCapability.manifestFiles},
      ),
    ];
  }
}

void main() {
  late Directory directory;
  late SettingsStore settings;
  late ManifestSourceService manifests;
  late KeyCacheService keys;
  late _Registry registry;
  late TaskCenter tasks;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('content-page-test-');
    final paths = AppPaths(directory.path);
    settings = SettingsStore(paths);
    manifests = ManifestSourceService(paths: paths);
    keys = KeyCacheService(paths: paths, settings: settings);
    registry = _Registry(
      manifests: manifests,
      keyCache: keys,
      settings: settings,
    );
    tasks = TaskCenter();
  });
  tearDown(() async {
    registry.dispose();
    manifests.dispose();
    keys.dispose();
    settings.dispose();
    tasks.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    ContentSourceRegistry? registryOverride,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: ContentSourcesPage(
          registry: registryOverride ?? registry,
          tasks: tasks,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectFilter(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(const ValueKey('content-source-filter')));
    await tester.pumpAndSettle();
    final menu = tester.widget<ui.CommonPopupMenu>(
      find.byType(ui.CommonPopupMenu),
    );
    menu.items[index].onPressed!();
    await tester.pump();
    Navigator.of(tester.element(find.byType(ui.CommonPopupMenu))).pop();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'one source list filters by capability and enabled state without implementation tabs',
    (tester) async {
      await mount(tester);
      expect(find.text('Subscription One'), findsOneWidget);
      expect(find.text('Manifest Two'), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect((grid.padding! as EdgeInsets).top, ui.pageContentTopInset);
      expect(find.byType(ui.MetaChip), findsWidgets);
      expect(find.byType(ui.DashboardChip), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Active'), findsNothing);
      await selectFilter(tester, 1);
      expect(find.text('Subscription One'), findsOneWidget);
      expect(find.text('Manifest Two'), findsNothing);
      await selectFilter(tester, 2);
      expect(find.text('Manifest Two'), findsOneWidget);
      expect(find.text('Subscription One'), findsNothing);
      await selectFilter(tester, 4);
      expect(find.text('Disabled Three'), findsOneWidget);
      expect(find.text('Manifest Two'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subscription editor returns explicit source configuration and has no global selection',
    (tester) async {
      KeyCacheSubscription? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await ui.showFormSheet<KeyCacheSubscription>(
                    context: context,
                    builder: (_) => const SubscriptionSourceEditor(),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'My Keys');
      await tester.enterText(
        fields.at(1),
        'https://example.com/depotkeys.json',
      );
      await tester.enterText(
        fields.at(2),
        'https://example.com/appaccesstokens.json',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result?.name, 'My Keys');
      expect(result?.intervalHours, 24);
      expect(result?.enabled, isTrue);
      expect(find.text('Active'), findsNothing);
    },
  );

  testWidgets(
    'script cards use compact status and expose editor actions in the menu',
    (tester) async {
      await mount(tester);
      final scriptCard = find.byKey(
        const ValueKey('content-source-script:second'),
      );
      expect(tester.widget<ui.CommonCard>(scriptCard).isError, isFalse);
      final incomplete = find.byKey(
        const ValueKey('content-source-script:third'),
      );
      expect(tester.widget<ui.CommonCard>(incomplete).isError, isFalse);

      final region = find.ancestor(
        of: scriptCard,
        matching: find.byType(ui.ContextMenuRegion),
      );
      final items = tester.widget<ui.ContextMenuRegion>(region).menuItems!;
      expect(
        items.map((item) => item.label),
        containsAll(['Edit script', 'Configure source', 'Validate script']),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('script card click opens source configuration', (tester) async {
    await tester.runAsync(manifests.initialize);
    final definition = manifests.sources.first;
    final scriptRegistry = _ScriptRegistry(
      manifests: manifests,
      keyCache: keys,
      settings: settings,
    );
    addTearDown(scriptRegistry.dispose);
    await mount(tester, registryOverride: scriptRegistry);

    await tester.tap(
      find.byKey(ValueKey('content-source-script:${definition.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScriptSourceEditor), findsOneWidget);
    expect(find.byType(ScriptSourceEditorPage), findsNothing);
    Navigator.of(tester.element(find.byType(ScriptSourceEditor))).pop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'script editor keeps save at the trailing edge and tools in overflow',
    (tester) async {
      await tester.runAsync(manifests.initialize);
      final source = manifests.sources.first;
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(),
          home: ScriptSourceEditorPage(
            service: manifests,
            sourceId: source.id,
            title: source.name,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tools = find.byKey(const ValueKey('script-tools'));
      final save = find.byKey(const ValueKey('script-save'));
      expect(tools, findsOneWidget);
      expect(save, findsOneWidget);
      expect(
        tester.getCenter(save).dx,
        greaterThan(tester.getCenter(tools).dx),
      );
      expect(tester.widget<IconButton>(save).onPressed, isNull);

      await tester.enterText(
        find.byType(TextField),
        '${source.script}\n// changed',
      );
      await tester.pump();
      expect(tester.widget<IconButton>(save).onPressed, isNotNull);

      await tester.tap(tools);
      await tester.pumpAndSettle();
      expect(find.text('Validate script'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
