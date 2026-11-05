class CloudStatus {
  const CloudStatus({
    required this.enabled,
    required this.syncPath,
    required this.provider,
    required this.configured,
    this.pluginInstalled = false,
    this.syncAchievements = false,
    this.syncPlaytime = false,
    this.pendingRestart = false,
    this.coreReady = false,
  });
  final bool enabled;
  final String syncPath;
  final String provider;
  final bool configured;
  final bool pluginInstalled;
  final bool syncAchievements;
  final bool syncPlaytime;
  final bool pendingRestart, coreReady;
  bool get remoteSyncConfigured => provider != 'folder' && configured;
}

class CloudPluginStatus {
  const CloudPluginStatus({
    required this.installed,
    required this.enabled,
    required this.path,
    this.size = 0,
    this.modifiedAt,
    this.version,
  });

  final bool installed;
  final bool enabled;
  final String path;
  final int size;
  final DateTime? modifiedAt;
  final String? version;
}

enum CloudSaveLocation { folder, cache, remote }

class CloudSave {
  const CloudSave({
    required this.appId,
    required this.accountId,
    required this.path,
    this.location = CloudSaveLocation.folder,
    this.modifiedAt,
    this.fileCount = 0,
    this.size = 0,
    this.storageId = 'current',
    this.detailsLoaded = true,
    this.checkedAt,
  });
  final int appId;
  final String accountId;
  final String path;
  final CloudSaveLocation location;
  bool get isRemote => location == CloudSaveLocation.remote;
  final DateTime? modifiedAt;
  final int fileCount;
  final int size;
  final String storageId;
  final bool detailsLoaded;
  final DateTime? checkedAt;
  String get id => '$storageId/${location.name}/$accountId/$appId';
}

class CloudDeleteTarget {
  const CloudDeleteTarget({
    required this.kind,
    required this.path,
    required this.accountId,
    required this.fileCount,
    required this.size,
  });
  final String kind;
  final String path;
  final String accountId;
  final int fileCount;
  final int size;
  bool get isRemote => kind == 'remote';
}

class CloudDeletePreview {
  const CloudDeletePreview({
    required this.appId,
    required this.provider,
    required this.targets,
    required this.backupDirectory,
    this.selection,
    this.target,
  });
  final int appId;
  final String provider;
  final List<CloudDeleteTarget> targets;
  final String backupDirectory;
  final CloudSave? selection;
  final CloudTarget? target;
  int get fileCount => targets.fold(0, (sum, target) => sum + target.fileCount);
  int get size => targets.fold(0, (sum, target) => sum + target.size);
}

class CloudBackup {
  const CloudBackup({
    required this.path,
    required this.appId,
    required this.createdAt,
    required this.fileCount,
    required this.size,
    this.provider = 'folder',
    this.locations = const [],
    this.target,
    this.note = '',
    this.pinned = false,
    this.reason = 'manual',
    this.verifiedAt,
  });
  final String path;
  final int appId;
  final DateTime createdAt;
  final int fileCount;
  final int size;
  final String provider;
  final List<CloudBackupLocation> locations;
  final CloudTarget? target;
  final String note, reason;
  final bool pinned;
  final DateTime? verifiedAt;
}

class CloudStorageProfile {
  const CloudStorageProfile({
    required this.id,
    required this.name,
    required this.provider,
    required this.summary,
    this.folder = '',
    this.account = '',
    this.checkedAt,
    this.writeTested = false,
  });
  final String id, name, provider, summary, folder, account;
  final DateTime? checkedAt;
  final bool writeTested;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'summary': summary,
    'folder': folder,
    'account': account,
    'checkedAt': checkedAt?.toIso8601String(),
    'writeTested': writeTested,
  };
  factory CloudStorageProfile.fromJson(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(value['id']) ||
        value['name'] is! String ||
        value['provider'] is! String ||
        value['summary'] is! String) {
      throw const FormatException('Invalid cloud storage profile');
    }
    return CloudStorageProfile(
      id: value['id'],
      name: value['name'],
      provider: value['provider'],
      summary: value['summary'],
      folder: value['folder'] as String? ?? '',
      account: value['account'] as String? ?? '',
      checkedAt: DateTime.tryParse(value['checkedAt'] as String? ?? ''),
      writeTested: value['writeTested'] == true,
    );
  }
}

class CloudTarget {
  const CloudTarget({
    required this.storageId,
    required this.provider,
    required this.fingerprint,
    required this.summary,
  });
  final String storageId, provider, fingerprint, summary;
  Map<String, dynamic> toJson() => {
    'storageId': storageId,
    'provider': provider,
    'fingerprint': fingerprint,
    'summary': summary,
  };
  factory CloudTarget.fromJson(Map<String, dynamic> json) => CloudTarget(
    storageId: json['storageId'] as String,
    provider: json['provider'] as String,
    fingerprint: json['fingerprint'] as String,
    summary: json['summary'] as String,
  );
  bool matches(CloudTarget other) =>
      storageId == other.storageId &&
      provider == other.provider &&
      fingerprint == other.fingerprint;
}

class CloudFileInfo {
  const CloudFileInfo(this.path, this.size, {this.modifiedAt, this.sha256});
  final String path;
  final int size;
  final DateTime? modifiedAt;
  final String? sha256;
}

class CloudConnectionResult {
  const CloudConnectionResult({
    required this.checkedAt,
    required this.writeVerified,
    required this.target,
  });
  final DateTime checkedAt;
  final bool writeVerified;
  final CloudTarget target;
}

class CloudSyncResult {
  const CloudSyncResult({
    required this.at,
    required this.changed,
    required this.fileCount,
    required this.changeNumber,
  });
  final DateTime at;
  final bool changed;
  final int fileCount, changeNumber;
  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'changed': changed,
    'fileCount': fileCount,
    'changeNumber': changeNumber,
  };
}

class CloudBackupLocation {
  const CloudBackupLocation({
    required this.kind,
    required this.accountId,
    required this.sourcePath,
  });
  final String kind;
  final String accountId;
  final String sourcePath;
}
