import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/process_observer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late AppPaths paths;
  late SettingsStore settings;
  late LibraryService library;
  late String gameExe;
  var snapshot = <RunningProcess>[];
  Object? snapshotError;
  var reads = 0;
  final stopped = <int>[];

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsl-processes-');
    paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    final steam = Directory(p.join(temp.path, 'steam'));
    await steam.create();
    settings = SettingsStore(paths);
    await settings.set('steamPath', steam.path);
    final manifest = File(
      p.join(steam.path, 'steamapps', 'appmanifest_10.acf'),
    );
    await manifest.parent.create(recursive: true);
    await manifest.writeAsString(
      Kv1.stringify({
        'AppState': {
          'appid': '10',
          'name': 'Observed Game',
          'installdir': 'observed',
          'StateFlags': '4',
        },
      }),
    );
    final executable = File(
      p.join(steam.path, 'steamapps', 'common', 'observed', 'game.exe'),
    );
    await executable.parent.create(recursive: true);
    await executable.writeAsBytes([1]);
    gameExe = executable.path;
    snapshot = [];
    snapshotError = null;
    reads = 0;
    stopped.clear();
    library = LibraryService(
      paths: paths,
      settings: settings,
      processSnapshotReader: () async {
        reads++;
        if (snapshotError != null) throw snapshotError!;
        return List.of(snapshot);
      },
      observedProcessStopper: (process) async {
        stopped.add(process.pid);
        snapshot.removeWhere((entry) => entry.pid == process.pid);
      },
    );
    await library.scan();
  });

  tearDown(() async {
    await library.stopProcessMonitoring();
    library.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });

  test(
    'detects external starts by exact image path and clears on exit',
    () async {
      snapshot = [RunningProcess(pid: 40, executablePath: gameExe)];
      await library.refreshRunningProcesses();
      expect(library.games.single.isRunning, isTrue);
      expect(library.games.single.ownership, GameOwnership.unknown);
      expect(library.isExecutableRunning(10, gameExe.toUpperCase()), isTrue);
      await library.scan();
      expect(library.games.single.isRunning, isTrue);
      snapshot = [];
      await library.refreshRunningProcesses();
      expect(library.games.single.isRunning, isFalse);
      expect(library.games.single.lastPlayed, isNull);
      expect(library.games.single.playtimeMinutes, isNull);
      expect(await File(paths.file('data/library.json')).exists(), isFalse);
    },
  );

  test(
    'same executable name in another directory does not mark game running',
    () async {
      snapshot = [
        RunningProcess(
          pid: 40,
          executablePath: p.join(temp.path, 'another-game', 'game.exe'),
        ),
      ];
      await library.refreshRunningProcesses();
      expect(library.games.single.isRunning, isFalse);
    },
  );

  test(
    'configured binding observes the chosen executable rather than heuristic',
    () async {
      final chosen = p.join(p.dirname(gameExe), 'bin', 'actual-game.exe');
      library.setMonitoredExecutables({10: chosen});
      snapshot = [
        RunningProcess(pid: 40, executablePath: gameExe),
        RunningProcess(pid: 41, executablePath: chosen),
      ];
      await library.refreshRunningProcesses();
      expect(library.isExecutableRunning(10, chosen), isTrue);
      expect(library.games.single.isRunning, isTrue);
      snapshot.removeAt(1);
      await library.refreshRunningProcesses();
      expect(library.isExecutableRunning(10, chosen), isFalse);
      expect(library.games.single.isRunning, isTrue);
    },
  );

  test(
    'failed process snapshots preserve running state and expose failure',
    () async {
      snapshot = [RunningProcess(pid: 40, executablePath: gameExe)];
      await library.refreshRunningProcesses();
      snapshotError = StateError('Snapshot denied');
      await library.refreshRunningProcesses();
      expect(library.games.single.isRunning, isTrue);
      expect(library.warnings.single, contains('Snapshot denied'));
      snapshotError = null;
      snapshot = [];
      await library.refreshRunningProcesses();
      expect(library.games.single.isRunning, isFalse);
      expect(library.warnings, isEmpty);
    },
  );

  test(
    'external stop targets only exact observed PIDs and refreshes state',
    () async {
      snapshot = [
        RunningProcess(pid: 40, executablePath: gameExe),
        RunningProcess(pid: 41, executablePath: p.join(temp.path, 'other.exe')),
      ];
      await library.refreshRunningProcesses();
      await library.stop(10);
      expect(stopped, [40]);
      expect(snapshot.single.pid, 41);
      expect(library.games.single.isRunning, isFalse);
    },
  );

  test('polling has an initial read and stops when shut down', () async {
    await library.startProcessMonitoring(
      interval: const Duration(milliseconds: 10),
    );
    expect(reads, 1);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(reads, greaterThan(1));
    await library.stopProcessMonitoring();
    final stoppedAt = reads;
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(reads, stoppedAt);
  });

  test(
    'native snapshot reads current executable without a helper runtime',
    () async {
      final processes = await readRunningProcesses();
      expect(processes.where((process) => process.pid == pid), hasLength(1));
      expect(
        p.equals(
          processes
              .firstWhere((process) => process.pid == pid)
              .executablePath
              .toLowerCase(),
          Platform.resolvedExecutable.toLowerCase(),
        ),
        isTrue,
      );
    },
    skip: !Platform.isWindows,
  );
}
