// Dart adaptation of Fluent-Steam-Lua kernel management (zlib).
// Copyright (c) 2024 SteamLuaManager. See assets/licenses/Fluent-Steam-Lua-zlib.txt.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../content_sources/content_models.dart';
import '../network/network_preferences.dart';
import 'kernel_models.dart';
import 'kernel_config.dart';
import 'local_toml_builder.dart';

export 'kernel_models.dart';

typedef KernelFileWriter = Future<void> Function(File file, List<int> bytes);

typedef ManifestCodeSourceProvider = List<ContentSourceDefinition> Function();

typedef ManifestRequestCodeResolver =
    Future<String?> Function({
      required String sourceId,
      required int appId,
      required int depotId,
      required String gid,
    });

typedef LocalTomlBuilderRunner =
    Future<LocalTomlBuildReport> Function({
      required String steamPath,
      void Function(LocalTomlBuildEvent event)? onEvent,
    });

const kernelManifestProxyBase = 'http://127.0.0.1:47831/manifest';

const _manifestLuaSource = r'''-- Managed by FlSteamLua.
function fetch_manifest_code_ex(app_id, depot_id, gid)
  local gid_text = string.format("%u", gid)
  local url = "http://127.0.0.1:47831/manifest/"
    .. tostring(app_id) .. "/"
    .. tostring(depot_id) .. "/"
    .. gid_text
  local body, status = http_get(url)
  if status == 200 and body then
    local code = string.match(body, "^%s*(%d+)%s*$")
    if code then
      return code
    end
  end
  return nil
end
''';

const kernelManifestProviders = <String, String>{
  '20770407': '20770407',
  'opensteamtool': 'OpenSteamTool',
  'steamrun': 'SteamRun',
  'wudrm': 'Wudrm',
  'SDM': 'SDM (993499094)',
  'manifestdex': 'ManifestDeX',
};

const _installNames = {
  'opensteamtool.dll': 'OpenSteamTool.dll',
  'xinput1_4.dll': 'xinput1_4.dll',
  'dwmapi.dll': 'dwmapi.dll',
  'version.dll': 'version.dll',
  'dwmapi.dll.disabled': 'dwmapi.dll.disabled',
  'version.dll.disabled': 'version.dll.disabled',
};

const _baseNames = [
  'OpenSteamTool.dll',
  'xinput1_4.dll',
  'dwmapi.dll',
  'version.dll',
  'bin/dwmapi.dll',
  'bin/version.dll',
];
const _tomlTargets = [
  ('pattern', 'steamclient'),
  ('pattern', 'steamui'),
  ('ipc', 'steamclient'),
];
const _foreignKernelFiles = {
  'hid.dll': 'SteamTools',
  'zlib1.dll': 'SteamTools',
  'user32.dll': 'TB/BIAO',
  'midimap.dll': 'TB/BIAO',
  'winmm.dll': 'TB/BIAO',
  'CaigamerQ.dll': 'TB/BIAO',
  'bin/winmm.dll': 'TB/BIAO',
};
const _dwmapiEntryNames = ['bin/dwmapi.dll', 'dwmapi.dll'];
const _versionEntryNames = ['version.dll', 'bin/version.dll'];
const _suffixes = ['', '.disabled', '.off'];
const _maxPackageBytes = 200 * 1024 * 1024;
const _maxUncompressedBytes = 512 * 1024 * 1024;
const _legacyVersionHashes = {
  '115ec256c7c5b066926015a24120cf6e7d9e5a7a5b87441817c2de11cc3f9fec': 'v1.2.0',
  '494bc762351b4dc80ca2f36cc005fc89b976f24e6e77c12945229e3e05502e93': 'v1.3.0',
  '8d4cb44bc57565e8183b9dab72eda873305c4257e080e29d57bbfda4cc755585': 'v1.3.1',
  '6daeef8b0a085c22ca43a6efeceee1f8547c3044573c394ec7cd4945fba13430': 'v1.3.2',
  'a1c4ffc819d96d9c397d132cb718aa7d7d44651375845e4bb9258499e643857d': 'v1.4.0',
  '550f9edfede4a4403f7aefdd5c4a40fdd92be22135443857fd997b415d7ced1e': 'v1.4.1',
  '962f5c7700a0ddde46cd419763ed15f95baf5a4a93525559f7bb6453aa1b1aac': 'v1.4.2',
  'd578da0170d18cd8f7cdee36a617a80147bddc8945701e3d5d1f11315d7e36fd': 'v1.4.3',
  '9113dce46b7a807e30abc018ee8469f188c51e2d277279c2f15427efc2f52226': 'v1.4.4',
  '5ec8351d5949c10c97210759efb5d618741d8414d67ff650e328d036e352c10c': 'v1.4.5',
  'cd7266e06d7416d3b02335386c54b909df68e2e0605941f70bb21ed392ee639f': 'v1.4.6',
  '9a2c459ad5124eeb48e4a1c7ac9808e5fad6eda54f7df8ad4b2e4465818f50f7':
      'v1.4.6-fix',
  '09d26118c7cf796cf37562c4cb965d1b213f5866c02ca04fe0fafc4c2f22b0bc': 'v1.4.7',
};

String _normalizeRepository(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    throw const FormatException('Kernel repository is empty');
  }
  final segments = text.startsWith('http://') || text.startsWith('https://')
      ? () {
          final uri = Uri.parse(text);
          if (uri.host.toLowerCase() != 'github.com') {
            throw const FormatException(
              'Kernel repository must use github.com',
            );
          }
          return uri.pathSegments;
        }()
      : text.split('/');
  final parts = segments
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (parts.length != 2) {
    throw const FormatException('Kernel repository must be owner/repository');
  }
  final owner = parts[0];
  final repository = parts[1].replaceFirst(
    RegExp(r'\.git$', caseSensitive: false),
    '',
  );
  final valid = RegExp(r'^[A-Za-z0-9_.-]+$');
  if (!valid.hasMatch(owner) || !valid.hasMatch(repository)) {
    throw const FormatException('Invalid kernel repository');
  }
  return '$owner/$repository';
}

