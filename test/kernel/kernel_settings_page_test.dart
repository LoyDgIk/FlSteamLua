import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_models.dart';
import 'package:fl_steam_lua/features/kernel/kernel_manifest_settings_page.dart';
import 'package:fl_steam_lua/features/kernel/kernel_service.dart';
import 'package:fl_steam_lua/features/kernel/kernel_settings_page.dart';
import 'package:fl_steam_lua/features/kernel/kernel_toml_channel_page.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory steam;
  late SettingsStore settings;
  late KernelService service;
  late TaskCenter tasks;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kernel-page-');
    steam = await Directory(p.join(temp.path, 'Steam')).create();
    await File(p.join(steam.path, 'steam.exe')).writeAsString('fixture');
    final paths = AppPaths(p.join(temp.path, 'app'));
    await paths.initialize();
    settings = SettingsStore(paths);
    await settings.set('steamPath', steam.path);
    service = KernelService(
      paths: paths,
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    tasks = TaskCenter();
  });

  tearDown(() async {
    service.dispose();
    settings.dispose();
    tasks.dispose();
    await temp.delete(recursive: true);
  });

  testWidgets(
    'checking updates preserves scrolled row geometry while showing progress',
    (tester) async {
      final response = Completer<http.Response>();
      service.dispose();
      service = KernelService(
        paths: AppPaths(p.join(temp.path, 'app')),
        settings: settings,
        isSteamRunning: () async => false,
        client: MockClient(
          (request) async => request.url.path.endsWith('/releases')
              ? response.future
              : http.Response('{"default_branch":"main","fork":true}', 200),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1100, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(),
          home: KernelSettingsPage(
            service: service,
            tasks: tasks,
            settings: settings,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final action = find.text('Install, update or repair kernel');
      await tester.scrollUntilVisible(
        action,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.pixels - 160);
      await tester.pumpAndSettle();
      final before = tester.getRect(action);
      final offset = scroll.pixels;
      await tester.runAsync(() async {
        await tester.tap(action);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (final elapsed in [0, 16, 50, 100, 200]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(find.byType(ui.CommonProgressBar), findsOneWidget);
        expect(
          tester.getRect(action),
          before,
          reason: 'Loading frame $elapsed moved the row',
        );
        expect(scroll.pixels, offset);
      }
      await tester.runAsync(() async {
        response.complete(http.Response('Forbidden', 403));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (var attempt = 0; attempt < 30 && tasks.runningCount > 0; attempt++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ui.CommonProgressBar), findsNothing);
      expect(tester.getRect(action), before);
      expect(scroll.pixels, offset);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('kernel page uses grouped rows and opens residual side sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(
      () => File(p.join(steam.path, 'midimap.dll')).writeAsString('residual'),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: KernelSettingsPage(
          service: service,
          tasks: tasks,
          settings: settings,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Kernel overview'), findsOneWidget);
    expect(find.text('Install and runtime'), findsOneWidget);
    expect(find.text('Repository subscription'), findsOneWidget);
    expect(find.text('Local kernel package'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(ui.CommonSelectField), findsNothing);
    final overviewTop = tester.getTopLeft(find.text('Kernel overview')).dy;
    final sourceSwitchTop = tester
        .getTopLeft(find.byType(ui.SegmentedControl<KernelSourceMode>))
        .dy;
    final repositoryTop = tester.getTopLeft(find.text('Kernel repository')).dy;
    expect(overviewTop, lessThan(sourceSwitchTop));
    expect(sourceSwitchTop, lessThan(repositoryTop));

    final scan = find.text('Scan kernel residuals');
    await tester.scrollUntilVisible(
      scan,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Manifest request codes'), findsOneWidget);
    expect(find.text('Built-in provider · 20770407'), findsOneWidget);
    expect(find.text('huanyuejue/steam-monitor · main'), findsOneWidget);
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
    expect(find.text('Kernel residuals'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recovery backups move to a side sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: KernelSettingsPage(
          service: service,
          tasks: tasks,
          settings: settings,
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final backups = find.text('Switch and recovery backups');
    await tester.scrollUntilVisible(
      backups,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(backups);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
    expect(find.text('Switch and recovery backups'), findsWidgets);
    expect(
      find.text(
        'A recoverable snapshot is saved before switching or uninstalling.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('data channel uses presets and a custom repository field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: KernelTomlChannelPage(service: service),
      ),
    );
    await tester.pumpAndSettle();

    final repository = find.text('huanyuejue/steam-monitor · Default');
    expect(repository, findsOneWidget);
    await tester.tap(repository);
    await tester.pump();
    await tester.tap(find.text('Custom repository').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ui.FormRowTextField), findsNWidgets(2));

    await tester.tap(find.text('Local emergency build'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
    expect(find.text('Local emergency build'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('available packages open in a side sheet with release notes', (
    tester,
  ) async {
    service.dispose();
    service = KernelService(
      paths: AppPaths(p.join(temp.path, 'app')),
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((request) async {
        if (request.url.path == '/repos/huanyuejue/OpenSteamTool') {
          return http.Response(
            '{"full_name":"huanyuejue/OpenSteamTool","fork":true,'
            '"parent":{"full_name":"OpenSteam001/OpenSteamTool"},'
            '"default_branch":"main","archived":false,'
            '"pushed_at":"2026-11-02T00:00:00Z"}',
            200,
          );
        }
        return http.Response(
          '[{"tag_name":"v2.0.0","draft":false,'
          '"body":"Important update announcement",'
          '"published_at":"2026-11-01T00:00:00Z","assets":['
          '{"name":"OpenSteamTool-v2.0.0-Release.zip","size":123,'
          '"browser_download_url":"https://github.com/huanyuejue/OpenSteamTool/releases/download/v2.0.0/OpenSteamTool-v2.0.0-Release.zip"}'
          ']}]',
          200,
        );
      }),
    );
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: KernelSettingsPage(
          service: service,
          tasks: tasks,
          settings: settings,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Available packages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Available packages'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    for (
      var attempt = 0;
      service.packages.isEmpty && attempt < 100;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
    expect(service.packages, isNotEmpty, reason: service.warnings.join(' | '));
    expect(find.text('v2.0.0'), findsOneWidget);
    await tester.tap(find.text('v2.0.0'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Release notes'), findsOneWidget);
    expect(
      find.textContaining('Important update announcement'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('local manifest proxy selects existing content sources', (
    tester,
  ) async {
    service.dispose();
    service = KernelService(
      paths: AppPaths(p.join(temp.path, 'app')),
      settings: settings,
      isSteamRunning: () async => false,
      manifestCodeSources: () => const [
        ContentSourceDefinition(
          id: 'script:request-codes',
          name: 'Request codes',
          kind: ContentSourceKind.script,
          capabilities: {ContentCapability.manifestRequestCodes},
        ),
      ],
      resolveManifestRequestCode:
          ({
            required sourceId,
            required appId,
            required depotId,
            required gid,
          }) async => '123456789',
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: KernelManifestSettingsPage(service: service),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Local proxy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Manifest URL template'), findsNothing);
    expect(
      find.byKey(const ValueKey('manifest-code-source-script:request-codes')),
      findsOneWidget,
    );

    await tester.tap(find.text('Request codes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final save = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Save'),
        matching: find.byType(IconButton),
      ),
    );
    await tester.runAsync(() async {
      save.onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(settings.get<List<dynamic>>('kernelManifestSourceIds', const []), [
      'script:request-codes',
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('source mode switches animate without refetching repositories', (
    tester,
  ) async {
    service.dispose();
    var requests = 0;
    service = KernelService(
      paths: AppPaths(p.join(temp.path, 'app')),
      settings: settings,
      isSteamRunning: () async => false,
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(),
        home: KernelSettingsPage(
          service: service,
          tasks: tasks,
          settings: settings,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, 0);

    final localSegment = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Local kernel package'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.runAsync(() async {
      localSegment.onTap!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, 0);
    expect(service.sourceMode, KernelSourceMode.local);
    expect(find.byType(ui.FadeBox), findsOneWidget);
    expect(find.byType(AnimatedSize), findsWidgets);

    final repositorySegment = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Repository subscription'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.runAsync(() async {
      repositorySegment.onTap!();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, 0);
    expect(service.sourceMode, KernelSourceMode.repository);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
