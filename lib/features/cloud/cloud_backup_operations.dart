part of 'cloud_service.dart';

extension CloudBackupOperations on CloudService {
  Future<Map<String, dynamic>> _backupDocument(CloudBackup backup) async {
    final base = p.normalize(p.absolute(paths.file('backups/cloud')));
    final target = p.normalize(p.absolute(backup.path));
    if (!p.isWithin(base, target) ||
        await FileSystemEntity.type(target, followLinks: false) !=
            FileSystemEntityType.directory) {
      throw FormatException(_l10n.cloudInvalidBackup);
    }
    final value = jsonDecode(
      await File(p.join(target, 'manifest.json')).readAsString(),
    );
    if (value is! Map<String, dynamic> ||
        value['app_id'] != backup.appId ||
        value['targets'] is! List) {
      throw FormatException(_l10n.cloudInvalidBackup);
    }
    final storedTarget = value['target'] is Map
        ? CloudTarget.fromJson(Map<String, dynamic>.from(value['target']))
        : null;
    if ((storedTarget == null) != (backup.target == null) ||
        storedTarget != null && !storedTarget.matches(backup.target!)) {
      throw FormatException(_l10n.cloudInvalidBackup);
    }
    final indices = <int>{};
    for (final raw in value['targets'] as List) {
      final item = raw as Map;
      if (item['index'] is! int ||
          item['index'] < 0 ||
          !indices.add(item['index'] as int) ||
          item['files'] is! List ||
          !RegExp(r'^\d+$').hasMatch(item['account_id'] as String? ?? '')) {
        throw FormatException(_l10n.cloudInvalidBackup);
      }
      if (!{
        'sync',
        'cache',
        'legacy-cache',
        'userdata',
        'remote',
      }.contains(item['kind'])) {
        throw FormatException(_l10n.cloudInvalidBackup);
      }
      if (item['kind'] == 'sync' &&
          (!p.isAbsolute(item['path'] as String) ||
              p.basename(item['path'] as String) != '${backup.appId}' ||
              p.basename(p.dirname(item['path'] as String)) !=
                  item['account_id'])) {
        throw FormatException(_l10n.cloudInvalidBackup);
      }
      for (final rawFile in item['files'] as List) {
        _validateRelative((rawFile as Map)['path'] as String);
      }
    }
    return value;
  }

  Future<List<CloudFileInfo>> backupFiles(CloudBackup backup) async {
    final data = await _backupDocument(backup);
    return [
      for (final target in data['targets'] as List)
        for (final file in target['files'] as List)
          CloudFileInfo(
            '${target['account_id']}/${target['kind']}/${file['path']}',
            file['size'] as int,
            sha256: file['sha256'] as String,
          ),
    ];
  }

  Future<void> verifyBackup(CloudBackup backup) async {
    final data = await _backupDocument(backup);
    for (final target in data['targets'] as List) {
      for (final record in target['files'] as List) {
        final file = File(
          p.join(
            backup.path,
            '${target['index']}',
            p.fromUri(Uri(path: record['path'])),
          ),
        );
        if ((await sha256.bind(file.openRead()).first).toString() !=
            record['sha256']) {
          throw FormatException(_l10n.cloudBackupChecksumFailed);
        }
      }
    }
    data['verified_at'] = DateTime.now().toUtc().toIso8601String();
    await atomicWrite(
      File(p.join(backup.path, 'manifest.json')),
      utf8.encode(jsonEncode(data)),
    );
  }

  Future<void> updateBackup(
    CloudBackup backup, {
    required String note,
    required bool pinned,
  }) async {
    final data = await _backupDocument(backup);
    data['note'] = note.trim();
    data['pinned'] = pinned;
    await atomicWrite(
      File(p.join(backup.path, 'manifest.json')),
      utf8.encode(jsonEncode(data)),
    );
    _notify();
  }

  Future<void> removeBackups(List<CloudBackup> values) async {
    for (final backup in values) {
      final data = await _backupDocument(backup);
      if (data['pinned'] == true) throw StateError(_l10n.cloudPinnedBackup);
    }
    for (final backup in values) {
      await Directory(backup.path).delete(recursive: true);
    }
    _notify();
  }