Future<void> _writeFile(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<bool> _steamRunning() async {
  if (!Platform.isWindows) return false;
  final result = await Process.run('tasklist', [
    '/FI',
    'IMAGENAME eq steam.exe',
    '/FO',
    'CSV',
    '/NH',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'tasklist',
      const [],
      '${result.stderr}',
      result.exitCode,
    );
  }
  return '${result.stdout}'.toLowerCase().contains('"steam.exe"');
}

Future<Map<String, List<int>>> _decodePackageAsync(List<int> bytes) =>
    Isolate.run(() => _decodePackage(bytes));

Map<String, List<int>> _decodePackage(List<int> bytes) {
  if (bytes.length > _maxPackageBytes) {
    throw const FormatException('Kernel ZIP exceeds 200 MB');
  }
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final result = <String, List<int>>{};
  var total = 0;
  for (final entry in archive.files) {
    final normalized = entry.name.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (normalized.startsWith('/') ||
        normalized.contains(':') ||
        segments.contains('..') ||
        entry.isSymbolicLink) {
      throw FormatException('Unsafe kernel ZIP entry: ${entry.name}');
    }
    if (!entry.isFile) continue;
    total += entry.size;
    if (total > _maxUncompressedBytes) {
      throw const FormatException('Uncompressed kernel ZIP exceeds 512 MB');
    }
    final name = _installNames[segments.last.toLowerCase()];
    if (name == null) continue;
    if (result.containsKey(name)) {
      throw FormatException('Duplicate kernel DLL in ZIP: $name');
    }
    final contents = entry.content;
    if (contents.isEmpty) throw FormatException('Empty kernel DLL: $name');
    result[name] = contents;
  }
  if (result.isEmpty) {
    throw const FormatException('ZIP contains no supported kernel DLLs');
  }
  return result;
}

class KernelService extends ChangeNotifier {
  KernelService({
    required this.paths,
    required this.settings,
    http.Client? client,
    Future<bool> Function()? isSteamRunning,
    KernelFileWriter? fileWriter,
    ManifestCodeSourceProvider? manifestCodeSources,
    ManifestRequestCodeResolver? resolveManifestRequestCode,
    LocalTomlBuilderRunner? localTomlBuilderRunner,
  }) : _client = client ?? NetworkHttpClient(settings: settings),
       _ownsClient = client == null,
       _isSteamRunning = isSteamRunning ?? _steamRunning,
       _fileWriter = fileWriter ?? _writeFile,
       _manifestCodeSources = manifestCodeSources ?? _noManifestCodeSources,
       _resolveManifestRequestCode =
           resolveManifestRequestCode ?? _noManifestRequestCode,
       _localTomlBuilderRunner = localTomlBuilderRunner ?? buildLocalSteamTomls;

  final AppPaths paths;
  final SettingsStore settings;
  final http.Client _client;
  final bool _ownsClient;
  final Future<bool> Function() _isSteamRunning;
  final KernelFileWriter _fileWriter;
  final ManifestCodeSourceProvider _manifestCodeSources;
  final ManifestRequestCodeResolver _resolveManifestRequestCode;
  final LocalTomlBuilderRunner _localTomlBuilderRunner;
  final List<KernelPackage> _packages = [];
  final List<String> _warnings = [];
  List<KernelBackup> _backups = [];
  KernelInstallation _installed = const KernelInstallation();
  KernelUpdateInfo? _updateInfo;
  Map<String, KernelResidualItem> _lastResidualItems = {};
  String? _lastResidualRoot;
  String? _activePackageId;
  KernelRepositoryInfo? _repositoryInfo;
  HttpServer? _manifestProxyServer;
  bool _mutating = false;

  static List<ContentSourceDefinition> _noManifestCodeSources() => const [];

  static Future<String?> _noManifestRequestCode({
    required String sourceId,
    required int appId,
    required int depotId,
    required String gid,
  }) async => null;

  List<KernelPackage> get packages => List.unmodifiable(_packages);
  List<String> get warnings => List.unmodifiable(_warnings);
  List<KernelBackup> get backups => List.unmodifiable(_backups);
  KernelInstallation get installed => _installed;
  KernelUpdateInfo? get updateInfo => _updateInfo;
  String? get activePackageId => _activePackageId;
  KernelRepositoryInfo? get repositoryInfo => _repositoryInfo;
  List<ContentSourceDefinition> get manifestCodeSources =>
      _manifestCodeSources();
  KernelSourceMode get sourceMode {
    final value = settings.get<String>(
      'kernelSourceMode',
      KernelSourceMode.repository.name,
    );
    return KernelSourceMode.values
            .where((mode) => mode.name == value)
            .firstOrNull ??
        KernelSourceMode.repository;
  }

  String get repositorySlug {
    final value = settings.get<String>(
      'kernelRepository',
      'huanyuejue/OpenSteamTool',
    );
    return _normalizeRepository(value);
  }

  List<KernelPackage> get visiblePackages =>
      sourceMode == KernelSourceMode.local
      ? _packages
            .where((package) => package.source == KernelSource.local)
            .toList()
      : _packages;

  Future<void> setSourceMode(KernelSourceMode mode) async {
    await settings.set('kernelSourceMode', mode.name);
    _updateInfo = null;
    notifyListeners();
  }

  Future<void> setRepository(String value) async {
    await settings.set('kernelRepository', _normalizeRepository(value));
    _repositoryInfo = null;
    _updateInfo = null;
    notifyListeners();
  }

  String get repositoryRoot => paths.file('kernel-packages');
  String get _packagesDir => p.join(repositoryRoot, 'packages');
  String get _backupDir => p.join(repositoryRoot, 'backup');
  File get _stateFile => File(p.join(repositoryRoot, 'state.json'));
  bool isCached(KernelPackage package) =>
      File(_zipPath(package.id)).existsSync();

  String _key(String id) =>
      sha256.convert(utf8.encode(id)).toString().substring(0, 24);
  String _zipPath(String id) => p.join(_packagesDir, '${_key(id)}.zip');
  String _metaPath(String id) => p.join(_packagesDir, '${_key(id)}.json');

  String _residualId(String fullPath) => sha256
      .convert(utf8.encode(p.normalize(fullPath).toLowerCase()))
      .toString()
      .substring(0, 16);

  bool _isUnderRoot(String path, String root) {
    final full = p.normalize(p.absolute(path));
    final base = p.normalize(p.absolute(root));
    final comparableFull = Platform.isWindows ? full.toLowerCase() : full;
    final comparableBase = Platform.isWindows ? base.toLowerCase() : base;
    return comparableFull.startsWith('$comparableBase${p.separator}');
  }

  Future<(int, int)> _measureResidual(
    String path, {
    required bool directory,
  }) async {
    if (!directory) {
      final file = File(path);
      return (await file.length(), 1);
    }
    var bytes = 0;
    var files = 0;
    try {
      await for (final entity in Directory(
        path,
      ).list(recursive: true, followLinks: false)) {
        if (entity is File) {
          files++;
          try {
            bytes += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {
      return (bytes, files);
    }
    return (bytes, files);
  }

  Future<void> _rejectDirectoryLinks(String path) async {
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'Residual directory contains a link',
          entity.path,
        );
      }
    }
  }

  Future<void> _copyResidualDirectory(String source, String target) async {
    await Directory(target).create(recursive: true);
    await for (final entity in Directory(source).list(followLinks: false)) {
      final name = p.basename(entity.path);
      final destination = p.join(target, name);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      switch (type) {
        case FileSystemEntityType.file:
          await File(entity.path).copy(destination);
        case FileSystemEntityType.directory:
          await _copyResidualDirectory(entity.path, destination);
        case FileSystemEntityType.link:
          throw FileSystemException(
            'Residual directory contains a link',
            entity.path,
          );
        default:
          break;
      }
    }
  }

  Future<void> loadLocal() async {
    await Directory(_packagesDir).create(recursive: true);
    await Directory(_backupDir).create(recursive: true);
    _warnings.clear();
    _packages.clear();
    await for (final entity in Directory(_packagesDir).list()) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      try {
        final json =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final id = json['id'] as String;
        if (entity.path != _metaPath(id)) {
          throw const FormatException(
            'Metadata filename does not match package ID',
          );
        }
        _packages.add(
          KernelPackage.fromJson(
            json,
            zipPath: await File(_zipPath(id)).exists() ? _zipPath(id) : null,
          ),
        );
      } catch (error) {
        _warnings.add('${p.basename(entity.path)}: $error');
      }
    }
    _activePackageId = null;
    if (await _stateFile.exists()) {
      try {
        final state =
            jsonDecode(await _stateFile.readAsString()) as Map<String, dynamic>;
        _activePackageId = state['activeId'] as String?;
      } catch (error) {
        _warnings.add('state.json: $error');
      }
    }
    _backups = await _readBackups();
    await _detectInstalled();
    _sortPackages();
    notifyListeners();
  }

  Future<List<KernelPackage>> refresh({TaskContext? context}) async {
    await loadLocal();
    if (sourceMode == KernelSourceMode.local) {
      _repositoryInfo = null;
      notifyListeners();
      return visiblePackages;
    }
    context?.checkCancelled();
    final slug = repositorySlug;
    context?.report('Fetching kernel repository $slug');
    try {
      final repositoryResponse = await _client
          .get(Uri.https('api.github.com', '/repos/$slug'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (repositoryResponse.statusCode != 200) {
        throw HttpException(
          'GitHub repository HTTP ${repositoryResponse.statusCode}',
        );
      }
      final repository = jsonDecode(repositoryResponse.body);
      if (repository is! Map<String, dynamic>) {
        throw const FormatException('Invalid repository metadata');
      }
      _repositoryInfo = KernelRepositoryInfo(
        slug: slug,
        fork: repository['fork'] == true,
        defaultBranch: repository['default_branch'] as String? ?? 'main',
        archived: repository['archived'] == true,
        parent: (repository['parent'] as Map?)?['full_name'] as String?,
        pushedAt: DateTime.tryParse(repository['pushed_at'] as String? ?? ''),
      );
      final uri = Uri.https('api.github.com', '/repos/$slug/releases', {
        'per_page': '30',
      });
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException(
          'GitHub releases HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final releases = jsonDecode(response.body);
      if (releases is! List) {
        throw const FormatException('Invalid release list');
      }
      _packages.removeWhere(
        (package) =>
            package.source == KernelSource.official &&
            package.repository != null &&
            package.repository != slug,
      );
      for (final item in releases) {
        context?.checkCancelled();
        if (item is! Map<String, dynamic> || item['draft'] == true) continue;
        final id = item['tag_name'];
        if (id is! String ||
            id.isEmpty ||
            _packages.any((package) => package.id == id)) {
          continue;
        }
        final assets = item['assets'];
        if (assets is! List) continue;
        Map<String, dynamic>? zip;
        for (final asset in assets) {
          if (asset is! Map<String, dynamic>) continue;
          final name = asset['name'];
          if (name is String &&
              name.contains('-Release') &&
              name.toLowerCase().endsWith('.zip')) {
            zip = asset;
            break;
          }
        }
        if (zip == null) {
          for (final asset in assets) {
            if (asset is! Map<String, dynamic>) continue;
            final name = asset['name'];
            if (name is String &&
                name.toLowerCase().endsWith('.zip') &&
                asset['browser_download_url'] is String) {
              zip = asset;
              break;
            }
          }
        }
        if (zip == null || zip['browser_download_url'] is! String) continue;
        final digest = zip['digest'];
        _packages.add(
          KernelPackage(
            id: id,
            version: id,
            displayName: id,
            source: KernelSource.official,
            repository: slug,
            releaseNotes: item['body'] as String? ?? '',
            downloadUrl: zip['browser_download_url'] as String,
            releaseUrl: item['html_url'] as String?,
            sizeBytes: (zip['size'] as num?)?.toInt() ?? 0,
            publishedAt: DateTime.tryParse(
              item['published_at'] as String? ?? '',
            ),
            sha256Digest: digest is String && digest.startsWith('sha256:')
                ? digest.substring(7)
                : null,
          ),
        );
      }
      _sortPackages();
    } on TaskCancelled {
      rethrow;
    } catch (error) {
      _warnings.add('Repository releases unavailable: $error');
    }
    notifyListeners();
    return packages;
  }

  Future<KernelUpdateInfo?> checkForUpdate({TaskContext? context}) async {
    if (sourceMode == KernelSourceMode.local) {
      _updateInfo = null;
      notifyListeners();
      return null;
    }
    await refresh(context: context);
    final warning = _warnings
        .where(
          (warning) => warning.startsWith('Repository releases unavailable:'),
        )
        .firstOrNull;
    if (warning != null) {
      throw StateError(warning);
    }
    final remote = _packages
        .where((package) => package.source == KernelSource.official)
        .firstOrNull;
    if (remote == null) {
      _updateInfo = null;
      notifyListeners();
      return null;
    }
    final local = _installed.version;
    final info = KernelUpdateInfo(
      localVersion: local,
      package: remote,
      hasUpdate: local == null || _isVersionOlder(local, remote.version),
    );
    _updateInfo = info;
    notifyListeners();
    return info;
  }

  static const _headers = {
    'User-Agent': 'FlSteamLua',
    'Accept': 'application/vnd.github+json',
  };

  Future<KernelPackage> importLocal(
    String zipPath, {
    TaskContext? context,
  }) async {
    context?.checkCancelled();
    final file = File(zipPath);
    if (await file.length() > _maxPackageBytes) {
      throw const FormatException('Kernel ZIP exceeds 200 MB');
    }
    final bytes = await file.readAsBytes();
    final entries = await _decodePackageAsync(bytes);
    context?.checkCancelled();
    final digest = sha256.convert(bytes).toString();
    final id = 'local-${digest.substring(0, 10)}';
    await Directory(_packagesDir).create(recursive: true);
    await _atomicBytes(File(_zipPath(id)), bytes);
    final package = KernelPackage(
      id: id,
      version: p.basenameWithoutExtension(zipPath),
      displayName: p.basenameWithoutExtension(zipPath),
      source: KernelSource.local,
      zipPath: _zipPath(id),
      sizeBytes: bytes.length,
      importedAt: DateTime.now(),
      sha256Digest: digest,
    );
    await _writeMeta(package);
    _replacePackage(package);
    final entryNames = entries.keys.map(_managedPath).toSet();
    if (!entryNames.contains('dwmapi.dll') &&
        !entryNames.contains(p.join('bin', 'dwmapi.dll')) &&
        !entryNames.contains('version.dll') &&
        !entryNames.contains('dwmapi.dll.disabled') &&
        !entryNames.contains('version.dll.disabled')) {
      _warnings.add(
        'Imported package has no injection entry; switching requires an existing compatible entry.',
      );
    }
    notifyListeners();
    return package;
  }

  Future<KernelPackage> download(
    KernelPackage package, {
    TaskContext? context,
  }) async {
    if (isCached(package)) {
      return package.copyWith(zipPath: _zipPath(package.id));
    }
    final uri = Uri.tryParse(package.downloadUrl ?? '');
    final expectedRepository = package.repository ?? repositorySlug;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        !uri.path.startsWith('/$expectedRepository/releases/download/')) {
      throw const FormatException(
        'Kernel download must be from the subscribed repository releases',
      );
    }
    context?.checkCancelled();
    context?.report('Downloading ${package.version}', 0);
    final response = await _client
        .send(http.Request('GET', uri)..headers.addAll(_headers))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException(
        'Kernel download HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    if ((response.contentLength ?? 0) > _maxPackageBytes) {
      throw const FormatException('Kernel ZIP exceeds 200 MB');
    }
    final bytes = <int>[];
    final expectedBytes =
        response.contentLength ??
        (package.sizeBytes > 0 ? package.sizeBytes : null);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 60),
    )) {
      context?.checkCancelled();
      bytes.addAll(chunk);
      if (bytes.length > _maxPackageBytes) {
        throw const FormatException('Kernel ZIP exceeds 200 MB');
      }
      context?.report(
        'Downloading ${package.version}',
        expectedBytes == null || expectedBytes == 0
            ? null
            : bytes.length / expectedBytes,
      );
    }
    await _decodePackageAsync(bytes);
    final digest = sha256.convert(bytes).toString();
    if (package.sha256Digest != null && package.sha256Digest != digest) {
      throw const FormatException('Kernel release SHA256 does not match');
    }
    context?.checkCancelled();
    await Directory(_packagesDir).create(recursive: true);
    await _atomicBytes(File(_zipPath(package.id)), bytes);
    final cached = package.copyWith(
      zipPath: _zipPath(package.id),
      sizeBytes: bytes.length,
      importedAt: DateTime.now(),
      sha256Digest: digest,
    );
    await _writeMeta(cached);
    _replacePackage(cached);
    notifyListeners();
    return cached;
  }

  Future<KernelSwitchResult> switchTo(
    KernelPackage package, {
    TaskContext? context,
  }) async {
    return _exclusive(() async {
      final steam = await _requireStoppedSteam();
      if (!isCached(package)) {
        package = await download(package, context: context);
      }
      context?.checkCancelled();
      final zip = File(_zipPath(package.id));
      final bytes = await zip.readAsBytes();
      if (package.sha256Digest != null &&
          sha256.convert(bytes).toString() != package.sha256Digest) {
        throw const FormatException('Cached kernel package checksum changed');
      }
      final entries = await _decodePackageAsync(bytes);
      final priorMode = _currentInjectionMode(steam);
      await _ensureSteamSignatures(steam, context: context);
      final backup = await _createBackup(
        steam,
        'Switch to ${package.displayName}',
        includeForeignKernels: true,
      );
      try {
        context?.report('Installing ${package.displayName}');
        for (final name in await _existingManaged(steam)) {
          context?.checkCancelled();
          await File(p.join(steam, name)).delete();
        }
        await _removeForeignKernelFiles(steam, context: context);
        for (final entry in entries.entries) {
          context?.checkCancelled();
          await _fileWriter(File(p.join(steam, entry.key)), entry.value);
        }
        await _normalizeEntry(steam, priorMode);
        await _writeState(package.id);
        await _detectInstalled();
        _backups = await _readBackups();
        notifyListeners();
        return KernelSwitchResult(
          success: true,
          message: 'Kernel switched to ${package.displayName}',
          backupId: backup.id,
        );
      } catch (error) {
        var restored = false;
        Object? restoreError;
        try {
          await _applyBackup(steam, backup);
          restored = true;
        } catch (error) {
          restoreError = error;
        }
        await _detectInstalled();
        _backups = await _readBackups();
        notifyListeners();
        if (error is TaskCancelled && restored) rethrow;
        return KernelSwitchResult(
          success: false,
          backupId: backup.id,
          rollbackSucceeded: restored,
          message: restored
              ? 'Switch failed; previous files restored: $error'
              : 'Switch failed: $error. Restore failed: $restoreError. Backup: ${backup.id}',
        );
      }
    });
  }

  Future<void> deletePackage(KernelPackage package) async {
    if (_activePackageId == package.id) {
      throw StateError('The active kernel package cannot be deleted');
    }
    for (final path in [_zipPath(package.id), _metaPath(package.id)]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _packages.removeWhere((item) => item.id == package.id);
    notifyListeners();
  }

  Future<KernelSwitchResult> restore(
    String backupId, {
    TaskContext? context,
  }) async {
    return _exclusive(() async {
      final steam = await _requireStoppedSteam();
      final backup = (await _readBackups())
          .where((item) => item.id == backupId)
          .firstOrNull;
      if (backup == null) {
        throw ArgumentError.value(backupId, 'backupId', 'Unknown backup');
      }
      final current = await _createBackup(steam, 'Before restoring $backupId');
      try {
        context?.checkCancelled();
        await _applyBackup(steam, backup);
        await _detectInstalled();
        _backups = await _readBackups();
        notifyListeners();
        return KernelSwitchResult(
          success: true,
          message: 'Kernel backup restored',
          backupId: current.id,
        );
      } catch (error) {
        await _applyBackup(steam, current);
        await _detectInstalled();
        _backups = await _readBackups();
        notifyListeners();
        rethrow;
      }
    });
  }

  Future<List<String>> previewUninstall() async {
    final steam = settings.steamPath;
    if (steam.isEmpty) return [];
    return _existingManaged(steam);
  }

  Future<String> uninstall() async => _exclusive(() async {
    final steam = await _requireStoppedSteam();
    final files = await _existingManaged(steam);
    if (files.isEmpty) throw StateError('No installed kernel files');
    final backup = await _createBackup(steam, 'Uninstall kernel');
    try {
      for (final name in files) {
        await File(p.join(steam, name)).delete();
      }
      await _writeState(null);
    } catch (_) {
      await _applyBackup(steam, backup);
      rethrow;
    }
    await _detectInstalled();
    _backups = await _readBackups();
    notifyListeners();
    return backup.id;
  });

  Future<int> setEnabled(bool enabled) async => _exclusive(() async {
    final steam = await _requireStoppedSteam();
    final mode = _currentInjectionMode(steam);
    final entryNames = mode == InjectionMode.version
        ? _versionEntryNames
        : _dwmapiEntryNames;
    final backup = await _createBackup(
      steam,
      enabled ? 'Enable kernel' : 'Disable kernel',
    );
    var changed = 0;
    try {
      final targets = enabled
          ? ['OpenSteamTool.dll', 'xinput1_4.dll', ...entryNames]
          : [
              'OpenSteamTool.dll',
              'xinput1_4.dll',
              for (final name in entryNames)
                if (File(p.join(steam, _managedPath(name))).existsSync()) name,
            ];
      for (final name in targets) {
        final path = _managedPath(name);
        final from = File(p.join(steam, '$path${enabled ? '.off' : ''}'));
        final to = File(p.join(steam, '$path${enabled ? '' : '.off'}'));
        if (!await from.exists()) continue;
        if (await to.exists()) {
          throw StateError(
            'Both ${p.basename(from.path)} and ${p.basename(to.path)} exist',
          );
        }
        await from.rename(to.path);
        changed++;
      }
      if (changed == 0) {
        throw StateError(
          enabled ? 'No disabled kernel files' : 'No enabled kernel files',
        );
      }
      if (enabled) await _normalizeEntry(steam, mode);
    } catch (_) {
      await _applyBackup(steam, backup);
      rethrow;
    }
    await _detectInstalled();
    _backups = await _readBackups();
    notifyListeners();
    return changed;
  });

  Future<void> setInjectionMode(InjectionMode mode) async =>
      _exclusive(() async {
        final steam = await _requireStoppedSteam();
        if (!_installed.installed ||
            !File(p.join(steam, 'OpenSteamTool.dll')).existsSync()) {
          throw StateError('Enable the kernel before changing injection entry');
        }
        final backup = await _createBackup(steam, 'Change injection entry');
        try {
          await _normalizeEntry(steam, mode);
        } catch (_) {
          await _applyBackup(steam, backup);
          rethrow;
        }
        await _detectInstalled();
        _backups = await _readBackups();
        notifyListeners();
      });

  Future<List<ForeignKernelFile>> scanForeignKernels() async {
    final steam = settings.steamPath;
    if (steam.isEmpty || !await Directory(steam).exists()) return [];
    return [
      for (final name in await _existingForeignKernelFiles(steam))
        ForeignKernelFile(name, _foreignKernelOwner(name)),
    ];
  }

  Future<KernelCleanupResult> cleanupForeign(
    List<String> selected,
  ) async => _exclusive(() async {
    final steam = await _requireStoppedSteam();
    final found = {
      for (final item in await scanForeignKernels()) item.relativePath: item,
    };
    for (final name in selected) {
      if (!found.containsKey(name)) {
        throw ArgumentError.value(
          name,
          'selected',
          'Not a detected kernel file',
        );
      }
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-foreign';
    final backupDir = Directory(p.join(_backupDir, id));
    await backupDir.create(recursive: true);
    final removed = <String>[];
    final failed = <String, String>{};
    for (final name in selected) {
      final file = File(p.join(steam, name));
      try {
        await _assertRegularFile(file);
        final target = File(p.join(backupDir.path, name));
        await target.parent.create(recursive: true);
        await file.copy(target.path);
        await file.delete();
        removed.add(name);
      } catch (error) {
        failed[name] = '$error';
      }
    }
    return KernelCleanupResult(removed: removed, failed: failed, backupId: id);
  });

  static const _residualFiles =
      <
        ({
          String name,
          KernelResidualCategory category,
          KernelResidualSeverity severity,
          String description,
          bool canClean,
        })
      >[
        (
          name: 'OpenSteamTool.dll',
          category: KernelResidualCategory.openSteamTool,
          severity: KernelResidualSeverity.high,
          description: 'OpenSteamTool core DLL',
          canClean: true,
        ),
        (
          name: 'opensteamtool.toml',
          category: KernelResidualCategory.openSteamTool,
          severity: KernelResidualSeverity.info,
          description: 'OpenSteamTool configuration used by this app',
          canClean: false,
        ),
        (
          name: 'hid.dll',
          category: KernelResidualCategory.steamTools,
          severity: KernelResidualSeverity.high,
          description: 'SteamTools injection DLL',
          canClean: true,
        ),
        (
          name: 'zlib1.dll',
          category: KernelResidualCategory.steamTools,
          severity: KernelResidualSeverity.high,
          description: 'SteamTools injection DLL',
          canClean: true,
        ),
        (
          name: 'user32.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.high,
          description: 'TB/BIAO injection DLL',
          canClean: true,
        ),
        (
          name: 'midimap.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.high,
          description: 'TB/BIAO injection DLL',
          canClean: true,
        ),
        (
          name: 'xinput1_4.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.high,
          description: 'TB/BIAO injection DLL',
          canClean: true,
        ),
        (
          name: 'dwmapi.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.high,
          description: 'TB/BIAO injection DLL',
          canClean: true,
        ),
        (
          name: 'version.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.high,
          description: 'TB/BIAO injection DLL',
          canClean: true,
        ),
        (
          name: 'winmm.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.high,
          description: 'TB/BIAO injection DLL',
          canClean: true,
        ),
        (
          name: 'CaigamerQ.dll',
          category: KernelResidualCategory.tbBiao,
          severity: KernelResidualSeverity.warning,
          description: 'TB/BIAO companion DLL',
          canClean: true,
        ),
        (
          name: 'steam.cfg',
          category: KernelResidualCategory.steamConfig,
          severity: KernelResidualSeverity.info,
          description: 'Steam configuration; review before removing',
          canClean: true,
        ),
      ];

  static const _residualDirectories =
      <({String name, KernelResidualCategory category, String description})>[
        (
          name: 'opensteamtool',
          category: KernelResidualCategory.openSteamTool,
          description: 'OpenSteamTool data directory',
        ),
        (
          name: 'stplug-in',
          category: KernelResidualCategory.steamTools,
          description: 'SteamTools Lua plugin directory',
        ),
        (
          name: 'TB',
          category: KernelResidualCategory.tbBiao,
          description: 'TB kernel directory',
        ),
        (
          name: 'BIAO',
          category: KernelResidualCategory.tbBiao,
          description: 'BIAO kernel directory',
        ),
      ];

  Future<KernelScanResult> scanResiduals({TaskContext? context}) async {
    final steam = settings.steamPath;
    if (steam.isEmpty || !await Directory(steam).exists()) {
      _lastResidualItems = {};
      _lastResidualRoot = null;
      return KernelScanResult(scannedAt: DateTime.now(), items: const []);
    }
    final root = p.normalize(p.absolute(steam));
    final items = <KernelResidualItem>[];
    final seen = <String>{};

    Future<void> add(
      String path, {
      required KernelResidualCategory category,
      required KernelResidualSeverity severity,
      required String description,
      required bool canClean,
      required bool directory,
    }) async {
      context?.checkCancelled();
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (directory
          ? type != FileSystemEntityType.directory
          : type != FileSystemEntityType.file) {
        return;
      }
      final full = p.normalize(p.absolute(path));
      if (!seen.add(full.toLowerCase())) return;
      final measured = await _measureResidual(full, directory: directory);
      items.add(
        KernelResidualItem(
          id: _residualId(full),
          category: category,
          displayName: p.basename(full),
          relativePath: p.relative(full, from: root),
          fullPath: full,
          isDirectory: directory,
          sizeBytes: measured.$1,
          fileCount: measured.$2,
          severity: severity,
          description: description,
          canClean: canClean,
        ),
      );
    }

    for (final directory in _residualDirectories) {
      await add(
        p.join(root, directory.name),
        category: directory.category,
        severity: KernelResidualSeverity.warning,
        description: directory.description,
        canClean: true,
        directory: true,
      );
    }
    for (final file in _residualFiles) {
      await add(
        p.join(root, file.name),
        category: file.category,
        severity: file.severity,
        description: file.description,
        canClean: file.canClean,
        directory: false,
      );
    }
    for (final name in ['dwmapi.dll', 'version.dll', 'winmm.dll']) {
      await add(
        p.join(root, 'bin', name),
        category: KernelResidualCategory.tbBiao,
        severity: KernelResidualSeverity.high,
        description: 'TB/BIAO DLL found under bin',
        canClean: true,
        directory: false,
      );
    }
    if (await Directory(root).exists()) {
      await for (final entity in Directory(root).list(followLinks: false)) {
        context?.checkCancelled();
        if (entity is File &&
            RegExp(
              r'^greenluma.*\.dll$',
              caseSensitive: false,
            ).hasMatch(p.basename(entity.path))) {
          await add(
            entity.path,
            category: KernelResidualCategory.tbBiao,
            severity: KernelResidualSeverity.high,
            description: 'GreenLuma injection DLL',
            canClean: true,
            directory: false,
          );
        }
      }
    }
    items.sort((a, b) {
      final category = a.category.index.compareTo(b.category.index);
      return category != 0
          ? category
          : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    _lastResidualItems = {for (final item in items) item.id: item};
    _lastResidualRoot = root;
    return KernelScanResult(
      steamPath: root,
      scannedAt: DateTime.now(),
      items: List.unmodifiable(items),
    );
  }

  KernelResidualCleanupPlan createResidualCleanupPlan(
    Iterable<String> itemIds,
  ) {
    final root = _lastResidualRoot;
    if (root == null) {
      return const KernelResidualCleanupPlan(
        items: [],
        backupRoot: '',
        totalBytes: 0,
      );
    }
    final ids = itemIds.toSet();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final backupRoot = p.join(_backupDir, 'residual-$stamp');
    final items = <KernelResidualCleanupItem>[];
    var totalBytes = 0;
    for (final item in _lastResidualItems.values) {
      if (!ids.contains(item.id) ||
          !item.canClean ||
          !_isUnderRoot(item.fullPath, root)) {
        continue;
      }
      final relative = p.relative(item.fullPath, from: root);
      items.add(
        KernelResidualCleanupItem(
          itemId: item.id,
          fullPath: item.fullPath,
          isDirectory: item.isDirectory,
          displayName: item.displayName,
          backupPath: p.join(backupRoot, relative),
          sizeBytes: item.sizeBytes,
        ),
      );
      totalBytes += item.sizeBytes;
    }
    return KernelResidualCleanupPlan(
      items: List.unmodifiable(items),
      backupRoot: backupRoot,
      totalBytes: totalBytes,
    );
  }

  Future<KernelResidualCleanupResult> executeResidualCleanup(
    KernelResidualCleanupPlan plan, {
    TaskContext? context,
  }) async => _exclusive(() async {
    final steam = await _requireStoppedSteam();
    final root = p.normalize(p.absolute(steam));
    if (plan.isEmpty) {
      return const KernelResidualCleanupResult(
        success: false,
        backupRoot: '',
        deletedCount: 0,
        failedCount: 0,
        errors: ['No selected residual items'],
        message: 'No selected residual items',
      );
    }
    await Directory(plan.backupRoot).create(recursive: true);
    final errors = <String>[];
    final removedIds = <String>{};
    var deleted = 0;
    for (final item in plan.items) {
      context?.checkCancelled();
      try {
        if (!_isUnderRoot(item.fullPath, root)) {
          throw FileSystemException(
            'Residual path is outside the Steam root',
            item.fullPath,
          );
        }
        final type = await FileSystemEntity.type(
          item.fullPath,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) {
          continue;
        }
        if (item.isDirectory) {
          if (type != FileSystemEntityType.directory) {
            throw FileSystemException(
              'Residual directory changed type',
              item.fullPath,
            );
          }
          await _rejectDirectoryLinks(item.fullPath);
          context?.report('Backing up ${item.displayName}');
          await _copyResidualDirectory(item.fullPath, item.backupPath);
          final original = await _measureResidual(
            item.fullPath,
            directory: true,
          );
          final backup = await _measureResidual(
            item.backupPath,
            directory: true,
          );
          if (original != backup) {
            throw FileSystemException(
              'Residual directory backup does not match',
              item.fullPath,
            );
          }
          context?.report('Removing ${item.displayName}');
          await Directory(item.fullPath).delete(recursive: true);
        } else {
          if (type != FileSystemEntityType.file) {
            throw FileSystemException(
              'Residual item changed type',
              item.fullPath,
            );
          }
          final source = File(item.fullPath);
          final backup = File(item.backupPath);
          await backup.parent.create(recursive: true);
          context?.report('Backing up ${item.displayName}');
          await source.copy(backup.path);
          if (await source.length() != await backup.length()) {
            throw FileSystemException(
              'Residual file backup does not match',
              item.fullPath,
            );
          }
          context?.report('Removing ${item.displayName}');
          await source.delete();
        }
        deleted++;
        removedIds.add(item.itemId);
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        errors.add('${item.displayName}: $error');
      }
    }
    final success = errors.isEmpty;
    final result = KernelResidualCleanupResult(
      success: success,
      backupRoot: plan.backupRoot,
      deletedCount: deleted,
      failedCount: errors.length,
      errors: List.unmodifiable(errors),
      message: success
          ? 'Backed up and removed $deleted residual items'
          : 'Removed $deleted residual items; ${errors.length} failed',
    );
    _lastResidualItems.removeWhere((id, _) => removedIds.contains(id));
    notifyListeners();
    return result;
  });

  Future<List<TomlFetchResult>> fetchTomlFiles({
    TaskContext? context,
    SteamDllTomlInfo? info,
  }) async {
    final steam = await _requireStoppedSteam();
    final resolved = info ?? await detectSteamDllInfo();
    if (resolved == null) {
      throw StateError('Steam DLL fingerprints are unavailable');
    }
    final results = <TomlFetchResult>[];
    final channel = tomlChannelSettings;
    for (final target in _tomlTargets) {
      final sha = target.$2 == 'steamui' ? resolved.uiSha : resolved.clientSha;
      context?.checkCancelled();
      final relative = 'opensteamtool/${target.$1}/${target.$2}/$sha.toml';
      final uri = Uri.parse(
        channel.urlTemplate
            .replaceAll('{channel}', target.$1)
            .replaceAll('{component}', target.$2)
            .replaceAll('{sha256}', sha),
      );
      context?.report('Fetching ${target.$1}/${target.$2}');
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 404) {
          results.add(
            TomlFetchResult(
              relativePath: relative,
              success: false,
              notFound: true,
              error: 'No signatures for this Steam build',
            ),
          );
        } else if (response.statusCode != 200) {
          throw HttpException(
            'Signatures HTTP ${response.statusCode}',
            uri: uri,
          );
        } else {
          if (response.bodyBytes.isEmpty ||
              response.bodyBytes.length > 4 * 1024 * 1024) {
            throw const FormatException('Invalid signature file size');
          }
          context?.checkCancelled();
          await _atomicBytes(File(p.join(steam, relative)), response.bodyBytes);
          results.add(TomlFetchResult(relativePath: relative, success: true));
        }
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        results.add(
          TomlFetchResult(
            relativePath: relative,
            success: false,
            error: '$error',
          ),
        );
      }
    }
    return results;
  }

  Future<void> _ensureSteamSignatures(
    String steam, {
    TaskContext? context,
  }) async {
    final info = await detectSteamDllInfo();
    if (info == null) return;
    var missing = await _missingSignatureFiles(steam, info);
    if (missing.isEmpty) return;

    context?.report('Downloading Steam signatures');
    await fetchTomlFiles(context: context, info: info);
    missing = await _missingSignatureFiles(steam, info);
    if (missing.isEmpty) return;

    Object? localError;
    context?.report('Building missing Steam signatures');
    try {
      await _localTomlBuilderRunner(steamPath: steam);
    } catch (error) {
      localError = error;
    }
    missing = await _missingSignatureFiles(steam, info);
    if (missing.isEmpty) return;
    final localeText = localizationsFor(settings.language);
    throw StateError(
      localeText.kernelSignaturesUnavailable(
        info.buildId ?? localeText.unknownVersion,
        missing.join(', '),
        localError?.toString() ?? localeText.kernelSignatureFallbackUnavailable,
      ),
    );
  }

  Future<List<String>> _missingSignatureFiles(
    String steam,
    SteamDllTomlInfo info,
  ) async {
    final missing = <String>[];
    for (final target in _tomlTargets) {
      final sha = target.$2 == 'steamui' ? info.uiSha : info.clientSha;
      final file = File(
        p.join(steam, 'opensteamtool', target.$1, target.$2, '$sha.toml'),
      );
      if (!await file.exists() || await file.length() == 0) {
        missing.add('${target.$1}/${target.$2}/$sha.toml');
      }
    }
    return missing;
  }

  Future<LocalTomlBuildReport> buildLocalTomlFiles({
    void Function(LocalTomlBuildEvent event)? onEvent,
  }) async {
    final steam = await _requireStoppedSteam();
    return _localTomlBuilderRunner(steamPath: steam, onEvent: onEvent);
  }

  File? get _kernelTomlFile {
    final steam = settings.steamPath;
    if (steam.isEmpty) return null;
    return File(p.join(steam, 'opensteamtool.toml'));
  }

  File? get _manifestLuaFile {
    final steam = settings.steamPath;
    if (steam.isEmpty) return null;
    return File(p.join(steam, 'config', 'lua', 'flsteamlua_manifest.lua'));
  }

  Future<void> _installManifestLuaBridge() async {
    final file = _manifestLuaFile;
    if (file == null) {
      throw StateError('Select your Steam folder first');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(_manifestLuaSource, flush: true);
  }

  Future<void> _removeManifestLuaBridge() async {
    final file = _manifestLuaFile;
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  Future<KernelManifestSettings> readManifestSettings() async {
    final file = _kernelTomlFile;
    final source = file != null && await file.exists()
        ? await file.readAsString()
        : '';
    final url = _tomlValue(source, 'manifest', 'url') ?? '20770407';
    final failover =
        (_tomlValue(source, 'manifest', 'failover') ?? 'true') != 'false';
    final storedMode = settings.get<String>('kernelManifestMode', '');
    final legacyMode = url.startsWith(kernelManifestProxyBase)
        ? KernelManifestMode.localProxy
        : url.startsWith('http://') || url.startsWith('https://')
        ? KernelManifestMode.custom
        : KernelManifestMode.builtIn;
    final mode =
        KernelManifestMode.values
            .where((value) => value.name == storedMode)
            .firstOrNull ??
        legacyMode;
    final header = settings.get<String>(
      'kernelManifestCustomHeader',
      _tomlValue(source, 'manifest', 'header') ?? '',
    );
    final formatValue = settings.get<String>(
      'kernelManifestFormat',
      _tomlValue(source, 'manifest', 'format') ?? '',
    );
    final format =
        KernelManifestFormat.values
            .where((value) => value.name == formatValue)
            .firstOrNull ??
        KernelManifestFormat.plain;
    final provider = mode == KernelManifestMode.builtIn
        ? url
        : settings.get<String>('kernelManifestProvider', '20770407');
    final storedCustomUrl = settings.get<String>('kernelManifestCustomUrl', '');
    final sourceIds = settings
        .get<List<dynamic>>('kernelManifestSourceIds', const [])
        .whereType<String>()
        .toList();
    return KernelManifestSettings(
      mode: mode,
      provider: provider,
      customUrl: mode == KernelManifestMode.custom && storedCustomUrl.isEmpty
          ? url
          : storedCustomUrl,
      customHeader: header,
      format: format,
      failover: failover,
      sourceIds: sourceIds,
    );
  }

  KernelTomlChannelSettings get tomlChannelSettings =>
      KernelTomlChannelSettings(
        repository: _normalizeRepository(
          settings.get<String>(
            'kernelTomlRepository',
            kernelDefaultTomlRepository,
          ),
        ),
        channel: settings.get<String>('kernelTomlChannel', 'main'),
        mode:
            KernelTomlChannelMode.values
                .where(
                  (value) =>
                      value.name ==
                      settings.get<String>(
                        'kernelTomlChannelMode',
                        KernelTomlChannelMode.directory.name,
                      ),
                )
                .firstOrNull ??
            KernelTomlChannelMode.directory,
      );

  Future<void> saveTomlChannelSettings(KernelTomlChannelSettings value) async {
    final normalized = KernelTomlChannelSettings(
      repository: _normalizeRepository(value.repository),
      channel: value.channel.trim(),
      mode: value.mode,
    );
    if (value.mode == KernelTomlChannelMode.directory &&
        !RegExp(r'^[A-Za-z0-9_.\-/]+$').hasMatch(value.channel)) {
      throw const FormatException('Invalid metadata branch');
    }
    await KernelConfig(
      settings.steamPath,
    ).update('remote', {'url_template': normalized.urlTemplate});
    await settings.set(
      'kernelTomlRepository',
      _normalizeRepository(value.repository),
    );
    await settings.set('kernelTomlChannel', value.channel.trim());
    await settings.set('kernelTomlChannelMode', value.mode.name);
    notifyListeners();
  }

  Future<void> saveManifestSettings(KernelManifestSettings value) async {
    if (value.mode == KernelManifestMode.custom) {
      final uri = Uri.tryParse(value.customUrl);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          !value.customUrl.contains(RegExp(r'\{(?:gid|manifestId)\}'))) {
        throw const FormatException(
          'Custom manifest URL must include {gid} or {manifestId}',
        );
      }
    }
    if (value.mode == KernelManifestMode.localProxy &&
        value.sourceIds.isEmpty) {
      throw const FormatException(
        'Select at least one manifest request-code source',
      );
    }
    final fallbackProvider = kernelManifestProviders.containsKey(value.provider)
        ? value.provider
        : '20770407';
    await settings.set('kernelManifestMode', value.mode.name);
    await settings.set('kernelManifestProvider', fallbackProvider);
    await settings.set('kernelManifestCustomUrl', value.customUrl.trim());
    await settings.set('kernelManifestCustomHeader', value.customHeader.trim());
    await settings.set('kernelManifestFormat', value.format.name);
    await settings.set('kernelManifestFailover', value.failover);
    await settings.set('kernelManifestSourceIds', value.sourceIds);
    final url = switch (value.mode) {
      KernelManifestMode.builtIn => fallbackProvider,
      KernelManifestMode.custom ||
      KernelManifestMode.localProxy => fallbackProvider,
    };
    final file = _kernelTomlFile;
    if (file == null) {
      throw StateError('Select your Steam folder first');
    }
    await KernelConfig(
      settings.steamPath,
    ).update('manifest', {'url': url, 'failover': value.failover});
    if (value.mode == KernelManifestMode.builtIn) {
      await _removeManifestLuaBridge();
    } else {
      await ensureManifestProxy();
    }
    notifyListeners();
  }

  Future<void> syncManifestConfiguration() async {
    final value = await readManifestSettings();
    if (value.mode == KernelManifestMode.builtIn) {
      await _removeManifestLuaBridge();
    } else {
      await ensureManifestProxy();
    }
  }

  Future<void> ensureManifestProxy() async {
    await _installManifestLuaBridge();
    if (_manifestProxyServer != null) return;
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      47831,
      shared: false,
    );
    _manifestProxyServer = server;
    server.listen((request) {
      unawaited(_handleManifestProxy(request));
    });
  }

  Future<void> _handleManifestProxy(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'GET' || request.uri.pathSegments.length != 4) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final segments = request.uri.pathSegments;
      final appId = int.tryParse(segments[1]);
      final depotId = int.tryParse(segments[2]);
      final gid = segments[3];
      if (segments.first != 'manifest' ||
          appId == null ||
          appId <= 0 ||
          depotId == null ||
          depotId <= 0 ||
          !RegExp(r'^[1-9]\d*$').hasMatch(gid)) {
        response.statusCode = HttpStatus.badRequest;
        return;
      }
      final code = await fetchManifestCode(
        appId: appId,
        depotId: depotId,
        gid: gid,
      );
      response.headers.contentType = ContentType.text;
      response.write(code);
    } catch (error) {
      response.statusCode = HttpStatus.badGateway;
      response.write('$error');
    } finally {
      await response.close();
    }
  }

  Future<String> fetchManifestCode({
    required int appId,
    required int depotId,
    required String gid,
  }) async {
    final config = await readManifestSettings();
    if (config.mode == KernelManifestMode.builtIn) {
      final preferred = config.provider;
      final providers = [
        preferred,
        if (config.failover)
          ...kernelManifestProviders.keys.where((value) => value != preferred),
      ];
      Object? lastError;
      for (final provider in providers) {
        final endpoint = _builtInManifestUrl(provider, appId, depotId, gid);
        if (endpoint == null) continue;
        try {
          final response = await _client
              .get(endpoint, headers: _manifestHeaders(config, provider))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) {
            throw HttpException(
              'Manifest provider HTTP ${response.statusCode}',
              uri: endpoint,
            );
          }
          final code = _manifestCodeAuto(response.body);
          if (code != null) return code;
          throw const FormatException('Manifest provider returned no code');
        } catch (error) {
          lastError = error;
        }
      }
      throw StateError(
        'No manifest provider returned a valid code: $lastError',
      );
    }
    if (config.mode == KernelManifestMode.localProxy) {
      Object? lastError;
      for (final sourceId in config.sourceIds) {
        try {
          final code = await _resolveManifestRequestCode(
            sourceId: sourceId,
            appId: appId,
            depotId: depotId,
            gid: gid,
          );
          if (code != null) return code;
          lastError = StateError('$sourceId returned no request code');
        } catch (error) {
          lastError = error;
        }
        if (!config.failover) break;
      }
      throw StateError(
        'No manifest content source returned a valid request code: $lastError',
      );
    }
    final endpoint = Uri.tryParse(
      _manifestUrl(config.customUrl, appId, depotId, gid),
    );
    if (endpoint == null || !endpoint.hasAuthority) {
      throw const FormatException('Manifest source URL is not configured');
    }
    final response = await _client
        .get(endpoint, headers: _manifestHeaders(config))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException(
        'Manifest source HTTP ${response.statusCode}',
        uri: endpoint,
      );
    }
    final code = _manifestCode(response.body, config.format);
    if (code == null) {
      throw const FormatException('Manifest source returned no code');
    }
    return code;
  }

  Map<String, String> _manifestHeaders(
    KernelManifestSettings config, [
    String? provider,
  ]) {
    final headers = <String, String>{..._headers};
    if (provider == 'manifestdex') {
      headers['User-Agent'] = 'ManifestDeX/1.0';
    }
    if (config.mode != KernelManifestMode.builtIn &&
        config.customHeader.trim().isNotEmpty) {
      final split = config.customHeader.indexOf(':');
      if (split > 0) {
        headers[config.customHeader.substring(0, split).trim()] = config
            .customHeader
            .substring(split + 1)
            .trim();
      }
    }
    return headers;
  }

  Uri? _builtInManifestUrl(
    String provider,
    int appId,
    int depotId,
    String gid,
  ) {
    final template = switch (provider) {
      '20770407' => 'https://20770407.xyz/manifest/{depotId}/{gid}',
      'opensteamtool' => 'https://manifest.opensteamtool.com/{gid}',
      'steamrun' => 'https://manifest.steam.run/api/manifest/{gid}',
      'wudrm' => 'http://gmrc.wudrm.com/manifest/{gid}',
      'SDM' => 'https://steamapi.993499094.xyz/manifest/{depotId}/{gid}',
      'manifestdex' => 'https://manifest.manifestdex.com/{gid}',
      _ => null,
    };
    return template == null
        ? null
        : Uri.tryParse(_manifestUrl(template, appId, depotId, gid));
  }

  String _manifestUrl(String template, int appId, int depotId, String gid) =>
      template
          .replaceAll('{gid}', Uri.encodeComponent(gid))
          .replaceAll('{manifestId}', Uri.encodeComponent(gid))
          .replaceAll('{appId}', '$appId')
          .replaceAll('{appid}', '$appId')
          .replaceAll('{depotId}', '$depotId')
          .replaceAll('{depotid}', '$depotId');

  String? _manifestCode(String body, KernelManifestFormat format) {
    final text = body.trim();
    if (format == KernelManifestFormat.plain) {
      return RegExp(r'^[1-9]\d*$').hasMatch(text) ? text : null;
    }
    return _jsonManifestCode(text);
  }

  String? _manifestCodeAuto(String body) {
    final text = body.trim();
    if (RegExp(r'^[1-9]\d*$').hasMatch(text)) return text;
    return _jsonManifestCode(text);
  }

  String? _jsonManifestCode(String text) {
    try {
      final value = jsonDecode(text);
      if (value is Map) {
        for (final key in ['content', 'manifestId', 'manifest_id', 'code']) {
          final code = value[key]?.toString().trim();
          if (code != null && RegExp(r'^[1-9]\d*$').hasMatch(code)) {
            return code;
          }
        }
      }
    } on FormatException {
      // Fall through to the content regex for non-standard JSON wrappers.
    }
    final match = RegExp(r'"content"\s*:\s*"([1-9]\d*)"').firstMatch(text);
    return match?.group(1);
  }

  static String? _tomlValue(String source, String section, String key) {
    final table = KernelConfig.decode(source)[section];
    return table is Map ? table[key]?.toString() : null;
  }

  Future<SteamDllTomlInfo?> detectSteamDllInfo() async {
    final steam = settings.steamPath;
    if (steam.isEmpty) return null;
    final client = File(p.join(steam, 'steamclient64.dll'));
    final ui = File(p.join(steam, 'steamui.dll'));
    if (!await client.exists() || !await ui.exists()) return null;
    final clientSha = (await sha256.bind(client.openRead()).first).toString();
    final uiSha = (await sha256.bind(ui.openRead()).first).toString();
    return SteamDllTomlInfo(
      clientSha: clientSha,
      uiSha: uiSha,
      clientSize: await client.length(),
      uiSize: await ui.length(),
      buildId: await _readInstalledBuildId(steam),
    );
  }

  Future<String> _requireStoppedSteam() async {
    final steam = settings.steamPath;
    if (steam.isEmpty || !await File(p.join(steam, 'steam.exe')).exists()) {
      throw StateError('Set a valid Steam folder containing steam.exe first');
    }
    if (await _isSteamRunning()) {
      throw const SteamRunningException();
    }
    for (final name in await _existingManaged(steam)) {
      await _assertRegularFile(File(p.join(steam, name)));
    }
    return steam;
  }

  Future<void> _assertRegularFile(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'Kernel target is not a regular file',
        file.path,
      );
    }
  }

  List<String> get _managedNames => [
    for (final base in _baseNames)
      for (final suffix in _suffixes) '${_managedPath(base)}$suffix',
  ];

  static String _managedPath(String value) => p.joinAll(value.split('/'));

  Future<List<String>> _existingForeignKernelFiles(String steam) async {
    final result = <String>{};
    for (final name in _foreignKernelFiles.keys) {
      final path = p.joinAll(name.split('/'));
      if (await FileSystemEntity.type(
            p.join(steam, path),
            followLinks: false,
          ) ==
          FileSystemEntityType.file) {
        result.add(path);
      }
    }
    await for (final entity in Directory(steam).list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (RegExp(r'^greenluma.*\.dll$', caseSensitive: false).hasMatch(name)) {
        result.add(name);
      }
    }
    return result.toList()..sort();
  }

  static String _foreignKernelOwner(String name) {
    final normalized = name.replaceAll('\\', '/');
    final known = _foreignKernelFiles[normalized];
    if (known != null) return known;
    return RegExp(
          r'^greenluma.*\.dll$',
          caseSensitive: false,
        ).hasMatch(p.basename(normalized))
        ? 'GreenLuma'
        : 'Unknown';
  }

  Future<void> _removeForeignKernelFiles(
    String steam, {
    TaskContext? context,
  }) async {
    for (final name in await _existingForeignKernelFiles(steam)) {
      context?.checkCancelled();
      final file = File(p.join(steam, name));
      await _assertRegularFile(file);
      context?.report('Removing conflicting $name');
      await file.delete();
    }
  }

  Future<List<String>> _existingManaged(String steam) async {
    final result = <String>[];
    for (final name in _managedNames) {
      if (await FileSystemEntity.type(
            p.join(steam, name),
            followLinks: false,
          ) !=
          FileSystemEntityType.notFound) {
        result.add(name);
      }
    }
    return result;
  }

  InjectionMode _currentInjectionMode(String steam) {
    for (final name in _versionEntryNames) {
      if (File(p.join(steam, _managedPath(name))).existsSync()) {
        return InjectionMode.version;
      }
    }
    for (final name in _dwmapiEntryNames) {
      if (File(p.join(steam, _managedPath(name))).existsSync()) {
        return InjectionMode.dwmapi;
      }
    }
    final stored = settings.get<String>('kernelInjectionMode', '');
    if (stored == InjectionMode.version.name) {
      return InjectionMode.version;
    }
    if (stored == InjectionMode.dwmapi.name) {
      return InjectionMode.dwmapi;
    }
    for (final name in _versionEntryNames) {
      if (File(p.join(steam, '${_managedPath(name)}.off')).existsSync()) {
        return InjectionMode.version;
      }
    }
    return InjectionMode.dwmapi;
  }

  Future<void> _normalizeEntry(String steam, InjectionMode mode) async {
    final entries = mode == InjectionMode.version
        ? _versionEntryNames
        : _dwmapiEntryNames;
    final otherEntries = mode == InjectionMode.version
        ? _dwmapiEntryNames
        : _versionEntryNames;
    final active = await _activateEntry(steam, entries);
    if (active == null) {
      throw StateError('Package is missing required entry ${entries.first}');
    }
    await _deactivateEntries(steam, otherEntries);
    await settings.set('kernelInjectionMode', mode.name);
  }

  Future<String?> _activateEntry(String steam, List<String> names) async {
    for (final name in names) {
      final active = File(p.join(steam, _managedPath(name)));
      if (await active.exists()) {
        for (final suffix in const ['.disabled', '.off']) {
          final inactive = File('${active.path}$suffix');
          if (await inactive.exists()) await inactive.delete();
        }
        return name;
      }
    }
    for (final name in names) {
      final active = File(p.join(steam, _managedPath(name)));
      for (final suffix in const ['.disabled', '.off']) {
        final inactive = File('${active.path}$suffix');
        if (await inactive.exists()) {
          await inactive.rename(active.path);
          return name;
        }
      }
    }
    return null;
  }

  Future<void> _deactivateEntries(String steam, List<String> names) async {
    for (final name in names) {
      final active = File(p.join(steam, _managedPath(name)));
      final disabled = File('${active.path}.disabled');
      final off = File('${active.path}.off');
      if (await active.exists()) {
        if (await disabled.exists()) await disabled.delete();
        await active.rename(disabled.path);
      }
      if (await off.exists() && !await disabled.exists()) {
        await off.rename(disabled.path);
      }
    }
  }

  Future<KernelBackup> _createBackup(
    String steam,
    String reason, {
    bool includeForeignKernels = false,
  }) async {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_key(reason).substring(0, 6)}';
    final directory = Directory(p.join(_backupDir, id));
    await directory.create(recursive: true);
    final files = {
      ...await _existingManaged(steam),
      if (includeForeignKernels) ...await _existingForeignKernelFiles(steam),
    }.toList()..sort();
    for (final name in files) {
      final file = File(p.join(steam, name));
      await _assertRegularFile(file);
      final target = File(p.join(directory.path, name));
      await target.parent.create(recursive: true);
      await file.copy(target.path);
    }
    final now = DateTime.now();
    await _atomicJson(File(p.join(directory.path, 'snapshot.json')), {
      'id': id,
      'createdAt': now.toIso8601String(),
      'reason': reason,
      'files': files,
      'activeId': _activePackageId,
    });
    return KernelBackup(
      id: id,
      createdAt: now,
      reason: reason,
      files: files,
      activePackageId: _activePackageId,
    );
  }

  Future<List<KernelBackup>> _readBackups() async {
    final result = <KernelBackup>[];
    if (!await Directory(_backupDir).exists()) return result;
    await for (final entry in Directory(_backupDir).list(followLinks: false)) {
      if (entry is! Directory) continue;
      final file = File(p.join(entry.path, 'snapshot.json'));
      if (!await file.exists()) continue;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final id = json['id'] as String;
        final files = (json['files'] as List).cast<String>();
        if (id != p.basename(entry.path) ||
            files.any((name) => !_isRestorableBackupFile(name))) {
          throw const FormatException('Invalid kernel backup manifest');
        }
        result.add(
          KernelBackup(
            id: id,
            createdAt: DateTime.parse(json['createdAt'] as String),
            reason: json['reason'] as String,
            files: files,
            activePackageId: json['activeId'] as String?,
          ),
        );
      } catch (error) {
        _warnings.add('Invalid backup ${p.basename(entry.path)}: $error');
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<void> _applyBackup(String steam, KernelBackup backup) async {
    final contents = <String, List<int>>{};
    for (final name in backup.files) {
      final file = File(p.join(_backupDir, backup.id, name));
      await _assertRegularFile(file);
      contents[name] = await file.readAsBytes();
    }
    for (final name in {...await _existingManaged(steam), ...backup.files}) {
      final file = File(p.join(steam, name));
      if (await file.exists()) {
        await _assertRegularFile(file);
        await file.delete();
      }
    }
    for (final entry in contents.entries) {
      await _writeFile(File(p.join(steam, entry.key)), entry.value);
    }
    await _writeState(backup.activePackageId);
  }

  bool _isRestorableBackupFile(String name) {
    final normalized = p.normalize(name);
    if (p.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('..${p.separator}')) {
      return false;
    }
    if (_managedNames.contains(normalized)) return true;
    final portable = normalized.replaceAll('\\', '/');
    if (_foreignKernelFiles.containsKey(portable)) return true;
    return p.dirname(normalized) == '.' &&
        RegExp(
          r'^greenluma.*\.dll$',
          caseSensitive: false,
        ).hasMatch(normalized);
  }

  Future<void> _detectInstalled() async {
    final steam = settings.steamPath;
    if (steam.isEmpty || !await Directory(steam).exists()) {
      _installed = const KernelInstallation();
      return;
    }
    final files = await _existingManaged(steam);
    final dwm = _hasActiveEntry(files, _dwmapiEntryNames);
    final version = _hasActiveEntry(files, _versionEntryNames);
    final bodyPresent =
        files.contains('OpenSteamTool.dll') ||
        files.contains('OpenSteamTool.dll.off');
    final disabled =
        files.contains('OpenSteamTool.dll.off') ||
        files.contains('xinput1_4.dll.off');
    final core = File(
      p.join(
        steam,
        files.contains('OpenSteamTool.dll')
            ? 'OpenSteamTool.dll'
            : 'OpenSteamTool.dll.off',
      ),
    );
    String? localVersion;
    if (await core.exists()) {
      final bytes = await core.readAsBytes();
      localVersion = await Isolate.run(() => _extractVersion(bytes));
    }
    _installed = KernelInstallation(
      installed: bodyPresent,
      enabled: bodyPresent && !disabled && (dwm != version),
      entryState: dwm && version
          ? InjectionEntryState.bothActive
          : dwm
          ? InjectionEntryState.dwmapi
          : version
          ? InjectionEntryState.version
          : InjectionEntryState.none,
      version: localVersion,
      files: files,
    );
  }

  static bool _hasActiveEntry(List<String> files, List<String> names) =>
      names.any((name) => files.contains(_managedPath(name)));

  static String? _extractVersion(List<int> bytes) {
    final legacy = _legacyVersionHashes[sha256.convert(bytes).toString()];
    if (legacy != null) return legacy;
    const marker = [255, 255, 255, 255, 0, 0, 0, 0];
    for (var i = 0; i <= bytes.length - marker.length - 1; i++) {
      var matches = true;
      for (var j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      final start = i + marker.length;
      var end = start;
      while (end < bytes.length && bytes[end] != 0 && end - start < 64) {
        end++;
      }
      final text = ascii.decode(bytes.sublist(start, end), allowInvalid: true);
      if (RegExp(r'^v?\d+\.\d+\.\d+').hasMatch(text)) return text;
    }
    return null;
  }

  Future<void> _writeState(String? id) async {
    await _atomicJson(_stateFile, {'activeId': id});
    _activePackageId = id;
  }

  Future<void> _writeMeta(KernelPackage package) =>
      _atomicJson(File(_metaPath(package.id)), package.toJson());

  Future<void> _atomicJson(File file, Map<String, dynamic> json) =>
      _atomicBytes(
        file,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
      );

  Future<void> _atomicBytes(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  void _replacePackage(KernelPackage package) {
    _packages.removeWhere((item) => item.id == package.id);
    _packages.add(package);
    _sortPackages();
  }

  void _sortPackages() => _packages.sort((a, b) {
    if (a.source != b.source) return a.source == KernelSource.local ? -1 : 1;
    return (b.publishedAt ?? b.importedAt ?? DateTime(1970)).compareTo(
      a.publishedAt ?? a.importedAt ?? DateTime(1970),
    );
  });

  Future<String?> _readInstalledBuildId(String steam) async {
    final manifests =
        [
          File(p.join(steam, 'package', 'steam_client_win64.manifest')),
          File(
            p.join(steam, 'package', 'steam_client_publicbeta_win64.manifest'),
          ),
        ].where((file) => file.existsSync()).toList()..sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );
    final versionPattern = RegExp(r'"version"\s+"(\d+)"');
    for (final manifest in manifests) {
      try {
        final match = versionPattern.firstMatch(await manifest.readAsString());
        if (match != null) return match.group(1);
      } catch (_) {}
    }
    try {
      final log = File(p.join(steam, 'logs', 'connection_log.txt'));
      if (!await log.exists()) return null;
      final pattern = RegExp(r'Client version:\s*(\d+)');
      String? latest;
      for (final line in await log.readAsLines()) {
        final match = pattern.firstMatch(line);
        if (match != null) latest = match.group(1);
      }
      return latest;
    } catch (_) {
      return null;
    }
  }

  bool _isVersionOlder(String local, String remote) {
    List<int> parts(String value) => RegExp(
      r'\d+',
    ).allMatches(value).map((match) => int.parse(match.group(0)!)).toList();
    final current = parts(local.trim().replaceFirst(RegExp('^[vV]'), ''));
    final next = parts(remote.trim().replaceFirst(RegExp('^[vV]'), ''));
    final length = current.length > next.length ? current.length : next.length;
    for (var index = 0; index < length; index++) {
      final left = index < current.length ? current[index] : 0;
      final right = index < next.length ? next[index] : 0;
      if (right != left) return right > left;
    }
    return false;
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_mutating) throw StateError('Another kernel operation is running');
    _mutating = true;
    try {
      return await operation();
    } finally {
      _mutating = false;
    }
  }

  @override
  void dispose() {
    final proxy = _manifestProxyServer;
    _manifestProxyServer = null;
    if (proxy != null) unawaited(proxy.close(force: true));
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
