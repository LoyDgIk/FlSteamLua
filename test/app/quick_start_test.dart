import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/app_shell.dart';
import 'package:fl_steam_lua/app/quick_start_page.dart';
import 'package:fl_steam_lua/app/settings_page.dart';
import 'package:fl_steam_lua/app/theme_settings_page.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/kernel/kernel_settings_page.dart';
import 'package:fl_steam_lua/features/library/lua_directories.dart';
import 'package:fl_steam_lua/features/library/lua_directories_page.dart';
import 'package:fl_steam_lua/main.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late AppServices services;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('quick-start-');
    services = AppServices(AppPaths(p.join(temp.path, 'app')));
    await services.paths.initialize();
    await services.settings.set('autoCheckKernelUpdate', false);
    await services.settings.set('autoCheckUpdates', false);
    await services.settings.set('themeFollowSystem', false);
  });

  tearDown(() async {
    await services.shutdown();
    services.dispose();
    await temp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> mount(WidgetTester tester, {double width = 1200}) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appServicesProvider.overrideWithValue(services)],
          child: const FlSteamLuaApp(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
  }

  Future<void> selectStep(WidgetTester tester, int index) async {
    tester
        .widget<ui.SegmentedControl<int>>(
          find.byKey(const ValueKey('quick-start-steps')),
        )
        .onChanged(index);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'first launch opens setup and skipping persists across a new app instance',
    (tester) async {
      await mount(tester);
      expect(find.byType(QuickStartWindow), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(ui.WindowHeader), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('quick-start-language')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('quick-start-theme-mode')))
              .dy,
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('quick-start-skip')));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await settle(tester);
      expect(services.settings.quickStartDismissed, isTrue);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(QuickStartPage), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      late AppServices reloaded;
      await tester.runAsync(() async {
        reloaded = AppServices(services.paths);
        await reloaded.settings.load();
      });
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appServicesProvider.overrideWithValue(reloaded)],
            child: const FlSteamLuaApp(),
          ),
        );
        await settle(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(find.byType(QuickStartWindow), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        await tester.runAsync(reloaded.shutdown);
        reloaded.dispose();
      }
    },
  );

  testWidgets(
    'language and appearance changes apply without leaving the guide',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('English'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);
      expect(services.settings.language, 'en');
      expect(find.text('Quick start'), findsOneWidget);
      expect(find.byType(QuickStartPage), findsOneWidget);

      await tester.runAsync(() async {
        tester
            .widget<ui.SegmentedControl<String>>(
              find.byKey(const ValueKey('quick-start-theme-mode')),
            )
            .onChanged('dark');
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await settle(tester);
      expect(
        Theme.of(tester.element(find.byType(QuickStartPage))).brightness,
        Brightness.dark,
      );
      await tester.runAsync(() async {
        tester
            .widget<ThemeColorSwatches>(
              find.byKey(const ValueKey('quick-start-colors')),
            )
            .onSelect(0xff34c759);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await settle(tester);
      expect(services.settings.themeSeed, 0xff34c759);
      expect(services.settings.themeFollowSystem, isFalse);
      await tester.runAsync(() async {
        tester
            .widget<ui.SegmentedControl<bool>>(
              find.byKey(const ValueKey('quick-start-sidebar-style')),
            )
            .onChanged(true);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await settle(tester);
      expect(services.settings.sidebarFloating, isTrue);
      expect(services.settings.quickStartDismissed, isFalse);

      await selectStep(tester, 1);
      await selectStep(tester, 0);
      expect(
        tester
            .widget<ui.SegmentedControl<String>>(
              find.byKey(const ValueKey('quick-start-theme-mode')),
            )
            .value,
        'dark',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'all steps are optional and navigation stays fixed while changing steps',
    (tester) async {
      await mount(tester, width: 600);
      final footer = find.byKey(const ValueKey('quick-start-navigation'));
      final before = tester.getRect(footer);
      await tester.tap(find.byKey(const ValueKey('quick-start-next')));
      for (final millis in [0, 16, 100, 300]) {
        await tester.pump(Duration(milliseconds: millis));
        expect(tester.getRect(footer), before);
        expect(tester.takeException(), isNull);
      }
      expect(find.byKey(const ValueKey('quick-start-steam')), findsOneWidget);
      expect(
        tester
            .widget<ui.DecorationListItem>(
              find.byKey(const ValueKey('quick-start-lua')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('quick-start-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(footer), before);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('quick-start-next')));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await settle(tester);
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'configuration destinations use existing services and retain the guide step',
    (tester) async {
      final steam = Directory(p.join(temp.path, 'steam'));
      await tester.runAsync(() async {
        await steam.create();
        await File(p.join(steam.path, 'steam.exe')).writeAsString('fixture');
        await services.settings.set('steamPath', steam.path);
      });
      await mount(tester);
      await selectStep(tester, 1);
      expect(find.text(LuaDirectories(steam.path).coreDefault), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quick-start-steam')));
      await settle(tester);
      expect(find.byType(SteamFilesPage), findsOneWidget);
      expect(find.byType(ui.WindowHeader), findsOneWidget);
      Navigator.of(tester.element(find.byType(SteamFilesPage))).pop();
      await settle(tester);
      expect(find.byKey(const ValueKey('quick-start-step-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('quick-start-lua')));
      await settle(tester);
      expect(
        tester
            .widget<LuaDirectoriesPage>(find.byType(LuaDirectoriesPage))
            .steamPath,
        steam.path,
      );
      Navigator.of(tester.element(find.byType(LuaDirectoriesPage))).pop();
      await settle(tester);
      await selectStep(tester, 2);
      await tester.tap(find.byKey(const ValueKey('quick-start-kernel')));
      await settle(tester);
      expect(
        tester
            .widget<KernelSettingsPage>(find.byType(KernelSettingsPage))
            .service,
        same(services.kernel),
      );
      Navigator.of(tester.element(find.byType(KernelSettingsPage))).pop();
      await settle(tester);
      expect(find.byKey(const ValueKey('quick-start-step-2')), findsOneWidget);
      expect(services.settings.quickStartDismissed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('settings reopens quick start and closes back to settings', (
    tester,
  ) async {
    await tester.runAsync(
      () => services.settings.set('quickStartDismissed', true),
    );
    await mount(tester);
    tester
        .widget<ui.NavigationSidebar>(find.byType(ui.NavigationSidebar))
        .onSelected(6);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('quick-start-settings')));
    await settle(tester);
    expect(find.byType(QuickStartPage), findsOneWidget);
    expect(find.byType(QuickStartWindow), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('quick-start-skip')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await settle(tester);
    expect(find.byType(QuickStartPage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(services.settings.quickStartDismissed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'minimum window with larger text keeps navigation and language reachable',
    (tester) async {
      await tester.runAsync(() async {
        await services.settings.set('textScaleEnabled', true);
        await services.settings.set('textScale', 1.5);
      });
      await mount(tester, width: 760);
      tester.view.physicalSize = const Size(760, 560);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      expect(find.text('English').hitTestable(), findsOneWidget);
      for (var step = 0; step < 3; step++) {
        await selectStep(tester, step);
        expect(
          find.byKey(const ValueKey('quick-start-next')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('quick-start-skip')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('incomplete setup is offered again after restart', () async {
    await services.settings.set('theme', 'dark');
    final reloaded = SettingsStore(services.paths);
    await reloaded.load();
    expect(reloaded.quickStartDismissed, isFalse);
    expect(reloaded.theme, 'dark');
    reloaded.dispose();
  });
}
