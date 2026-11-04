const lanTransferProtocol = 'flsteamlua-lan/4';
const lanTransferPort = 47821;
const lanTransferMulticastAddress = '239.255.42.99';

enum TransferDirection { send, receive }

enum TransferSessionStatus {
  preparing,
  waitingForApproval,
  transferring,
  paused,
  verifying,
  waitingForSteamExit,
  committing,
  completed,
  failed,
  cancelled,
}

class LanPeer {
  const LanPeer({
    required this.id,
    required this.alias,
    required this.address,
    required this.port,
    required this.fingerprint,
    required this.trusted,
    this.lastSeen,
  });

  final String id;
  final String alias;
  final String address;
  final int port;
  final String fingerprint;
  final bool trusted;
  final DateTime? lastSeen;
}

class LanTransferOptionalFile {
  const LanTransferOptionalFile({
    required this.id,
    required this.relativePath,
    required this.size,
    required this.category,
  });

  final String id;
  final String relativePath;
  final int size;
  final String category;

  factory LanTransferOptionalFile.fromJson(Map<String, dynamic> json) =>
      LanTransferOptionalFile(
        id: '${json['id']}',
        relativePath: '${json['relativePath']}',
        size: (json['size'] as num?)?.toInt() ?? 0,
        category: '${json['category']}',
      );
}

class LanTransferPlanSummary {
  const LanTransferPlanSummary({
    required this.planId,
    required this.appId,
    required this.gameName,
    required this.installDir,
    required this.coverUrl,
    required this.luaEnabled,
    required this.manifestAvailable,
    required this.selectedBytes,
    required this.officialBytes,
    required this.manifestBytes,
    required this.optionalBytes,
    required this.officialFiles,
    required this.manifestFiles,
    required this.chunkCount,
    required this.warnings,
    required this.optionalFiles,
  });

  final String planId;
  final int appId;
  final String gameName;
  final String installDir;
  final String? coverUrl;
  final bool luaEnabled;
  final bool manifestAvailable;
  final int selectedBytes;
  final int officialBytes;
  final int manifestBytes;
  final int optionalBytes;
  final int officialFiles;
  final int manifestFiles;
  final int chunkCount;
  final List<String> warnings;
  final List<LanTransferOptionalFile> optionalFiles;

  factory LanTransferPlanSummary.fromJson(
    Map<String, dynamic> json,
  ) => LanTransferPlanSummary(
    planId: '${json['id']}',
    appId: (json['appId'] as num?)?.toInt() ?? 0,
    gameName: '${json['gameName'] ?? ''}',
    installDir: '${json['installDir'] ?? ''}',
    coverUrl: json['coverUrl']?.toString(),
    luaEnabled: json['luaEnabled'] == true,
    manifestAvailable: json['manifestAvailable'] != false,
    selectedBytes: (json['selectedBytes'] as num?)?.toInt() ?? 0,
    officialBytes: (json['officialBytes'] as num?)?.toInt() ?? 0,
    manifestBytes: (json['manifestBytes'] as num?)?.toInt() ?? 0,
    optionalBytes: (json['optionalBytes'] as num?)?.toInt() ?? 0,
    officialFiles: (json['officialFiles'] as num?)?.toInt() ?? 0,
    manifestFiles: (json['manifestFiles'] as num?)?.toInt() ?? 0,
    chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
    warnings: (json['warnings'] as List? ?? const [])
        .map((value) => '$value')
        .toList(growable: false),
    optionalFiles: (json['optionalFiles'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              LanTransferOptionalFile.fromJson(value.cast<String, dynamic>()),
        )
        .toList(growable: false),
  );
}

class LanTransferOffer {
  const LanTransferOffer({
    required this.sessionId,
    required this.bundleId,
    required this.appId,
    required this.gameName,
    required this.installDir,
    required this.coverUrl,
    required this.totalBytes,
    required this.selectedBytes,
    required this.fileCount,
    required this.chunkCount,
    required this.luaEnabled,
    required this.manifestAvailable,
    required this.warnings,
    required this.peer,
    required this.trusted,
    required this.receivedAt,
  });

  final String sessionId;
  final String bundleId;
  final int appId;
  final String gameName;
  final String installDir;
  final String? coverUrl;
  final int totalBytes;
  final int selectedBytes;
  final int fileCount;
  final int chunkCount;
  final bool luaEnabled;
  final bool manifestAvailable;
  final List<String> warnings;
  final LanPeer peer;
  final bool trusted;
  final DateTime receivedAt;

