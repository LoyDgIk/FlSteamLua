import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/dashboard_page.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Library extends LibraryService {
  _Library(AppPaths paths, SettingsStore settings)
    : super(paths: paths, settings: settings);
  List<GameEntry> entries = [];
  final List<int> launched = [];
  final List<int> stopped = [];

  @override
  List<GameEntry> get games => entries;
  @override
  String? get steamPath => 'C:/FixtureSteam';
  @override
  Future<void> launch(
    int appId, {
    List<String> launchArguments = const [],
  }) async => launched.add(appId);
  @override
  Future<void> stop(int appId) async => stopped.add(appId);
}

class _Services extends AppServices {
  _Services(super.paths)
    : fixtureLibrary = _Library(paths, SettingsStore(paths));
  final _Library fixtureLibrary;
  @override
  LibraryService get library => fixtureLibrary;

  @override
  void dispose() {
    final fixtureSettings = fixtureLibrary.settings;
    super.library.dispose();
    super.dispose();
    fixtureSettings.dispose();
  }
}

void main() {
  late Directory temp;
  late _Services services;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fl-dashboard-');
    services = _Services(AppPaths(temp.path));
  });

  tearDown(() async {
    await services.shutdown();
    services.dispose();
    await temp.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 1280,
    void Function(int)? onLibraryTab,
    void Function(String)? onOpenFeature,
    VoidCallback? onShowTasks,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(),
          home: Scaffold(
            body: DashboardPage(
              services: services,
              onNavigate: (_) {},
              detailBuilder: (game) => Text('Details ${game.appId}'),
              onSettings: () {},
              onLibraryTab: onLibraryTab,
              onOpenFeature: onOpenFeature,
              onShowTasks: onShowTasks,
            ),
          ),
        ),
      );
      await services.kernel.loadLocal();
    });
    await tester.pump();
  }

  testWidgets('Lua and Steam cards select different library tabs', (
    tester,
  ) async {
    services.fixtureLibrary.entries = const [
      GameEntry(appId: 1, name: 'Lua only', luaPath: '1.lua'),
      GameEntry(appId: 2, name: 'Installed', isInstalled: true),
    ];
    final selected = <int>[];
    await mount(tester, onLibraryTab: selected.add);
    await tester.tap(find.byKey(const ValueKey('dashboard-lua-library')));
    await tester.tap(find.byKey(const ValueKey('dashboard-steam-library')));
    expect(selected, [0, 1]);
    expect(find.byType(ui.DashboardCard), findsNWidgets(11));
    expect(find.text('Your games. Your progress.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('content and game tools use their real feature destinations', (
    tester,
  ) async {
    final opened = <String>[];
    var tasksOpened = 0;
    await mount(
      tester,
      onOpenFeature: opened.add,
      onShowTasks: () => tasksOpened++,
    );
    for (final key in [
      'dashboard-content-sources',
      'dashboard-trainers',
      'dashboard-onlinefix',
    ]) {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.tap(target);
    }
    final tasks = find.byKey(const ValueKey('dashboard-tasks'));
    await tester.ensureVisible(tasks);
    await tester.tap(tasks);
    expect(opened, ['content_sources', 'trainers', 'onlinefix']);
    expect(tasksOpened, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('game start and stop use the correct game identity', (
    tester,
  ) async {
    services.fixtureLibrary.entries = [
      const GameEntry(
        appId: 10,
        name: 'Running fixture',
        isInstalled: true,
        isRunning: true,
      ),
      GameEntry(
        appId: 20,
        name: 'Recent fixture',
        isInstalled: true,
        lastPlayed: DateTime(2026),
      ),
    ];
    await mount(tester);
    for (final entry in [
      (id: 10, key: 'dashboard-game-10'),
      (id: 20, key: 'dashboard-recent-game-20'),
    ]) {
      final button = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(button);
      // Tasks created by this callback are awaited by real asynchronous teardown.
      await tester.runAsync(() => tester.tap(button));
      await tester.pump();
      expect(services.tasks.runningCount, 0);
    }
    expect(services.fixtureLibrary.stopped, [10]);
    expect(services.fixtureLibrary.launched, [20]);
    expect(
      services.tasks.tasks.map((task) => task.appId),
      containsAll([10, 20]),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a running task exposes progress and requests cancellation', (
    tester,
  ) async {
    final finish = Completer<void>();
    late Future<void> operation;
    await tester.runAsync(() async {
      operation = services.tasks.run('Fixture import', (task) async {
        task.report('Importing 1/4', .25);
        await finish.future;
        task.checkCancelled();
      });
      // Observe the cancellation exception without hiding it from TaskCenter.
      operation = operation.catchError((Object error) {
        if (error is! TaskCancelled) throw error;
      });
    });
    try {
      await mount(tester);
      final cancel = find.text('Cancel task');
      await tester.ensureVisible(cancel);
      expect(
        tester
            .widget<ui.CommonProgressBar>(
              find.byKey(const ValueKey('dashboard-task-progress')),
            )
            .value,
        .25,
      );
      await tester.tap(cancel);
      await tester.pump();
      expect(services.tasks.tasks.single.cancellationRequested, isTrue);
      expect(find.text('Cancelling'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.runAsync(() async {
        finish.complete();
        await operation;
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('narrow dashboard wraps controls without overflow', (
    tester,
  ) async {
    await mount(tester, width: 520);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('panel edit toggles show the card switches and hide cards', (
    tester,
  ) async {
    await mount(tester);
    final steam = find.byKey(const ValueKey('dashboard-steam-library'));
    final widthBefore = tester.getSize(steam).width;
    final settings = find.byTooltip('Settings');
    expect(settings, findsOneWidget);
    await tester.tap(settings);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('dashboard-panel-toggle-status')),
      findsOneWidget,
    );
    expect(find.byTooltip('Done'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-panel-toggle-lua')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-lua-library')), findsNothing);
    expect(tester.getSize(steam).width, greaterThan(widthBefore));
  });
}
