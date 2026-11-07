import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/manifests/manifest_script_runner.dart';
import 'package:fl_steam_lua/features/steam_protocol/app_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

String protect(String value) => base64Encode(utf8.encode(value));
String unprotect(String value) => utf8.decode(base64Decode(value));
String key(String character) => List.filled(64, character).join();

class _DynamicScriptRunner implements ManifestScriptRunner {
  _DynamicScriptRunner(this.result);
  final Object? result;
  String? executedScript;

  @override
  Future<Object?> invoke({
    required String script,
    required String function,
    required Map<String, Object?> params,
    required ManifestRequestHandler request,
    required void Function(String) log,
    TaskContext? task,
  }) async {
    executedScript = script;
    final value = result;
    if (value is Exception) throw value;
    return result;
  }
}

void main() {
  late Directory directory;
  late AppPaths paths;
  late SettingsStore settings;
  final services = <KeyCacheService>[];
  var invalidTokens = false;
  var networkCalls = 0;

  KeyCacheService service({
    KeyCacheMetadataLoader? loader,
    ManifestScriptRunner? dynamicRunner,
  }) {
    final value = KeyCacheService(
      paths: paths,
      settings: settings,
      protect: protect,
      unprotect: unprotect,
      dynamicScriptRunner: dynamicRunner,
      metadataLoader: loader,
      httpClient: MockClient((request) async {
        networkCalls++;
        return http.Response(
          request.url.path.endsWith('depotkeys.json')
              ? jsonEncode({'10': key('a'), '11': key('b'), '31': key('c')})
              : invalidTokens
              ? '{"10":"not-a-token"}'
              : '{"10":"18446744073709551615"}',
          200,
        );
      }),
    );
    services.add(value);
    return value;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fl-key-cache-');
    paths = AppPaths(directory.path);
    settings = SettingsStore(paths);
    invalidTokens = false;
    networkCalls = 0;
  });

  tearDown(() async {
    for (final service in services) {
      service.dispose();
    }
    services.clear();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  const custom = KeyCacheSubscription(
    id: 'custom',
    name: 'Fixture source',
    depotKeysUrl: 'https://fixtures.invalid/depotkeys.json?token=secret',
    tokenKeysUrl: 'https://fixtures.invalid/appaccesstokens.json',
    intervalHours: 12,
  );

  test('defaults load without network or pretending cache exists', () async {
    final cache = service();
    await cache.load();
    expect(cache.subscriptions.length, 2);
    final defaultSource = cache.subscriptions.firstWhere(
      (source) => source.id == 'default',
    );
    final toolboxSource = cache.subscriptions.firstWhere(
      (source) => source.id == 'steam-toolbox',
    );
    expect(toolboxSource.name, 'SteamToolbox');
    expect(toolboxSource.addressMode, KeySubscriptionAddressMode.script);
    expect(toolboxSource.depotKeysUrl, isEmpty);
    expect(toolboxSource.tokenKeysUrl, isEmpty);
    expect(
      defaultSource.depotKeysUrl,
      'https://api.993499094.xyz/depotkeys.json',
    );
    expect(toolboxSource.dynamicScript, contains('toolbox2.txt'));
    expect(await cache.readCache('default'), isA<KeyCacheData>());
    expect((await cache.readCache('default')).depotKeys, isEmpty);
    expect(networkCalls, 0);
  });

  test(
    'dynamic address scripts provide current URLs before download',
    () async {
      const dynamic = KeyCacheSubscription(
        id: 'dynamic',
        name: 'Dynamic source',
        depotKeysUrl: '',
        tokenKeysUrl: '',
        dynamicScript: '''
async function download(ctx) {
  return {
    depotKeysUrl: "https://dynamic.invalid/depotkeys.json",
    tokenKeysUrl: "https://dynamic.invalid/appaccesstokens.json"
  };
}
''',
        addressMode: KeySubscriptionAddressMode.script,
      );
      final runner = _DynamicScriptRunner({
        'depotKeysUrl': 'https://dynamic.invalid/depotkeys.json',
        'tokenKeysUrl': 'https://dynamic.invalid/appaccesstokens.json',
      });
      final cache = service(dynamicRunner: runner);
      await cache.upsert(dynamic);
      await cache.update(dynamic.id);
      expect(runner.executedScript, contains('function download'));
      final resolved = cache.subscriptions.firstWhere(
        (source) => source.id == dynamic.id,
      );
      expect(resolved.depotKeysUrl, 'https://dynamic.invalid/depotkeys.json');
      expect(
        resolved.tokenKeysUrl,
        'https://dynamic.invalid/appaccesstokens.json',
      );
      expect((await cache.readCache(dynamic.id)).depotKeys[11], key('b'));
    },
  );

  test(
    'persisted SteamToolbox source upgrades to the dynamic script',
    () async {
      final legacy = KeyCacheSubscription(
        id: 'steam-toolbox',
        name: 'SteamToolbox 兼容缓存',
        depotKeysUrl: 'https://legacy.invalid/depotkeys.json',
        tokenKeysUrl: 'https://legacy.invalid/appaccesstokens.json',
      );
      final file = File(paths.file('data/key-cache-subscriptions.json'));
      await file.parent.create(recursive: true);
      await file.writeAsString(
        protect(
          jsonEncode({
            'sources': [legacy.toJson()],
          }),
        ),
      );

      final cache = service();
      await cache.load();
      final upgraded = cache.subscriptions.single;
      expect(upgraded.name, 'SteamToolbox');
      expect(upgraded.addressMode, KeySubscriptionAddressMode.script);
      expect(upgraded.dynamicScript, contains('toolbox2.txt'));
      expect(upgraded.depotKeysUrl, isEmpty);
      expect(upgraded.tokenKeysUrl, isEmpty);
    },
  );

  test('CRUD, encrypted configuration and per-source cache persist', () async {
    final cache = service();
    await cache.upsert(custom);
    expect(cache.subscriptions.last.name, 'Fixture source');
    final config = await File(
      paths.file('data/key-cache-subscriptions.json'),
    ).readAsString();
    expect(config, isNot(contains('token=secret')));
    await cache.update(custom.id);
    final active = await cache.readCache(custom.id);
    expect(active.depotKeys[11], key('b'));
    expect(active.appTokens[10], '18446744073709551615');
    final restored = service();
    await restored.load();
    expect(
      (await restored.readCache(custom.id)).appTokens[10],
      '18446744073709551615',
    );
    expect(restored.subscriptions.last.lastUpdated, isNotNull);
    await cache.upsert(custom.copyWith(name: 'Edited fixture'));
    expect(cache.subscriptions.last.name, 'Edited fixture');
    await cache.remove(custom.id);
    await expectLater(cache.readCache(custom.id), throwsStateError);
  });

  test('a successful update is reused without decrypting it again', () async {
    var unprotectCalls = 0;
    final cache = KeyCacheService(
      paths: paths,
      settings: settings,
      protect: protect,
      unprotect: (value) {
        unprotectCalls++;
        return unprotect(value);
      },
      httpClient: MockClient((request) async {
        return http.Response(
          request.url.path.endsWith('depotkeys.json')
              ? jsonEncode({'11': key('b')})
              : jsonEncode({'10': '111'}),
          200,
        );
      }),
    );
    services.add(cache);
    await cache.upsert(custom);
    await cache.update(custom.id);
    expect(
      await cache.readCache(custom.id),
      same(await cache.readCache(custom.id)),
    );
    expect(unprotectCalls, 0);
  });

  test(
    'invalid downloaded pair does not replace previous valid cache',
    () async {
      final cache = service();
      await cache.upsert(custom);
      await cache.update(custom.id);
      final first = await cache.readCache(custom.id);
      invalidTokens = true;
      await expectLater(cache.update(custom.id), throwsFormatException);
      final after = await cache.readCache(custom.id);
      expect(after.depotKeys, first.depotKeys);
      expect(after.appTokens, first.appTokens);
    },
  );

  test(
    'source boundary rejects traversal, plaintext transport and userinfo',
    () async {
      final cache = service();
      await expectLater(
        cache.upsert(
          const KeyCacheSubscription(
            id: '../outside',
            name: 'Bad',
            depotKeysUrl: 'https://x.invalid/a',
            tokenKeysUrl: 'https://x.invalid/b',
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        cache.upsert(custom.copyWith(depotKeysUrl: 'http://x.invalid/a')),
        throwsFormatException,
      );
      await expectLater(
        cache.upsert(
          custom.copyWith(tokenKeysUrl: 'https://user:pass@x.invalid/a'),
        ),
        throwsFormatException,
      );
      expect(networkCalls, 0);
    },
  );

  test('disabled sources cannot update or be read', () async {
    final cache = service();
    await cache.upsert(custom.copyWith(enabled: false));
    await expectLater(cache.update(custom.id), throwsStateError);
    await expectLater(cache.readCache(custom.id), throwsStateError);
    expect(networkCalls, 0);
  });

  test('cancelled update preserves the last successful cache', () async {
    final cache = service();
    await cache.upsert(custom);
    await cache.update(custom.id);
    final calls = networkCalls;
    final progress = TaskProgress('cancelled-update', 'Fixture update')
      ..cancellationRequested = true;
    await expectLater(
      cache.update(custom.id, task: TaskContext(progress, () {})),
      throwsA(isA<TaskCancelled>()),
    );
    expect(networkCalls, calls);
    expect((await cache.readCache(custom.id)).depotKeys[11], key('b'));
  });

  test(
    'updateDue honors the refresh interval and explicit disabled interval',
    () async {
      final cache = service();
      await cache.load();
      await cache.remove('default');
      await cache.remove('steam-toolbox');
      await cache.upsert(custom);
      await cache.update(custom.id);
      final calls = networkCalls;
      await cache.updateDue();
      expect(networkCalls, calls);
      await cache.upsert(cache.subscriptions.single.copyWith(intervalHours: 0));
      await cache.updateDue();
      expect(networkCalls, calls);
    },
  );

  test(
    'offline generation only reads cached metadata and saving is explicit',
    () async {
      var metadataCalls = 0;
      final cache = service(
        loader: (id, token) async {
          metadataCalls++;
          if (id == 10) expect(token, '18446744073709551615');
          return SteamAppInfo.fromData(
            id,
            id == 10
                ? {
                    'common': {'name': 'Fixture game'},
                    'extended': {'listofdlc': '20,30'},
                    'depots': {
                      '11': {
                        'manifests': {
                          'public': {'gid': '123456789012345'},
                        },
                      },
                    },
                  }
                : {
                    'common': {'name': 'DLC $id'},
                    if (id == 30) 'depots': {'31': <String, dynamic>{}},
                  },
          );
        },
      );
      await cache.upsert(custom);
      await cache.update(custom.id);
      await expectLater(
        cache.generateOffline(10, sourceId: custom.id),
        throwsStateError,
      );
      await cache.refreshAppMetadata(10, sourceId: custom.id);
      final calls = networkCalls;
      final unpinned = await cache.generateOffline(
        10,
        sourceId: custom.id,
        dlcIds: {20},
      );
      expect(unpinned.lua, contains('--setManifestid(11,"123456789012345",0)'));
      final preview = await cache.generateOffline(
        10,
        sourceId: custom.id,
        dlcIds: {20},
        pinManifests: true,
      );
      expect(networkCalls, calls);
      expect(metadataCalls, 3);
      expect(preview.lua, contains('addappid(20)'));
      expect(preview.lua, isNot(contains('addappid(30)')));
      expect(preview.lua, isNot(contains('addappid(31, 1,')));
      expect(preview.lua, contains('setManifestid(11,"123456789012345",0)'));
      expect(preview.skippedDlcIds, isEmpty);
      final file = File(p.join(directory.path, '10.lua'));
      expect(await file.exists(), isFalse);
      await cache.savePreview(preview, file);
      expect(await file.readAsString(), preview.lua);
      await expectLater(
        cache.savePreview(preview, file),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), preview.lua);
    },
  );

  test(
    'cache parser preserves 64-bit tokens without numeric precision loss',
    () {
      final data = parseKeyCache(
        '{"10":"${key('a')}"}',
        '{"0":"0","10":"18446744073709551615","11":"'
            '0000000000000000000000000000000000000000000000000000000000000001"}',
      );
      expect(data.appTokens[0], '0');
      expect(data.appTokens[10], '18446744073709551615');
      expect(data.appTokens[11], '1');
      expect(
        () => parseKeyCache('{"10":"not-a-key"}', '{}'),
        throwsFormatException,
      );
      expect(
        () => parseKeyCache('{}', '{"10":"18446744073709551616"}'),
        throwsFormatException,
      );
      expect(() => parseKeyCache('{}', '{"10":123}'), throwsFormatException);
      expect(
        () => parseKeyCache('{"0":"${key('a')}"}', '{}'),
        throwsFormatException,
      );
    },
  );

  test('explicit sources keep keys, metadata and tokens independent', () async {
    final tokens = <String?>[];
    final cache = KeyCacheService(
      paths: paths,
      settings: settings,
      protect: protect,
      unprotect: unprotect,
      metadataLoader: (id, token) async {
        tokens.add(token);
        return SteamAppInfo.fromData(id, {
          'common': {'name': 'Game from token $token'},
          'depots': {'11': <String, dynamic>{}},
        });
      },
      httpClient: MockClient((request) async {
        final second = request.url.host == 'second.invalid';
        return http.Response(
          request.url.path.endsWith('depotkeys.json')
              ? jsonEncode({'11': key(second ? 'b' : 'a')})
              : jsonEncode({'10': second ? '222' : '111'}),
          200,
        );
      }),
    );
    services.add(cache);
    const second = KeyCacheSubscription(
      id: 'second',
      name: 'Second source',
      depotKeysUrl: 'https://second.invalid/depotkeys.json',
      tokenKeysUrl: 'https://second.invalid/appaccesstokens.json',
    );
    await cache.upsert(custom);
    await cache.upsert(second);
    await cache.update(custom.id);
    await cache.update(second.id);

    await cache.refreshAppMetadata(10, sourceId: custom.id);
    await cache.refreshAppMetadata(10, sourceId: second.id);
    expect(tokens, ['111', '222']);
    final first = await cache.generateOffline(10, sourceId: custom.id);
    final other = await cache.generateOffline(10, sourceId: second.id);
    expect(first.sourceName, custom.name);
    expect(first.name, 'Game from token 111');
    expect(first.lua, contains(key('a')));
    expect(first.lua, contains('addtoken(10, "111")'));
    expect(other.sourceName, second.name);
    expect(other.name, 'Game from token 222');
    expect(other.lua, contains(key('b')));
    expect(other.lua, contains('addtoken(10, "222")'));
    expect((await cache.readCache(second.id)).appTokens[10], '222');
    expect((await cache.readCache(custom.id)).appTokens[10], '111');

    final restored = service();
    await restored.load();
    expect(
      (await restored.generateOffline(10, sourceId: second.id)).name,
      'Game from token 222',
    );
  });

  test('subscriptions persist without a global active source', () async {
    final cache = service();
    await cache.load();
    await cache.remove('default');
    await cache.remove('steam-toolbox');
    await cache.upsert(custom);
    final persisted =
        jsonDecode(
              unprotect(
                await File(
                  paths.file('data/key-cache-subscriptions.json'),
                ).readAsString(),
              ),
            )
            as Map;
    expect(persisted.containsKey('activeId'), isFalse);
    await cache.update(custom.id);
    expect((await cache.readCache(custom.id)).appTokens[10], isNotNull);
    await cache.upsert(custom.copyWith(enabled: false));
    await expectLater(cache.readCache(custom.id), throwsStateError);
    await expectLater(cache.readCache('missing'), throwsStateError);
  });
}
