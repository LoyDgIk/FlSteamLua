import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:win32/win32.dart' show WindowsException;
import 'package:win32_registry/win32_registry.dart';

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import 'kv1.dart';
import 'process_observer.dart';

typedef LibraryProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef LibraryProcessStarter =
    Future<void> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef LibraryUriOpener = Future<bool> Function(Uri uri);

class SteamLocalAccount {
  const SteamLocalAccount({
    required this.steamId,
    required this.accountName,
    required this.personaName,
    this.mostRecent = false,
  });
  final String steamId;
  final String accountName;
  final String personaName;
  final bool mostRecent;
}

class ImportResult {
  ImportResult({
    required this.written,
    required this.skipped,
    required this.errors,
  });
  final List<String> written;
  final List<String> skipped;
  final Map<String, String> errors;
  bool get succeeded => errors.isEmpty;
}

class SteamUpdateControlSettings {
  const SteamUpdateControlSettings({
    this.disableUpdateCheck = false,
    this.disableForcedUpdate = false,
  });

  final bool disableUpdateCheck;
  final bool disableForcedUpdate;

  SteamUpdateControlSettings copyWith({
    bool? disableUpdateCheck,
    bool? disableForcedUpdate,
  }) => SteamUpdateControlSettings(
    disableUpdateCheck: disableUpdateCheck ?? this.disableUpdateCheck,
    disableForcedUpdate: disableForcedUpdate ?? this.disableForcedUpdate,
  );
}

class _GameSession {
  _GameSession(this.process, this.startedAt, this.executablePath);
  final Process process;
  final DateTime startedAt;
  final String executablePath;
}

/// Local Steam installation and Lua files share one AppID-indexed catalogue.
class LibraryService extends ChangeNotifier {
  LibraryService({
    required this.paths,
    required this.settings,
    LibraryProcessRunner? processRunner,
    LibraryProcessStarter? processStarter,
    LibraryUriOpener? uriOpener,
    ProcessSnapshotReader? processSnapshotReader,
    ObservedProcessStopper? observedProcessStopper,
  }) : _run = processRunner ?? _runProcess,
       _startSteamProcess = processStarter ?? _startDetached,
       _open = uriOpener ?? _openUri,
       _readProcesses = processSnapshotReader ?? readRunningProcesses,
       _stopObserved = observedProcessStopper ?? stopObservedProcess;

  final AppPaths paths;
  final SettingsStore settings;
  final LibraryProcessRunner _run;
  final LibraryProcessStarter _startSteamProcess;
  final LibraryUriOpener _open;
  final ProcessSnapshotReader _readProcesses;
  final ObservedProcessStopper _stopObserved;
  List<GameEntry> _games = [];
  List<SteamLocalAccount> _accounts = [];
  List<String> _warnings = [];
  String? _steamPath;
  final Map<int, _GameSession> _sessions = {};
  Map<int, List<RunningProcess>> _observedProcesses = {};
  Map<int, String> _monitoredExecutables = {};
  final Map<int, DateTime> _runningSince = {};
  Timer? _processTimer;
  bool _processMonitoring = false;
  Future<void>? _processRefresh;
  String? _processWarning;
  Future<void> _recordWrite = Future.value();
  bool _disposed = false;

  late final SteamProcessActions processActions = SteamProcessActions(
    isRunning: isSteamRunning,
    start: startSteam,
    stop: stopSteam,
    restart: restartSteam,
  );

  List<GameEntry> get games => List.unmodifiable(_games);
  List<SteamLocalAccount> get accounts => List.unmodifiable(_accounts);
  List<String> get warnings =>
      List.unmodifiable([..._warnings, ?_processWarning]);
  String? get steamPath => _steamPath;
  bool get isScanning => _scanning;
  bool _scanning = false;

  Map<int, String> get runningExecutables => {
    for (final entry in _observedProcesses.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.first.executablePath,
    for (final entry in _sessions.entries)
      entry.key: entry.value.executablePath,
  };

  bool isExecutableRunning(int appId, String path) {
    final key = _executableKey(path);
    return _sessions[appId] != null &&
            _executableKey(_sessions[appId]!.executablePath) == key ||
        (_observedProcesses[appId] ?? const <RunningProcess>[]).any(
          (process) => _executableKey(process.executablePath) == key,
        );
  }

  void setMonitoredExecutables(Map<int, String> executables) {
    _monitoredExecutables = Map.of(executables);
  }

  Future<void> startProcessMonitoring({
    Duration interval = const Duration(seconds: 2),
  }) async {
    _processMonitoring = true;
    _processTimer?.cancel();
    await refreshRunningProcesses();
    if (_disposed || !_processMonitoring) return;
    _processTimer = Timer.periodic(interval, (_) {
      unawaited(refreshRunningProcesses());
    });
  }

  Future<void> stopProcessMonitoring() async {
    _processMonitoring = false;
    _processTimer?.cancel();
    _processTimer = null;
    await _processRefresh;
  }

  Future<void> refreshRunningProcesses() {
    if (_disposed) return Future.value();
    return _processRefresh ??= _refreshRunningProcesses().whenComplete(() {
      _processRefresh = null;
    });
  }

  Future<void> _refreshRunningProcesses() async {
    try {
      final processes = await _readProcesses();
      if (_disposed) return;
      final targets = <String, Set<int>>{};
      void target(int appId, String path) {
        targets.putIfAbsent(_executableKey(path), () => {}).add(appId);
      }

      for (final game in _games) {
        if (game.isInstalled && game.executablePath != null) {
          target(game.appId, game.executablePath!);
        }
      }
      for (final entry in _monitoredExecutables.entries) {
        target(entry.key, entry.value);
      }
      final observed = <int, List<RunningProcess>>{};
      for (final process in processes) {
        final ids = targets[_executableKey(process.executablePath)];
        if (ids == null) continue;
        for (final id in ids) {
          observed.putIfAbsent(id, () => []).add(process);
        }
      }
      _observedProcesses = observed;
      _processWarning = null;
      await _syncRunningState();
    } catch (error) {
      // A failed snapshot must not make live games appear to have exited.
      if (!_disposed) _processWarning = 'Game process detection: $error';
    }
    _emit();
  }

  static String _executableKey(String path) =>
      p.normalize(p.absolute(path)).toLowerCase();

  Future<void> _syncRunningState() async {
    final running = runningExecutables.keys.toSet();
    for (final game in List<GameEntry>.of(_games)) {
      final active = running.contains(game.appId);
      if (active) {
        _runningSince.putIfAbsent(game.appId, DateTime.now);
      }
      if (game.isRunning == active) continue;
      if (active) {
        _replace(game.copyWith(isRunning: true));
      } else {
        final since = _runningSince.remove(game.appId);
        final now = DateTime.now();
        final minutes =
            game.playtimeMinutes +
            (since == null ? 0 : now.difference(since).inMinutes);
        await _updateRecord(game.appId, {
          'name': game.name,
          'playtimeMinutes': minutes,
          'lastPlayed': now.toIso8601String(),
        });
        if (_disposed) return;
        final current = _games
            .where((entry) => entry.appId == game.appId)
            .firstOrNull;
        if (current != null) {
          _replace(
            current.copyWith(
              isRunning: false,
              playtimeMinutes: minutes,
              lastPlayed: now,
            ),
          );
        }
      }
    }
  }

  static Future<ProcessResult> _runProcess(String command, List<String> args) =>
      Process.run(command, args, stdoutEncoding: null, stderrEncoding: utf8);
  static Future<void> _startDetached(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
    );
  }

