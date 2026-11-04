// Portions adapted from Fluent-Steam-Lua (zlib license); rewritten for Dart.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../library/kv1.dart';
import '../network/network_preferences.dart';
import 'lua_vdf_converter.dart';

class DiagnosticItem {
  const DiagnosticItem(this.name, this.ok, this.detail);
  final String name;
  final bool ok;
  final String detail;
}

class LuaDepot {
  const LuaDepot(this.id, this.key, this.manifestId, this.pinned);
  final int id;
  final String? key;
  final String? manifestId;
  final bool pinned;
}

class ToolsService {
  ToolsService({
    required this.paths,
    required this.settings,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;
  final AppPaths paths;
  final SettingsStore settings;
  final http.Client _client;
  final bool _ownsClient;
  final LuaVdfConverter converter = LuaVdfConverter();

  static final _pin = RegExp(
    r'''^\s*(--\s*)?setManifestid\s*\(\s*(\d+)\s*,\s*["'](\d+)["'](?:\s*,\s*\d+)?\s*\)''',
    caseSensitive: false,
  );
  static final _depot = RegExp(
    r'''^\s*addappid\s*\(\s*(\d+)\s*,\s*\d+\s*,\s*["']([^"']+)["']\s*\)''',
    caseSensitive: false,
  );
  static final _bare = RegExp(
    r'^\s*addappid\s*\(\s*(\d+)\s*\)',
    caseSensitive: false,
  );

  Future<List<LuaDepot>> depots(GameEntry game) async {
    final text = await _luaFile(game).readAsString();
    final records = <int, LuaDepot>{};
    for (final line in const LineSplitter().convert(text)) {
      final match = _depot.firstMatch(line);
      if (match != null) {
        final id = int.parse(match[1]!);
        records[id] = LuaDepot(id, match[2], null, false);
        continue;
      }
      final bare = _bare.firstMatch(line);
      if (bare != null) {
        final id = int.parse(bare[1]!);
        records.putIfAbsent(id, () => LuaDepot(id, null, null, false));
      }
    }
    for (final line in const LineSplitter().convert(text)) {
      final match = _pin.firstMatch(line);
      if (match != null) {
        final id = int.parse(match[2]!);
        final current = records[id];
        records[id] = LuaDepot(id, current?.key, match[3], match[1] == null);
      }
    }
    return records.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> pinManifests(
    GameEntry game,
    Map<int, String> manifestIds,
  ) async {
    if (manifestIds.isEmpty) {
      throw const FormatException('Select at least one manifest');
    }
    for (final entry in manifestIds.entries) {
      if (entry.key <= 0 || !RegExp(r'^[1-9]\d*$').hasMatch(entry.value)) {
        throw const FormatException('Invalid depot or manifest ID');
      }
    }
    final file = _luaFile(game);
    final lines = const LineSplitter().convert(await file.readAsString());
    final remaining = {...manifestIds};
    final output = <String>[];
    for (final line in lines) {
      final match = _pin.firstMatch(line);
      final id = match == null ? null : int.parse(match[2]!);
      if (id != null && manifestIds.containsKey(id)) {
        if (remaining.containsKey(id)) {
          output.add('setManifestid($id,"${remaining.remove(id)}",0)');
        }
      } else {
        output.add(line);
      }
    }
    for (final entry in remaining.entries) {
      output.add('setManifestid(${entry.key},"${entry.value}",0)');
    }
    await _backupAndWrite(file, '${output.join('\n')}\n');
  }

  Future<void> unpinManifests(GameEntry game) async {
    final file = _luaFile(game);
    final text = await file.readAsString();
    final lines = const LineSplitter().convert(text).map((line) {
      final match = _pin.firstMatch(line);
      return match != null && match[1] == null ? '--${line.trimLeft()}' : line;
    });
    await _backupAndWrite(file, '${lines.join('\n')}\n');
  }

  Future<Map<int, String>> installedManifests(GameEntry game) async {
    if (game.libraryPath == null) {
      throw const FileSystemException('Game is not installed');
    }
    final file = File(
      p.join(game.libraryPath!, 'steamapps', 'appmanifest_${game.appId}.acf'),
    );
    final root = Kv1.parse(await file.readAsString());
    final state = root['AppState'] as Map? ?? root;
    final installed = state['InstalledDepots'] as Map?;
    final mounted = state['MountedDepots'] as Map?;
    final results = <int, String>{};
    if (installed != null) {
      for (final entry in installed.entries) {
        final id = int.tryParse('${entry.key}');
        final manifest = entry.value is Map
            ? '${(entry.value as Map)['manifest'] ?? ''}'
            : '';
        if (id != null && RegExp(r'^[1-9]\d*$').hasMatch(manifest)) {
          results[id] = manifest;
        }
      }
    }
    if (mounted != null) {
      for (final entry in mounted.entries) {
        final id = int.tryParse('${entry.key}');
        if (id != null && RegExp(r'^[1-9]\d*$').hasMatch('${entry.value}')) {
          results[id] = '${entry.value}';
        }
      }
    }
    return results;
  }

  Future<int> clearDepotcacheManifests(GameEntry game) async {
    final depotIds = <int>{};
    final readErrors = <Object>[];
    if (game.hasLua) {
      try {
        depotIds.addAll((await depots(game)).map((depot) => depot.id));
      } catch (error) {
        readErrors.add(error);
      }
    }
    if (game.isInstalled) {
      try {
        depotIds.addAll((await installedManifests(game)).keys);
      } catch (error) {
        readErrors.add(error);
      }
    }
    if (depotIds.isEmpty) {
      if (readErrors.isNotEmpty) throw readErrors.first;
      throw StateError('No depot information is available for this game');
    }

    final roots = <String>{};
    void addRoot(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      roots.add(p.normalize(p.absolute(trimmed)));
    }

    addRoot(settings.steamPath);
    if (game.libraryPath case final library?) addRoot(library);
    final primary = settings.steamPath.trim();
    if (primary.isNotEmpty) {
      final folders = File(p.join(primary, 'steamapps', 'libraryfolders.vdf'));
      if (await folders.exists()) {
        final parsed = Kv1.parse(await folders.readAsString());
        final listing = parsed['libraryfolders'] as Map? ?? parsed;
        for (final value in listing.values) {
          final path = value is Map ? '${value['path'] ?? ''}' : '$value';
          addRoot(path);
        }
      }
    }

    final directories = {
      for (final root in roots) ...[
        p.join(root, 'depotcache'),
        p.join(root, 'steamapps', 'depotcache'),
      ],
    };
    final manifestName = RegExp(r'^(\d+)_.*\.manifest$', caseSensitive: false);
    var removed = 0;
    for (final path in directories) {
      final directory = Directory(path);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final match = manifestName.firstMatch(p.basename(entity.path));
        final depotId = match == null ? null : int.tryParse(match[1]!);
        if (depotId == null || !depotIds.contains(depotId)) continue;
        await entity.delete();
        removed++;
      }
    }
    return removed;
  }

  Future<Map<int, String>> latestManifests(
    int appId,
    Iterable<int> depotIds,
  ) async {
    if (appId <= 0) throw const FormatException('Invalid AppID');
    final response = await _client
        .get(Uri.https('api.steamcmd.net', '/v1/info/$appId'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('App info HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final app = (decoded['data'] as Map?)?['$appId'] as Map?;
    final depots = app?['depots'] as Map?;
    if (depots == null) throw const FormatException('App info has no depots');
    final result = <int, String>{};
    for (final id in depotIds) {
      final depot = depots['$id'] as Map?;
      final manifests = depot?['manifests'] as Map?;
      final public = manifests?['public'] as Map?;
      final gid = '${public?['gid'] ?? ''}';
      if (RegExp(r'^[1-9]\d*$').hasMatch(gid)) result[id] = gid;
    }
    return result;
  }

  Future<int> addDlc(GameEntry game, Iterable<int> appIds) async {
    final ids = appIds.toSet();
    if (ids.any((id) => id <= 0 || id == game.appId)) {
      throw const FormatException('Invalid DLC AppID');
    }
    final file = _luaFile(game);
    var text = await file.readAsString();
    final existing = <int>{};
    for (final line in const LineSplitter().convert(text)) {
      final match = _bare.firstMatch(line) ?? _depot.firstMatch(line);
      if (match != null) existing.add(int.parse(match[1]!));
    }
    final missing = ids.difference(existing).toList()..sort();
    if (missing.isEmpty) return 0;
    if (!text.endsWith('\n')) text += '\n';
    text += '${missing.map((id) => 'addappid($id)').join('\n')}\n';
    await _backupAndWrite(file, text);
    return missing.length;
  }

  Future<void> removeDlc(GameEntry game, Iterable<int> appIds) async {
    final ids = appIds.toSet();
    if (ids.contains(game.appId)) {
      throw const FormatException('Cannot remove the base AppID');
    }
    final file = _luaFile(game);
    final lines = const LineSplitter().convert(await file.readAsString());
    final output = lines.where((line) {
      final entry = _bare.firstMatch(line) ?? _depot.firstMatch(line);
      final pin = _pin.firstMatch(line);
      final id = entry != null
          ? int.parse(entry[1]!)
          : pin != null
          ? int.parse(pin[2]!)
          : null;
      return !ids.contains(id);
    });
    await _backupAndWrite(file, '${output.join('\n')}\n');
  }

  Future<File> downloadCover(
    int appId, {
    String kind = 'header',
    TaskContext? task,
  }) async {
    if (appId <= 0 ||
        !{'header', 'library_600x900', 'library_hero', 'logo'}.contains(kind)) {
      throw const FormatException('Invalid cover request');
    }
    final extension = kind == 'logo' ? 'png' : 'jpg';
    final original = Uri.https(
      'shared.akamai.steamstatic.com',
      '/store_item_assets/steam/apps/$appId/$kind.$extension',
    );
    task?.checkCancelled();
    var urls = [original.toString()];
    if (kind == 'header') {
      try {
        urls = await NetworkPreferences(
          settings,
          client: _client,
        ).coverUrls(appId, fallback: original.toString());
      } on Exception {
        // The requested source may be offline; preserve the original download.
      }
    }
    http.Response? response;
    Object? failure;
    for (final url in urls) {
      task?.checkCancelled();
      try {
        final candidate = await _client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (candidate.statusCode != 200) {
          throw HttpException('Cover HTTP ${candidate.statusCode}');
        }
        if (!NetworkPreferences.isImage(candidate.bodyBytes)) {
          throw const FormatException('Invalid image response');
        }
        response = candidate;
        break;
      } on Exception catch (error) {
        failure = error;
      }
    }
    if (response == null) throw failure!;
    final bytes = response.bodyBytes;
    final png = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final webp = bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49;
    if (!NetworkPreferences.isImage(bytes) || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Invalid image response');
    }
    task?.checkCancelled();
    final directory = paths.directory('cache/covers');
    await directory.create(recursive: true);
    final file = File(
      p.join(
        directory.path,
        '${appId}_$kind.${png
            ? 'png'
            : webp
            ? 'webp'
            : 'jpg'}',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    task?.report(file.path, 1);
    return file;
  }

  Future<List<DiagnosticItem>> diagnose() async {
    final steam = Directory(settings.steamPath);
    final found = settings.steamPath.isNotEmpty && await steam.exists();
    final result = <DiagnosticItem>[
      DiagnosticItem(
        'Steam',
        found,
        found
            ? steam.path
            : 'Choose the Steam installation directory in Settings',
      ),
      DiagnosticItem(
        'Application data',
        await Directory(paths.root).exists(),
        paths.root,
      ),
    ];
    if (found) {
      for (final relative in [
        'steam.exe',
        'steamclient64.dll',
        'logs/content_log.txt',
      ]) {
        final file = File(p.join(steam.path, relative));
        result.add(DiagnosticItem(relative, await file.exists(), file.path));
      }
      final lua = Directory(p.join(steam.path, 'config', 'stplug-in'));
      result.add(DiagnosticItem('Lua directory', await lua.exists(), lua.path));
    }
    return result;
  }

  Future<void> openPath(String path) async {
    if (!await FileSystemEntity.isDirectory(path) &&
        !await FileSystemEntity.isFile(path)) {
      throw FileSystemException('Path does not exist', path);
    }
    if (!Platform.isWindows) throw UnsupportedError('Windows desktop only');
    await Process.start('explorer.exe', [
      path,
    ], mode: ProcessStartMode.detached);
  }

  File _luaFile(GameEntry game) {
    final path = game.luaPath;
    if (path == null) {
      throw const FileSystemException('This game has no Lua configuration');
    }
    return File(path);
  }

  Future<void> _backupAndWrite(File file, String text) async {
    final directory = paths.directory('backups/lua');
    await directory.create(recursive: true);
    await file.copy(
      p.join(
        directory.path,
        '${p.basename(file.path)}.${DateTime.now().microsecondsSinceEpoch}.bak',
      ),
    );
    final temp = File('${file.path}.flsteamlua.tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(file.path);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
