import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const destinations = [
  SidebarDestination(icon: Icons.dashboard_outlined, label: '面板主页'),
  SidebarDestination(icon: Icons.library_books_outlined, label: '库'),
  SidebarDestination(icon: Icons.store_outlined, label: '商店'),
  SidebarDestination(icon: Icons.emoji_events_outlined, label: '成就'),
  SidebarDestination(icon: Icons.cloud_outlined, label: '云存档'),
];

void main() {
  testWidgets('sidebar exposes five destinations and returns selection', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Row(
            children: [
              NavigationSidebar(
                destinations: destinations,
                selectedIndex: selected,
                onSelected: (index) => selected = index,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(NavigationSidebar)).width, 220);
    for (final destination in destinations) {
      expect(find.text(destination.label), findsOneWidget);
    }
    await tester.tap(find.text('云存档'));
    expect(selected, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed sidebar is 48 pixels without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Row(
            children: [
              NavigationSidebar(
                destinations: destinations,
                selectedIndex: 2,
                expanded: false,
                onSelected: (_) {},
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(NavigationSidebar)).width, 48);
    expect(tester.takeException(), isNull);
  });

  test(
    'detail route retains the expected timing and reduced-motion override',
    () {
      final route = buildAppPageRoute<void>(builder: (_) => const SizedBox());
      final reduced = buildAppPageRoute<void>(
        builder: (_) => const SizedBox(),
        reduceMotion: true,
      );
      expect(
        (route as PageRoute).transitionDuration,
        const Duration(milliseconds: 450),
      );
      expect((reduced as PageRoute).transitionDuration, Duration.zero);
    },
  );

  testWidgets('reduced motion opens a container without animated route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: OpenContainer(
            reduceMotion: true,
            closedBuilder: (_, open) =>
                TextButton(onPressed: open, child: const Text('打开游戏')),
            openBuilder: (_) => const Scaffold(body: Text('游戏详情')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开游戏'));
    await tester.pumpAndSettle();
    expect(find.text('游戏详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system reduced motion is observed by UI helpers', (
    tester,
  ) async {
    late bool reduced;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = reduceMotionOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(reduced, isTrue);
  });

  testWidgets(
    'theme frame wrapper supports an immediate reduced-motion change',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildAppTheme(brightness: brightness),
            themeAnimationDuration: Duration.zero,
            home: const ThemeCrossFade(
              reduceMotion: true,
              child: Scaffold(body: Text('主题')),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('主题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('theme cross-fade renders a normal light-to-dark change', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildAppTheme(brightness: brightness),
          themeAnimationDuration: Duration.zero,
          home: const ThemeCrossFade(child: Scaffold(body: Text('主题内容'))),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('主题内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
