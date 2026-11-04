import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/cloud/cloud_page.dart';
import 'package:fl_steam_lua/features/cloud/cloud_redirect_plugin_page.dart';
import 'package:fl_steam_lua/features/cloud/cloud_service.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets(
    'game context limits save list and exposes provider configuration',
    (tester) async {
      late Directory directory;
      late SettingsStore settings;
      late CloudService service;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('flsteam-cloud-ui-');
        final paths = AppPaths(p.join(directory.path, 'app'));
        await paths.initialize();
        settings = SettingsStore(paths);
        await settings.set('language', 'en');
        service = CloudService(
          paths: paths,
          settings: settings,
          configDirectory: p.join(directory.path, 'config'),
          credentialCodec: CredentialCodec(
            protect: (bytes) => bytes,
            unprotect: (bytes) => bytes,
          ),
        );
        await service.setSyncPath(p.join(directory.path, 'saves'));
        final tf = File(p.join(service.syncPath, '123', '440', 'save.dat'));
        await tf.parent.create(recursive: true);
        await tf.writeAsString('save');
        final other = File(p.join(service.syncPath, '123', '570', 'save.dat'));
        await other.parent.create(recursive: true);
        await other.writeAsString('save');
        await service.refresh();
      });

      Future<void> finishRefresh() async {
        for (var attempt = 0; service.loading && attempt < 200; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: resolveAppLocale(settings.language),
            home: Scaffold(
              body: CloudPage(
                service: service,
                game: const GameEntry(appId: 440, name: 'Team Fortress'),
                games: const [
                  GameEntry(appId: 440, name: 'Team Fortress'),
                  GameEntry(appId: 570, name: 'Dota'),
                ],
              ),
            ),
          ),
        );
        await finishRefresh();
        expect(service.loading, isFalse);
        expect(service.lastError, isNull);
        expect(find.textContaining('Team Fortress'), findsWidgets);
        expect(find.text('Dota'), findsNothing);

        await tester.tap(find.byTooltip('Search'));
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'missing');
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('No matching results'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '440');
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('Team Fortress'), findsWidgets);
        await tester.enterText(find.byType(TextField), '');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.byTooltip('Save backups'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        Navigator.of(tester.element(find.byType(ui.SideSheetScaffold))).pop();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.byKey(const ValueKey('cloud-plugin-management')));
        await tester.pumpAndSettle();
        expect(find.byType(CloudRedirectPluginPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cloud-configure')));
        await tester.pumpAndSettle();
        expect(find.text('Configure storage'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await finishRefresh();
        await tester.runAsync(() async {
          service.dispose();
          settings.dispose();
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