  static Future<bool> _openUri(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<String?> detectSteamPath() async {
    final custom = settings.steamPath.trim();
    if (custom.isNotEmpty) {
      if (!await Directory(custom).exists()) {
        throw FileSystemException(
          'Configured Steam directory does not exist',
          custom,
        );
      }
      return _steamPath = p.normalize(p.absolute(custom));
    }
    if (Platform.isWindows) {
      for (final query in [
        (RegistryHive.currentUser, r'Software\Valve\Steam', 'SteamPath'),
        (
          RegistryHive.localMachine,
          r'SOFTWARE\WOW6432Node\Valve\Steam',
          'InstallPath',
        ),
        (RegistryHive.localMachine, r'SOFTWARE\Valve\Steam', 'InstallPath'),
      ]) {
        try {
          final key = Registry.openPath(query.$1, path: query.$2);
          final String? path;
          try {
            path = key.getStringValue(query.$3);
          } finally {
            key.close();
          }
          if (path != null && await File(p.join(path, 'steam.exe')).exists()) {
            return _steamPath = p.normalize(path);
          }
        } on WindowsException {
          // An installation may only be registered in one of these hives.
        }
      }
    }
    for (final candidate in [
      p.join(
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)',
        'Steam',
      ),
      p.join(
        Platform.environment['ProgramFiles'] ?? r'C:\Program Files',
        'Steam',
      ),
      r'D:\Steam',
      r'E:\Steam',
    ]) {
      if (await File(p.join(candidate, 'steam.exe')).exists()) {
        return _steamPath = candidate;
      }
    }
    return _steamPath = null;
  }

  Future<void> refresh({TaskContext? context}) => scan(context: context);

  Future<void> scan({TaskContext? context}) async {
    if (_scanning) return;
    _scanning = true;
    _emit();
    try {
      context?.checkCancelled();
      final root = await detectSteamPath();
      if (root == null) {
        _games = [];
        _accounts = [];
        _warnings = [];
        return;
      }
      context?.report('Reading Steam libraries');
      final customLuaPath = settings.get<String>('luaPath', '');
      final appRoot = paths.root;
      final result = await _scanInIsolate(root, customLuaPath, appRoot);
      context?.checkCancelled();
      _warnings = result.$2;
      _games = result.$1
          .map(
            (game) => game.copyWith(
              isRunning: runningExecutables.containsKey(game.appId),
            ),
          )
          .toList();
      _accounts = await listAccounts();
      if (_processTimer != null) await refreshRunningProcesses();
      context?.report('Found ${_games.length} games', 1);
    } finally {
      _scanning = false;
      _emit();
    }
  }

  static Future<(List<GameEntry>, List<String>)> _scanInIsolate(
    String root,
    String customLua,
    String appRoot,
  ) => Isolate.run(() => _scanLocal(root, customLua, appRoot));

