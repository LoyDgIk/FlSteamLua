import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/patching/game_file_verification.dart';
import 'package:fl_steam_lua/features/steam_protocol/manifest/depot_manifest.dart';
import 'package:fl_steam_lua/features/tools/tools_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('verification reports missing changed and unexpected files', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'flsteam-verification-',
    );
    final gameDirectory = await Directory(
      p.join(temporary.path, 'game'),
    ).create();
    final steamapps = await Directory(
      p.join(temporary.path, 'steam', 'steamapps'),
    ).create(recursive: true);
    final depotCache = await Directory(
      p.join(steamapps.path, 'depotcache'),
    ).create();
    final appPaths = AppPaths(p.join(temporary.path, 'app'));
    final settings = SettingsStore(appPaths);
    final tools = ToolsService(paths: appPaths, settings: settings);
    try {
      final good = utf8.encode('good file');
      final changed = utf8.encode('old version');
      final missing = utf8.encode('missing file');
      await File(p.join(gameDirectory.path, 'good.dll')).writeAsBytes(good);
      await File(
        p.join(gameDirectory.path, 'changed.dll'),
      ).writeAsString('new version');
      await File(
        p.join(gameDirectory.path, 'unexpected.cfg'),
      ).writeAsString('user data');
      final manifest = DepotManifest(
        depotId: 456,
        manifestGid: BigInt.from(789),
        files: [
          DepotManifestFile(
            fileName: 'good.dll',
            size: good.length,
            flags: 0,
            sha: sha1.convert(good).bytes,
          ),
          DepotManifestFile(
            fileName: 'changed.dll',
            size: changed.length,
            flags: 0,
            sha: sha1.convert(changed).bytes,
          ),
          DepotManifestFile(
            fileName: 'missing.dll',
            size: missing.length,
            flags: 0,
            sha: sha1.convert(missing).bytes,
          ),
        ],
      );
      await File(
        p.join(depotCache.path, '456_789.manifest'),
      ).writeAsBytes(manifest.toBytes());
      await File(p.join(steamapps.path, 'appmanifest_123.acf')).writeAsString(
        '''
"AppState"
{
  "appid" "123"
  "InstalledDepots"
  {
    "456"
    {
      "manifest" "789"
    }
  }
}
''',
      );
      final result = await GameFileVerificationService(tools: tools).verify(
        GameEntry(
          appId: 123,
          name: 'Fixture',
          installPath: gameDirectory.path,
          libraryPath: p.join(temporary.path, 'steam'),
          isInstalled: true,
        ),
      );
      expect(result.verifiedCount, 1);
      expect(result.missingCount, 1);
      expect(result.changedCount, 1);
      expect(result.unexpectedCount, 1);
      expect(result.issueCount, 2);
      expect(
        result.files.firstWhere((file) => file.path == 'unexpected.cfg').state,
        GameFileState.unexpected,
      );
    } finally {
      tools.dispose();
      settings.dispose();
      await temporary.delete(recursive: true);
    }
  });

  test(
    'verification finds manifests in another configured Steam library',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'flsteam-verification-primary-',
      );
      final primary = Directory(p.join(temporary.path, 'steam'));
      final secondary = p.join(temporary.path, 'library');
      final gameDirectory = await Directory(
        p.join(secondary, 'steamapps', 'common', 'game'),
      ).create(recursive: true);
      await Directory(
        p.join(primary.path, 'steamapps', 'depotcache'),
      ).create(recursive: true);
      await File(
        p.join(primary.path, 'steamapps', 'libraryfolders.vdf'),
      ).writeAsString('''
"libraryfolders"
{
  "0"
  {
    "path" "${primary.path.replaceAll('\\', '\\\\')}"
  }
  "1"
  {
    "path" "${secondary.replaceAll('\\', '\\\\')}"
  }
}
''');
      final appPaths = AppPaths(p.join(temporary.path, 'app'));
      final settings = SettingsStore(appPaths);
      await settings.set('steamPath', primary.path);
      final tools = ToolsService(paths: appPaths, settings: settings);
      try {
        final content = utf8.encode('file');
        await File(
          p.join(gameDirectory.path, 'game.dll'),
        ).writeAsBytes(content);
        final manifest = DepotManifest(
          depotId: 456,
          manifestGid: BigInt.from(789),
          files: [
            DepotManifestFile(
              fileName: 'game.dll',
              size: content.length,
              flags: 0,
              sha: sha1.convert(content).bytes,
            ),
          ],
        );
        await File(
          p.join(primary.path, 'steamapps', 'depotcache', '456_789.manifest'),
        ).writeAsBytes(manifest.toBytes());
        await File(
          p.join(secondary, 'steamapps', 'appmanifest_123.acf'),
        ).writeAsString('''
"AppState"
{
  "appid" "123"
  "InstalledDepots"
  {
    "456"
    {
      "manifest" "789"
    }
  }
}
''');

        final result = await GameFileVerificationService(tools: tools).verify(
          GameEntry(
            appId: 123,
            name: 'Fixture',
            installPath: gameDirectory.path,
            libraryPath: secondary,
            isInstalled: true,
          ),
        );
        expect(result.manifestCount, 1);
        expect(result.verifiedCount, 1);
        expect(result.unverifiedCount, 0);
      } finally {
        tools.dispose();
        settings.dispose();
        await temporary.delete(recursive: true);
      }
    },
  );

  test('missing manifests fall back to an unverified file inventory', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'flsteam-verification-fallback-',
    );
    final library = p.join(temporary.path, 'steam');
    final gameDirectory = await Directory(
      p.join(library, 'steamapps', 'common', 'game'),
    ).create(recursive: true);
    await File(p.join(gameDirectory.path, 'game.dll')).writeAsString('file');
    await File(
      p.join(library, 'steamapps', 'appmanifest_123.acf'),
    ).writeAsString('''
"AppState"
{
  "appid" "123"
  "InstalledDepots"
  {
    "4115451"
    {
      "manifest" "7450216563795868763"
    }
  }
}
''');
    final appPaths = AppPaths(p.join(temporary.path, 'app'));
    final settings = SettingsStore(appPaths);
    final tools = ToolsService(paths: appPaths, settings: settings);
    try {
      final result = await GameFileVerificationService(tools: tools).verify(
        GameEntry(
          appId: 123,
          name: 'Fixture',
          installPath: gameDirectory.path,
          libraryPath: library,
          isInstalled: true,
        ),
      );
      expect(result.manifestCount, 0);
      expect(result.unverifiedCount, 1);
      expect(result.files.single.state, GameFileState.unverified);
      expect(result.warnings.join('\n'), contains('file inventory only'));
    } finally {
      tools.dispose();
      settings.dispose();
      await temporary.delete(recursive: true);
    }
  });
}
