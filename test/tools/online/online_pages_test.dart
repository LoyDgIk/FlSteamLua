import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/tools/online/online_pages.dart';
import 'package:fl_steam_lua/features/tools/online/online_services.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:fl_steam_lua/ui/card.dart';
import 'package:fl_steam_lua/ui/form_page.dart';
import 'package:fl_steam_lua/ui/page_progress.dart';
import 'package:fl_steam_lua/ui/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _PageTrainerService extends TrainerService {
  _PageTrainerService({
    required super.paths,
    required super.settings,
    required super.client,
  });

  List<DownloadedTrainer> localDownloads = [];
  final catalogueLoaded = Completer<void>();

  @override
  Future<void> loadBindings() async {}

  @override
  Future<List<DownloadedTrainer>> downloaded() async => localDownloads;

  Future<void> readLocalDownloads() async {
    localDownloads = await super.downloaded();
  }

  @override
  Future<List<TrainerEntry>> recent({int count = 20}) async {
    final entries = await super.recent(count: count);
    catalogueLoaded.complete();
    return entries;
  }
}

void main() {
  late Directory temp;
  late AppPaths paths;
  late SettingsStore settings;
  late TaskCenter tasks;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsl-online-page-');
    paths = AppPaths(temp.path);
    await paths.initialize();
    settings = SettingsStore(paths);
    tasks = TaskCenter();
  });
  tearDown(() async {
    tasks.dispose();
    settings.dispose();
    await temp.delete(recursive: true);
  });
  Widget app(Widget page) => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: page,
  );
  void largeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'trainer starts with a real catalogue and keeps downloaded management reachable',
    (tester) async {
      largeView(tester);
      final requests = <Uri>[];
      final service = _PageTrainerService(
        paths: paths,
        settings: settings,
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/trainer/fixture/') {
            return http.Response(
              '<h1>Fixture Trainer</h1><div class="entry-content">'
              'A long trainer description with supported game versions and notes.'
              '</div><a class="attachment-link" href="/files/fixture.zip">'
              'Download</a><time datetime="2026-11-03"></time>',
              200,
            );
          }
          return http.Response(
            '<article class="post-standard"><h2 class="post-title">'
            '<a href="/trainer/fixture/">Fixture Trainer</a></h2></article>',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final file = File(paths.file('downloads/trainers/Local Trainer.exe'));
      await tester.runAsync(() async {
        await file.parent.create(recursive: true);
        await file.writeAsBytes([1]);
        await service.readLocalDownloads();
      });
      await tester.pumpWidget(
        app(
          TrainerToolsPage(
            appPaths: paths,
            settings: settings,
            tasks: tasks,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        service.catalogueLoaded.isCompleted,
        isTrue,
        reason:
            'The real catalogue request and parser must finish before checking the browse UI.',
      );
      expect(requests.any((uri) => uri.host == 'flingtrainer.com'), isTrue);
      expect(find.text('Fixture'), findsOneWidget);
      expect(find.byType(CommonCard), findsWidgets);
      final grid = tester.widget<GridView>(find.byType(GridView));
      final gridDelegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(gridDelegate.crossAxisCount, 3);
      expect(gridDelegate.mainAxisExtent, 220);
      expect(
        find.byKey(const ValueKey('trainer-source-recent')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('trainer-count')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(
          const ValueKey('trainer-https://flingtrainer.com/trainer/fixture/'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpandableTextCard), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('side-sheet-close')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(700, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('My trainers'));
      await tester.pumpAndSettle();
      expect(find.text('Local'), findsOneWidget);
      expect(find.byTooltip('Manage trainer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Game bindings'));
      await tester.pumpAndSettle();
      expect(find.text('Add binding'), findsOneWidget);
      await tester.tap(find.text('Add binding'));
      await tester.pumpAndSettle();
      expect(find.byType(FormPage), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('online fix detail uses a side sheet with navigable directories', (
    tester,
  ) async {
    largeView(tester);
    final service = OnlineFixService(
      paths: paths,
      requestGap: Duration.zero,
      client: MockClient((request) async {
        if (request.url.path == '/index.php') {
          return http.Response(
            '<div class="news-search"><div><a class="big-link" href="/fixture.html"></a>'
            '<h2 class="title">Fixture</h2></div></div>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        if (request.url.path == '/fixture.html') {
          return http.Response(
            '<h1 id="news-title">Fixture</h1><div class="lightedited">'
            'Updated: 15 August 2026, 12:35. The patch follows version 1.29.163709 '
            'and includes a long explanation that must wrap without moving the row label.'
            '</div><div class="quote"><a href="https://online-fix.me:2053/uploads/Fixture/">Files</a></div>'
            '<div itemprop="articleBody">Fixture instructions</div>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response(
          '<pre><a href="nested/">nested/</a></pre>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      app(
        OnlineFixToolsPage(
          appPaths: paths,
          settings: settings,
          tasks: tasks,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('-onlinefix'), findsOneWidget);
    await tester.tap(find.text('Online fixes'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('online-fix-feed-recent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('online-fix-feed-popular')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('toolbar-search-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fixture');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final resultTitle = find.byKey(
      const ValueKey('online-fix-title-https://online-fix.me/fixture.html'),
    );
    expect(resultTitle, findsOneWidget);
    await tester.tap(resultTitle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('side-sheet-close')), findsOneWidget);
    expect(find.byType(ExpandableTextCard), findsOneWidget);
    expect(find.text('nested'), findsOneWidget);
    await tester.tap(find.text('nested'));
    await tester.pumpAndSettle();
    expect(find.text('Parent folder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('side-sheet-close')));
    await tester.pumpAndSettle();
    expect(resultTitle, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('online fix feed appends the next page on scroll fill', (
    tester,
  ) async {
    largeView(tester);
    String articles(int count, String prefix) => List.generate(
      count,
      (index) =>
          '<article class="news"><div class="article">'
          '<a class="big-link" href="/games/$prefix-$index.html"></a>'
          '<h2 class="title">$prefix $index</h2>'
          '<time datetime="2026-11-03"></time></div></article>',
    ).join();
    final service = OnlineFixService(
      paths: paths,
      requestGap: Duration.zero,
      client: MockClient((request) async {
        if (request.url.path == '/page/2/') {
          return http.Response(
            '${articles(20, 'Second page')}'
            '<nav class="pagination"><a href="/page/9/">9</a></nav>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return http.Response(
          '${articles(1, 'First page')}'
          '<nav class="pagination"><a href="/page/2/">2</a></nav>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      app(
        OnlineFixToolsPage(
          appPaths: paths,
          settings: settings,
          tasks: tasks,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online fixes'));
    await tester.pumpAndSettle();

    expect(find.text('First page 0'), findsOneWidget);
    expect(find.text('Second page 0'), findsOneWidget);
    expect(find.byType(PageProgressCapsule), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