  Future<List<CloudBackup>> retentionCandidates({
    required int appId,
    required int keep,
    required int maxBytes,
  }) async {
    if (keep < 0 || maxBytes < 0) {
      throw FormatException(_l10n.cloudInvalidRetention);
    }
    final items = await backups(appId: appId);
    var count = 0, bytes = 0;
    final remove = <CloudBackup>[];
    for (final backup in items) {
      if (backup.pinned) continue;
      count++;
      bytes += backup.size;
      if (keep > 0 && count > keep || maxBytes > 0 && bytes > maxBytes) {
        remove.add(backup);
      }
    }
    return remove;
  }

  Future<void> saveRetention(int appId, int keep, int maxBytes) => settings.set(
    'cloudRetention:$appId',
    {'keep': keep, 'maxBytes': maxBytes},
  );

  Future<void> _assertTarget(CloudTarget? target) async {
    if (target == null) throw StateError(_l10n.cloudBackupTargetUnknown);
    if (!storageProfiles.any((v) => v.id == target.storageId)) {
      throw StateError(_l10n.cloudBackupTargetChanged);
    }
    final current = await targetFor(target.storageId);
    if (!target.matches(current)) {
      throw StateError(_l10n.cloudBackupTargetChanged);
    }
  }

  Future<CloudBackup?> _snapshotTargets(
    int appId,
    List<CloudBackupLocation> locations,
    CloudTarget? target,
    String reason,
    TaskContext? context,
  ) async {
    final targets = <CloudDeleteTarget>[];
    for (final location in locations) {
      final path = _localRestorePath(
        location.kind,
        location.accountId,
        appId,
        sourcePath: location.sourcePath.isEmpty ? null : location.sourcePath,
      );
      if (path != null) {
        if (!await Directory(path).exists()) continue;
        final count = await Isolate.run(() => _countDirectory(path));
        targets.add(
          CloudDeleteTarget(
            kind: location.kind,
            path: path,
            accountId: location.accountId,
            fileCount: count.$1,
            size: count.$2,
          ),
        );
      } else {
        final remote = await remoteFor(target!.storageId);
        final directory = '${location.accountId}/$appId';
        final files = await _remoteFiles(remote, directory, context);
        if (files.isEmpty) continue;
        targets.add(
          CloudDeleteTarget(
            kind: 'remote',
            path: directory,
            accountId: location.accountId,
            fileCount: files.length,
            size: files.fold(0, (sum, f) => sum + f.size),
          ),
        );
      }
    }
    if (targets.isEmpty) return null;
    return _backupPreview(
      CloudDeletePreview(
        appId: appId,
        provider: target?.provider ?? provider,
        target: target,
        targets: targets,
        backupDirectory: paths.file(
          'backups/cloud/$appId-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
      context,
      reason: reason,
    );
  }

  Future<CloudSyncResult> synchronize(
    CloudSave save, {
    TaskContext? context,
  }) async {
    if (!save.isRemote || save.storageId != activeStorageId) {
      throw StateError(_l10n.cloudSyncActiveOnly);
    }
    if ((await _processReader()).any(
      (v) => p.basename(v.executablePath).toLowerCase() == 'steam.exe',
    )) {
      throw StateError(_l10n.cloudSteamMustStop);
    }
    final plugin = await inspectPlugin();
    if (!plugin.installed) throw StateError(_l10n.cloudInstallPluginFirst);
    final target = await targetFor(save.storageId);
    final remote = await remoteFor(save.storageId);
    final cn = BigInt.tryParse(
      utf8.decode(await remote.read('${save.path}/cn.cloudredirect')).trim(),
    );
    if (cn == null || cn < BigInt.zero) {
      throw FormatException(_l10n.cloudSyncMetadataMissing);
    }
    final manifest = jsonDecode(
      utf8.decode(await remote.read('${save.path}/manifest.cloudredirect')),
    );
    if (manifest is! Map<String, dynamic> ||
        manifest.values.any(
          (v) =>
              v is! Map ||
              v['sha'] is! String ||
              !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(v['sha']) ||
              v['size'] is! int ||
              v['size'] < 0,
        )) {
      throw FormatException(_l10n.cloudSyncMetadataMissing);
    }
    for (final path in manifest.keys) {
      _validateRelative(path);
    }
    final before = await _snapshotTargets(
      save.appId,
      [
        CloudBackupLocation(
          kind: 'cache',
          accountId: save.accountId,
          sourcePath: '',
        ),
      ],
      target,
      'beforeSync',
      context,
    );
    await _assertTarget(target);
    context?.checkCancelled();
    final cache = Directory(
      p.join(
        settings.steamPath,
        'cloud_redirect',
        'storage',
        save.accountId,
        '${save.appId}',
      ),
    );
    try {
      final result = await _nativeRunner(
        library: plugin.path,
        provider: target.provider,
        accountId: save.accountId,
        appId: save.appId,
        cloudRoot: p.join(settings.steamPath, 'cloud_redirect'),
        context: context,
      );
      if (result['success'] != true ||
          result['drained'] != true ||
          result['local_cn'] is! int ||
          BigInt.from(result['local_cn'] as int) < cn ||
          result['local_file_count'] is! int) {
        throw StateError(_l10n.cloudSyncNotVerified);
      }
      final local = File(
        p.join(
          settings.steamPath,
          'cloud_redirect',
          'storage',
          save.accountId,
          '${save.appId}',
          'cn.cloudredirect',
        ),
      );
      if (!await local.exists() ||
          BigInt.tryParse((await local.readAsString()).trim()) !=
              BigInt.from(result['local_cn'] as int)) {
        throw StateError(_l10n.cloudSyncNotVerified);
      }
      for (final entry in manifest.entries) {
        final info = entry.value as Map;
        final file = File(p.join(cache.path, p.fromUri(Uri(path: entry.key))));
        if (!await file.exists() ||
            await file.length() != info['size'] ||
            (await sha1.bind(file.openRead()).first).toString() !=
                info['sha']) {
          throw StateError(_l10n.cloudSyncNotVerified);
        }
      }
      final receipt = CloudSyncResult(
        at: DateTime.now(),
        changed: result['had_newer'] == true,
        fileCount: result['local_file_count'] as int,
        changeNumber: result['local_cn'] as int,
      );
      syncResults[save.id] = receipt;
      await settings.set('cloudSync:${save.id}', receipt.toJson());
      await _refreshAfterMutation(appId: save.appId);
      return receipt;
    } catch (_) {
      if (before != null) {
        await _applyBackup(await _backupDocument(before), before, null);
      } else if (await cache.exists()) {
        await cache.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<
    ({List<String> localOnly, List<String> remoteOnly, List<String> changed})
  >
  compareRepository(CloudSave local, CloudSave remote) async {
    Future<Map<String, dynamic>> manifest(CloudSave save) async {
      final bytes = save.isRemote
          ? await (await remoteFor(
              save.storageId,
            )).read('${save.path}/manifest.cloudredirect')
          : await File(
              p.join(save.path, 'manifest.cloudredirect'),
            ).readAsBytes();
      final data = jsonDecode(utf8.decode(bytes));
      if (data is! Map<String, dynamic> ||
          data.values.any(
            (v) => v is! Map || v['sha'] is! String || v['size'] is! num,
          )) {
        throw FormatException(_l10n.cloudSyncMetadataMissing);
      }
      return data;
    }

    final a = await manifest(local), b = await manifest(remote);
    return (
      localOnly: a.keys.where((key) => !b.containsKey(key)).toList(),
      remoteOnly: b.keys.where((key) => !a.containsKey(key)).toList(),
      changed: a.keys
          .where(
            (key) =>
                b.containsKey(key) && !mapEquals(a[key] as Map, b[key] as Map),
          )
          .toList(),
    );
  }
}
