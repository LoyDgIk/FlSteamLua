import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/steam_protocol/steam_avatar.dart';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/cloud/cloud_page.dart';
import 'package:fl_steam_lua/features/cloud/cloud_redirect_plugin_page.dart';
import 'package:fl_steam_lua/features/cloud/cloud_service.dart';
import 'package:fl_steam_lua/features/cloud/cloud_storage_page.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _AvatarLibrary extends LibraryService {
  _AvatarLibrary({
    required super.paths,
    required super.settings,
    required this.avatar,
  });
  final String avatar;
  int lookups = 0;
  @override
  List<SteamLocalAccount> get accounts => const [
    SteamLocalAccount(
      steamId: '76561197960265851',
      accountName: 'alice',
      personaName: 'Alice',
    ),
    SteamLocalAccount(
      steamId: '76561197960266184',
      accountName: 'bob',
      personaName: 'Bob',
    ),
  ];
  @override
  String? avatarPath(SteamLocalAccount account) {
    lookups++;
    return avatar;
  }
}

void main() {
  testWidgets(
    'game context limits save list and exposes provider configuration',
    (tester) async {
      late Directory directory;
      late SettingsStore settings;
      late CloudService service;
      late _AvatarLibrary library;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('flsteam-cloud-ui-');
        final paths = AppPaths(p.join(directory.path, 'app'));
        await paths.initialize();
        settings = SettingsStore(paths);
        await settings.set('language', 'en');
        final avatar = File(p.join(directory.path, 'avatar.png'));
        await File('assets/branding/app.png').copy(avatar.path);
        library = _AvatarLibrary(
          paths: paths,
          settings: settings,
          avatar: avatar.path,
        );
        service = CloudService(
          paths: paths,
          settings: settings,
          configDirectory: p.join(directory.path, 'config'),
          processReader: () async => [],
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
                library: library,
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
        await tester.runAsync(
          () => precacheImage(
            FileImage(File(library.avatar)),
            tester.element(find.byType(CloudPage)),
          ),
        );
        expect(service.loading, isFalse);
        expect(service.lastError, isNull);
        expect(find.textContaining('Team Fortress'), findsWidgets);
        expect(find.text('Dota'), findsNothing);
        final browsingTitle = find.text(
          'Browsing · Current core configuration',
        );
        final pluginTitle = find.text('CloudRedirect save plugin');
        expect(
          tester.getTopLeft(browsingTitle).dx,
          tester.getTopLeft(pluginTitle).dx,
        );
        final firstGame = find.byKey(const ValueKey('cloud-game-440-123')).last;
        final firstTop = tester.getTopLeft(firstGame).dy;
        await tester.tap(find.byKey(const ValueKey('cloud-account-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('123'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ui.DashboardIconButton>(
                find.byKey(const ValueKey('cloud-account-filter')),
              )
              .selected,
          isTrue,
        );
        expect(find.text('Account ID · 123'), findsNothing);
        expect(tester.getTopLeft(firstGame).dy, firstTop);
        expect(
          tester
              .widget<SteamAvatar>(
                find.byKey(const ValueKey('cloud-avatar-123')),
              )
              .path,
          library.avatar,
        );
        final lookups = library.lookups;
        await tester.tap(find.byKey(const ValueKey('cloud-account-filter')));
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        await tester.tap(find.text('Bob'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('cloud-avatar-456')), findsOneWidget);
        expect(library.lookups, lookups);
        await tester.tap(find.byKey(const ValueKey('cloud-account-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();

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

        await tester.tap(find.byKey(const ValueKey('cloud-game-440-123')).last);
        await tester.pumpAndSettle();
        expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
        expect(find.text('Export repository copy'), findsOneWidget);
        expect(find.text('View files'), findsWidgets);
        Navigator.of(tester.element(find.byType(ui.SideSheetScaffold))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Save backups'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        Navigator.of(tester.element(find.byType(ui.SideSheetScaffold))).pop();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(const ValueKey('cloud-plugin-management')),
          );
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await finishRefresh();
        await tester.pumpAndSettle();
        expect(find.byType(CloudRedirectPluginPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cloud-configure')));
        await tester.pumpAndSettle();
        expect(find.byType(CloudStoragePage), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Add storage'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(find.text('Configure storage'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('cloud-storage-name')),
            matching: find.byType(TextFormField),
          ),
          'Draft',
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsWidgets);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.byType(ui.FormPage), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await finishRefresh();
        await tester.runAsync(() async {
          service.dispose();
          library.dispose();
          settings.dispose();
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
