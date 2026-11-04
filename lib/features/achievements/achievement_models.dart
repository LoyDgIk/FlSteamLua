class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    this.description = '',
    required this.achieved,
    this.hidden = false,
    this.permission = 0,
    this.unlockedAt,
    this.iconUrl,
    this.lockedIconUrl,
  });

  final String id;
  final String name;
  final String description;
  final bool achieved;
  final bool hidden;
  final int permission;
  final DateTime? unlockedAt;
  final String? iconUrl;
  final String? lockedIconUrl;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    description: json['description'] as String? ?? '',
    achieved: json['achieved'] as bool,
    hidden: json['hidden'] as bool? ?? false,
    permission: json['permission'] as int? ?? 0,
    unlockedAt: json['unlockTime'] is int && json['unlockTime'] > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            (json['unlockTime'] as int) * 1000,
            isUtc: true,
          )
        : null,
    iconUrl: json['iconUrl'] as String?,
    lockedIconUrl: json['lockedIconUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'achieved': achieved,
    'hidden': hidden,
    'permission': permission,
    'unlockTime': unlockedAt == null
        ? 0
        : unlockedAt!.millisecondsSinceEpoch ~/ 1000,
    'iconUrl': iconUrl,
    'lockedIconUrl': lockedIconUrl,
  };
}

enum StatType { integer, floating }

class GameStat {
  const GameStat({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.permission = 0,
    this.minimum,
    this.maximum,
  });
  final String id;
  final String name;
  final StatType type;
  final num value;
  final int permission;
  final num? minimum;
  final num? maximum;

  factory GameStat.fromJson(Map<String, dynamic> json) => GameStat(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    type: json['type'] == 'integer' ? StatType.integer : StatType.floating,
    value: json['value'] as num,
    permission: json['permission'] as int? ?? 0,
    minimum: json['minimum'] as num?,
    maximum: json['maximum'] as num?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'value': value,
    'permission': permission,
    'minimum': minimum,
    'maximum': maximum,
  };
}

class AchievementSnapshot {
  const AchievementSnapshot({
    required this.appId,
    required this.achievements,
    this.stats = const [],
  });
  final int appId;
  final List<Achievement> achievements;
  final List<GameStat> stats;

  factory AchievementSnapshot.fromJson(Map<String, dynamic> json) =>
      AchievementSnapshot(
        appId: json['appId'] as int,
        achievements: (json['achievements'] as List)
            .map(
              (item) =>
                  Achievement.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        stats: (json['stats'] as List? ?? [])
            .map(
              (item) =>
                  GameStat.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'appId': appId,
    'achievements': achievements.map((a) => a.toJson()).toList(),
    'stats': stats.map((s) => s.toJson()).toList(),
  };
}

class SteamTickets {
  const SteamTickets({
    required this.appId,
    required this.steamId,
    required this.appTicketBase64,
    required this.encryptedTicketBase64,
  });
  final int appId;
  final String steamId;
  final String appTicketBase64;
  final String encryptedTicketBase64;

  factory SteamTickets.fromJson(Map<String, dynamic> json) => SteamTickets(
    appId: json['appId'] as int,
    steamId: json['steamId'].toString(),
    appTicketBase64: json['appTicketBase64'] as String,
    encryptedTicketBase64: json['encryptedTicketBase64'] as String,
  );
  Map<String, dynamic> toJson() => {
    'appId': appId,
    'steamId': steamId,
    'appTicketBase64': appTicketBase64,
    'encryptedTicketBase64': encryptedTicketBase64,
  };
}
