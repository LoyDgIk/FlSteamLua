import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/patching/patching_page.dart';
import 'package:fl_steam_lua/features/tools/tools_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'patch settings exposes verification and network downloads without generic install',
    (tester) async {
      late Directory directory;
      late Directory gameDirectory;
      late AppPaths paths;
      late SettingsStore settings;
      late ToolsService tools;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'flsteam-patch-widget-',
        );
        gameDirectory = await Directory(
          '${directory.path}${Platform.pathSeparator}game',
        ).create();
        paths = AppPaths(directory.path);
        settings = SettingsStore(paths);
        tools = ToolsService(paths: paths, settings: settings);
        await settings.set('language', 'en');
      });
      final tasks = TaskCenter();
      tester.view.physicalSize = const Size(1100, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: resolveAppLocale(settings.language),
          home: PatchSettingsPage(
            paths: paths,
            settings: settings,
            tasks: tasks,
            tools: tools,
            game: GameEntry(
              appId: 123,
              name: 'Test game',
              installPath: gameDirectory.path,
              isInstalled: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Patch tools'), findsNWidgets(2));
      expect(find.text('Game file verification'), findsOneWidget);
      expect(find.text('Game patch download'), findsOneWidget);
      expect(find.text('Goldberg settings'), findsOneWidget);
      expect(find.text('Tickets'), findsNothing);
      expect(find.text('Choose patch archive'), findsNothing);
      expect(find.text('Patch backups'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tools.dispose();
      settings.dispose();
      tasks.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    },
  );
}
