// Dart adaptation of Fluent-Steam-Lua configuration support.
// Original: Copyright (c) 2024 SteamLuaManager, zlib; modified for FlSteamLua.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/task_center.dart';
import 'patching_service.dart';

class GoldbergConfig {
  GoldbergConfig({
    this.appId = '',
    this.accountName = 'Goldberg',
    this.steamId = '76561197960287930',
    this.language = 'english',
    this.ticket = '',
    this.localSavePath = '',
    this.disableNetworking = false,
    this.offline = false,
    this.listenPort = 47584,
    this.unlockAllDlc = false,
    this.steamInput = false,
    this.cloudSaves = false,
    this.createCloudDirectory = true,
    this.overlay = false,
    List<int>? dlcIds,
    List<int>? depotIds,
    this.broadcasts = '',
    List<String>? languages,
    List<String>? interfaces,
    List<dynamic>? achievements,
    List<dynamic>? stats,
    Map<String, dynamic>? items,
    Map<String, dynamic>? defaultItems,
  }) : dlcIds = dlcIds ?? [],
       depotIds = depotIds ?? [],
       languages = languages ?? [],
       interfaces = interfaces ?? [],
       achievements = achievements ?? [],
       stats = stats ?? [],
       items = items ?? {},
       defaultItems = defaultItems ?? {};

  String appId,
      accountName,
      steamId,
      language,
      ticket,
      localSavePath,
      broadcasts;
  bool disableNetworking,
      offline,
      unlockAllDlc,
      steamInput,
      cloudSaves,
      createCloudDirectory,
      overlay;
  int listenPort;
  List<int> dlcIds, depotIds;
  List<String> languages, interfaces;
  List<dynamic> achievements, stats;
  Map<String, dynamic> items, defaultItems;
}

class GoldbergLoadResult {
  const GoldbergLoadResult(
    this.config,
    this.directory,
    this.exists,
    this.warnings,
  );
  final GoldbergConfig config;
  final String directory;
  final bool exists;
  final List<String> warnings;
}

class GoldbergConfigService {
  GoldbergConfigService(this.patching);
  final PatchingService patching;

  String settingsDirectory(String gameDirectory) =>
      p.basename(gameDirectory).toLowerCase() == 'steam_settings'
      ? gameDirectory
      : p.join(gameDirectory, 'steam_settings');

  Future<GoldbergLoadResult> load(String gameDirectory) async {
    final folder = settingsDirectory(gameDirectory);
    final config = GoldbergConfig();
    final warnings = <String>[];
    if (!await Directory(folder).exists()) {
      return GoldbergLoadResult(config, folder, false, warnings);
    }
    Future<String> read(String name) async {
      final file = File(p.join(folder, name));
      return await file.exists() ? await file.readAsString() : '';
    }

    final main = IniDocument(await read('configs.main.ini'));
    final user = IniDocument(await read('configs.user.ini'));
    final app = IniDocument(await read('configs.app.ini'));
    final overlay = IniDocument(await read('configs.overlay.ini'));
    bool flag(
      IniDocument ini,
      String section,
      String key, [
      bool fallback = false,
    ]) => switch (ini.value(section, key)?.toLowerCase()) {
      '1' || 'true' => true,
      '0' || 'false' => false,
      _ => fallback,
    };
    config.appId = (await read('steam_appid.txt')).trim();
    config.accountName =
        user.value('user::general', 'account_name') ?? config.accountName;
    config.steamId =
        user.value('user::general', 'account_steamid') ?? config.steamId;
    config.language =
        user.value('user::general', 'language') ?? config.language;
    config.ticket = user.value('user::general', 'ticket') ?? '';
    config.localSavePath = user.value('user::saves', 'local_save_path') ?? '';
    config.disableNetworking = flag(
      main,
      'main::connectivity',
      'disable_networking',
    );
    config.offline = flag(main, 'main::connectivity', 'offline');
    config.listenPort =
        int.tryParse(main.value('main::connectivity', 'listen_port') ?? '') ??
        47584;
    config.unlockAllDlc = flag(app, 'app::dlcs', 'unlock_all');
    config.steamInput = flag(app, 'app::controller', 'steam_input');
    config.cloudSaves = flag(app, 'app::cloud_saves', 'enabled');
    config.createCloudDirectory = flag(
      app,
      'app::cloud_saves',
      'create_default_dir',
      true,
    );
    config.overlay = flag(
      overlay,
      'overlay::general',
      'enable_experimental_overlay',
    );
    List<String> lines(String text) => const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    config.dlcIds = lines(
      await read('dlc.txt'),
    ).map(int.tryParse).whereType<int>().toList();
    config.depotIds = lines(
      await read('depots.txt'),
    ).map(int.tryParse).whereType<int>().toList();
    config.broadcasts = (await read('custom_broadcasts.txt')).trim();
    config.languages = lines(await read('supported_languages.txt'));
    config.interfaces = lines(await read('steam_interfaces.txt'));
    Future<T> json<T>(String name, T fallback) async {
      final text = await read(name);
      if (text.isEmpty) return fallback;
      try {
        final value = jsonDecode(text);
        if (value is! T) {
          throw FormatException('Expected ${fallback.runtimeType}');
        }
        return value;
      } catch (error) {
        warnings.add('$name: $error');
        return fallback;
      }
    }

    config.achievements = await json<List<dynamic>>('achievements.json', []);
    config.stats = await json<List<dynamic>>('stats.json', []);
    config.items = await json<Map<String, dynamic>>('items.json', {});
    config.defaultItems = await json<Map<String, dynamic>>(
      'default_items.json',
      {},
    );
    return GoldbergLoadResult(config, folder, true, warnings);
  }

