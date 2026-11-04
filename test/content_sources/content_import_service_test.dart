import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_import_service.dart';
import 'package:fl_steam_lua/features/content_sources/content_models.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/steam_protocol/manifest/depot_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Library extends LibraryService {
  _Library({
    required super.paths,
    required super.settings,
    required this.steam,
    required this.lua,
  });
  final String steam;
  final String lua;
  int scans = 0;
  List<GameEntry> entries = [];
  Future<void> Function()? onScan;

  @override
  List<GameEntry> get games => List.unmodifiable(entries);

  @override
  Future<({String steam, String lua})> contentDirectories() async =>
      (steam: steam, lua: lua);

  @override
  Future<void> scan({TaskContext? context}) async {
    scans++;
    await onScan?.call();
  }
}

void main() {
  late Directory directory;
  late _Library library;
  late SettingsStore settings;
  late ContentImportService importer;

  ContentBundle bundle({bool withManifest = true}) => ContentBundle(
    appId: 440,
    lua: ContentArtifact(
      filename: '440.lua',
      bytes: utf8.encode('addappid(440)\n'),
      capability: ContentCapability.lua,
      sourceId: 'subscription:test',
    ),
    manifestFiles: [
      if (withManifest)
        ContentArtifact(
          filename: '441_123.manifest',
          bytes: DepotManifest(
            depotId: 441,
            manifestGid: BigInt.from(123),
            files: [],
          ).toBytes(),
          capability: ContentCapability.manifestFiles,
          sourceId: 'script:test',
          depotId: 441,
          manifestId: '123',
        ),
    ],
  );

  Future<File> write(String path, String value) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return file.writeAsString(value);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('content-import-');
    final paths = AppPaths(p.join(directory.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    library = _Library(
      paths: paths,
      settings: settings,
      steam: p.join(directory.path, 'Steam'),
      lua: p.join(directory.path, 'Lua'),
    );
    importer = ContentImportService(library: library);
  });

  tearDown(() async {
    library.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'preview is read-only and successful commit writes targets then scans once',
    () async {
      final preview = await importer.preview(bundle());
      expect(preview.entries, hasLength(2));
      expect(preview.hasConflicts, isFalse);
      expect(await File(p.join(library.lua, '440.lua')).exists(), isFalse);
      expect(library.scans, 0);

      final result = await importer.commit(preview);
      expect(result.written, hasLength(2));
      expect(result.skipped, isEmpty);
      expect(result.wroteLua, isTrue);
      expect(
        await File(p.join(library.lua, '440.lua')).readAsString(),
        contains('addappid(440)'),
      );
      expect(
        DepotManifest.parse(
          await File(
            p.join(library.steam, 'depotcache', '441_123.manifest'),
          ).readAsBytes(),
        ).depotId,
        441,
      );
      expect(library.scans, 1);
    },
  );

  test('conflict without overwrite skips the entire bundle', () async {
    final previous = await write(p.join(library.lua, '440.lua'), 'old Lua');
    final preview = await importer.preview(bundle());
    expect(preview.hasConflicts, isTrue);
    final result = await importer.commit(preview);
    expect(result.written, isEmpty);
    expect(result.wroteLua, isFalse);
    expect(result.skipped, hasLength(2));
    expect(await previous.readAsString(), 'old Lua');
    expect(
      await File(
        p.join(library.steam, 'depotcache', '441_123.manifest'),
      ).exists(),
      isFalse,
    );
    expect(library.scans, 0);
  });

  test('overwrite retains a backup of each previous target', () async {
    final oldLua = await write(p.join(library.lua, '440.lua'), 'old Lua');
    final oldManifest = await write(
      p.join(library.steam, 'depotcache', '441_123.manifest'),
      'old manifest',
    );
    final result = await importer.commit(
      await importer.preview(bundle()),
      overwrite: true,
    );
    expect(result.backups.keys, containsAll([oldLua.path, oldManifest.path]));
    expect(await File(result.backups[oldLua.path]!).readAsString(), 'old Lua');
    expect(
      await File(result.backups[oldManifest.path]!).readAsString(),
      'old manifest',
    );
    expect(result.wroteLua, isTrue);
    expect(library.scans, 1);
  });

  test(
    'failure during the second write restores previously replaced targets',
    () async {
      final oldLua = await write(p.join(library.lua, '440.lua'), 'old Lua');
      final oldManifest = await write(
        p.join(library.steam, 'depotcache', '441_123.manifest'),
        'old manifest',
      );
      var writes = 0;
      importer = ContentImportService(
        library: library,
        fileWriter: (file, bytes) async {
          writes++;
          if (writes == 2) {
            throw const FileSystemException('simulated second write failure');
          }
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
        },
      );
      await expectLater(
        importer.commit(await importer.preview(bundle()), overwrite: true),
        throwsA(isA<Exception>()),
      );
      expect(await oldLua.readAsString(), 'old Lua');
      expect(await oldManifest.readAsString(), 'old manifest');
      expect(library.scans, 0);
    },
  );

  test('cancelled preparation creates no target files', () async {
    final progress = TaskProgress('cancelled', 'Import')
      ..cancellationRequested = true;
    final task = TaskContext(progress, () {});
    await expectLater(
      importer.commit(await importer.preview(bundle()), task: task),
      throwsA(isA<TaskCancelled>()),
    );
    expect(await File(p.join(library.lua, '440.lua')).exists(), isFalse);
    expect(
      await File(
        p.join(library.steam, 'depotcache', '441_123.manifest'),
      ).exists(),
      isFalse,
    );
    expect(library.scans, 0);
  });

  test(
    'changed target after preview is preserved and requires a new preview',
    () async {
      final target = await write(
        p.join(library.lua, '440.lua'),
        'before preview',
      );
      final preview = await importer.preview(bundle());
      await target.writeAsString('external edit after preview');
      await expectLater(
        importer.commit(preview, overwrite: true),
        throwsA(isA<Exception>()),
      );
      expect(await target.readAsString(), 'external edit after preview');
      expect(
        await File(
          p.join(library.steam, 'depotcache', '441_123.manifest'),
        ).exists(),
        isFalse,
      );
      expect(library.scans, 0);
    },
  );

  test(
    'failure after creating a new target removes the incomplete import',
    () async {
      var writes = 0;
      importer = ContentImportService(
        library: library,
        fileWriter: (file, bytes) async {
          writes++;
          await file.writeAsBytes(bytes.take(4).toList(), flush: true);
          if (writes == 2) throw const FileSystemException('partial write');
          await file.writeAsBytes(bytes, flush: true);
        },
      );
      await expectLater(
        importer.commit(await importer.preview(bundle())),
        throwsA(isA<Exception>()),
      );
      expect(await File(p.join(library.lua, '440.lua')).exists(), isFalse);
      expect(
        await File(
          p.join(library.steam, 'depotcache', '441_123.manifest'),
        ).exists(),
        isFalse,
      );
      expect(library.scans, 0);
    },
  );

  test(
    'cancellation after committing starts waits for a complete transaction',
    () async {
      final progress = TaskProgress('during-commit', 'Import');
      final task = TaskContext(progress, () {});
      var writes = 0;
      importer = ContentImportService(
        library: library,
        fileWriter: (file, bytes) async {
          await file.writeAsBytes(bytes, flush: true);
          writes++;
          if (writes == 1) progress.cancellationRequested = true;
        },
      );
      final result = await importer.commit(
        await importer.preview(bundle()),
        task: task,
      );
      expect(result.written, hasLength(2));
      expect(result.wroteLua, isTrue);
      expect(library.scans, 1);
    },
  );

  test(
    'replacing disabled nested Lua preserves its path and disabled state',
    () async {
      final disabledPath = p.join(
        library.lua,
        'Disable',
        'collection',
        '440.lua',
      );
      final previous = await write(
        disabledPath,
        'addappid(440) -- old disabled',
      );
      library.entries = [
        GameEntry(
          appId: 440,
          name: 'Disabled game',
          luaPath: disabledPath,
          luaEnabled: false,
        ),
      ];

      final preview = await importer.preview(bundle(withManifest: false));
      expect(preview.entries.single.path, disabledPath);
      expect(preview.hasConflicts, isTrue);
      final result = await importer.commit(preview, overwrite: true);

      expect(result.written, [disabledPath]);
      expect(await previous.readAsString(), 'addappid(440)\n');
      expect(await File(p.join(library.lua, '440.lua')).exists(), isFalse);
      expect(library.games.single.luaPath, disabledPath);
      expect(library.games.single.luaEnabled, isFalse);
      expect(library.scans, 1);
    },
  );

  test(
    'a scan failure rolls files back and rescans to restore catalogue state',
    () async {
      final oldLua = await write(
        p.join(library.lua, '440.lua'),
        'addappid(440) -- original',
      );
      library.entries = [
        GameEntry(appId: 440, name: 'Original game', luaPath: oldLua.path),
      ];
      var storedGame = await oldLua.readAsString();
      final observed = <String>[];
      library.onScan = () async {
        storedGame = await oldLua.readAsString();
        observed.add(storedGame);
        library.entries = [
          GameEntry(appId: 440, name: storedGame, luaPath: oldLua.path),
        ];
        if (library.scans == 1) {
          throw const FileSystemException('scan failed after catalogue update');
        }
      };

      await expectLater(
        importer.commit(
          await importer.preview(bundle(withManifest: false)),
          overwrite: true,
        ),
        throwsA(isA<ContentImportException>()),
      );

      expect(observed, ['addappid(440)\n', 'addappid(440) -- original']);
      expect(await oldLua.readAsString(), 'addappid(440) -- original');
      expect(storedGame, 'addappid(440) -- original');
      expect(library.games.single.name, 'addappid(440) -- original');
      expect(library.scans, 2);
    },
  );
}
