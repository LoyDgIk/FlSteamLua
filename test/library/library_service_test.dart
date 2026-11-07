import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory fixture;
  late Directory steam;
  late AppPaths paths;
  late SettingsStore settings;
  late LibraryService library;
  final opened = <Uri>[];

  Future<File> write(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  Future<void> manifest(
    String root,
    int appId,
    String name, {
    bool installed = true,
  }) async {
    await write(
      p.join(root, 'steamapps', 'appmanifest_$appId.acf'),
      Kv1.stringify({
        'AppState': {
          'appid': '$appId',
          'name': name,
          'installdir': 'game-$appId',
          'StateFlags': installed ? '4' : '1024',
          'SizeOnDisk': '123456',
          'LastPlayed': '1700000000',
        },
      }),
    );
    if (installed) {
      await Directory(
        p.join(root, 'steamapps', 'common', 'game-$appId'),
      ).create(recursive: true);
    }
  }

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('flsteamlua-library-');
    steam = await Directory(p.join(fixture.path, 'Steam')).create();
    paths = AppPaths(p.join(fixture.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    await settings.set('steamPath', steam.path);
    opened.clear();
    library = LibraryService(
      paths: paths,
      settings: settings,
      processRunner: (command, args) async => ProcessResult(1, 0, <int>[], ''),
      uriOpener: (uri) async {
        opened.add(uri);
        return true;
      },
    );
  });

  tearDown(() async {
    library.dispose();
    settings.dispose();
    await fixture.delete(recursive: true);
  });

  test(
    'reads current Steam account playtime for installed and Lua games',
    () async {
      await manifest(steam.path, 10, 'Installed Game');
      await write(
        p.join(steam.path, 'config', 'lua', '20.lua'),
        'addappid(20)',
      );
      await write(
        paths.file('data/library.json'),
        jsonEncode({
          '10': {'playtimeMinutes': 9000, 'lastPlayed': '2030-01-01'},
        }),
      );
      await write(
        p.join(steam.path, 'config', 'loginusers.vdf'),
        Kv1.stringify({
          'users': {
            '76561197960265729': {'AccountName': 'current', 'AutoLogin': '1'},
            '76561197960265730': {'AccountName': 'other', 'AutoLogin': '0'},
          },
        }),
      );
      Future<void> history(String account, int minutes) => write(
        p.join(steam.path, 'userdata', account, 'config', 'localconfig.vdf'),
        Kv1.stringify({
          'UserLocalConfigStore': {
            'Software': {
              'Valve': {
                'Steam': {
                  'Apps': {
                    '10': {'Playtime': '$minutes', 'LastPlayed': '1793637603'},
                    '20': {'Playtime': '90', 'LastPlayed': '1793637000'},
                  },
                },
              },
            },
          },
        }),
      ).then((_) {});
      await history('1', 1247);
      await history('2', 9999);

      await library.scan();
      expect(
        library.games.firstWhere((g) => g.appId == 10).playtimeMinutes,
        1247,
      );
      expect(
        library.games.firstWhere((g) => g.appId == 20).playtimeMinutes,
        90,
      );
      expect(
        library.games.firstWhere((g) => g.appId == 10).lastPlayed,
        DateTime.fromMillisecondsSinceEpoch(1793637603000),
      );

      await history('1', 1250);
      await library.scan();
      expect(
        library.games.firstWhere((g) => g.appId == 10).playtimeMinutes,
        1250,
      );
      expect(library.accounts.first.accountName, 'current');
      expect(library.accounts.first.mostRecent, isTrue);

      await write(
        p.join(steam.path, 'config', 'loginusers.vdf'),
        Kv1.stringify({
          'users': {
            '76561197960265729': {'AccountName': 'current', 'MostRecent': '0'},
            '76561197960265730': {'AccountName': 'other', 'MostRecent': '1'},
          },
        }),
      );
      await library.scan();
      expect(
        library.games.firstWhere((g) => g.appId == 10).playtimeMinutes,
        9999,
      );
    },
  );

  test(
    'missing Steam history does not use client time or another account',
    () async {
      await manifest(steam.path, 10, 'Installed Game');
      await write(
        p.join(steam.path, 'config', 'lua', '20.lua'),
        'addappid(20)',
      );
      await write(
        paths.file('data/library.json'),
        jsonEncode({
          '10': {'playtimeMinutes': 9000, 'lastPlayed': '2030-01-01'},
          '20': {'playtimeMinutes': 8000, 'lastPlayed': '2030-01-01'},
        }),
      );
      await library.scan();
      for (final game in library.games) {
        expect(game.playtimeMinutes, isNull);
        expect(game.lastPlayed, isNull);
      }

      await write(
        p.join(steam.path, 'config', 'loginusers.vdf'),
        Kv1.stringify({
          'users': {
            '76561197960265729': {'AccountName': 'current', 'MostRecent': '1'},
          },
        }),
      );
      await write(
        p.join(steam.path, 'userdata', '1', 'config', 'localconfig.vdf'),
        Kv1.stringify({
          'UserLocalConfigStore': {
            'Software': {
              'Valve': {
                'Steam': {
                  'apps': {
                    '10': {'Playtime': '0'},
                    '20': {'Playtime': '-1', 'LastPlayed': '1793637603'},
                  },
                },
              },
            },
          },
        }),
      );
      await library.scan();
      expect(library.games.firstWhere((g) => g.appId == 10).playtimeMinutes, 0);
      expect(
        library.games.firstWhere((g) => g.appId == 20).playtimeMinutes,
        isNull,
      );
      expect(
        library.games.firstWhere((g) => g.appId == 20).lastPlayed,
        isNotNull,
      );
    },
  );

  test(
    'unifies installed and Lua records without inventing ownership',
    () async {
      await manifest(steam.path, 10, 'Installed Game');
      await write(
        p.join(steam.path, 'config', 'lua', '10.lua'),
        'addappid(10)',
      );
      await write(
        p.join(steam.path, 'config', 'lua', 'Disable', '20.lua'),
        'addappid(20)',
      );
      await library.scan();
      expect(library.games, hasLength(2));
      final installed = library.games.firstWhere((game) => game.appId == 10);
      expect(installed.isInstalled, isTrue);
      expect(installed.hasLua, isTrue);
      expect(installed.luaEnabled, isTrue);
      expect(installed.ownership, GameOwnership.unknown);
      expect(installed.sizeOnDisk, 123456);
      final luaOnly = library.games.firstWhere((game) => game.appId == 20);
      expect(luaOnly.luaEnabled, isFalse);
      expect(luaOnly.isInstalled, isFalse);
      expect(luaOnly.ownership, GameOwnership.unknown);
    },
  );

  test(
    'duplicate AppID prefers actual installed copy and active Lua',
    () async {
      final other = await Directory(
        p.join(fixture.path, 'Other Library'),
      ).create();
      await write(
        p.join(steam.path, 'steamapps', 'libraryfolders.vdf'),
        Kv1.stringify({
          'libraryfolders': {
            '0': {'path': steam.path},
            '1': {'path': other.path},
          },
        }),
      );
      await manifest(steam.path, 42, 'Missing copy', installed: false);
      await manifest(other.path, 42, 'Working copy');
      await write(
        p.join(steam.path, 'config', 'lua', '42.lua'),
        'addappid(42)',
      );
      await write(
        p.join(steam.path, 'config', 'lua', 'Disable', '42.lua'),
        'addappid(42)',
      );
      await library.scan();
      expect(library.games, hasLength(1));
      expect(library.games.single.name, 'Working copy');
      expect(library.games.single.libraryPath, other.path);
      expect(library.games.single.luaEnabled, isTrue);
    },
  );

  test('detects active manifest pins and ignores commented pins', () async {
    await write(
      p.join(steam.path, 'config', 'lua', '10.lua'),
      'addappid(10)\nsetManifestid(11,"123456789",0)',
    );
    await write(
      p.join(steam.path, 'config', 'lua', '20.lua'),
      'addappid(20)\n-- setManifestid(21,"987654321",0)',
    );
    await library.scan();
    expect(
      library.games.firstWhere((game) => game.appId == 10).versionPinned,
      isTrue,
    );
    expect(
      library.games.firstWhere((game) => game.appId == 20).versionPinned,
      isFalse,
    );
  });

  test(
    'handles broken individual manifests and rejects install traversal',
    () async {
      await manifest(steam.path, 10, 'Valid');
      await write(
        p.join(steam.path, 'steamapps', 'appmanifest_20.acf'),
        '"AppState" {',
      );
      await write(
        p.join(steam.path, 'steamapps', 'appmanifest_30.acf'),
        '"AppState" { "appid" "30" "installdir" "../../outside" }',
      );
      await library.scan();
      expect(library.games.map((game) => game.appId), [10]);
      expect(library.warnings, hasLength(2));
    },
  );

  test('reads configured TOML Lua paths including relative locations', () async {
    await write(
      p.join(steam.path, 'opensteamtool.toml'),
      '[other]\nactive = true\n[lua]\npaths = ["custom/lua", "D:/not-existing"]\n',
    );
    await write(p.join(steam.path, 'custom', 'lua', '77.lua'), 'addappid(77)');
    await library.scan();
    expect(library.games.single.appId, 77);
    expect(
      library.games.single.luaPath,
      p.join(steam.path, 'custom', 'lua', '77.lua'),
    );
  });

  test('Lua enable and disable moves files without dropping content', () async {
    final source = await write(
      p.join(steam.path, 'config', 'lua', '10.lua'),
      '-- keep\naddappid(10)',
    );
    await library.scan();
    await library.toggleLua(10, false);
    expect(await source.exists(), isFalse);
    expect(library.games.single.luaEnabled, isFalse);
    expect(
      await File(library.games.single.luaPath!).readAsString(),
      '-- keep\naddappid(10)',
    );
    await library.toggleLua(10, true);
    expect(await source.exists(), isTrue);
    expect(library.games.single.luaEnabled, isTrue);
  });

  test(
    'favorites persist in new app data and Lua deletion retains a backup',
    () async {
      await write(
        p.join(steam.path, 'config', 'lua', '10.lua'),
        'addappid(10)',
      );
      await library.scan();
      await library.setFavorite(10, true);
      await library.scan();
      expect(library.games.single.isFavorite, isTrue);
      final data =
          jsonDecode(
                await File(
                  paths.file(p.join('data', 'library.json')),
                ).readAsString(),
              )
              as Map;
      expect(data['10']['favorite'], isTrue);
      await library.deleteLua(10);
      expect(library.games, isEmpty);
      final backups = await paths
          .directory(p.join('backups', 'library'))
          .list()
          .toList();
      expect(backups, hasLength(1));
      expect(await File(backups.single.path).readAsString(), 'addappid(10)');
    },
  );

  test('imports content into correct roots and skips existing files', () async {
    final source = p.join(fixture.path, 'input');
    await write(p.join(source, '10.lua'), 'addappid(10)');
    await write(p.join(source, 'UserGameStatsSchema_10.bin'), 'binary');
    await write(p.join(source, '11_1234.manifest'), 'manifest');
    final files = [
      p.join(source, '10.lua'),
      p.join(source, 'UserGameStatsSchema_10.bin'),
      p.join(source, '11_1234.manifest'),
    ];
    final result = await library.importFiles(files);
    expect(result.written, hasLength(3));
    expect(result.errors, isEmpty);
    expect(
      await File(p.join(steam.path, 'config', 'lua', '10.lua')).readAsString(),
      'addappid(10)',
    );
    expect(
      await File(
        p.join(steam.path, 'appcache', 'stats', 'UserGameStatsSchema_10.bin'),
      ).exists(),
      isTrue,
    );
    expect(
      await File(p.join(steam.path, 'depotcache', '11_1234.manifest')).exists(),
      isTrue,
    );
    final repeated = await library.importFiles(files);
    expect(repeated.written, isEmpty);
    expect(repeated.skipped, hasLength(3));
  });

  test(
    'zip import flattens Lua into a core-loaded directory and rejects traversal',
    () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'config/lua/nested/10.lua',
            12,
            utf8.encode('addappid(10)'),
          ),
        )
        ..addFile(
          ArchiveFile(
            'depotcache/11_1234.manifest',
            8,
            utf8.encode('manifest'),
          ),
        );
      final zip = File(p.join(fixture.path, 'games.zip'));
      await zip.writeAsBytes(ZipEncoder().encode(archive));
      final result = await library.importFiles([zip.path]);
      expect(result.errors, isEmpty);
      expect(result.written, hasLength(2));
      expect(
        await File(p.join(steam.path, 'config', 'lua', '10.lua')).exists(),
        isTrue,
      );
      expect(library.games.single.appId, 10);
      final malicious = Archive()
        ..addFile(ArchiveFile('../20.lua', 12, utf8.encode('addappid(20)')));
      final badZip = File(p.join(fixture.path, 'bad.zip'));
      await badZip.writeAsBytes(ZipEncoder().encode(malicious));
      final rejected = await library.importFiles([badZip.path]);
      expect(rejected.errors, hasLength(1));
      expect(
        await File(p.join(steam.path, 'config', '20.lua')).exists(),
        isFalse,
      );
    },
  );

  test(
    'lists local accounts and updates only most recent offline preference',
    () async {
      final login = await write(
        p.join(steam.path, 'config', 'loginusers.vdf'),
        Kv1.stringify({
          'users': {
            '76561198000000001': {
              'AccountName': 'alice',
              'PersonaName': 'Alice',
              'MostRecent': '1',
            },
            '76561198000000002': {
              'AccountName': 'bob',
              'PersonaName': 'Bob',
              'MostRecent': '0',
            },
          },
        }),
      );
      await library.scan();
      expect(library.accounts.map((account) => account.accountName), [
        'alice',
        'bob',
      ]);
      final avatar = await write(
        p.join(steam.path, 'config', 'avatarcache', '76561198000000001.png'),
        'fixture',
      );
      expect(library.avatarPath(library.accounts.first), avatar.path);
      await library.setOfflineMode(true);
      final parsed = Kv1.parse(await login.readAsString());
      expect(parsed['users']['76561198000000001']['WantsOfflineMode'], '1');
      expect(parsed['users']['76561198000000002']['WantsOfflineMode'], isNull);
    },
  );

  test('launch and install URI fallback opens requested AppID', () async {
    await write(p.join(steam.path, 'config', 'lua', '10.lua'), 'addappid(10)');
    await library.scan();
    await library.launch(10);
    await library.launch(
      10,
      launchArguments: const ['-onlinefix', '-realappid'],
    );
    await library.install(10);
    expect(opened.map((uri) => uri.toString()), [
      'steam://rungameid/10',
      'steam://rungameid/10//-onlinefix%20-realappid',
      'steam://install/10',
    ]);
    expect(library.games.single.isRunning, isFalse);
  });

  test(
    'Lua game information persists across scans and service reloads',
    () async {
      await write(
        p.join(steam.path, 'config', 'lua', '10.lua'),
        'addappid(10)',
      );
      await library.scan();
      await library.updateGameMetadata(
        10,
        name: 'Lua Adventure',
        coverUrl: 'https://example.test/10.jpg',
      );
      await library.scan();
      expect(library.games.single.name, 'Lua Adventure');
      expect(library.games.single.coverUrl, 'https://example.test/10.jpg');
      final reloaded = LibraryService(paths: paths, settings: settings);
      try {
        await reloaded.scan();
        expect(reloaded.games.single.name, 'Lua Adventure');
        expect(reloaded.games.single.coverUrl, 'https://example.test/10.jpg');
        expect(reloaded.games.single.hasLua, isTrue);
      } finally {
        reloaded.dispose();
      }
    },
  );

  test(
    'Lua editor saves the disabled file and backs up its original text',
    () async {
      final file = await write(
        p.join(steam.path, 'config', 'lua', 'Disable', '10.lua'),
        '-- original\naddappid(10)',
      );
      await library.scan();
      expect(await library.readLua(10), '-- original\naddappid(10)');
      await library.saveLua(10, '-- edited\naddappid(10)\naddappid(11)');
      expect(
        await file.readAsString(),
        '-- edited\naddappid(10)\naddappid(11)',
      );
      expect(library.games.single.luaEnabled, isFalse);
      expect(
        await File(p.join(steam.path, 'config', 'lua', '10.lua')).exists(),
        isFalse,
      );
      final backup = await paths
          .directory(p.join('backups', 'library'))
          .list()
          .single;
      expect(
        await File(backup.path).readAsString(),
        '-- original\naddappid(10)',
      );
    },
  );

  test('disabled Lua returns to its core-loaded directory', () async {
    final source = await write(
      p.join(steam.path, 'config', 'lua', 'Disable', '10.lua'),
      'addappid(10)',
    );
    await library.scan();
    await library.toggleLua(10, true);
    expect(await source.exists(), isFalse);
    expect(
      library.games.single.luaPath,
      p.join(steam.path, 'config', 'lua', '10.lua'),
    );
    expect(library.games.single.luaEnabled, isTrue);
    await library.toggleLua(10, false);
    expect(await source.exists(), isTrue);
    expect(library.games.single.luaEnabled, isFalse);
  });

  test(
    'batch Lua operations keep successes and report individual failures',
    () async {
      await write(
        p.join(steam.path, 'config', 'lua', '10.lua'),
        'addappid(10)',
      );
      await write(
        p.join(steam.path, 'config', 'lua', '20.lua'),
        'addappid(20)',
      );
      await library.scan();
      final result = await library.setLuaEnabled([10, 999, 20], false);
      expect(result.written, hasLength(2));
      expect(result.errors.keys, ['999']);
      expect(library.games.every((game) => !game.luaEnabled), isTrue);
      final removed = await library.deleteLuaFiles([10, 20]);
      expect(removed.errors, isEmpty);
      expect(removed.written, hasLength(2));
      expect(library.games, isEmpty);
      expect(
        await paths.directory(p.join('backups', 'library')).list().length,
        2,
      );
    },
  );

  test(
    'exports enabled and disabled Lua without moving or overwriting files',
    () async {
      final enabled = await write(
        p.join(steam.path, 'config', 'lua', '10.lua'),
        '-- enabled',
      );
      final disabled = await write(
        p.join(steam.path, 'config', 'lua', 'Disable', '20.lua'),
        '-- disabled',
      );
      await library.scan();
      final directory = p.join(fixture.path, 'export');
      await write(p.join(directory, '10.lua'), '-- keep existing');
      final result = await library.exportLua([10, 20], directory);
      expect(result.errors, isEmpty);
      expect(result.written, [p.join(directory, '20.lua')]);
      expect(result.skipped, [p.join(directory, '10.lua')]);
      expect(
        await File(p.join(directory, '10.lua')).readAsString(),
        '-- keep existing',
      );
      expect(
        await File(p.join(directory, '20.lua')).readAsString(),
        '-- disabled',
      );
      expect(await enabled.exists(), isTrue);
      expect(await disabled.exists(), isTrue);
    },
  );

  test(
    'Lua directory action opens the actual disabled-file location',
    () async {
      final source = await write(
        p.join(steam.path, 'config', 'lua', 'Disable', '10.lua'),
        'addappid(10)',
      );
      await library.scan();
      await library.openLuaDirectory(appId: 10);
      await library.openLuaDirectory();
      expect(opened, [
        Uri.directory(p.dirname(source.path), windows: Platform.isWindows),
        Uri.directory(
          p.join(steam.path, 'config', 'lua'),
          windows: Platform.isWindows,
        ),
      ]);
    },
  );

  test('Steam update control preserves unrelated Steam.cfg keys', () async {
    final config = File(p.join(steam.path, 'Steam.cfg'));
    await config.writeAsString(
      'OtherSetting=keep\n'
      'BootStrapperInhibitAll=enable\n'
      'BootStrapperForceSelfUpdate=disable\n',
    );

    expect(
      await library.readSteamUpdateControl(),
      isA<SteamUpdateControlSettings>()
          .having(
            (value) => value.disableUpdateCheck,
            'disableUpdateCheck',
            isTrue,
          )
          .having(
            (value) => value.disableForcedUpdate,
            'disableForcedUpdate',
            isTrue,
          ),
    );

    final updated = await library.setSteamUpdateControl(
      const SteamUpdateControlSettings(disableForcedUpdate: true),
    );
    expect(updated.disableUpdateCheck, isFalse);
    expect(updated.disableForcedUpdate, isTrue);
    final content = await config.readAsString();
    expect(content, contains('OtherSetting=keep'));
    expect(content, contains('BootStrapperForceSelfUpdate=disable'));
    expect(content, isNot(contains('BootStrapperInhibitAll')));
  });

  test('Steam lifecycle actions start, stop and restart the client', () async {
    var running = false;
    var starts = 0;
    final lifecycle = LibraryService(
      paths: paths,
      settings: settings,
      processRunner: (command, args) async {
        if (command == 'tasklist.exe') {
          return ProcessResult(
            1,
            0,
            running ? '"steam.exe","1","Console","1","1 K"' : '',
            '',
          );
        }
        if (command == 'taskkill.exe') {
          running = false;
          return ProcessResult(2, 0, '', '');
        }
        return ProcessResult(3, 1, '', 'Unexpected command');
      },
      processStarter: (executable, arguments, {workingDirectory}) async {
        starts++;
        running = true;
        expect(executable, p.join(steam.path, 'steam.exe'));
        expect(workingDirectory, steam.path);
      },
    );
    addTearDown(lifecycle.dispose);

    expect(await lifecycle.processActions.isRunning(), isFalse);
    await lifecycle.processActions.start();
    expect(starts, 1);
    expect(await lifecycle.processActions.isRunning(), isTrue);
    await lifecycle.processActions.restart();
    expect(starts, 2);
    expect(await lifecycle.processActions.isRunning(), isTrue);
    await lifecycle.processActions.stop();
    expect(await lifecycle.processActions.isRunning(), isFalse);
  });
}
