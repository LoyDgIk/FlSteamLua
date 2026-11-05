import 'package:fl_steam_lua/core/steam_process_actions.dart';
import 'package:fl_steam_lua/features/cloud/cloud_workflows.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'operation confirmation stops Steam once and can cancel without side effects',
    (tester) async {
      var running = true, stops = 0, applied = 0;
      final steam = SteamProcessActions(
        isRunning: () async => running,
        start: () async {},
        restart: () async {},
        stop: () async {
          stops++;
          running = false;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ui.TonalButton(
                label: 'Run fixture',
                onPressed: () async {
                  if (await confirmCloudOperation(
                    context,
                    title: 'Fixture operation',
                    details: const [
                      ('Account', '123'),
                      ('Destination', 'fixture'),
                    ],
                    steam: steam,
                    stopSteam: true,
                    backup: true,
                  )) {
                    applied++;
                  }
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Run fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
      expect(find.text('Automatic pre-operation backup'), findsOneWidget);
      expect(find.text('Close Steam and continue'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(stops, 0);
      expect(applied, 0);
      await tester.tap(find.text('Run fixture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cloud-confirm-operation')));
      await tester.pumpAndSettle();
      expect(stops, 1);
      expect(applied, 1);
      expect(find.byType(ui.SideSheetScaffold), findsNothing);
    },
  );
}
