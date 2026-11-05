import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/steam_process_actions.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/process_observer.dart';
import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:fl_steam_lua/features/steam_versions/steam_version_service.dart';
import 'package:fl_steam_lua/features/steam_versions/steam_version_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

Uint8List bootstrapBytes(String arch) {
  final bytes = Uint8List(128);
  bytes[0] = 77;
  bytes[1] = 90;
  final view = ByteData.sublistView(bytes);
  view.setUint32(0x3c, 64, Endian.little);
  view.setUint32(64, 0x00004550, Endian.little);
  view.setUint16(68, arch == 'win64' ? 0x8664 : 0x14c, Endian.little);
  return bytes;
}

({SteamClientVersion version, Map<String, List<int>> files}) fixture(
  String arch,
  String build, {
  String source = 'official',
  String? snapshot,
  bool compressed = false,
}) {
  final executable = bootstrapBytes(arch);
  final zip = ZipEncoder().encode(
    Archive()..addFile(ArchiveFile('steam.exe', executable.length, executable)),
  );
  final payload = utf8.encode('client-data-$arch-$build');
  final files = <String, List<int>>{
    'steam_$arch.zip.fixture': zip,
    'public.zip.fixture': payload,
  };
  final public = <String, String>{
    'file': 'public.zip.fixture',
    'size': '${payload.length}',
    'sha2': sha256.convert(payload).toString(),
  };
  if (compressed) {
    files['public.zip.vz.fixture_4'] = [1, 2, 3, 4];
    public.addAll({
      'zipvz': 'public.zip.vz.fixture_4',
      'sha2vz': sha256.convert([1, 2, 3, 4]).toString(),
    });
  }
  final text = Kv1.stringify({
    arch: {
      'version': build,
      'public_all': public,
      'steam_$arch': {
        'file': 'steam_$arch.zip.fixture',
        'size': '${zip.length}',
        'sha2': sha256.convert(zip).toString(),
        'IsBootstrapperPackage': '1',
      },
    },
  });
  return (
    version: SteamClientVersion(
      arch: arch,
      build: build,
      manifest: text,
      source: source,
      manifestUrl: '${SteamVersionService.cdn}/steam_client_$arch',
      snapshot: snapshot,
    ),
    files: files,
  );
}

