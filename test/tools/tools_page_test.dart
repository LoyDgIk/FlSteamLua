import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/achievements/achievement_service.dart';
import 'package:fl_steam_lua/features/patching/ticket_page.dart';
import 'package:fl_steam_lua/features/tools/steam_extraction_pages.dart';
import 'package:fl_steam_lua/features/tools/tools_page.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('authorization and extraction are sibling tools', (tester) async {
    late Directory directory;
    late AppPaths paths;
    late SettingsStore settings;
    final tasks = TaskCenter();
    final achievements = AchievementService();
    late ToolsController controller;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('flsteam-tools-ui-');
      paths = AppPaths(p.join(directory.path, 'app'));
      await paths.initialize();
      settings = SettingsStore(paths);
      await settings.set('language', 'en');
      controller = ToolsController(
        appPaths: paths,
        settings: settings,
        tasks: tasks,
      );
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
          home: ToolsPage(
            appPaths: paths,
            settings: settings,
            tasks: tasks,
            controller: controller,
            achievements: achievements,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Authorization'), findsOneWidget);
      expect(find.text('Denuvo authorization'), findsOneWidget);
      expect(find.text('Denuvo ticket extraction'), findsOneWidget);

      await tester.ensureVisible(find.text('Denuvo authorization'));
      await tester.tap(find.text('Denuvo authorization'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TicketPage), findsOneWidget);

      Navigator.of(tester.element(find.byType(TicketPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Denuvo ticket extraction'));
      await tester.tap(find.text('Denuvo ticket extraction'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DenuvoExtractionPage), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      achievements.dispose();
      tasks.dispose();
      settings.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });
}
