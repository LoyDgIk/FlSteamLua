// Altered C ABI adaptation of the SAM.API interface layout.
// Upstream zlib attribution is retained in native/steam_bridge/LICENSE-SAM.txt.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'achievement_models.dart';
import 'binary_stats_schema.dart';

typedef _ContextIntNative = Int32 Function(Pointer<Void>);
typedef _ContextIntDart = int Function(Pointer<Void>);
typedef _StateNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Uint8>,
      Pointer<Uint32>,
    );
typedef _StateDart =
    int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, Pointer<Uint32>);

class NativeSteam {
  NativeSteam({required this.steamPath, required this.appId, String? library})
    : _dll = DynamicLibrary.open(
        library ??
            p.join(p.dirname(Platform.resolvedExecutable), 'steam_bridge.dll'),
      ) {
    final path = steamPath.toNativeUtf16();
    try {
      _context = _dll
          .lookupFunction<
            Pointer<Void> Function(Pointer<Utf16>, Uint32),
            Pointer<Void> Function(Pointer<Utf16>, int)
          >('sb_open')(path, appId);
      if (_context == nullptr) throw StateError(lastError);
    } finally {
      calloc.free(path);
    }
  }

  final String steamPath;
  final int appId;
  final DynamicLibrary _dll;
  Pointer<Void> _context = nullptr;

  String get lastError {
    final text = _dll
        .lookupFunction<
          Pointer<Utf8> Function(Pointer<Void>),
          Pointer<Utf8> Function(Pointer<Void>)
        >('sb_error')(_context);
    return text == nullptr
        ? 'Steam client operation failed'
        : text.toDartString();
  }

  int _int(String name) =>
      _dll.lookupFunction<_ContextIntNative, _ContextIntDart>(name)(_context);
  void _check(int result) {
    if (result <= 0) throw StateError(lastError);
  }

  void _pump() =>
      _dll.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('sb_pump')(_context);

