// Functional adaptation of Fluent-Steam-Lua DlcAnalysisService (zlib).
// The source notice is retained in assets/licenses/Fluent-Steam-Lua-zlib.txt.
import '../library/lua_directories.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../key_cache/key_cache_service.dart';
import '../steam_protocol/steam_protocol_service.dart';

enum DlcDepotKind { unknown, noDepot, singleDepot, multiDepot, inMainDepot }

class DlcSuggestion {
  const DlcSuggestion(this.id, this.line);
  final String id;
  final String line;
}

class DlcAnalysisItem {
  const DlcAnalysisItem({
    required this.appId,
    required this.name,
    required this.kind,
    required this.depotIds,
    required this.isConfigured,
    required this.suggestions,
    required this.missingKeys,
    this.error,
  });
  final int appId;
  final String name;
  final DlcDepotKind kind;
  final List<int> depotIds;
  // Lua configuration is deliberately independent of Steam account ownership.
  final bool isConfigured;
  final List<DlcSuggestion> suggestions;
  final List<int> missingKeys;
  final String? error;
}

class DlcAnalysisResult {
  const DlcAnalysisResult({
    required this.appId,
    required this.name,
    required this.mainDepotCount,
    required this.items,
    required this.warnings,
    this.luaPath,
    this.luaDigest,
  });
  final int appId;
  final String name;
  final int mainDepotCount;
  final List<DlcAnalysisItem> items;
  final List<String> warnings;
  final String? luaPath;
  final String? luaDigest;

  List<DlcSuggestion> selectedSuggestions(Set<int> selected) {
    final emitted = <String>{};
    return [
      for (final item in items)
        if (selected.contains(item.appId))
          for (final suggestion in item.suggestions)
            if (emitted.add(suggestion.id)) suggestion,
    ];
  }

  String preview(Set<int> selected) =>
      selectedSuggestions(selected).map((item) => item.line).join('\n');
}

class DlcAnalysisService {
  DlcAnalysisService({
    required this.paths,
    required this.settings,
    SteamProtocolService? protocol,
    Future<SteamAppInfo> Function(int)? queryApp,
    Future<KeyCacheData> Function(String sourceId)? readCache,
  }) : _protocol = queryApp == null
           ? protocol ?? SteamProtocolService(paths: paths, settings: settings)
           : protocol,
       _ownsProtocol = protocol == null && queryApp == null,
       _queryApp = queryApp,
       _cache = readCache == null
           ? KeyCacheService(paths: paths, settings: settings)
           : null {
    _readCache = readCache ?? _cache!.readCache;
  }

  final AppPaths paths;
  final SettingsStore settings;
  final SteamProtocolService? _protocol;
  final bool _ownsProtocol;
  final KeyCacheService? _cache;
  final Future<SteamAppInfo> Function(int)? _queryApp;
  late final Future<KeyCacheData> Function(String sourceId) _readCache;

