// Reimplemented from Fluent-Steam-Lua cloud management (zlib).
import 'dart:async';
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
import '../../ui/localization.dart';
import '../library/process_observer.dart';
import 'remote/folder_store.dart';
import 'cloud_native_sync.dart';
import 'cloud_credentials.dart';
import '../kernel/kernel_config.dart';
import 'cloud_models.dart';
import 'cloud_oauth.dart';
import 'remote/cloud_remote.dart';

export 'cloud_credentials.dart' show CredentialCodec;
export 'cloud_models.dart';

part 'cloud_profile_operations.dart';
part 'cloud_backup_operations.dart';

class CloudService extends ChangeNotifier {
  CloudService({
    required this.paths,
    required this.settings,
    http.Client? client,
    String? configDirectory,
    CredentialCodec? credentialCodec,
    Future<bool> Function(Uri)? openBrowser,
    RemoteStore? remoteStore,
    CloudNativeRunner? nativeRunner,
    Future<List<RunningProcess>> Function()? processReader,
  }) : client = client ?? http.Client(),
       configDirectory =
           configDirectory ??
           p.join(
             Platform.environment['APPDATA'] ?? paths.root,
             'CloudRedirect',
           ),
       _remoteOverride = remoteStore,
       _nativeRunner = nativeRunner ?? runCloudNativeSync,
       _processReader = processReader ?? readRunningProcesses {
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
  final CloudNativeRunner _nativeRunner;
  final Future<List<RunningProcess>> Function() _processReader;
  List<CloudStorageProfile> _profiles = [];
  String _activeStorageId = 'current';
  String? _browsingStorageId;
  bool _mutating = false;
  int _refreshGeneration = 0;
  DateTime? checkedAt;
  final Map<String, CloudSyncResult> syncResults = {};
  final Map<String, String> locationErrors = {};
  final Map<String, List<CloudFileInfo>> fileDetails = {};
  AppLocalizations get _l10n => localizationsFor(settings.language);
  bool get busy => _mutating;
  void _notify() => notifyListeners();

  Future<T> runMutation<T>(Future<T> Function() action) async {
    if (_mutating) throw StateError(_l10n.cloudOperationBusy);
    _mutating = true;
    ++_refreshGeneration;
    loading = false;
    notifyListeners();
    try {
      return await action();
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

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
    config['flsteamlua_changed_at'] = DateTime.now().toUtc().toIso8601String();
    final running = await _processReader();
    config['flsteamlua_changed_pid'] = running
        .where((v) => p.basename(v.executablePath).toLowerCase() == 'steam.exe')
        .firstOrNull
        ?.pid;
    await atomicWrite(
      _configFile,
      utf8.encode(const JsonEncoder.withIndent('  ').convert(config)),
    );
  }

  Future<void> refreshStatus() async {
    final config = await _readConfig();
    final selected = config['provider'] as String? ?? 'folder';
    if (!providers.contains(selected)) {
      throw FormatException(_l10n.cloudUnknownStorage);
    }
    final token =
        (config['token_paths'] as Map?)?[selected] as String? ??
        config['token_path'] as String?;
    final credential = CloudCredentialStore(
      configDirectory,
      credentials.codec,
      overrides: {selected: ?token},
    );
    final configured =
        selected == 'folder' ||
        _remoteOverride != null ||
        await credential.read(selected) != null;
    final plugin = await inspectPlugin();
    final processes = await _processReader();
    final steam = processes
        .where((v) => p.basename(v.executablePath).toLowerCase() == 'steam.exe')
        .firstOrNull;
    final oldPid = config['flsteamlua_changed_pid'];
    final pending =
        config['flsteamlua_changed_at'] != null &&
        (steam == null || oldPid == steam.pid);
    final root = settings.steamPath;
    final dwm =
        File(p.join(root, 'dwmapi.dll')).existsSync() ||
        File(p.join(root, 'bin', 'dwmapi.dll')).existsSync();
    final version = File(p.join(root, 'version.dll')).existsSync();
    status = CloudStatus(
      enabled: plugin.enabled,
      pluginInstalled: plugin.installed,
      configured: configured,
      provider: selected,
      syncPath: config['sync_path'] as String? ?? '',
      syncAchievements: config['sync_achievements'] == true,
      syncPlaytime: config['sync_playtime'] == true,
      pendingRestart: pending,
      coreReady:
          root.isNotEmpty &&
          File(p.join(root, 'OpenSteamTool.dll')).existsSync() &&
          dwm != version,
    );
    await loadProfiles();
    notifyListeners();
  }

  Future<void> _refreshAfterMutation({int? appId}) async {
    try {
      await refresh(appId: appId);
    } catch (_) {
      /* refresh records the listing error without undoing a committed operation */
    }
  }

  Future<void> browseStorage(String id, {int? appId}) async {
    if (_mutating) throw StateError(_l10n.cloudOperationBusy);
    _browsingStorageId = id;
    await refresh(appId: appId);
  }

  Future<void> refresh({
    int? appId,
    TaskContext? context,
    bool includeRemote = true,
  }) async {
    if (!includeRemote) {
      await refreshStatus();
      return;
    }
    final generation = ++_refreshGeneration;
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      await refreshStatus();
      final selected = browsingStorage;
      final storageId = selected.id;
      fileDetails.clear();
      locationErrors.clear();
      final folderRoot = selected.provider == 'folder'
          ? selected.folder
          : syncPath;
      final cacheRoot = settings.steamPath.isEmpty
          ? null
          : p.join(settings.steamPath, 'cloud_redirect', 'storage');
      final local = await Isolate.run(
        () => [
          ..._scanLocalSaves(
            folderRoot,
            CloudSaveLocation.folder,
            appId: appId,
            storageId: storageId,
          ),
          if (cacheRoot != null && !p.equals(cacheRoot, folderRoot))
            ..._scanLocalSaves(
              cacheRoot,
              CloudSaveLocation.cache,
              appId: appId,
              storageId: storageId,
            ),
        ],
      );
      if (generation != _refreshGeneration) return;
      final keep = _saves
          .where(
            (v) =>
                v.storageId == storageId &&
                (v.isRemote || appId != null && v.appId != appId),
          )
          .toList();
      _saves = [...keep, ...local];
      notifyListeners();
      if (selected.provider != 'folder') {
        final remote = await remoteFor(storageId);
        final found = <CloudSave>[];
        for (final account in await remote.list('')) {
          context?.checkCancelled();
          if (!account.isDirectory ||
              int.tryParse(p.posix.basename(account.path)) == null) {
            continue;
          }
          final apps = await remote.list(account.path);
          for (final app in apps) {
            final id = int.tryParse(p.posix.basename(app.path));
            if (!app.isDirectory ||
                id == null ||
                id <= 0 ||
                appId != null && id != appId) {
              continue;
            }
            found.add(
              CloudSave(
                appId: id,
                accountId: p.posix.basename(account.path),
                path: app.path,
                location: CloudSaveLocation.remote,
                storageId: storageId,
                detailsLoaded: false,
                modifiedAt: app.modifiedAt,
                checkedAt: DateTime.now(),
              ),
            );
          }
          if (generation != _refreshGeneration) return;
          _saves = [
            ...keep.where((v) => !found.any((n) => n.id == v.id)),
            ...local,
            ...found,
          ];
          notifyListeners();
        }
        if (generation != _refreshGeneration) return;
        _saves = [
          ...keep.where((v) => appId != null && v.appId != appId),
          ...local,
          ...found,
        ];
      }
      checkedAt = DateTime.now();
    } catch (error) {
      if (generation == _refreshGeneration) lastError = error.toString();
      rethrow;
    } finally {
      if (generation == _refreshGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<List<CloudFileInfo>> inspectSave(
    CloudSave save, {
    TaskContext? context,
  }) async {
    try {
      final files = save.isRemote
          ? (await _remoteFiles(
                  await remoteFor(save.storageId),
                  save.path,
                  context,
                ))
                .map(
                  (v) => CloudFileInfo(
                    p.posix.relative(v.path, from: save.path),
                    v.size,
                    modifiedAt: v.modifiedAt,
                  ),
                )
                .toList()
          : await Isolate.run(
              () => Directory(save.path)
                  .listSync(recursive: true, followLinks: false)
                  .whereType<File>()
                  .map(
                    (v) => CloudFileInfo(
                      p.relative(v.path, from: save.path).replaceAll('\\', '/'),
                      v.lengthSync(),
                      modifiedAt: v.lastModifiedSync(),
                    ),
                  )
                  .toList(),
            );
      fileDetails[save.id] = files;
      locationErrors.remove(save.id);
      final updated = CloudSave(
        appId: save.appId,
        accountId: save.accountId,
        path: save.path,
        location: save.location,
        storageId: save.storageId,
        fileCount: files.length,
        size: files.fold(0, (sum, v) => sum + v.size),
        checkedAt: DateTime.now(),
        modifiedAt: save.modifiedAt,
      );
      _saves = _saves.map((v) => v.id == save.id ? updated : v).toList();
      notifyListeners();
      return files;
    } catch (error) {
      locationErrors[save.id] = '$error';
      notifyListeners();
      rethrow;
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
      await _writeConfig({'sync_path': destination, 'auto_update_dll': false});
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
    await _refreshAfterMutation();
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
      'auto_update_dll': false,
      'token_paths': tokenPaths,
      'flsteamlua_storage_id': 'current',
      if (selected != 'folder') 'token_path': credentials.path(selected),
    });
    await refresh(includeRemote: false);
  }

  Future<Map<String, dynamic>?> providerConfiguration(String selected) =>
      credentials.read(selected);

  Future<void> authorize(String selected, {TaskContext? context}) async {
    await oauth.authorize(selected, context: context);
    await configureProvider(selected, {});
  }

  Future<void> signOut(String selected) async {
    await credentials.signOut(selected);
    if (selected == provider) await disableRedirect();
    await _refreshAfterMutation();
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
      version: await _pluginVersion(file),
    );
  }

  DateTime? _versionStamp;
  String? _versionValue;
  String? _versionPath;
  Future<String?> _pluginVersion(File file) async {
    final stamp = await file.lastModified();
    if (_versionStamp == stamp && _versionPath == file.path) {
      return _versionValue;
    }
    _versionStamp = stamp;
    _versionPath = file.path;
    if (!Platform.isWindows) return null;
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r"(Get-Item -LiteralPath $env:FLSTEAM_CLOUD_DLL).VersionInfo.ProductVersion",
      ],
      environment: {'FLSTEAM_CLOUD_DLL': file.path},
    );
    if (result.exitCode != 0) return null;
    final version = '${result.stdout}'.trim();
    return _versionValue = version.isEmpty ? null : version;
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
    await _refreshAfterMutation();
  }

