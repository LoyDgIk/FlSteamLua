import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/data_management_page.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets('data management shows total and percentage breakdown', (
    tester,
  ) async {
    late Directory directory;
    late AppServices services;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('flsteam-data-ui-');
      services = AppServices(AppPaths(p.join(directory.path, 'app')));
      await services.paths.initialize();
      await services.settings.set('language', 'en');
      final cache = File(services.paths.file('cache/sample.bin'));
      await cache.parent.create(recursive: true);
      await cache.writeAsBytes(List.filled(2048, 1));
      final data = File(services.paths.file('data/sample.bin'));
      await data.writeAsBytes(List.filled(1024, 2));
    });
    tester.view.physicalSize = const Size(1100, 900);
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
          theme: ui.buildAppTheme(),
          home: DataManagementPage(services: services),
        ),
      );
      for (
        var attempt = 0;
        attempt < 100 &&
            find.text('Calculating storage usage').evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Storage usage'), findsOneWidget);
      expect(find.text('Storage locations'), findsOneWidget);
      expect(find.text('Cleanup'), findsOneWidget);
      expect(find.text('67%'), findsWidgets);
      expect(find.text('33%'), findsWidgets);
      expect(find.byKey(const ValueKey('storage-location-cache')), findsOne);
      expect(find.byKey(const ValueKey('storage-location-data')), findsOne);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      services.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });
}