  Future<PatchBackup> save(
    String gameDirectory,
    GoldbergConfig config, {
    TaskContext? context,
  }) async {
    _validate(config);
    final folder = settingsDirectory(gameDirectory);
    await Directory(folder).create(recursive: true);
    final files = <String, Uint8List>{};
    Future<void> ini(
      String filename,
      Map<String, Map<String, String>> sections,
    ) async {
      final file = File(p.join(folder, filename));
      final document = IniDocument(
        await file.exists() ? await file.readAsString() : '',
      );
      for (final section in sections.entries) {
        for (final entry in section.value.entries) {
          document.set(section.key, entry.key, entry.value);
        }
      }
      files[filename] = Uint8List.fromList(utf8.encode(document.text));
    }

    String flag(bool value) => value ? '1' : '0';
    await ini('configs.main.ini', {
      'main::connectivity': {
        'disable_networking': flag(config.disableNetworking),
        'listen_port': '${config.listenPort}',
        'offline': flag(config.offline),
      },
    });
    await ini('configs.user.ini', {
      'user::general': {
        'account_name': config.accountName,
        'account_steamid': config.steamId,
        'language': config.language,
        'ticket': config.ticket,
      },
      'user::saves': {'local_save_path': config.localSavePath},
    });
    await ini('configs.app.ini', {
      'app::dlcs': {'unlock_all': flag(config.unlockAllDlc)},
      'app::controller': {'steam_input': flag(config.steamInput)},
      'app::cloud_saves': {
        'enabled': flag(config.cloudSaves),
        'create_default_dir': flag(config.createCloudDirectory),
      },
    });
    await ini('configs.overlay.ini', {
      'overlay::general': {'enable_experimental_overlay': flag(config.overlay)},
    });
    final texts = <String, String>{
      'steam_appid.txt': config.appId,
      'dlc.txt': config.dlcIds.toSet().join('\n'),
      'depots.txt': config.depotIds.toSet().join('\n'),
      'custom_broadcasts.txt': config.broadcasts,
      'supported_languages.txt': config.languages.toSet().join('\n'),
      'steam_interfaces.txt': config.interfaces.toSet().join('\n'),
      'achievements.json': const JsonEncoder.withIndent(
        '  ',
      ).convert(config.achievements),
      'stats.json': const JsonEncoder.withIndent('  ').convert(config.stats),
      'items.json': const JsonEncoder.withIndent('  ').convert(config.items),
      'default_items.json': const JsonEncoder.withIndent(
        '  ',
      ).convert(config.defaultItems),
    };
    for (final entry in texts.entries) {
      files[entry.key] = Uint8List.fromList(utf8.encode(entry.value));
    }
    return patching.installFiles(folder, files, context: context);
  }

