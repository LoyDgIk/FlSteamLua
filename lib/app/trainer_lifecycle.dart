import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/settings_store.dart';
import '../core/task_center.dart';
import '../features/library/library_service.dart';
import '../features/tools/online/online_services.dart';
import '../ui/localization.dart';

/// One application-lifetime owner for trainer start/stop transitions. Pages do
/// not launch trainers: observed Steam starts and direct starts use this path.
class TrainerLifecycle {
  TrainerLifecycle({
    required this.library,
    required this.trainers,
    required this.tasks,
    required this.settings,
  }) {
    library.addListener(_synchronize);
    trainers.addListener(_bindingsChanged);
    _bindingsChanged();
  }

  final LibraryService library;
  final TrainerService trainers;
  final TaskCenter tasks;
  final SettingsStore settings;
  Map<int, String> _paths = {};
  Map<int, String> _active = {};
  Future<void> _queue = Future.value();
  bool _closing = false;

  Future<void> get idle => _queue;

  void _bindingsChanged() {
    if (_closing) return;
    final paths = {
      for (final binding in trainers.bindings)
        if (binding.enabled) binding.appId: binding.gameExecutable,
    };
    if (!mapEquals(paths, _paths)) {
      _paths = paths;
      library.setMonitoredExecutables(paths);
      unawaited(library.refreshRunningProcesses());
    }
    _synchronize();
  }

  void _synchronize() {
    if (_closing) return;
    final desired = <int, String>{};
    for (final binding in trainers.bindings) {
      if (binding.enabled &&
          library.isExecutableRunning(binding.appId, binding.gameExecutable)) {
        desired[binding.appId] = binding.gameExecutable;
      }
    }
    final stopped = _active.keys
        .where((id) => desired[id] != _active[id])
        .toList();
    final started = desired.entries
        .where((entry) => _active[entry.key] != entry.value)
        .toList();
    _active = desired;
    if (stopped.isEmpty && started.isEmpty) return;
    _queue = _queue.then((_) async {
      for (final id in stopped) {
        await _transition(id, false);
      }
      for (final entry in started) {
        await _transition(entry.key, true, executable: entry.value);
      }
    });
  }

  Future<void> _transition(int appId, bool start, {String? executable}) async {
    try {
      await tasks.run(
        localizationsFor(settings.language).linkedTrainer(
          ((start
                  ? localizationsFor(settings.language).start
                  : localizationsFor(settings.language).stop2))
              .toString(),
          (appId).toString(),
        ),
        (_) => start
            ? trainers.onGameStarted(appId, executablePath: executable)
            : trainers.onGameStopped(appId),
        appId: appId,
      );
    } catch (_) {
      // TaskCenter retains the actual failure for the global task panel.
    }
  }

  void detach() {
    if (_closing) return;
    _closing = true;
    library.removeListener(_synchronize);
    trainers.removeListener(_bindingsChanged);
  }

  Future<void> stop() async {
    detach();
    await _queue;
  }
}
