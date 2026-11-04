// Reimplemented from Fluent-Steam-Lua cloud management (zlib).
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../platform/windows/dpapi.dart';
import 'cloud_credentials.dart';
import 'cloud_models.dart';
import 'cloud_oauth.dart';
import 'remote/cloud_remote.dart';

export 'cloud_credentials.dart' show CredentialCodec;
export 'cloud_models.dart';

class CloudService extends ChangeNotifier {
  CloudService({
    required this.paths,
    required this.settings,
    http.Client? client,
    String? configDirectory,
    CredentialCodec? credentialCodec,
    Future<bool> Function(Uri)? openBrowser,
    RemoteStore? remoteStore,
  }) : client = client ?? http.Client(),
       configDirectory =
           configDirectory ??
           p.join(
             Platform.environment['APPDATA'] ?? paths.root,
             'CloudRedirect',
           ),
       _remoteOverride = remoteStore {
    credentials = CloudCredentialStore(
      this.configDirectory,
      credentialCodec ??
          CredentialCodec(
            protect: WindowsDpapi.protectBytes,
            unprotect: WindowsDpapi.unprotectBytes,
          ),
    );
    oauth = CloudOAuth(
      client: this.client,
      credentials: credentials,
      openBrowser:
          openBrowser ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  }

  final AppPaths paths;
  final SettingsStore settings;
  final http.Client client;
  final String configDirectory;
  final RemoteStore? _remoteOverride;
  late final CloudCredentialStore credentials;
  late final CloudOAuth oauth;
  static const providers = [
    'folder',
    'gdrive',
    'onedrive',
    'r2',
    's3',
    'webdav',
  ];
  List<CloudSave> _saves = [];
  List<CloudSave> get saves => List.unmodifiable(_saves);
  CloudStatus status = const CloudStatus(
    enabled: false,
    syncPath: '',
    provider: 'folder',
    configured: false,
  );
  String get provider => status.provider;
  String? lastError;
  bool loading = false;

  File get _configFile => File(p.join(configDirectory, 'config.json'));
  String get syncPath => status.syncPath.isNotEmpty
      ? status.syncPath
      : settings.steamPath.isNotEmpty
      ? p.join(settings.steamPath, 'Cloud_Archiving')
      : paths.file('saves');

  Future<Map<String, dynamic>> _readConfig() async {
    if (!await _configFile.exists()) return {};
    final value = jsonDecode(await _configFile.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid CloudRedirect config');
    }
    return value;
  }

  Future<void> _writeConfig(Map<String, dynamic> values) async {
    final config = await _readConfig();
    config.addAll(values);
    await atomicWrite(
      _configFile,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(config)),
    );
  }

