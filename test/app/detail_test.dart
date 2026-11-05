import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/dashboard_page.dart';
import 'package:fl_steam_lua/app/game_detail_page.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/store/store_screenshot.dart';
import 'package:fl_steam_lua/features/store/store_service.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Library extends LibraryService {
  _Library(AppPaths paths, SettingsStore settings)
    : super(paths: paths, settings: settings);
  List<GameEntry> entries = [];
  bool connected = true;
  int launches = 0;
  int installs = 0;
  int removals = 0;
  @override
  List<GameEntry> get games => List.unmodifiable(entries);
  @override
  String? get steamPath => connected ? 'C:/FixtureSteam' : null;
  @override
  List<String> get warnings => [];
  @override
  bool get isScanning => false;
  void replace(GameEntry game) {
    entries = [
      for (final item in entries)
        if (item.appId == game.appId) game else item,
    ];
    notifyListeners();
  }

  @override
  Future<void> setFavorite(int appId, bool favorite) async => replace(
    entries.firstWhere((g) => g.appId == appId).copyWith(isFavorite: favorite),
  );
  @override
  Future<void> toggleLua(int appId, bool enabled) async => replace(
    entries.firstWhere((g) => g.appId == appId).copyWith(luaEnabled: enabled),
  );
  @override
  Future<void> deleteLua(int appId) async {
    removals++;
    entries = entries.where((game) => game.appId != appId).toList();
    notifyListeners();
  }

  @override
  Future<void> launch(int appId) async {
    launches++;
  }

  @override
  Future<void> install(int appId) async {
    installs++;
  }
}

class _Store extends StoreService {
  bool fail = false;
  Completer<StoreGameDetails>? pending;
  @override
  Future<StoreGameDetails> details(int appId, {Future<void>? cancelled}) async {
    if (fail) throw const StoreException('Fixture: offline');
    if (pending != null) return pending!.future;
    return StoreGameDetails(
      appId: appId,
      name: 'Fixture Adventure',
      headerImage: 'https://example.invalid/header.jpg',
      description: 'A real fixture description.',
      dlcIds: appId == 440 ? [441, 442] : [],
      screenshots: const [
        'https://example.invalid/screenshot-1.jpg',
        'https://example.invalid/screenshot-2.jpg',
      ],
      developers: const ['Fixture Studio'],
    );
  }
}

class _Services extends AppServices {
  _Services(super.paths, this.fakeStore)
    : fakeLibrary = _Library(paths, SettingsStore(paths));
  final _Library fakeLibrary;
  final _Store fakeStore;
  @override
  LibraryService get library => fakeLibrary;
  @override
  StoreService get store => fakeStore;

  @override
  void dispose() {
    final fixtureSettings = fakeLibrary.settings;
    super.library.dispose();
    super.store.dispose();
    super.dispose();
    fixtureSettings.dispose();
  }
}

