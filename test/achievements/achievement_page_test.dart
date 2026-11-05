import 'dart:async';

import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/features/achievements/achievement_models.dart';
import 'package:fl_steam_lua/features/achievements/achievement_service.dart';
import 'package:fl_steam_lua/features/achievements/achievements_page.dart';
import 'package:fl_steam_lua/features/achievements/worker_session.dart';
import 'package:fl_steam_lua/ui/theme.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Worker implements AchievementWorkerSession {
  _Worker(this.appId);
  final int appId;
  final states = {'first': false, 'second': true, 'server': false};
  final stats = <String, num>{'score': 10, 'time': 2.5};
  int saves = 0;
  bool failLoad = false;
  Completer<void>? loadGate;

  @override
  Future<AchievementSnapshot> load() async {
    if (failLoad) throw StateError('Fixture: Steam is not running');
    await loadGate?.future;
    return AchievementSnapshot(
      appId: appId,
      achievements: [
        Achievement(
          id: 'first',
          name: 'First steps',
          description: 'Complete the introduction',
          achieved: states['first']!,
          iconUrl: 'https://example.invalid/first-unlocked.png',
          lockedIconUrl: 'https://example.invalid/first-locked.png',
        ),
        Achievement(
          id: 'second',
          name: 'A hidden secret',
          achieved: states['second']!,
          hidden: true,
        ),
        Achievement(
          id: 'server',
          name: 'Server achievement',
          achieved: states['server']!,
          permission: 1,
        ),
      ],
      stats: [
        GameStat(
          id: 'score',
          name: 'Score',
          type: StatType.integer,
          value: stats['score']!,
          minimum: 0,
          maximum: 100,
        ),
        GameStat(
          id: 'time',
          name: 'Time played',
          type: StatType.floating,
          value: stats['time']!,
        ),
      ],
    );
  }

  @override
  Future<void> save(
    Map<String, bool> achievements,
    Map<String, num> statistics,
  ) async {
    saves++;
    states.addAll(achievements);
    stats.addAll(statistics);
  }

  @override
  Future<void> close() async {}

  @override
  Future<SteamTickets> tickets() async => throw UnimplementedError();
}