  Future<void> refresh({int? appId, TaskContext? context}) async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final config = await _readConfig();
      final selected = config['provider'] is String
          ? config['provider'] as String
          : 'folder';
      if (!providers.contains(selected)) {
        throw FormatException('Unknown cloud provider: $selected');
      }
      final configured =
          selected == 'folder' ||
          _remoteOverride != null ||
          await credentials.read(selected) != null;
      status = CloudStatus(
        enabled: await _redirectEnabled(),
        syncPath: config['sync_path'] as String? ?? '',
        provider: selected,
        configured: configured,
      );
      final localRoot = syncPath;
      final local = await Isolate.run(() => _scanLocalSaves(localRoot));
      _saves = local;
      if (selected != 'folder' && configured) {
        final remote = await _remote();
        final remoteSaves = <CloudSave>[];
        for (final account in await remote.list('')) {
          context?.checkCancelled();
          if (!account.isDirectory ||
              int.tryParse(p.posix.basename(account.path)) == null) {
            continue;
          }
          for (final app in await remote.list(account.path)) {
            final id = int.tryParse(p.posix.basename(app.path));
            if (!app.isDirectory || id == null || id <= 0) continue;
            final files = await _remoteFiles(remote, app.path, context);
            final timestamps =
                files
                    .map((file) => file.modifiedAt)
                    .whereType<DateTime>()
                    .toList()
                  ..sort();
            remoteSaves.add(
              CloudSave(
                appId: id,
                accountId: p.posix.basename(account.path),
                path: app.path,
                isRemote: true,
                fileCount: files.length,
                size: files.fold(0, (sum, file) => sum + file.size),
                modifiedAt: timestamps.isNotEmpty
                    ? timestamps.last
                    : app.modifiedAt,
              ),
            );
          }
        }
        _saves = [...local, ...remoteSaves];
      }
      _saves.sort((a, b) => a.appId.compareTo(b.appId));
    } catch (error) {
      lastError = error.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setSyncPath(String path, {TaskContext? context}) async {
    if (!p.isAbsolute(path)) throw ArgumentError('Save path must be absolute');
    final source = await _resolveSavePath(syncPath);
    final destination = await _resolveSavePath(path);
    final samePath = p.equals(source, destination);
    if (!samePath &&
        (p.isWithin(source, destination) || p.isWithin(destination, source))) {
      throw ArgumentError('Save folders cannot contain one another');
    }
    Directory? stage;
    Directory? previous;
    var promoted = false;
    try {
      if (!samePath) {
        context?.checkCancelled();
        context?.report('Copying saves; the original folder will be retained');
        final stagePath = await Isolate.run(
          () => _stageSavePath(source, destination),
        );
        stage = Directory(stagePath);
        context?.checkCancelled();
        final target = Directory(destination);
        if (await target.exists()) {
          if (!await target.list().isEmpty) {
            throw FileSystemException(
              'Destination changed during copying; nothing was overwritten',
              destination,
            );
          }
          previous = await target.rename('$stagePath.previous');
        }
        await stage.rename(destination);
        promoted = true;
      } else {
        await Directory(destination).create(recursive: true);
      }
      await _writeConfig({
        'sync_path': destination,
        'sync_achievements': true,
        'sync_playtime': true,
        'auto_update_dll': false,
      });
    } catch (_) {
      if (promoted) await Directory(destination).rename(stage!.path);
      if (previous != null) await previous.rename(destination);
      rethrow;
    } finally {
      if (stage != null && await stage.exists()) {
        await stage.delete(recursive: true);
      }
    }
    if (previous != null) await previous.delete();
    await refresh();
    context?.report('Save folder changed. Restart Steam to apply it.');
  }

  Future<void> configureProvider(
    String selected,
    Map<String, dynamic> values,
  ) async {
    if (!providers.contains(selected)) {
      throw ArgumentError.value(selected, 'provider');
    }
    var storedValues = values;
    if (selected != 'folder' &&
        selected != 'gdrive' &&
        selected != 'onedrive') {
      // Config constructors validate the external form before it is written for the DLL.
      if (selected == 'webdav') {
        final config = WebDavConfig.fromJson(values);
        WebDavRemoteStore(client, config);
        if (['basic', 'auto', 'digest'].contains(config.auth) &&
            config.username.isEmpty) {
          throw const FormatException('A WebDAV username is required');
        }
        if (config.auth == 'bearer' && config.bearerToken.isEmpty) {
          throw const FormatException('A WebDAV bearer token is required');
        }
        storedValues = config.toJson();
      } else {
        final normalized = selected == 'r2' ? _r2Config(values) : values;
        S3RemoteStore(client, S3Config.fromJson(normalized));
      }
      await credentials.write(selected, storedValues);
    }
    final config = await _readConfig();
    final tokenPaths = Map<String, dynamic>.from(
      config['token_paths'] as Map? ?? {},
    );
    if (selected != 'folder') tokenPaths[selected] = credentials.path(selected);
    await _writeConfig({
      'provider': selected,
      'sync_path': syncPath,
      'sync_achievements': true,
      'sync_playtime': true,
      'auto_update_dll': false,
      'token_paths': tokenPaths,
      if (selected != 'folder') 'token_path': credentials.path(selected),
    });
    await refresh();
  }

  Future<Map<String, dynamic>?> providerConfiguration(String selected) =>
      credentials.read(selected);

  Future<void> authorize(String selected, {TaskContext? context}) async {
    await oauth.authorize(selected, context: context);
    await configureProvider(selected, {});
  }

  Future<void> signOut(String selected) async {
    await credentials.signOut(selected);
    if (selected == provider) await configureProvider('folder', {});
    await refresh();
  }

  Future<void> testConnection() async => (await _remote()).testConnection();

  Future<CloudPluginStatus> inspectPlugin() async {
    if (settings.steamPath.isEmpty) {
      return const CloudPluginStatus(
        installed: false,
        enabled: false,
        path: '',
      );
    }
    final config = await _readKernelConfig();
    final target = _pluginTarget(config.$2);
    final file = File(target);
    if (!await file.exists()) {
      return CloudPluginStatus(
        installed: false,
        enabled: _tomlValue(config.$2, 'cloud', 'enabled') == 'true',
        path: target,
      );
    }
    final stat = await file.stat();
    return CloudPluginStatus(
      installed: true,
      enabled: _tomlValue(config.$2, 'cloud', 'enabled') == 'true',
      path: target,
      size: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<void> removePlugin({TaskContext? context}) async {
    final plugin = await inspectPlugin();
    if (!plugin.installed) return;
    await _setKernelEnabled(false);
    final file = File(plugin.path);
    if (await file.exists()) {
      final backup = File(
        paths.file(
          'backups/cloud-dll/${DateTime.now().microsecondsSinceEpoch}.dll',
        ),
      );
      await backup.parent.create(recursive: true);
      await file.copy(backup.path);
      context?.checkCancelled();
      await file.delete();
    }
    await refresh();
  }

  Map<String, dynamic> _r2Config(Map<String, dynamic> value) => {
    ...value,
    'endpoint': (value['endpoint'] as String? ?? '').isNotEmpty
        ? value['endpoint']
        : 'https://${value['account_id']}.r2.cloudflarestorage.com',
    'region': 'auto',
  };

  Future<RemoteStore> _remote() async {
    if (_remoteOverride != null) return _remoteOverride;
    final value = provider == 'folder'
        ? null
        : await credentials.read(provider);
    if (value == null) {
      throw StateError('Configure the selected cloud provider first');
    }
    return switch (provider) {
      'webdav' => WebDavRemoteStore(client, WebDavConfig.fromJson(value)),
      's3' => S3RemoteStore(client, S3Config.fromJson(value)),
      'r2' => S3RemoteStore(client, S3Config.fromJson(_r2Config(value))),
      'gdrive' => GoogleDriveRemoteStore(
        client,
        () => oauth.accessToken('gdrive'),
      ),
      'onedrive' => OneDriveRemoteStore(
        client,
        () => oauth.accessToken('onedrive'),
      ),
      _ => throw StateError('Local folder mode has no remote connection'),
    };
  }

  Future<void> enableRedirect({TaskContext? context}) async {
    final steam = settings.steamPath;
    if (steam.isEmpty || !await File(p.join(steam, 'steam.exe')).exists()) {
      throw StateError('Select a valid Steam directory first');
    }
    context?.report('Downloading CloudRedirect native library');
    const base =
        'https://github.com/huanyuejue/CloudRedirect/releases/latest/download';
    final checksums = await client
        .get(Uri.parse('$base/cloud_redirect.dll.sha256'))
        .timeout(const Duration(seconds: 30));
    if (checksums.statusCode != 200) {
      throw HttpException(
        'CloudRedirect checksum HTTP ${checksums.statusCode}',
      );
    }
    final expected = checksums.body
        .trim()
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
      throw const FormatException('Invalid CloudRedirect checksum');
    }
    context?.checkCancelled();
    final response = await client
        .get(Uri.parse('$base/cloud_redirect.dll'))
        .timeout(const Duration(minutes: 2));
    if (response.statusCode != 200) {
      throw HttpException('CloudRedirect DLL HTTP ${response.statusCode}');
    }
    if (sha256.convert(response.bodyBytes).toString() != expected) {
      throw const FormatException('CloudRedirect DLL SHA256 mismatch');
    }
    context?.checkCancelled();
    final toml = await _readKernelConfig();
    final target = _pluginTarget(toml.$2);
    final existing = File(target);
    if (await existing.exists()) {
      final backup = File(
        paths.file(
          'backups/cloud-dll/${DateTime.now().microsecondsSinceEpoch}.dll',
        ),
      );
      await backup.parent.create(recursive: true);
      await existing.copy(backup.path);
    }
    await atomicWrite(existing, response.bodyBytes);
    await Directory(syncPath).create(recursive: true);
    await _writeConfig({
      'provider': provider,
      'sync_path': syncPath,
      'sync_achievements': true,
      'sync_playtime': true,
      'auto_update_dll': false,
    });
    await _setKernelEnabled(true);
    await refresh();
    context?.report('Enabled. Restart Steam for the native library to load.');
  }

  Future<void> disableRedirect() async {
    await _setKernelEnabled(false);
    await refresh();
  }

  Future<(File, String)> _readKernelConfig() async {
    if (settings.steamPath.isEmpty) {
      throw StateError('Steam directory is not configured');
    }
    final main = File(p.join(settings.steamPath, 'opensteamtool.toml'));
    final example = File(
      p.join(settings.steamPath, 'opensteamtool.example.toml'),
    );
    final file = await main.exists()
        ? main
        : await example.exists()
        ? example
        : main;
    return (file, await file.exists() ? await file.readAsString() : '');
  }

  String _pluginTarget(String toml) {
    final steam = settings.steamPath;
    final library = _tomlValue(toml, 'cloud', 'library');
    return library == null
        ? p.join(steam, 'cloud_redirect.dll')
        : p.isAbsolute(library)
        ? library
        : p.join(steam, library);
  }

  Future<bool> _redirectEnabled() async {
    if (settings.steamPath.isEmpty) return false;
    final config = await _readKernelConfig();
    return _tomlValue(config.$2, 'cloud', 'enabled') == 'true';
  }

  Future<void> _setKernelEnabled(bool enabled) async {
    final config = await _readKernelConfig();
    final lines = const LineSplitter().convert(config.$2).toList();
    var start = lines.indexWhere((line) => line.trim() == '[cloud]');
    if (start < 0) {
      lines.addAll(['', '[cloud]']);
      start = lines.length - 1;
    }
    var end = lines.length;
    for (var i = start + 1; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('[')) {
        end = i;
        break;
      }
    }
    final index = lines.indexWhere(
      (line) => RegExp(r'^\s*enabled\s*=').hasMatch(line),
      start + 1,
    );
    if (index >= 0 && index < end) {
      lines[index] = 'enabled = $enabled';
    } else {
      lines.insert(end, 'enabled = $enabled');
    }
    await atomicWrite(config.$1, utf8.encode('${lines.join('\n')}\n'));
    final pin = File(
      p.join(settings.steamPath, 'cloud_redirect', 'config.json'),
    );
    if (await pin.exists()) {
      final value = jsonDecode(await pin.readAsString());
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid Steam CloudRedirect pin config');
      }
      value['cloud_redirect'] = enabled;
      await atomicWrite(pin, utf8.encode(jsonEncode(value)));
    }
  }

  static String? _tomlValue(String source, String section, String key) {
    var active = false;
    for (final line in const LineSplitter().convert(source)) {
      final text = line.trim();
      if (text.startsWith('[')) {
        active = text == '[$section]';
        continue;
      }
      if (!active || text.startsWith('#')) continue;
      final match = RegExp(
        '^${RegExp.escape(key)}\\s*=\\s*(.*)',
      ).firstMatch(text);
      if (match != null) {
        final value = match.group(1)!.split(' #').first.trim();
        if (value.startsWith('"') && value.endsWith('"')) {
          return value.substring(1, value.length - 1).replaceAll(r'\\', '\\');
        }
        if (value.startsWith("'") && value.endsWith("'")) {
          return value.substring(1, value.length - 1);
        }
        return value;
      }
    }
    return null;
  }

  Future<CloudDeletePreview> previewDelete(
    int appId, {
    TaskContext? context,
  }) async {
    if (appId <= 0) throw ArgumentError.value(appId, 'appId');
    final targets = <CloudDeleteTarget>[];
    final roots = <String, String>{'sync': syncPath};
    if (settings.steamPath.isNotEmpty) {
      roots['cache'] = p.join(settings.steamPath, 'cloud_redirect', 'storage');
      roots['legacy-cache'] = p.join(
        settings.steamPath,
        'cloud_redirect',
        'blobs',
      );
      roots['userdata'] = p.join(settings.steamPath, 'userdata');
    }
    for (final root in roots.entries) {
      if (!await Directory(root.value).exists()) continue;
      await for (final account in Directory(
        root.value,
      ).list(followLinks: false)) {
        if (account is! Directory ||
            int.tryParse(p.basename(account.path)) == null) {
          continue;
        }
        final target = Directory(p.join(account.path, '$appId'));
        if (!await target.exists()) continue;
        final count = await Isolate.run(() => _countDirectory(target.path));
        targets.add(
          CloudDeleteTarget(
            kind: root.key,
            path: target.path,
            accountId: p.basename(account.path),
            fileCount: count.$1,
            size: count.$2,
          ),
        );
      }
    }
    if (provider != 'folder' && status.configured) {
      final remote = await _remote();
      for (final account in await remote.list('')) {
        context?.checkCancelled();
        if (!account.isDirectory ||
            int.tryParse(p.posix.basename(account.path)) == null) {
          continue;
        }
        final apps = await remote.list(account.path);
        for (final app in apps.where(
          (entry) =>
              entry.isDirectory && p.posix.basename(entry.path) == '$appId',
        )) {
          final files = await _remoteFiles(remote, app.path, context);
          targets.add(
            CloudDeleteTarget(
              kind: 'remote',
              path: app.path,
              accountId: p.posix.basename(account.path),
              fileCount: files.length,
              size: files.fold(0, (sum, file) => sum + file.size),
            ),
          );
        }
      }
    }
    return CloudDeletePreview(
      appId: appId,
      provider: provider,
      targets: targets,
      backupDirectory: p.normalize(
        paths.file(
          'backups/cloud/$appId-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
    );
  }

  Future<CloudBackup> backup(int appId, {TaskContext? context}) async {
    final preview = await previewDelete(appId, context: context);
    return _backupPreview(preview, context);
  }

  Future<CloudBackup> _backupPreview(
    CloudDeletePreview preview,
    TaskContext? context,
  ) async {
    if (preview.targets.isEmpty) {
      throw StateError('No saves found for this game');
    }
    final records = <Map<String, dynamic>>[];
    var totalBytes = 0;
    for (var i = 0; i < preview.targets.length; i++) {
      context?.checkCancelled();
      final target = preview.targets[i];
      context?.report('Backing up ${target.path}', i / preview.targets.length);
      final targetDir = Directory(p.join(preview.backupDirectory, '$i'));
      await targetDir.create(recursive: true);
      final files = <Map<String, dynamic>>[];
      if (target.isRemote) {
        final remote = await _remote();
        for (final file in await _remoteFiles(remote, target.path, context)) {
          context?.checkCancelled();
          final relative = p.posix.relative(file.path, from: target.path);
          _validateRelative(relative);
          final bytes = await remote.read(file.path);
          await atomicWrite(
            File(p.join(targetDir.path, p.fromUri(Uri(path: relative)))),
            bytes,
          );
          files.add({
            'path': relative,
            'size': bytes.length,
            'sha256': sha256.convert(bytes).toString(),
          });
          totalBytes += bytes.length;
        }
      } else {
        for (final file in await _localFiles(target.path)) {
          context?.checkCancelled();
          final relative = p
              .relative(file.path, from: target.path)
              .replaceAll('\\', '/');
          final bytes = await file.readAsBytes();
          await atomicWrite(
            File(p.join(targetDir.path, p.fromUri(Uri(path: relative)))),
            bytes,
          );
          files.add({
            'path': relative,
            'size': bytes.length,
            'sha256': sha256.convert(bytes).toString(),
          });
          totalBytes += bytes.length;
        }
      }
      if (files.length != target.fileCount ||
          files.fold<int>(0, (sum, f) => sum + (f['size'] as int)) !=
              target.size) {
        throw StateError(
          'Save files changed since preview; refresh and try again. Backup retained.',
        );
      }
      records.add({
        'kind': target.kind,
        'path': target.path,
        'account_id': target.accountId,
        'files': files,
        'index': i,
      });
    }
    final created = DateTime.now().toUtc();
    await atomicWrite(
      File(p.join(preview.backupDirectory, 'manifest.json')),
      utf8.encode(
        jsonEncode({
          'version': 1,
          'app_id': preview.appId,
          'provider': preview.provider,
          'created_at': created.toIso8601String(),
          'targets': records,
        }),
      ),
    );
    return CloudBackup(
      path: preview.backupDirectory,
      appId: preview.appId,
      createdAt: created,
      fileCount: records.fold(0, (sum, r) => sum + (r['files'] as List).length),
      size: totalBytes,
    );
  }

  Future<CloudBackup> delete(
    CloudDeletePreview preview, {
    TaskContext? context,
  }) async {
    if (preview.provider != provider) {
      throw StateError('Cloud provider changed; request a new preview');
    }
    final fresh = await previewDelete(preview.appId, context: context);
    if (!_samePreview(preview, fresh)) {
      throw StateError('Save files changed; request a new delete preview');
    }
    final backup = await _backupPreview(preview, context);
    final manifest =
        jsonDecode(
              await File(p.join(backup.path, 'manifest.json')).readAsString(),
            )
            as Map<String, dynamic>;
    // Verify every source against its backup before removing any source.
    for (final value in manifest['targets'] as List) {
      final target = value as Map<String, dynamic>;
      for (final value in target['files'] as List) {
        context?.checkCancelled();
        final file = value as Map<String, dynamic>;
        final bytes = target['kind'] == 'remote'
            ? await (await _remote()).read(
                p.posix.join(target['path'] as String, file['path'] as String),
              )
            : await File(
                p.join(
                  target['path'] as String,
                  p.fromUri(Uri(path: file['path'] as String)),
                ),
              ).readAsBytes();
        if (sha256.convert(bytes).toString() != file['sha256']) {
          throw StateError('A save changed during backup; nothing deleted');
        }
      }
    }
    for (final target in preview.targets) {
      context?.checkCancelled();
      if (target.isRemote) {
        await (await _remote()).delete(target.path);
      } else {
        await Directory(target.path).delete(recursive: true);
      }
    }
    await refresh();
    return backup;
  }

  static bool _samePreview(CloudDeletePreview a, CloudDeletePreview b) {
    if (a.targets.length != b.targets.length) return false;
    final other = {for (final t in b.targets) '${t.kind}:${t.path}': t};
    return a.targets.every(
      (t) =>
          other['${t.kind}:${t.path}']?.fileCount == t.fileCount &&
          other['${t.kind}:${t.path}']?.size == t.size,
    );
  }

  Future<List<CloudBackup>> backups({int? appId}) async {
    final root = paths.directory('backups/cloud');
    if (!await root.exists()) return [];
    final values = <CloudBackup>[];
    await for (final item in root.list(followLinks: false)) {
      if (item is! Directory) continue;
      final file = File(p.join(item.path, 'manifest.json'));
      if (!await file.exists()) continue;
      final value =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (appId != null && value['app_id'] != appId) continue;
      final files = (value['targets'] as List)
          .expand((t) => (t as Map)['files'] as List)
          .cast<Map>();
      values.add(
        CloudBackup(
          path: p.normalize(item.path),
          appId: value['app_id'] as int,
          createdAt: DateTime.parse(value['created_at'] as String),
          fileCount: files.length,
          size: files.fold(0, (sum, f) => sum + (f['size'] as int)),
        ),
      );
    }
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  Future<void> restore(CloudBackup backup, {TaskContext? context}) async {
    final value = jsonDecode(
      await File(p.join(backup.path, 'manifest.json')).readAsString(),
    );
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['app_id'] != backup.appId) {
      throw const FormatException('Invalid cloud backup manifest');
    }
    // Check the entire imported backup before performing writes to any target.
    for (final raw in value['targets'] as List) {
      final target = raw as Map<String, dynamic>;
      if (target['index'] is! int || (target['index'] as int) < 0) {
        throw const FormatException('Invalid backup target index');
      }
      for (final raw in target['files'] as List) {
        context?.checkCancelled();
        final file = raw as Map<String, dynamic>;
        final relative = file['path'] as String;
        _validateRelative(relative);
        final bytes = await File(
          p.join(
            backup.path,
            '${target['index']}',
            p.fromUri(Uri(path: relative)),
          ),
        ).readAsBytes();
        if (sha256.convert(bytes).toString() != file['sha256']) {
          throw const FormatException('Backup checksum mismatch');
        }
      }
    }
    final staged = <(Directory, Directory, Directory?)>[];
    for (final raw in value['targets'] as List) {
      final target = raw as Map<String, dynamic>;
      if (target['kind'] == 'remote') {
        if (value['provider'] != provider) {
          throw StateError('Select the backup cloud provider before restoring');
        }
      }
      final account = target['account_id'] as String;
      if (int.tryParse(account) == null) {
        throw const FormatException('Invalid backup account');
      }
      final localDestination = switch (target['kind']) {
        'sync' => p.join(syncPath, account, '${backup.appId}'),
        'cache' => p.join(
          settings.steamPath,
          'cloud_redirect',
          'storage',
          account,
          '${backup.appId}',
        ),
        'legacy-cache' => p.join(
          settings.steamPath,
          'cloud_redirect',
          'blobs',
          account,
          '${backup.appId}',
        ),
        'userdata' => p.join(
          settings.steamPath,
          'userdata',
          account,
          '${backup.appId}',
        ),
        'remote' => null,
        _ => throw const FormatException('Unknown backup target'),
      };
      if (localDestination != null &&
          target['kind'] != 'sync' &&
          settings.steamPath.isEmpty) {
        throw StateError('Configure Steam directory before restoring');
      }
      final stage = localDestination == null
          ? null
          : Directory(
              '$localDestination.restore-${DateTime.now().microsecondsSinceEpoch}',
            );
      if (stage != null) await stage.create(recursive: true);
      for (final raw in target['files'] as List) {
        context?.checkCancelled();
        final file = raw as Map<String, dynamic>;
        final relative = file['path'] as String;
        _validateRelative(relative);
        final source = File(
          p.join(
            backup.path,
            '${target['index']}',
            p.fromUri(Uri(path: relative)),
          ),
        );
        final bytes = await source.readAsBytes();
        if (sha256.convert(bytes).toString() != file['sha256']) {
          throw const FormatException('Backup checksum mismatch');
        }
        if (stage != null) {
          await atomicWrite(
            File(p.join(stage.path, p.fromUri(Uri(path: relative)))),
            bytes,
          );
        } else {
          await (await _remote()).write(
            p.posix.join(account, '${backup.appId}', relative),
            bytes,
          );
        }
      }
      if (stage != null) {
        final destination = Directory(localDestination!);
        // Keep the previous directory on its own volume so rename remains atomic.
        final previous = await destination.exists()
            ? Directory(
                '${destination.path}.before-restore-${DateTime.now().microsecondsSinceEpoch}',
              )
            : null;
        staged.add((stage, destination, previous));
      }
    }
    for (final (stage, destination, previous) in staged) {
      context?.checkCancelled();
      if (previous != null) {
        await previous.parent.create(recursive: true);
        await destination.rename(previous.path);
      }
      try {
        await stage.rename(destination.path);
      } catch (_) {
        if (previous != null) await previous.rename(destination.path);
        rethrow;
      }
    }
    await refresh();
  }

  Future<void> download(
    CloudSave save,
    String destination, {
    TaskContext? context,
  }) async {
    if (!save.isRemote) throw ArgumentError('Selected save is already local');
    final remote = await _remote();
    for (final file in await _remoteFiles(remote, save.path, context)) {
      context?.checkCancelled();
      final relative = p.posix.relative(file.path, from: save.path);
      _validateRelative(relative);
      await atomicWrite(
        File(p.join(destination, p.fromUri(Uri(path: relative)))),
        await remote.read(file.path),
      );
    }
  }

  Future<void> upload(CloudSave save, {TaskContext? context}) async {
    if (save.isRemote) throw ArgumentError('Selected save is already remote');
    final remote = await _remote();
    for (final file in await _localFiles(save.path)) {
      context?.checkCancelled();
      final relative = p
          .relative(file.path, from: save.path)
          .replaceAll('\\', '/');
      await remote.write(
        p.posix.join(save.accountId, '${save.appId}', relative),
        await file.readAsBytes(),
      );
    }
    await refresh();
  }

  Future<void> openSave(CloudSave save) async {
    if (save.isRemote) {
      throw StateError('Download the remote save to inspect its files');
    }
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [
        save.path,
      ], mode: ProcessStartMode.detached);
      return;
    }
    if (!await launchUrl(Uri.directory(save.path))) {
      throw StateError('Could not open save folder');
    }
  }
}

