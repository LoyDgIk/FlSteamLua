import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/steam_process_actions.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/patching/ticket_authorization.dart';
import 'package:fl_steam_lua/features/patching/ticket_page.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'ticket_transaction_test.dart'
    show FixtureTicketRegistry, base64EncodeString, base64DecodeString;

void main() {
  for (final synchronize in [false, true]) {
    testWidgets(
      'one confirmation applies tickets with explicit identity choice $synchronize',
      (tester) async {
        late Directory root;
        late AppPaths paths;
        late SettingsStore settings;
        late TicketAuthorizationStore store;
        final registry = FixtureTicketRegistry()..steamId = '111';
        final tasks = TaskCenter();
        late File lua;
        var stops = 0;
        var running = true;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('ticket-identity-page-');
          paths = AppPaths(p.join(root.path, 'app'));
          settings = SettingsStore(paths);
          await settings.set('steamPath', root.path);
          lua = File(p.join(root.path, 'config', 'lua', '480.lua'));
          await lua.parent.create(recursive: true);
          await lua.writeAsString(
            'addappid(480)\nsetAppTicket(480,"old-secret")\n',
          );
          store = TicketAuthorizationStore(
            paths: paths,
            registry: registry,
            protect: base64EncodeString,
            unprotect: base64DecodeString,
          );
        });
        await tester.binding.setSurfaceSize(const Size(1200, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final app = Uint8List(24);
        ByteData.sublistView(app)
          ..setUint32(8, 222, Endian.little)
          ..setUint32(16, 480, Endian.little);
        final ticket = AuthorizationTicket(
          appId: 480,
          steamId: BigInt.from(222),
          appTicket: app,
          eTicket: Uint8List.fromList([8]),
        );
        Future<void> waitIo() async {
          for (var attempt = 0; attempt < 8; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump(const Duration(milliseconds: 80));
          }
          await tester.pump(const Duration(milliseconds: 500));
        }

        try {
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: TicketPage(
                paths: paths,
                tasks: tasks,
                settings: settings,
                store: store,
                initialTicket: ticket,
                game: GameEntry(appId: 480, name: 'Fixture', luaPath: lua.path),
                currentAccountReader: () async => '111',
                steamProcess: SteamProcessActions(
                  isRunning: () async => running,
                  start: () async {},
                  restart: () async {},
                  stop: () async {
                    stops++;
                    running = false;
                  },
                ),
              ),
            ),
          );
          await waitIo();
          expect(find.text('Current Steam account'), findsOneWidget);
          expect(find.text('Ticket owner'), findsOneWidget);
          expect(
            find.text('Cached authorization identity for this game'),
            findsOneWidget,
          );
          final apply = find.byKey(const ValueKey('apply-ticket'));
          await tester.ensureVisible(apply);
          expect(
            tester.widget<ui.DecorationListItem>(apply).onPressed,
            isNotNull,
          );
          await tester.runAsync(() async {
            tester.widget<ui.DecorationListItem>(apply).onPressed!();
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await waitIo();
          expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
          expect(find.textContaining('old-secret'), findsNothing);
          expect(find.textContaining('setAppTicket(480, …)'), findsOneWidget);
          final toggle = tester.widget<ui.CommonSwitch>(
            find.descendant(
              of: find.byKey(const ValueKey('sync-ticket-identity')),
              matching: find.byType(ui.CommonSwitch),
            ),
          );
          expect(toggle.value, isFalse);
          expect(registry.writes, isEmpty);
          if (synchronize) {
            toggle.onChanged!(true);
            await tester.pump();
          }
          await tester.tap(find.byKey(const ValueKey('confirm-ticket-apply')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await waitIo();
          expect(registry.steamId, synchronize ? '222' : '111');
          expect(registry.values['ETicket'], [8]);
          expect(stops, 1);
          expect(find.byType(ui.SideSheetScaffold), findsNothing);
          expect(
            find.byKey(const ValueKey('ticket-identity-warning')),
            synchronize ? findsNothing : findsOneWidget,
          );
          expect(tasks.tasks.single.status, TaskStatus.succeeded);
          expect(
            (await tester.runAsync(lua.readAsString))!,
            isNot(contains('setAppTicket')),
          );
          if (synchronize) {
            final restore = find
                .byWidgetPredicate(
                  (widget) =>
                      widget is ui.DecorationListItem &&
                      widget.key is ValueKey<String> &&
                      (widget.key! as ValueKey<String>).value.startsWith(
                        'restore-credentials-',
                      ),
                )
                .first;
            await tester.ensureVisible(restore);
            await tester.runAsync(() async {
              tester.widget<ui.DecorationListItem>(restore).onPressed!();
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await waitIo();
            expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
            await tester.tap(
              find.byKey(const ValueKey('confirm-ticket-restore')),
            );
            await tester.pump(const Duration(milliseconds: 400));
            await waitIo();
            expect(registry.steamId, '111');
            expect(registry.values, isEmpty);
            expect(
              (await tester.runAsync(lua.readAsString))!,
              contains('setAppTicket(480,"old-secret")'),
            );
            expect(
              tasks.tasks.every((task) => task.status == TaskStatus.succeeded),
              isTrue,
            );
            expect(
              find.byKey(const ValueKey('ticket-identity-warning')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          tasks.dispose();
          settings.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        }
      },
    );
  }
}
