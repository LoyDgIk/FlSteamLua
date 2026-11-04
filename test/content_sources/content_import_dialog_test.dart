import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_import_dialog.dart';
import 'package:fl_steam_lua/features/content_sources/content_import_service.dart';
import 'package:fl_steam_lua/features/content_sources/content_resolver.dart';
import 'package:fl_steam_lua/features/content_sources/content_source_registry.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/manifests/manifest_source_service.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Registry extends ContentSourceRegistry {
  _Registry(
    ManifestSourceService scripts,
    KeyCacheService keys,
    SettingsStore settings,
  ) : super(manifests: scripts, keyCache: keys, settings: settings);
  final definitions = <ContentSourceDefinition>[
    const ContentSourceDefinition(
      id: 'subscription:lua',
      name: 'Lua provider',
      kind: ContentSourceKind.subscription,
      capabilities: {ContentCapability.lua},
    ),
    const ContentSourceDefinition(
      id: 'script:both',
      name: 'Both provider',
      kind: ContentSourceKind.script,
      capabilities: {ContentCapability.lua, ContentCapability.manifestFiles},
    ),
    const ContentSourceDefinition(
      id: 'script:manifest',
      name: 'Manifest only',
      kind: ContentSourceKind.script,
      capabilities: {ContentCapability.manifestFiles},
    ),
  ];
  @override
  Future<void> initialize() async {}
  @override
  List<ContentSourceDefinition> get sources => definitions;
}

class _LocalResolver extends ContentResolver {
  _LocalResolver(super.registry, {this.cancelSecond = false});
  final bool cancelSecond;
  @override
  Future<List<int>> discoverLocalGames(
    List<String> paths, {
    TaskContext? task,
  }) async => [10, 20];
  @override
  Future<ContentBundle> resolveLocal(
    int appId,
    List<String> paths, {
    TaskContext? task,
  }) async {
    if (cancelSecond && appId == 20) throw const TaskCancelled();
    return ContentBundle(
      appId: appId,
      lua: ContentArtifact(
        filename: '$appId.lua',
        bytes: [1],
        capability: ContentCapability.lua,
      ),
    );
  }
}

class _FailingImporter extends ContentImportService {
  _FailingImporter(LibraryService library) : super(library: library);
  @override
  Future<ContentImportPreview> preview(ContentBundle bundle) async =>
      ContentImportPreview(
        bundle: bundle,
        entries: [
          ContentImportEntry(
            path: 'fixture/${bundle.appId}.lua',
            artifact: bundle.lua!,
            exists: false,
          ),
        ],
      );
  @override
  Future<ContentImportResult> commit(
    ContentImportPreview preview, {
    bool overwrite = false,
    TaskContext? task,
  }) async => throw StateError('Fixture commit failure');
}

void main() {
  late Directory directory;
  late SettingsStore settings;
  late ManifestSourceService scripts;
  late KeyCacheService keys;
  late _Registry registry;
  late LibraryService library;
  late TaskCenter tasks;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('content-dialog-test-');
    final paths = AppPaths(directory.path);
    settings = SettingsStore(paths);
    scripts = ManifestSourceService(paths: paths);
    keys = KeyCacheService(paths: paths, settings: settings);
    registry = _Registry(scripts, keys, settings);
    library = LibraryService(paths: paths, settings: settings);
    tasks = TaskCenter();
  });
  tearDown(() async {
    registry.dispose();
    scripts.dispose();
    keys.dispose();
    library.dispose();
    tasks.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: ContentImportDialog(
            registry: registry,
            resolver: ContentResolver(registry),
            importer: ContentImportService(library: library),
            tasks: tasks,
            appId: 440,
            gameName: 'Test game',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Lua selection is required and only compatible sources appear', (
    tester,
  ) async {
    await mount(tester);
    final fields = tester
        .widgetList<ui.FormRowSelect<String>>(
          find.byType(ui.FormRowSelect<String>),
        )
        .toList();
    expect(fields, hasLength(2));
    expect(fields.first.options.map((item) => item.$1), [
      'subscription:lua',
      'script:both',
    ]);
    expect(fields.last.options.map((item) => item.$1), [
      '',
      'script:both',
      'script:manifest',
    ]);
    final preview = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Preview content'),
    );
    expect(preview.onPressed, isNull);
    expect(tasks.tasks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global import selection is restored in the dialog', (
    tester,
  ) async {
    await tester.runAsync(
      () => registry.rememberImportSelection(
        const ContentImportSelection(
          luaSourceId: 'script:both',
          manifestSourceId: 'script:both',
          manifestExplicit: true,
        ),
      ),
    );
    await mount(tester);

    final fields = tester
        .widgetList<ui.FormRowSelect<String>>(
          find.byType(ui.FormRowSelect<String>),
        )
        .toList();
    expect(fields.first.value, 'script:both');
    expect(fields.last.value, 'script:both');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dual capability source defaults to itself but manifest selection can be cleared',
    (tester) async {
      await mount(tester);
      final lua = find.byKey(const ValueKey('content-import-lua-source'));
      await tester.tap(lua);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Both provider').last);
      await tester.pumpAndSettle();
      var fields = tester
          .widgetList<ui.FormRowSelect<String>>(
            find.byType(ui.FormRowSelect<String>),
          )
          .toList();
      expect(fields.first.value, 'script:both');
      expect(fields.last.value, 'script:both');
      await tester.tap(
        find.byKey(const ValueKey('content-import-manifest-source')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('None; let Steam or the kernel retrieve manifests').last,
      );
      await tester.pumpAndSettle();
      fields = tester
          .widgetList<ui.FormRowSelect<String>>(
            find.byType(ui.FormRowSelect<String>),
          )
          .toList();
      expect(fields.last.value, '');
      expect(tasks.tasks, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> mountLocal(
    WidgetTester tester, {
    bool cancelSecond = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: Scaffold(
          body: LocalContentImportDialog(
            resolver: _LocalResolver(registry, cancelSecond: cancelSecond),
            importer: _FailingImporter(library),
            tasks: tasks,
            paths: const ['fixture.zip'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cancelled local preparation clears previously prepared games', (
    tester,
  ) async {
    await mountLocal(tester, cancelSecond: true);
    expect(find.text('AppID 10'), findsNothing);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Import'),
    );
    expect(button.onPressed, isNull);
    expect(tasks.tasks.single.status, TaskStatus.cancelled);
  });

  testWidgets(
    'per-game commit failures retain details and fail the global task',
    (tester) async {
      await mountLocal(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Import'));
      await tester.pumpAndSettle();
      expect(tasks.tasks.first.status, TaskStatus.failed);
      expect(find.byType(LocalContentImportDialog), findsOneWidget);
      expect(
        find.textContaining('Fixture commit failure'),
        findsAtLeastNWidgets(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
