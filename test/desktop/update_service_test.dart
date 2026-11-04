import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/platform/desktop/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('version ordering', () {
    test('compares numeric components and ignores build metadata', () {
      expect(compareVersions('v1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0+5', '1.0.0+2'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });
    test('orders prereleases before stable', () {
      expect(compareVersions('1.0.0-rc.2', '1.0.0-rc.10'), lessThan(0));
      expect(compareVersions('1.0.0-rc.2', '1.0.0'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.0-beta'), greaterThan(0));
    });
    test('rejects an invalid remote version', () {
      expect(() => compareVersions('latest', '0.1.0'), throwsFormatException);
    });
  });

  test('unconfigured endpoint never checks the WPF upstream', () async {
    var requests = 0;
    final service = UpdateService(
      repository: '',
      client: MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    expect(service.isConfigured, isFalse);
    await expectLater(service.checkLatest('0.1.0'), throwsStateError);
    expect(requests, 0);
  });

  test('parses a real release shape and selects Windows assets', () async {
    final service = UpdateService(
      repository: 'example/FlSteamLua',
      client: MockClient((request) async {
        expect(request.url.path, '/repos/example/FlSteamLua/releases/latest');
        return http.Response(
          jsonEncode({
            'tag_name': 'v0.2.0',
            'html_url':
                'https://github.com/example/FlSteamLua/releases/tag/v0.2.0',
            'published_at': '2026-11-01T00:00:00Z',
            'body': 'Release notes',
            'assets': [
              {
                'name': 'FlSteamLua-windows-x64.zip',
                'size': 4,
                'digest': 'sha256:${sha256.convert(utf8.encode('test'))}',
                'browser_download_url':
                    'https://github.com/example/FlSteamLua/releases/download/v0.2.0/FlSteamLua-windows-x64.zip',
              },
            ],
          }),
          200,
        );
      }),
    );
    final release = await service.checkLatest('0.1.0');
    expect(release?.version, 'v0.2.0');
    expect(release?.windowsAsset?.size, 4);
    expect(release?.windowsAsset?.sha256, isNotNull);
  });

  test('prefers the setup executable over the portable ZIP', () async {
    final release = ApplicationRelease(
      version: 'v0.2.0',
      url: Uri.parse('https://github.com/example/app/releases/tag/v0.2.0'),
      notes: '',
      assets: [
        ReleaseAsset(
          name: 'FlSteamLua-windows-x64.zip',
          url: Uri.parse('https://github.com/example/app/portable.zip'),
          size: 10,
        ),
        ReleaseAsset(
          name: 'FlSteamLua-windows-x64-setup.exe',
          url: Uri.parse('https://github.com/example/app/setup.exe'),
          size: 20,
        ),
      ],
    );
    expect(release.windowsAsset?.name, contains('setup.exe'));
  });

  test('does not report current or older releases as an update', () async {
    final service = UpdateService(
      repository: 'example/app',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'tag_name': 'v0.1.0',
            'html_url': 'https://github.com/example/app/releases/tag/v0.1.0',
            'assets': [],
          }),
          200,
        ),
      ),
    );
    expect(await service.checkLatest('0.1.0'), isNull);
  });

  test('surfaces rate limiting instead of saying up to date', () async {
    final service = UpdateService(
      repository: 'example/app',
      client: MockClient((request) async => http.Response('{}', 403)),
    );
    await expectLater(
      service.checkLatest('0.1.0'),
      throwsA(isA<HttpException>()),
    );
  });

  test('failed size validation removes a partial download', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flsteamlua-update-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = UpdateService(
      repository: 'example/app',
      client: MockClient((request) async => http.Response('ab', 200)),
    );
    final asset = ReleaseAsset(
      name: 'app.zip',
      url: Uri.https('github.com', '/example/app.zip'),
      size: 4,
    );
    await expectLater(
      service.download(asset, directory),
      throwsA(isA<HttpException>()),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('cancelled download never becomes a completed installer', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flsteamlua-update-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = UpdateService(
      repository: 'example/app',
      client: MockClient((request) async => http.Response('abcd', 200)),
    );
    final progress = TaskProgress('test', 'Download')
      ..cancellationRequested = true;
    final task = TaskContext(progress, () {});
    final asset = ReleaseAsset(
      name: 'app.zip',
      url: Uri.https('github.com', '/example/app.zip'),
      size: 4,
    );
    await expectLater(
      service.download(asset, directory, task: task),
      throwsA(isA<TaskCancelled>()),
    );
    expect(await directory.list().toList(), isEmpty);
  });

  test('release download verifies the sidecar checksum', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flsteamlua-update-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final bytes = utf8.encode('verified update');
    final expected = sha256.convert(bytes).toString();
    final asset = ReleaseAsset(
      name: 'FlSteamLua-windows-x64.zip',
      url: Uri.https('github.com', '/example/app/update.zip'),
      size: bytes.length,
    );
    final release = ApplicationRelease(
      version: 'v0.2.0',
      url: Uri.parse('https://github.com/example/app/releases/tag/v0.2.0'),
      notes: '',
      assets: [
        asset,
        ReleaseAsset(
          name: '${asset.name}.sha256',
          url: Uri.https('github.com', '/example/app/update.zip.sha256'),
          size: expected.length,
        ),
      ],
    );
    final service = UpdateService(
      repository: 'example/app',
      client: MockClient((request) async {
        if (request.url.path.endsWith('.sha256')) {
          return http.Response('$expected  ${asset.name}\n', 200);
        }
        return http.Response.bytes(bytes, 200);
      }),
    );
    final file = await service.downloadRelease(release, directory);
    expect(await file.readAsBytes(), bytes);
  });

  test('release download deletes a checksum mismatch', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flsteamlua-update-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final asset = ReleaseAsset(
      name: 'FlSteamLua-windows-x64.zip',
      url: Uri.https('github.com', '/example/app/update.zip'),
      size: 4,
      sha256: List.filled(64, '0').join(),
    );
    final release = ApplicationRelease(
      version: 'v0.2.0',
      url: Uri.parse('https://github.com/example/app/releases/tag/v0.2.0'),
      notes: '',
      assets: [asset],
    );
    final service = UpdateService(
      repository: 'example/app',
      client: MockClient(
        (request) async => http.Response.bytes([1, 2, 3, 4], 200),
      ),
    );
    await expectLater(
      service.downloadRelease(release, directory),
      throwsFormatException,
    );
    expect(await directory.list().toList(), isEmpty);
  });
}