  static (List<GameEntry>, List<String>) _scanLocal(
    String root,
    String customLua,
    String appRoot,
  ) {
    final warnings = <String>[];
    final records = _readRecordsSync(p.join(appRoot, 'data', 'library.json'));
    final libraries = <String>[root];
    final folders = File(p.join(root, 'steamapps', 'libraryfolders.vdf'));
    if (folders.existsSync()) {
      try {
        final parsed = Kv1.parse(folders.readAsStringSync());
        final listing = _mapValue(parsed, 'libraryfolders') ?? parsed;
        for (final entry in listing.entries) {
          if (int.tryParse(entry.key) == null) continue;
          final value = entry.value;
          final library = value is Map
              ? _stringValue(value, 'path')
              : value.toString();
          if (library.isNotEmpty &&
              !libraries.any(
                (existing) =>
                    p.equals(existing.toLowerCase(), library.toLowerCase()),
              )) {
            libraries.add(library);
          }
        }
      } on FormatException catch (error) {
        warnings.add('${folders.path}: $error');
      }
    }
    final games = <int, GameEntry>{};
    for (final library in libraries) {
      final steamapps = Directory(p.join(library, 'steamapps'));
      if (!steamapps.existsSync()) continue;
      try {
        for (final file
            in steamapps.listSync(followLinks: false).whereType<File>()) {
          if (!RegExp(
            r'^appmanifest_\d+\.acf$',
            caseSensitive: false,
          ).hasMatch(p.basename(file.path))) {
            continue;
          }
          try {
            final parsed = Kv1.parse(file.readAsStringSync());
            final state = _mapValue(parsed, 'AppState');
            if (state == null) throw const FormatException('Missing AppState');
            final id =
                int.tryParse(_stringValue(state, 'appid')) ??
                int.tryParse(
                  RegExp(r'\d+').firstMatch(p.basename(file.path))?.group(0) ??
                      '',
                );
            if (id == null || id <= 0) {
              throw const FormatException('Invalid AppID');
            }
            final name = _stringValue(state, 'name');
            if (name.toLowerCase().contains(
              'steamworks common redistributables',
            )) {
              continue;
            }
            final installName = _stringValue(state, 'installdir');
            final common = p.join(library, 'steamapps', 'common');
            final install = installName.isEmpty
                ? null
                : _safeChild(common, installName);
            final exists = install != null && Directory(install).existsSync();
            final flags = int.tryParse(_stringValue(state, 'StateFlags')) ?? 0;
            final local = records['$id'] is Map
                ? records['$id'] as Map
                : const {};
            final recordTime = DateTime.tryParse(
              local['lastPlayed']?.toString() ?? '',
            );
            final timestamp =
                int.tryParse(_stringValue(state, 'LastPlayed')) ?? 0;
            final game = GameEntry(
              appId: id,
              name:
                  local['name']?.toString() ??
                  (name.isEmpty ? 'App $id' : name),
              coverUrl: local['coverUrl']?.toString(),
              installPath: install,
              libraryPath: library,
              executablePath: exists ? _findExecutable(install) : null,
              isInstalled: exists && (flags == 0 || flags & 4 != 0),
              ownership: GameOwnership.unknown,
              isFavorite: local['favorite'] == true,
              playtimeMinutes: local['playtimeMinutes'] is int
                  ? local['playtimeMinutes'] as int
                  : 0,
              sizeOnDisk: int.tryParse(_stringValue(state, 'SizeOnDisk')) ?? 0,
              lastPlayed: timestamp > 0
                  ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
                  : recordTime,
            );
            final existing = games[id];
            if (existing == null || !existing.isInstalled && game.isInstalled) {
              games[id] = game;
            }
          } on FormatException catch (error) {
            warnings.add('${file.path}: $error');
          } on FileSystemException catch (error) {
            warnings.add('${file.path}: ${error.message}');
          }
        }
      } on FileSystemException catch (error) {
        warnings.add('${steamapps.path}: ${error.message}');
      }
    }
    for (final luaRoot in _luaDirectories(root, customLua)) {
      final directory = Directory(luaRoot);
      if (!directory.existsSync()) continue;
      try {
        for (final file
            in directory
                .listSync(recursive: true, followLinks: false)
                .whereType<File>()) {
          if (p.extension(file.path).toLowerCase() != '.lua') continue;
          final appId = int.tryParse(p.basenameWithoutExtension(file.path));
          if (appId == null || appId <= 0) continue;
          final relative = p.relative(file.path, from: luaRoot);
          final enabled = !p
              .split(relative)
              .any((part) => part.toLowerCase() == 'disable');
          final existing = games[appId];
          if (existing?.hasLua == true && existing!.luaEnabled) continue;
          final local = records['$appId'] is Map
              ? records['$appId'] as Map
              : const {};
          games[appId] =
              existing?.copyWith(luaPath: file.path, luaEnabled: enabled) ??
              GameEntry(
                appId: appId,
                name: local['name']?.toString() ?? 'App $appId',
                coverUrl: local['coverUrl']?.toString(),
                luaPath: file.path,
                luaEnabled: enabled,
                isFavorite: local['favorite'] == true,
                playtimeMinutes: local['playtimeMinutes'] is int
                    ? local['playtimeMinutes'] as int
                    : 0,
                lastPlayed: DateTime.tryParse(
                  local['lastPlayed']?.toString() ?? '',
                ),
              );
        }
      } on FileSystemException catch (error) {
        warnings.add('${directory.path}: ${error.message}');
      }
    }
    final sorted = games.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return (sorted, warnings);
  }

  Future<void> setFavorite(int appId, bool favorite) async {
    final game = _game(appId);
    await _updateRecord(appId, {'name': game.name, 'favorite': favorite});
    _replace(game.copyWith(isFavorite: favorite));
  }

  Future<void> updateGameMetadata(
    int appId, {
    required String name,
    String? coverUrl,
  }) async {
    final game = _game(appId);
    await _updateRecord(appId, {'name': name, 'coverUrl': ?coverUrl});
    _replace(game.copyWith(name: name, coverUrl: coverUrl));
  }

  Future<String> readLua(int appId) => _luaFile(appId).readAsString();

  Future<void> saveLua(int appId, String content) async {
    final file = _luaFile(appId);
    await _backup(file);
    await _atomicWrite(file, utf8.encode(content));
    await scan();
  }

  File _luaFile(int appId) {
    final path = _game(appId).luaPath;
    if (path == null) throw StateError('No Lua file for App $appId');
    return File(path);
  }

  Future<void> openLuaDirectory({int? appId}) async {
    final directory = appId == null
        ? _luaDirectories(
            await _requireSteam(),
            settings.get<String>('luaPath', ''),
          ).first
        : p.dirname(_luaFile(appId).path);
    await Directory(directory).create(recursive: true);
    if (!await _open(Uri.directory(directory, windows: Platform.isWindows))) {
      throw StateError('Cannot open Lua directory');
    }
  }