void main() {
  late Directory temp;
  late AppPaths paths;
  late SettingsStore settings;
  late LibraryService library;
  late SteamVersionService service;
  late String steam;
  final win64 = fixture('win64', '1792618285'),
      win32 = fixture('win32', '1750000000');
  Future<File> write(String path, String data) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    return f.writeAsString(data);
  }

  SteamVersionService create({
    http.Client? client,
    SteamVersionRunner? runner,
    ProcessSnapshotReader? processes,
    Future<void> Function(File, List<int>)? writer,
  }) => SteamVersionService(
    paths: paths,
    settings: settings,
    library: library,
    builtInCatalog: () async => '{"versions":[]}',
    client:
        client ??
        MockClient((request) async {
          final name = request.url.pathSegments.last;
          if (name == 'steam_client_win64') {
            return http.Response(win64.version.manifest, 200);
          }
          if (name == 'steam_client_win32') {
            return http.Response(win32.version.manifest, 200);
          }
          final bytes = win64.files[name];
          return bytes == null
              ? http.Response('missing', 404)
              : http.Response.bytes(bytes, 200);
        }),
    runner: runner,
    processReader: processes ?? () async => [],
    writer: writer,
  );
  Future<void> stage({
    required String executable,
    required String workingDirectory,
    required String packagesUrl,
    TaskContext? context,
  }) async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse('$packagesUrl/steam_client_win64'),
      );
      expect(response.body, win64.version.manifest);
      final data = await client.get(
        Uri.parse('$packagesUrl/public.zip.fixture'),
      );
      expect(data.bodyBytes, win64.files['public.zip.fixture']);
      await write(
        p.join(workingDirectory, 'package', 'steam_client_win64.manifest'),
        win64.version.manifest,
      );
      await write(p.join(workingDirectory, 'steamclient64.dll'), 'new-client');
      await write(p.join(workingDirectory, 'new-client-file'), 'new');
      await write(
        p.join(workingDirectory, 'package', 'steam_client_win64.installed'),
        'steam.exe,128;1;0\nsteamclient64.dll,10;1;0\nnew-client-file,3;1;0\n',
      );
      await write(p.join(workingDirectory, 'config', 'do-not-copy'), 'bad');
      await write(p.join(workingDirectory, 'opensteamtool.dll'), 'bad-plugin');
    } finally {
      client.close();
    }
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('steam-versions-');
    paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    steam = p.join(temp.path, 'Steam');
    await write(p.join(steam, 'steam.exe'), 'old-exe');
    await settings.set('steamPath', steam);
    library = LibraryService(
      paths: paths,
      settings: settings,
      processSnapshotReader: () async => [],
    );
    service = create(runner: stage);
  });
  tearDown(() async {
    service.dispose();
    library.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });
  Future<void> oldInstall() async {
    await write(
      p.join(steam, 'package', 'steam_client_win32.manifest'),
      win32.version.manifest,
    );
    await write(
      p.join(steam, 'package', 'steam_client_win32.installed'),
      'steam.exe,7;1;0\nobsolete.dll,3;1;0\n',
    );
    await write(p.join(steam, 'obsolete.dll'), 'old');
    await write(p.join(steam, 'steamclient64.dll'), 'old-client');
    await write(p.join(steam, 'Steam.cfg'), '# keep\nOtherSetting=1\n');
    await write(p.join(steam, 'config', 'loginusers.vdf'), '"users" {}');
    await write(p.join(steam, 'steamapps', 'keep'), 'game');
    await write(p.join(steam, 'opensteamtool.dll'), 'plugin');
    await write(p.join(steam, 'config', 'lua', '440.lua'), 'lua');
  }

  test(
    'official manifests preserve parent and nested packages with preferred vz variants',
    () {
      for (final arch in ['win64', 'win32']) {
        final parsed = parseSteamClientManifest(
          File(
            'test/steam_versions/fixtures/steam_client_$arch.manifest',
          ).readAsStringSync(),
        );
        expect(parsed.arch, arch);
        expect(
          parsed.packages.any((v) => v.section == 'steam_$arch/steamchina'),
          isTrue,
        );
        expect(
          parsed.packages.any((v) => v.section == 'steam_$arch' && v.bootstrap),
          isTrue,
        );
        expect(parsed.packages.first.preferred.name, contains('.zip.vz.'));
      }
    },
  );
  test('manifest rejects traversal and missing checksums', () {
    expect(
      () => parseSteamClientManifest(
        win64.version.manifest.replaceAll('public.zip.fixture', '../escape'),
      ),
      throwsFormatException,
    );
    expect(
      () => parseSteamClientManifest(
        win64.version.manifest.replaceFirst(
          sha256.convert(win64.files['public.zip.fixture']!).toString(),
          'bad',
        ),
      ),
      throwsFormatException,
    );
  });
  test(
    'current version uses active installed-index timestamp, not merely downloaded manifests',
    () async {
      await oldInstall();
      await write(
        p.join(steam, 'package', 'steam_client_win64.manifest'),
        win64.version.manifest,
      );
      final info = await inspectInstallation(steam);
      expect(info.arch, 'win32');
      expect(info.build, win32.version.build);
    },
  );
  test(
    'latest catalogue persists offline and download verifies every object',
    () async {
      await service.latest();
      expect(service.versions.length, 2);
      await service.download(win64.version);
      expect(
        service.downloadedCounts[win64.version.id],
        win64.version.files.length,
      );
      service.dispose();
      service = create(
        client: MockClient((_) async => throw StateError('offline')),
      );
      await service.load();
      expect(service.versions.length, 2);
      await service.verify(win64.version);
    },
  );
  test('bad downloaded checksum cannot enable installation', () async {
    service.dispose();
    service = create(
      client: MockClient((_) async => http.Response('corrupt', 200)),
      runner: stage,
    );
    await expectLater(service.download(win64.version), throwsFormatException);
    expect(await File(p.join(steam, 'steam.exe')).readAsString(), 'old-exe');
    expect(await service.backups(), isEmpty);
  });
  test(
    'resume requests the correct range and verifies completed bytes',
    () async {
      final calls = <String, String?>{};
      service.dispose();
      service = create(
        client: MockClient((request) async {
          final name = request.url.pathSegments.last,
              bytes = win64.files[request.url.pathSegments.last]!;
          calls[name] = request.headers['range'];
          if (request.headers['range'] != null) {
            return http.Response.bytes(
              bytes.sublist(3),
              206,
              headers: {
                'content-range': 'bytes 3-${bytes.length - 1}/${bytes.length}',
              },
            );
          }
          return http.Response.bytes(bytes, 200);
        }),
      );
      final partial = File(
        p.join(service.directory(win64.version), 'public.zip.fixture.part'),
      );
      await partial.parent.create(recursive: true);
      await partial.writeAsBytes(
        win64.files['public.zip.fixture']!.sublist(0, 3),
      );
      await service.download(win64.version);
      expect(calls['public.zip.fixture'], 'bytes=3-');
      await service.verify(win64.version);
    },
  );
  test(
    'historical package falls back from missing CDN object to its recorded snapshot',
    () async {
      final historical = fixture(
        'win64',
        '1792618285',
        source: 'archive',
        snapshot: '20261022000000',
      );
      final hosts = <String>[];
      service.dispose();
      service = create(
        client: MockClient((r) async {
          hosts.add(r.url.host);
          return r.url.host == 'media.steampowered.com'
              ? http.Response('', 404)
              : http.Response.bytes(
                  historical.files[r.url.pathSegments.last]!,
                  200,
                );
        }),
      );
      await service.download(historical.version);
      expect(hosts, contains('web.archive.org'));
      await service.verify(historical.version);
    },
  );
  test(
    'offline catalogue immediately provides historical versions without HTTP',
    () async {
      var calls = 0;
      service.dispose();
      service = SteamVersionService(
        paths: paths,
        settings: settings,
        library: library,
        builtInCatalog: () =>
            File('assets/steam_versions/catalog.json').readAsString(),
        client: MockClient((_) async {
          calls++;
          throw StateError('offline');
        }),
        processReader: () async => [],
      );
      await service.load();
      expect(service.versions.length, greaterThan(50));
      expect(
        service.versions.any(
          (v) => v.build == '1682573004' && v.arch == 'win32',
        ),
        isTrue,
      );
      expect(service.versions.any((v) => v.arch == 'win64'), isTrue);
      expect(service.versions.every((v) => !v.hasManifest), isTrue);
      expect(calls, 0);
    },
  );

  test(
    'refresh discovers future releases and history without downloading every manifest',
    () async {
      final future = fixture('win64', '1892618285');
      final calls = <Uri>[];
      service.dispose();
      service = create(
        client: MockClient((request) async {
          calls.add(request.url);
          if (request.url.host == 'media.steampowered.com') {
            return http.Response(
              request.url.path.endsWith('win64')
                  ? future.version.manifest
                  : win32.version.manifest,
              200,
            );
          }
          final arch = request.url.queryParameters['url']!.endsWith('win64')
              ? 'win64'
              : 'win32';
          expect(request.url.queryParameters.containsKey('limit'), isFalse);
          return http.Response(
            jsonEncode([
              ['timestamp', 'original'],
              [
                '20261106090000',
                'http://media.steampowered.com/client/steam_client_$arch',
              ],
            ]),
            200,
          );
        }),
      );
      await service.refreshCatalog();
      expect(service.versions.any((v) => v.build == '1892618285'), isTrue);
      expect(service.versions.where((v) => v.build.isEmpty), hasLength(2));
      expect(calls, hasLength(4));
      expect(calls.where((u) => u.path.startsWith('/web/')), isEmpty);
    },
  );

  test(
    'history index is cached and duplicate snapshots collapse after lazy manifest resolution',
    () async {
      final calls = <Uri>[];
      service.dispose();
      service = create(
        client: MockClient((request) async {
          calls.add(request.url);
          if (request.url.path.contains('/cdx/')) {
            return http.Response(
              jsonEncode([
                ['timestamp', 'original'],
                [
                  '20250101000000',
                  'http://media.steampowered.com/client/steam_client_win32',
                ],
                [
                  '20250201000000',
                  'http://media.steampowered.com/client/steam_client_win32',
                ],
              ]),
              200,
            );
          }
          return http.Response.bytes(
            gzip.encode(utf8.encode(win32.version.manifest)),
            200,
          );
        }),
      );
      await service.history(arch: 'win32');
      expect(service.versions, hasLength(2));
      expect(service.versions.every((v) => !v.hasManifest), isTrue);
      expect(calls, hasLength(1));
      final pending = service.versions.toList();
      final resolved = await service.resolveVersion(pending.first);
      expect(resolved.build, win32.version.build);
      expect(resolved.hasManifest, isTrue);
      await service.resolveVersion(pending.last);
      expect(service.versions, hasLength(1));
      calls.clear();
      await service.load();
      await service.history(arch: 'win32');
      await service.resolveVersion(pending.first);
      expect(calls, isEmpty);
      expect(service.versions, hasLength(1));
    },
  );

  test(
    'expired indexes refresh independently of permanent selected manifest cache',
    () async {
      final now = DateTime.utc(2026, 11, 6);
      var clock = now;
      final calls = <Uri>[];
      service.dispose();
      service = SteamVersionService(
        paths: paths,
        settings: settings,
        library: library,
        builtInCatalog: () async => '{"versions":[]}',
        clock: () => clock,
        processReader: () async => [],
        client: MockClient((request) async {
          calls.add(request.url);
          return request.url.path.contains('/cdx/')
              ? http.Response(
                  jsonEncode([
                    ['timestamp', 'original'],
                    [
                      '20250101000000',
                      'http://media.steampowered.com/client/steam_client_win32',
                    ],
                  ]),
                  200,
                )
              : http.Response(win32.version.manifest, 200);
        }),
      );
      await service.history(arch: 'win32');
      final item = service.versions.single;
      await service.resolveVersion(item);
      calls.clear();
      await service.history(arch: 'win32');
      await service.resolveVersion(item);
      expect(calls, isEmpty);
      clock = now.add(const Duration(hours: 25));
      await service.history(arch: 'win32');
      await service.resolveVersion(item);
      expect(calls, hasLength(1));
      expect(calls.single.path, contains('/cdx/'));
      calls.clear();
      await service.history(arch: 'win32', forceRefresh: true);
      expect(calls, hasLength(1));
      await service.resolveVersion(item, forceRefresh: true);
      expect(calls, hasLength(2));
    },
  );

  test(
    'custom Wayback is the only archive endpoint and errors never trigger original-site fallback',
    () async {
      final urls = <Uri>[];
      service.dispose();
      service = create(
        client: MockClient((request) async {
          urls.add(request.url);
          return http.Response('<html>challenge</html>', 200);
        }),
      );
      expect(service.waybackBase, 'https://web.archive.org');
      await service.setWaybackBase('https://mirror.example/archive/');
      await expectLater(service.history(arch: 'win32'), throwsFormatException);
      expect(urls, hasLength(1));
      expect(urls.single.host, 'mirror.example');
      expect(urls.single.path, '/archive/cdx/search/cdx');
      await expectLater(
        service.setWaybackBase('http://mirror.example'),
        throwsFormatException,
      );
      await expectLater(
        service.setWaybackBase('https://user:pass@mirror.example'),
        throwsFormatException,
      );
    },
  );

  test(
    'archived downloads use CDN then the configured archive without other hosts',
    () async {
      final historical = fixture(
        'win64',
        '1792618285',
        source: 'archive',
        snapshot: '20261022000000',
      );
      final hosts = <String>[];
      service.dispose();
      service = create(
        client: MockClient((r) async {
          hosts.add(r.url.host);
          return r.url.host == 'media.steampowered.com'
              ? http.Response('', 404)
              : http.Response.bytes(
                  historical.files[r.url.pathSegments.last]!,
                  200,
                );
        }),
      );
      await service.setWaybackBase('https://custom.example');
      await service.download(historical.version);
      expect(hosts.toSet(), {'media.steampowered.com', 'custom.example'});
      await service.verify(historical.version);
    },
  );

  test(
    'loopback server supports manifest aliases, ranges and denies unrelated paths',
    () async {
      await service.download(win64.version);
      final server = SteamPackageServer(
        directory: service.directory(win64.version),
        arch: 'win64',
        files: win64.version.files.map((v) => v.name).toSet(),
      );
      await server.start();
      final client = http.Client();
      try {
        expect(
          (await client.get(
            Uri.parse('${server.url}/steam_client_win32'),
          )).body,
          win64.version.manifest,
        );
        final range = await client.get(
          Uri.parse('${server.url}/public.zip.fixture'),
          headers: {'Range': 'bytes=2-4'},
        );
        expect(range.statusCode, 206);
        expect(
          range.bodyBytes,
          win64.files['public.zip.fixture']!.sublist(2, 5),
        );
        expect(
          (await client.get(
            Uri.parse('${server.url}/not-a-package'),
          )).statusCode,
          404,
        );
        expect(
          (await client.get(Uri.parse('${server.url}/steam.exe'))).statusCode,
          404,
        );
      } finally {
        client.close();
        await server.close();
      }
    },
  );
  test(
    'staged install preserves games config and plugins; rollback restores absent files and obsolete client',
    () async {
      await oldInstall();
      await service.latest();
      await service.download(win64.version);
      final backup = await service.install(win64.version);
      expect((await inspectInstallation(steam)).build, win64.version.build);
      expect(await File(p.join(steam, 'obsolete.dll')).exists(), isFalse);
      expect(
        await File(p.join(steam, 'steamapps', 'keep')).readAsString(),
        'game',
      );
      expect(
        await File(p.join(steam, 'opensteamtool.dll')).readAsString(),
        'plugin',
      );
      expect(
        await File(p.join(steam, 'config', 'lua', '440.lua')).readAsString(),
        'lua',
      );
      expect(
        await File(p.join(steam, 'config', 'do-not-copy')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(steam, 'Steam.cfg')).readAsString(),
        contains('OtherSetting=1'),
      );
      expect(
        await File(p.join(steam, 'Steam.cfg')).readAsString(),
        '# keep\nOtherSetting=1\n',
      );
      await File(
        p.join(steam, 'Steam.cfg'),
      ).writeAsString('# changed separately\nBootStrapperInhibitAll=enable\n');
      await service.restoreBackup(backup);
      expect(await File(p.join(steam, 'steam.exe')).readAsString(), 'old-exe');
      expect(await File(p.join(steam, 'obsolete.dll')).readAsString(), 'old');
      expect(await File(p.join(steam, 'new-client-file')).exists(), isFalse);
      expect(
        await File(p.join(steam, 'Steam.cfg')).readAsString(),
        '# changed separately\nBootStrapperInhibitAll=enable\n',
      );
    },
  );
  test(
    'win32 bootstrap accepts the win64 manifest alias and installed index',
    () async {
      service.dispose();
      service = create(
        client: MockClient(
          (request) async => http.Response.bytes(
            win32.files[request.url.pathSegments.last]!,
            200,
          ),
        ),
        runner:
            ({
              required executable,
              required workingDirectory,
              required packagesUrl,
              context,
            }) async {
              final client = http.Client();
              try {
                final response = await client.get(
                  Uri.parse('$packagesUrl/steam_client_win64'),
                );
                expect(response.body, win32.version.manifest);
                await write(
                  p.join(
                    workingDirectory,
                    'package',
                    'steam_client_win64.manifest',
                  ),
                  response.body,
                );
                await write(
                  p.join(workingDirectory, 'steamclient.dll'),
                  '32-client',
                );
                await write(
                  p.join(
                    workingDirectory,
                    'package',
                    'steam_client_win64.installed',
                  ),
                  'steam.exe,128;1;0\nsteamclient.dll,9;1;0\n',
                );
              } finally {
                client.close();
              }
            },
      );
      await service.download(win32.version);
      await service.install(win32.version);
      final result = await inspectInstallation(steam);
      expect(result.arch, 'win32');
      expect(result.build, win32.version.build);
    },
  );

  test(
    'partial client promotion failure restores all modified files',
    () async {
      await oldInstall();
      var writes = 0;
      service.dispose();
      service = create(
        runner: stage,
        writer: (file, bytes) async {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
          if (++writes == 2) {
            throw const FileSystemException('fixture write failure');
          }
        },
      );
      await service.download(win64.version);
      await expectLater(
        service.install(win64.version),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(p.join(steam, 'steam.exe')).readAsString(), 'old-exe');
      expect(
        await File(p.join(steam, 'steamclient64.dll')).readAsString(),
        'old-client',
      );
      expect(await File(p.join(steam, 'obsolete.dll')).readAsString(), 'old');
      expect(await File(p.join(steam, 'new-client-file')).exists(), isFalse);
    },
  );
  test('cancelled staged install never modifies the destination', () async {
    final tasks = TaskCenter();
    service.dispose();
    service = create(
      runner:
          ({
            required executable,
            required workingDirectory,
            required packagesUrl,
            context,
          }) async {
            tasks.cancel(context!.task.id);
          },
    );
    await service.download(win64.version);
    await expectLater(
      tasks.run(
        'install',
        (task) => service.install(win64.version, context: task),
      ),
      throwsA(isA<TaskCancelled>()),
    );
    expect(await File(p.join(steam, 'steam.exe')).readAsString(), 'old-exe');
    expect(await service.backups(), isEmpty);
    tasks.dispose();
  });
  test(
    'running Steam and incomplete installation are rejected before replacement',
    () async {
      service.dispose();
      service = create(
        runner: stage,
        processes: () async => [
          RunningProcess(pid: 1, executablePath: p.join(steam, 'steam.exe')),
        ],
      );
      await expectLater(
        service.install(win64.version),
        throwsA(isA<SteamRunningException>()),
      );
      service.dispose();
      service = create(
        runner:
            ({
              required executable,
              required workingDirectory,
              required packagesUrl,
              context,
            }) async {
              await write(
                p.join(
                  workingDirectory,
                  'package',
                  'steam_client_win64.manifest',
                ),
                win64.version.manifest,
              );
            },
      );
      await service.download(win64.version);
      await expectLater(service.install(win64.version), throwsStateError);
      expect(await File(p.join(steam, 'steam.exe')).readAsString(), 'old-exe');
    },
  );
}
