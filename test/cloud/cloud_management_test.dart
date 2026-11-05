import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/cloud/cloud_service.dart';
import 'package:fl_steam_lua/features/cloud/cloud_native_sync.dart';
import 'package:fl_steam_lua/features/cloud/remote/remote_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class ObjectStore implements RemoteStore {
  final files = <String, List<int>>{};
  final listed = <String>[];
  bool failList = false;
  int failWriteAt = -1, writes = 0;
  @override
  Future<List<RemoteEntry>> list(String path) async {
    if (failList) throw const RemoteStoreException('offline');
    listed.add(path);
    final prefix = path.isEmpty ? '' : '$path/';
    final result = <String, RemoteEntry>{};
    for (final file in files.entries.where((e) => e.key.startsWith(prefix))) {
      final suffix = file.key.substring(prefix.length),
          slash = file.key.substring(prefix.length).indexOf('/');
      final child = slash < 0
          ? file.key
          : '$prefix${suffix.substring(0, slash)}';
      result[child] = RemoteEntry(
        path: child,
        isDirectory: slash >= 0,
        size: slash < 0 ? file.value.length : 0,
      );
    }
    return result.values.toList();
  }

  @override
  Future<Uint8List> read(String path) async => Uint8List.fromList(files[path]!);
  @override
  Future<void> write(String path, List<int> bytes) async {
    if (++writes == failWriteAt) {
      throw const RemoteStoreException('write failed');
    }
    files[path] = [...bytes];
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  Future<void> testConnection() async {
    await list('');
  }
}

