import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/network/network_preferences.dart';
import 'package:fl_steam_lua/features/network/network_settings_page.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late SettingsStore settings;
  late TaskCenter tasks;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fl-network-page-');
    settings = SettingsStore(AppPaths(directory.path));
    tasks = TaskCenter();
  });

  tearDown(() async {
    settings.dispose();
    tasks.dispose();
    await directory.delete(recursive: true);
  });

  testWidgets('network choices render without starting network tasks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: resolveAppLocale(settings.language),
        home: NetworkSettingsPage(settings: settings, tasks: tasks),
      ),
    );
    expect(find.text('网络与下载来源'), findsOneWidget);
    expect(find.byKey(const ValueKey('cover-source-selector')), findsOneWidget);
    expect(tasks.tasks, isEmpty);
    expect(tester.takeException(), isNull);

    final selected = NetworkPreferences.coverSources.last;
    await tester.tap(find.byKey(const ValueKey('cover-source-selector')));
    await tester.pumpAndSettle();
    final menu = tester.widget<ui.CommonPopupMenu>(
      find.byType(ui.CommonPopupMenu),
    );
    expect(menu.items.any((item) => item.label == '自动'), isTrue);
    expect(menu.items.any((item) => item.label == '小黑盒接口'), isTrue);
    await tester.runAsync(() async {
      menu.items
          .singleWhere(
            (item) => item.label == selected.label(localizationsFor('zh')),
          )
          .onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    Navigator.of(tester.element(find.byType(ui.CommonPopupMenu))).pop();
    await tester.pumpAndSettle();
    final preference = NetworkPreferences(settings);
    expect(preference.coverSourceId, selected.id);
    preference.dispose();
    final persisted = SettingsStore(AppPaths(directory.path));
    await tester.runAsync(persisted.load);
    expect(persisted.get<String>('coverCdn', ''), selected.id);
    persisted.dispose();

    await tester.tap(find.byKey(const ValueKey('test-cover-sources')));
    await tester.pumpAndSettle();
    expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('network-probe-heybox')), findsOneWidget);
    Navigator.of(tester.element(find.byType(ui.SideSheetScaffold))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('github-mirror-selector')));
    await tester.pumpAndSettle();
    final mirrorMenu = tester.widget<ui.CommonPopupMenu>(
      find.byType(ui.CommonPopupMenu),
    );
    expect(
      mirrorMenu.items.any((item) => item.label == '自定义 GitHub 镜像'),
      isTrue,
    );
    Navigator.of(tester.element(find.byType(ui.CommonPopupMenu))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('test-github-mirrors')));
    await tester.pumpAndSettle();
    expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('network-probe-direct')), findsOneWidget);
    Navigator.of(tester.element(find.byType(ui.SideSheetScaffold))).pop();
    await tester.pumpAndSettle();

    expect(tasks.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('English compact page keeps source controls reachable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await settings.set('language', 'en');
      await settings.set('githubMirror', NetworkPreferences.customMirrorId);
      await settings.set(
        'githubMirrorCustom',
        'https://mirror.example.com/proxy',
      );
    });
    await tester.binding.setSurfaceSize(const Size(600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: resolveAppLocale(settings.language),
        home: NetworkSettingsPage(settings: settings, tasks: tasks),
      ),
    );
    expect(find.text('Network and download sources'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('github-mirror-selector')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('custom-github-mirror')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('https://mirror.example.com/proxy'), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(tasks.tasks, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
