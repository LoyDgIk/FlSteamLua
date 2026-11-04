import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:fl_steam_lua/features/tools/lua_vdf_converter.dart';
import 'package:fl_steam_lua/features/tools/tools_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late AppPaths paths;
  late SettingsStore settings;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsteam-tools-');
    paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
  });
  tearDown(() async => temp.delete(recursive: true));

  test('conversion roundtrip retains keys and optional manifest IDs', () {
    final converter = LuaVdfConverter();
    const lua =
        '-- addappid(999,1,"COMMENT")\naddappid(50)\n'
        'addappid(71, 1, "KEY-A")\naddappid(72,1,"KEY-B")\n'
        'setManifestid(71,"99988877766554433",0)\n';
    final vdf = converter.luaToVdf(lua, 50);
    final root = Kv1.parse(vdf);
    expect((root['AppState'] as Map)['appid'], '50');
    final back = converter.vdfToLua(vdf, includeManifestIds: true);
    expect(back, contains('addappid(71, 1, "KEY-A")'));
    expect(back, contains('setManifestid(71, "99988877766554433", 0)'));
    expect(back, isNot(contains('999, 1')));
    expect(converter.vdfToLua(vdf), isNot(contains('setManifestid')));
  });

  test('batch conversion does not overwrite existing files', () async {
    final source = File(p.join(temp.path, '50.lua'));
    await source.writeAsString('addappid(50)\naddappid(71,1,"KEY")');
    final output = Directory(p.join(temp.path, 'out'));
    await output.create();
    final target = File(p.join(output.path, '50.vdf'));
    await target.writeAsString('keep');
    final result = await LuaVdfConverter().convertFiles([
      source.path,
    ], outputDirectory: output.path);
    expect(result.single.succeeded, false);
    expect(await target.readAsString(), 'keep');
  });

  test(
    'pin updates remove duplicates, unpin keeps records and backup',
    () async {
      final lua = File(p.join(temp.path, '50.lua'));
      await lua.writeAsString(
        'addappid(50)\naddappid(71,1,"KEY")\n'
        '--setManifestid(71,"123",0)\nsetManifestid(71,"124",0)\n-- keep me\n',
      );
      final service = ToolsService(paths: paths, settings: settings);
      addTearDown(service.dispose);
      final game = GameEntry(appId: 50, name: 'Fixture', luaPath: lua.path);
      await service.pinManifests(game, {71: '55500011122233344', 72: '567'});
      final pinned = await lua.readAsString();
      expect('setManifestid(71,'.allMatches(pinned).length, 1);
      expect(pinned, contains('setManifestid(71,"55500011122233344",0)'));
      expect(pinned, contains('-- keep me'));
      await service.unpinManifests(game);
      expect(await lua.readAsString(), contains('--setManifestid(71,'));
      expect(await paths.directory('backups/lua').list().length, 2);
    },
  );

  test('DLC addition is idempotent and refuses removal of base game', () async {
    final lua = File(p.join(temp.path, '50.lua'));
    await lua.writeAsString(
      'addappid(50)\naddappid(51)\naddappid(71,1,"KEY")\n',
    );
    final game = GameEntry(appId: 50, name: 'Fixture', luaPath: lua.path);
    final service = ToolsService(paths: paths, settings: settings);
    addTearDown(service.dispose);
    expect(await service.addDlc(game, [51, 52, 52]), 1);
    expect(await service.addDlc(game, [52]), 0);
    await expectLater(service.removeDlc(game, [50]), throwsFormatException);
    await service.removeDlc(game, [52]);
    final text = await lua.readAsString();
    expect(text, isNot(contains('addappid(52)')));
    expect(text, contains('addappid(71,1,"KEY")'));
  });

  test('installed manifests supports both ACF depot layouts', () async {
    final steamapps = Directory(p.join(temp.path, 'library', 'steamapps'));
    await steamapps.create(recursive: true);
    await File(p.join(steamapps.path, 'appmanifest_50.acf')).writeAsString(
      '"AppState" { "appid" "50" "InstalledDepots" { "71" { "manifest" "99900011122233344" } } '
      '"MountedDepots" { "72" "777888999" } }',
    );
    final service = ToolsService(paths: paths, settings: settings);
    addTearDown(service.dispose);
    final result = await service.installedManifests(
      GameEntry(
        appId: 50,
        name: 'Fixture',
        libraryPath: p.dirname(steamapps.path),
      ),
    );
    expect(result, {71: '99900011122233344', 72: '777888999'});
  });

  test(
    'latest manifests checks endpoint response and keeps large GIDs as text',
    () async {
      final service = ToolsService(
        paths: paths,
        settings: settings,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/info/50');
          return http.Response(
            jsonEncode({
              'data': {
                '50': {
                  'depots': {
                    '71': {
                      'manifests': {
                        'public': {'gid': '99900011122233344'},
                      },
                    },
                  },
                },
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      expect(await service.latestManifests(50, [71, 72]), {
        71: '99900011122233344',
      });
    },
  );
}
