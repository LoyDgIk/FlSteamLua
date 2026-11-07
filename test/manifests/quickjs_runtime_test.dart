import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:fl_steam_lua/features/manifests/manifest_script_runner.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    if (Platform.environment['FLUTTER_QJS_NEXT_LIBRARY'] != null) return;
    for (final mode in ['Release', 'Debug', 'Profile']) {
      final file = File(
        'build/windows/x64/runner/$mode/flutter_qjs_next_plugin.dll',
      );
      if (file.existsSync()) {
        // Windows shares loaded native modules across the test worker isolates.
        DynamicLibrary.open(file.absolute.path);
        return;
      }
    }
  });
  test('QuickJS worker awaits Dart HTTP and returns JSON', () async {
    final result = await const QuickJsManifestRunner().invoke(
      script: '''
        async function download(ctx) {
          ctx.log('requesting');
          const response = await ctx.http.get('https://fixture.test/' + ctx.params.appid);
          return {filename: ctx.params.appid + '.lua', encoding: 'text', content: response.text};
        }
      ''',
      function: 'download',
      params: {'appid': 440},
      request: (payload) async {
        expect(payload['url'], 'https://fixture.test/440');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return {'text': 'addappid(440)', 'status': 200, 'ok': true};
      },
      log: (_) {},
    );
    expect(result, {
      'filename': '440.lua',
      'encoding': 'text',
      'content': 'addappid(440)',
    });
  });

  test('SteamToolbox dynamic script resolves current key addresses', () async {
    final result = await const QuickJsManifestRunner().invoke(
      script: steamToolboxDynamicScript,
      function: 'download',
      params: const {},
      request: (payload) async {
        expect(
          payload['url'],
          'https://gitee.com/biaogeNB/SteamToolbox/raw/master/toolbox2.txt',
        );
        return {
          'status': 200,
          'ok': true,
          'text': '''
appaccesstokens：https://pan.invalid/current/appaccesstokens.json
depotkeys：https://pan.invalid/current/depotkeys.json
''',
        };
      },
      log: (_) {},
    );
    expect(result, {
      'depotKeysUrl': 'https://pan.invalid/current/depotkeys.json',
      'tokenKeysUrl': 'https://pan.invalid/current/appaccesstokens.json',
    });
  });

  for (final source in ['luatools', 'ryuu', 'hubcap', 'manifesthub2']) {
    test(
      '$source async script downloads through its existing endpoint',
      () async {
        final script = await File(
          'assets/manifest_sources/$source.js',
        ).readAsString();
        final result = await const QuickJsManifestRunner().invoke(
          script: script,
          function: 'download',
          params: {
            'appid': 440,
            'token': 'fixture-token',
            'authKey': 'fixture-token',
            'apiKey': 'fixture-token',
            'apikey': 'fixture-token',
            'fileType': 'zip',
          },
          request: (payload) async {
            expect(payload['method'], 'GET');
            final uri = Uri.parse(payload['url'] as String);
            expect(uri.scheme, 'https');
            expect(uri.toString(), contains('440'));
            return {
              'status': 200,
              'ok': true,
              'contentType': 'application/zip',
              'base64': base64Encode([80, 75, 3, 4]),
              'text': '',
            };
          },
          log: (_) {},
        );
        expect(result, isA<Map>());
        final artifact = result as Map;
        expect(artifact['filename'], '440.zip');
        expect(artifact['encoding'], 'base64');
        expect(artifact['content'], base64Encode([80, 75, 3, 4]));
      },
    );
  }

  for (final source in ['ryuu', 'hubcap']) {
    test(
      '$source fetches requested Lua and files in one source invocation',
      () async {
        final script = await File(
          'assets/manifest_sources/$source.js',
        ).readAsString();
        final responseTypes = <String>[];
        final result = await const QuickJsManifestRunner().invoke(
          script: script,
          function: 'download',
          params: {
            'appid': 440,
            'authKey': 'fixture-token',
            'apiKey': 'fixture-token',
            'fileType': 'zip',
            'requestedCapabilities': ['lua', 'manifestFiles'],
          },
          request: (payload) async {
            final options = payload['options'] as Map;
            final responseType = options['responseType'] as String;
            responseTypes.add(responseType);
            return {
              'status': 200,
              'ok': true,
              'contentType': responseType == 'text'
                  ? 'text/plain'
                  : 'application/zip',
              'text': responseType == 'text' ? 'addappid(440)' : '',
              'base64': responseType == 'base64'
                  ? base64Encode([80, 75, 3, 4])
                  : '',
            };
          },
          log: (_) {},
        );
        expect(responseTypes, ['text', 'base64']);
        final artifacts = (result as Map)['artifacts'] as List;
        expect(artifacts.map((value) => (value as Map)['filename']), [
          '440.lua',
          '440.zip',
        ]);
        expect((artifacts.first as Map)['content'], 'addappid(440)');
      },
    );
  }
}
