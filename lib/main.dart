import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_services.dart';
import 'app/app_shell.dart';
import 'app/quick_start_page.dart';
import 'core/app_paths.dart';
import 'core/system_appearance.dart';
import 'platform/desktop/desktop_integration.dart';
import 'ui/localization.dart';
import 'ui/ui.dart' as ui;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.registerAppLicenses();
  final services = AppServices(AppPaths.platform());
  await services.initialize();
  if (Platform.isWindows) {
    final desktop = DesktopIntegration(
      settings: services.settings,
      onExitRequested: services.shutdown,
      onRestartSteam: services.library.processActions.restart,
      onError: (error) => services.startupErrors.add('Desktop: $error'),
    );
    await desktop.initialize();
  }
  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const FlSteamLuaApp(),
    ),
  );
}

class FlSteamLuaApp extends ConsumerWidget {
  const FlSteamLuaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    return ListenableBuilder(
      listenable: services.settings,
      builder: (context, _) {
        final settings = services.settings;
        final colorStyle = switch (settings.colorStyle) {
          'tinted' => ui.ColorStyle.tinted,
          'soft' => ui.ColorStyle.soft,
          'monochrome' => ui.ColorStyle.monochrome,
          _ => ui.ColorStyle.vivid,
        };
        final seed = Color(
          settings.themeFollowSystem ? systemAccentColor() : settings.themeSeed,
        );
        return MaterialApp(
          title: 'FlSteamLua',
          debugShowCheckedModeBanner: false,
          themeAnimationStyle: AnimationStyle.noAnimation,
          theme: ui.buildAppTheme(
            seedColor: seed,
            colorStyle: colorStyle,
            fontFamily: settings.fontFamily,
          ),
          darkTheme: ui.buildAppTheme(
            brightness: Brightness.dark,
            seedColor: seed,
            colorStyle: colorStyle,
            pureBlack: settings.pureBlack,
            fontFamily: settings.fontFamily,
          ),
          themeMode: switch (settings.theme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          locale: resolveAppLocale(settings.language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          scrollBehavior: const ui.BaseScrollBehavior(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: settings.textScaleEnabled
                  ? media.copyWith(
                      textScaler: TextScaler.linear(settings.textScale),
                    )
                  : media,
              child: ui.LiquidGlassScope(
                enabled: settings.liquidGlass != 'none',
                quality: settings.liquidGlass == 'standard'
                    ? ui.LiquidGlassQuality.standard
                    : ui.LiquidGlassQuality.ultra,
                child: ui.LiquidGlassHost(
                  enabled: settings.liquidGlass != 'none',
                  child: ui.StatusManager(
                    key: ui.appFeedbackKey,
                    topOffset: ui.windowHeaderHeight + ui.pageToolbarHeight,
                    child: ui.ThemeCrossFade(
                      reduceMotion: MediaQuery.disableAnimationsOf(context),
                      child: child!,
                    ),
                  ),
                ),
              ),
            );
          },
          home: settings.quickStartDismissed
              ? AppShell(services: services)
              : QuickStartWindow(services: services),
        );
      },
    );
  }
}
