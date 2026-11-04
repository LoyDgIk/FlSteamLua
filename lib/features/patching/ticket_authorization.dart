// Dart adaptation of Fluent-Steam-Lua ticket validation and registry storage.
// Original: Copyright (c) 2024 SteamLuaManager, zlib; modified for FlSteamLua.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:win32_registry/win32_registry.dart';

import '../../core/app_paths.dart';
import '../../platform/windows/dpapi.dart';

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
  void write(int appId, String name, Uint8List? bytes);
}

class WindowsTicketRegistry implements TicketRegistry {
  String _key(int appId) => 'Software\\Valve\\Steam\\Apps\\$appId';

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
  }) : registry = registry ?? WindowsTicketRegistry(),
       _protect = protect ?? WindowsDpapi.protectString,
       _unprotect = unprotect ?? WindowsDpapi.unprotectString;
  final AppPaths paths;
  final TicketRegistry registry;
  final TicketCodec _protect, _unprotect;

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

  void apply(AuthorizationTicket ticket) {
    final previous = registry.read(ticket.appId);
    try {
      registry.write(ticket.appId, 'AppTicket', ticket.appTicket);
      registry.write(ticket.appId, 'ETicket', ticket.eTicket);
      final actual = registry.read(ticket.appId);
      if (!listEquals(actual['AppTicket'], ticket.appTicket) ||
          !listEquals(actual['ETicket'], ticket.eTicket)) {
        throw StateError('Registry verification failed');
      }
    } catch (error, stack) {
      try {
        registry.write(ticket.appId, 'AppTicket', previous['AppTicket']);
        registry.write(ticket.appId, 'ETicket', previous['ETicket']);
      } catch (rollback) {
        throw StateError(
          'Ticket write failed ($error); rollback failed ($rollback)',
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  void removeFromRegistry(int appId) {
    final previous = registry.read(appId);
    try {
      registry.write(appId, 'AppTicket', null);
      registry.write(appId, 'ETicket', null);
    } catch (error, stack) {
      registry.write(appId, 'AppTicket', previous['AppTicket']);
      registry.write(appId, 'ETicket', previous['ETicket']);
      Error.throwWithStackTrace(error, stack);
    }
  }
}
