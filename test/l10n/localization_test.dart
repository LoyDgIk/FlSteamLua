import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/ui/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all generated languages have complete ARB messages and placeholders',
    () {
      final directory = Directory('lib/l10n');
      final template =
          jsonDecode(File('${directory.path}/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final messageKeys = template.keys
          .where((key) => !key.startsWith('@'))
          .toSet();
      for (final locale in AppLocalizations.supportedLocales) {
        final tag = locale.toString();
        final resource =
            jsonDecode(
                  File('${directory.path}/app_$tag.arb').readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(
          resource.keys.where((key) => !key.startsWith('@')).toSet(),
          messageKeys,
          reason: '$tag must translate every application message',
        );
        expect(lookupAppLocalizations(locale).languageName, isNotEmpty);
        for (final key in messageKeys) {
          final placeholders = RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}')
              .allMatches(template[key] as String)
              .map((match) => match.group(1))
              .toSet();
          expect(
            RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}')
                .allMatches(resource[key] as String)
                .map((match) => match.group(1))
                .toSet(),
            placeholders,
            reason: '$tag.$key must retain its typed parameters',
          );
        }
      }
    },
  );

  test('generated messages preserve parameter order across translations', () {
    final en = localizationsFor('en');
    final zh = localizationsFor('zh');
    expect(en.completedSkippedFailed('3', '2', '1'), contains('3'));
    expect(zh.completedSkippedFailed('3', '2', '1'), contains('3'));
    expect(
      en.manifestPinsSaveToApply('7', 'enabled'),
      '7 manifest pins enabled. Save to apply.',
    );
    expect(zh.manifestPinsSaveToApply('7', '启用'), '已启用 7 行版本固定，保存后生效。');
    expect(en.couldNotLoadAchievements, 'Could not load achievements');
    expect(zh.couldNotLoadAchievements, '未能读取成就');
  });

  test(
    'locale resolution uses generated languages and normalizes region tags',
    () {
      expect(resolveAppLocale('en_US'), const Locale('en'));
      expect(resolveAppLocale('zh-CN'), const Locale('zh'));
      expect(
        AppLocalizations.supportedLocales,
        contains(resolveAppLocale('unsupported')),
      );
      for (final locale in AppLocalizations.supportedLocales) {
        expect(resolveAppLocale(locale.toLanguageTag()), locale);
      }
    },
  );

  test(
    'Steam API language names are independent from translated UI resources',
    () {
      expect(steamLanguageFor('en-US'), 'english');
      expect(steamLanguageFor('zh-CN'), 'schinese');
      expect(steamLanguageFor('zh-Hant-TW'), 'tchinese');
      expect(steamLanguageFor('fr'), 'french');
      expect(steamLanguageFor('de'), 'german');
      expect(steamLanguageFor('pt_BR'), 'brazilian');
      expect(steamLanguageFor('es-419'), 'latam');
      expect(steamLanguageFor('unknown'), 'english');
    },
  );

  testWidgets(
    'changing MaterialApp locale rebuilds typed application messages',
    (tester) async {
      final selected = ValueNotifier(const Locale('zh'));
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: selected,
          builder: (context, locale, child) => MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) =>
                  Scaffold(body: Text(context.l10n.couldNotLoadAchievements)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('未能读取成就'), findsOneWidget);
      selected.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Could not load achievements'), findsOneWidget);
      expect(find.text('未能读取成就'), findsNothing);
    },
  );
}
