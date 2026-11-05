// Dart adaptation of Fluent-Steam-Lua ticket validation and registry storage.
// Original: Copyright (c) 2024 SteamLuaManager, zlib; modified for FlSteamLua.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:win32_registry/win32_registry.dart';

import '../../core/app_paths.dart';
import '../../platform/windows/dpapi.dart';
import 'ticket_lua_cleanup.dart';
export 'ticket_lua_cleanup.dart';

class AuthorizationTicket {
  const AuthorizationTicket({
    required this.appId,
    required this.steamId,
    required this.appTicket,
    required this.eTicket,
  });
  final int appId;
  final BigInt steamId;
  final Uint8List appTicket, eTicket;

  String exportText() =>
      'appid: $appId\nappticket (${appTicket.length} bytes): ${_hex(appTicket)}\neticket (${eTicket.length} bytes): ${_hex(eTicket)}\n';

  static AuthorizationTicket parse(String text) {
    if (utf8.encode(text).length > 2 * 1024 * 1024) {
      throw const FormatException('Ticket file exceeds 2 MiB');
    }
    var normalizedText = text.replaceFirst(RegExp(r'^\uFEFF'), '');
    normalizedText = normalizedText.replaceFirst(
      RegExp(
        r'^\s*(?:Extracted by|由)\s*FlSteamLua[^\r\n]*(?:\r?\n|$)',
        caseSensitive: false,
      ),
      '',
    );
    int? appId;
    Uint8List? app, encrypted;
    for (final raw in const LineSplitter().convert(normalizedText)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      final idMatch = RegExp(
        r'^appid\s*:\s*(\d+)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (idMatch != null) {
        if (appId != null) throw const FormatException('Duplicate AppID');
        appId = int.tryParse(idMatch[1]!);
        if (appId == null || appId <= 0 || appId > 0xffffffff) {
          throw const FormatException('Invalid AppID');
        }
        continue;
      }
      final match = RegExp(
        r'^(appticket|eticket)\s*\(\s*(\d+)\s*bytes\s*\)\s*:\s*([0-9a-f]+)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) {
        throw const FormatException('Unrecognized ticket file line');
      }
      final hex = match[3]!;
      if (hex.length.isOdd) {
        throw const FormatException('Ticket hex length must be even');
      }
      final bytes = Uint8List.fromList([
        for (var offset = 0; offset < hex.length; offset += 2)
          int.parse(hex.substring(offset, offset + 2), radix: 16),
      ]);
      if (bytes.length != int.tryParse(match[2]!)) {
        throw const FormatException(
          'Ticket byte count does not match declaration',
        );
      }
      if (match[1]!.toLowerCase() == 'appticket') {
        if (app != null) throw const FormatException('Duplicate AppTicket');
        app = bytes;
      } else {
        if (encrypted != null) throw const FormatException('Duplicate ETicket');
        encrypted = bytes;
      }
    }
    if (appId == null || app == null || encrypted == null) {
      throw const FormatException(
        'Ticket file requires AppID, AppTicket and ETicket',
      );
    }
    if (app.length < 20 || encrypted.isEmpty) {
      throw const FormatException('Ticket payload is too short');
    }
    final data = ByteData.sublistView(app);
    var embedded = false;
    for (var offset = 0; offset + 4 <= app.length; offset += 4) {
      if (data.getUint32(offset, Endian.little) == appId) {
        embedded = true;
        break;
      }
    }
    if (!embedded) {
      throw const FormatException(
        'AppTicket does not contain the declared AppID',
      );
    }
    final steamId =
        BigInt.from(data.getUint32(8, Endian.little)) |
        (BigInt.from(data.getUint32(12, Endian.little)) << 32);
    if (steamId == BigInt.zero) {
      throw const FormatException('AppTicket does not contain a SteamID');
    }
    return AuthorizationTicket(
      appId: appId,
      steamId: steamId,
      appTicket: app,
      eTicket: encrypted,
    );
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

abstract interface class TicketRegistry {
  Map<String, Uint8List?> read(int appId);
  String? readSteamId(int appId);
  void writeSteamId(int appId, String? value);
  void write(int appId, String name, Uint8List? bytes);
}

class WindowsTicketRegistry implements TicketRegistry {
  String _key(int appId) => 'Software\\Valve\\Steam\\Apps\\$appId';

  static String? activeSteamId() {
    if (!Platform.isWindows) return null;
    final root = Registry.currentUser;
    try {
      final value = root.getValue(
        'ActiveUser',
        path: r'Software\Valve\Steam\ActiveProcess',
      );
      if (value is! Int32Value || value.value == 0) return null;
      final universe = root.getValue(
        'Universe',
        path: r'Software\Valve\Steam\ActiveProcess',
      );
      if (universe is StringValue && universe.value != 'Public') return null;
      return (BigInt.from(76561197960265728) +
              BigInt.from(value.value & 0xffffffff))
          .toString();
    } finally {
      root.close();
    }
  }

  @override
  String? readSteamId(int appId) {
    final root = Registry.currentUser;
    try {
      final value = root.getValue('SteamID', path: _key(appId));
      if (value == null) return null;
      if (value is! StringValue) {
        throw const FormatException('SteamID registry value must be text');
      }
      return value.value;
    } finally {
      root.close();
    }
  }

  @override
  void writeSteamId(int appId, String? value) {
    final root = Registry.currentUser;
    final key = root.createKey(_key(appId));
    try {
      if (value == null) {
        if (key.getValue('SteamID') != null) key.deleteValue('SteamID');
      } else {
        key.createValue(RegistryValue.string('SteamID', value));
      }
    } finally {
      key.close();
      root.close();
    }
  }

  @override
  Map<String, Uint8List?> read(int appId) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Steam ticket registry requires Windows');
    }
    final root = Registry.currentUser;
    try {
      return {
        'AppTicket': _binary(root.getValue('AppTicket', path: _key(appId))),
        'ETicket': _binary(root.getValue('ETicket', path: _key(appId))),
      };
    } finally {
      root.close();
    }
  }

