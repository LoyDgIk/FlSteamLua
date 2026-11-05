import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/library_page.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/lua_editor_page.dart';
import 'package:fl_steam_lua/features/network/network_cover_image.dart';
import 'package:fl_steam_lua/features/patching/ticket_authorization.dart';
import 'package:fl_steam_lua/features/patching/ticket_page.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeLuaLibrary extends LibraryService {
  _FakeLuaLibrary(AppPaths paths, SettingsStore settings)
    : super(paths: paths, settings: settings);

  @override
  Future<String> readLua(int appId) async => 'addappid(550)\n';

  @override
  Future<void> saveLua(int appId, String content) async {}
}

void main() {
  late Directory temp;
  late AppServices services;
  final destinations = <(String, int)>[];

  Future<void> write(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('fl-library-page-');
    services = AppServices(AppPaths(p.join(temp.path, 'app')));
    await services.paths.initialize();
    final steam = p.join(temp.path, 'steam');
    await services.settings.set('steamPath', steam);
    await services.settings.set('language', 'en');
    await services.settings.set('coverCdn', 'direct');
    await write(
      p.join(steam, 'config', 'lua', '10.lua'),
      'addappid(10)\nsetManifestid(11,"123456789",0)',
    );
    await write(
      p.join(steam, 'config', 'lua', 'Disable', '20.lua'),
      'addappid(20)',
    );
    for (final id in [20, 30]) {
      await write(
        p.join(steam, 'steamapps', 'appmanifest_$id.acf'),
        Kv1.stringify({
          'AppState': {
            'appid': '$id',
            'name': id == 20 ? 'Shared Adventure' : 'Installed Adventure',
            'installdir': 'game-$id',
            'StateFlags': '4',
          },
        }),
      );
      await Directory(
        p.join(steam, 'steamapps', 'common', 'game-$id'),
      ).create(recursive: true);
    }
    await services.library.scan();
    await services.library.updateGameMetadata(
      10,
      name: 'Lua Adventure',
      coverUrl: 'https://example.test/10.jpg',
    );
    destinations.clear();
  });

  tearDown(() async {
    await services.shutdown();
    services.dispose();
    await temp.delete(recursive: true);
  });

  Widget app({int initialTab = 0, int tabRequest = 0}) => MaterialApp(
    theme: ui.buildAppTheme(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: LibraryPage(
        services: services,
        initialTab: initialTab,
        tabRequest: tabRequest,
        onSettings: () {},
        onDestination: (destination, game) =>
            destinations.add((destination, game.appId)),
        detailBuilder: (game) => Scaffold(body: Text('Detail ${game.appId}')),
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> mount(WidgetTester tester, {int initialTab = 0}) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(initialTab: initialTab));
    await settle(tester);
  }

  Set<int> visibleIds(WidgetTester tester) => tester
      .widgetList<GameCard>(find.byType(GameCard))
      .map((card) => card.game.appId)
      .toSet();

  Future<void> selectScope(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('library-scope-menu')));
    await settle(tester);
    final menu = tester.widget<ui.CommonPopupMenu>(
      find.byType(ui.CommonPopupMenu),
    );
    menu.items.singleWhere((item) => item.label == label).onPressed!();
    await tester.pump();
    Navigator.of(tester.element(find.byType(ui.CommonPopupMenu))).pop();
    await settle(tester);
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('toolbar-search-button')));
    await settle(tester);
  }

  testWidgets(
    'default Lua scope manages records and Steam scope contains installed games',
    (tester) async {
      await mount(tester);
      expect(visibleIds(tester), {10, 20});
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect((grid.padding! as EdgeInsets).top, ui.pageContentTopInset);
      expect(find.byTooltip('Set Lua library folder'), findsNothing);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('library-more-menu')),
          matching: find.byType(ui.TonalButtonTheme),
        ),
        findsOneWidget,
      );
      final luaCover = tester
          .widgetList<NetworkCoverImage>(find.byType(NetworkCoverImage))
          .firstWhere((image) => image.appId == 10);
      expect(luaCover.url, 'https://example.test/10.jpg');
      expect(find.text('Lua Adventure'), findsOneWidget);
      expect(find.text('Version pinned'), findsOneWidget);
      await selectScope(tester, 'Steam games');
      expect(visibleIds(tester), {20, 30});
      expect(find.text('Lua Adventure'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'initial scope can open Steam directly and updates without replacing page state',
    (tester) async {
      await mount(tester, initialTab: 1);
      final element = tester.element(find.byType(LibraryPage));
      expect(visibleIds(tester), {20, 30});
      await openSearch(tester);
      expect(find.text('Library'), findsOneWidget);
      expect(
        tester.getSize(find.byType(TextField).first).width,
        lessThanOrEqualTo(300),
      );
      final hiddenToolbarActions = tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.byKey(const ValueKey('library-more-menu')),
              matching: find.byType(FadeTransition),
            ),
          )
          .any((transition) => transition.opacity.value == 0);
      expect(hiddenToolbarActions, isTrue);
      await tester.enterText(find.byType(TextField).first, 'Adventure');
      await tester.pumpWidget(app(initialTab: 0));
      await settle(tester);
      expect(
        identical(tester.element(find.byType(LibraryPage)), element),
        isTrue,
      );
      expect(find.text('Adventure'), findsOneWidget);
      expect(visibleIds(tester), {10, 20});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ordinary rebuild keeps selected scope and search; explicit request retargets it',
    (tester) async {
      await mount(tester);
      await selectScope(tester, 'Steam games');
      await openSearch(tester);
      await tester.enterText(find.byType(TextField).first, 'Adventure');
      await tester.pumpWidget(app());
      await settle(tester);
      expect(visibleIds(tester), {20, 30});
      await tester.pumpWidget(app(tabRequest: 1));
      await settle(tester);
      expect(visibleIds(tester), {10, 20});
      expect(find.text('Adventure'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('game actions are grouped under functional second-level menus', (
    tester,
  ) async {
    await mount(tester);
    final card = find.ancestor(
      of: find.text('Lua Adventure'),
      matching: find.byType(ui.ContextMenuRegion),
    );
    final contextItems = tester.widget<ui.ContextMenuRegion>(card).menuItems!;
    expect(contextItems.length, lessThanOrEqualTo(7));
    expect(
      contextItems.map((item) => item.label),
      containsAll(['Lua library', 'Game management', 'More']),
    );
    final contextManagement = contextItems.singleWhere(
      (item) => item.label == 'Game management',
    );
    expect(
      contextManagement.subItems.map((item) => item.label),
      contains('Clear Steam manifest cache'),
    );
    final saveAction = contextManagement.subItems.singleWhere(
      (item) => item.label == 'Manage game saves',
    );
    saveAction.onPressed!();
    expect(destinations, [('cloud', 10)]);
    destinations.clear();
    final origin =
        tester.getTopLeft(find.byType(GameCard).first) + const Offset(70, 60);
    await tester.tapAt(origin, buttons: kSecondaryMouseButton);
    await settle(tester);
    final menu = tester.widget<ui.CommonPopupMenu>(
      find.byType(ui.CommonPopupMenu),
    );
    expect(
      menu.items.map((item) => item.label),
      contextItems.map((item) => item.label),
    );
    final action = menu.items
        .singleWhere((item) => item.label == 'Game management')
        .subItems
        .singleWhere((item) => item.label == 'Manage game saves');
    action.onPressed!();
    expect(destinations, [('cloud', 10)]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Lua files have a real desktop drop target and visible drop feedback',
    (tester) async {
      await mount(tester);
      final target = tester.widget<DropTarget>(find.byType(DropTarget));
      expect(target.onDragDone, isNotNull);
      target.onDragEntered!(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(
        find.text('Drop to import Lua, manifests or archives'),
        findsOneWidget,
      );
      target.onDragExited!(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(
        find.text('Drop to import Lua, manifests or archives'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'ticket drag import opens authorization instead of content import',
    (tester) async {
      final app = Uint8List(24);
      ByteData.sublistView(app)
        ..setUint32(8, 1234, Endian.little)
        ..setUint32(16, 480, Endian.little);
      final ticket = AuthorizationTicket(
        appId: 480,
        steamId: BigInt.from(1234),
        appTicket: app,
        eTicket: Uint8List.fromList([1, 2, 3]),
      );
      final file = File(p.join(temp.path, 'tickets.txt'));
      await tester.runAsync(() => file.writeAsString(ticket.exportText()));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => importLibraryFiles(
                  context,
                  services,
                  sourcePaths: [file.path],
                ),
                child: const Text('Import ticket'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import ticket'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
      expect(find.byType(TicketPage), findsOneWidget);
      expect(find.text('Ticket management'), findsWidgets);
      expect(find.text('AppID 480'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('toolbar switches view and search empty state', (tester) async {
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('library-view-menu')));
    await settle(tester);
    final viewMenu = tester.widget<ui.CommonPopupMenu>(
      find.byType(ui.CommonPopupMenu),
    );
    viewMenu.items
        .singleWhere((item) => item.label == 'List view')
        .onPressed!();
    await tester.pump();
    Navigator.of(tester.element(find.byType(ui.CommonPopupMenu))).pop();
    await settle(tester);
    expect(find.byType(GameCard), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));

    await openSearch(tester);
    await tester.enterText(find.byType(TextField).first, 'no such game');
    await settle(tester);
    expect(find.text('No matching results'), findsOneWidget);
    expect(find.byType(ui.NullStatus), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lua editor uses the editor toolbar layout', (tester) async {
    final library = _FakeLuaLibrary(services.paths, services.settings);
    addTearDown(library.dispose);
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ui.buildAppTheme(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: LuaEditorPage(
          library: library,
          game: const GameEntry(appId: 550, name: 'Fixture Lua'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lua-editor-content')), findsOneWidget);
    expect(find.byKey(const ValueKey('lua-editor-tools')), findsOneWidget);
    expect(find.byKey(const ValueKey('lua-editor-save')), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lua-editor-tools')));
    await tester.pumpAndSettle();
    expect(find.text('addappid(AppID)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
