// Functional reference: Fluent-Steam-Lua KeyCacheSubscriptionService.
// Its zlib notice is retained in assets/licenses/Fluent-Steam-Lua-zlib.txt.
class KeyCacheSubscription {
  const KeyCacheSubscription({
    required this.id,
    required this.name,
    required this.depotKeysUrl,
    required this.tokenKeysUrl,
    this.intervalHours = 24,
    this.enabled = true,
    this.lastUpdated,
    this.depotCount = 0,
    this.tokenCount = 0,
  });

  final String id;
  final String name;
  final String depotKeysUrl;
  final String tokenKeysUrl;
  final int intervalHours;
  final bool enabled;
  final DateTime? lastUpdated;
  final int depotCount;
  final int tokenCount;

  KeyCacheSubscription copyWith({
    String? name,
    String? depotKeysUrl,
    String? tokenKeysUrl,
    int? intervalHours,
    bool? enabled,
    DateTime? lastUpdated,
    int? depotCount,
    int? tokenCount,
  }) => KeyCacheSubscription(
    id: id,
    name: name ?? this.name,
    depotKeysUrl: depotKeysUrl ?? this.depotKeysUrl,
    tokenKeysUrl: tokenKeysUrl ?? this.tokenKeysUrl,
    intervalHours: intervalHours ?? this.intervalHours,
    enabled: enabled ?? this.enabled,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    depotCount: depotCount ?? this.depotCount,
    tokenCount: tokenCount ?? this.tokenCount,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'depotKeysUrl': depotKeysUrl,
    'tokenKeysUrl': tokenKeysUrl,
    'intervalHours': intervalHours,
    'enabled': enabled,
    'lastUpdated': lastUpdated?.toUtc().toIso8601String(),
    'depotCount': depotCount,
    'tokenCount': tokenCount,
  };

  factory KeyCacheSubscription.fromJson(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        data['name'] is! String ||
        data['depotKeysUrl'] is! String ||
        data['tokenKeysUrl'] is! String ||
        data['intervalHours'] is! int ||
        data['enabled'] is! bool ||
        data['depotCount'] is! int ||
        data['tokenCount'] is! int ||
        (data['lastUpdated'] != null && data['lastUpdated'] is! String)) {
      throw const FormatException('Invalid key cache subscription');
    }
    final stamp = data['lastUpdated'] as String?;
    return KeyCacheSubscription(
      id: data['id'] as String,
      name: data['name'] as String,
      depotKeysUrl: data['depotKeysUrl'] as String,
      tokenKeysUrl: data['tokenKeysUrl'] as String,
      intervalHours: data['intervalHours'] as int,
      enabled: data['enabled'] as bool,
      lastUpdated: stamp == null ? null : DateTime.parse(stamp),
      depotCount: data['depotCount'] as int,
      tokenCount: data['tokenCount'] as int,
    );
  }
}

class KeyCacheData {
  const KeyCacheData({this.depotKeys = const {}, this.appTokens = const {}});
  final Map<int, String> depotKeys;
  final Map<int, String> appTokens;
}

class KeyCacheLuaPreview {
  const KeyCacheLuaPreview({
    required this.appId,
    required this.name,
    required this.lua,
    required this.sourceName,
    required this.missingDepotIds,
    required this.skippedDlcIds,
    required this.dlcIds,
  });
  final int appId;
  final String name;
  final String lua;
  final String sourceName;
  final List<int> missingDepotIds;
  final List<int> skippedDlcIds;
  final List<int> dlcIds;
}