void main() {
  late Directory temp;
  late AppPaths paths;
  late SettingsStore settings;
  late CloudService service;
  final codec = CredentialCodec(
    protect: (b) => Uint8List.fromList(b.map((v) => v ^ 42).toList()),
    unprotect: (b) => Uint8List.fromList(b.map((v) => v ^ 42).toList()),
  );
  Map<String, dynamic> s3(String bucket) => {
    'endpoint': 'https://fixture.invalid',
    'region': 'test',
    'bucket': bucket,
    'access_key_id': 'key',
    'secret_access_key': 'secret-$bucket',
  };
  Future<File> write(String path, String text) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return file.writeAsString(text);
  }

  CloudService create({RemoteStore? remote, CloudNativeRunner? native}) =>
      CloudService(
        paths: paths,
        settings: settings,
        configDirectory: p.join(temp.path, 'config'),
        credentialCodec: codec,
        processReader: () async => [],
        remoteStore: remote,
        nativeRunner: native,
        client: MockClient((_) async => http.Response('offline', 503)),
      );
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cloud-management-');
    paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    await settings.set('steamPath', p.join(temp.path, 'steam'));
    service = create();
    await service.setSyncPath(p.join(temp.path, 'original'));
  });
  tearDown(() async {
    service.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });

  test(
    'named same-provider targets isolate credentials; browsing never activates',
    () async {
      service.dispose();
      service = create(remote: ObjectStore());
      await service.refreshStatus();
      final original = service.syncPath;
      final a = await service.saveStorage(
        name: 'A',
        kind: 's3',
        values: s3('a'),
      );
      final b = await service.saveStorage(
        name: 'B',
        kind: 's3',
        values: s3('b'),
      );
      expect(service.activeStorageId, 'current');
      expect(
        (await service.storageValues(a.id))['secret_access_key'],
        'secret-a',
      );
      expect(
        (await service.storageValues(b.id))['secret_access_key'],
        'secret-b',
      );
      await service.activateStorage(a.id);
      final configFile = File(p.join(service.configDirectory, 'config.json'));
      final activeBytes = await configFile.readAsBytes();
      await service.browseStorage(b.id);
      expect(await configFile.readAsBytes(), activeBytes);
      expect(service.activeStorageId, a.id);
      expect(service.browsingStorageId, b.id);
      final config = jsonDecode(await configFile.readAsString());
      expect(config['token_paths']['s3'], endsWith('${a.id}.json'));
      final encrypted = await File(config['token_path']).readAsBytes();
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('secret-a')),
      );
      await service.activateStorage('current');
      expect(service.syncPath, original);
      await service.reorderStorages([b.id, 'current', a.id]);
      await service.loadProfiles();
      expect(service.savedStorageProfiles.map((v) => v.id), [
        b.id,
        'current',
        a.id,
      ]);
      await service.removeStorage(a.id);
      expect(
        await File(
          p.join(service.configDirectory, 'profiles', '${a.id}.json'),
        ).exists(),
        isFalse,
      );
    },
  );

  test(
    'draft read-write probes clean up without saving or activating',
    () async {
      final store = ObjectStore();
      service.dispose();
      service = create(remote: store);
      await service.refreshStatus();
      final result = await service.testStorage('s3', s3('draft'), write: true);
      expect(result.writeVerified, isTrue);
      expect(store.files, isEmpty);
      expect(service.activeStorageId, 'current');
      expect(service.savedStorageProfiles, isEmpty);
      expect(
        await File(
          p.join(service.configDirectory, 's3_credentials.json'),
        ).exists(),
        isFalse,
      );
    },
  );

  test(
    'inactive folder backups restore only their captured location and reject changed targets',
    () async {
      final a = await service.saveStorage(
        name: 'A',
        kind: 'folder',
        values: {'folder': p.join(temp.path, 'a')},
      );
      final b = await service.saveStorage(
        name: 'B',
        kind: 'folder',
        values: {'folder': p.join(temp.path, 'b')},
      );
      final fa = await write(p.join(a.folder, '123', '440', 'save'), 'a');
      final fb = await write(p.join(b.folder, '123', '440', 'save'), 'b');
      await service.activateStorage(a.id);
      await service.browseStorage(b.id);
      final backup = await service.backup(440, selection: service.saves.single);
      await fb.writeAsString('new-b');
      await service.restore(backup);
      expect(await fb.readAsString(), 'b');
      expect(await fa.readAsString(), 'a');
      final before = (await service.backups())
          .where((v) => v.reason == 'beforeRestore')
          .single;
      expect(
        await File(p.join(before.path, '0', 'save')).readAsString(),
        'new-b',
      );
      await service.saveStorage(
        id: b.id,
        name: 'B',
        kind: 'folder',
        values: {'folder': p.join(temp.path, 'other')},
      );
      await expectLater(service.restore(backup), throwsStateError);
      expect(await fb.readAsString(), 'b');
    },
  );

  test(
    'listing is shallow; status reads and failed refresh preserve last remote results',
    () async {
      final store = ObjectStore()..files['123/440/blobs/slot/hash'] = [1, 2, 3];
      service.dispose();
      service = create(remote: store);
      await service.configureProvider('s3', s3('a'));
      await service.refresh(appId: 440);
      expect(store.listed, ['', '123']);
      expect(service.saves.single.detailsLoaded, isFalse);
      final row = service.saves.single;
      await service.inspectSave(row);
      expect(service.saves.single.size, 3);
      await service.refreshStatus();
      expect(service.saves.single.size, 3);
      store.failList = true;
      await expectLater(
        service.refresh(appId: 440),
        throwsA(isA<RemoteStoreException>()),
      );
      expect(service.saves.single.id, row.id);
      expect(service.lastError, contains('offline'));
    },
  );

  test(
    'prefix deletion removes every object and can restore the exact selected account',
    () async {
      final store = ObjectStore()
        ..files.addAll({
          '123/440/a/one': [1],
          '123/440/a/two': [2],
          '456/440/keep': [3],
        });
      service.dispose();
      service = create(remote: store);
      await service.configureProvider('s3', s3('a'));
      await service.refresh();
      final row = service.saves.firstWhere((v) => v.accountId == '123');
      final backup = await service.delete(
        await service.previewDelete(440, selection: row),
      );
      expect(store.files.keys, ['456/440/keep']);
      await service.restore(backup);
      expect(store.files.keys.toSet(), {
        '123/440/a/one',
        '123/440/a/two',
        '456/440/keep',
      });
    },
  );

  test(
    'failed repository upload restores overwritten and removes newly written objects',
    () async {
      final store = ObjectStore()..files['123/440/slot'] = utf8.encode('old');
      service.dispose();
      service = create(remote: store);
      await service.configureProvider('s3', s3('a'));
      final source = p.join(temp.path, 'copy');
      await write(p.join(source, 'slot'), 'new');
      await write(p.join(source, 'extra'), 'extra');
      store.failWriteAt = 2;
      await expectLater(
        service.upload(CloudSave(appId: 440, accountId: '123', path: source)),
        throwsA(isA<RemoteStoreException>()),
      );
      expect(store.files.keys, ['123/440/slot']);
      expect(utf8.decode(store.files['123/440/slot']!), 'old');
      expect((await service.backups()).single.reason, 'beforeUpload');
    },
  );

  test(
    'notes, checksum verification and pinned retention survive reload',
    () async {
      final file = await write(
        p.join(service.syncPath, '123', '440', 'slot'),
        'one',
      );
      final first = await service.backup(440);
      await file.writeAsString('two');
      final second = await service.backup(440);
      await service.updateBackup(first, note: 'milestone', pinned: true);
      await service.verifyBackup(first);
      final records = await service.backups();
      final pinned = records.firstWhere((v) => v.path == first.path);
      expect(pinned.note, 'milestone');
      expect(pinned.pinned, isTrue);
      expect(pinned.verifiedAt, isNotNull);
      expect(
        await service.retentionCandidates(appId: 440, keep: 1, maxBytes: 0),
        isEmpty,
      );
      expect(
        (await service.retentionCandidates(
          appId: 440,
          keep: 0,
          maxBytes: 1,
        )).single.path,
        second.path,
      );
      await expectLater(service.removeBackups([pinned]), throwsStateError);
      await service.removeBackups([second]);
      expect((await service.backups()).single.path, first.path);
    },
  );

  test(
    'native pull requires verified cache content, snapshots and rolls back failed output',
    () async {
      final bytes = utf8.encode('remote');
      final store = ObjectStore()
        ..files.addAll({
          '123/440/cn.cloudredirect': utf8.encode('2'),
          '123/440/manifest.cloudredirect': utf8.encode(
            jsonEncode({
              'slot': {
                'sha': sha1.convert(bytes).toString(),
                'size': bytes.length,
                'ts': 1,
              },
            }),
          ),
        });
      var corrupt = false;
      service.dispose();
      service = create(
        remote: store,
        native:
            ({
              required library,
              required provider,
              required accountId,
              required appId,
              required cloudRoot,
              context,
            }) async {
              expect(provider, 's3');
              expect(appId, 440);
              expect(accountId, '123');
              await write(
                p.join(
                  cloudRoot,
                  'storage',
                  accountId,
                  '$appId',
                  'cn.cloudredirect',
                ),
                '2',
              );
              await write(
                p.join(cloudRoot, 'storage', accountId, '$appId', 'slot'),
                corrupt ? 'broken' : 'remote',
              );
              return {
                'success': true,
                'drained': true,
                'local_cn': 2,
                'local_file_count': 1,
                'had_newer': true,
              };
            },
      );
      await File(
        p.join(settings.steamPath, 'cloud_redirect.dll'),
      ).parent.create(recursive: true);
      await File(
        p.join(settings.steamPath, 'cloud_redirect.dll'),
      ).writeAsBytes([77, 90]);
      final cache = await write(
        p.join(
          settings.steamPath,
          'cloud_redirect',
          'storage',
          '123',
          '440',
          'slot',
        ),
        'local',
      );
      await service.configureProvider('s3', s3('a'));
      await service.refresh();
      final row = service.saves.firstWhere((v) => v.isRemote);
      final receipt = await service.synchronize(row);
      expect(receipt.changed, isTrue);
      expect(await cache.readAsString(), 'remote');
      expect((await service.backups()).single.reason, 'beforeSync');
      corrupt = true;
      await expectLater(service.synchronize(row), throwsStateError);
      expect(await cache.readAsString(), 'remote');
    },
  );
}
