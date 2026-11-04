import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/steam_process_actions.dart';
import 'package:fl_steam_lua/features/content_sources/content_models.dart';
import 'package:fl_steam_lua/features/kernel/kernel_service.dart';
import 'package:fl_steam_lua/features/kernel/local_toml_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory steam;
  late AppPaths paths;
  late SettingsStore settings;
  late KernelService service;

  Future<String> zip(String name, Map<String, String> files) async {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    final file = File(p.join(temp.path, name));
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file.path;
  }

  Future<KernelPackage> importFull(String name, String value) async {
    return service.importLocal(
      await zip(name, {
        'Release/OpenSteamTool.dll': 'core-$value',
        'Release/xinput1_4.dll': 'side-$value',
        'Release/dwmapi.dll': 'dwm-$value',
        'Release/version.dll.disabled': 'version-$value',
        'Release/README.md': 'ignored',
      }),
    );
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsteamlua-kernel-test-');
    steam = await Directory(p.join(temp.path, 'Steam')).create();
    await File(p.join(steam.path, 'steam.exe')).writeAsString('fixture');
    paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    await settings.set('steamPath', steam.path);
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await service.loadLocal();
  });

  tearDown(() async {
    service.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });

  test(
    'imports content-addressed local packages and reloads metadata',
    () async {
      final package = await importFull('first.zip', 'v1');
      expect(package.id, startsWith('local-'));
      expect(service.isCached(package), isTrue);
      expect(package.sha256Digest, hasLength(64));
      await service.loadLocal();
      expect(service.packages.single.id, package.id);
      expect(service.packages.single.displayName, 'first');
      expect(service.isCached(service.packages.single), isTrue);
      expect(
        await File(p.join(steam.path, 'OpenSteamTool.dll')).exists(),
        isFalse,
      );
    },
  );

  test('rejects package without known DLL and unsafe ZIP paths', () async {
    final unrelated = await zip('unrelated.zip', {'readme.txt': 'text'});
    await expectLater(service.importLocal(unrelated), throwsFormatException);
    final traversal = await zip('traversal.zip', {
      '../OpenSteamTool.dll': 'bad',
    });
    await expectLater(service.importLocal(traversal), throwsFormatException);
    final rooted = await zip('rooted.zip', {'C:/OpenSteamTool.dll': 'bad'});
    await expectLater(service.importLocal(rooted), throwsFormatException);
    expect(service.packages, isEmpty);
  });

  test('rejects ambiguous duplicate known DLL filenames', () async {
    final archive = await zip('duplicates.zip', {
      'a/OpenSteamTool.dll': 'one',
      'b/opensteamtool.dll': 'two',
    });
    await expectLater(service.importLocal(archive), throwsFormatException);
  });

  test('switches known DLLs and only one injection entry', () async {
    final package = await importFull('full.zip', 'v1');
    final result = await service.switchTo(package);
    expect(result.success, isTrue);
    expect(result.backupId, isNotNull);
    expect(service.activePackageId, package.id);
    expect(service.installed.installed, isTrue);
    expect(service.installed.enabled, isTrue);
    expect(service.installed.entryState, InjectionEntryState.dwmapi);
    expect(await File(p.join(steam.path, 'version.dll')).exists(), isFalse);
    expect(
      await File(p.join(steam.path, 'version.dll.disabled')).readAsString(),
      'version-v1',
    );
    expect(await File(p.join(steam.path, 'README.md')).exists(), isFalse);
    await service.setInjectionMode(InjectionMode.version);
    expect(service.installed.entryState, InjectionEntryState.version);
    expect(
      await File(p.join(steam.path, 'dwmapi.dll.disabled')).readAsString(),
      'dwm-v1',
    );
  });

  test('detects and toggles the bin/dwmapi injection entry', () async {
    final bin = await Directory(p.join(steam.path, 'bin')).create();
    await File(p.join(steam.path, 'OpenSteamTool.dll')).writeAsString('core');
    await File(p.join(steam.path, 'xinput1_4.dll')).writeAsString('side');
    await File(p.join(bin.path, 'dwmapi.dll')).writeAsString('entry');
    await service.loadLocal();

    expect(service.installed.installed, isTrue);
    expect(service.installed.enabled, isTrue);
    expect(service.installed.entryState, InjectionEntryState.dwmapi);
    expect(service.installed.files, contains(p.join('bin', 'dwmapi.dll')));

    await service.setEnabled(false);
    expect(
      await File(p.join(steam.path, 'OpenSteamTool.dll.off')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(steam.path, 'bin', 'dwmapi.dll.off')).exists(),
      isTrue,
    );

    await service.setEnabled(true);
    expect(
      await File(p.join(steam.path, 'bin', 'dwmapi.dll')).exists(),
      isTrue,
    );
    expect(service.installed.entryState, InjectionEntryState.dwmapi);
  });

  test(
    'failed mid-switch restores complete preimage and old active package',
    () async {
      final initial = await importFull('old.zip', 'old');
      expect((await service.switchTo(initial)).success, isTrue);
      await File(p.join(steam.path, 'xinput1_4.dll')).delete();
      final replacement = await importFull('new.zip', 'new');
      service.dispose();
      var writes = 0;
      service = KernelService(
        paths: paths,
        settings: settings,
        isSteamRunning: () async => false,
        fileWriter: (file, bytes) async {
          writes++;
          await file.writeAsBytes(bytes);
          if (writes == 2) {
            throw const FileSystemException('Injected locked file');
          }
        },
      );
      await service.loadLocal();
      final result = await service.switchTo(replacement);
      expect(result.success, isFalse);
      expect(result.rollbackSucceeded, isTrue);
      expect(service.activePackageId, initial.id);
      expect(
        await File(p.join(steam.path, 'OpenSteamTool.dll')).readAsString(),
        'core-old',
      );
      expect(
        await File(p.join(steam.path, 'dwmapi.dll')).readAsString(),
        'dwm-old',
      );
      expect(await File(p.join(steam.path, 'xinput1_4.dll')).exists(), isFalse);
      await service.loadLocal();
      expect(service.activePackageId, initial.id);
    },
  );

  test('active cached package cannot be deleted', () async {
    final active = await importFull('active.zip', 'one');
    await service.switchTo(active);
    await expectLater(service.deletePackage(active), throwsStateError);
    expect(service.isCached(active), isTrue);
    final inactive = await importFull('inactive.zip', 'two');
    await service.deletePackage(inactive);
    expect(service.isCached(inactive), isFalse);
    expect(service.packages.map((p) => p.id), [active.id]);
  });

  test(
    'uninstall preserves unrelated files and can restore snapshot',
    () async {
      final active = await importFull('active.zip', 'one');
      await service.switchTo(active);
      final config = File(p.join(steam.path, 'steam.cfg'));
      await config.writeAsString('user configuration');
      final lua = File(p.join(steam.path, 'config', 'stplug-in', '440.lua'));
      await lua.parent.create(recursive: true);
      await lua.writeAsString('addappid(440)');
      final orphan = File(p.join(steam.path, 'bin', 'dwmapi.dll'));
      await orphan.parent.create(recursive: true);
      await orphan.writeAsString('old orphan');
      final preview = await service.previewUninstall();
      expect(preview, contains(p.join('bin', 'dwmapi.dll')));
      final backupId = await service.uninstall();
      expect(service.installed.installed, isFalse);
      expect(service.activePackageId, isNull);
      expect(await config.readAsString(), 'user configuration');
      expect(await lua.readAsString(), 'addappid(440)');
      expect(await orphan.exists(), isFalse);
      expect((await service.restore(backupId)).success, isTrue);
      expect(service.activePackageId, active.id);
      expect(await orphan.readAsString(), 'old orphan');
    },
  );

  test('disable and enable preserve chosen version entry', () async {
    final package = await importFull('full.zip', 'one');
    await service.switchTo(package);
    await service.setInjectionMode(InjectionMode.version);
    expect(await service.setEnabled(false), 3);
    expect(service.installed.enabled, isFalse);
    expect(await File(p.join(steam.path, 'version.dll.off')).exists(), isTrue);
    expect(await service.setEnabled(true), 3);
    expect(service.installed.enabled, isTrue);
    expect(service.installed.entryState, InjectionEntryState.version);
  });

  test('refuses file mutations while Steam is running', () async {
    final package = await importFull('full.zip', 'one');
    service.dispose();
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => true,
    );
    await service.loadLocal();
    await expectLater(
      service.switchTo(package),
      throwsA(isA<SteamRunningException>()),
    );
    expect(
      await File(p.join(steam.path, 'OpenSteamTool.dll')).exists(),
      isFalse,
    );
  });

  test(
    'foreign cleanup only accepts detected filenames and backs up them',
    () async {
      await File(p.join(steam.path, 'hid.dll')).writeAsString('foreign');
      await File(p.join(steam.path, 'steam.cfg')).writeAsString('keep');
      expect((await service.scanForeignKernels()).single.owner, 'SteamTools');
      await expectLater(
        service.cleanupForeign(['../steam.cfg']),
        throwsArgumentError,
      );
      final result = await service.cleanupForeign(['hid.dll']);
      expect(result.removed, ['hid.dll']);
      expect(result.failed, isEmpty);
      expect(
        await File(p.join(steam.path, 'steam.cfg')).readAsString(),
        'keep',
      );
      expect(
        await File(
          p.join(service.repositoryRoot, 'backup', result.backupId, 'hid.dll'),
        ).readAsString(),
        'foreign',
      );
    },
  );

  test(
    'residual scan covers known folders, files, severity, and backup cleanup',
    () async {
      final openSteamTool = Directory(
        p.join(steam.path, 'opensteamtool', 'pattern'),
      );
      await openSteamTool.create(recursive: true);
      final nested = File(p.join(openSteamTool.path, 'steamclient.toml'));
      await nested.writeAsString('toml-data');
      final steamTools = Directory(p.join(steam.path, 'stplug-in'));
      await steamTools.create();
      await File(p.join(steamTools.path, '440.lua')).writeAsString('lua');
      await File(p.join(steam.path, 'midimap.dll')).writeAsString('midimap');
      await File(
        p.join(steam.path, 'GreenLuma_2025.dll'),
      ).writeAsString('greenluma');
      await File(
        p.join(steam.path, 'opensteamtool.toml'),
      ).writeAsString('config');
      final config = File(p.join(steam.path, 'steam.cfg'));
      await config.writeAsString('steam-config');

      final scan = await service.scanResiduals();
      expect(
        scan.items.map((item) => item.relativePath),
        containsAll([
          'opensteamtool',
          'stplug-in',
          'midimap.dll',
          'GreenLuma_2025.dll',
          'opensteamtool.toml',
          'steam.cfg',
        ]),
      );
      final toml = scan.items.singleWhere(
        (item) => item.relativePath == 'opensteamtool.toml',
      );
      expect(toml.canClean, isFalse);
      final openSteamToolItem = scan.items.singleWhere(
        (item) => item.relativePath == 'opensteamtool',
      );
      expect(openSteamToolItem.isDirectory, isTrue);
      expect(openSteamToolItem.fileCount, 1);
      expect(openSteamToolItem.sizeBytes, greaterThan(0));
      expect(openSteamToolItem.severity, KernelResidualSeverity.warning);

      final plan = service.createResidualCleanupPlan([
        openSteamToolItem.id,
        scan.items.singleWhere((item) => item.relativePath == 'steam.cfg').id,
        toml.id,
      ]);
      expect(plan.items, hasLength(2));
      final result = await service.executeResidualCleanup(plan);
      expect(result.success, isTrue);
      expect(result.deletedCount, 2);
      expect(
        await Directory(p.join(steam.path, 'opensteamtool')).exists(),
        isFalse,
      );
      expect(await config.exists(), isFalse);
      expect(
        await File(p.join(steam.path, 'opensteamtool.toml')).readAsString(),
        'config',
      );
      expect(
        await File(
          p.join(
            result.backupRoot,
            'opensteamtool',
            'pattern',
            'steamclient.toml',
          ),
        ).readAsString(),
        'toml-data',
      );
      expect(
        await File(p.join(result.backupRoot, 'steam.cfg')).readAsString(),
        'steam-config',
      );
    },
  );

  test(
    'detects Steam DLL fingerprints and fetches previewed signatures',
    () async {
      await File(
        p.join(steam.path, 'steamclient64.dll'),
      ).writeAsBytes([1, 2, 3]);
      await File(p.join(steam.path, 'steamui.dll')).writeAsBytes([4, 5, 6]);
      final packageDir = Directory(p.join(steam.path, 'package'));
      await packageDir.create();
      await File(
        p.join(packageDir.path, 'steam_client_win64.manifest'),
      ).writeAsString('"version" "123456"');
      service.dispose();
      service = KernelService(
        paths: paths,
        settings: settings,
        isSteamRunning: () async => false,
        client: MockClient((_) async => http.Response('signature', 200)),
      );
      await service.loadLocal();

      final info = await service.detectSteamDllInfo();
      expect(info, isNotNull);
      expect(info!.buildId, '123456');
      expect(info.clientSha, hasLength(64));
      expect(info.uiSha, hasLength(64));
      final results = await service.fetchTomlFiles(info: info);
      expect(results, hasLength(3));
      expect(results.every((result) => result.success), isTrue);
      expect(
        await File(
          p.join(
            steam.path,
            'opensteamtool',
            'pattern',
            'steamclient',
            '${info.clientSha}.toml',
          ),
        ).exists(),
        isTrue,
      );
    },
  );

  test('kernel update check exposes the newest official package', () async {
    service.dispose();
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((request) async {
        if (request.url.path == '/repos/huanyuejue/OpenSteamTool') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'full_name': 'huanyuejue/OpenSteamTool',
                'fork': true,
                'parent': {'full_name': 'OpenSteam001/OpenSteamTool'},
                'default_branch': 'main',
                'archived': false,
                'pushed_at': '2026-11-02T00:00:00Z',
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v2.0.0',
              'draft': false,
              'body': 'Important update announcement',
              'published_at': '2026-11-01T00:00:00Z',
              'assets': [
                {
                  'name': 'OpenSteamTool-Release.zip',
                  'size': 100,
                  'browser_download_url':
                      'https://github.com/huanyuejue/OpenSteamTool/releases/download/v2.0.0/OpenSteamTool-Release.zip',
                },
              ],
            },
          ]),
          200,
        );
      }),
    );
    final update = await service.checkForUpdate();
    expect(update, isNotNull);
    expect(update!.package.version, 'v2.0.0');
    expect(update.package.releaseNotes, 'Important update announcement');
    expect(update.hasUpdate, isTrue);
    expect(service.updateInfo?.package.id, update.package.id);
  });

  test('release refresh selects official ZIP and retains local cache', () async {
    final local = await importFull('local.zip', 'one');
    service.dispose();
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        if (request.url.path == '/repos/huanyuejue/OpenSteamTool') {
          return http.Response(
            jsonEncode({
              'full_name': 'huanyuejue/OpenSteamTool',
              'fork': true,
              'parent': {'full_name': 'OpenSteam001/OpenSteamTool'},
              'default_branch': 'main',
              'archived': false,
              'pushed_at': '2026-11-02T00:00:00Z',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v2.0.0',
              'draft': false,
              'published_at': '2026-11-01T00:00:00Z',
              'assets': [
                {
                  'name': 'OpenSteamTool-Release.zip',
                  'size': 123,
                  'browser_download_url':
                      'https://github.com/huanyuejue/OpenSteamTool/releases/download/v2.0.0/OpenSteamTool-Release.zip',
                },
              ],
            },
            {'tag_name': 'draft', 'draft': true, 'assets': []},
            {'tag_name': 'source-only', 'draft': false, 'assets': []},
          ]),
          200,
        );
      }),
    );
    await service.refresh();
    expect(service.repositoryInfo?.fork, isTrue);
    expect(service.repositoryInfo?.parent, 'OpenSteam001/OpenSteamTool');
    expect(service.packages.length, 2);
    expect(service.packages.first.id, local.id);
    expect(service.packages.last.id, 'v2.0.0');
  });

  test('local kernel mode never checks repository updates', () async {
    service.dispose();
    await settings.set('kernelSourceMode', 'local');
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((request) async {
        throw StateError('network must not be used in local mode');
      }),
    );
    final local = await importFull('local-only.zip', 'local');
    final packages = await service.refresh();
    expect(packages.single.id, local.id);
    expect(await service.checkForUpdate(), isNull);
    expect(service.repositoryInfo, isNull);
  });

  test(
    'custom manifest settings bridge through Lua and convert JSON',
    () async {
      service.dispose();
      service = KernelService(
        paths: paths,
        settings: settings,
        isSteamRunning: () async => false,
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://manifest.test/440/1/22');
          expect(request.headers['X-Test'], 'yes');
          return http.Response('{"content":"123456"}', 200);
        }),
      );
      await service.saveManifestSettings(
        const KernelManifestSettings(
          mode: KernelManifestMode.custom,
          provider: '20770407',
          customUrl: 'https://manifest.test/{appId}/{depotId}/{gid}',
          customHeader: 'X-Test: yes',
          format: KernelManifestFormat.jsonContent,
          failover: false,
        ),
      );
      final toml = await File(
        p.join(steam.path, 'opensteamtool.toml'),
      ).readAsString();
      expect(toml, contains('url = "20770407"'));
      final bridge = await File(
        p.join(steam.path, 'config', 'lua', 'flsteamlua_manifest.lua'),
      ).readAsString();
      expect(bridge, contains('fetch_manifest_code_ex'));
      expect(bridge, contains('127.0.0.1:47831'));
      await service.saveTomlChannelSettings(
        const KernelTomlChannelSettings(
          repository: 'owner/steam-monitor',
          channel: 'channel-a',
          mode: KernelTomlChannelMode.directory,
        ),
      );
      expect(service.tomlChannelSettings.repository, 'owner/steam-monitor');
      expect(service.tomlChannelSettings.channel, 'channel-a');
      expect(service.tomlChannelSettings.mode, KernelTomlChannelMode.directory);
      final code = await service.fetchManifestCode(
        appId: 440,
        depotId: 1,
        gid: '22',
      );
      expect(code, '123456');
    },
  );

  test('Steam data channel defaults to the local emergency repository', () {
    expect(service.tomlChannelSettings.repository, kernelDefaultTomlRepository);
    expect(service.tomlChannelSettings.channel, 'main');
    expect(service.tomlChannelSettings.mode, KernelTomlChannelMode.branch);
  });

  test('local TOML build delegates only after Steam is stopped', () async {
    service.dispose();
    var eventDelivered = false;
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((_) async => http.Response('', 500)),
      localTomlBuilderRunner: ({required steamPath, onEvent}) async {
        expect(steamPath, steam.path);
        onEvent?.call(
          const LocalTomlBuildEvent(
            kind: LocalTomlBuildEventKind.completed,
            resolved: 1,
            total: 3,
          ),
        );
        return const LocalTomlBuildReport(
          clientSha: 'client',
          uiSha: 'ui',
          components: [
            LocalTomlComponentResult(
              component: 'ipc/steamclient',
              success: true,
              written: true,
              resolved: 1,
              total: 1,
            ),
          ],
        );
      },
    );
    final report = await service.buildLocalTomlFiles(
      onEvent: (event) {
        eventDelivered = event.kind == LocalTomlBuildEventKind.completed;
      },
    );
    expect(report.writtenCount, 1);
    expect(eventDelivered, isTrue);
  });

  test(
    'local manifest proxy resolves request codes from content sources',
    () async {
      service.dispose();
      service = KernelService(
        paths: paths,
        settings: settings,
        isSteamRunning: () async => false,
        manifestCodeSources: () => const [
          ContentSourceDefinition(
            id: 'script:request-codes',
            name: 'Request codes',
            kind: ContentSourceKind.script,
            capabilities: {ContentCapability.manifestRequestCodes},
          ),
        ],
        resolveManifestRequestCode:
            ({
              required sourceId,
              required appId,
              required depotId,
              required gid,
            }) async {
              expect(sourceId, 'script:request-codes');
              expect(appId, 440);
              expect(depotId, 123);
              expect(gid, '456');
              return '987654321';
            },
      );
      await service.saveManifestSettings(
        const KernelManifestSettings(
          mode: KernelManifestMode.localProxy,
          provider: '20770407',
          failover: false,
          sourceIds: ['script:request-codes'],
        ),
      );
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:47831/manifest/440/123/456'),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(await utf8.decodeStream(response), '987654321');
      } finally {
        client.close(force: true);
      }
    },
  );

  test(
    'release network failure leaves cached packages and explicit warning',
    () async {
      final local = await importFull('local.zip', 'one');
      service.dispose();
      service = KernelService(
        paths: paths,
        settings: settings,
        client: MockClient((_) async => http.Response('rate limited', 403)),
      );
      await service.refresh();
      expect(service.packages.single.id, local.id);
      expect(service.warnings.single, contains('HTTP 403'));
    },
  );

  test('rejects non-official release URL before network request', () async {
    const package = KernelPackage(
      id: 'foreign',
      version: 'foreign',
      displayName: 'foreign',
      source: KernelSource.official,
      downloadUrl: 'https://example.com/kernel.zip',
    );
    await expectLater(service.download(package), throwsFormatException);
  });
}
