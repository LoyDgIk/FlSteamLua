import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/network/network_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory root;
  late SettingsStore settings;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('fl-network-');
    settings = SettingsStore(AppPaths(root.path));
  });
  tearDown(() async {
    settings.dispose();
    await root.delete(recursive: true);
  });

  test(
    'heybox is default and invalid stored options do not route requests',
    () async {
      final preferences = NetworkPreferences(
        settings,
        client: MockClient((request) async {
          fail('Direct cover selection must not look up metadata');
        }),
      );
      expect(preferences.coverSourceId, 'heybox');
      expect(preferences.mirrorHost, 'direct');
      await preferences.setCoverSource('direct');
      expect(
        await preferences.coverUrls(440, fallback: 'https://example.com/a.jpg'),
        ['https://example.com/a.jpg'],
      );
      await settings.set('githubMirror', 'unknown.example');
      expect(preferences.mirrorHost, 'direct');
      expect(
        () => preferences.setMirror('unknown.example'),
        throwsFormatException,
      );
      preferences.dispose();
    },
  );

  test('CDN template choice retains original image fallback', () async {
    final preferences = NetworkPreferences(settings);
    await preferences.setCoverSource('cloudflare');
    final urls = await preferences.coverUrls(
      440,
      fallback: 'https://example.com/cover.jpg',
    );
    expect(Uri.parse(urls.first).host, 'cdn.cloudflare.steamstatic.com');
    expect(urls.last, 'https://example.com/cover.jpg');
    preferences.dispose();
  });

  test('auto cover source is selectable', () async {
    final preferences = NetworkPreferences(
      settings,
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(preferences.coverSourceId, 'heybox');
    await preferences.setCoverSource('auto');
    expect(preferences.coverSourceId, 'auto');
    expect(
      NetworkPreferences.coverSources.map((source) => source.id),
      contains('auto'),
    );
    preferences.dispose();
  });

  test('fastly covers gain Dart-compatible Steam CDN fallbacks', () async {
    final preferences = NetworkPreferences(settings);
    await preferences.setCoverSource('direct');
    final urls = await preferences.coverUrls(
      440,
      fallback:
          'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/440/header.jpg',
    );
    expect(Uri.parse(urls.first).host, 'shared.fastly.steamstatic.com');
    expect(
      urls.map((url) => Uri.parse(url).host),
      containsAll([
        'shared.akamai.steamstatic.com',
        'cdn.akamai.steamstatic.com',
        'cdn.cloudflare.steamstatic.com',
      ]),
    );
    preferences.dispose();
  });

  test(
    'metadata sources parse provider response without guessing image URLs',
    () async {
      final client = MockClient((request) async {
        if (request.url.host == 'store.steampowered.com') {
          return http.Response(
            jsonEncode({
              '440': {
                'success': true,
                'data': {'header_image': 'https://cdn.example.com/store.jpg'},
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'result': {'image': 'https://cdn.example.com/heybox.jpg'},
          }),
          200,
        );
      });
      final preferences = NetworkPreferences(settings, client: client);
      await preferences.setCoverSource('store');
      expect(
        (await preferences.coverUrls(440)).first,
        'https://cdn.example.com/store.jpg',
      );
      await preferences.setCoverSource('heybox');
      expect(
        (await preferences.coverUrls(440)).first,
        'https://cdn.example.com/heybox.jpg',
      );
      preferences.dispose();
      client.close();
    },
  );

  test(
    'explicit mirror applies to a public release asset and falls back direct',
    () async {
      await settings.set('githubMirror', 'ghfast.top');
      final requests = <Uri>[];
      final client = NetworkHttpClient(
        settings: settings,
        inner: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            request.url.host == 'ghfast.top' ? 'unavailable' : 'asset',
            request.url.host == 'ghfast.top' ? 502 : 200,
          );
        }),
      );
      final url = Uri.parse(
        'https://github.com/owner/repo/releases/download/v1/asset.zip',
      );
      expect((await client.get(url)).body, 'asset');
      expect(requests.map((url) => url.host), ['ghfast.top', 'github.com']);
      expect(
        requests.first.path,
        '/https://github.com/owner/repo/releases/download/v1/asset.zip',
      );
      client.close();
    },
  );

  test(
    'authorization cookies queries API endpoints and private headers stay direct',
    () async {
      await settings.set('githubMirror', 'ghfast.top');
      final seen = <Uri>[];
      final client = NetworkHttpClient(
        settings: settings,
        inner: MockClient((request) async {
          seen.add(request.url);
          return http.Response('ok', 200);
        }),
      );
      final asset = Uri.parse(
        'https://github.com/owner/repo/releases/download/v1/asset.zip',
      );
      await client.get(asset, headers: {'Authorization': 'Bearer secret'});
      await client.get(asset, headers: {'Cookie': 'session=secret'});
      await client.get(asset, headers: {'X-Api-Key': 'secret'});
      await client.get(asset.replace(query: 'token=secret'));
      await client.get(
        Uri.parse('https://api.github.com/repos/owner/repo/releases'),
      );
      await client.post(asset);
      expect(seen.any((url) => url.host == 'ghfast.top'), isFalse);
      client.close();
    },
  );

  test(
    'raw public download keeps abort trigger across mirror transport',
    () async {
      await settings.set('githubMirror', 'gh-proxy.org');
      final abort = Completer<void>();
      final client = NetworkHttpClient(
        settings: settings,
        inner: _InspectClient((request) async {
          expect(request.url.host, 'gh-proxy.org');
          expect(request, isA<http.Abortable>());
          expect((request as http.Abortable).abortTrigger, same(abort.future));
          await request.finalize().drain<void>();
          return http.StreamedResponse(
            Stream.value(utf8.encode('public data')),
            200,
          );
        }),
      );
      final response = await client.send(
        http.AbortableRequest(
          'GET',
          Uri.parse(
            'https://raw.githubusercontent.com/owner/repo/main/file.lua',
          ),
          abortTrigger: abort.future,
        ),
      );
      expect(await response.stream.bytesToString(), 'public data');
      client.close();
    },
  );

  test(
    'custom GitHub mirror supports a base path and falls back direct',
    () async {
      final preferences = NetworkPreferences(settings);
      await preferences.setMirror(
        NetworkPreferences.customMirrorId,
        custom: 'https://mirror.example.com/proxy/',
      );
      expect(preferences.mirrorSelection, NetworkPreferences.customMirrorId);
      expect(preferences.customMirror, 'https://mirror.example.com/proxy');
      expect(
        () => preferences.setMirror(
          NetworkPreferences.customMirrorId,
          custom: 'http://insecure.example.com',
        ),
        throwsFormatException,
      );

      final requests = <Uri>[];
      final client = NetworkHttpClient(
        settings: settings,
        inner: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            request.url.host == 'mirror.example.com' ? 'unavailable' : 'asset',
            request.url.host == 'mirror.example.com' ? 502 : 200,
          );
        }),
      );
      final url = Uri.parse(
        'https://github.com/owner/repo/releases/download/v1/asset.zip',
      );
      expect((await client.get(url)).body, 'asset');
      expect(requests.map((uri) => uri.host), [
        'mirror.example.com',
        'github.com',
      ]);
      expect(
        requests.first.path,
        '/proxy/https://github.com/owner/repo/releases/download/v1/asset.zip',
      );
      client.close();
      preferences.dispose();
    },
  );

  test(
    'latency tests report HTTP failure and never change selected options',
    () async {
      final preferences = NetworkPreferences(
        settings,
        client: MockClient((request) async {
          return http.Response(
            request.url.host == 'raw.githubusercontent.com'
                ? 'GNU GENERAL PUBLIC LICENSE'
                : 'unavailable',
            request.url.host == 'raw.githubusercontent.com' ? 200 : 503,
          );
        }),
      );
      final results = await preferences.testMirrors();
      expect(results.first.succeeded, isTrue);
      expect(results.skip(1).every((result) => !result.succeeded), isTrue);
      expect(preferences.mirrorHost, 'direct');
      preferences.dispose();
    },
  );
}

class _InspectClient extends http.BaseClient {
  _InspectClient(this.handle);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handle;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handle(request);
}
