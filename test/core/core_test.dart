import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Lua never implies account ownership', () {
    const game = GameEntry(appId: 42, name: 'Example', luaPath: '42.lua');
    expect(game.hasLua, isTrue);
    expect(game.isInstalled, isFalse);
    expect(game.ownership, GameOwnership.unknown);
    expect(game.copyWith(isInstalled: true).ownership, GameOwnership.unknown);
  });

  test('concurrent preference writes persist all values and reload', () async {
    final root = await Directory.systemTemp.createTemp('fl-settings-');
    final paths = AppPaths(root.path);
    final store = SettingsStore(paths);
    try {
      await Future.wait([
        store.set('language', 'en'),
        store.set('theme', 'dark'),
        store.set('sidebarExpanded', false),
      ]);
      final saved = jsonDecode(
        await File(paths.file('settings.json')).readAsString(),
      );
      expect(saved, {
        'language': 'en',
        'theme': 'dark',
        'sidebarExpanded': false,
      });
      final restored = SettingsStore(paths);
      await restored.load();
      expect(restored.language, 'en');
      expect(restored.theme, 'dark');
      expect(restored.sidebarExpanded, false);
      restored.dispose();
    } finally {
      store.dispose();
      await root.delete(recursive: true);
    }
  });

  test(
    'tasks retain failure results and finish cancellation before shutdown',
    () async {
      final tasks = TaskCenter();
      final release = Completer<void>();
      final running = tasks.run('Import', (context) async {
        context.report('Reading', .3);
        await release.future;
        context.checkCancelled();
      });
      expect(tasks.runningCount, 1);
      final completion = expectLater(running, throwsA(isA<TaskCancelled>()));
      final shutdown = tasks.cancelAndWait();
      expect(tasks.tasks.single.cancellationRequested, isTrue);
      release.complete();
      await completion;
      await shutdown;
      expect(tasks.tasks.single.status, TaskStatus.cancelled);
      expect(tasks.runningCount, 0);
      await expectLater(
        tasks.run(
          'Failure',
          (_) async => throw const FormatException('bad file'),
        ),
        throwsFormatException,
      );
      expect(tasks.tasks.first.status, TaskStatus.failed);
      expect(tasks.tasks.first.error, isA<FormatException>());
      tasks.clearCompleted();
      expect(tasks.tasks, isEmpty);
      tasks.dispose();
    },
  );
}
