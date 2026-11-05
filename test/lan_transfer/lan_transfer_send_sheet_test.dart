import 'dart:async';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_models.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_page.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_service.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _peer = LanPeer(
  id: 'peer',
  alias: 'Peer',
  address: '127.0.0.1',
  port: lanTransferPort,
  fingerprint: 'PEER',
  trusted: true,
);

void main() {
  testWidgets('closing an unsent plan discards it', (tester) async {
    final fixture = _Fixture();
    try {
      await _openSheet(tester, fixture);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(fixture.service.discarded, ['plan']);
    } finally {
      fixture.dispose();
    }
  });

  testWidgets('a plan prepared after closing the sheet is discarded', (
    tester,
  ) async {
    final fixture = _Fixture();
    final prepare = Completer<LanTransferPlanSummary>();
    fixture.service.preparation = prepare.future;
    try {
      await _openSheet(tester, fixture);
      await tester.pumpWidget(const SizedBox());
      prepare.complete(_plan);
      await tester.pump();
      expect(fixture.service.discarded, ['plan']);
    } finally {
      fixture.dispose();
    }
  });

  testWidgets('extras are selected independently and sent plans stay alive', (
    tester,
  ) async {
    final fixture = _Fixture();
    try {
      await _openSheet(tester, fixture);
      await _openExtras(tester);
      final firstFile = find.text('mods/first.bin');
      await tester.ensureVisible(firstFile);
      await tester.tap(firstFile);
      await tester.pump();
      await tester.tap(find.byTooltip('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final send = find.widgetWithText(ui.TonalButton, 'Send game');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fixture.service.selected, {'first'});
      expect(fixture.service.discarded, isEmpty);
    } finally {
      fixture.dispose();
    }
  });

  testWidgets('disabled Lua is shown and counted alongside game files', (
    tester,
  ) async {
    final fixture = _Fixture();
    fixture.service.plan = _planWithFiles(
      const [],
      luaAvailable: true,
      officialFiles: 1,
    );
    try {
      await _openSheet(tester, fixture);
      expect(find.text('1 · 0 B · 42.lua · Lua disabled'), findsOneWidget);
      final send = find.widgetWithText(ui.TonalButton, 'Send game');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fixture.service.selected, isEmpty);
      expect(fixture.service.discarded, isEmpty);
    } finally {
      fixture.dispose();
    }
  });

  testWidgets(
    'optional-file picker builds visible rows and searches all files',
    (tester) async {
      final fixture = _Fixture();
      fixture.service.plan = _planWithFiles([
        for (var index = 0; index < 10000; index++)
          LanTransferOptionalFile(
            id: '$index',
            relativePath: 'mods/file_$index.bin',
            size: 100,
            category: 'extra',
          ),
      ]);
      try {
        await _openSheet(tester, fixture);
        await _openExtras(tester);
        expect(find.byType(ui.CommonSwitch).evaluate().length, lessThan(50));
        expect(find.text('mods/file_9999.bin'), findsNothing);
        await tester.tap(find.byTooltip('Search'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byType(TextField).last, 'file_9999');
        await tester.pump();
        expect(find.text('mods/file_9999.bin'), findsOneWidget);
        expect(find.byType(ui.CommonSwitch), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        fixture.dispose();
      }
    },
  );

  testWidgets('Lua without game files or manifests does not start a transfer', (
    tester,
  ) async {
    final fixture = _Fixture();
    fixture.service.plan = _planWithFiles(const [], luaAvailable: true);
    try {
      await _openSheet(tester, fixture);
      final send = find.widgetWithText(ui.TonalButton, 'Send game');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(fixture.service.selected, isNull);
      expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(fixture.service.discarded, ['plan']);
    } finally {
      fixture.dispose();
    }
  });
}

Future<void> _openExtras(WidgetTester tester) async {
  final extras = find.text('Additional files and mods').last;
  await tester.ensureVisible(extras);
  await tester.tap(extras);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _openSheet(WidgetTester tester, _Fixture fixture) async {
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
              showLanTransferSendSheet(
                context,
                service: fixture.service,
                settings: fixture.settings,
                game: const GameEntry(appId: 42, name: 'Fixture'),
                initialPeerId: _peer.fingerprint,
              ),
            ),
            child: const Text('open send'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open send'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

class _Fixture {
  _Fixture() {
    service = _Service(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
    );
  }

  final paths = AppPaths('fixture');
  late final settings = SettingsStore(paths);
  late final library = LibraryService(paths: paths, settings: settings);
  final tasks = TaskCenter();
  late final _Service service;

  void dispose() {
    service.dispose();
    tasks.dispose();
    library.dispose();
    settings.dispose();
  }
}

class _Service extends LanTransferService {
  _Service({
    required super.paths,
    required super.settings,
    required super.library,
    required super.tasks,
  });

  final discarded = <String>[];
  Set<String>? selected;
  Future<LanTransferPlanSummary>? preparation;
  LanTransferPlanSummary plan = _plan;

  @override
  List<LanPeer> get peers => const [_peer];

  @override
  Future<LanTransferPlanSummary> prepare(
    GameEntry game, {
    TaskContext? task,
  }) async => preparation ?? plan;

  @override
  Future<void> discardPlan(String planId) async {
    discarded.add(planId);
  }

  @override
  Future<TransferSession> send(
    LanPeer peer,
    LanTransferPlanSummary plan,
    Set<String> selectedOptionalIds,
  ) async {
    selected = Set.of(selectedOptionalIds);
    return TransferSession(
      id: 'send:plan',
      bundleId: 'plan',
      appId: 42,
      gameName: 'Fixture',
      direction: TransferDirection.send,
      peer: peer,
      status: TransferSessionStatus.preparing,
      totalBytes: 100,
      createdAt: DateTime.now(),
    );
  }
}

const _plan = LanTransferPlanSummary(
  planId: 'plan',
  appId: 42,
  gameName: 'Fixture',
  installDir: 'Fixture',
  coverUrl: null,
  luaAvailable: false,
  luaEnabled: false,
  manifestAvailable: true,
  selectedBytes: 0,
  officialBytes: 0,
  manifestBytes: 0,
  optionalBytes: 200,
  officialFiles: 0,
  manifestFiles: 0,
  chunkCount: 2,
  warnings: [],
  optionalFiles: [
    LanTransferOptionalFile(
      id: 'first',
      relativePath: 'mods/first.bin',
      size: 100,
      category: 'extra',
    ),
    LanTransferOptionalFile(
      id: 'second',
      relativePath: 'mods/second.bin',
      size: 100,
      category: 'extra',
    ),
  ],
);

LanTransferPlanSummary _planWithFiles(
  List<LanTransferOptionalFile> files, {
  bool luaAvailable = false,
  int officialFiles = 0,
}) => LanTransferPlanSummary(
  planId: 'plan',
  appId: 42,
  gameName: 'Fixture',
  installDir: 'Fixture',
  coverUrl: null,
  luaAvailable: luaAvailable,
  luaEnabled: false,
  manifestAvailable: true,
  selectedBytes: officialFiles * 100,
  officialBytes: officialFiles * 100,
  manifestBytes: 0,
  optionalBytes: files.length * 100,
  officialFiles: officialFiles,
  manifestFiles: 0,
  chunkCount: files.length + officialFiles,
  warnings: const [],
  optionalFiles: files,
);
