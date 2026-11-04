import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_models.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_widgets.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;

void main() {
  testWidgets('transfer hero shows Steam-style speed metrics', (tester) async {
    final settings = SettingsStore(AppPaths('fixture'));
    final session = TransferSession(
      id: 'send:fixture',
      bundleId: 'fixture',
      appId: 42,
      gameName: 'Fixture Game',
      direction: TransferDirection.send,
      peer: const LanPeer(
        id: 'peer',
        alias: 'Peer',
        address: '127.0.0.1',
        port: lanTransferPort,
        fingerprint: '00',
        trusted: true,
      ),
      status: TransferSessionStatus.transferring,
      totalBytes: 100 * 1024 * 1024,
      transferredBytes: 48 * 1024 * 1024,
      speed: 12 * 1024 * 1024,
      peakSpeed: 20 * 1024 * 1024,
      createdAt: DateTime.now(),
      speedSamples: const [0.2, .4, .1, .8, .6, .9],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(seedColor: Colors.blue),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: TransferHero(
              session: session,
              settings: settings,
              background: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Fixture Game'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Peak'), findsOneWidget);
    expect(find.text('12.0 MB/s'), findsOneWidget);
  });
}
