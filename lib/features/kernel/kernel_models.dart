enum KernelSource { official, local }

enum KernelSourceMode { repository, local }

enum KernelManifestMode { builtIn, custom, localProxy }

enum KernelManifestFormat { plain, steamrun, jsonContent }

enum KernelTomlChannelMode { branch, directory }

const kernelDefaultTomlRepository = 'huanyuejue/steam-monitor';

const kernelTomlChannelRepositories = [
  kernelDefaultTomlRepository,
  'hazre/steam-monitor',
  'kasakigaming/steam-monitor',
  'mmxlyo/steam-monitor',
  'OpenSteam001/steam-monitor',
  'madoiscool/steam-monitor',
];

class KernelTomlChannelSettings {
  const KernelTomlChannelSettings({
    this.repository = kernelDefaultTomlRepository,
    this.channel = 'main',
    this.mode = KernelTomlChannelMode.directory,
  });

  final String repository;
  final String channel;
  final KernelTomlChannelMode mode;
  String get urlTemplate =>
      'https://raw.githubusercontent.com/$repository/'
      '${mode == KernelTomlChannelMode.directory ? '$channel/' : ''}'
      '{channel}/{component}/{sha256}.toml';
}

class KernelManifestSettings {
  const KernelManifestSettings({
    this.mode = KernelManifestMode.builtIn,
    this.provider = '20770407',
    this.customUrl = '',
    this.customHeader = '',
    this.format = KernelManifestFormat.plain,
    this.failover = true,
    this.sourceIds = const [],
  });

  final KernelManifestMode mode;
  final String provider;
  final String customUrl;
  final String customHeader;
  final KernelManifestFormat format;
  final bool failover;
  final List<String> sourceIds;

  KernelManifestSettings copyWith({
    KernelManifestMode? mode,
    String? provider,
    String? customUrl,
    String? customHeader,
    KernelManifestFormat? format,
    bool? failover,
    List<String>? sourceIds,
  }) => KernelManifestSettings(
    mode: mode ?? this.mode,
    provider: provider ?? this.provider,
    customUrl: customUrl ?? this.customUrl,
    customHeader: customHeader ?? this.customHeader,
    format: format ?? this.format,
    failover: failover ?? this.failover,
    sourceIds: sourceIds ?? this.sourceIds,
  );
}

class KernelRepositoryInfo {
  const KernelRepositoryInfo({
    required this.slug,
    required this.fork,
    required this.defaultBranch,
    required this.archived,
    this.parent,
    this.pushedAt,
  });

  final String slug;
  final bool fork;
  final String defaultBranch;
  final bool archived;
  final String? parent;
  final DateTime? pushedAt;
}

enum InjectionMode { dwmapi, version }

enum InjectionEntryState { none, dwmapi, version, bothActive }

enum KernelResidualCategory { openSteamTool, steamTools, tbBiao, steamConfig }

enum KernelResidualSeverity { info, warning, high }

class SteamDllTomlInfo {
  const SteamDllTomlInfo({
    required this.clientSha,
    required this.uiSha,
    this.clientSize = 0,
    this.uiSize = 0,
    this.buildId,
  });

  final String clientSha;
  final String uiSha;
  final int clientSize;
  final int uiSize;
  final String? buildId;
}

class KernelUpdateInfo {
  const KernelUpdateInfo({
    required this.localVersion,
    required this.package,
    required this.hasUpdate,
  });

  final String? localVersion;
  final KernelPackage package;
  final bool hasUpdate;
}

class KernelPackage {
  const KernelPackage({
    required this.id,
    required this.version,
    required this.displayName,
    required this.source,
    this.zipPath,
    this.downloadUrl,
    this.releaseUrl,
    this.sizeBytes = 0,
    this.publishedAt,
    this.importedAt,
    this.sha256Digest,
    this.repository,
    this.releaseNotes = '',
  });

  final String id;
  final String version;
  final String displayName;
  final KernelSource source;
  final String? zipPath;
  final String? downloadUrl;
  final String? releaseUrl;
  final int sizeBytes;
  final DateTime? publishedAt;
  final DateTime? importedAt;
  final String? sha256Digest;
  final String? repository;
  final String releaseNotes;

  KernelPackage copyWith({
    String? zipPath,
    int? sizeBytes,
    DateTime? importedAt,
    String? sha256Digest,
  }) => KernelPackage(
    id: id,
    version: version,
    displayName: displayName,
    source: source,
    zipPath: zipPath ?? this.zipPath,
    downloadUrl: downloadUrl,
    releaseUrl: releaseUrl,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    publishedAt: publishedAt,
    importedAt: importedAt ?? this.importedAt,
    sha256Digest: sha256Digest ?? this.sha256Digest,
    repository: repository,
    releaseNotes: releaseNotes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'displayName': displayName,
    'source': source.name,
    'downloadUrl': downloadUrl,
    'releaseUrl': releaseUrl,
    'sizeBytes': sizeBytes,
    'publishedAt': publishedAt?.toIso8601String(),
    'importedAt': importedAt?.toIso8601String(),
    'sha256': sha256Digest,
    'repository': repository,
    'releaseNotes': releaseNotes,
  };

