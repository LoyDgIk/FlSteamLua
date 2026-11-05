enum GameOwnership { unknown, owned, notOwned }

class GameEntry {
  const GameEntry({
    required this.appId,
    required this.name,
    this.installPath,
    this.executablePath,
    this.libraryPath,
    this.luaPath,
    this.luaEnabled = true,
    this.versionPinned = false,
    this.isInstalled = false,
    this.isRunning = false,
    this.isFavorite = false,
    this.ownership = GameOwnership.unknown,
    this.playtimeMinutes,
    this.lastPlayed,
    this.sizeOnDisk = 0,
    this.coverUrl,
  });

  final int appId;
  final String name;
  final String? installPath;
  final String? executablePath;
  final String? libraryPath;
  final String? luaPath;
  final bool luaEnabled;
  final bool versionPinned;
  final bool isInstalled;
  final bool isRunning;
  final bool isFavorite;
  final GameOwnership ownership;
  final int? playtimeMinutes;
  final DateTime? lastPlayed;
  final int sizeOnDisk;
  final String? coverUrl;

  bool get hasLua => luaPath != null;
  String get imageUrl =>
      coverUrl ??
      'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$appId/header.jpg';

  GameEntry copyWith({
    String? name,
    String? installPath,
    String? executablePath,
    String? libraryPath,
    String? luaPath,
    bool? luaEnabled,
    bool? versionPinned,
    bool? isInstalled,
    bool? isRunning,
    bool? isFavorite,
    GameOwnership? ownership,
    int? playtimeMinutes,
    DateTime? lastPlayed,
    int? sizeOnDisk,
    String? coverUrl,
  }) => GameEntry(
    appId: appId,
    name: name ?? this.name,
    installPath: installPath ?? this.installPath,
    executablePath: executablePath ?? this.executablePath,
    libraryPath: libraryPath ?? this.libraryPath,
    luaPath: luaPath ?? this.luaPath,
    luaEnabled: luaEnabled ?? this.luaEnabled,
    versionPinned: versionPinned ?? this.versionPinned,
    isInstalled: isInstalled ?? this.isInstalled,
    isRunning: isRunning ?? this.isRunning,
    isFavorite: isFavorite ?? this.isFavorite,
    ownership: ownership ?? this.ownership,
    playtimeMinutes: playtimeMinutes ?? this.playtimeMinutes,
    lastPlayed: lastPlayed ?? this.lastPlayed,
    sizeOnDisk: sizeOnDisk ?? this.sizeOnDisk,
    coverUrl: coverUrl ?? this.coverUrl,
  );
}