void main() {
  late Directory temp;
  late _Services services;
  const game = GameEntry(
    appId: 440,
    name: 'Fixture Adventure',
    luaPath: 'C:/FixtureSteam/config/lua/440.lua',
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsteamlua-detail-test-');
    services = _Services(AppPaths(temp.path), _Store());
    services.fakeLibrary.entries = [game];
  });

  tearDown(() async {
    services.dispose();
    await temp.delete(recursive: true);
  });

  Widget app(Widget page, {String language = 'en'}) => MaterialApp(
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: page,
  );

  void largeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'playtime displays Steam minutes as hours and preserves unknown',
    (tester) async {
      largeView(tester);
      services.fakeLibrary.replace(game.copyWith(playtimeMinutes: 1247));
      await tester.pumpWidget(
        app(
          GameDetailPage(
            services: services,
            game: game,
            onDestination: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('20.8 hours'), findsOneWidget);

      services.fakeLibrary.replace(game.copyWith(playtimeMinutes: 0));
      await tester.pump();
      expect(find.text('0 minutes'), findsOneWidget);

      services.fakeLibrary.replace(game);
      await tester.pump();
      expect(find.text('0 minutes'), findsNothing);
      expect(find.text('Not recorded'), findsNWidgets(2));
    },
  );

  testWidgets(
    'ownership status stays hidden and local actions survive Store error',
    (tester) async {
      largeView(tester);
      services.fakeStore.fail = true;
      await tester.pumpWidget(
        app(
          GameDetailPage(
            services: services,
            game: game,
            onDestination: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lua configured'), findsOneWidget);
      expect(find.text('Ownership unknown'), findsNothing);
      expect(find.text('Account owns this game'), findsNothing);
      expect(find.text('Install with Steam'), findsOneWidget);
      expect(find.byType(ui.NullStatus), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ui.NullStatus),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Store details are unavailable. Local game actions remain available.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Install with Steam'));
      await tester.pumpAndSettle();
      expect(services.fakeLibrary.installs, 1);
      expect(services.tasks.tasks.single.appId, 440);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('store details show an animated loading skeleton', (
    tester,
  ) async {
    largeView(tester);
    services.fakeStore.pending = Completer<StoreGameDetails>();
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (_, _) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('store-details-loading')), findsOneWidget);
    expect(find.byType(ui.SkeletonPill), findsNWidgets(4));
    services.fakeStore.pending!.complete(
      const StoreGameDetails(
        appId: 440,
        name: 'Fixture Adventure',
        headerImage: '',
        description: 'Loaded description.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store-details-loading')), findsNothing);
    expect(find.text('Loaded description.'), findsOneWidget);
  });

  testWidgets('store screenshots open a zoomable side preview', (tester) async {
    largeView(tester);
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screenshot = find.byType(StoreScreenshot).first;
    await tester.scrollUntilVisible(
      screenshot,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(screenshot);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('store-screenshot-preview')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail destinations retain AppID and realtime library state', (
    tester,
  ) async {
    largeView(tester);
    final destinations = <(String, int)>[];
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (destination, selected) =>
              destinations.add((destination, selected.appId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Achievements'));
    expect(destinations, [('achievements', 440)]);
    await tester.tap(find.text('Cloud saves'));
    expect(destinations.last, ('cloud', 440));
    services.fakeLibrary.replace(
      game.copyWith(isInstalled: true, isFavorite: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Installed'), findsOneWidget);
    expect(find.byTooltip('Unfavorite'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    await tester.tap(find.byTooltip('Unfavorite'));
    await tester.pumpAndSettle();
    expect(services.fakeLibrary.games.single.isFavorite, isFalse);
    expect(find.byTooltip('Favorite'), findsOneWidget);
  });

  testWidgets('Lua removal requires explicit confirmation', (tester) async {
    largeView(tester);
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();
    expect(services.fakeLibrary.removals, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(services.fakeLibrary.removals, 0);
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record').last);
    await tester.pumpAndSettle();
    expect(services.fakeLibrary.removals, 1);
    expect(find.text('Lua record'), findsNothing);
    expect(find.text('Lua configured'), findsNothing);
  });

  testWidgets('DLC section expands metadata without selection controls', (
    tester,
  ) async {
    largeView(tester);
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final section = find.byKey(const ValueKey('game-dlc-section'));
    await tester.ensureVisible(section);
    await tester.tap(section);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: section, matching: find.text('AppID 441')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: section, matching: find.byType(ui.CommonSwitch)),
      findsNothing,
    );
    expect(find.text('Account owns this game'), findsNothing);
  });

  testWidgets('pending details completion after page removal is ignored', (
    tester,
  ) async {
    largeView(tester);
    services.fakeStore.pending = Completer<StoreGameDetails>();
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (_, _) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(app(const SizedBox()));
    services.fakeStore.pending!.complete(
      const StoreGameDetails(appId: 440, name: 'Late data', headerImage: ''),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard has meaningful empty state without invented games', (
    tester,
  ) async {
    largeView(tester);
    services.fakeLibrary.entries = [];
    services.fakeLibrary.connected = false;
    var settingsOpened = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: DashboardPage(
            services: services,
            onNavigate: (_) {},
            detailBuilder: (_) => const SizedBox(),
            onSettings: () => settingsOpened++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Fixture Adventure'), findsNothing);
    expect(find.byTooltip('Choose Steam folder'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose Steam folder'));
    expect(settingsOpened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese detail labels and compact layout render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        GameDetailPage(
          services: services,
          game: game,
          onDestination: (_, _) {},
        ),
        language: 'zh',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('拥有状态未知'), findsNothing);
    expect(find.text('在 Steam 中安装'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
