import 'dart:async' show Completer;
import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/manifests/manifest_http_host.dart';
import 'package:fl_steam_lua/features/manifests/encrypted_secret_store.dart';
import 'package:fl_steam_lua/features/manifests/manifest_script_parser.dart';
import 'package:fl_steam_lua/features/manifests/manifest_script_runner.dart';
import 'package:fl_steam_lua/features/manifests/manifest_source_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

class _LoopbackHttpOverrides extends HttpOverrides {}

class _MemorySecrets implements SecretValueStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FixtureRunner implements ManifestScriptRunner {
  _FixtureRunner(this.action);
  final Future<Object?> Function(
    Map<String, Object?>,
    ManifestRequestHandler,
    void Function(String),
  )
  action;

  @override
  Future<Object?> invoke({
    required String script,
    required String function,
    required Map<String, Object?> params,
    required ManifestRequestHandler request,
    required void Function(String) log,
    TaskContext? task,
  }) => action(params, request, log);
}

Future<String> _loadScript(String path) => File(path).readAsString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'source parser reads metadata, quoted attributes and parameter defaults',
    () {
      final definition = ManifestScriptParser.parse('''
      // @id fixture
      // @name Fixture source
      // @param key type=password label="Access key" required=true
      // @param mode type=text default="zip file"
      async function download(ctx) { return {}; }
    ''');
      expect(definition.id, 'fixture');
      expect(definition.parameters.first.isSecret, isTrue);
      expect(definition.parameters.first.label, 'Access key');
      expect(definition.parameters.last.defaultValue, 'zip file');
      expect(
        () => ManifestScriptParser.parse('// @id ../bad'),
        throwsFormatException,
      );
      expect(
        () => ManifestScriptParser.parse(
          '// @id good\n// @param key\n// @param key',
        ),
        throwsFormatException,
      );
    },
  );

  test('all four bundled sources await host requests', () async {
    for (final name in ['luatools', 'ryuu', 'hubcap', 'manifesthub2']) {
      final script = await File(
        'assets/manifest_sources/$name.js',
      ).readAsString();
      final definition = ManifestScriptParser.parse(script, builtIn: true);
      expect(definition.id, name);
      expect(definition.version, '2.0.0');
      expect(script, contains('await ctx.http.get('));
      expect(
        script.replaceAll('await ctx.http.get(', ''),
        isNot(contains('ctx.http.get(')),
      );
    }
  });

  test('built-in scripts can be edited, persisted and restored', () async {
    final directory = await Directory.systemTemp.createTemp(
      'manifest-script-edit-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final paths = AppPaths(directory.path);
    final service = ManifestSourceService(
      paths: paths,
      assetLoader: _loadScript,
    );
    addTearDown(service.dispose);
    await service.initialize();
    final original = service.scriptFor('luatools');
    final edited = '$original\n// edited in FlSteamLua';

    await service.saveScript('luatools', edited);
    expect(service.scriptFor('luatools'), contains('edited in FlSteamLua'));
    expect(
      service.sources.singleWhere((it) => it.id == 'luatools').builtIn,
      true,
    );
    expect(await service.scriptFileFor('luatools').exists(), true);

    final reloaded = ManifestSourceService(
      paths: paths,
      assetLoader: _loadScript,
    );
    addTearDown(reloaded.dispose);
    await reloaded.initialize();
    expect(reloaded.scriptFor('luatools'), contains('edited in FlSteamLua'));
    expect(
      reloaded.sources.singleWhere((it) => it.id == 'luatools').builtIn,
      true,
    );

    await reloaded.restoreBuiltInScript('luatools');
    expect(
      reloaded.scriptFor('luatools'),
      isNot(contains('edited in FlSteamLua')),
    );
    expect(await reloaded.scriptFileFor('luatools').exists(), false);
  });

  test(
    'host bridges JSON/text/base64 and POST without exposing tokens in errors',
    () async {
      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {'hello': 'world'});
          expect(request.headers['content-type'], contains('application/json'));
        }
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final host = ManifestHttpHost(client);
      final json = await host.request({
        'method': 'GET',
        'url': 'https://source.test',
        'options': {'responseType': 'json'},
      });
      expect(json['data'], {'ok': true});
      final binary = await host.request({
        'method': 'POST',
        'url': 'https://source.test',
        'options': {
          'responseType': 'base64',
          'body': {'hello': 'world'},
        },
      });
      expect(
        utf8.decode(base64Decode(binary['base64'] as String)),
        '{"ok":true}',
      );
      expect(binary['text'], '');
    },
  );

  test(
    'host classifies HTTP failures, rejects schemes and response size overflow',
    () async {
      final host = ManifestHttpHost(
        MockClient((_) async => http.Response('denied', 403)),
      );
      await expectLater(
        host.request({'method': 'GET', 'url': 'https://source.test'}),
        throwsA(
          isA<ManifestSourceException>().having(
            (e) => e.kind,
            'kind',
            'invalid_key',
          ),
        ),
      );
      final response = await host.request({
        'method': 'GET',
        'url': 'https://source.test',
        'options': {'allowNonSuccess': true},
      });
      expect(response['status'], 403);
      await expectLater(
        host.request({'method': 'GET', 'url': 'file:///etc/passwd'}),
        throwsA(isA<ManifestSourceException>()),
      );
      final large = ManifestHttpHost(
        MockClient((_) async => http.Response('12345', 200)),
      );
      await expectLater(
        large.request({
          'method': 'GET',
          'url': 'https://source.test',
          'options': {'maxBytes': 4},
        }),
        throwsA(
          isA<ManifestSourceException>().having(
            (e) => e.kind,
            'kind',
            'invalid_response',
          ),
        ),
      );
    },
  );

  test(
    'host request timeout and cancellation are observable failures',
    () async {
      final delayed = ManifestHttpHost(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
          return http.Response('late', 200);
        }),
      );
      await expectLater(
        delayed.request({
          'method': 'GET',
          'url': 'https://source.test',
          'options': {'timeout': 1},
        }),
        throwsA(
          isA<ManifestSourceException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      final task = TaskProgress('fixture', 'Download')
        ..cancellationRequested = true;
      await expectLater(
        delayed.request({
          'method': 'GET',
          'url': 'https://source.test',
        }, task: TaskContext(task, () {})),
        throwsA(isA<TaskCancelled>()),
      );
    },
  );

  test('cancelling an in-flight HTTP request aborts the connection', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = Completer<void>();
    server.listen((request) {
      if (!seen.isCompleted) seen.complete();
    });
    final client = IOClient(_LoopbackHttpOverrides().createHttpClient(null));
    addTearDown(() async {
      client.close();
      await server.close(force: true);
    });
    final task = TaskProgress('cancel-http', 'Download');
    final operation = ManifestHttpHost(client).request({
      'method': 'GET',
      'url': 'http://127.0.0.1:${server.port}/held',
    }, task: TaskContext(task, () {}));
    final cancellationResult = expectLater(
      operation.timeout(const Duration(seconds: 3)),
      throwsA(isA<TaskCancelled>()),
    );
    await seen.future.timeout(const Duration(seconds: 3));
    task.cancellationRequested = true;
    await cancellationResult;
  });

  test(
    'source settings never persist password values in the public config',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flsteam-manifest-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final secrets = _MemorySecrets();
      final service = ManifestSourceService(
        paths: AppPaths(directory.path),
        secrets: secrets,
        assetLoader: _loadScript,
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.saveConfig('ryuu', {
        'authKey': 'sensitive-key',
        'fileType': 'lua',
      });
      final publicConfig = await File(
        '${directory.path}/data/manifest-sources.json',
      ).readAsString();
      expect(publicConfig, isNot(contains('sensitive-key')));
      expect(secrets.values['ryuu.authKey'], 'sensitive-key');
      expect(service.configFor('ryuu').values['authKey'], 'sensitive-key');
      await service.initialize();
      expect(service.configFor('ryuu').values['authKey'], 'sensitive-key');
    },
  );

  test(
    'Windows credentials persist encrypted and round-trip for this user',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flsteam-manifest-secret-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = EncryptedManifestSecretStore(AppPaths(directory.path));
      await store.write('source.key', 'fixture-secret-value');
      expect(await store.read('source.key'), 'fixture-secret-value');
      final contents = await File(
        '${directory.path}/data/manifest-secrets.json',
      ).readAsString();
      expect(contents, isNot(contains('fixture-secret-value')));
      await store.delete('source.key');
      expect(await store.read('source.key'), isNull);
    },
  );

  test(
    'download passes AppID, saves the artifact and redacts script logs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flsteam-manifest-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final runner = _FixtureRunner((params, request, log) async {
        expect(params['appid'], 440);
        expect(params['authKey'], 'sensitive-key');
        log('key=sensitive-key');
        final result = await request({
          'method': 'GET',
          'url': 'https://source.test/440',
          'options': {},
        });
        return {
          'filename': '440.lua',
          'encoding': 'text',
          'content': result['text'],
        };
      });
      final service = ManifestSourceService(
        paths: AppPaths(directory.path),
        secrets: _MemorySecrets(),
        assetLoader: _loadScript,
        runner: runner,
        client: MockClient((_) async => http.Response('addappid(440)', 200)),
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.saveConfig('ryuu', {
        'authKey': 'sensitive-key',
        'fileType': 'lua',
      });
      final artifact = await service.download('ryuu', 440);
      expect(artifact.logs, ['key=[redacted]']);
      final file = await service.downloadToFile('ryuu', 440);
      expect(await file.readAsString(), 'addappid(440)');
    },
  );

  test(
    'download refuses traversal names and source failure payloads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flsteam-manifest-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var result = <String, Object?>{
        'filename': '../440.lua',
        'content': 'payload',
      };
      final service = ManifestSourceService(
        paths: AppPaths(directory.path),
        secrets: _MemorySecrets(),
        assetLoader: _loadScript,
        runner: _FixtureRunner((_, _, _) async => result),
      );
      addTearDown(service.dispose);
      await service.initialize();
      await service.saveConfig('ryuu', {'authKey': 'test-key'});
      for (final filename in [
        '../440.lua',
        r'..\440.lua',
        '440.zip:payload.lua',
        'CON.lua',
      ]) {
        result = {'filename': filename, 'content': 'payload'};
        await expectLater(
          service.download('ryuu', 440),
          throwsA(
            isA<ManifestSourceException>().having(
              (e) => e.kind,
              'kind',
              'invalid_response',
            ),
          ),
        );
      }
      result = {
        'error': 'Daily quota used',
        'errorKind': 'quota',
        'statusCode': 429,
      };
      await expectLater(
        service.download('ryuu', 440),
        throwsA(
          isA<ManifestSourceException>().having((e) => e.kind, 'kind', 'quota'),
        ),
      );
    },
  );

  test(
    'clears downloaded manifest packages only for the selected AppID',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flsteam-manifest-clear-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final paths = AppPaths(directory.path);
      final service = ManifestSourceService(
        paths: paths,
        assetLoader: _loadScript,
      );
      addTearDown(service.dispose);
      final root = paths.directory('downloads/manifests');
      for (final name in ['1-440', '2-440', '3-441']) {
        final folder = Directory(p.join(root.path, name));
        await folder.create(recursive: true);
        await File(p.join(folder.path, '440.lua')).writeAsString('payload');
      }

      expect(await service.clearDownloadedManifests(440), 2);
      expect(
        await root.list().map((entity) => p.basename(entity.path)).toList(),
        ['3-441'],
      );
    },
  );
}