  Future<ImportResult> exportLua(
    Iterable<int> appIds,
    String directory, {
    bool overwrite = false,
    TaskContext? context,
  }) async {
    final target = Directory(directory);
    await target.create(recursive: true);
    final written = <String>[];
    final skipped = <String>[];
    final errors = <String, String>{};
    for (final id in appIds.toSet()) {
      context?.checkCancelled();
      try {
        final destination = File(p.join(target.path, '$id.lua'));
        final source = _luaFile(id);
        if (p.equals(p.absolute(source.path), p.absolute(destination.path)) ||
            !overwrite && await destination.exists()) {
          skipped.add(destination.path);
          continue;
        }
        await _atomicWrite(destination, await source.readAsBytes());
        written.add(destination.path);
        context?.report('Exported $id.lua');
      } catch (error) {
        errors['$id'] = '$error';
      }
    }
    return ImportResult(written: written, skipped: skipped, errors: errors);
  }

  Future<void> toggleLua(int appId, bool enabled) async {
    await _moveLua(_game(appId), enabled);
    await scan();
  }

  Future<void> _moveLua(GameEntry game, bool enabled) async {
    final source = game.luaPath;
    if (source == null) throw StateError('No Lua file for App ${game.appId}');
    if (game.luaEnabled == enabled) return;
    final root = _luaDirectories(
      await _requireSteam(),
      settings.get<String>('luaPath', ''),
    ).firstWhere((root) => p.isWithin(root, source));
    final relative = p.split(p.relative(source, from: root));
    if (enabled) {
      relative.removeAt(
        relative.indexWhere((part) => part.toLowerCase() == 'disable'),
      );
    } else {
      relative.insert(0, 'Disable');
    }
    final target = p.join(root, p.joinAll(relative));
    if (await File(target).exists()) {
      throw FileSystemException(
        'Destination already contains a Lua file',
        target,
      );
    }
    await Directory(p.dirname(target)).create(recursive: true);
    await File(source).rename(target);
  }

  Future<ImportResult> setLuaEnabled(
    Iterable<int> appIds,
    bool enabled, {
    TaskContext? context,
  }) => _batchLua(appIds, (game) => _moveLua(game, enabled), context: context);

  Future<ImportResult> deleteLuaFiles(
    Iterable<int> appIds, {
    TaskContext? context,
  }) => _batchLua(appIds, (game) async {
    final source = _luaFile(game.appId);
    await _backup(source);
    await source.delete();
  }, context: context);

  Future<ImportResult> _batchLua(
    Iterable<int> appIds,
    Future<void> Function(GameEntry game) action, {
    TaskContext? context,
  }) async {
    final written = <String>[];
    final errors = <String, String>{};
    try {
      for (final id in appIds.toSet()) {
        context?.checkCancelled();
        try {
          final game = _game(id);
          await action(game);
          written.add(game.luaPath!);
          context?.report('Updated $id.lua');
        } catch (error) {
          errors['$id'] = '$error';
        }
      }
    } finally {
      await scan();
    }
    return ImportResult(written: written, skipped: const [], errors: errors);
  }

  Future<void> deleteLua(int appId) async {
    final game = _game(appId);
    if (game.luaPath == null) throw StateError('No Lua file for App $appId');
    final source = File(game.luaPath!);
    await _backup(source);
    await source.delete();
    await scan();
  }

  Future<ImportResult> importFiles(
    List<String> sources, {
    bool overwrite = false,
    TaskContext? context,
  }) async {
    final root = await _requireSteam();
    final customLua = settings.get<String>('luaPath', '');
    final luaRoot = _luaDirectories(root, customLua).first;
    final written = <String>[];
    final skipped = <String>[];
    final errors = <String, String>{};
    for (final source in sources) {
      context?.checkCancelled();
      try {
        final type = await FileSystemEntity.type(source, followLinks: false);
        if (type == FileSystemEntityType.link) {
          throw const FormatException('Symbolic links cannot be imported');
        }
        if (type == FileSystemEntityType.directory) {
          final files = await Directory(source)
              .list(recursive: true, followLinks: false)
              .where((e) => e is File)
              .cast<File>()
              .toList();
          for (final file in files) {
            context?.checkCancelled();
            if (!_contentExtensions.contains(
              p.extension(file.path).toLowerCase(),
            )) {
              continue;
            }
            await _writeImport(
              file.readAsBytes,
              p.relative(file.path, from: source),
              root,
              luaRoot,
              overwrite,
              written,
              skipped,
            );
          }
        } else if (type == FileSystemEntityType.file) {
          final extension = p.extension(source).toLowerCase();
          if (_contentExtensions.contains(extension)) {
            await _writeImport(
              File(source).readAsBytes,
              p.basename(source),
              root,
              luaRoot,
              overwrite,
              written,
              skipped,
            );
          } else if (['.zip', '.tar', '.tgz', '.gz'].contains(extension)) {
            final sourceBytes = await File(source).readAsBytes();
            final entries = await _decodeInIsolate(sourceBytes, extension);
            var total = 0;
            for (final entry in entries) {
              context?.checkCancelled();
              if (!entry.isFile) continue;
              if (entry.isSymbolicLink) {
                throw FormatException('Archive contains a link: ${entry.name}');
              }
              _archiveRelative(entry.name);
              total += entry.size;
              if (total > 1024 * 1024 * 1024 || entries.length > 10000) {
                throw const FormatException('Archive exceeds import limit');
              }
              if (!_contentExtensions.contains(
                p.extension(entry.name).toLowerCase(),
              )) {
                continue;
              }
              await _writeImport(
                () async => entry.readBytes() ?? <int>[],
                entry.name,
                root,
                luaRoot,
                overwrite,
                written,
                skipped,
              );
            }
          } else if (['.7z', '.rar'].contains(extension)) {
            await _importNativeArchive(
              source,
              root,
              luaRoot,
              overwrite,
              written,
              skipped,
              context,
            );
          } else {
            throw FormatException('Unsupported import file: $extension');
          }
        } else {
          throw FileSystemException('Import source does not exist', source);
        }
        context?.report('Imported ${p.basename(source)}');
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        errors[source] = error.toString();
      }
    }
    await scan(context: context);
    return ImportResult(written: written, skipped: skipped, errors: errors);
  }

