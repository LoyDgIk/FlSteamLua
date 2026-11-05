import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/steam_versions/steam_version_service.dart';
import 'package:fl_steam_lua/features/steam_versions/steam_versions_page.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'steam_version_service_test.dart' show fixture;

void main() {
  testWidgets(
    'historical choices open directly; empty and search states share the page scroll',
    (tester) async {
      late Directory root;
      late SettingsStore settings;
      late LibraryService library;
      late SteamVersionService service;
      final tasks = TaskCenter();
      var requests = 0;
      final old = fixture('win32', '1750000000');
      final pending = SteamClientVersion(
        arch: 'win32',
        build: old.version.build,
        manifest: '',
        source: 'builtin',
        manifestUrl: '',
        snapshot: '20250601000000',
      );
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('steam-version-page-');
        final paths = AppPaths(p.join(root.path, 'app'));
        await paths.initialize();
        settings = SettingsStore(paths);
        await settings.set('language', 'en');
        library = LibraryService(
          paths: paths,
          settings: settings,
          processSnapshotReader: () async => [],
        );
        service = SteamVersionService(
          paths: paths,
          settings: settings,
          library: library,
          processReader: () async => [],
          builtInCatalog: () async => jsonEncode({
            'versions': [pending.toJson()],
          }),
          client: MockClient((request) async {
            requests++;
            return http.Response(old.version.manifest, 200);
          }),
        );
      });
      tester.view.physicalSize = const Size(1000, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SteamVersionsPage(service: service, tasks: tasks),
            ),
          );
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
        expect(find.text('1750000000 · win32'), findsOneWidget);
        expect(find.text('Manifest not loaded'), findsOneWidget);
        expect(requests, 0);
        expect(find.byType(ui.CommonSwitch), findsNothing);
        await tester.runAsync(() async {
          await tester.tap(find.text('1750000000 · win32'));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 80));
        });
        await tester.pumpAndSettle();
        expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
        expect(requests, 1);
        expect(find.text('Download and verify'), findsOneWidget);
        expect(find.byType(ui.CommonSwitch), findsNothing);
        Navigator.of(tester.element(find.byType(ui.SideSheetScaffold))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Search'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'no-such-build');
        await tester.pumpAndSettle();
        expect(find.text('No matching results'), findsOneWidget);
        final empty = find.byType(ui.NullStatus);
        expect(tester.widget<ui.NullStatus>(empty).scrollable, isFalse);
        expect(
          find.descendant(of: empty, matching: find.byType(Scrollable)),
          findsNothing,
        );
        final vertical = tester
            .widgetList<Scrollable>(
              find.descendant(
                of: find.byType(SteamVersionsPage),
                matching: find.byType(Scrollable),
              ),
            )
            .where(
              (v) =>
                  v.axisDirection == AxisDirection.down ||
                  v.axisDirection == AxisDirection.up,
            );
        expect(vertical, hasLength(1));
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = const Size(900, 480);
        await tester.pumpAndSettle();
        await tester.drag(empty, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(requests, 1);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          service.dispose();
          library.dispose();
          settings.dispose();
          tasks.dispose();
          await root.delete(recursive: true);
        });
      }
    },
  );
}