  Future<DlcAnalysisResult> analyze(
    int appId, {
    String? luaPath,
    String? sourceId,
    TaskContext? task,
  }) async {
    if (appId <= 0 || appId > 0xffffffff) {
      throw const FormatException('AppID must be a positive 32-bit integer');
    }
    task?.checkCancelled();
    final effectivePath = await _existingLua(appId, luaPath);
    final bytes = effectivePath == null
        ? null
        : await File(effectivePath).readAsBytes();
    final lua = await Isolate.run(
      () => _LuaRecords.parse(bytes == null ? '' : utf8.decode(bytes)),
    );
    final warnings = <String>[];
    if (bytes == null) {
      warnings.add('No existing Lua file. Choose a Lua file before applying.');
    }
    var cache = const KeyCacheData();
    if (sourceId != null) {
      try {
        cache = await _readCache(sourceId);
        if (cache.depotKeys.isEmpty) {
          warnings.add('The selected content source has no cached depot keys.');
        }
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        warnings.add('Content source cache could not be read: $error');
      }
    }
    task?.checkCancelled();
    task?.report('Querying Steam app $appId');
    final main = await _query(appId, cache);
    task?.checkCancelled();
    final mainDepots = main.depots.map((depot) => depot.depotId).toSet();
    final mainDlcDepotIds = <int, Set<int>>{};
    for (final depot in main.depots) {
      if (depot.dlcAppId != null) {
        mainDlcDepotIds
            .putIfAbsent(depot.dlcAppId!, () => {})
            .add(depot.depotId);
      }
    }
    final dlcIds = {
      ...main.dlcAppIds,
      ...mainDlcDepotIds.keys,
    }.where((id) => id > 0 && id != appId).toList()..sort();
    final items = <DlcAnalysisItem>[];
    for (final dlcId in dlcIds) {
      task?.checkCancelled();
      SteamAppInfo? detail;
      String? error;
      try {
        detail = await _query(dlcId, cache);
      } on TaskCancelled {
        rethrow;
      } catch (failure) {
        error = '$failure';
      }
      task?.checkCancelled();
      final depots = detail?.depots.map((depot) => depot.depotId).toSet() ?? {};
      final inMain =
          mainDlcDepotIds.containsKey(dlcId) ||
          mainDepots.contains(dlcId) ||
          depots.any(mainDepots.contains);
      final kind = detail == null
          ? DlcDepotKind.unknown
          : inMain
          ? DlcDepotKind.inMainDepot
          : depots.length > 1
          ? DlcDepotKind.multiDepot
          : depots.isNotEmpty
          ? DlcDepotKind.singleDepot
          : DlcDepotKind.noDepot;
      final suggestions = <DlcSuggestion>[];
      final missing = <int>[];
      void addApp(int id, {String? key}) {
        suggestions.add(
          DlcSuggestion(
            'app:$id',
            key == null ? 'addappid($id)' : 'addappid($id, 1, "$key")',
          ),
        );
      }

      if (kind == DlcDepotKind.noDepot || kind == DlcDepotKind.inMainDepot) {
        if (!lua.appIds.contains(dlcId)) addApp(dlcId);
      } else if (kind != DlcDepotKind.unknown) {
        for (final depot in depots.toList()..sort()) {
          if (lua.keyedIds.contains(depot)) continue;
          final key = cache.depotKeys[depot];
          if (key == null || !RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(key)) {
            missing.add(depot);
          } else {
            addApp(depot, key: key);
          }
        }
        // Do not suggest enabling a DLC whose required depot keys are missing.
        if (missing.isEmpty &&
            !lua.appIds.contains(dlcId) &&
            !depots.contains(dlcId)) {
          addApp(dlcId);
        }
      }
      final token = cache.appTokens[dlcId];
      if (kind != DlcDepotKind.unknown &&
          missing.isEmpty &&
          !lua.tokenIds.contains(dlcId) &&
          token != null &&
          RegExp(r'^\d+$').hasMatch(token)) {
        suggestions.add(
          DlcSuggestion('token:$dlcId', 'addtoken($dlcId, "$token")'),
        );
      }
      final depotIds = depots.toList()..sort();
      items.add(
        DlcAnalysisItem(
          appId: dlcId,
          name: detail?.name ?? 'DLC $dlcId',
          kind: kind,
          depotIds: depotIds,
          isConfigured:
              lua.ids.contains(dlcId) || depotIds.any(lua.ids.contains),
          suggestions: suggestions,
          missingKeys: missing,
          error: error,
        ),
      );
      task?.report('Analyzed DLC $dlcId', items.length / (dlcIds.length + 1));
    }
    final unknown = items
        .where((item) => item.kind == DlcDepotKind.unknown)
        .length;
    if (unknown > 0) {
      warnings.add(
        '$unknown DLC queries failed; their depot layout is unknown.',
      );
    }
    for (final warning in warnings) {
      task?.report(warning);
    }
    task?.report(
      'DLC refresh complete: ${items.length} DLC, $unknown unknown',
      1,
    );
    return DlcAnalysisResult(
      appId: appId,
      name: main.name,
      mainDepotCount: mainDepots.length,
      items: items,
      warnings: warnings,
      luaPath: effectivePath,
      luaDigest: bytes == null ? null : sha256.convert(bytes).toString(),
    );
  }

  Future<SteamAppInfo> _query(int appId, KeyCacheData cache) {
    final injected = _queryApp;
    if (injected != null) return injected(appId);
    return _protocol!.getAppInfo(
      appId,
      accessToken: BigInt.tryParse(cache.appTokens[appId] ?? ''),
    );
  }

  Future<String?> _existingLua(int appId, String? explicitPath) async {
    if (explicitPath != null && explicitPath.trim().isNotEmpty) {
      final file = File(explicitPath);
      if (!await file.exists()) {
        throw FileSystemException(
          'Selected Lua file does not exist',
          explicitPath,
        );
      }
      return file.path;
    }
    if (settings.steamPath.isEmpty) return null;
    final roots = LuaDirectories(settings.steamPath).loadOrder.reversed;
    for (final root in roots) {
      for (final candidate in [
        p.join(root, '$appId.lua'),
        p.join(root, 'Disable', '$appId.lua'),
      ]) {
        if (await File(candidate).exists()) return candidate;
      }
    }
    return null;
  }