  Future<void> _importNativeArchive(
    String archive,
    String root,
    String luaRoot,
    bool overwrite,
    List<String> written,
    List<String> skipped,
    TaskContext? context,
  ) async {
    // Windows bsdtar reads 7z/RAR; each selected file is streamed, never extracted by a shell.
    final listing = await _run('tar.exe', ['-tf', archive]);
    if (listing.exitCode != 0) {
      throw ProcessException(
        'tar.exe',
        ['-tf', archive],
        _output(listing.stderr),
        listing.exitCode,
      );
    }
    final names = const LineSplitter().convert(_output(listing.stdout));
    if (names.length > 10000) {
      throw const FormatException('Archive exceeds entry limit');
    }
    var total = 0;
    for (final name in names) {
      context?.checkCancelled();
      _archiveRelative(name);
      if (!_contentExtensions.contains(p.extension(name).toLowerCase())) {
        continue;
      }
      final data = await _run('tar.exe', ['-xOf', archive, '--', name]);
      if (data.exitCode != 0) {
        throw ProcessException(
          'tar.exe',
          ['-xOf', archive, '--', name],
          _output(data.stderr),
          data.exitCode,
        );
      }
      final bytes = data.stdout is List<int>
          ? data.stdout as List<int>
          : utf8.encode(data.stdout.toString());
      total += bytes.length;
      if (total > 1024 * 1024 * 1024) {
        throw const FormatException('Archive exceeds size limit');
      }
      await _writeImport(
        () async => bytes,
        name,
        root,
        luaRoot,
        overwrite,
        written,
        skipped,
      );
    }
  }

  static const _contentExtensions = {'.lua', '.bin', '.manifest'};

  static Future<Archive> _decodeInIsolate(List<int> bytes, String extension) =>
      Isolate.run(() => _decodeArchive(bytes, extension));

  static Archive _decodeArchive(List<int> bytes, String extension) {
    if (extension == '.zip') {
      return ZipDecoder().decodeBytes(bytes, verify: true);
    }
    if (extension == '.gz' || extension == '.tgz') {
      return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    }
    return TarDecoder().decodeBytes(bytes);
  }

  Future<void> _writeImport(
    Future<List<int>> Function() read,
    String relative,
    String root,
    String luaRoot,
    bool overwrite,
    List<String> written,
    List<String> skipped,
  ) async {
    final normalized = _archiveRelative(relative);
    final extension = p.extension(normalized).toLowerCase();
    final targetRoot = switch (extension) {
      '.lua' => luaRoot,
      '.bin' => p.join(root, 'appcache', 'stats'),
      '.manifest' => p.join(root, 'depotcache'),
      _ => throw FormatException('Unsupported content: $relative'),
    };
    final parts = p.split(normalized);
    final markerIndex = switch (extension) {
      '.lua' => parts.lastIndexWhere(
        (part) =>
            part.toLowerCase() == 'lua' || part.toLowerCase() == 'stplug-in',
      ),
      '.bin' => parts.indexWhere((part) => part.toLowerCase() == 'stats'),
      _ => parts.indexWhere((part) => part.toLowerCase() == 'depotcache'),
    };
    final destinationRelative = markerIndex >= 0
        ? p.joinAll(parts.skip(markerIndex + 1))
        : normalized;
    final target = File(_safeChild(targetRoot, destinationRelative));
    if (await target.exists()) {
      if (!overwrite) {
        skipped.add(target.path);
        return;
      }
      await _backup(target);
    }
    await _rejectLinkedParents(targetRoot, target.path);
    final bytes = await read();
    if (extension == '.lua') {
      final appId = int.tryParse(p.basenameWithoutExtension(target.path));
      if (appId == null || appId <= 0) {
        throw FormatException('Lua filename must be an AppID: $relative');
      }
      utf8.decode(bytes);
    }
    await target.parent.create(recursive: true);
    await _atomicWrite(target, bytes);
    written.add(target.path);
  }

  Future<void> launch(int appId) async {
    final game = _game(appId);
    if (game.isRunning) {
      throw StateError('Game is already running');
    }
    final executable = game.executablePath;
    if (executable == null || !await File(executable).exists()) {
      await _launchSteamUri('steam://rungameid/$appId');
      return;
    }
    if (Platform.isWindows) {
      await startSteam();
    }
    final process = await Process.start(
      executable,
      const [],
      workingDirectory: p.dirname(executable),
      environment: {'SteamAppId': '$appId', 'SteamGameId': '$appId'},
    );
    // Drain redirected streams so a verbose game cannot block on a full pipe.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final session = _GameSession(process, DateTime.now(), executable);
    _sessions[appId] = session;
    _runningSince.putIfAbsent(appId, () => session.startedAt);
    _replace(game.copyWith(isRunning: true));
    unawaited(process.exitCode.then((_) => _finishSession(appId, session)));
  }

