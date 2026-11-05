part of 'steam_version_service.dart';

extension SteamVersionInstallation on SteamVersionService {
  Future<SteamClientBackup> install(
    SteamClientVersion version, {
    String? targetDirectory,
    TaskContext? context,
  }) => operation(() async {
    final root = await _installationRoot(targetDirectory ?? settings.steamPath);
    await _requireStopped();
    await verify(version, context: context);
    final stageBase = paths.directory('cache/steam-client-stage');
    await stageBase.create(recursive: true);
    final stage = await stageBase.createTemp('${version.id}-');
    final bootstrap = version.packages
        .firstWhere((v) => v.bootstrap && v.section == 'steam_${version.arch}')
        .zip;
    final server = SteamPackageServer(
      directory: directory(version),
      arch: version.arch,
      files: version.files.map((v) => v.name).toSet(),
    );
    try {
      final zipPath = p.join(directory(version), bootstrap.name);
      final executable = await _readBootstrap(zipPath, version.arch);
      await _writeBytes(File(p.join(stage.path, 'steam.exe')), executable);
      await server.start();
      context?.report(texts.steamVersionStaging);
      await _runner(
        executable: p.join(stage.path, 'steam.exe'),
        workingDirectory: stage.path,
        packagesUrl: server.url,
        context: context,
      );
      context?.checkCancelled();
      final staged = await inspectInstallation(stage.path);
      if (staged.indexPath == null) {
        throw StateError(texts.steamVersionInstallUnverified);
      }
      final indexed = await _installedFiles(File(staged.indexPath!));
      if (!indexed.containsKey('steam.exe') || indexed.length < 2) {
        throw StateError(texts.steamVersionInstallUnverified);
      }
      for (final entry in indexed.entries) {
        if (_preservedSteamPath(entry.key)) continue;
        final file = await _clientFile(stage.path, entry.key);
        if (!await file.exists() || await file.length() != entry.value) {
          throw StateError(texts.steamVersionInstallUnverified);
        }
      }
      if (staged.build != version.build ||
          staged.arch != version.arch ||
          server.missing.isNotEmpty) {
        throw StateError(texts.steamVersionInstallUnverified);
      }
      await _requireStopped();
      final replacements = <String, File?>{};
      await for (final entry in stage.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entry is Link) {
          throw FileSystemException(texts.steamVersionLinkedPath, entry.path);
        }
        if (entry is! File) continue;
        final relative = p
            .relative(entry.path, from: stage.path)
            .replaceAll('\\', '/');
        if (_preservedSteamPath(relative)) continue;
        replacements[relative] = entry;
      }
      // Remove other installed markers so an older architecture cannot look active.
      final package = Directory(p.join(root, 'package'));
      if (await package.exists()) {
        await for (final entry in package.list(followLinks: false)) {
          if (entry is File &&
              RegExp(
                r'^steam_client_(?:publicbeta_)?win(?:32|64)\.(installed|manifest)$',
              ).hasMatch(p.basename(entry.path))) {
            if (entry.path.endsWith('.installed')) {
              for (final relative in (await _installedFiles(entry)).keys) {
                if (_preservedSteamPath(relative)) continue;
                await _clientFile(root, relative);
                replacements.putIfAbsent(relative, () => null);
              }
            }
            replacements.putIfAbsent(
              'package/${p.basename(entry.path)}',
              () => null,
            );
          }
        }
      }
      final backup = await _snapshotClient(
        root,
        replacements.keys.toList(),
        version.build,
        context,
      );
      try {
        await _requireStopped();
        var done = 0;
        for (final entry in replacements.entries) {
          context?.checkCancelled();
          final destination = await _clientFile(root, entry.key);
          if (entry.value == null) {
            if (await destination.exists()) await destination.delete();
          } else {
            await _writer(destination, await entry.value!.readAsBytes());
          }
          context?.reportProgress(
            texts.steamVersionApplying('${++done}', '${replacements.length}'),
            done / replacements.length,
          );
        }
        final result = await inspectInstallation(root);
        if (result.build != version.build || result.arch != version.arch) {
          throw StateError(texts.steamVersionInstallUnverified);
        }
      } catch (_) {
        await _restoreClientSnapshot(backup);
        rethrow;
      }
      if (!p.equals(settings.steamPath, root)) {
        await settings.set('steamPath', root);
      }
      await refreshLocal();
      return backup;
    } finally {
      await server.close();
      await stage.delete(recursive: true);
    }
  });

  Future<String> _installationRoot(String value) async {
    if (value.isEmpty || !p.isAbsolute(value) || p.dirname(value) == value) {
      throw FormatException(texts.steamVersionTargetRequired);
    }
    final directory = Directory(p.normalize(p.absolute(value)));
    if (!await directory.exists()) await directory.create(recursive: true);
    final resolved = await directory.resolveSymbolicLinks();
    final dataRoot = p.normalize(p.absolute(paths.root));
    if (p.equals(resolved, dataRoot) ||
        p.isWithin(resolved, dataRoot) ||
        p.isWithin(dataRoot, resolved)) {
      throw FormatException(texts.steamVersionTargetRequired);
    }
    if (!await File(p.join(resolved, 'steam.exe')).exists() &&
        !await Directory(resolved).list().isEmpty) {
      throw FormatException(texts.steamVersionTargetRequired);
    }
    return resolved;
  }

  Future<void> _requireStopped() async {
    if ((await _processReader()).any(
      (v) => p.basename(v.executablePath).toLowerCase() == 'steam.exe',
    )) {
      throw const SteamRunningException();
    }
  }

  Future<SteamClientBackup> _snapshotClient(
    String root,
    List<String> relatives,
    String build,
    TaskContext? context,
  ) async {
    final folder = paths.directory(
      'backups/steam-client/${DateTime.now().microsecondsSinceEpoch}',
    );
    final records = <Map<String, dynamic>>[];
    for (final relative in relatives) {
      context?.checkCancelled();
      final source = await _clientFile(root, relative);
      if (await source.exists()) {
        final bytes = await source.readAsBytes();
        await _writeBytes(
          File(p.join(folder.path, 'files', p.fromUri(Uri(path: relative)))),
          bytes,
        );
        records.add({
          'path': relative,
          'sha256': sha256.convert(bytes).toString(),
        });
      } else {
        records.add({'path': relative, 'sha256': null});
      }
    }
    final now = DateTime.now().toUtc();
    await _writeBytes(
      File(p.join(folder.path, 'snapshot.json')),
      utf8.encode(
        jsonEncode({
          'target': root,
          'createdAt': now.toIso8601String(),
          'build': build,
          'files': records,
        }),
      ),
    );
    return SteamClientBackup(
      path: folder.path,
      target: root,
      createdAt: now,
      files: records.length,
      build: build,
    );
  }

  Future<Map<String, dynamic>> _snapshotData(SteamClientBackup backup) async {
    final base = p.normalize(p.absolute(paths.file('backups/steam-client')));
    if (!p.isWithin(base, p.normalize(p.absolute(backup.path)))) {
      throw FormatException(texts.steamVersionInvalidBackup);
    }
    if (await FileSystemEntity.type(backup.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FormatException(texts.steamVersionInvalidBackup);
    }
    final json = jsonDecode(
      await File(p.join(backup.path, 'snapshot.json')).readAsString(),
    );
    if (json is! Map<String, dynamic> ||
        json['target'] != backup.target ||
        json['files'] is! List) {
      throw FormatException(texts.steamVersionInvalidBackup);
    }
    for (final record in json['files'] as List) {
      if (record is! Map || record['path'] is! String) {
        throw FormatException(texts.steamVersionInvalidBackup);
      }
      await _clientFile(backup.target, record['path']);
      if (record['sha256'] != null) {
        final file = File(
          p.join(backup.path, 'files', p.fromUri(Uri(path: record['path']))),
        );
        if ((await sha256.bind(file.openRead()).first).toString() !=
            record['sha256']) {
          throw FormatException(texts.steamVersionChecksumFailed);
        }
      }
    }
    return json;
  }

  Future<void> _restoreClientSnapshot(SteamClientBackup backup) async {
    final data = await _snapshotData(backup);
    for (final record in data['files'] as List) {
      final destination = await _clientFile(backup.target, record['path']);
      if (record['sha256'] == null) {
        if (await destination.exists()) await destination.delete();
      } else {
        await _writeBytes(
          destination,
          await File(
            p.join(backup.path, 'files', p.fromUri(Uri(path: record['path']))),
          ).readAsBytes(),
        );
      }
    }
  }

  Future<List<SteamClientBackup>> backups() async {
    final root = paths.directory('backups/steam-client');
    if (!await root.exists()) return [];
    final result = <SteamClientBackup>[];
    await for (final folder in root.list(followLinks: false)) {
      if (folder is! Directory) continue;
      final manifest = File(p.join(folder.path, 'snapshot.json'));
      if (!await manifest.exists()) continue;
      final data = jsonDecode(await manifest.readAsString());
      if (data is! Map ||
          data['target'] is! String ||
          data['files'] is! List ||
          data['build'] is! String) {
        throw FormatException(texts.steamVersionInvalidBackup);
      }
      result.add(
        SteamClientBackup(
          path: folder.path,
          target: data['target'],
          createdAt: DateTime.parse(data['createdAt'] as String),
          files: (data['files'] as List).length,
          build: data['build'],
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> restoreBackup(
    SteamClientBackup backup, {
    TaskContext? context,
  }) => operation(() async {
    await _requireStopped();
    final root = await _installationRoot(settings.steamPath);
    if (!p.equals(root, backup.target)) {
      throw StateError(texts.steamVersionBackupTargetChanged);
    }
    final data = await _snapshotData(backup);
    final before = await _snapshotClient(
      root,
      [for (final record in data['files'] as List) record['path'] as String],
      installed?.build ?? '',
      context,
    );
    context?.checkCancelled();
    try {
      await _restoreClientSnapshot(backup);
    } catch (_) {
      await _restoreClientSnapshot(before);
      rethrow;
    }
    await library.scan();
    await refreshLocal();
  });
}

bool _preservedSteamPath(String relative) {
  final parts = relative.toLowerCase().split('/');
  return {
        'steamapps',
        'userdata',
        'config',
        'logs',
        'dumps',
        'appcache',
        'cloud_redirect',
        'lua',
        'opensteamtool',
      }.contains(parts.first) ||
      {
        'registry.vdf',
        'steam.cfg',
        'opensteamtool.dll',
        'dwmapi.dll',
        'version.dll',
        'xinput1_4.dll',
        'cloud_redirect.dll',
        'opensteamtool.toml',
      }.contains(parts.first) ||
      parts.first.startsWith('ssfn') ||
      relative.toLowerCase() == 'bin/dwmapi.dll';
}

Future<File> _clientFile(String root, String relative) async {
  if (relative.isEmpty ||
      p.posix.isAbsolute(relative) ||
      relative.contains('\\') ||
      relative.contains(':') ||
      relative.split('/').any((v) => v.isEmpty || v == '.' || v == '..') ||
      _preservedSteamPath(relative)) {
    throw const FormatException('Invalid Steam client file path');
  }
  var path = root;
  for (final part in relative.split('/')) {
    path = p.join(path, part);
    if (await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FileSystemException('Linked Steam client file');
    }
  }
  return File(path);
}

List<int> _bootstrapBytes(String zipPath, String arch) {
  final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
  final entry = archive.files
      .where((v) => v.isFile && v.name.toLowerCase() == 'steam.exe')
      .single;
  final bytes = Uint8List.fromList(entry.content);
  if (bytes.length < 64 || bytes[0] != 77 || bytes[1] != 90) {
    throw const FormatException('Invalid Steam bootstrap executable');
  }
  final data = ByteData.sublistView(bytes);
  final pe = data.getUint32(0x3c, Endian.little);
  if (pe + 6 > bytes.length ||
      data.getUint32(pe, Endian.little) != 0x00004550 ||
      data.getUint16(pe + 4, Endian.little) !=
          (arch == 'win64' ? 0x8664 : 0x14c)) {
    throw const FormatException('Steam bootstrap architecture mismatch');
  }
  return bytes;
}

Future<Map<String, int>> _installedFiles(File index) async {
  final files = <String, int>{};
  for (final line in await index.readAsLines()) {
    if (line.trim().isEmpty) continue;
    final match = RegExp(r'^(.*),(-?\d+);\d+;\d+$').firstMatch(line);
    if (match == null) {
      throw const FormatException('Invalid Steam installed-file index');
    }
    final size = int.parse(match[2]!);
    if (size < 0) continue;
    final relative = match[1]!.replaceAll('\\', '/');
    if (relative.isEmpty ||
        p.posix.isAbsolute(relative) ||
        relative.contains(':') ||
        relative.split('/').any((v) => v.isEmpty || v == '.' || v == '..')) {
      throw const FormatException('Invalid Steam installed-file path');
    }
    files[relative] = size;
  }
  return files;
}

Future<List<int>> _readBootstrap(String path, String arch) =>
    Isolate.run(() => _bootstrapBytes(path, arch));