  Future<void> _wait(String name) async {
    final watch = Stopwatch()..start();
    while (watch.elapsed < const Duration(seconds: 20)) {
      _pump();
      final state = _int(name);
      if (state == 1) return;
      if (state < 0) throw StateError(lastError);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('Steam did not respond within 20 seconds');
  }

  Future<void> requestStats() async {
    _check(_int('sb_request_stats'));
    await _wait('sb_stats_ready');
  }

  String _attribute(String id, String key) {
    final idPtr = id.toNativeUtf8();
    final keyPtr = key.toNativeUtf8();
    try {
      final value = _dll
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>),
            Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)
          >('sb_achievement_attribute')(_context, idPtr, keyPtr);
      return value == nullptr ? '' : value.toDartString();
    } finally {
      calloc.free(idPtr);
      calloc.free(keyPtr);
    }
  }

  Future<AchievementSnapshot> load({String language = 'english'}) async {
    await requestStats();
    final schemaFile = File(
      p.join(steamPath, 'appcache', 'stats', 'UserGameStatsSchema_$appId.bin'),
    );
    BinaryStatsSchema? schema;
    if (await schemaFile.exists()) {
      schema = BinaryStatsSchema.decode(await schemaFile.readAsBytes());
    }
    final definitions = schema?.achievementDefinitions(appId) ?? {};
    final count = _dll
        .lookupFunction<
          Uint32 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('sb_achievement_count')(_context);
    if (count > 100000) {
      throw const FormatException('Invalid Steam achievement count');
    }
    final achievements = <Achievement>[];
    final achieved = calloc<Uint8>();
    final unlockTime = calloc<Uint32>();
    try {
      final getName = _dll
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>, Uint32),
            Pointer<Utf8> Function(Pointer<Void>, int)
          >('sb_achievement_name');
      final getState = _dll.lookupFunction<_StateNative, _StateDart>(
        'sb_achievement_state',
      );
      for (var i = 0; i < count; i++) {
        final nativeName = getName(_context, i);
        if (nativeName == nullptr) {
          throw StateError('Steam returned an invalid achievement name');
        }
        final id = nativeName.toDartString();
        _check(getState(_context, nativeName, achieved, unlockTime));
        final definition = definitions[id] ?? {};
        final display = definition['display'] is Map
            ? Map<String, dynamic>.from(definition['display'] as Map)
            : <String, dynamic>{};
        final name = BinaryStatsSchema.localized(
          display['name'],
          language,
          _attribute(id, 'name'),
        );
        achievements.add(
          Achievement(
            id: id,
            name: name.isEmpty ? id : name,
            description: BinaryStatsSchema.localized(
              display['desc'],
              language,
              _attribute(id, 'desc'),
            ),
            achieved: achieved.value != 0,
            hidden: _attribute(id, 'hidden') == '1',
            permission: _number(definition['permission'])?.toInt() ?? 0,
            unlockedAt: unlockTime.value == 0
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    unlockTime.value * 1000,
                    isUtc: true,
                  ),
            iconUrl: _icon(display['icon']),
            lockedIconUrl: _icon(display['icon_gray']),
          ),
        );
      }
    } finally {
      calloc.free(achieved);
      calloc.free(unlockTime);
    }
    final stats = <GameStat>[];
    for (final entry in (schema?.stats(appId) ?? {}).entries) {
      if (entry.value is! Map) continue;
      final value = Map<String, dynamic>.from(entry.value as Map);
      final rawType = value['type_int'] ?? value['type'];
      final type = rawType.toString().toLowerCase();
      if (![
        '1',
        '2',
        '3',
        'int',
        'integer',
        'float',
        'averagerate',
      ].contains(type)) {
        continue;
      }
      final id = value['name'];
      if (id is! String || id.isEmpty) continue;
      final integer = ['1', 'int', 'integer'].contains(type);
      final nativeId = id.toNativeUtf8();
      num current;
      try {
        if (integer) {
          final output = calloc<Int32>();
          try {
            final ok = _dll
                .lookupFunction<
                  Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Int32>),
                  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Int32>)
                >('sb_get_stat_int')(_context, nativeId, output);
            if (ok == 0) continue;
            current = output.value;
          } finally {
            calloc.free(output);
          }
        } else {
          final output = calloc<Float>();
          try {
            final ok = _dll
                .lookupFunction<
                  Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Float>),
                  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Float>)
                >('sb_get_stat_float')(_context, nativeId, output);
            if (ok == 0) continue;
            current = output.value;
          } finally {
            calloc.free(output);
          }
        }
      } finally {
        calloc.free(nativeId);
      }
      stats.add(
        GameStat(
          id: id,
          name: BinaryStatsSchema.localized(value['display'], language, id),
          type: integer ? StatType.integer : StatType.floating,
          value: current,
          permission: _number(value['permission'])?.toInt() ?? 0,
          minimum: _number(value['min']),
          maximum: _number(value['max']),
        ),
      );
    }
    return AchievementSnapshot(
      appId: appId,
      achievements: achievements,
      stats: stats,
    );
  }

  num? _number(dynamic value) => value is num ? value : num.tryParse('$value');
  String? _icon(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    if (value.startsWith('https://')) return value;
    return 'https://cdn.fastly.steamstatic.com/steamcommunity/public/images/apps/$appId/$value';
  }

  Future<void> save(
    Map<String, bool> achievements,
    Map<String, num> stats,
  ) async {
    // Validate every requested name/type before changing Steam's local cache.
    final snapshot = await load();
    final knownAchievements = snapshot.achievements.map((a) => a.id).toSet();
    final knownStats = {for (final s in snapshot.stats) s.id: s};
    for (final id in achievements.keys) {
      if (!knownAchievements.contains(id)) {
        throw FormatException('Unknown achievement: $id');
      }
    }
    for (final change in stats.entries) {
      final definition = knownStats[change.key];
      if (definition == null ||
          !change.value.isFinite ||
          (definition.type == StatType.floating &&
              change.value.abs() > 3.4028234663852886e38) ||
          (definition.type == StatType.integer &&
              (change.value != change.value.round() ||
                  change.value < -2147483648 ||
                  change.value > 2147483647)) ||
          (definition.minimum != null && change.value < definition.minimum!) ||
          (definition.maximum != null && change.value > definition.maximum!)) {
        throw FormatException('Invalid statistic: ${change.key}');
      }
    }
    for (final change in achievements.entries) {
      final id = change.key.toNativeUtf8();
      try {
        _check(
          _dll.lookupFunction<
            Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32),
            int Function(Pointer<Void>, Pointer<Utf8>, int)
          >('sb_set_achievement')(_context, id, change.value ? 1 : 0),
        );
      } finally {
        calloc.free(id);
      }
    }
    for (final change in stats.entries) {
      final id = change.key.toNativeUtf8();
      try {
        if (knownStats[change.key]!.type == StatType.integer) {
          _check(
            _dll.lookupFunction<
              Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32),
              int Function(Pointer<Void>, Pointer<Utf8>, int)
            >('sb_set_stat_int')(_context, id, change.value.toInt()),
          );
        } else {
          _check(
            _dll.lookupFunction<
              Int32 Function(Pointer<Void>, Pointer<Utf8>, Float),
              int Function(Pointer<Void>, Pointer<Utf8>, double)
            >('sb_set_stat_float')(_context, id, change.value.toDouble()),
          );
        }
      } finally {
        calloc.free(id);
      }
    }
    _check(_int('sb_store_stats'));
    await _wait('sb_store_result');
  }

  Future<SteamTickets> tickets() async {
    final buffer = calloc<Uint8>(16384);
    final steamId = calloc<Uint64>();
    try {
      final length = _dll
          .lookupFunction<
            Int32 Function(
              Pointer<Void>,
              Pointer<Uint8>,
              Uint32,
              Pointer<Uint64>,
            ),
            int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint64>)
          >('sb_app_ticket')(_context, buffer, 16384, steamId);
      _check(length);
      final appTicket = base64Encode(buffer.asTypedList(length));
      final call = _dll
          .lookupFunction<
            Uint64 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('sb_request_encrypted_ticket')(_context);
      if (call == 0) throw StateError(lastError);
      final watch = Stopwatch()..start();
      while (watch.elapsed < const Duration(seconds: 20)) {
        _pump();
        final ticketLength = _dll
            .lookupFunction<
              Int32 Function(Pointer<Void>, Uint64, Pointer<Uint8>, Uint32),
              int Function(Pointer<Void>, int, Pointer<Uint8>, int)
            >('sb_encrypted_ticket')(_context, call, buffer, 16384);
        if (ticketLength < 0) throw StateError(lastError);
        if (ticketLength > 0) {
          return SteamTickets(
            appId: appId,
            steamId: steamId.value.toString(),
            appTicketBase64: appTicket,
            encryptedTicketBase64: base64Encode(
              buffer.asTypedList(ticketLength),
            ),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      throw StateError('Steam encrypted ticket request timed out');
    } finally {
      buffer.asTypedList(16384).fillRange(0, 16384, 0);
      calloc.free(buffer);
      calloc.free(steamId);
    }
  }

  void close() {
    if (_context == nullptr) return;
    _dll.lookupFunction<
      Void Function(Pointer<Void>),
      void Function(Pointer<Void>)
    >('sb_close')(_context);
    _context = nullptr;
  }
}