void main() {
  const games = [
    GameEntry(appId: 10, name: 'Alpha Adventure'),
    GameEntry(appId: 20, name: 'Beta Builder'),
  ];
  late AchievementService service;
  late List<_Worker> workers;
  bool failFirstLoad = false;
  Completer<void>? nextLoadGate;

  setUp(() {
    workers = [];
    failFirstLoad = false;
    nextLoadGate = null;
    service = AchievementService(
      sessionFactory: (appId, steamPath) async {
        final worker = _Worker(appId);
        worker.failLoad = failFirstLoad && workers.isEmpty;
        worker.loadGate = nextLoadGate;
        nextLoadGate = null;
        workers.add(worker);
        return worker;
      },
    );
  });

  tearDown(() async {
    await service.close();
    service.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    GameEntry? selectedGame,
    double width = 1100,
    double height = 820,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: AchievementsPage(
            service: service,
            games: games,
            steamPath: 'C:/FixtureSteam',
            selectedGame: selectedGame,
            language: 'en',
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder imageUrl(String url) => find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is NetworkImage &&
        (widget.image as NetworkImage).url == url,
  );

  Future<void> search(WidgetTester tester, String value) async {
    await tester.tap(find.byKey(const ValueKey('toolbar-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, value);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'game browser restores covers, sorting, list view and AppID search',
    (tester) async {
      await mount(tester);
      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect((grid.padding! as EdgeInsets).top, ui.pageContentTopInset);
      expect(imageUrl(games.first.imageUrl), findsOneWidget);
      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AppID descending'));
      await tester.pumpAndSettle();
      final firstRow = tester.widget<ListTile>(find.byType(ListTile).first);
      expect((firstRow.title! as Text).data, 'Beta Builder');
      await search(tester, '20');
      expect(find.text('Alpha Adventure'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('achievement-game-20')));
      await tester.pumpAndSettle();
      expect(service.game!.appId, 20);
      expect(find.text('First steps'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('achievement-list-fade')),
        findsOneWidget,
      );
      final save = tester.widget<ui.DashboardIconButton>(
        find.byKey(const ValueKey('achievement-save')),
      );
      expect(save.onPressed, isNull);
      expect(workers.single.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bulk changes stage, invert and discard without changing protected achievements',
    (tester) async {
      await mount(tester, selectedGame: games.first);
      final protected = tester.widget<ui.DecorationListItem>(
        find.byKey(const ValueKey('achievement-toggle-server')),
      );
      expect((protected.trailing! as ui.CommonSwitch).onChanged, isNull);
      expect(
        imageUrl('https://example.invalid/first-locked.png'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('achievement-unlock-all')));
      await tester.pumpAndSettle();
      expect(service.pending, {'first': true});
      expect(
        imageUrl('https://example.invalid/first-unlocked.png'),
        findsOneWidget,
      );
      expect(find.text('Pending'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('achievement-lock-all')));
      await tester.pumpAndSettle();
      expect(service.pending, {'second': false});
      await tester.tap(find.byKey(const ValueKey('achievement-invert')));
      await tester.pumpAndSettle();
      expect(service.pending, {'first': true});
      expect(workers.single.states['server'], false);
      expect(workers.single.saves, 0);
      await tester.tap(find.byKey(const ValueKey('achievement-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(service.hasChanges, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'statistics and achievement changes only write after explicit save confirmation',
    (tester) async {
      await mount(tester, selectedGame: games.first);
      await tester.tap(find.byKey(const ValueKey('achievement-toggle-first')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statistics (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Score'));
      await tester.pumpAndSettle();
      expect(find.byType(ui.FormPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(statEditorField(), '22');
      await tester.tap(find.text('Stage change'));
      await tester.pumpAndSettle();
      expect(service.pendingStats, {'score': 22});
      expect(find.text('Pending'), findsOneWidget);
      expect(workers.single.saves, 0);
      await tester.tap(find.byKey(const ValueKey('achievement-save')));
      await tester.pumpAndSettle();
      expect(find.text('10 → 22'), findsOneWidget);
      expect(workers.single.saves, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.hasChanges, true);
      await tester.tap(find.byKey(const ValueKey('achievement-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to Steam'));
      await tester.pumpAndSettle();
      expect(workers.single.saves, 1);
      expect(workers.single.states['first'], true);
      expect(workers.single.stats['score'], 22);
      expect(service.hasChanges, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'statistic dialog retains its field through dismissal and can reopen',
    (tester) async {
      await mount(tester, selectedGame: games.first);
      await tester.tap(find.text('Statistics (2)'));
      await tester.pumpAndSettle();
      await search(tester, 'score');
      await tester.tap(find.byTooltip('Edit statistic'));
      await tester.pumpAndSettle();
      final dialogField = statEditorField();
      await tester.enterText(dialogField, '35');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(service.pendingStats, isEmpty);
      await tester.tap(find.byTooltip('Edit statistic'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(dialogField).controller!.text, '10');
      await tester.enterText(dialogField, '35');
      await tester.tap(find.text('Stage change'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(service.pendingStats, {'score': 35});
      expect(workers.single.saves, 0);
    },
  );

  testWidgets(
    'browsing preserves edits and switching games asks before discarding',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('achievement-game-10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('achievement-unlock-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Continue editing Alpha Adventure'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('achievement-continue-editing')),
          matching: find.byType(ui.ItemPositionProvider),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('achievement-game-list-fade')),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue editing Alpha Adventure'));
      await tester.pumpAndSettle();
      expect(service.pending, {'first': true});
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('achievement-game-20')));
      await tester.pumpAndSettle();
      expect(find.text('Discard pending changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(service.game!.appId, 10);
      expect(service.pending, {'first': true});
      await tester.tap(find.byKey(const ValueKey('achievement-game-20')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard and continue'));
      await tester.pumpAndSettle();
      expect(service.game!.appId, 20);
      expect(service.hasChanges, false);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('achievement-continue-editing')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed first load leaves reload available and retries the same AppID',
    (tester) async {
      failFirstLoad = true;
      await mount(tester, selectedGame: games.first);
      expect(service.data, isNull);
      final reload = tester.widget<ui.DashboardIconButton>(
        find.byKey(const ValueKey('achievement-reload')),
      );
      expect(reload.onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('achievement-reload')));
      await tester.pumpAndSettle();
      expect(workers.length, 2);
      expect(service.data!.appId, 10);
      expect(find.text('First steps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor shows a loading skeleton while achievements load', (
    tester,
  ) async {
    final gate = Completer<void>();
    nextLoadGate = gate;
    await mount(tester, selectedGame: games.first, settle: false);
    await tester.pump();
    expect(find.byType(ui.SkeletonPill), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('First steps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact editor keeps bulk tools and save action visible without overflow',
    (tester) async {
      await mount(tester, selectedGame: games.first, width: 700, height: 720);
      await tester.tap(find.byKey(const ValueKey('achievement-unlock-all')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('achievement-save')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('achievement-lock-all')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('achievement-invert')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('achievement-bulk-toolbar')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Finder statEditorField() => find.descendant(
  of: find.byType(ui.FormPage),
  matching: find.byType(TextField),
);
