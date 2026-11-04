import 'package:fl_steam_lua/features/store/store_screenshot.dart';
import 'package:fl_steam_lua/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('store screenshot reserves space while loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 190,
              child: StoreScreenshot(
                url: 'https://example.invalid/screenshot.jpg',
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find
              .byKey(const ValueKey('store-screenshot-loading'))
              .evaluate()
              .isNotEmpty ||
          find
              .byKey(const ValueKey('store-screenshot-error'))
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
