import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/dashboard_page.dart';
import 'package:fl_steam_lua/app/library_page.dart';
import 'package:fl_steam_lua/app/settings_page.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/features/tools/tool_pages.dart';
import 'package:fl_steam_lua/features/tools/tools_page.dart';
import 'package:fl_steam_lua/main.dart';
import 'package:fl_steam_lua/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppServices services;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('fl-shell-');
    services = AppServices(AppPaths(root.path));
    await services.settings.set('quickStartDismissed', true);
    await services.settings.set('coverCdn', 'direct');
  });
  tearDown(() async {
    await services.shutdown();
    services.dispose();
    await root.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    double width = 1280,
    double devicePixelRatio = 1,
  }) async {
    tester.view.physicalSize = Size(
      width * devicePixelRatio,
      820 * devicePixelRatio,
    );
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(services)],
        child: const FlSteamLuaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSidebar(
    WidgetTester tester,
    String label, {
    bool settle = true,
  }) async {
    final target = find
        .descendant(
          of: find.byType(NavigationSidebar),
          matching: find.byTooltip(label),
        )
        .hitTestable();
    expect(target, findsOneWidget);
    await tester.tap(target);
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('five ordered primary destinations and real empty library', (
    tester,
  ) async {
    await mount(tester);
    final sidebar = tester.widget<NavigationSidebar>(
      find.byType(NavigationSidebar),
    );
    expect(sidebar.destinations.map((d) => d.label), [
      '面板主页',
      '库',
      '商店',
      '成就',
      '云存档',
    ]);
    expect(find.byType(DashboardPage), findsOneWidget);
    await tapSidebar(tester, '库');
    expect(find.byType(LibraryPage), findsOneWidget);
    expect(find.text('连接你的 Steam 游戏库'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('navigation retains page state and running app task', (
    tester,
  ) async {
    await mount(tester);
    late Completer<void> release;
    late Future<void> task;
    // The task represents real background I/O, independently of widget frames.
    // Keeping its futures outside fake time also lets application teardown await it.
    await tester.runAsync(() async {
      release = Completer<void>();
      task = services.tasks.run('Long operation', (_) => release.future);
    });
    try {
      await tapSidebar(tester, '库', settle: false);
      await tester.tap(find.byKey(const ValueKey('toolbar-search-button')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).first, 'query stays');
      await tapSidebar(tester, '面板主页', settle: false);
      expect(services.tasks.runningCount, 1);
      await tapSidebar(tester, '库', settle: false);
      expect(find.text('query stays'), findsOneWidget);
    } finally {
      await tester.runAsync(() async {
        release.complete();
        await task;
      });
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(services.tasks.runningCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact window and English dark theme render without overflow', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await services.settings.set('language', 'en');
      await services.settings.set('theme', 'dark');
    });
    await mount(tester, width: 760);
    expect(
      tester.widget<NavigationSidebar>(find.byType(NavigationSidebar)).expanded,
      isFalse,
    );
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tools and Settings are primary sidebar pages', (tester) async {
    await mount(tester);
    for (final destination in ['工具', '设置']) {
      await tapSidebar(tester, destination);
      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byTooltip('任务'), findsOneWidget);
      expect(
        destination == '工具'
            ? find.byType(ToolsPage)
            : find.byType(SettingsPage),
        findsOneWidget,
      );
      expect(find.byType(BackButton), findsNothing);
      await tapSidebar(tester, '面板主页');
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.byType(ToolsPage), findsNothing);
      expect(find.byType(SettingsPage), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('task entry opens the shared side sheet framework', (
    tester,
  ) async {
    await mount(tester);
    final tasks = find.byTooltip('任务').hitTestable();
    expect(tasks, findsOneWidget);
    await tester.tap(tasks);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SideSheetScaffold), findsOneWidget);
    Navigator.of(tester.element(find.byType(SideSheetScaffold))).pop();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sidebar expands continuously with account below settings', (
    tester,
  ) async {
    await mount(tester);
    final settings = find.descendant(
      of: find.byType(NavigationSidebar),
      matching: find.byTooltip('设置'),
    );
    final account = find.descendant(
      of: find.byType(NavigationSidebar),
      matching: find.byTooltip('Steam 账号'),
    );
    expect(settings, findsOneWidget);
    expect(account, findsOneWidget);
    expect(
      tester.getTopLeft(settings).dy,
      lessThan(tester.getTopLeft(account).dy),
    );

    await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final middleWidth = tester.getSize(find.byType(NavigationSidebar)).width;
    expect(middleWidth, greaterThan(48));
    expect(middleWidth, lessThan(220));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getSize(find.byType(NavigationSidebar)).width,
      closeTo(220, .1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('floating blurred sidebar keeps an end-side page gap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await services.settings.set('sidebarFloating', true);
      await services.settings.set('sidebarBlur', true);
      await services.settings.set('sidebarExpanded', true);
    });
    await mount(tester);

    final shell = tester.getRect(find.byKey(const ValueKey('sidebar-shell')));
    final sidebar = tester.getRect(find.byType(NavigationSidebar));
    expect(sidebar.left - shell.left, 8);
    expect(shell.right - sidebar.right, 8);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Tools groups features and opens dedicated work pages', (
    tester,
  ) async {
    await mount(tester);
    await tapSidebar(tester, '工具');
    expect(find.text('文件与清单'), findsOneWidget);
    expect(find.text('游戏工具'), findsOneWidget);
    await tester.tap(find.text('Lua / VDF 转换'));
    await tester.pumpAndSettle();
    expect(find.byType(ToolConverterPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ToolsPage), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text('维护'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('150 percent scaling preserves Ctrl+1 and Ctrl+2 navigation', (
    tester,
  ) async {
    await mount(tester, devicePixelRatio: 1.5);
    expect(
      MediaQuery.devicePixelRatioOf(tester.element(find.byType(DashboardPage))),
      1.5,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LibraryPage), findsOneWidget);
    expect(
      tester
          .widget<NavigationSidebar>(find.byType(NavigationSidebar))
          .selectedIndex,
      1,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(
      tester
          .widget<NavigationSidebar>(find.byType(NavigationSidebar))
          .selectedIndex,
      0,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dashboard library actions retarget the retained library page', (
    tester,
  ) async {
    await mount(tester);
    await tapSidebar(tester, '库');
    await tapSidebar(tester, '面板主页');
    tester.widget<DashboardPage>(find.byType(DashboardPage)).onLibraryTab!(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<LibraryPage>(find.byType(LibraryPage)).initialTab, 1);
    await tapSidebar(tester, '面板主页');
    tester.widget<DashboardPage>(find.byType(DashboardPage)).onLibraryTab!(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<LibraryPage>(find.byType(LibraryPage)).initialTab, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
