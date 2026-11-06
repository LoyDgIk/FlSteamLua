import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/app/app_services.dart';
import 'package:fl_steam_lua/app/data_management_page.dart';
import 'package:fl_steam_lua/app/settings_page.dart';
import 'package:fl_steam_lua/app/theme_settings_page.dart';
import 'package:fl_steam_lua/core/app_release.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/cloud/cloud_redirect_plugin_page.dart';
import 'package:fl_steam_lua/features/kernel/kernel_settings_page.dart';
import 'package:fl_steam_lua/features/library/lua_directories.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late AppServices services;
  final opened = <Widget>[];

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flsteamlua-settings-');
    services = AppServices(AppPaths(p.join(directory.path, 'app')));
    await services.paths.initialize();
    opened.clear();
  });

  tearDown(() async {
    services.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> render(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: services.settings,
        builder: (_, _) => MaterialApp(
          locale: resolveAppLocale(services.settings.language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => SettingsPage(
              services: services,
              onOpenPage: (page) {
                opened.add(page);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page));
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> renderTheme(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: services.settings,
        builder: (_, _) => MaterialApp(
          locale: resolveAppLocale(services.settings.language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeSettingsPage(settings: services.settings),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    } else {
      await tester.ensureVisible(finder);
    }
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    final widget = tester.widget(finder);
    if (widget is ButtonStyleButton) {
      await tester.runAsync(() async {
        await (widget.onPressed as dynamic)();
      });
    } else if (widget is ui.ListItem) {
      await tester.runAsync(() async {
        widget.onTap?.call();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    } else if (widget is ui.DecorationListItem) {
      await tester.runAsync(() async {
        widget.onPressed?.call();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    } else {
      await tester.tap(finder);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> editPath(
    WidgetTester tester,
    String fieldKey,
    String value,
  ) async {
    await tester.tap(find.byKey(ValueKey(fieldKey)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), value);
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
  }

  Future<void> popFrom(WidgetTester tester, Finder finder) async {
    Navigator.of(tester.element(finder)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('rejects invalid Steam paths before changing saved settings', (
    tester,
  ) async {
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('steam-file-settings')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('disable-steam-update-check')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('disable-steam-forced-update')),
      findsOneWidget,
    );
    await editPath(
      tester,
      'steam-path-field',
      p.join(directory.path, 'missing'),
    );
    await press(tester, find.byKey(const ValueKey('save-paths')));
    expect(find.textContaining('包含 steam.exe'), findsAtLeastNWidgets(1));
    expect(services.settings.steamPath, isEmpty);
    expect(services.tasks.tasks, isEmpty);
  });

  testWidgets(
    'saves explicit paths and refreshes only the fixture Steam library',
    (tester) async {
      final steam = Directory(p.join(directory.path, 'Steam'));
      final lua = Directory(p.join(directory.path, 'Lua'));
      await tester.runAsync(() async {
        await steam.create();
        await File(p.join(steam.path, 'steam.exe')).writeAsBytes([]);
        await lua.create();
        await File(p.join(lua.path, '42.lua')).writeAsString('addappid(42)');
      });
      await render(tester);
      await tester.tap(find.byKey(const ValueKey('steam-file-settings')));
      await tester.pumpAndSettle();
      await editPath(tester, 'steam-path-field', steam.path);
      await press(tester, find.byKey(const ValueKey('save-paths')));
      expect(services.settings.steamPath, steam.path);
      expect(find.byKey(const ValueKey('lua-path-field')), findsNothing);
      await tester.runAsync(() async {
        await LuaDirectories(steam.path).save([lua.path]);
        await services.library.scan();
      });
      expect(services.library.games.single.appId, 42);
      expect(services.tasks.tasks.single.status.name, 'succeeded');
    },
  );

  testWidgets(
    'appearance controls persist and language immediately changes labels',
    (tester) async {
      await tester.runAsync(() async {
        await services.settings.set('sidebarExpanded', true);
        await services.settings.set('minimizeToTray', true);
      });
      await render(tester);
      await reveal(tester, find.text('主题'));
      await tester.tap(find.text('主题'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opened.last, isA<ThemeSettingsPage>());
      await popFrom(tester, find.byType(ThemeSettingsPage));
      await tester.tap(find.byKey(const ValueKey('general-settings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final sidebar = tester.widget<ui.CommonSwitch>(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-switch')),
          matching: find.byType(ui.CommonSwitch),
        ),
      );
      expect(sidebar.value, isTrue);
      await tester.runAsync(
        () => services.settings.set('sidebarExpanded', false),
      );
      await tester.pump();
      expect(services.settings.sidebarExpanded, isFalse);
      final tray = tester.widget<ui.CommonSwitch>(
        find.descendant(
          of: find.byKey(const ValueKey('tray-switch')),
          matching: find.byType(ui.CommonSwitch),
        ),
      );
      expect(tray.value, isTrue);
      await tester.runAsync(
        () => services.settings.set('minimizeToTray', false),
      );
      await tester.pump();
      expect(services.settings.minimizeToTray, isFalse);
      await popFrom(tester, find.byKey(const ValueKey('sidebar-switch')));
      await reveal(tester, find.byKey(const ValueKey('language-selector')));
      await tester.runAsync(() => services.settings.set('language', 'en'));
      await tester.pump();
      expect(services.settings.language, 'en');
      expect(find.text('Settings'), findsWidgets);
      final loaded = SettingsStore(services.paths);
      await tester.runAsync(loaded.load);
      expect(loaded.sidebarExpanded, isFalse);
      expect(loaded.minimizeToTray, isFalse);
      expect(loaded.language, 'en');
      loaded.dispose();
    },
  );

  testWidgets('language menu keeps its settings row visible', (tester) async {
    await render(tester);
    await tester.tap(find.byKey(const ValueKey('language-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('显示语言'), findsOneWidget);
    expect(find.text('中文'), findsWidgets);
    expect(find.text('English'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('settings rows omit redundant path and source subtitles', (
    tester,
  ) async {
    final zh = localizationsFor('zh');
    await render(tester);

    expect(find.text(zh.followSystem), findsOneWidget);
    expect(find.text(services.paths.root), findsNothing);
    expect(find.text(zh.heyboxApi), findsNothing);
    expect(find.text(zh.notConfigured), findsNothing);

    await tester.tap(find.byKey(const ValueKey('general-settings')));
    await tester.pumpAndSettle();
    expect(find.text(zh.showDestinationLabelsAlongsideIcons), findsNothing);
    expect(
      find.text(zh.keepBackgroundTasksRunningQuitFromTheTrayMenu),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('data management opens from settings', (tester) async {
    await render(tester);
    final row = find.byKey(const ValueKey('data-management-settings'));
    await reveal(tester, row);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened.last, isA<DataManagementPage>());
    expect(find.text('数据管理'), findsWidgets);
  });

  testWidgets('theme page exposes the FlClash appearance controls', (
    tester,
  ) async {
    await renderTheme(tester);
    expect(find.byKey(const ValueKey('theme-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-mode-dark')), findsOneWidget);
    for (final key in [
      'theme-pure-black',
      'navigation-floating',
      'tab-animation-slide',
      'liquid-glass-ultra',
      'sidebar-blur',
      'font-family',
      'text-scale-mode',
      'text-scale',
    ]) {
      await reveal(tester, find.byKey(ValueKey(key)));
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
  });

  testWidgets('theme editors use FlClash sheets instead of native dialogs', (
    tester,
  ) async {
    await renderTheme(tester);
    await reveal(tester, find.byKey(const ValueKey('theme-color-add')));
    await tester.tap(find.byKey(const ValueKey('theme-color-add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ui.Palette), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    Navigator.of(tester.element(find.byType(ui.Palette))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await reveal(tester, find.byKey(const ValueKey('font-family')));
    await tester.tap(find.byKey(const ValueKey('font-family')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('默认'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'side sheets share a semi-transparent header and collapsed search',
    (tester) async {
      await renderTheme(tester);
      await reveal(tester, find.byKey(const ValueKey('font-family')));
      await tester.tap(find.byKey(const ValueKey('font-family')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final close = find.byKey(const ValueKey('side-sheet-close'));
      expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
      expect(close, findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      final scrim = find.byKey(const ValueKey('side-sheet-header-scrim'));
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(of: scrim, matching: find.byType(DecoratedBox)).first,
      );
      final gradient =
          (decorated.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors.first.a, closeTo(.9, .001));
      expect(gradient.colors.last.a, 0);

      Finder iconButtonWithTooltip(String tooltip) => find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      );
      final searchButton = iconButtonWithTooltip('搜索');
      expect(searchButton, findsOneWidget);
      expect(
        tester.getCenter(close).dx,
        lessThan(tester.getCenter(searchButton).dx),
      );
      await tester.tap(searchButton);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(TextField), findsOneWidget);

      final cancel = iconButtonWithTooltip('取消');
      expect(cancel, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      final sheetBefore = find.byType(ui.SideSheetScaffold);
      final cancelButton = tester.widget<IconButton>(cancel);
      cancelButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
      expect(sheetBefore.evaluate().isNotEmpty, isTrue);
    },
  );

  testWidgets('settings leaves sidebar roots out and shares kernel services', (
    tester,
  ) async {
    await render(tester);
    expect(find.text('内容源'), findsNothing);
    expect(find.text('Steam 账号与提取'), findsNothing);
    await reveal(tester, find.text('OpenSteamTool 内核'));
    await tester.tap(find.text('OpenSteamTool 内核'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final kernel = opened.last as KernelSettingsPage;
    expect(identical(kernel.service, services.kernel), isTrue);
    await popFrom(tester, find.byType(KernelSettingsPage));
    await reveal(tester, find.text('CloudRedirect 云存档插件'));
    await tester.tap(find.text('CloudRedirect 云存档插件'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final cloudPlugin = opened.last as CloudRedirectPluginPage;
    expect(identical(cloudPlugin.service, services.cloud), isTrue);
    await popFrom(tester, find.byType(CloudRedirectPluginPage));
  });

  testWidgets(
    'updates and complete changelog live in About without a source row',
    (tester) async {
      await render(tester);
      await reveal(tester, find.byKey(const ValueKey('about-settings')));
      await tester.tap(find.byKey(const ValueKey('about-settings')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('check-update')));
      expect(find.text(appRepository), findsNothing);
      expect(
        find.byKey(const ValueKey('release-repository-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('save-release-repository')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('check-update')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('view-changelog-history')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('app-changelog')), findsNothing);
      expect(services.settings.releaseRepository, appRepository);
      await tester.tap(find.byKey(const ValueKey('view-changelog-history')));
      await tester.pumpAndSettle();
      expect(find.byType(ChangelogHistorySheet), findsOneWidget);
    },
  );

  testWidgets('update failure stays outside the rounded settings group', (
    tester,
  ) async {
    services.preferences.updateError = const HttpException(
      'Release check failed: HTTP 403',
    );
    await render(tester);
    await reveal(tester, find.byKey(const ValueKey('about-settings')));
    await tester.tap(find.byKey(const ValueKey('about-settings')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('check-update'));
    await reveal(tester, row);
    expect(
      ui.ItemPositionProvider.of(tester.element(row))?.position,
      ui.ItemPosition.start,
    );
    final error = find.textContaining('Release check failed: HTTP 403');
    expect(error, findsOneWidget);
    final card = find.ancestor(of: error, matching: find.byType(ui.CommonCard));
    expect(
      tester.getTopLeft(card).dy - tester.getBottomLeft(row).dy,
      greaterThanOrEqualTo(12),
    );
    expect(tester.widget<ui.CommonCard>(card).inert, isTrue);
  });

  testWidgets('open-source licenses are reachable from About', (tester) async {
    await render(tester);
    await reveal(tester, find.byKey(const ValueKey('about-settings')));
    await reveal(tester, find.byKey(const ValueKey('about-settings')));
    await tester.tap(find.byKey(const ValueKey('about-settings')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('open-licenses'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(ui.AppLicensePage), findsOneWidget);
    expect(find.text('开源许可'), findsOneWidget);
    await popFrom(tester, find.byType(ui.AppLicensePage));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/branding/app.png',
      ),
      findsOneWidget,
    );
    expect(find.text(services.paths.root), findsNothing);
    expect(
      find.text(
        localizationsFor(
          'zh',
        ).uiComponentsAndMotionAreAdaptedFromFlclashFeaturesAreBasedOnFluentSteamLuaAndReimplem,
      ),
      findsNothing,
    );
  });
}
