import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/achievements/achievement_service.dart';
import 'package:fl_steam_lua/features/patching/ticket_page.dart';
import 'package:fl_steam_lua/features/tools/steam_extraction_pages.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('standalone extraction page opens authorization tickets', (
    tester,
  ) async {
    late Directory directory;
    late AppPaths paths;
    late SettingsStore settings;
    final tasks = TaskCenter();
    final achievements = AchievementService();
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('flsteam-ticket-ui-');
      paths = AppPaths(p.join(directory.path, 'app'));
      await paths.initialize();
      settings = SettingsStore(paths);
    });
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DenuvoExtractionPage(
            paths: paths,
            settings: settings,
            tasks: tasks,
            achievements: achievements,
            games: const [GameEntry(appId: 480, name: 'Spacewar')],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Denuvo ticket extraction'), findsOneWidget);
      await tester.tap(find.byTooltip('Open authorization page'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TicketPage), findsOneWidget);
      expect(find.text('Ticket management'), findsWidgets);
    } finally {
      await tester.pumpWidget(const SizedBox());
      achievements.dispose();
      tasks.dispose();
      settings.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });
}
