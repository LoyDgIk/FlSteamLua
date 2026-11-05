import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/app_release.dart';
import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../platform/desktop/startup_registration.dart';
import '../../platform/desktop/update_service.dart';
import '../library/kv1.dart';
import '../library/library_service.dart';
import '../library/lua_directories.dart';
import '../network/network_preferences.dart';
import '../../ui/localization.dart';

typedef PreferencesTimerFactory =
    Timer Function(Duration interval, void Function(Timer timer) callback);
typedef PreferencesUpdateFactory = UpdateService Function(String repository);

/// App-owned preferences keep background work alive when a settings page closes.
class PreferencesController extends ChangeNotifier {
  PreferencesController({
    required this.paths,
    required this.settings,
    required this.library,
    required this.tasks,
    this.currentVersion = appVersion,
    StartupRegistration? startup,
    PreferencesTimerFactory? periodicTimer,
    PreferencesUpdateFactory? updateFactory,
    Future<void> Function()? libraryRefresh,
    this.keyCacheUpdateDue,
    this.watchFiles = true,
    bool? supportsStartup,
  }) : _startup = startup ?? StartupRegistration(),
       _periodic = periodicTimer ?? Timer.periodic,
       _updateFactory =
           updateFactory ??
           ((repo) => UpdateService(
             repository: repo,
             client: NetworkHttpClient(settings: settings),
             closeClient: true,
           )),
       _libraryRefresh = libraryRefresh ?? (() => library.refresh()),
       supportsStartup = supportsStartup ?? Platform.isWindows;

  final AppPaths paths;
  final SettingsStore settings;
  final LibraryService library;
  final TaskCenter tasks;
  final String currentVersion;
  final bool supportsStartup;
  final bool watchFiles;
  final Future<void> Function()? keyCacheUpdateDue;
  final StartupRegistration _startup;
  final PreferencesTimerFactory _periodic;
  final PreferencesUpdateFactory _updateFactory;
  final Future<void> Function() _libraryRefresh;
  final Set<Future<void>> _background = {};
  final List<StreamSubscription<FileSystemEvent>> _watchers = [];
  Timer? _refreshTimer;
  Timer? _updateTimer;
  Timer? _keyCacheTimer;
  Timer? _fileDebounce;
  Future<void>? _refreshWork;
  Future<void>? _keyCacheWork;
  Future<ApplicationRelease?>? _updateWork;
  String? _refreshSignature;
  String? _updateSignature;
  bool? _keyCacheEnabled;
  String? _watchSignature;
  int _watchGeneration = 0;
  bool _initialized = false;
  bool _stopping = false;
  bool _disposed = false;

  bool? startupEnabled;
  bool? offlineEnabled;
  ApplicationRelease? updateRelease;
  Object? updateError;
  DateTime? updateCheckedAt;
  Object? platformError;
  Object? backgroundError;

