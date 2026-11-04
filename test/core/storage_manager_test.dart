import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/storage_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('AppPaths maps configurable storage categories', () async {
    final root = await Directory.systemTemp.createTemp('flsteamlua-paths-');
    final cache = p.join(root.path, 'custom-cache');
    final paths = AppPaths(p.join(root.path, 'app'));
    paths.configureStorageLocations({'cache': cache});
    await paths.initialize();
    try {
      expect(
        paths.file('cache/covers/a.jpg'),
        p.join(cache, 'covers', 'a.jpg'),
      );
      expect(
        paths.file('backups/lua/a.zip'),
        p.join(root.path, 'app', 'backups', 'lua', 'a.zip'),
      );
      expect(await Directory(cache).exists(), isTrue);

      final settings = SettingsStore(paths);
      await settings.setStorageLocation('cache', cache);
      final loaded = SettingsStore(AppPaths(p.join(root.path, 'app')));
      await loaded.load();
      expect(loaded.storageLocations['cache'], cache);
      loaded.dispose();
      settings.dispose();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('storage directories can be measured, moved and cleared', () async {
    final root = await Directory.systemTemp.createTemp('flsteamlua-storage-');
    final source = Directory(p.join(root.path, 'source'));
    final destination = Directory(p.join(root.path, 'destination'));
    try {
      await Directory(p.join(source.path, 'nested')).create(recursive: true);
      await File(
        p.join(source.path, 'nested', 'data.bin'),
      ).writeAsBytes([1, 2, 3]);
      await destination.create();

      final before = await measureStorageDirectory(source.path);
      expect(before.bytes, 3);
      expect(before.files, 1);

      await moveStorageDirectory(source.path, destination.path);
      expect(await source.exists(), isFalse);
      expect(
        await File(
          p.join(destination.path, 'nested', 'data.bin'),
        ).readAsBytes(),
        [1, 2, 3],
      );

      await clearStorageDirectory(destination.path);
      expect(await destination.exists(), isTrue);
      expect(await destination.list().isEmpty, isTrue);
      expect(formatStorageBytes(1536), '1.50 KB');
    } finally {
      await root.delete(recursive: true);
    }
  });
}
