import 'package:fl_steam_lua/features/store/store_page.dart';
import 'package:fl_steam_lua/features/store/store_service.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:fl_steam_lua/ui/form_page.dart';
import 'package:fl_steam_lua/ui/page_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PagedStoreService extends StoreService {
  final offsets = <int>[];
  bool failNextMore = false;

  @override
  Future<StorePageResult> search(
    String query, {
    StoreCategory category = StoreCategory.popular,
    int offset = 0,
    int count = 25,
    Future<void>? cancelled,
  }) async {
    offsets.add(offset);
    if (offset == 0) {
      return const StorePageResult(
        items: [StoreGame(appId: 1, name: 'First game', headerImage: '')],
        totalCount: 60,
        nextOffset: 25,
        hasMore: true,
      );
    }
    if (failNextMore) {
      failNextMore = false;
      throw const StoreException('Steam request timed out');
    }
    return StorePageResult(
      items: [
        for (var index = 0; index < 25; index++)
          StoreGame(
            appId: 100 + index,
            name: 'Second page $index',
            headerImage: '',
          ),
      ],
      totalCount: 60,
      nextOffset: 50,
      hasMore: true,
    );
  }
}

void main() {
  testWidgets('store appends pages automatically and exposes page jump', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _PagedStoreService();
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: StorePage(service: service, onOpenGame: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.offsets, [0, 25]);
    expect(find.text('First game'), findsOneWidget);
    expect(find.text('Second page 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('store-region-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('store-adult-content')), findsOneWidget);
    expect(find.byType(PageProgressCapsule), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byType(PageProgressCapsule));
    await tester.pumpAndSettle();
    expect(find.byType(FormPage), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed store page can be retried from the banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _PagedStoreService()..failNextMore = true;
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: StorePage(service: service, onOpenGame: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.offsets, [0, 25]);
    expect(find.text('Steam request timed out'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.offsets, [0, 25, 25]);
    expect(find.text('Second page 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
