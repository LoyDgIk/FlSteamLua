import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/kernel/kernel_config.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/lua_directories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late LuaDirectories directories;
  late SettingsStore settings;
  late LibraryService library;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lua-directories-');
    directories = LuaDirectories(root.path);
    final paths = AppPaths(p.join(root.path, 'client'));
    settings = SettingsStore(paths);
    await settings.set('steamPath', root.path);
    library = LibraryService(paths: paths, settings: settings);
  });
  tearDown(() async {
    library.dispose();
    settings.dispose();
    await root.delete(recursive: true);
  });

  test(
    'fresh core uses config/lua and imported Lua is in its load range',
    () async {
      final input = File(p.join(root.path, '42.lua'));
      await input.writeAsString('addappid(42)');
      final imported = await library.importFiles([input.path]);
      expect(
        imported.written.single,
        p.join(root.path, 'config', 'lua', '42.lua'),
      );
      expect(directories.loadOrder, [directories.coreDefault]);
      expect(library.games.single.luaEnabled, isTrue);
    },
  );

  test(
    'reordering changes only new imports and default directory remains scanned',
    () async {
      final a = p.join(root.path, 'a');
      final b = p.join(root.path, 'b');
      await directories.save([a, b]);
      await Directory(directories.coreDefault).create(recursive: true);
      await File(
        p.join(directories.coreDefault, '10.lua'),
      ).writeAsString('addappid(10)');
      final input = File(p.join(root.path, '42.lua'));
      await input.writeAsString('addappid(42)');
      await library.importFiles([input.path]);
      await directories.save([b, a]);
      expect((await library.contentDirectories()).lua, b);
      expect(await File(p.join(a, '42.lua')).exists(), isTrue);
      await File(p.join(b, '43.lua')).writeAsString('addappid(43)');
      await library.scan();
      expect(
        library.games.map((game) => game.appId),
        containsAll([10, 42, 43]),
      );
      expect(KernelConfig(root.path).readSync()['lua']['paths'], [b, a]);
    },
  );

  test(
    'TOML arrays and escapes preserve comments and unrelated settings',
    () async {
      final file = KernelConfig(root.path).file;
      await file.writeAsString(
        "\uFEFF# kept\r\n[lua]\r\npaths = [\r\n  'a#b', # a path\r\n  '目录',\r\n]\r\n[manifest]\r\ntimeout_recv_ms = 4321 # kept\r\nurl = 'wudrm'\r\n",
      );
      expect(directories.read(), [
        p.join(root.path, 'a#b'),
        p.join(root.path, '目录'),
      ]);
      await directories.save([
        p.join(root.path, '新目录'),
        directories.coreDefault,
      ]);
      await KernelConfig(
        root.path,
      ).update('manifest', {'url': 'steamrun', 'failover': false});
      final result = await file.readAsString();
      expect((await file.readAsBytes()).take(3), [0xef, 0xbb, 0xbf]);
      expect(result, startsWith('# kept\r\n'));
      expect(result, contains('timeout_recv_ms = 4321 # kept'));
      expect(KernelConfig.decode(result)['manifest'], {
        'timeout_recv_ms': 4321,
        'url': 'steamrun',
        'failover': false,
      });
    },
  );

  test(
    'core default wins duplicate Lua and unconfigured nested folders stay inactive',
    () async {
      final extra = p.join(root.path, 'extra');
      await directories.save([extra]);
      final core = File(p.join(directories.coreDefault, '42.lua'));
      await core.parent.create(recursive: true);
      await core.writeAsString('addappid(42)');
      await File(
        p.join(extra, '42.lua'),
      ).writeAsString('addappid(42)\nsetManifestid(43,"123")');
      final nested = File(p.join(extra, 'nested', '44.lua'));
      await nested.parent.create();
      await nested.writeAsString('addappid(44)');
      await library.scan();
      expect(library.games.single.luaPath, core.path);
      expect(library.games.single.versionPinned, isTrue);
    },
  );

  test(
    'invalid TOML is not overwritten by directory or manifest edits',
    () async {
      final file = KernelConfig(root.path).file;
      await file.writeAsString('[lua]\npaths = [');
      await expectLater(
        directories.save([p.join(root.path, 'new')]),
        throwsA(isA<Exception>()),
      );
      expect(await file.readAsString(), '[lua]\npaths = [');
    },
  );
  test('removing every custom directory restores the fixed default', () async {
    await directories.save([p.join(root.path, 'custom')]);
    await directories.save([]);
    expect(directories.customPaths(), isEmpty);
    expect(directories.read(), [directories.coreDefault]);
    expect(directories.loadOrder, [directories.coreDefault]);
    expect(KernelConfig(root.path).readSync()['lua']['paths'], isEmpty);
  });
}