Future<String> _resolveSavePath(String path) async {
  var existing = p.normalize(path);
  final suffix = <String>[];
  while (await FileSystemEntity.type(existing, followLinks: false) ==
      FileSystemEntityType.notFound) {
    suffix.insert(0, p.basename(existing));
    final parent = p.dirname(existing);
    if (parent == existing) {
      throw FileSystemException('Save folder has no accessible parent', path);
    }
    existing = parent;
  }
  if (!await Directory(existing).exists()) {
    throw FileSystemException('Save path is not a directory', existing);
  }
  final resolved = await Directory(existing).resolveSymbolicLinks();
  return p.normalize(p.joinAll([resolved, ...suffix]));
}

Future<String> _stageSavePath(String source, String destination) async {
  final target = Directory(destination);
  if (p.dirname(destination) == destination) {
    throw ArgumentError('Choose a dedicated save folder, not a drive root');
  }
  if (await target.exists() && !await target.list().isEmpty) {
    throw FileSystemException(
      'Choose an empty destination; existing files will not be overwritten',
      destination,
    );
  }
  await target.parent.create(recursive: true);
  final stage = await target.parent.createTemp(
    '${p.basename(destination)}.flsteam-migrate-',
  );
  try {
    final original = Directory(source);
    if (await original.exists()) {
      final snapshot = <String, String>{};
      await for (final entry in original.list(
        recursive: true,
        followLinks: false,
      )) {
        final relative = p.relative(entry.path, from: source);
        final copyPath = p.join(stage.path, relative);
        if (entry is Link) {
          throw FileSystemException(
            'Linked save entries are not supported',
            entry.path,
          );
        }
        if (entry is Directory) {
          await Directory(copyPath).create(recursive: true);
          snapshot[relative] = 'directory';
        } else if (entry is File) {
          await Directory(p.dirname(copyPath)).create(recursive: true);
          final copy = await entry.copy(copyPath);
          await copy.setLastModified(await entry.lastModified());
          snapshot[relative] = (await sha256.bind(copy.openRead()).first)
              .toString();
        }
      }
      // Steam must be closed during migration. Detect writes that occurred
      // while copying before the native config starts using the new directory.
      final current = <String, String>{};
      await for (final entry in original.list(
        recursive: true,
        followLinks: false,
      )) {
        final relative = p.relative(entry.path, from: source);
        current[relative] = entry is Directory
            ? 'directory'
            : entry is File
            ? (await sha256.bind(entry.openRead()).first).toString()
            : 'unsupported';
      }
      if (!mapEquals(snapshot, current)) {
        throw StateError('Save files changed; close Steam and try again');
      }
    }
    if (await target.exists() && !await target.list().isEmpty) {
      throw FileSystemException(
        'Destination changed during copying; nothing was overwritten',
        destination,
      );
    }
    return stage.path;
  } catch (_) {
    await stage.delete(recursive: true);
    rethrow;
  }
}

