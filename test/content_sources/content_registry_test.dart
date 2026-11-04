import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_source_registry.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/manifests/manifest_script_parser.dart';
import 'package:fl_steam_lua/features/manifests/manifest_script_runner.dart';
import 'package:fl_steam_lua/features/manifests/manifest_source_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Secrets implements SecretValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Runner implements ManifestScriptRunner {
  Object? output;
  Map<String, Object?>? params;
  @override
  Future<Object?> invoke({
    required String script,
    required String function,
    required Map<String, Object?> params,
    required ManifestRequestHandler request,
    required void Function(String) log,
    TaskContext? task,
  }) async {
    this.params = params;
    return output;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'capability declarations distinguish Lua, IDs, files, codes and defaults',
    () {
      const prefix = '// @id fixture\n';
      expect(ManifestScriptParser.parse(prefix).capabilities, {
        ContentCapability.manifestFiles,
      });
      expect(
        ManifestScriptParser.parse('$prefix// @provides lua').capabilities,
        {ContentCapability.lua},
      );
      expect(
        ManifestScriptParser.parse(
          '$prefix// @provides lua,manifest\n'
          '// @manifest-types ids,files,codes',
        ).capabilities,
        ContentCapability.values.toSet(),
      );
      for (final declaration in [
        '// @provides manifest',
        '// @provides lua\n// @manifest-types files',
        '// @provides other',
        '// @provides manifest\n// @manifest-types something',
        '// @provides lua\n// @provides manifest',
        '// @manifest-types ids',
      ]) {
        expect(
          () => ManifestScriptParser.parse('$prefix$declaration'),
          throwsFormatException,
        );
      }
    },
  );

  late Directory directory;
  late SettingsStore settings;
  late KeyCacheService subscriptions;
  late ManifestSourceService scripts;
  late ContentSourceRegistry registry;
  late _Runner runner;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fl-content-registry-');
    final paths = AppPaths(directory.path);
    settings = SettingsStore(paths);
    subscriptions = KeyCacheService(
      paths: paths,
      settings: settings,
      protect: (text) => text,
      unprotect: (text) => text,
    );
    runner = _Runner();
    scripts = ManifestSourceService(
      paths: paths,
      settings: settings,
      runner: runner,
      secrets: _Secrets(),
      assetLoader: (path) => File(path).readAsString(),
    );
    registry = ContentSourceRegistry(
      manifests: scripts,
      keyCache: subscriptions,
      settings: settings,
    );
    await registry.initialize();
  });
  tearDown(() async {
    registry.dispose();
    scripts.dispose();
    subscriptions.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'source identity is namespaced and script enabled state persists',
    () async {
      final fixture = File('${directory.path}/fixture.js');
      await fixture.writeAsString('// @id default\n// @provides lua');
      await scripts.importScript(fixture);
      expect(
        registry.source('subscription:default').kind,
        ContentSourceKind.subscription,
      );
      expect(registry.source('script:default').kind, ContentSourceKind.script);
      await registry.setEnabled('script:default', false);
      expect(registry.source('script:default').enabled, isFalse);
      await settings.load();
      expect(registry.source('script:default').enabled, isFalse);
      expect(registry.source('subscription:default').enabled, isTrue);
      await expectLater(
        registry.fetch(
          'script:default',
          440,
          requestedCapabilities: {ContentCapability.lua},
        ),
        throwsStateError,
      );
      await registry.remove('script:default');
      expect(
        registry.sources.any((source) => source.id == 'script:default'),
        isFalse,
      );
      expect(
        subscriptions.subscriptions.any((source) => source.id == 'default'),
        isTrue,
      );
    },
  );

  test('DLC key-cache access uses unified subscription identities', () async {
    expect(
      registry.keyCacheSources.map((source) => source.id),
      contains('subscription:default'),
    );
    final cache = await registry.readKeyCache('subscription:default');
    expect(cache.depotKeys, isEmpty);
    expect(
      () => registry.readKeyCache('script:luatools'),
      throwsArgumentError,
    );
  });

  test(
    'structured pins retain exact 64-bit IDs and requested capabilities reach scripts',
    () async {
      final fixture = File('${directory.path}/fixture.js');
      await fixture.writeAsString(
        '// @id ids\n// @provides manifest\n// @manifest-types ids',
      );
      await scripts.importScript(fixture);
      runner.output = {
        'manifestPins': [
          {'depotId': 441, 'manifestId': '18446744073709551615'},
        ],
      };
      final payload = await registry.fetch(
        'script:ids',
        440,
        requestedCapabilities: {ContentCapability.manifestIds},
      );
      expect(payload.pins.single.manifestId, '18446744073709551615');
      expect(payload.pins.single.sourceId, 'script:ids');
      expect(runner.params!['requestedCapabilities'], ['manifestIds']);
      await expectLater(
        registry.fetch(
          'script:ids',
          440,
          requestedCapabilities: {ContentCapability.lua},
        ),
        throwsStateError,
      );
      for (final invalid in [42, '18446744073709551616', '-1', '0']) {
        runner.output = {
          'manifestPins': [
            {'depotId': 441, 'manifestId': invalid},
          ],
        };
        await expectLater(
          registry.fetch(
            'script:ids',
            440,
            requestedCapabilities: {ContentCapability.manifestIds},
          ),
          throwsA(isA<ManifestSourceException>()),
        );
      }
    },
  );

  test('content sources can return kernel manifest request codes', () async {
    final fixture = File('${directory.path}/request-codes.js');
    await fixture.writeAsString(
      '// @id request-codes\n'
      '// @provides manifest\n'
      '// @manifest-types codes',
    );
    await scripts.importScript(fixture);
    runner.output = {
      'manifestRequestCodes': [
        {
          'depotId': 441,
          'manifestId': '9007199254740993',
          'requestCode': '18446744073709551615',
        },
      ],
    };
    final payload = await registry.fetch(
      'script:request-codes',
      440,
      requestedCapabilities: {ContentCapability.manifestRequestCodes},
    );
    expect(payload.requestCodes.single.depotId, 441);
    expect(payload.requestCodes.single.manifestId, '9007199254740993');
    expect(payload.requestCodes.single.requestCode, '18446744073709551615');
    expect(payload.requestCodes.single.sourceId, 'script:request-codes');
  });

  test(
    'script can return Lua and manifests together without losing logs',
    () async {
      final fixture = File('${directory.path}/fixture.js');
      await fixture.writeAsString(
        '// @id combined\n// @provides lua,manifest\n// @manifest-types files',
      );
      await scripts.importScript(fixture);
      runner.output = {
        'artifacts': [
          {'filename': '440.lua', 'content': 'addappid(440)'},
          {
            'filename': '441_12.manifest',
            'content': 'AA==',
            'encoding': 'base64',
          },
        ],
      };
      final payload = await registry.fetch(
        'script:combined',
        440,
        requestedCapabilities: {
          ContentCapability.lua,
          ContentCapability.manifestFiles,
        },
      );
      expect(payload.artifacts.map((value) => value.filename), [
        '440.lua',
        '441_12.manifest',
      ]);
      expect(
        payload.artifacts.every((value) => value.sourceId == 'script:combined'),
        isTrue,
      );
    },
  );
}
