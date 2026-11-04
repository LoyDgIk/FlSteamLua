import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/dlc_analysis/dlc_analysis_service.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/steam_protocol/app_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

SteamAppInfo app(
  int id, {
  List<int> dlcs = const [],
  List<SteamDepotInfo> depots = const [],
}) => SteamAppInfo(
  appId: id,
  name: 'Game $id',
  depots: depots,
  dlcAppIds: dlcs,
  data: const {},
);

SteamDepotInfo depot(int id, int appId, {int? dlcId}) =>
    SteamDepotInfo(depotId: id, appId: appId, dlcAppId: dlcId);

void main() {
  late Directory temporary;
  late AppPaths paths;
  late SettingsStore settings;
  final keyA = List.filled(64, 'a').join();
  final keyB = List.filled(64, 'b').join();

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('fl-dlc-analysis-');
    paths = AppPaths(p.join(temporary.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
  });

  tearDown(() async {
    settings.dispose();
    await temporary.delete(recursive: true);
  });

  test(
    'classifies metadata, compares Lua and does not confuse failure with no depots',
    () async {
      final lua = File(p.join(temporary.path, '100.lua'));
      await lua.writeAsString(
        '-- addappid(201)\n'
        '--[=[\naddappid(204)\n]=]\n'
        'addappid(100)\n'
        'addappid(202)\n'
        'addappid(2030, 1, "$keyA")\n'
        'setManifestid(204,"12345678901234567",0)\n',
      );
      final data = <int, SteamAppInfo>{
        100: app(
          100,
          dlcs: [201, 202, 203, 204, 205, 206, 202],
          depots: [depot(1000, 100, dlcId: 204)],
        ),
        201: app(201),
        202: app(202, depots: [depot(2020, 202)]),
        203: app(203, depots: [depot(2030, 203), depot(2031, 203)]),
        204: app(204, depots: [depot(1000, 204)]),
        206: app(206, depots: [depot(2060, 206)]),
      };
      final service = DlcAnalysisService(
        paths: paths,
        settings: settings,
        queryApp: (id) async =>
            data[id] ?? (throw StateError('fixture offline')),
        readCache: (_) async => KeyCacheData(
          depotKeys: {2020: keyA, 2031: keyB},
          appTokens: {201: '123456789'},
        ),
      );
      addTearDown(service.dispose);
      final result = await service.analyze(
        100,
        sourceId: 'fixture',
        luaPath: lua.path,
      );
      expect(result.items.map((item) => item.kind), [
        DlcDepotKind.noDepot,
        DlcDepotKind.singleDepot,
        DlcDepotKind.multiDepot,
        DlcDepotKind.inMainDepot,
        DlcDepotKind.unknown,
        DlcDepotKind.singleDepot,
      ]);
      expect(result.items.first.isConfigured, isFalse);
      expect(result.items[1].isConfigured, isTrue);
      expect(result.items[4].error, contains('fixture offline'));
      expect(result.items[4].suggestions, isEmpty);
      expect(result.items[5].missingKeys, [2060]);
      expect(result.items[5].suggestions, isEmpty);
      expect(
        result.preview({201}),
        'addappid(201)\naddtoken(201, "123456789")',
      );
      expect(result.preview({202}), 'addappid(2020, 1, "$keyA")');
      expect(
        result.preview({203}),
        'addappid(2031, 1, "$keyB")\naddappid(203)',
      );
      expect(result.preview({204}), 'addappid(204)');
      expect(result.warnings.single, contains('queries failed'));
    },
  );

  test(
    'only selected additions append and original bytes, manifest pins and backup survive',
    () async {
      final lua = File(p.join(temporary.path, '100.lua'));
      const original =
          '-- 用户脚本\r\naddappid(100)\r\nsetManifestid(1000,"888",0)\r\ncustomFunction()';
      final originalBytes = [0xef, 0xbb, 0xbf, ...utf8.encode(original)];
      await lua.writeAsBytes(originalBytes);
      final service = DlcAnalysisService(
        paths: paths,
        settings: settings,
        queryApp: (id) async =>
            id == 100 ? app(100, dlcs: [201, 202]) : app(id),
        readCache: (_) async => const KeyCacheData(),
      );
      addTearDown(service.dispose);
      final result = await service.analyze(
        100,
        sourceId: 'fixture',
        luaPath: lua.path,
      );
      expect(await service.apply(result, {201}), 1);
      final written = await lua.readAsBytes();
      expect(written.take(originalBytes.length).toList(), originalBytes);
      final text = utf8.decode(written);
      expect(
        text,
        contains(
          'customFunction()\r\n-- FlSteamLua DLC additions\r\naddappid(201)\r\n',
        ),
      );
      expect(text, isNot(contains('addappid(202)')));
      expect(text, contains('setManifestid(1000,"888",0)'));
      final backups = await paths
          .directory('backups/lua')
          .list()
          .where((file) => file is File)
          .toList();
      expect(backups, hasLength(1));
      expect(await File(backups.single.path).readAsBytes(), originalBytes);
      await expectLater(service.apply(result, {202}), throwsStateError);
      expect(await lua.readAsBytes(), written);
    },
  );

  test(
    'rejects edits after preview and leaves the changed script untouched',
    () async {
      final lua = File(p.join(temporary.path, '100.lua'));
      await lua.writeAsString('addappid(100)\n');
      final service = DlcAnalysisService(
        paths: paths,
        settings: settings,
        queryApp: (id) async => id == 100 ? app(100, dlcs: [201]) : app(id),
        readCache: (_) async => const KeyCacheData(),
      );
      addTearDown(service.dispose);
      final result = await service.analyze(
        100,
        sourceId: 'fixture',
        luaPath: lua.path,
      );
      await lua.writeAsString('user changed this\n');
      await expectLater(service.apply(result, {201}), throwsStateError);
      expect(await lua.readAsString(), 'user changed this\n');
      expect(await paths.directory('backups/lua').exists(), isFalse);
    },
  );

  test(
    'missing Lua allows preview, blocks apply, and cache failure remains visible',
    () async {
      final service = DlcAnalysisService(
        paths: paths,
        settings: settings,
        queryApp: (id) async => id == 100 ? app(100, dlcs: [201]) : app(id),
        readCache: (_) async => throw const FormatException('cache is invalid'),
      );
      addTearDown(service.dispose);
      final result = await service.analyze(100, sourceId: 'fixture');
      expect(result.luaPath, isNull);
      expect(result.preview({201}), 'addappid(201)');
      expect(result.warnings.join(' '), contains('cache is invalid'));
      await expectLater(service.apply(result, {201}), throwsStateError);
    },
  );

  test(
    'source query error propagates rather than showing an empty successful analysis',
    () async {
      final service = DlcAnalysisService(
        paths: paths,
        settings: settings,
        queryApp: (id) async => throw const SocketException('fixture offline'),
        readCache: (_) async => const KeyCacheData(),
      );
      addTearDown(service.dispose);
      await expectLater(service.analyze(100), throwsA(isA<SocketException>()));
      await expectLater(service.analyze(0), throwsFormatException);
      await expectLater(
        service.analyze(100, luaPath: p.join(temporary.path, 'missing.lua')),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('overlapping child depots emit one selected key line', () async {
    final service = DlcAnalysisService(
      paths: paths,
      settings: settings,
      queryApp: (id) async => id == 100
          ? app(100, dlcs: [201, 202])
          : app(id, depots: [depot(3000, id)]),
      readCache: (_) async => KeyCacheData(depotKeys: {3000: keyA}),
    );
    addTearDown(service.dispose);
    final result = await service.analyze(100, sourceId: 'fixture');
    expect(
      'addappid(3000'.allMatches(result.preview({201, 202})),
      hasLength(1),
    );
    expect(result.preview({201}), isNot(contains('addappid(202)')));
  });

  test('uses only the source selected for this analysis', () async {
    final requestedSources = <String>[];
    final service = DlcAnalysisService(
      paths: paths,
      settings: settings,
      queryApp: (id) async => id == 100
          ? app(100, dlcs: [201])
          : app(id, depots: [depot(3000, id)]),
      readCache: (sourceId) async {
        requestedSources.add(sourceId);
        return KeyCacheData(
          depotKeys: {3000: sourceId == 'first' ? keyA : keyB},
        );
      },
    );
    addTearDown(service.dispose);

    final first = await service.analyze(100, sourceId: 'first');
    final second = await service.analyze(100, sourceId: 'second');
    final withoutSource = await service.analyze(100);

    expect(requestedSources, ['first', 'second']);
    expect(first.preview({201}), contains('"$keyA"'));
    expect(second.preview({201}), contains('"$keyB"'));
    expect(withoutSource.items.single.missingKeys, [3000]);
    expect(withoutSource.items.single.suggestions, isEmpty);
  });

  test('finds an existing Lua in the Steam plugin directory', () async {
    final steam = Directory(p.join(temporary.path, 'Steam'));
    final lua = File(p.join(steam.path, 'config', 'stplug-in', '100.lua'));
    await lua.parent.create(recursive: true);
    await lua.writeAsString('addappid(100)\n');
    await settings.set('steamPath', steam.path);
    final service = DlcAnalysisService(
      paths: paths,
      settings: settings,
      queryApp: (id) async => app(id),
      readCache: (_) async => throw StateError('No source was selected'),
    );
    addTearDown(service.dispose);

    final result = await service.analyze(100);

    expect(result.luaPath, lua.path);
    expect(result.warnings, isEmpty);
  });
}