void _validateRelative(String path) {
  if (path.isEmpty ||
      p.posix.isAbsolute(path) ||
      path.contains('\\') ||
      path.split('/').any((part) => part == '..' || part.contains(':'))) {
    throw FormatException('Invalid save relative path: $path');
  }
}

Future<List<File>> _localFiles(String root) async {
  final result = <File>[];
  if (!await Directory(root).exists()) return result;
  await for (final entity in Directory(
    root,
  ).list(recursive: true, followLinks: false)) {
    if (entity is Link) {
      throw FileSystemException(
        'Linked save entries are not supported',
        entity.path,
      );
    }
    if (entity is File) result.add(entity);
  }
  return result;
}

Future<List<RemoteEntry>> _remoteFiles(
  RemoteStore store,
  String root,
  TaskContext? context,
) async {
  final result = <RemoteEntry>[];
  final queue = [root];
  final seen = <String>{};
  while (queue.isNotEmpty) {
    context?.checkCancelled();
    final path = queue.removeLast();
    if (!seen.add(path)) continue;
    for (final entry in await store.list(path)) {
      _validateRelative(entry.path);
      if (!entry.path.startsWith('$root/')) {
        throw const FormatException(
          'Remote listing escaped the selected save folder',
        );
      }
      if (entry.isDirectory) {
        queue.add(entry.path);
      } else {
        result.add(entry);
      }
    }
  }
  return result;
}

