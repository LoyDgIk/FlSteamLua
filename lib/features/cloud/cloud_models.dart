class CloudStatus {
  const CloudStatus({
    required this.enabled,
    required this.syncPath,
    required this.provider,
    required this.configured,
  });
  final bool enabled;
  final String syncPath;
  final String provider;
  final bool configured;
  bool get remoteSyncConfigured => provider != 'folder' && configured;
}

class CloudPluginStatus {
  const CloudPluginStatus({
    required this.installed,
    required this.enabled,
    required this.path,
    this.size = 0,
    this.modifiedAt,
  });

  final bool installed;
  final bool enabled;
  final String path;
  final int size;
  final DateTime? modifiedAt;
}

class CloudSave {
  const CloudSave({
    required this.appId,
    required this.accountId,
    required this.path,
    this.isRemote = false,
    this.modifiedAt,
    this.fileCount = 0,
    this.size = 0,
  });
  final int appId;
  final String accountId;
  final String path;
  final bool isRemote;
  final DateTime? modifiedAt;
  final int fileCount;
  final int size;
  String get id => '$accountId/$appId';
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
  });
  final int appId;
  final String provider;
  final List<CloudDeleteTarget> targets;
  final String backupDirectory;
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
  });
  final String path;
  final int appId;
  final DateTime createdAt;
  final int fileCount;
  final int size;
}