  factory KernelPackage.fromJson(Map<String, dynamic> json, {String? zipPath}) {
    if (json['id'] is! String ||
        json['version'] is! String ||
        json['displayName'] is! String ||
        json['source'] is! String) {
      throw const FormatException('Invalid kernel package metadata');
    }
    return KernelPackage(
      id: json['id'] as String,
      version: json['version'] as String,
      displayName: json['displayName'] as String,
      source: KernelSource.values.byName(json['source'] as String),
      zipPath: zipPath,
      downloadUrl: json['downloadUrl'] as String?,
      releaseUrl: json['releaseUrl'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? ''),
      sha256Digest: json['sha256'] as String?,
      repository: json['repository'] as String?,
      releaseNotes: json['releaseNotes'] as String? ?? '',
    );
  }
}

class KernelInstallation {
  const KernelInstallation({
    this.installed = false,
    this.enabled = false,
    this.entryState = InjectionEntryState.none,
    this.version,
    this.files = const [],
  });

  final bool installed;
  final bool enabled;
  final InjectionEntryState entryState;
  final String? version;
  final List<String> files;
  bool get disabled =>
      files.contains('OpenSteamTool.dll.off') ||
      files.contains('xinput1_4.dll.off');
}

class KernelSwitchResult {
  const KernelSwitchResult({
    required this.success,
    required this.message,
    this.backupId,
    this.rollbackSucceeded,
  });
  final bool success;
  final String message;
  final String? backupId;
  final bool? rollbackSucceeded;
}

class KernelBackup {
  const KernelBackup({
    required this.id,
    required this.createdAt,
    required this.reason,
    required this.files,
    this.activePackageId,
  });
  final String id;
  final DateTime createdAt;
  final String reason;
  final List<String> files;
  final String? activePackageId;
}

class ForeignKernelFile {
  const ForeignKernelFile(this.relativePath, this.owner);
  final String relativePath;
  final String owner;
}

class KernelResidualItem {
  const KernelResidualItem({
    required this.id,
    required this.category,
    required this.displayName,
    required this.relativePath,
    required this.fullPath,
    required this.isDirectory,
    required this.sizeBytes,
    required this.fileCount,
    required this.severity,
    required this.description,
    required this.canClean,
  });

  final String id;
  final KernelResidualCategory category;
  final String displayName;
  final String relativePath;
  final String fullPath;
  final bool isDirectory;
  final int sizeBytes;
  final int fileCount;
  final KernelResidualSeverity severity;
  final String description;
  final bool canClean;
}

class KernelScanResult {
  const KernelScanResult({
    required this.scannedAt,
    required this.items,
    this.steamPath,
  });

  final String? steamPath;
  final DateTime scannedAt;
  final List<KernelResidualItem> items;

  bool get hasResiduals => items.isNotEmpty;
  int get cleanableCount => items.where((item) => item.canClean).length;
  int get totalBytes => items.fold(0, (sum, item) => sum + item.sizeBytes);
}

class KernelResidualCleanupItem {
  const KernelResidualCleanupItem({
    required this.itemId,
    required this.fullPath,
    required this.isDirectory,
    required this.displayName,
    required this.backupPath,
    required this.sizeBytes,
  });

  final String itemId;
  final String fullPath;
  final bool isDirectory;
  final String displayName;
  final String backupPath;
  final int sizeBytes;
}

class KernelResidualCleanupPlan {
  const KernelResidualCleanupPlan({
    required this.items,
    required this.backupRoot,
    required this.totalBytes,
  });

  final List<KernelResidualCleanupItem> items;
  final String backupRoot;
  final int totalBytes;

  bool get isEmpty => items.isEmpty;
}

class KernelResidualCleanupResult {
  const KernelResidualCleanupResult({
    required this.success,
    required this.backupRoot,
    required this.deletedCount,
    required this.failedCount,
    required this.errors,
    required this.message,
  });

  final bool success;
  final String backupRoot;
  final int deletedCount;
  final int failedCount;
  final List<String> errors;
  final String message;
}

class KernelCleanupResult {
  const KernelCleanupResult({
    required this.removed,
    required this.failed,
    required this.backupId,
  });
  final List<String> removed;
  final Map<String, String> failed;
  final String backupId;
}

class TomlFetchResult {
  const TomlFetchResult({
    required this.relativePath,
    required this.success,
    this.notFound = false,
    this.error,
  });
  final String relativePath;
  final bool success;
  final bool notFound;
  final String? error;
}
