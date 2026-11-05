import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/cloud/cloud_page.dart';
import 'package:fl_steam_lua/features/cloud/cloud_storage_form.dart';
import 'package:fl_steam_lua/features/cloud/cloud_service.dart';
import 'package:fl_steam_lua/features/content_sources/content_import_dialog.dart';
import 'package:fl_steam_lua/features/content_sources/content_import_service.dart';
import 'package:fl_steam_lua/features/content_sources/content_resolver.dart';
import 'package:fl_steam_lua/features/content_sources/content_source_registry.dart';
import 'package:fl_steam_lua/features/content_sources/content_sources_page.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/lua_directories.dart';
import 'package:fl_steam_lua/features/library/lua_directories_page.dart';
import 'package:fl_steam_lua/features/manifests/manifest_source_service.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Scripts extends ManifestSourceService {
  _Scripts({required super.paths});
  @override
  bool supportsTest(String sourceId) => true;
}

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
      id: 'script:fixture',
      name: 'Fixture source',
      kind: ContentSourceKind.script,
      capabilities: {ContentCapability.lua},
    ),
  ];
  @override
  Future<ContentSourceTestResult> testSource(
    String id, {
    TaskContext? task,
  }) async => const ContentSourceTestResult(
    success: false,
    message: 'Fixture rejected credentials',
  );
}

class _Resolver extends ContentResolver {
  _Resolver(super.registry);
  @override
  Future<ContentBundle> resolve(
    int appId,
    ContentPlan plan, {
    bool pinManifests = false,
    bool refreshMetadata = true,
    TaskContext? task,
  }) async => ContentBundle(
    appId: appId,
    lua: ContentArtifact(
      filename: '$appId.lua',
      bytes: Uint8List.fromList('addappid($appId)'.codeUnits),
      capability: ContentCapability.lua,
    ),
  );
}

class _Importer extends ContentImportService {
  _Importer({required super.library});
  bool? lastOverwrite;
  @override
  Future<ContentImportPreview> preview(ContentBundle bundle) async =>
      ContentImportPreview(
        bundle: bundle,
        entries: [
          ContentImportEntry(
            path: 'fixture/440.lua',
            artifact: bundle.lua!,
            exists: true,
          ),
        ],
      );
  @override
  Future<ContentImportResult> commit(
    ContentImportPreview preview, {
    bool overwrite = false,
    TaskContext? task,
  }) async {
    lastOverwrite = overwrite;
    return ContentImportResult(
      written: ['fixture/440.lua'],
      skipped: [],
      backups: {},
      wroteLua: true,
    );
  }
}

class _Cloud extends CloudService {
  _Cloud({
    required super.paths,
    required super.settings,
    CredentialCodec? codec,
  }) : super(
         configDirectory: p.join(paths.root, 'cloud'),
         credentialCodec: codec,
         processReader: () async => [],
       );
  bool reject = true;
  int writes = 0;
  Map<String, dynamic>? saved;
  List<CloudBackup> backupFixtures = [];
  int restores = 0;
  @override
  Future<List<CloudBackup>> backups({int? appId}) async => backupFixtures;
  @override
  Future<void> restore(CloudBackup backup, {TaskContext? context}) async {
    restores++;
  }

  @override
  Future<void> refresh({
    int? appId,
    TaskContext? context,
    bool includeRemote = true,
  }) async {}
  @override
  Future<Map<String, dynamic>?> providerConfiguration(String selected) async =>
      null;
  @override
  Future<void> configureProvider(
    String selected,
    Map<String, dynamic> values,
  ) async {
    writes++;
    if (reject) throw const FileSystemException('Fixture write failure');
    saved = values;
  }
}

