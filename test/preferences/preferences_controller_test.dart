import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_release.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/preferences/preferences_controller.dart';
import 'package:fl_steam_lua/platform/desktop/startup_registration.dart';
import 'package:fl_steam_lua/platform/desktop/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

class _ManualTimer implements Timer {
  _ManualTimer(this.interval, this.callback);
  final Duration interval;
  final void Function(Timer) callback;
  bool _active = true;
  int _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    callback(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;
}

class _ManualTimers {
  final timers = <_ManualTimer>[];

  Timer create(Duration interval, void Function(Timer) callback) {
    final timer = _ManualTimer(interval, callback);
    timers.add(timer);
    return timer;
  }

  List<_ManualTimer> get active =>
      timers.where((timer) => timer.isActive).toList();

  _ManualTimer at(Duration interval) =>
      active.singleWhere((timer) => timer.interval == interval);
}

Future<void> _drain() => Future<void>.delayed(Duration.zero);

String _releaseJson([String version = 'v0.2.0']) => jsonEncode({
  'tag_name': version,
  'html_url': 'https://github.com/$appRepository/releases/tag/$version',
  'body': 'Fixture release notes',
  'assets': <Object>[],
});

void main() {
  late Directory directory;
  late AppPaths paths;
  late SettingsStore settings;
  late LibraryService library;
  late TaskCenter tasks;
  late _ManualTimers timers;
  PreferencesController? controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flsl-preferences-');
    paths = AppPaths(p.join(directory.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    await settings.set('autoCheckUpdates', false);
    library = LibraryService(paths: paths, settings: settings);
    tasks = TaskCenter();
    timers = _ManualTimers();
  });

  tearDown(() async {
    await controller?.shutdown();
    controller?.dispose();
    controller = null;
    library.dispose();
    tasks.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  PreferencesController create({
    Future<void> Function()? refresh,
    Future<void> Function()? keyCacheUpdate,
    Future<void> Function()? kernelUpdate,
    PreferencesUpdateFactory? updates,
    StartupRegistration? startup,
    bool supportsStartup = false,
  }) {
    final value = PreferencesController(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
      periodicTimer: timers.create,
      libraryRefresh: refresh ?? () async {},
      keyCacheUpdateDue: keyCacheUpdate,
      kernelUpdateCheck: kernelUpdate,
      updateFactory: updates,
      startup: startup,
      supportsStartup: supportsStartup,
      watchFiles: false,
    );
    controller = value;
    return value;
  }

  test('update checks always use the official repository', () async {
    await settings.set('releaseRepository', 'example/replacement');
    String? requestedRepository;
    final preferences = create(
      updates: (repository) {
        requestedRepository = repository;
        return UpdateService(
          repository: repository,
          client: MockClient((request) async {
            expect(request.url.path, '/repos/$appRepository/releases/latest');
            return http.Response(_releaseJson(), 200);
          }),
        );
      },
    );
    await preferences.initialize();
    expect(preferences.autoUpdateCheck, isFalse);
    expect(settings.releaseRepository, appRepository);
    expect(requestedRepository, isNull);
    final release = await preferences.checkUpdates();
    expect(requestedRepository, appRepository);
    expect(release?.version, 'v0.2.0');
  });

  test(
    'library refresh uses the saved interval and cancels when disabled',
    () async {
      var refreshes = 0;
      final preferences = create(
        refresh: () async {
          refreshes++;
        },
      );
      await preferences.initialize();
      final original = timers.at(const Duration(seconds: 30));
      original.fire();
      await _drain();
      expect(refreshes, 1);
      await preferences.setRefreshSeconds(60);
      expect(original.isActive, isFalse);
      final replacement = timers.at(const Duration(seconds: 60));
      replacement.fire();
      await _drain();
      expect(refreshes, 2);
      await preferences.setAutoRefresh(false);
      expect(replacement.isActive, isFalse);
      expect(timers.active, isEmpty);
      replacement.fire();
      await _drain();
      expect(refreshes, 2);
      expect(settings.get<int>('libraryRefreshSeconds', 0), 60);
      expect(settings.get<bool>('autoLibraryRefresh', true), isFalse);
    },
  );

  test(
    'refresh is not reentered and shutdown waits for in-flight work',
    () async {
      final pending = Completer<void>();
      var refreshes = 0;
      final preferences = create(
        refresh: () {
          refreshes++;
          return pending.future;
        },
      );
      await preferences.initialize();
      final timer = timers.at(const Duration(seconds: 30));
      timer.fire();
      timer.fire();
      expect(refreshes, 1);
      var stopped = false;
      final shutdown = preferences.shutdown().then((_) {
        stopped = true;
      });
      await _drain();
      expect(stopped, isFalse);
      expect(timers.active, isEmpty);
      pending.complete();
      await shutdown;
      timer.fire();
      await preferences.setAutoRefresh(true);
      await _drain();
      expect(refreshes, 1);
      expect(timers.active, isEmpty);
    },
  );

  test('a disabled refresh preference never starts a timer', () async {
    await settings.set('autoLibraryRefresh', false);
    final preferences = create();
    await preferences.initialize();
    expect(timers.active, isEmpty);
    await preferences.setAutoRefresh(true);
    expect(timers.at(const Duration(seconds: 30)).isActive, isTrue);
  });

  test('automatic update intervals default to one day', () {
    final preferences = create();
    expect(preferences.appUpdateIntervalSeconds, 86400);
    expect(preferences.kernelUpdateIntervalSeconds, 86400);
  });

  test('automatic update intervals can be configured independently', () async {
    final preferences = create();
    await preferences.setAppUpdateIntervalSeconds(3600);
    await preferences.setKernelUpdateIntervalSeconds(604800);
    expect(preferences.appUpdateIntervalSeconds, 3600);
    expect(preferences.kernelUpdateIntervalSeconds, 604800);
  });

  test(
    'application update checks honor the persisted interval and default day',
    () async {
      await settings.set('autoLibraryRefresh', false);
      await settings.set('autoCheckUpdates', true);
      await settings.set('appUpdateIntervalSeconds', 21600);
      await settings.set(
        'appUpdateLastCheckAt',
        DateTime.now().toUtc().toIso8601String(),
      );
      var requests = 0;
      final preferences = create(
        updates: (repository) => UpdateService(
          repository: repository,
          client: MockClient((_) async {
            requests++;
            return http.Response(_releaseJson(), 200);
          }),
        ),
      );
      await preferences.initialize();
      await _drain();
      expect(requests, 0);
      final timer = timers.at(const Duration(hours: 6));
      timer.fire();
      await _drain();
      expect(requests, 0);

      await settings.set(
        'appUpdateLastCheckAt',
        DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 7))
            .toIso8601String(),
      );
      timer.fire();
      await _drain();
      expect(requests, 1);
      expect(preferences.appUpdateIntervalSeconds, 21600);
    },
  );

  test(
    'kernel update checks use their own interval and can be disabled',
    () async {
      await settings.set('autoLibraryRefresh', false);
      await settings.set('autoCheckUpdates', false);
      await settings.set('autoCheckKernelUpdate', true);
      await settings.set('kernelUpdateIntervalSeconds', 21600);
      await settings.set(
        'kernelUpdateLastCheckAt',
        DateTime.now().toUtc().toIso8601String(),
      );
      var checks = 0;
      final preferences = create(
        kernelUpdate: () async {
          checks++;
        },
      );
      await preferences.initialize();
      await _drain();
      expect(checks, 0);
      final timer = timers.at(const Duration(hours: 6));
      await settings.set(
        'kernelUpdateLastCheckAt',
        DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 7))
            .toIso8601String(),
      );
      timer.fire();
      await _drain();
      expect(checks, 1);
      await preferences.setAutoKernelUpdateCheck(false);
      expect(timer.isActive, isFalse);
    },
  );

  test(
    'automatic and manual update checks share one in-flight request',
    () async {
      await settings.set('autoCheckUpdates', true);
      final response = Completer<http.Response>();
      var requests = 0;
      final client = MockClient((request) {
        requests++;
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, '/repos/$appRepository/releases/latest');
        return response.future;
      });
      addTearDown(client.close);
      final preferences = create(
        updates: (repository) =>
            UpdateService(repository: repository, client: client),
      );
      await preferences.initialize();
      final first = preferences.checkUpdates();
      final second = preferences.checkUpdates();
      expect(identical(first, second), isTrue);
      expect(preferences.isCheckingUpdate, isTrue);
      response.complete(http.Response(_releaseJson(), 200));
      final release = await first;
      await second;
      expect(requests, 1);
      expect(release?.version, 'v0.2.0');
      expect(identical(preferences.updateRelease, release), isTrue);
      expect(preferences.updateCheckedAt, isNotNull);
      expect(preferences.updateError, isNull);
      expect(preferences.isCheckingUpdate, isFalse);
      expect(tasks.tasks.single.status, TaskStatus.succeeded);
      final timer = timers.at(const Duration(hours: 24));
      await preferences.setAutoUpdateCheck(false);
      expect(timer.isActive, isFalse);
      expect(
        timers.active.any(
          (timer) => timer.interval == const Duration(hours: 24),
        ),
        isFalse,
      );
    },
  );

  test(
    'update failures remain failures in controller state and task history',
    () async {
      await settings.set('autoCheckUpdates', false);
      final client = MockClient((_) async => http.Response('{}', 403));
      addTearDown(client.close);
      final preferences = create(
        updates: (repository) =>
            UpdateService(repository: repository, client: client),
      );
      await preferences.initialize();
      await expectLater(
        preferences.checkUpdates(),
        throwsA(isA<HttpException>()),
      );
      expect(preferences.updateError, isA<HttpException>());
      expect(preferences.updateRelease, isNull);
      expect(preferences.updateCheckedAt, isNull);
      expect(preferences.isCheckingUpdate, isFalse);
      expect(tasks.tasks.single.status, TaskStatus.failed);
      expect(tasks.tasks.single.error, isA<HttpException>());
    },
  );

  test(
    'an automatic update failure is surfaced without an unhandled future',
    () async {
      await settings.set('autoCheckUpdates', true);
      final client = MockClient((_) async => http.Response('{}', 503));
      addTearDown(client.close);
      final preferences = create(
        updates: (repository) =>
            UpdateService(repository: repository, client: client),
      );
      await preferences.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(preferences.updateError, isA<HttpException>());
      expect(preferences.backgroundError, isA<HttpException>());
      expect(tasks.tasks.single.status, TaskStatus.failed);
    },
  );

  test(
    'key subscriptions only update after opt-in and stop when disabled',
    () async {
      var updates = 0;
      final preferences = create(
        keyCacheUpdate: () async {
          updates++;
        },
      );
      await preferences.initialize();
      await _drain();
      expect(updates, 0);
      expect(preferences.autoKeyCacheUpdate, isFalse);
      expect(
        timers.active.any(
          (timer) => timer.interval == const Duration(hours: 1),
        ),
        isFalse,
      );
      await preferences.setAutoKeyCacheUpdate(true);
      await _drain();
      expect(updates, 1);
      final timer = timers.at(const Duration(hours: 1));
      timer.fire();
      await _drain();
      expect(updates, 2);
      await preferences.setAutoKeyCacheUpdate(false);
      expect(timer.isActive, isFalse);
      timer.fire();
      await _drain();
      expect(updates, 2);
      expect(settings.get<bool>('autoUpdateKeyCache', true), isFalse);
    },
  );

  test(
    'startup registration is read separately and written only on a toggle',
    () async {
      final commands = <List<String>>[];
      var enabled = false;
      const executable = r'C:\Fixture\FlSteamLua.exe';
      final startup = StartupRegistration(
        executable: executable,
        runner: (command, args) async {
          expect(command, 'reg.exe');
          commands.add(List.of(args));
          switch (args.first) {
            case 'query':
              return ProcessResult(
                1,
                enabled ? 0 : 1,
                enabled ? 'FlSteamLua    REG_SZ    "$executable"' : '',
                '',
              );
            case 'add':
              enabled = true;
              return ProcessResult(1, 0, '', '');
            case 'delete':
              enabled = false;
              return ProcessResult(1, 0, '', '');
            default:
              throw StateError('Unexpected registry command');
          }
        },
      );
      final preferences = create(startup: startup, supportsStartup: true);
      await preferences.initialize();
      expect(preferences.startupEnabled, isFalse);
      expect(commands.map((args) => args.first), ['query']);
      await preferences.setStartupEnabled(true);
      expect(preferences.startupEnabled, isTrue);
      final registration = commands.singleWhere((args) => args.first == 'add');
      expect(registration[registration.indexOf('/d') + 1], '"$executable"');
      await preferences.setStartupEnabled(false);
      expect(preferences.startupEnabled, isFalse);
      expect(commands.where((args) => args.first == 'delete'), hasLength(1));
      expect(
        tasks.tasks.map((task) => task.status),
        everyElement(TaskStatus.succeeded),
      );
    },
  );

  test(
    'offline preference edits only the recent fixture account and backs up VDF',
    () async {
      final steam = await Directory(p.join(directory.path, 'steam')).create();
      await settings.set('steamPath', steam.path);
      final file = File(p.join(steam.path, 'config', 'loginusers.vdf'));
      await file.parent.create(recursive: true);
      final original = Kv1.stringify({
        'users': {
          '111': {
            'AccountName': 'older-account',
            'MostRecent': '0',
            'WantsOfflineMode': '0',
            'SkipOfflineModeWarning': '0',
          },
          '222': {
            'AccountName': 'recent-account',
            'MostRecent': '1',
            'WantsOfflineMode': '0',
            'SkipOfflineModeWarning': '0',
            'RememberPassword': '1',
          },
        },
      });
      await file.writeAsString(original);
      final preferences = create();
      await preferences.initialize();
      expect(preferences.offlineEnabled, isFalse);
      await preferences.setOfflineMode(true);
      expect(preferences.offlineEnabled, isTrue);
      expect(settings.get<bool>('offlineMode', false), isTrue);
      final users = Kv1.parse(await file.readAsString())['users'] as Map;
      final older = users['111'] as Map;
      final recent = users['222'] as Map;
      expect(older['WantsOfflineMode'], '0');
      expect(older['SkipOfflineModeWarning'], '0');
      expect(recent['WantsOfflineMode'], '1');
      expect(recent['SkipOfflineModeWarning'], '1');
      expect(recent['RememberPassword'], '1');
      final backups = await paths
          .directory('backups/library')
          .list()
          .where(
            (entry) =>
                entry is File &&
                p.basename(entry.path).endsWith('-loginusers.vdf'),
          )
          .cast<File>()
          .toList();
      expect(backups, hasLength(1));
      expect(await backups.single.readAsString(), original);
      await preferences.refreshPlatformState();
      expect(preferences.offlineEnabled, isTrue);
      expect(preferences.platformError, isNull);
      expect(tasks.tasks.single.status, TaskStatus.succeeded);
    },
  );
}
