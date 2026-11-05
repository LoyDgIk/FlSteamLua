import 'dart:async';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_engine_client.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_models.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_page.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_service.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('closing a transfer page does not cancel its session', (
    tester,
  ) async {
    final paths = AppPaths('fixture');
    final settings = SettingsStore(paths);
    final tasks = TaskCenter();
    final engine = _FakeEngine();
    final library = LibraryService(paths: paths, settings: settings);
    final service = LanTransferService(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
      engine: engine,
    );
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
        fingerprint: 'PEER',
        trusted: true,
      ),
      status: TransferSessionStatus.transferring,
      totalBytes: 100,
      createdAt: DateTime.now(),
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(seedColor: Colors.blue),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  openLanTransferSessionPage(
                    context,
                    service: service,
                    settings: settings,
                    session: session,
                  ),
                ),
                child: const Text('open transfer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open transfer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LanTransferSessionPage), findsOneWidget);
      expect(find.text('Fixture Game'), findsWidgets);

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LanTransferSessionPage), findsNothing);
      expect(
        engine.requests.where((request) => request.$1 == 'session.cancel'),
        isEmpty,
      );
    } finally {
      service.dispose();
      tasks.dispose();
      library.dispose();
      settings.dispose();
    }
  });

  testWidgets('failed sending session exposes retry', (tester) async {
    final paths = AppPaths('fixture');
    final settings = SettingsStore(paths);
    final tasks = TaskCenter();
    final engine = _FakeEngine();
    final library = LibraryService(paths: paths, settings: settings);
    final service = LanTransferService(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
      engine: engine,
    );
    final session = TransferSession(
      id: 'send:failed',
      bundleId: 'failed',
      appId: 42,
      gameName: 'Fixture Game',
      direction: TransferDirection.send,
      peer: const LanPeer(
        id: 'peer',
        alias: 'Peer',
        address: '127.0.0.1',
        port: lanTransferPort,
        fingerprint: 'PEER',
        trusted: true,
      ),
      status: TransferSessionStatus.failed,
      totalBytes: 100,
      createdAt: DateTime.now(),
    );

    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(seedColor: Colors.blue),
          home: LanTransferSessionPage(
            service: service,
            settings: settings,
            session: session,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Retry transfer').first);
      await tester.pump();
      expect(engine.requests.single.$1, 'session.resume');
      expect(engine.requests.single.$2, {'sessionId': 'send:failed'});
    } finally {
      service.dispose();
      tasks.dispose();
      library.dispose();
      settings.dispose();
    }
  });
}

class _FakeEngine implements LanTransferEngineTransport {
  final StreamController<LanTransferEngineEvent> _events =
      StreamController<LanTransferEngineEvent>.broadcast();
  final List<(String, Map<String, dynamic>)> requests = [];

  @override
  Stream<LanTransferEngineEvent> get events => _events.stream;

  @override
  bool get isRunning => true;

  @override
  Future<void> start(String dataDir) async {}

  @override
  Future<dynamic> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    requests.add((method, params));
    return const <String, dynamic>{};
  }

  @override
  Future<void> close() => _events.close();
}
