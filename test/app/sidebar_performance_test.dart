import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/library_page.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/main.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingLibrary extends LibraryService {
  _CountingLibrary(AppPaths paths)
    : super(paths: paths, settings: SettingsStore(paths));
  int avatarQueries = 0;
  @override
  List<SteamLocalAccount> get accounts => const [
    SteamLocalAccount(
      steamId: '1',
      accountName: 'fixture',
      personaName: 'Fixture',
      mostRecent: true,
    ),
  ];
  @override
  String? avatarPath(SteamLocalAccount account) {
    avatarQueries++;
    return null;
  }
}

class _Services extends AppServices {
  _Services(super.paths) : fixtureLibrary = _CountingLibrary(paths);
  final _CountingLibrary fixtureLibrary;
  @override
  LibraryService get library => fixtureLibrary;
  @override
  void dispose() {
    super.library.dispose();
    fixtureLibrary.settings.dispose();
    super.dispose();
  }
}

void main() {
  testWidgets(
    'persisting sidebar expansion does not start a theme transition',
    (tester) async {
      late Directory root;
      late _Services services;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('sidebar-theme-');
        services = _Services(AppPaths(root.path));
        await services.settings.set('quickStartDismissed', true);
        await services.settings.set('autoCheckUpdates', false);
        await services.settings.set('themeFollowSystem', false);
      });
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appServicesProvider.overrideWithValue(services)],
            child: const FlSteamLuaApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
        final beforeWidth = tester
            .getSize(find.byType(ui.NavigationSidebar))
            .width;
        await tester.runAsync(() async {
          tester
              .widget<ui.NavigationSidebar>(find.byType(ui.NavigationSidebar))
              .onToggle!();
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final startWidth = tester
            .getSize(find.byType(ui.NavigationSidebar))
            .width;
        final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(identical(before.theme, after.theme), isTrue);
        expect(identical(before.darkTheme, after.darkTheme), isTrue);
        expect(startWidth, greaterThan(beforeWidth));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.getSize(find.byType(ui.NavigationSidebar)).width,
          closeTo(220, .1),
        );
        await tester.runAsync(
          () => services.settings.set('themeSeed', 0xffb22070),
        );
        await tester.pump();
        final changed = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(identical(after.theme, changed.theme), isFalse);
        expect(identical(after.darkTheme, changed.darkTheme), isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await services.shutdown();
          services.dispose();
          await root.delete(recursive: true);
        });
      }
    },
  );

  testWidgets(
    'hidden library does not relayout during sidebar or window resize',
    (tester) async {
      late Directory root;
      late _Services services;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('sidebar-performance-');
        services = _Services(AppPaths(root.path));
        await services.settings.set('quickStartDismissed', true);
        await services.settings.set('autoCheckUpdates', false);
        await services.settings.set('autoCheckKernelUpdate', false);
      });
      var hiddenLayouts = 0;
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appServicesProvider.overrideWithValue(services)],
            child: const FlSteamLuaApp(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        Future<void> navigate(String label) async {
          await tester.tap(
            find
                .descendant(
                  of: find.byType(ui.NavigationSidebar),
                  matching: find.byTooltip(label),
                )
                .hitTestable(),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        }

        await navigate('库');
        Navigator.of(tester.element(find.byType(LibraryPage))).push(
          MaterialPageRoute<void>(
            builder: (_) => LayoutBuilder(
              builder: (_, constraints) {
                hiddenLayouts++;
                return ListView.builder(
                  itemCount: 500,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 48, child: Text('Fixture game $index')),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await navigate('面板主页');
        final before = hiddenLayouts;
        final avatarsBefore = services.fixtureLibrary.avatarQueries;
        await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final expansionLayouts = hiddenLayouts - before;
        final expansionAvatars =
            services.fixtureLibrary.avatarQueries - avatarsBefore;
        for (var width = 1260; width >= 1000; width -= 20) {
          tester.view.physicalSize = Size(width.toDouble(), 820);
          await tester.pump(const Duration(milliseconds: 16));
        }
        final resizeLayouts = hiddenLayouts - before - expansionLayouts;
        expect(
          expansionAvatars,
          lessThanOrEqualTo(2),
          reason: 'Avatar filesystem lookup must not run every animation frame',
        );
        expect(
          expansionLayouts,
          0,
          reason:
              'Sidebar animation must not relayout retained invisible pages',
        );
        expect(
          resizeLayouts,
          0,
          reason:
              'Resizing the window must not repeatedly lay out hidden navigation stacks',
        );
        tester
            .widget<ui.NavigationSidebar>(find.byType(ui.NavigationSidebar))
            .onSelected(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Fixture game 0'), findsOneWidget);
        expect(hiddenLayouts, greaterThan(before));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await services.shutdown();
          services.dispose();
          await root.delete(recursive: true);
        });
      }
    },
  );
}