void main() {
  late Directory root;
  late AppPaths paths;
  late SettingsStore settings;
  late TaskCenter tasks;
  late _Scripts scripts;
  late KeyCacheService cache;
  late _Registry registry;
  late LibraryService library;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('usability-');
    paths = AppPaths(root.path);
    settings = SettingsStore(paths);
    tasks = TaskCenter();
    scripts = _Scripts(paths: paths);
    cache = KeyCacheService(paths: paths, settings: settings);
    registry = _Registry(
      manifests: scripts,
      keyCache: cache,
      settings: settings,
    );
    library = LibraryService(paths: paths, settings: settings);
  });
  tearDown(() async {
    registry.dispose();
    scripts.dispose();
    cache.dispose();
    library.dispose();
    settings.dispose();
    tasks.dispose();
    await root.delete(recursive: true);
  });

  Future<void> mount(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: ui.StatusManager(child: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a rejected source test fails its task and never reports success',
    (tester) async {
      await mount(tester, ContentSourcesPage(registry: registry, tasks: tasks));
      final region = tester.widget<ui.ContextMenuRegion>(
        find.byType(ui.ContextMenuRegion).first,
      );
      region.menuItems!.firstWhere((item) => item.label == 'Test').onPressed!();
      await tester.pumpAndSettle();
      expect(tasks.tasks.single.status, TaskStatus.failed);
      expect(find.text('Fixture source passed the test.'), findsNothing);
      expect(find.textContaining('could not finish'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sole ready source is selected and replacement preview tracks the switch',
    (tester) async {
      final importer = _Importer(library: library);
      await mount(
        tester,
        Scaffold(
          body: ContentImportDialog(
            registry: registry,
            resolver: _Resolver(registry),
            importer: importer,
            tasks: tasks,
            appId: 440,
            gameName: 'Fixture game',
          ),
        ),
      );
      expect(
        tester
            .widget<ui.FormRowSelect<String>>(
              find.byKey(const ValueKey('content-import-lua-source')),
            )
            .value,
        'script:fixture',
      );
      tester.widget<ui.FormPage>(find.byType(ui.FormPage)).onSave();
      await tester.pumpAndSettle();
      expect(
        find.text('File exists; confirm backup and replacement'),
        findsOneWidget,
      );
      expect(
        tester.widget<ui.FormPage>(find.byType(ui.FormPage)).canSave,
        isFalse,
      );
      final replacement = tester.widget<ui.FormRowSwitch>(
        find.byKey(const ValueKey('content-import-replace')),
      );
      replacement.onChanged!(true);
      await tester.pumpAndSettle();
      expect(find.text('Will be backed up and replaced'), findsOneWidget);
      expect(
        find.text('File exists; confirm backup and replacement'),
        findsNothing,
      );
      expect(
        tester.widget<ui.FormPage>(find.byType(ui.FormPage)).canSave,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cloud form validates requirements, switches credential fields and retains failed input',
    (tester) async {
      var writes = 0;
      var reject = true;
      final cloud = _Cloud(
        paths: paths,
        settings: settings,
        codec: CredentialCodec(
          protect: (bytes) {
            writes++;
            if (reject) {
              throw const FileSystemException('Fixture write failure');
            }
            return bytes;
          },
          unprotect: (bytes) => bytes,
        ),
      );
      addTearDown(cloud.dispose);
      await mount(
        tester,
        Builder(
          builder: (context) => ui.TonalButton(
            label: 'Open form',
            onPressed: () => ui.showFormSheet(
              context: context,
              builder: (_) => CloudStorageForm(
                service: cloud,
                initialProvider: 'folder',
                initialValues: const {},
                initialName: 'Fixture',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      tester
          .widget<ui.FormRowSelect<String>>(
            find.byType(ui.FormRowSelect<String>).first,
          )
          .onChanged!('webdav');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cloud-field-bearer_token')),
        findsNothing,
      );
      await tester.runAsync(() async {
        tester.widget<ui.FormPage>(find.byType(ui.FormPage)).onSave();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.textContaining('required fields'), findsOneWidget);

      Future<void> fill(String field, String value) async {
        final input = find.descendant(
          of: find.byKey(ValueKey('cloud-field-$field')),
          matching: find.byType(TextFormField),
        );
        await tester.ensureVisible(input);
        await tester.enterText(input, value);
      }

      await fill('url', 'https://fixture.test/dav/');
      final auth = tester
          .widgetList<ui.FormRowSelect<String>>(
            find.byType(ui.FormRowSelect<String>),
          )
          .firstWhere((field) => field.value == 'basic');
      auth.onChanged!('bearer');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cloud-field-username')), findsNothing);
      await fill('bearer_token', 'fixture-token');
      await tester.runAsync(() async {
        tester.widget<ui.FormPage>(find.byType(ui.FormPage)).onSave();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byType(ui.FormPage), findsOneWidget);
      expect(find.text('https://fixture.test/dav/'), findsOneWidget);
      expect(find.textContaining('Check folder permissions'), findsWidgets);
      reject = false;
      await tester.runAsync(() async {
        tester.widget<ui.FormPage>(find.byType(ui.FormPage)).onSave();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(ui.FormPage), findsNothing);
      final stored = await tester.runAsync(
        () => cloud.storageValues(cloud.savedStorageProfiles.single.id),
      );
      expect(stored?['bearer_token'], 'fixture-token');
      expect(stored?['username'], '');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'editing a Lua directory persists once without a second page save',
    (tester) async {
      final steam = p.join(root.path, 'Steam');
      final a = p.join(root.path, 'a');
      final b = p.join(root.path, 'b');
      await tester.runAsync(() async {
        await Directory(steam).create();
        await LuaDirectories(steam).save([a]);
      });
      var refreshes = 0;
      await mount(
        tester,
        LuaDirectoriesPage(
          steamPath: steam,
          onSaved: () async {
            refreshes++;
          },
        ),
      );
      expect(find.byKey(const ValueKey('save-lua-directories')), findsNothing);
      await tester.tap(find.text(a));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('lua-directory-input')),
          matching: find.byType(TextFormField),
        ),
        b,
      );
      await tester.runAsync(() async {
        tester.widget<ui.FormPage>(find.byType(ui.FormPage)).onSave();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(LuaDirectories(steam).customPaths(), [b]);
      expect(refreshes, 1);
      expect(find.byType(ui.FormPage), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'backup selection identifies account and source before confirming the current target',
    (tester) async {
      final cloud = _Cloud(paths: paths, settings: settings);
      addTearDown(cloud.dispose);
      cloud.backupFixtures = [
        CloudBackup(
          path: p.join(root.path, 'backups', 'fixture'),
          appId: 440,
          createdAt: DateTime(2026, 11, 5),
          fileCount: 1,
          size: 123,
          locations: const [
            CloudBackupLocation(
              kind: 'sync',
              accountId: '76561190000000001',
              sourcePath: 'D:/old-folder',
            ),
          ],
        ),
      ];
      await mount(tester, CloudPage(service: cloud));
      await tester.tap(find.byTooltip('Save backups'));
      await tester.pumpAndSettle();
      expect(find.textContaining('76561190000000001'), findsOneWidget);
      await tester.tap(find.textContaining('2026-11-05').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('D:/old-folder'), findsOneWidget);
      await tester.tap(find.text('Restore backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('D:/old-folder'), findsWidgets);
      expect(cloud.restores, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cloud.restores, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('backup listing retains stored account and source metadata', () async {
    final cloud = CloudService(
      paths: paths,
      settings: settings,
      configDirectory: p.join(root.path, 'config'),
    );
    try {
      await cloud.setSyncPath(p.join(root.path, 'saves'));
      final file = File(p.join(cloud.syncPath, '123', '440', 'slot.dat'));
      await file.parent.create(recursive: true);
      await file.writeAsString('fixture save');
      await cloud.refresh();
      final backup = await cloud.backup(440, selection: cloud.saves.single);
      final reloaded = (await cloud.backups()).single;
      expect(reloaded.provider, 'folder');
      expect(reloaded.locations.single.accountId, '123');
      expect(reloaded.locations.single.kind, 'sync');
      expect(reloaded.locations.single.sourcePath, file.parent.path);
      expect(cloud.restoreLocations(reloaded).single.path, file.parent.path);
      expect(
        backup.locations.single.accountId,
        reloaded.locations.single.accountId,
      );
    } finally {
      cloud.dispose();
    }
  });
}
