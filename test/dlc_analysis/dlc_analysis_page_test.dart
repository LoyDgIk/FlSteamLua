import 'package:fl_steam_lua/ui/localization.dart';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_source_registry.dart';
import 'package:fl_steam_lua/features/dlc_analysis/dlc_analysis_page.dart';
import 'package:fl_steam_lua/features/dlc_analysis/dlc_analysis_service.dart';
import 'package:fl_steam_lua/features/key_cache/key_cache_service.dart';
import 'package:fl_steam_lua/features/manifests/manifest_source_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sources extends KeyCacheService {
  _Sources(AppPaths paths, SettingsStore settings)
    : super(paths: paths, settings: settings);

  @override
  List<KeyCacheSubscription> get subscriptions => const [
    KeyCacheSubscription(
      id: 'fixture-source',
      name: 'Fixture source',
      depotKeysUrl: 'https://example.invalid/depots.json',
      tokenKeysUrl: 'https://example.invalid/tokens.json',
    ),
  ];

  @override
  Future<void> load() async {}
}

class _Analysis extends DlcAnalysisService {
  _Analysis(AppPaths paths, SettingsStore settings)
    : super(paths: paths, settings: settings);

  final sourceIds = <String?>[];

  @override
  Future<DlcAnalysisResult> analyze(
    int appId, {
    String? luaPath,
    String? sourceId,
    TaskContext? task,
  }) async {
    sourceIds.add(sourceId);
    return DlcAnalysisResult(
      appId: appId,
      name: 'Fixture',
      mainDepotCount: 0,
      items: const [],
      warnings: const [],
    );
  }
}

void main() {
  testWidgets('content source choice belongs to this analysis only', (
    tester,
  ) async {
    late Directory directory;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('fl-dlc-source-');
    });
    final paths = AppPaths(directory.path);
    final settings = SettingsStore(paths);
    final tasks = TaskCenter();
    final sources = _Sources(paths, settings);
    final manifests = ManifestSourceService(paths: paths, settings: settings);
    final contentSources = ContentSourceRegistry(
      manifests: manifests,
      keyCache: sources,
      settings: settings,
    );
    final service = _Analysis(paths, settings);
    addTearDown(() async {
      service.dispose();
      contentSources.dispose();
      manifests.dispose();
      sources.dispose();
      settings.dispose();
      tasks.dispose();
      await directory.delete(recursive: true);
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: DlcAnalysisPage(
          paths: paths,
          settings: settings,
          tasks: tasks,
          contentSources: contentSources,
          service: service,
          game: const GameEntry(appId: 440, name: 'Fixture'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('dlc-analysis-content-source'));
    expect(find.text('不使用订阅缓存'), findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture source').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dlc-analysis-start')));
    await tester.pumpAndSettle();
    expect(service.sourceIds, ['subscription:fixture-source']);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'starts with game context and validates AppID before network work',
    (tester) async {
      late Directory directory;
      late AppPaths paths;
      late SettingsStore settings;
      late TaskCenter tasks;
      late _Sources sources;
      late ManifestSourceService manifests;
      late ContentSourceRegistry contentSources;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('fl-dlc-page-');
        paths = AppPaths(directory.path);
        settings = SettingsStore(paths);
        tasks = TaskCenter();
        sources = _Sources(paths, settings);
        manifests = ManifestSourceService(paths: paths, settings: settings);
        contentSources = ContentSourceRegistry(
          manifests: manifests,
          keyCache: sources,
          settings: settings,
        );
      });
      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: DlcAnalysisPage(
              paths: paths,
              settings: settings,
              tasks: tasks,
              contentSources: contentSources,
              game: const GameEntry(
                appId: 440,
                name: 'TF2',
                luaPath: r'C:\fixture\440.lua',
              ),
            ),
          ),
        );
        expect(find.text('DLC 管理'), findsWidgets);
        expect(find.text('440'), findsOneWidget);
        expect(find.text(r'C:\fixture\440.lua'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('dlc-analysis-app-id')),
            matching: find.byType(TextFormField),
          ),
          '0',
        );
        await tester.tap(find.byKey(const ValueKey('dlc-analysis-start')));
        await tester.pump();
        expect(tasks.tasks, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          contentSources.dispose();
          manifests.dispose();
          sources.dispose();
          settings.dispose();
          tasks.dispose();
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
