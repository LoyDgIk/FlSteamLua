import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

Locale resolveAppLocale(String language) {
  final tag = language.replaceAll('_', '-').toLowerCase();
  final locales = AppLocalizations.supportedLocales;
  for (final locale in locales) {
    if (locale.toLanguageTag().toLowerCase() == tag) return locale;
  }
  final languageCode = tag.split('-').first;
  for (final locale in locales) {
    if (locale.languageCode.toLowerCase() == languageCode) return locale;
  }
  return locales.firstWhere(
    (locale) => locale.languageCode == 'zh',
    orElse: () => locales.first,
  );
}

AppLocalizations localizationsFor(String language) =>
    lookupAppLocalizations(resolveAppLocale(language));

String steamLanguageFor(String language) {
  final tag = language.replaceAll('_', '-').toLowerCase();
  if (tag == 'zh-tw' || tag == 'zh-hk' || tag.startsWith('zh-hant')) {
    return 'tchinese';
  }
  if (tag == 'pt-br') return 'brazilian';
  if (tag == 'es-419') return 'latam';
  return switch (tag.split('-').first) {
    'ar' => 'arabic',
    'bg' => 'bulgarian',
    'cs' => 'czech',
    'da' => 'danish',
    'de' => 'german',
    'el' => 'greek',
    'en' => 'english',
    'es' => 'spanish',
    'fi' => 'finnish',
    'fr' => 'french',
    'hu' => 'hungarian',
    'id' => 'indonesian',
    'it' => 'italian',
    'ja' => 'japanese',
    'ko' => 'koreana',
    'nl' => 'dutch',
    'no' => 'norwegian',
    'pl' => 'polish',
    'pt' => 'portuguese',
    'ro' => 'romanian',
    'ru' => 'russian',
    'sv' => 'swedish',
    'th' => 'thai',
    'tr' => 'turkish',
    'uk' => 'ukrainian',
    'vi' => 'vietnamese',
    'zh' => 'schinese',
    _ => 'english',
  };
}