  Future<int> apply(
    DlcAnalysisResult result,
    Set<int> selected, {
    TaskContext? task,
  }) async {
    final additions = result.selectedSuggestions(selected);
    if (additions.isEmpty) return 0;
    final path = result.luaPath;
    if (path == null || result.luaDigest == null) {
      throw StateError('Select an existing Lua file and analyze it first');
    }
    task?.checkCancelled();
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('Lua file is no longer a regular file', path);
    }
    final file = File(path);
    final original = await file.readAsBytes();
    if (sha256.convert(original).toString() != result.luaDigest) {
      throw StateError(
        'Lua changed since analysis. Analyze again before applying.',
      );
    }
    final originalText = utf8.decode(original);
    final newline = originalText.contains('\r\n') ? '\r\n' : '\n';
    final suffix =
        '${originalText.endsWith('\n') ? '' : newline}'
        '-- FlSteamLua DLC additions$newline'
        '${additions.map((item) => item.line).join(newline)}$newline';
    final backupRoot = paths.directory('backups/lua');
    await backupRoot.create(recursive: true);
    await file.copy(
      p.join(
        backupRoot.path,
        '${p.basename(path)}.${DateTime.now().microsecondsSinceEpoch}.bak',
      ),
    );
    final temporary = File('$path.flsteamlua-dlc.tmp');
    try {
      await temporary.writeAsBytes([
        ...original,
        ...utf8.encode(suffix),
      ], flush: true);
      task?.checkCancelled();
      if (sha256.convert(await file.readAsBytes()).toString() !=
          result.luaDigest) {
        throw StateError('Lua changed while saving. Analyze again.');
      }
      await temporary.rename(path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    task?.report('Saved ${additions.length} DLC lines', 1);
    return additions.length;
  }

  void dispose() {
    if (_ownsProtocol) _protocol?.dispose();
    _cache?.dispose();
  }
}

class _LuaRecords {
  final Set<int> appIds = {};
  final Set<int> keyedIds = {};
  final Set<int> tokenIds = {};
  final Set<int> pinIds = {};
  Set<int> get ids => {...appIds, ...tokenIds, ...pinIds};

  static _LuaRecords parse(String input) {
    final records = _LuaRecords();
    final clean = _withoutLuaComments(
      input.replaceFirst(RegExp('^\uFEFF'), ''),
    );
    final pattern = RegExp(
      r'''(?:^|[;\r\n])\s*(addappid|addtoken|setManifestid)\s*\(\s*(\d+)([^\r\n)]*)\)''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(clean)) {
      final id = int.parse(match[2]!);
      switch (match[1]!.toLowerCase()) {
        case 'addappid':
          records.appIds.add(id);
          if (RegExp(
            r'''^\s*,\s*\d+\s*,\s*["'][A-Fa-f0-9]{64}["']\s*$''',
          ).hasMatch(match[3]!)) {
            records.keyedIds.add(id);
          }
        case 'addtoken':
          records.tokenIds.add(id);
        case 'setmanifestid':
          records.pinIds.add(id);
      }
    }
    return records;
  }
}

String _withoutLuaComments(String source) {
  final out = StringBuffer();
  var cursor = 0;
  while (cursor < source.length) {
    final character = source[cursor];
    if (character == '"' || character == "'") {
      final quote = character;
      out.write(character);
      cursor++;
      while (cursor < source.length) {
        final next = source[cursor++];
        out.write(next);
        if (next == r'\' && cursor < source.length) {
          out.write(source[cursor++]);
        } else if (next == quote) {
          break;
        }
      }
      continue;
    }
    final comment = source.startsWith('--', cursor);
    final bracketStart = cursor + (comment ? 2 : 0);
    final bracket = bracketStart < source.length && source[bracketStart] == '['
        ? RegExp(r'^\[(=*)\[').firstMatch(source.substring(bracketStart))
        : null;
    if (bracket != null) {
      final endToken = ']${bracket[1]}]';
      final end = source.indexOf(
        endToken,
        cursor + (comment ? 2 : 0) + bracket.end,
      );
      final next = end < 0 ? source.length : end + endToken.length;
      out.write(
        source.substring(cursor, next).replaceAll(RegExp(r'[^\r\n]'), ' '),
      );
      cursor = next;
    } else if (comment) {
      final next = source.indexOf('\n', cursor);
      cursor = next < 0 ? source.length : next;
    } else {
      out.write(character);
      cursor++;
    }
  }
  return out.toString();
}