  Map<String, dynamic> _r2Config(Map<String, dynamic> value) => {
    ...value,
    'endpoint': (value['endpoint'] as String? ?? '').isNotEmpty
        ? value['endpoint']
        : 'https://${value['account_id']}.r2.cloudflarestorage.com',
    'region': 'auto',
  };

  Future<RemoteStore> _remote() async {
    await loadProfiles();
    return remoteFor(activeStorageId);
  }

  Future<void> installPlugin({TaskContext? context}) async {
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
      'auto_update_dll': false,
    });
    await refresh(includeRemote: false);
  }

  Future<void> enableRedirect({TaskContext? context}) async {
    final plugin = await inspectPlugin();
    if (!plugin.installed) {
      throw StateError('Install the CloudRedirect plugin first');
    }
    await _setKernelEnabled(true);
    await refresh(includeRemote: false);
  }

  Future<void> disableRedirect() async {
    await _setKernelEnabled(false);
    await refresh(includeRemote: false);
  }

  Future<(File, String)> _readKernelConfig() async {
    if (settings.steamPath.isEmpty) {
      throw StateError('Steam directory is not configured');
    }
    final file = KernelConfig(settings.steamPath).file;
    return (
      file,
      await file.exists() ? await file.readAsString(encoding: utf8) : '',
    );
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

  Future<void> _setKernelEnabled(bool enabled) async {
    await KernelConfig(
      settings.steamPath,
    ).update('cloud', {'enabled': enabled});
    await _writeConfig({});
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
    final table = KernelConfig.decode(source)[section];
    return table is Map ? table[key]?.toString() : null;
  }

  Future<void> setMetadataSync({
    required bool achievements,
    required bool playtime,
  }) async {
    await _writeConfig({
      'sync_achievements': achievements,
      'sync_playtime': playtime,
    });
    await refresh(includeRemote: false);
  }

  Future<CloudDeletePreview> previewDelete(
    int appId, {
    CloudSave? selection,
    TaskContext? context,
  }) async {
    if (appId <= 0) throw ArgumentError.value(appId, 'appId');
    final targets = <CloudDeleteTarget>[];
    await loadProfiles();
    final profile = storage(selection?.storageId ?? browsingStorageId);
    final folder = profile.provider == 'folder' ? profile.folder : syncPath;
    final roots = <String, String>{'sync': folder};
    if (settings.steamPath.isNotEmpty) {
      roots['cache'] = p.join(settings.steamPath, 'cloud_redirect', 'storage');
      roots['legacy-cache'] = p.join(
        settings.steamPath,
        'cloud_redirect',
        'blobs',
      );
      roots['userdata'] = p.join(settings.steamPath, 'userdata');
    }
    final selectedKind = selection == null
        ? null
        : switch (selection.location) {
            CloudSaveLocation.folder => 'sync',
            CloudSaveLocation.cache => 'cache',
            CloudSaveLocation.remote => 'remote',
          };
    for (final root in roots.entries) {
      if (selectedKind != null && selectedKind != root.key) continue;
      if (!await Directory(root.value).exists()) continue;
      await for (final account in Directory(
        root.value,
      ).list(followLinks: false)) {
        if (account is! Directory ||
            int.tryParse(p.basename(account.path)) == null) {
          continue;
        }
        if (selection != null &&
            p.basename(account.path) != selection.accountId) {
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
    if ((selectedKind == null || selectedKind == 'remote') &&
        profile.provider != 'folder' &&
        (await storageValues(profile.id)).isNotEmpty) {
      final remote = await remoteFor(profile.id);
      for (final account in await remote.list('')) {
        context?.checkCancelled();
        if (!account.isDirectory ||
            int.tryParse(p.posix.basename(account.path)) == null) {
          continue;
        }
        if (selection != null &&
            p.posix.basename(account.path) != selection.accountId) {
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
      provider: profile.provider,
      target: targets.any((v) => v.kind == 'sync' || v.isRemote)
          ? await targetFor(profile.id)
          : null,
      selection: selection,
      targets: targets,
      backupDirectory: p.normalize(
        paths.file(
          'backups/cloud/$appId-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
    );
  }

  Future<CloudBackup> backup(
    int appId, {
    CloudSave? selection,
    TaskContext? context,
  }) async {
    final preview = await previewDelete(
      appId,
      selection: selection,
      context: context,
    );
    return _backupPreview(preview, context);
  }

  Future<CloudBackup> _backupPreview(
    CloudDeletePreview preview,
    TaskContext? context, {
    String reason = 'manual',
  }) async {
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
        final remote = await remoteFor(preview.target!.storageId);
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
          'target': preview.target?.toJson(),
          'reason': reason,
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
      provider: preview.provider,
      target: preview.target,
      reason: reason,
      locations: [
        for (final target in preview.targets)
          CloudBackupLocation(
            kind: target.kind,
            accountId: target.accountId,
            sourcePath: target.path,
          ),
      ],
    );
  }

  Future<CloudBackup> delete(
    CloudDeletePreview preview, {
    TaskContext? context,
  }) async {
    if (preview.target != null) await _assertTarget(preview.target);
    final fresh = await previewDelete(
      preview.appId,
      selection: preview.selection,
      context: context,
    );
    if (!_samePreview(preview, fresh)) {
      throw StateError('Save files changed; request a new delete preview');
    }
    final backup = await _backupPreview(
      preview,
      context,
      reason: 'beforeDelete',
    );
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
            ? await (await remoteFor(preview.target!.storageId)).read(
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
    try {
      for (final target in preview.targets) {
        context?.checkCancelled();
        if (target.isRemote) {
          await _deleteRemoteTree(
            await remoteFor(preview.target!.storageId),
            target.path,
            context,
          );
        } else {
          await Directory(target.path).delete(recursive: true);
        }
      }
    } catch (_) {
      await _applyBackup(manifest, backup, null);
      rethrow;
    }
    await _refreshAfterMutation();
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
          provider: value['provider'] as String,
          target: value['target'] is Map
              ? CloudTarget.fromJson(Map<String, dynamic>.from(value['target']))
              : null,
          note: value['note'] as String? ?? '',
          pinned: value['pinned'] == true,
          reason: value['reason'] as String? ?? 'manual',
          verifiedAt: DateTime.tryParse(value['verified_at'] as String? ?? ''),
          locations: [
            for (final target in value['targets'] as List)
              CloudBackupLocation(
                kind: target['kind'] as String,
                accountId: target['account_id'] as String,
                sourcePath: target['path'] as String,
              ),
          ],
        ),
      );
    }
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  List<({CloudBackupLocation location, String path})> restoreLocations(
    CloudBackup backup,
  ) => [
    for (final location in backup.locations)
      (
        location: location,
        path:
            _localRestorePath(
              location.kind,
              location.accountId,
              backup.appId,
              sourcePath: location.sourcePath,
            ) ??
            p.posix.join(location.accountId, '${backup.appId}'),
      ),
  ];

  String? _localRestorePath(
    String kind,
    String account,
    int appId, {
    String? sourcePath,
  }) {
    return switch (kind) {
      'sync' => sourcePath ?? p.join(syncPath, account, '$appId'),
      'cache' => p.join(
        settings.steamPath,
        'cloud_redirect',
        'storage',
        account,
        '$appId',
      ),
      'legacy-cache' => p.join(
        settings.steamPath,
        'cloud_redirect',
        'blobs',
        account,
        '$appId',
      ),
      'userdata' => p.join(settings.steamPath, 'userdata', account, '$appId'),
      'remote' => null,
      _ => throw const FormatException('Unknown backup target'),
    };
  }

  Future<void> restore(CloudBackup backup, {TaskContext? context}) async {
    final value = await _backupDocument(backup);
    await verifyBackup(backup);
    if (backup.locations.isEmpty) throw StateError(_l10n.cloudNoRestoreTargets);
    if (backup.locations.any((v) => v.kind == 'remote' || v.kind == 'sync')) {
      await _assertTarget(backup.target);
    }
    for (final raw in value['targets'] as List) {
      if (raw['kind'] == 'sync') {
        final profile = storage(backup.target!.storageId);
        final root = profile.provider == 'folder' ? profile.folder : syncPath;
        if (!p.equals(
          raw['path'] as String,
          p.join(root, raw['account_id'] as String, '${backup.appId}'),
        )) {
          throw StateError(_l10n.cloudBackupTargetChanged);
        }
      }
    }
    final before = await _snapshotTargets(
      backup.appId,
      backup.locations,
      backup.target,
      'beforeRestore',
      context,
    );
    await _applyBackup(value, backup, context, rollback: before);
    await _refreshAfterMutation();
  }

  Future<void> _applyBackup(
    Map<String, dynamic> value,
    CloudBackup backup,
    TaskContext? context, {
    CloudBackup? rollback,
  }) async {
    final staged = <(Directory, Directory, Directory?)>[];
    final promoted = <(Directory, Directory?)>[];
    final remoteTargets = <String>[];
    try {
      for (final raw in value['targets'] as List) {
        final target = raw as Map;
        final account = target['account_id'] as String;
        final kind = target['kind'] as String;
        final local = _localRestorePath(
          kind,
          account,
          backup.appId,
          sourcePath: target['path'] as String,
        );
        if (local != null && kind != 'sync' && settings.steamPath.isEmpty) {
          throw StateError(_l10n.cloudFolderAbsolute);
        }
        final stage = local == null
            ? null
            : Directory(
                '$local.restore-${DateTime.now().microsecondsSinceEpoch}',
              );
        final destination = local == null ? null : Directory(local);
        if (stage != null) {
          await stage.create(recursive: true);
          final previous = await destination!.exists()
              ? Directory(
                  '$local.before-restore-${DateTime.now().microsecondsSinceEpoch}',
                )
              : null;
          staged.add((stage, destination, previous));
        } else {
          remoteTargets.add('$account/${backup.appId}');
        }
        for (final rawFile in target['files'] as List) {
          context?.checkCancelled();
          final file = rawFile as Map;
          final relative = file['path'] as String;
          final bytes = await File(
            p.join(
              backup.path,
              '${target['index']}',
              p.fromUri(Uri(path: relative)),
            ),
          ).readAsBytes();
          if (stage != null) {
            await atomicWrite(
              File(p.join(stage.path, p.fromUri(Uri(path: relative)))),
              bytes,
            );
          } else {
            await (await remoteFor(
              backup.target!.storageId,
            )).write('$account/${backup.appId}/$relative', bytes);
          }
        }
        if (stage == null) {
          final remote = await remoteFor(backup.target!.storageId);
          final expected = {
            for (final f in target['files'] as List)
              '$account/${backup.appId}/${f['path']}',
          };
          for (final extra in await _remoteFiles(
            remote,
            '$account/${backup.appId}',
            context,
          )) {
            if (!expected.contains(extra.path)) await remote.delete(extra.path);
          }
        }
      }
      for (final (stage, destination, previous) in staged) {
        context?.checkCancelled();
        if (previous != null) await destination.rename(previous.path);
        try {
          await stage.rename(destination.path);
        } catch (_) {
          if (previous != null) await previous.rename(destination.path);
          rethrow;
        }
        promoted.add((destination, previous));
      }
    } catch (_) {
      for (final (destination, previous) in promoted.reversed) {
        await destination.delete(recursive: true);
        if (previous != null) await previous.rename(destination.path);
      }
      if (remoteTargets.isNotEmpty) {
        final remote = await remoteFor(backup.target!.storageId);
        for (final target in remoteTargets) {
          await _deleteRemoteTree(remote, target, null);
        }
        if (rollback != null) {
          final data = await _backupDocument(rollback);
          final remoteData = {
            ...data,
            'targets': (data['targets'] as List)
                .where((v) => v['kind'] == 'remote')
                .toList(),
          };
          await _applyBackup(remoteData, rollback, null);
        }
      }
      rethrow;
    } finally {
      for (final (stage, _, _) in staged) {
        if (await stage.exists()) await stage.delete(recursive: true);
      }
    }
    for (final (_, previous) in promoted) {
      if (previous != null && await previous.exists()) {
        await previous.delete(recursive: true);
      }
    }
  }

  Future<void> download(
    CloudSave save,
    String destination, {
    TaskContext? context,
  }) async {
    final target = Directory(destination);
    if (await target.exists() && !await target.list().isEmpty) {
      throw StateError(_l10n.cloudExportNotEmpty);
    }
    final stage = Directory(
      '$destination.export-${DateTime.now().microsecondsSinceEpoch}',
    );
    await stage.create(recursive: true);
    try {
      if (save.isRemote) {
        final remote = await remoteFor(save.storageId);
        for (final file in await _remoteFiles(remote, save.path, context)) {
          context?.checkCancelled();
          final relative = p.posix.relative(file.path, from: save.path);
          _validateRelative(relative);
          await atomicWrite(
            File(p.join(stage.path, p.fromUri(Uri(path: relative)))),
            await remote.read(file.path),
          );
        }
      } else {
        for (final file in await _localFiles(save.path)) {
          context?.checkCancelled();
          await atomicWrite(
            File(p.join(stage.path, p.relative(file.path, from: save.path))),
            await file.readAsBytes(),
          );
        }
      }
      if (await target.exists()) {
        if (!await target.list().isEmpty) {
          throw StateError(_l10n.cloudExportNotEmpty);
        }
        await target.delete();
      }
      await stage.rename(destination);
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
  }

  Future<void> upload(CloudSave save, {TaskContext? context}) async {
    if (save.location != CloudSaveLocation.folder) {
      throw ArgumentError('Only a folder repository can be copied directly');
    }
    final target = await targetFor(activeStorageId);
    if (target.provider == 'folder') {
      throw ArgumentError('Select a remote sync target');
    }
    final path = '${save.accountId}/${save.appId}';
    final before = await _snapshotTargets(
      save.appId,
      [
        CloudBackupLocation(
          kind: 'remote',
          accountId: save.accountId,
          sourcePath: path,
        ),
      ],
      target,
      'beforeUpload',
      context,
    );
    final remote = await remoteFor(target.storageId);
    try {
      for (final file in await _localFiles(save.path)) {
        context?.checkCancelled();
        final relative = p
            .relative(file.path, from: save.path)
            .replaceAll('\\', '/');
        await remote.write('$path/$relative', await file.readAsBytes());
      }
    } catch (_) {
      await _deleteRemoteTree(remote, path, null);
      if (before != null) {
        await _applyBackup(await _backupDocument(before), before, null);
      }
      rethrow;
    }
    await _refreshAfterMutation();
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

List<CloudSave> _scanLocalSaves(
  String root,
  CloudSaveLocation location, {
  int? appId,
  String storageId = 'current',
}) {
  final directory = Directory(root);
  if (!directory.existsSync()) return [];
  final result = <CloudSave>[];
  for (final account
      in directory.listSync(followLinks: false).whereType<Directory>()) {
    if (int.tryParse(p.basename(account.path)) == null) continue;
    for (final app
        in account.listSync(followLinks: false).whereType<Directory>()) {
      final id = int.tryParse(p.basename(app.path));
      if (id == null || id <= 0 || appId != null && id != appId) continue;
      final marker = File(p.join(app.path, 'cn.cloudredirect'));
      result.add(
        CloudSave(
          appId: id,
          location: location,
          accountId: p.basename(account.path),
          path: app.path,
          storageId: storageId,
          detailsLoaded: false,
          checkedAt: DateTime.now(),
          modifiedAt: marker.existsSync()
              ? marker.lastModifiedSync()
              : app.statSync().modified,
        ),
      );
    }
  }
  return result;
}

Future<void> _deleteRemoteTree(
  RemoteStore store,
  String path,
  TaskContext? context,
) async {
  // S3 DELETE removes one key, not a prefix. Enumerate every object first.
  for (final file in await _remoteFiles(store, path, context)) {
    context?.checkCancelled();
    await store.delete(file.path);
  }
  await store.delete(path);
}
