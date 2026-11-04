import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/cloud/cloud_service.dart';
import 'package:fl_steam_lua/features/cloud/remote/cloud_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late AppPaths paths;
  late SettingsStore settings;
  late CloudService service;
  final codec = CredentialCodec(
    protect: (bytes) => Uint8List.fromList(bytes.map((b) => b ^ 0x58).toList()),
    unprotect: (bytes) =>
        Uint8List.fromList(bytes.map((b) => b ^ 0x58).toList()),
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsteam-cloud-');
    paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    final steam = Directory(p.join(temp.path, 'steam'));
    await steam.create();
    await File(p.join(steam.path, 'steam.exe')).writeAsBytes([77, 90]);
    await settings.set('steamPath', steam.path);
    service = CloudService(
      paths: paths,
      settings: settings,
      configDirectory: p.join(temp.path, 'config'),
      credentialCodec: codec,
      client: MockClient((request) async => http.Response('not found', 404)),
    );
    await service.setSyncPath(p.join(temp.path, 'saves'));
  });

  tearDown(() async {
    service.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });

  Future<File> save(String relative, String body) async {
    final file = File(p.join(service.syncPath, relative));
    await file.parent.create(recursive: true);
    return file.writeAsString(body);
  }

  test(
    'changing save folder copies current saves and retains originals',
    () async {
      final source = await save('123/440/remote/save.dat', 'current progress');
      await Directory(p.join(service.syncPath, '123', '440', 'empty')).create();
      final destination = p.join(temp.path, 'new-saves');
      await service.setSyncPath(destination);
      expect(service.syncPath, destination);
      expect(await source.readAsString(), 'current progress');
      expect(
        await File(
          p.join(destination, '123', '440', 'remote', 'save.dat'),
        ).readAsString(),
        'current progress',
      );
      expect(
        await Directory(p.join(destination, '123', '440', 'empty')).exists(),
        isTrue,
      );
      expect(service.saves.single.appId, 440);
      final config =
          jsonDecode(
                await File(
                  p.join(service.configDirectory, 'config.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(config['sync_path'], destination);
    },
  );

  test(
    'changing to a nonempty folder never overwrites or changes config',
    () async {
      final source = await save('123/440/save.dat', 'current progress');
      final originalPath = service.syncPath;
      final existing = File(
        p.join(temp.path, 'new-saves', '123', '440', 'save.dat'),
      );
      await existing.parent.create(recursive: true);
      await existing.writeAsString('destination progress');
      await expectLater(
        service.setSyncPath(p.join(temp.path, 'new-saves')),
        throwsA(isA<FileSystemException>()),
      );
      expect(service.syncPath, originalPath);
      expect(await source.readAsString(), 'current progress');
      expect(await existing.readAsString(), 'destination progress');
      final config =
          jsonDecode(
                await File(
                  p.join(service.configDirectory, 'config.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(config['sync_path'], originalPath);
    },
  );

  test(
    'save folders cannot be descendants or ancestors of one another',
    () async {
      await save('123/440/save.dat', 'keep');
      final originalPath = service.syncPath;
      await expectLater(
        service.setSyncPath(p.join(originalPath, 'child')),
        throwsArgumentError,
      );
      await expectLater(service.setSyncPath(temp.path), throwsArgumentError);
      expect(service.syncPath, originalPath);
      expect(await Directory(p.join(originalPath, 'child')).exists(), isFalse);
    },
  );

  test('config failure rolls back an existing empty destination', () async {
    final source = await save('123/440/save.dat', 'keep');
    final originalPath = service.syncPath;
    final destination = Directory(p.join(temp.path, 'new-saves'));
    await destination.create();
    final config = File(p.join(service.configDirectory, 'config.json'));
    await config.delete();
    await Directory(config.path).create();
    await expectLater(
      service.setSyncPath(destination.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(service.syncPath, originalPath);
    expect(await source.readAsString(), 'keep');
    expect(await destination.exists(), isTrue);
    expect(await destination.list().isEmpty, isTrue);
    expect(
      (await temp.list().toList()).where(
        (entry) => p.basename(entry.path).contains('.flsteam-migrate-'),
      ),
      isEmpty,
    );
  });

  test(
    'cancelled save-folder change retains current config and saves',
    () async {
      final source = await save('123/440/save.dat', 'keep');
      final originalPath = service.syncPath;
      final tasks = TaskCenter();
      final destination = p.join(temp.path, 'new-saves');
      final operation = tasks.run('change folder', (context) async {
        tasks.cancel(context.task.id);
        await service.setSyncPath(destination, context: context);
      });
      await expectLater(operation, throwsA(isA<TaskCancelled>()));
      expect(service.syncPath, originalPath);
      expect(await source.readAsString(), 'keep');
      expect(await Directory(destination).exists(), isFalse);
      tasks.dispose();
    },
  );

  test(
    'scans all account directories without merging distinct saves',
    () async {
      await save('123/440/remote/save.dat', 'one');
      await save('456/440/slot.dat', 'two');
      await save('not-account/440/ignored', 'ignore');
      await save('123/not-app/ignored', 'ignore');
      await service.refresh();
      expect(service.saves, hasLength(2));
      expect(service.saves.map((s) => s.accountId).toSet(), {'123', '456'});
      expect(service.saves.every((s) => s.appId == 440 && !s.isRemote), isTrue);
      expect(service.saves.fold<int>(0, (sum, s) => sum + s.size), 6);
      expect(service.status.remoteSyncConfigured, isFalse);
    },
  );

  test('backup delete and restore preserves verified files', () async {
    final file = await save('123/440/remote/save.dat', 'progress');
    await service.refresh();
    final preview = await service.previewDelete(440);
    expect(preview.fileCount, 1);
    final backup = await service.delete(preview);
    expect(await file.exists(), isFalse);
    expect((await service.backups(appId: 440)).single.path, backup.path);
    await service.restore(backup);
    expect(await file.readAsString(), 'progress');
  });

  test('changed delete preview is rejected before deleting sources', () async {
    final file = await save('123/440/slot.dat', 'first');
    final preview = await service.previewDelete(440);
    await file.writeAsString('changed length');
    await expectLater(service.delete(preview), throwsStateError);
    expect(await file.readAsString(), 'changed length');
  });

  test('restore validates all checksums before overwriting', () async {
    final file = await save('123/440/slot.dat', 'first');
    final backup = await service.backup(440);
    await file.writeAsString('current');
    await File(p.join(backup.path, '0', 'slot.dat')).writeAsString('corrupted');
    await expectLater(service.restore(backup), throwsFormatException);
    expect(await file.readAsString(), 'current');
  });

  test('restore keeps previous directory adjacent to target', () async {
    final file = await save('123/440/slot.dat', 'first');
    final backup = await service.backup(440);
    await file.writeAsString('current');
    await service.restore(backup);
    final siblings = await Directory(
      p.join(service.syncPath, '123'),
    ).list().toList();
    final previous = siblings
        .whereType<Directory>()
        .where((d) => p.basename(d.path).startsWith('440.before-restore-'))
        .single;
    expect(
      await File(p.join(previous.path, 'slot.dat')).readAsString(),
      'current',
    );
    expect(await file.readAsString(), 'first');
  });

  test('cancelled operation leaves source files intact', () async {
    final file = await save('123/440/slot.dat', 'keep');
    final tasks = TaskCenter();
    final future = tasks.run('backup', (context) async {
      tasks.cancel(context.task.id);
      await service.backup(440, context: context);
    });
    await expectLater(future, throwsA(isA<TaskCancelled>()));
    expect(await file.readAsString(), 'keep');
    expect(tasks.tasks.single.status, TaskStatus.cancelled);
  });

  test(
    'credentials use encrypted native-file schema and preserve config keys',
    () async {
      final config = File(p.join(service.configDirectory, 'config.json'));
      final value =
          jsonDecode(await config.readAsString()) as Map<String, dynamic>;
      value['other_native_key'] = 42;
      await config.writeAsString(jsonEncode(value));
      // Configure only the contract here; refresh will fail at the mocked endpoint.
      await expectLater(
        service.configureProvider('s3', {
          'endpoint': 'https://s3.example.test',
          'bucket': 'saves',
          'region': 'test-1',
          'access_key_id': 'user',
          'secret_access_key': 'secret',
        }),
        throwsA(isA<RemoteStoreException>()),
      );
      final raw = await File(service.credentials.path('s3')).readAsBytes();
      expect(utf8.decode(raw, allowMalformed: true), isNot(contains('secret')));
      expect(
        (await service.providerConfiguration('s3'))!['secret_access_key'],
        'secret',
      );
      final current =
          jsonDecode(await config.readAsString()) as Map<String, dynamic>;
      expect(current['other_native_key'], 42);
      expect(current['token_paths']['s3'], service.credentials.path('s3'));
    },
  );

  test('enable validates DLL checksum and preserves unrelated TOML', () async {
    final bytes = [77, 90, 1, 2, 3];
    final client = MockClient(
      (request) async => request.url.path.endsWith('.sha256')
          ? http.Response('${sha256.convert(bytes)} cloud_redirect.dll', 200)
          : http.Response.bytes(bytes, 200),
    );
    final other = CloudService(
      paths: paths,
      settings: settings,
      client: client,
      configDirectory: service.configDirectory,
      credentialCodec: codec,
    );
    final toml = File(p.join(settings.steamPath, 'opensteamtool.toml'));
    await toml.writeAsString(
      '# keep\n[manifest]\nfailover = true\n[cloud]\n# keep cloud\nenabled = false\n[other]\nvalue = 7\n',
    );
    await other.enableRedirect();
    final result = await toml.readAsString();
    expect(result, contains('# keep cloud'));
    expect(result, contains('[other]\nvalue = 7'));
    expect(result, contains('enabled = true'));
    expect(
      await File(
        p.join(settings.steamPath, 'cloud_redirect.dll'),
      ).readAsBytes(),
      bytes,
    );
    expect(other.status.enabled, isTrue);
    final installed = await other.inspectPlugin();
    expect(installed.installed, isTrue);
    expect(installed.enabled, isTrue);
    expect(installed.size, bytes.length);
    await other.disableRedirect();
    expect(other.status.enabled, isFalse);
    await other.removePlugin();
    final removed = await other.inspectPlugin();
    expect(removed.installed, isFalse);
    expect(removed.enabled, isFalse);
    other.dispose();
  });

  test('bad DLL checksum does not deploy files or enable kernel', () async {
    final other = CloudService(
      paths: paths,
      settings: settings,
      client: MockClient(
        (request) async => request.url.path.endsWith('.sha256')
            ? http.Response('0' * 64, 200)
            : http.Response.bytes([77, 90], 200),
      ),
      configDirectory: service.configDirectory,
      credentialCodec: codec,
    );
    await expectLater(other.enableRedirect(), throwsFormatException);
    expect(
      await File(p.join(settings.steamPath, 'cloud_redirect.dll')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(settings.steamPath, 'opensteamtool.toml')).exists(),
      isFalse,
    );
    other.dispose();
  });

  test(
    'remote save backup deletion restore and download use the same logical root',
    () async {
      final remote = _MemoryRemoteStore({
        '123/440/remote/progress.sav': utf8.encode('remote progress'),
      });
      final other = CloudService(
        paths: paths,
        settings: settings,
        configDirectory: p.join(temp.path, 'remote-config'),
        credentialCodec: codec,
        remoteStore: remote,
      );
      await other.configureProvider('s3', {
        'endpoint': 'https://example.test',
        'bucket': 'saves',
        'region': 'test-1',
        'access_key_id': 'test',
        'secret_access_key': 'secret',
      });
      expect(other.saves.single.isRemote, isTrue);
      expect(other.saves.single.fileCount, 1);
      final destination = p.join(temp.path, 'download');
      await other.download(other.saves.single, destination);
      expect(
        await File(
          p.join(destination, 'remote', 'progress.sav'),
        ).readAsString(),
        'remote progress',
      );
      final backup = await other.delete(await other.previewDelete(440));
      expect(remote.files, isEmpty);
      await other.restore(backup);
      expect(
        utf8.decode(remote.files['123/440/remote/progress.sav']!),
        'remote progress',
      );
      other.dispose();
    },
  );
}

class _MemoryRemoteStore implements RemoteStore {
  _MemoryRemoteStore(this.files);
  final Map<String, List<int>> files;

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final prefix = path.isEmpty ? '' : '$path/';
    final values = <String, RemoteEntry>{};
    for (final file in files.entries.where(
      (entry) => entry.key.startsWith(prefix),
    )) {
      final suffix = file.key.substring(prefix.length);
      final slash = suffix.indexOf('/');
      final child = slash < 0
          ? file.key
          : '$prefix${suffix.substring(0, slash)}';
      values[child] = RemoteEntry(
        path: child,
        isDirectory: slash >= 0,
        size: slash < 0 ? file.value.length : 0,
      );
    }
    return values.values.toList();
  }

  @override
  Future<Uint8List> read(String path) async => Uint8List.fromList(files[path]!);
  @override
  Future<void> write(String path, List<int> bytes) async {
    files[path] = List.of(bytes);
  }

  @override
  Future<void> delete(String path) async {
    files.removeWhere((key, _) => key == path || key.startsWith('$path/'));
  }

  @override
  Future<void> testConnection() async {}
}