  Uint8List? _binary(RegistryValue? value) {
    if (value == null) return null;
    if (value is! BinaryValue) {
      throw const FormatException('Existing Steam ticket value is not binary');
    }
    return value.value;
  }

  @override
  void write(int appId, String name, Uint8List? bytes) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Steam ticket registry requires Windows');
    }
    final root = Registry.currentUser;
    final key = root.createKey(_key(appId));
    try {
      if (bytes != null) {
        key.createValue(RegistryValue.binary(name, bytes));
      } else if (key.getValue(name) != null) {
        key.deleteValue(name);
      }
    } finally {
      key.close();
      root.close();
    }
  }
}

typedef TicketCodec = String Function(String value);

class TicketAuthorizationStore {
  TicketAuthorizationStore({
    required this.paths,
    TicketRegistry? registry,
    TicketCodec? protect,
    TicketCodec? unprotect,
    Future<void> Function(File, List<int>)? fileWriter,
  }) : registry = registry ?? WindowsTicketRegistry(),
       _protect = protect ?? WindowsDpapi.protectString,
       _unprotect = unprotect ?? WindowsDpapi.unprotectString,
       _writeFile = fileWriter ?? _atomicWrite;
  final AppPaths paths;
  final TicketRegistry registry;
  final TicketCodec _protect, _unprotect;
  final Future<void> Function(File, List<int>) _writeFile;
  bool _mutating = false;

