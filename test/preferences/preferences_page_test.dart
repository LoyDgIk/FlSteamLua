import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/preferences/preferences_controller.dart';
import 'package:fl_steam_lua/features/preferences/preferences_page.dart';
import 'package:fl_steam_lua/platform/desktop/startup_registration.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _IdleTimer implements Timer {
  bool _active = true;
  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

void main() {
  late Directory directory;
  late AppPaths paths;
  late SettingsStore settings;
  late LibraryService library;
  late TaskCenter tasks;
  late PreferencesController controller;
  late List<List<String>> commands;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flsl-preferences-page-');
    paths = AppPaths(directory.path);
    await paths.initialize();
    settings = SettingsStore(paths);
    library = LibraryService(paths: paths, settings: settings);
    tasks = TaskCenter();
    commands = [];
    var startupEnabled = false;
    const executable = r'C:\Fixture\FlSteamLua.exe';
    controller = PreferencesController(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
      periodicTimer: (_, callback) => _IdleTimer(),
      libraryRefresh: () async {},
      keyCacheUpdateDue: () async {},
      watchFiles: false,
      supportsStartup: true,
      startup: StartupRegistration(
        executable: executable,
        runner: (command, arguments) async {
          expect(command, 'reg.exe');
          commands.add(List.of(arguments));
          if (arguments.first == 'add') startupEnabled = true;
          if (arguments.first == 'delete') startupEnabled = false;
          return ProcessResult(
            1,
            arguments.first == 'query' && !startupEnabled ? 1 : 0,
            startupEnabled ? 'FlSteamLua    REG_SZ    "$executable"' : '',
            '',
          );
        },
      ),
      updateFactory: (_) =>
          throw StateError('No release repository is configured'),
    );
    await controller.initialize();
  });

  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
    library.dispose();
    settings.dispose();
    tasks.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> render(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: settings,
        builder: (_, _) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: resolveAppLocale(settings.language),
          home: PreferencesPage(controller: controller, settings: settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    } else {
      await tester.ensureVisible(finder);
    }
    await tester.pumpAndSettle();
  }

  Future<void> changeSwitch(WidgetTester tester, String key, bool value) async {
    final finder = find.byKey(ValueKey(key));
    await reveal(tester, finder);
    final toggle = tester.widget<ui.CommonSwitch>(
      find.descendant(of: finder, matching: find.byType(ui.CommonSwitch)),
    );
    await tester.runAsync(() async {
      toggle.onChanged?.call(value);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'preference switches save real settings and use the injected startup action',
    (tester) async {
      await render(tester, const Size(1000, 1000));
      expect(find.text('后台与 Steam 偏好'), findsOneWidget);
      expect(commands.map((arguments) => arguments.first), ['query']);
      expect(tasks.tasks, isEmpty);
      await changeSwitch(tester, 'auto-library-refresh', false);
      await changeSwitch(tester, 'auto-update-check', false);
      await changeSwitch(tester, 'auto-key-cache-update', true);
      await changeSwitch(tester, 'startup-switch', true);
      final loaded = SettingsStore(paths);
      await tester.runAsync(loaded.load);
      expect(loaded.get<bool>('autoLibraryRefresh', true), isFalse);
      expect(loaded.get<bool>('autoCheckUpdates', true), isFalse);
      expect(loaded.get<bool>('autoUpdateKeyCache', false), isTrue);
      loaded.dispose();
      expect(controller.startupEnabled, isTrue);
      expect(
        commands.where((arguments) => arguments.first == 'add'),
        hasLength(1),
      );
      expect(tasks.tasks.single.status, TaskStatus.succeeded);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('English compact layout keeps the Steam preferences reachable', (
    tester,
  ) async {
    await tester.runAsync(() => settings.set('language', 'en'));
    await render(tester, const Size(600, 700));
    expect(find.text('Background and Steam preferences'), findsOneWidget);
    expect(find.text('Refresh the library automatically'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('auto-key-cache-update')));
    expect(find.text('Update key subscriptions automatically'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('steam-offline-switch')));
    expect(find.text('Steam offline mode'), findsOneWidget);
    final offline = tester.widget<ui.CommonSwitch>(
      find.descendant(
        of: find.byKey(const ValueKey('steam-offline-switch')),
        matching: find.byType(ui.CommonSwitch),
      ),
    );
    expect(offline.onChanged, isNull);
    expect(
      find.text(
        'No recent Steam account was read. Sign in to Steam, then refresh the state.',
      ),
      findsOneWidget,
    );
    expect(commands.map((arguments) => arguments.first), ['query']);
    expect(tasks.tasks, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'background update errors do not extend the automatic-task row group',
    (tester) async {
      controller.updateError = const HttpException('Update unavailable');
      await render(tester, const Size(1100, 1000));
      final lastRow = find.byKey(const ValueKey('auto-key-cache-update'));
      expect(
        ui.ItemPositionProvider.of(tester.element(lastRow))?.position,
        ui.ItemPosition.end,
      );
      final card = find.ancestor(
        of: find.textContaining('Update unavailable'),
        matching: find.byType(ui.CommonCard),
      );
      expect(tester.getTopLeft(card).dy - tester.getBottomLeft(lastRow).dy, 12);
      expect(tester.widget<ui.CommonCard>(card).inert, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