  factory LanTransferOffer.fromJson(Map<String, dynamic> json) {
    final peer = json['peer'] is Map
        ? Map<String, dynamic>.from(json['peer'] as Map)
        : const <String, dynamic>{};
    return LanTransferOffer(
      sessionId: '${json['sessionId']}',
      bundleId: '${json['bundleId']}',
      appId: (json['appId'] as num?)?.toInt() ?? 0,
      gameName: '${json['gameName'] ?? ''}',
      installDir: '${json['installDir'] ?? ''}',
      coverUrl: json['coverUrl']?.toString(),
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      selectedBytes: (json['selectedBytes'] as num?)?.toInt() ?? 0,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
      luaEnabled: json['luaEnabled'] == true,
      manifestAvailable: json['manifestAvailable'] != false,
      warnings: (json['warnings'] as List? ?? const [])
          .map((value) => '$value')
          .toList(growable: false),
      peer: LanTransferPeerJson.fromEngineJson(peer),
      trusted: json['trusted'] == true,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['receivedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class TransferSession {
  TransferSession({
    required this.id,
    required this.bundleId,
    required this.appId,
    required this.gameName,
    required this.direction,
    required this.peer,
    required this.status,
    required this.totalBytes,
    required this.createdAt,
    this.coverUrl,
    this.transferredBytes = 0,
    this.speed = 0,
    this.peakSpeed = 0,
    this.message = '',
    this.error,
    this.targetLibraryRoot,
    this.canPause = false,
    this.totalChunks = 0,
    this.completedChunks = 0,
    this.cachedChunks = 0,
    List<double>? speedSamples,
  }) : speedSamples = List.of(speedSamples ?? const <double>[]);

  final String id;
  final String bundleId;
  final int appId;
  final String gameName;
  final String? coverUrl;
  final TransferDirection direction;
  final LanPeer peer;
  final int totalBytes;
  final DateTime createdAt;
  final String? targetLibraryRoot;
  final bool canPause;
  int totalChunks;
  int completedChunks;
  int cachedChunks;
  TransferSessionStatus status;
  int transferredBytes;
  double speed;
  double peakSpeed;
  String message;
  Object? error;
  final List<double> speedSamples;

  double get progress =>
      totalBytes <= 0 ? 0 : (transferredBytes / totalBytes).clamp(0, 1);
}

extension LanTransferPeerJson on LanPeer {
  static LanPeer fromEngineJson(Map<String, dynamic> json) {
    final lastSeen = (json['lastSeen'] as num?)?.toInt() ?? 0;
    return LanPeer(
      id: '${json['id'] ?? json['fingerprint'] ?? ''}',
      alias: '${json['alias'] ?? json['id'] ?? 'FlSteamLua'}',
      address: '${json['address'] ?? ''}',
      port: (json['port'] as num?)?.toInt() ?? lanTransferPort,
      fingerprint: '${json['fingerprint'] ?? json['id'] ?? ''}',
      trusted: json['trusted'] == true,
      lastSeen: lastSeen == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSeen),
    );
  }
}

TransferSessionStatus transferSessionStatusFromEngine(String value) =>
    switch (value) {
      'preparing' => TransferSessionStatus.preparing,
      'waitingForApproval' => TransferSessionStatus.waitingForApproval,
      'transferring' => TransferSessionStatus.transferring,
      'paused' => TransferSessionStatus.paused,
      'verifying' => TransferSessionStatus.verifying,
      'waitingForSteamExit' => TransferSessionStatus.waitingForSteamExit,
      'committing' => TransferSessionStatus.committing,
      'completed' => TransferSessionStatus.completed,
      'failed' => TransferSessionStatus.failed,
      'cancelled' => TransferSessionStatus.cancelled,
      _ => TransferSessionStatus.preparing,
    };

TransferSession transferSessionFromEngine(Map<String, dynamic> json) {
  final direction = '${json['direction']}' == 'receive'
      ? TransferDirection.receive
      : TransferDirection.send;
  return TransferSession(
    id: '${json['id']}',
    bundleId: '${json['bundleId']}',
    appId: (json['appId'] as num?)?.toInt() ?? 0,
    gameName: '${json['gameName'] ?? ''}',
    coverUrl: json['coverUrl']?.toString(),
    direction: direction,
    peer: LanPeer(
      id: '${json['peerId'] ?? ''}',
      alias: '${json['peerAlias'] ?? ''}',
      address: '${json['peerAddress'] ?? ''}',
      port: lanTransferPort,
      fingerprint: '${json['peerFingerprint'] ?? ''}',
      trusted: false,
    ),
    status: transferSessionStatusFromEngine('${json['status']}'),
    totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((json['createdAt'] as num?)?.toInt() ?? 0) * 1000,
    ),
    transferredBytes: (json['transferredBytes'] as num?)?.toInt() ?? 0,
    speed: (json['speed'] as num?)?.toDouble() ?? 0,
    peakSpeed: (json['peakSpeed'] as num?)?.toDouble() ?? 0,
    message: '${json['message'] ?? ''}',
    error: json['error']?.toString(),
    targetLibraryRoot: json['targetLibrary']?.toString(),
    canPause: json['canPause'] == true,
    totalChunks: (json['totalChunks'] as num?)?.toInt() ?? 0,
    completedChunks: (json['completedChunks'] as num?)?.toInt() ?? 0,
    cachedChunks: (json['cachedChunks'] as num?)?.toInt() ?? 0,
  );
}
