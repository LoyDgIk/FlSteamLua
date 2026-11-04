import 'dart:io';

import 'package:fl_steam_lua/app/trainer_lifecycle.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/process_observer.dart';
import 'package:fl_steam_lua/features/tools/online/online_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late SettingsStore settings;
  late TaskCenter tasks;
  late LibraryService library;
  late TrainerService trainers;
  late TrainerLifecycle lifecycle;
  late String gamePath;
  late String trainerPath;
  var snapshot = <RunningProcess>[];
  final launches = <String>[];
  final stops = <int>[];
  var failLaunch = false;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsl-trainer-lifecycle-');
    final paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    tasks = TaskCenter();
    gamePath = p.join(temp.path, 'game.exe');
    trainerPath = p.join(temp.path, 'trainer.exe');
    await File(trainerPath).writeAsBytes([1]);
    snapshot = [];
    launches.clear();
    stops.clear();
    failLaunch = false;
    library = LibraryService(
      paths: paths,
      settings: settings,
      processSnapshotReader: () async => List.of(snapshot),
    );
    trainers = TrainerService(
      paths: paths,
      settings: settings,
      launcher: (path) async {
        if (failLaunch) {
          throw const ProcessException('trainer.exe', [], 'denied');
        }
        launches.add(path);
        return 50 + launches.length;
      },
      stopper: (pid) async {
        stops.add(pid);
      },
    );
    lifecycle = TrainerLifecycle(
      library: library,
      trainers: trainers,
      tasks: tasks,
      settings: settings,
    );
    await trainers.saveBinding(
      TrainerBinding(
        appId: 10,
        gameName: 'Game',
        gameExecutable: gamePath,
        trainerPath: trainerPath,
      ),
    );
    await library.refreshRunningProcesses();
  });

  tearDown(() async {
    await lifecycle.stop();
    await trainers.shutdown();
    library.dispose();
    trainers.dispose();
    tasks.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });

  test(
    'external game starts once and natural exit permits the next launch',
    () async {
      snapshot = [RunningProcess(pid: 40, executablePath: gamePath)];
      await library.refreshRunningProcesses();
      await lifecycle.idle;
      await library.refreshRunningProcesses();
      await lifecycle.idle;
      expect(launches, [trainerPath]);
      snapshot = [];
      await library.refreshRunningProcesses();
      await lifecycle.idle;
      expect(stops, [51]);
      await library.refreshRunningProcesses();
      await lifecycle.idle;
      expect(stops, [51]);
      snapshot = [RunningProcess(pid: 41, executablePath: gamePath)];
      await library.refreshRunningProcesses();
      await lifecycle.idle;
      expect(launches, [trainerPath, trainerPath]);
      expect(
        tasks.tasks.every((task) => task.status == TaskStatus.succeeded),
        isTrue,
      );
    },
  );

  test('trainer failures are retained as failed global tasks', () async {
    failLaunch = true;
    snapshot = [RunningProcess(pid: 40, executablePath: gamePath)];
    await library.refreshRunningProcesses();
    await lifecycle.idle;
    expect(tasks.tasks.single.status, TaskStatus.failed);
    expect(tasks.tasks.single.error, isA<ProcessException>());
    expect(library.isExecutableRunning(10, gamePath), isTrue);
  });

  test(
    'detaching application lifecycle prevents further trainer launches',
    () async {
      await lifecycle.stop();
      snapshot = [RunningProcess(pid: 40, executablePath: gamePath)];
      await library.refreshRunningProcesses();
      expect(launches, isEmpty);
      expect(tasks.tasks, isEmpty);
    },
  );
}