(int, int) _countDirectory(String root) {
  var count = 0, size = 0;
  for (final file in Directory(
    root,
  ).listSync(recursive: true, followLinks: false)) {
    if (file is Link) {
      throw FileSystemException(
        'Linked save entries are not supported',
        file.path,
      );
    }
    if (file is File) {
      count++;
      size += file.lengthSync();
    }
  }
  return (count, size);
}

List<CloudSave> _scanLocalSaves(String root) {
  final directory = Directory(root);
  if (!directory.existsSync()) return [];
  final result = <CloudSave>[];
  for (final account
      in directory.listSync(followLinks: false).whereType<Directory>()) {
    if (int.tryParse(p.basename(account.path)) == null) continue;
    for (final app
        in account.listSync(followLinks: false).whereType<Directory>()) {
      final id = int.tryParse(p.basename(app.path));
      if (id == null || id <= 0) continue;
      final count = _countDirectory(app.path);
      final marker = File(p.join(app.path, 'cn.cloudredirect'));
      result.add(
        CloudSave(
          appId: id,
          accountId: p.basename(account.path),
          path: app.path,
          fileCount: count.$1,
          size: count.$2,
          modifiedAt: marker.existsSync()
              ? marker.lastModifiedSync()
              : app.statSync().modified,
        ),
      );
    }
  }
  return result;
}