  Future<void> save(AuthorizationTicket ticket) async {
    final file = File(
      paths.file(p.join('data', 'tickets', '${ticket.appId}.json')),
    );
    await file.parent.create(recursive: true);
    final encrypted = _protect(ticket.exportText());
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'appId': ticket.appId,
        'steamId': ticket.steamId.toString(),
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': encrypted,
      }),
      flush: true,
    );
  }

  Future<List<int>> list() async {
    final directory = paths.directory(p.join('data', 'tickets'));
    if (!await directory.exists()) return [];
    final result = <int>[];
    await for (final file in directory.list()) {
      if (file is! File || p.extension(file.path) != '.json') continue;
      final appId = int.tryParse(p.basenameWithoutExtension(file.path));
      if (appId != null) result.add(appId);
    }
    return result..sort();
  }

  Future<AuthorizationTicket> load(int appId) async {
    final json = jsonDecode(
      await File(
        paths.file(p.join('data', 'tickets', '$appId.json')),
      ).readAsString(),
    );
    if (json is! Map || json['appId'] != appId || json['payload'] is! String) {
      throw const FormatException('Invalid saved ticket');
    }
    return AuthorizationTicket.parse(_unprotect(json['payload'] as String));
  }

  Future<void> delete(int appId) =>
      File(paths.file(p.join('data', 'tickets', '$appId.json'))).delete();

  TicketCredentials credentials(int appId) {
    final tickets = registry.read(appId);
    return TicketCredentials(
      appTicket: tickets['AppTicket'] == null
          ? null
          : Uint8List.fromList(tickets['AppTicket']!),
      eTicket: tickets['ETicket'] == null
          ? null
          : Uint8List.fromList(tickets['ETicket']!),
      steamId: registry.readSteamId(appId),
    );
  }

  Future<TicketApplyPlan> prepare(
    AuthorizationTicket ticket, {
    List<String> luaPaths = const [],
  }) async {
    final before = credentials(ticket.appId);
    final lua = <TicketLuaCleanup>[];
    for (final path in luaPaths.toSet()) {
      if (!await File(path).exists()) continue;
      final cleanup = await TicketLuaCleanup.read(path, ticket.appId);
      if (cleanup.statements.isNotEmpty) lua.add(cleanup);
    }
    return TicketApplyPlan(
      ticket: ticket,
      before: before,
      lua: List.unmodifiable(lua),
    );
  }

  Future<TicketApplyResult> apply(
    AuthorizationTicket ticket, {
    bool synchronizeIdentity = false,
    TicketApplyPlan? plan,
  }) => _exclusive(() async {
    final ready = plan ?? await prepare(ticket);
    if (ready.ticket.appId != ticket.appId ||
        !ready.before.matches(credentials(ticket.appId))) {
      throw const TicketOperationException(TicketOperationFailure.stalePreview);
    }
    await _checkLua(ready.lua, original: true);
    final backup = await _backup(
      ticket.appId,
      ready.before,
      ready.lua,
      'apply',
    );
    final next = TicketCredentials(
      appTicket: ticket.appTicket,
      eTicket: ticket.eTicket,
      steamId: synchronizeIdentity
          ? ticket.steamId.toString()
          : ready.before.steamId,
    );
    await _replace(
      ticket.appId,
      ready.before,
      next,
      ready.lua,
      modifyIdentity: synchronizeIdentity,
    );
    return TicketApplyResult(
      backup: backup,
      credentials: next,
      identityMismatch: next.identityMismatch(ticket.steamId),
    );
  });

  Future<List<TicketCredentialBackup>> credentialBackups({int? appId}) async {
    final root = paths.directory('backups/tickets');
    if (!await root.exists()) return [];
    final backups = <TicketCredentialBackup>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      final value = jsonDecode(await entity.readAsString(encoding: utf8));
      if (value is! Map ||
          value['appId'] is! int ||
          value['createdAt'] is! String) {
        throw const TicketOperationException(
          TicketOperationFailure.invalidBackup,
        );
      }
      if (appId != null && value['appId'] != appId) continue;
      backups.add(
        TicketCredentialBackup(
          path: entity.path,
          appId: value['appId'] as int,
          createdAt: DateTime.parse(value['createdAt'] as String),
        ),
      );
    }
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<TicketRestorePlan> prepareRestore(
    TicketCredentialBackup backup,
  ) async {
    final outer = jsonDecode(
      await File(backup.path).readAsString(encoding: utf8),
    );
    if (outer is! Map ||
        outer['version'] != 1 ||
        outer['appId'] != backup.appId ||
        outer['payload'] is! String) {
      throw const TicketOperationException(
        TicketOperationFailure.invalidBackup,
      );
    }
    final data = jsonDecode(_unprotect(outer['payload'] as String));
    if (data is! Map ||
        data['appId'] != backup.appId ||
        data['lua'] is! List ||
        data['credentials'] is! Map) {
      throw const TicketOperationException(
        TicketOperationFailure.invalidBackup,
      );
    }
    final target = TicketCredentials.fromJson(data['credentials'] as Map);
    final lua = <TicketLuaCleanup>[];
    for (final raw in data['lua'] as List) {
      if (raw is! Map ||
          raw['path'] is! String ||
          raw['original'] is! String ||
          raw['appliedSha256'] is! String) {
        throw const TicketOperationException(
          TicketOperationFailure.invalidBackup,
        );
      }
      final path = raw['path'] as String;
      if (!p.isAbsolute(path) || p.extension(path).toLowerCase() != '.lua') {
        throw const TicketOperationException(
          TicketOperationFailure.invalidBackup,
        );
      }
      final current = await File(path).readAsBytes();
      final original = base64Decode(raw['original'] as String);
      if (!listEquals(current, original) &&
          sha256.convert(current).toString() != raw['appliedSha256']) {
        throw const TicketOperationException(TicketOperationFailure.luaChanged);
      }
      lua.add(
        TicketLuaCleanup(
          path: path,
          original: current,
          updated: original,
          statements: const [],
        ),
      );
    }
    return TicketRestorePlan(
      backup: backup,
      before: credentials(backup.appId),
      target: target,
      lua: lua,
    );
  }

  Future<void> restoreCredentials(TicketRestorePlan plan) =>
      _exclusive(() async {
        final appId = plan.backup.appId;
        if (!plan.before.matches(credentials(appId))) {
          throw const TicketOperationException(
            TicketOperationFailure.stalePreview,
          );
        }
        await _checkLua(plan.lua, original: true);
        // Restoring is reversible as a complete set too.
        await _backup(appId, plan.before, plan.lua, 'restore');
        await _replace(
          appId,
          plan.before,
          plan.target,
          plan.lua,
          modifyIdentity: true,
        );
      });

  Future<TicketCredentialBackup> _backup(
    int appId,
    TicketCredentials before,
    List<TicketLuaCleanup> lua,
    String operation,
  ) async {
    final now = DateTime.now().toUtc();
    final file = File(
      paths.file('backups/tickets/$appId/${now.microsecondsSinceEpoch}.json'),
    );
    final payload = _protect(
      jsonEncode({
        'appId': appId,
        'credentials': before.toJson(),
        'lua': [
          for (final edit in lua)
            {
              'path': edit.path,
              'original': base64Encode(edit.original),
              'appliedSha256': sha256.convert(edit.updated).toString(),
            },
        ],
      }),
    );
    await _atomicWrite(
      file,
      utf8.encode(
        jsonEncode({
          'version': 1,
          'appId': appId,
          'createdAt': now.toIso8601String(),
          'operation': operation,
          'payload': payload,
        }),
      ),
    );
    return TicketCredentialBackup(
      path: file.path,
      appId: appId,
      createdAt: now,
    );
  }

  Future<void> _checkLua(
    List<TicketLuaCleanup> edits, {
    required bool original,
  }) async {
    for (final edit in edits) {
      final file = File(edit.path);
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          !listEquals(
            await file.readAsBytes(),
            original ? edit.original : edit.updated,
          )) {
        throw const TicketOperationException(TicketOperationFailure.luaChanged);
      }
    }
  }

  Future<void> _replace(
    int appId,
    TicketCredentials before,
    TicketCredentials next,
    List<TicketLuaCleanup> lua, {
    required bool modifyIdentity,
  }) async {
    final undo = <Future<void> Function()>[];
    try {
      for (final edit in lua) {
        undo.add(() => _atomicWrite(File(edit.path), edit.original));
        await _writeFile(File(edit.path), edit.updated);
      }
      undo.add(
        () async => registry.write(appId, 'AppTicket', before.appTicket),
      );
      registry.write(appId, 'AppTicket', next.appTicket);
      undo.add(() async => registry.write(appId, 'ETicket', before.eTicket));
      registry.write(appId, 'ETicket', next.eTicket);
      if (modifyIdentity) {
        undo.add(() async => registry.writeSteamId(appId, before.steamId));
        registry.writeSteamId(appId, next.steamId);
      }
      if (!next.matches(credentials(appId))) {
        throw const TicketOperationException(
          TicketOperationFailure.verification,
        );
      }
      await _checkLua(lua, original: false);
    } catch (error, stack) {
      var failed = false;
      for (final action in undo.reversed) {
        try {
          await action();
        } catch (_) {
          failed = true;
        }
      }
      if (failed || !before.matches(credentials(appId))) {
        throw const TicketOperationException(TicketOperationFailure.rollback);
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_mutating) {
      throw const TicketOperationException(TicketOperationFailure.busy);
    }
    _mutating = true;
    try {
      return await action();
    } finally {
      _mutating = false;
    }
  }

  static Future<void> _atomicWrite(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.$pid.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}

class TicketCredentials {
  const TicketCredentials({this.appTicket, this.eTicket, this.steamId});
  final Uint8List? appTicket, eTicket;
  final String? steamId;

  BigInt? get effectiveSteamId {
    final id = BigInt.tryParse(steamId ?? '');
    return id != null && id > BigInt.zero && id < (BigInt.one << 64)
        ? id
        : null;
  }

  bool identityMismatch(BigInt ticketId) =>
      effectiveSteamId != null && effectiveSteamId != ticketId;
  bool matches(TicketCredentials other) =>
      listEquals(appTicket, other.appTicket) &&
      listEquals(eTicket, other.eTicket) &&
      steamId == other.steamId;
  Map<String, Object?> toJson() => {
    'AppTicket': appTicket == null ? null : base64Encode(appTicket!),
    'ETicket': eTicket == null ? null : base64Encode(eTicket!),
    'SteamID': steamId,
  };
  factory TicketCredentials.fromJson(Map value) {
    if (!['AppTicket', 'ETicket', 'SteamID'].every(
      (key) =>
          value.containsKey(key) &&
          (value[key] == null || value[key] is String),
    )) {
      throw const TicketOperationException(
        TicketOperationFailure.invalidBackup,
      );
    }
    return TicketCredentials(
      appTicket: value['AppTicket'] == null
          ? null
          : base64Decode(value['AppTicket'] as String),
      eTicket: value['ETicket'] == null
          ? null
          : base64Decode(value['ETicket'] as String),
      steamId: value['SteamID'] as String?,
    );
  }
}

class TicketApplyPlan {
  const TicketApplyPlan({
    required this.ticket,
    required this.before,
    required this.lua,
  });
  final AuthorizationTicket ticket;
  final TicketCredentials before;
  final List<TicketLuaCleanup> lua;
}

class TicketCredentialBackup {
  const TicketCredentialBackup({
    required this.path,
    required this.appId,
    required this.createdAt,
  });
  final String path;
  final int appId;
  final DateTime createdAt;
}

class TicketRestorePlan {
  const TicketRestorePlan({
    required this.backup,
    required this.before,
    required this.target,
    required this.lua,
  });
  final TicketCredentialBackup backup;
  final TicketCredentials before, target;
  final List<TicketLuaCleanup> lua;
}

class TicketApplyResult {
  const TicketApplyResult({
    required this.backup,
    required this.credentials,
    required this.identityMismatch,
  });
  final TicketCredentialBackup backup;
  final TicketCredentials credentials;
  final bool identityMismatch;
}

enum TicketOperationFailure {
  busy,
  stalePreview,
  luaChanged,
  invalidBackup,
  verification,
  rollback,
}

class TicketOperationException implements Exception {
  const TicketOperationException(this.failure);
  final TicketOperationFailure failure;
  @override
  String toString() => 'Ticket credentials: ${failure.name}';
}