  bool get isCheckingUpdate => _updateWork != null;
  bool get autoRefresh => settings.get<bool>('autoLibraryRefresh', true);
  bool get autoUpdateCheck => settings.get<bool>('autoCheckUpdates', true);
  bool get autoKeyCacheUpdate =>
      settings.get<bool>('autoUpdateKeyCache', false);
  int get refreshSeconds => settings.get<int>('libraryRefreshSeconds', 30);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    settings.addListener(_settingsChanged);
    library.addListener(_libraryChanged);
    _settingsChanged();
    await refreshPlatformState();
  }

  Future<void> setAutoRefresh(bool enabled) =>
      settings.set('autoLibraryRefresh', enabled);

  Future<void> setRefreshSeconds(int seconds) {
    if (seconds < 5 || seconds > 3600) {
      throw ArgumentError.value(seconds, 'seconds', 'Use 5 to 3600 seconds');
    }
    return settings.set('libraryRefreshSeconds', seconds);
  }

  Future<void> setAutoUpdateCheck(bool enabled) =>
      settings.set('autoCheckUpdates', enabled);

  Future<void> setAutoKeyCacheUpdate(bool enabled) =>
      settings.set('autoUpdateKeyCache', enabled);

  void _settingsChanged() {
    if (_stopping || _disposed) return;
    final refresh = '$autoRefresh:$refreshSeconds';
    if (_refreshSignature != refresh) {
      _refreshSignature = refresh;
      _refreshTimer?.cancel();
      _refreshTimer = autoRefresh
          ? _periodic(
              Duration(seconds: refreshSeconds.clamp(5, 3600).toInt()),
              (_) {
                _launch(_refreshLibrary);
              },
            )
          : null;
    }
    final repo = settings.releaseRepository;
    final update = '$autoUpdateCheck:$repo';
    if (_updateSignature != update) {
      _updateSignature = update;
      _updateTimer?.cancel();
      _updateTimer = null;
      updateRelease = null;
      updateError = null;
      updateCheckedAt = null;
      if (autoUpdateCheck && _configuredRepository(repo)) {
        _launch(() async {
          await checkUpdates();
        });
        _updateTimer = _periodic(const Duration(hours: 24), (_) {
          _launch(() async {
            await checkUpdates();
          });
        });
      }
    }
    if (_keyCacheEnabled != autoKeyCacheUpdate) {
      _keyCacheEnabled = autoKeyCacheUpdate;
      _keyCacheTimer?.cancel();
      _keyCacheTimer = null;
      if (autoKeyCacheUpdate && keyCacheUpdateDue != null) {
        _launch(_updateKeyCache);
        _keyCacheTimer = _periodic(const Duration(hours: 1), (_) {
          _launch(_updateKeyCache);
        });
      }
    }
    _configureWatchers();
    _emit();
  }

  static bool _configuredRepository(String repository) =>
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository);

  void _libraryChanged() {
    if (!_stopping && !_disposed) _configureWatchers();
  }

  void _configureWatchers() {
    if (!watchFiles) return;
    final targets = <String, bool>{};
    if (autoRefresh) {
      final root = settings.steamPath.isNotEmpty
          ? settings.steamPath
          : library.steamPath;
      if (root != null && root.isNotEmpty) {
        targets[p.join(root, 'config')] = false;
        targets[p.join(root, 'steamapps')] = false;
        for (final path in LuaDirectories(root).loadOrder) {
          targets[path] = true;
        }
        targets[root] = false;
      }
      for (final game in library.games) {
        if (game.libraryPath != null) {
          targets[p.join(game.libraryPath!, 'steamapps')] = false;
        }
        if (game.luaPath != null) targets[p.dirname(game.luaPath!)] = true;
      }
    }
    final signature = targets.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    if (signature == _watchSignature) return;
    _watchSignature = signature;
    final generation = ++_watchGeneration;
    _launch(() => _replaceWatchers(targets, generation));
  }

  Future<void> _replaceWatchers(
    Map<String, bool> targets,
    int generation,
  ) async {
    final old = List.of(_watchers);
    _watchers.clear();
    for (final watcher in old) {
      await watcher.cancel();
    }
    for (final target in targets.entries) {
      if (_stopping || _disposed || generation != _watchGeneration) return;
      final directory = Directory(target.key);
      if (!await directory.exists()) continue;
      if (_stopping || _disposed || generation != _watchGeneration) return;
      _watchers.add(
        directory
            .watch(recursive: target.value)
            .listen(
              _fileChanged,
              onError: (Object error) {
                backgroundError = error;
                _emit();
              },
            ),
      );
    }
  }

  void _fileChanged(FileSystemEvent event) {
    if (_stopping || !autoRefresh) return;
    final name = p.basename(event.path).toLowerCase();
    if (!name.endsWith('.lua') &&
        !RegExp(r'^appmanifest_\d+\.acf$').hasMatch(name) &&
        name != 'libraryfolders.vdf' &&
        !name.endsWith('.toml')) {
      return;
    }
    _fileDebounce?.cancel();
    _fileDebounce = Timer(const Duration(milliseconds: 500), () {
      _launch(_refreshLibrary);
    });
  }

  Future<void> _refreshLibrary() {
    if (_stopping || !autoRefresh || library.isScanning) return Future.value();
    return _refreshWork ??= _libraryRefresh().whenComplete(() {
      _refreshWork = null;
      // Retry missing directories when a library or Lua folder is created later.
      _watchSignature = null;
      if (!_stopping && !_disposed) _configureWatchers();
    });
  }

  Future<void> _updateKeyCache() {
    if (_stopping || !autoKeyCacheUpdate || keyCacheUpdateDue == null) {
      return Future.value();
    }
    return _keyCacheWork ??= keyCacheUpdateDue!().whenComplete(() {
      _keyCacheWork = null;
    });
  }

  Future<ApplicationRelease?> checkUpdates() {
    if (_stopping) return Future.value();
    if (_updateWork != null) return _updateWork!;
    final repository = settings.releaseRepository;
    if (!_configuredRepository(repository)) {
      return Future.error(
        StateError(
          localizationsFor(
            settings.language,
          ).configureTheReleaseRepositoryForThisFlutterApplicationFirst,
        ),
      );
    }
    updateError = null;
    _updateWork = _checkUpdates(repository).whenComplete(() {
      _updateWork = null;
      _emit();
      final currentRepository = settings.releaseRepository;
      if (!_stopping &&
          autoUpdateCheck &&
          currentRepository != repository &&
          _configuredRepository(currentRepository)) {
        _launch(() async {
          await checkUpdates();
        });
      }
    });
    _emit();
    return _updateWork!;
  }

  Future<ApplicationRelease?> _checkUpdates(String repository) async {
    final service = _updateFactory(repository);
    try {
      final release = await tasks.run(
        localizationsFor(settings.language).checkApplicationUpdates,
        (_) => service.checkLatest(currentVersion),
      );
      if (settings.releaseRepository == repository) {
        updateRelease = release;
        updateCheckedAt = DateTime.now();
        updateError = null;
      }
      return release;
    } catch (error) {
      if (settings.releaseRepository == repository) {
        updateError = error;
      }
      rethrow;
    } finally {
      service.dispose();
    }
  }

  Future<void> refreshPlatformState() async {
    platformError = null;
    final errors = <String>[];
    if (supportsStartup) {
      try {
        startupEnabled = await _startup.isEnabled();
      } catch (error) {
        startupEnabled = null;
        errors.add('$error');
      }
    }
    final root = settings.steamPath.isNotEmpty
        ? settings.steamPath
        : library.steamPath;
    if (root != null && root.isNotEmpty) {
      try {
        final file = File(p.join(root, 'config', 'loginusers.vdf'));
        if (await file.exists()) {
          final values = Kv1.parse(await file.readAsString());
          final users = _value(values, 'users');
          final recent = users is Map
              ? users.values
                    .whereType<Map>()
                    .where((user) => _value(user, 'MostRecent') == '1')
                    .firstOrNull
              : null;
          offlineEnabled = recent == null
              ? null
              : _value(recent, 'WantsOfflineMode') == '1';
        } else {
          offlineEnabled = null;
        }
      } catch (error) {
        offlineEnabled = null;
        errors.add('$error');
      }
    } else {
      offlineEnabled = null;
    }
    platformError = errors.isEmpty ? null : errors.join('\n');
    _emit();
  }

  static dynamic _value(Map map, String key) => map.entries
      .where((entry) => entry.key.toString().toLowerCase() == key.toLowerCase())
      .firstOrNull
      ?.value;

  Future<void> setStartupEnabled(bool enabled) async {
    if (!supportsStartup) throw UnsupportedError('Startup requires Windows');
    await tasks.run(
      localizationsFor(settings.language).setStartupRegistration,
      (_) async {
        await _startup.setEnabled(enabled);
        startupEnabled = await _startup.isEnabled();
        _emit();
      },
    );
  }

  Future<void> setOfflineMode(bool enabled) async {
    await tasks.run(localizationsFor(settings.language).setSteamOfflineMode, (
      _,
    ) async {
      await library.setOfflineMode(enabled);
      offlineEnabled = enabled;
      _emit();
    });
  }

  void _launch(Future<void> Function() action) {
    if (_stopping || _disposed) return;
    late final Future<void> work;
    work = Future<void>.sync(action)
        .catchError((Object error) {
          backgroundError = error;
          _emit();
        })
        .whenComplete(() {
          _background.remove(work);
        });
    _background.add(work);
  }

  void _stop() {
    if (_stopping) return;
    _stopping = true;
    if (_initialized) {
      settings.removeListener(_settingsChanged);
      library.removeListener(_libraryChanged);
    }
    _refreshTimer?.cancel();
    _updateTimer?.cancel();
    _keyCacheTimer?.cancel();
    _fileDebounce?.cancel();
    _watchGeneration++;
  }

  Future<void> shutdown() async {
    _stop();
    final watchers = List.of(_watchers);
    _watchers.clear();
    for (final watcher in watchers) {
      await watcher.cancel();
    }
    await Future.wait(List.of(_background));
    try {
      await _updateWork;
    } catch (_) {
      /* State and task retain errors. */
    }
    try {
      await _refreshWork;
    } catch (_) {
      /* Background state retains errors. */
    }
    try {
      await _keyCacheWork;
    } catch (_) {
      /* Background state retains errors. */
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _stop();
    _disposed = true;
    for (final watcher in _watchers) {
      unawaited(watcher.cancel());
    }
    _watchers.clear();
    super.dispose();
  }
}