  Future<void> exportZip(String gameDirectory, String destination) async {
    final folder = Directory(settingsDirectory(gameDirectory));
    if (!await folder.exists()) {
      throw FileSystemException(
        'Goldberg settings directory does not exist',
        folder.path,
      );
    }
    final archive = Archive();
    await for (final file in folder.list(recursive: true, followLinks: false)) {
      if (file is! File) continue;
      final bytes = await file.readAsBytes();
      archive.addFile(
        ArchiveFile(
          p
              .join('steam_settings', p.relative(file.path, from: folder.path))
              .replaceAll('\\', '/'),
          bytes.length,
          bytes,
        ),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    await File(destination).writeAsBytes(encoded, flush: true);
  }

  Future<PatchBackup> importZip(
    String gameDirectory,
    String archivePath, {
    TaskContext? context,
  }) async {
    final files = await readArchiveFiles(archivePath);
    const known = {
      'steam_appid.txt',
      'dlc.txt',
      'depots.txt',
      'custom_broadcasts.txt',
      'supported_languages.txt',
      'steam_interfaces.txt',
      'configs.main.ini',
      'configs.user.ini',
      'configs.app.ini',
      'configs.overlay.ini',
      'achievements.json',
      'stats.json',
      'items.json',
      'default_items.json',
    };
    if (files.keys.any((name) {
      final portable = name.replaceAll('\\', '/');
      return !known.contains(portable) &&
          !portable.startsWith('achievement_images/');
    })) {
      throw const FormatException(
        'Archive contains files outside Goldberg configuration',
      );
    }
    final folder = settingsDirectory(gameDirectory);
    await Directory(folder).create(recursive: true);
    return patching.installFiles(folder, files, context: context);
  }

  void _validate(GoldbergConfig config) {
    if (config.appId.isNotEmpty && (int.tryParse(config.appId) ?? 0) <= 0) {
      throw const FormatException('AppID must be a positive integer');
    }
    if (config.listenPort < 1 || config.listenPort > 65535) {
      throw const FormatException('Listen port must be 1-65535');
    }
    if (config.steamId.isNotEmpty &&
        (BigInt.tryParse(config.steamId) ?? BigInt.zero) <= BigInt.zero) {
      throw const FormatException('SteamID must be a positive integer');
    }
    if (config.dlcIds.any((id) => id <= 0) ||
        config.depotIds.any((id) => id <= 0)) {
      throw const FormatException('DLC and depot IDs must be positive');
    }
    for (final value in [
      config.accountName,
      config.steamId,
      config.language,
      config.ticket,
      config.localSavePath,
    ]) {
      if (value.contains('\n') ||
          value.contains('\r') ||
          value.contains('\u0000')) {
        throw const FormatException('INI values must be a single line');
      }
    }
    for (final achievement in config.achievements) {
      if (achievement is! Map || achievement['name'] is! String) {
        throw const FormatException('Every achievement requires a name');
      }
    }
    for (final stat in config.stats) {
      if (stat is! Map || stat['name'] is! String) {
        throw const FormatException('Every stat requires a name');
      }
    }
  }
}

class IniDocument {
  IniDocument(String text) : _lines = const LineSplitter().convert(text);
  final List<String> _lines;
  String get text => '${_lines.join('\n')}\n';

  String? value(String section, String key) {
    var current = '';
    for (final line in _lines) {
      final clean = line.trim();
      if (clean.startsWith('[') && clean.endsWith(']')) {
        current = clean.substring(1, clean.length - 1);
        continue;
      }
      if (current != section ||
          clean.startsWith('#') ||
          clean.startsWith(';')) {
        continue;
      }
      final split = clean.indexOf('=');
      if (split >= 0 && clean.substring(0, split).trim() == key) {
        return clean.substring(split + 1).trim();
      }
    }
    return null;
  }

  void set(String section, String key, String value) {
    var current = '';
    var insertion = -1;
    for (var i = 0; i < _lines.length; i++) {
      final clean = _lines[i].trim();
      if (clean.startsWith('[') && clean.endsWith(']')) {
        if (current == section) break;
        current = clean.substring(1, clean.length - 1);
        if (current == section) insertion = i + 1;
        continue;
      }
      if (current != section) continue;
      insertion = i + 1;
      if (clean.startsWith('#') || clean.startsWith(';')) continue;
      final split = clean.indexOf('=');
      if (split >= 0 && clean.substring(0, split).trim() == key) {
        _lines[i] = '$key=$value';
        return;
      }
    }
    if (insertion >= 0) {
      _lines.insert(insertion, '$key=$value');
    } else {
      if (_lines.isNotEmpty && _lines.last.isNotEmpty) _lines.add('');
      _lines.addAll(['[$section]', '$key=$value']);
    }
  }
}