  Future<void> stop(int appId) async {
    final session = _sessions[appId];
    if (session == null) {
      final observed = List<RunningProcess>.of(
        _observedProcesses[appId] ?? const [],
      );
      if (observed.isEmpty) throw StateError('Game is no longer running');
      for (final process in observed) {
        await _stopObserved(process);
      }
      await refreshRunningProcesses();
      return;
    }
    if (Platform.isWindows) {
      final result = await _run('taskkill.exe', [
        '/PID',
        '${session.process.pid}',
        '/T',
        '/F',
      ]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'taskkill.exe',
          const [],
          _output(result.stderr),
          result.exitCode,
        );
      }
    } else if (!session.process.kill()) {
      throw StateError('Unable to stop game process');
    }
    await session.process.exitCode;
  }

  Future<void> _finishSession(int appId, _GameSession session) async {
    if (!identical(_sessions[appId], session)) return;
    _sessions.remove(appId);
    _observedProcesses[appId]?.removeWhere(
      (process) => process.pid == session.process.pid,
    );
    await _syncRunningState();
    _emit();
  }

  Future<void> openDirectory(int appId) async {
    final game = _game(appId);
    final directory =
        game.installPath ??
        (game.luaPath != null ? p.dirname(game.luaPath!) : null);
    if (directory == null || !await Directory(directory).exists()) {
      throw StateError('Game directory is unavailable');
    }
    if (!await _open(Uri.directory(directory, windows: Platform.isWindows))) {
      throw StateError('Cannot open game directory');
    }
  }

  Future<void> install(int appId) => _launchSteamUri('steam://install/$appId');

  Future<void> _launchSteamUri(String uri) async {
    if (!await _open(Uri.parse(uri))) {
      throw StateError('Steam could not handle $uri');
    }
  }

  Future<List<SteamLocalAccount>> listAccounts() async {
    final root = _steamPath ?? await detectSteamPath();
    if (root == null) return [];
    final file = File(p.join(root, 'config', 'loginusers.vdf'));
    if (!await file.exists()) return [];
    final parsed = Kv1.parse(await file.readAsString());
    final users = _mapValue(parsed, 'users') ?? parsed;
    final accounts = <SteamLocalAccount>[];
    for (final item in users.entries) {
      if (item.value is! Map) continue;
      final data = item.value as Map;
      final account = _stringValue(data, 'AccountName');
      if (account.isEmpty) continue;
      final persona = _stringValue(data, 'PersonaName');
      accounts.add(
        SteamLocalAccount(
          steamId: item.key,
          accountName: account,
          personaName: persona.isEmpty ? account : persona,
          mostRecent: _stringValue(data, 'MostRecent') == '1',
        ),
      );
    }
    accounts.sort(
      (a, b) => a.mostRecent == b.mostRecent
          ? a.personaName.compareTo(b.personaName)
          : (a.mostRecent ? -1 : 1),
    );
    return accounts;
  }

  Future<void> refreshAccounts() async {
    _accounts = await listAccounts();
    _emit();
  }

  Future<SteamUpdateControlSettings> readSteamUpdateControl() async {
    final root = await _requireSteam();
    final file = File(p.join(root, 'Steam.cfg'));
    if (!await file.exists()) return const SteamUpdateControlSettings();
    final lines = const LineSplitter().convert(await file.readAsString());
    final values = <String, String>{};
    for (final line in lines) {
      final text = line.trim();
      if (text.isEmpty || text.startsWith('#') || text.startsWith('//')) {
        continue;
      }
      final separator = text.indexOf('=');
      if (separator <= 0) continue;
      values[text.substring(0, separator).trim().toLowerCase()] = text
          .substring(separator + 1)
          .trim()
          .toLowerCase();
    }
    return SteamUpdateControlSettings(
      disableUpdateCheck: values['bootstrapperinhibitall'] == 'enable',
      disableForcedUpdate: values['bootstrapperforceselfupdate'] == 'disable',
    );
  }

  Future<SteamUpdateControlSettings> setSteamUpdateControl(
    SteamUpdateControlSettings value,
  ) async {
    final root = await _requireSteam();
    final file = File(p.join(root, 'Steam.cfg'));
    final exists = await file.exists();
    final lines = exists
        ? const LineSplitter().convert(await file.readAsString())
        : <String>[];
    _setCfgValue(
      lines,
      'BootStrapperInhibitAll',
      value.disableUpdateCheck ? 'enable' : null,
    );
    _setCfgValue(
      lines,
      'BootStrapperForceSelfUpdate',
      value.disableForcedUpdate ? 'disable' : null,
    );
    if (exists) await _backup(file);
    if (exists || lines.any((line) => line.trim().isNotEmpty)) {
      await _atomicWrite(file, utf8.encode('${lines.join('\n')}\n'));
    }
    return readSteamUpdateControl();
  }

  static void _setCfgValue(List<String> lines, String key, String? value) {
    final indices = <int>[];
    for (var index = 0; index < lines.length; index++) {
      final text = lines[index].trim();
      if (text.isEmpty || text.startsWith('#') || text.startsWith('//')) {
        continue;
      }
      final separator = text.indexOf('=');
      if (separator > 0 &&
          text.substring(0, separator).trim().toLowerCase() ==
              key.toLowerCase()) {
        indices.add(index);
      }
    }
    if (value == null) {
      for (final index in indices.reversed) {
        lines.removeAt(index);
      }
      return;
    }
    if (indices.isEmpty) {
      lines.add('$key=$value');
      return;
    }
    lines[indices.first] = '$key=$value';
    for (final index in indices.skip(1).toList().reversed) {
      lines.removeAt(index);
    }
  }

  String? avatarPath(SteamLocalAccount account) {
    final root = _steamPath;
    if (root == null) return null;
    for (final extension in ['.png', '.jpg', '.jpeg']) {
      final path = p.join(
        root,
        'config',
        'avatarcache',
        '${account.steamId}$extension',
      );
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  Future<void> openSteamLogin() async {
    final root = await _requireSteam();
    if (!Platform.isWindows) {
      throw UnsupportedError('Steam account login requires Windows');
    }
    await stopSteam();
    final config = File(p.join(root, 'config', 'config.vdf'));
    if (await config.exists()) {
      try {
        final parsed = Kv1.parse(await config.readAsString());
        final install = _mapValue(parsed, 'InstallConfigStore');
        final software = install == null
            ? null
            : _mapValue(install, 'Software');
        final valve = software == null ? null : _mapValue(software, 'Valve');
        final steam = valve == null ? null : _mapValue(valve, 'Steam');
        if (steam != null) {
          steam['AlwaysShowUserChooser'] = '1';
          steam['RememberPassword'] = '0';
          await _backup(config);
          await _atomicWrite(config, utf8.encode(Kv1.stringify(parsed)));
        }
      } on FormatException {
        // Steam will still open its own login flow if config.vdf is unreadable.
      }
    }
    final usersFile = File(p.join(root, 'config', 'loginusers.vdf'));
    if (await usersFile.exists()) {
      final parsed = Kv1.parse(await usersFile.readAsString());
      final users = _mapValue(parsed, 'users') ?? parsed;
      for (final value in users.values) {
        if (value is! Map) continue;
        value['AutoLogin'] = '0';
        value['MostRecent'] = '0';
      }
      await _backup(usersFile);
      await _atomicWrite(usersFile, utf8.encode(Kv1.stringify(parsed)));
    }
    final steamKey = Registry.openPath(
      RegistryHive.currentUser,
      path: r'Software\Valve\Steam',
      desiredAccessRights: AccessRights.writeOnly,
    );
    try {
      if (steamKey.getValue('AutoLoginUser') != null) {
        steamKey.deleteValue('AutoLoginUser');
      }
      steamKey
        ..createValue(RegistryValue.int32('RememberPassword', 0))
        ..createValue(RegistryValue.int32('DontAutoLogin', 1))
        ..createValue(RegistryValue.int32('AlwaysShowUserChooser', 1));
    } finally {
      steamKey.close();
    }
    await _startSteamProcess(
      p.join(root, 'steam.exe'),
      const [],
      workingDirectory: root,
    );
  }

  Future<bool> isSteamRunning() async {
    if (!Platform.isWindows) return false;
    final list = await _run('tasklist.exe', [
      '/FI',
      'IMAGENAME eq steam.exe',
      '/FO',
      'CSV',
      '/NH',
    ]);
    if (list.exitCode != 0) {
      throw ProcessException(
        'tasklist.exe',
        const [],
        _output(list.stderr),
        list.exitCode,
      );
    }
    return _output(list.stdout).toLowerCase().contains('steam.exe');
  }

  Future<void> startSteam() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Starting Steam requires Windows');
    }
    final root = await _requireSteam();
    if (await isSteamRunning()) return;
    await _startSteamProcess(
      p.join(root, 'steam.exe'),
      const [],
      workingDirectory: root,
    );
  }

  Future<void> stopSteam() async {
    if (!Platform.isWindows) return;
    if (!await isSteamRunning()) return;
    final killed = await _run('taskkill.exe', ['/IM', 'steam.exe', '/T', '/F']);
    if (killed.exitCode != 0) {
      throw ProcessException(
        'taskkill.exe',
        const [],
        _output(killed.stderr),
        killed.exitCode,
      );
    }
    for (var attempt = 0; attempt < 50; attempt++) {
      if (!await isSteamRunning()) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Steam did not close in time');
  }

  Future<void> restartSteam() async {
    await stopSteam();
    await startSteam();
  }

  Future<void> switchAccount(String accountName) async {
    final accounts = await listAccounts();
    if (!accounts.any((account) => account.accountName == accountName)) {
      throw ArgumentError.value(
        accountName,
        'accountName',
        'Unknown local Steam account',
      );
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Steam account switching requires Windows');
    }
    final root = await _requireSteam();
    await stopSteam();
    final loginFile = File(p.join(root, 'config', 'loginusers.vdf'));
    if (await loginFile.exists()) {
      final parsed = Kv1.parse(await loginFile.readAsString());
      final users = _mapValue(parsed, 'users');
      if (users != null) {
        for (final value in users.values) {
          if (value is! Map) continue;
          final selected = _stringValue(value, 'AccountName') == accountName;
          value['MostRecent'] = selected ? '1' : '0';
          value['AutoLogin'] = selected ? '1' : '0';
        }
        await _backup(loginFile);
        await _atomicWrite(loginFile, utf8.encode(Kv1.stringify(parsed)));
      }
    }
    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: r'Software\Valve\Steam',
      desiredAccessRights: AccessRights.writeOnly,
    );
    try {
      key.createValue(RegistryValue.string('AutoLoginUser', accountName));
    } finally {
      key.close();
    }
    await _startSteamProcess(
      p.join(root, 'steam.exe'),
      const [],
      workingDirectory: root,
    );
  }

  Future<void> setOfflineMode(bool offline) async {
    final root = await _requireSteam();
    final file = File(p.join(root, 'config', 'loginusers.vdf'));
    final parsed = Kv1.parse(await file.readAsString());
    final users = _mapValue(parsed, 'users');
    if (users == null) {
      throw const FormatException('Steam account list is empty');
    }
    final recent = users.values
        .whereType<Map>()
        .where((user) => _stringValue(user, 'MostRecent') == '1')
        .firstOrNull;
    if (recent == null) throw StateError('No recently signed-in Steam account');
    recent['WantsOfflineMode'] = offline ? '1' : '0';
    recent['SkipOfflineModeWarning'] = offline ? '1' : '0';
    await _backup(file);
    await _atomicWrite(file, utf8.encode(Kv1.stringify(parsed)));
    await settings.set('offlineMode', offline);
  }

  Future<String> _requireSteam() async {
    final root = _steamPath ?? await detectSteamPath();
    if (root == null) {
      throw StateError('Select the Steam installation directory first');
    }
    return root;
  }

  Future<({String steam, String lua})> contentDirectories() async {
    final steam = await _requireSteam();
    return (
      steam: steam,
      lua: _luaDirectories(steam, settings.get<String>('luaPath', '')).first,
    );
  }

  GameEntry _game(int appId) => _games.firstWhere(
    (game) => game.appId == appId,
    orElse: () => throw StateError('App $appId is not in the library'),
  );

  void _replace(GameEntry game) {
    _games = _games
        .map((item) => item.appId == game.appId ? game : item)
        .toList();
    _emit();
  }

  Future<void> _updateRecord(int appId, Map<String, dynamic> changes) {
    final write = _recordWrite.then((_) async {
      final file = File(paths.file(p.join('data', 'library.json')));
      final records = _readRecordsSync(file.path);
      final current = records['$appId'] is Map
          ? Map<String, dynamic>.from(records['$appId'] as Map)
          : <String, dynamic>{};
      records['$appId'] = {...current, ...changes};
      await file.parent.create(recursive: true);
      await _atomicWrite(
        file,
        utf8.encode(const JsonEncoder.withIndent('  ').convert(records)),
      );
    });
    _recordWrite = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return write;
  }

  Future<void> _backup(File file) async {
    if (!await file.exists()) return;
    final backup = File(
      paths.file(
        p.join(
          'backups',
          'library',
          '${DateTime.now().microsecondsSinceEpoch}-${p.basename(file.path)}',
        ),
      ),
    );
    await backup.parent.create(recursive: true);
    await file.copy(backup.path);
  }

  static Future<void> _atomicWrite(File file, List<int> bytes) async {
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static Future<void> _rejectLinkedParents(String root, String target) async {
    var current = Directory(p.dirname(target));
    final rootPath = p.normalize(p.absolute(root));
    while (p.isWithin(rootPath, current.path) ||
        p.equals(rootPath, current.path)) {
      if (await FileSystemEntity.type(current.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw FileSystemException(
          'Import destination contains a symbolic link',
          current.path,
        );
      }
      if (p.equals(rootPath, current.path)) break;
      current = current.parent;
    }
    if (await FileSystemEntity.type(target, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FileSystemException(
        'Import destination is a symbolic link',
        target,
      );
    }
  }

  static Map<String, dynamic> _readRecordsSync(String path) {
    final file = File(path);
    if (!file.existsSync()) return {};
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid library records');
    }
    return decoded;
  }

  static List<String> _luaDirectories(String root, String customLua) {
    if (customLua.trim().isNotEmpty) {
      return [
        p.normalize(
          p.isAbsolute(customLua) ? customLua : p.join(root, customLua),
        ),
      ];
    }
    final toml = File(p.join(root, 'opensteamtool.toml'));
    if (toml.existsSync()) {
      final section = RegExp(
        r'\[lua\]([\s\S]*?)(?=\n\s*\[|$)',
      ).firstMatch(toml.readAsStringSync());
      final list = section == null
          ? null
          : RegExp(r'paths\s*=\s*\[([\s\S]*?)\]').firstMatch(section.group(1)!);
      if (list != null) {
        final matches = RegExp(
          r'''["']([^"']+)["']''',
        ).allMatches(list.group(1)!);
        final paths = matches
            .map((match) => match.group(1)!.replaceAll(r'\\', r'\'))
            .where((path) => path.trim().isNotEmpty)
            .map(
              (path) =>
                  p.normalize(p.isAbsolute(path) ? path : p.join(root, path)),
            )
            .toList();
        if (paths.isNotEmpty) return paths;
      }
    }
    return [p.join(root, 'config', 'stplug-in')];
  }

  static String _archiveRelative(String name) {
    final normalized = name.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized) ||
        normalized
            .split('/')
            .any(
              (part) =>
                  part == '..' || part.contains(':') || part.contains('\u0000'),
            )) {
      throw FormatException('Archive path escapes import root: $name');
    }
    return p.joinAll(
      normalized.split('/').where((part) => part.isNotEmpty && part != '.'),
    );
  }

  static String _safeChild(String root, String relative) {
    final child = p.normalize(p.join(root, _archiveRelative(relative)));
    if (!p.isWithin(p.normalize(root), child)) {
      throw FormatException('Path escapes root: $relative');
    }
    return child;
  }

  static Map<String, dynamic>? _mapValue(
    Map<dynamic, dynamic> source,
    String key,
  ) {
    for (final entry in source.entries) {
      if (entry.key.toString().toLowerCase() == key.toLowerCase() &&
          entry.value is Map) {
        return (entry.value as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  static String _stringValue(Map<dynamic, dynamic> source, String key) {
    for (final entry in source.entries) {
      if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
        return entry.value?.toString() ?? '';
      }
    }
    return '';
  }

  static String _output(Object? value) => value is List<int>
      ? utf8.decode(value, allowMalformed: true)
      : value?.toString() ?? '';

  static String? _findExecutable(String root) {
    const excluded = [
      'launcher',
      'setup',
      'install',
      'unins',
      'crash',
      'redist',
      'helper',
      'anticheat',
      'easyanti',
      'benchmark',
      'dotnet',
      'editor',
    ];
    final candidates = <(File, int)>[];
    void collect(Directory directory, int depth) {
      try {
        for (final entity in directory.listSync(followLinks: false)) {
          final name = p.basename(entity.path).toLowerCase();
          if (excluded.any(name.contains)) continue;
          if (entity is File && name.endsWith('.exe')) {
            candidates.add((entity, depth));
          }
          if (entity is Directory && depth < 3) collect(entity, depth + 1);
        }
      } on FileSystemException {
        // An unreadable optional executable directory does not invalidate its manifest.
      }
    }

    collect(Directory(root), 0);
    candidates.sort((a, b) {
      final depth = a.$2.compareTo(b.$2);
      if (depth != 0) return depth;
      return b.$1.lengthSync().compareTo(a.$1.lengthSync());
    });
    return candidates.firstOrNull?.$1.path;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _processMonitoring = false;
    _processTimer?.cancel();
    super.dispose();
  }
}
