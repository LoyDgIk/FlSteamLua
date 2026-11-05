// FlClash theme composition at 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Provider inputs replaced by parameters. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'color.dart';
import 'font.dart';
import 'metrics.dart';
import 'shape.dart';
import 'surface.dart';
import 'typography.dart';

// Same input cache as FlClash manager/theme_manager.dart. Theme composition
// contains state properties that make freshly built ThemeData unequal, so an
// unrelated settings notification would otherwise trigger ThemeCrossFade.
final _appThemes = <Brightness, ({Object inputs, ThemeData theme})>{};

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  Color seedColor = const Color(0xff007aff),
  ColorStyle colorStyle = ColorStyle.vivid,
  bool pureBlack = false,
  String? fontFamily,
}) {
  final locales = [
    const Locale('zh'),
    ...WidgetsBinding.instance.platformDispatcher.locales,
  ];
  final inputs = (
    seedColor,
    colorStyle,
    pureBlack,
    fontFamily,
    defaultTargetPlatform,
    locales.join(','),
  );
  final cached = _appThemes[brightness];
  if (cached != null && cached.inputs == inputs) return cached.theme;
  final colors = seededColorScheme(
    seedColor: seedColor,
    brightness: brightness,
    style: colorStyle,
  ).toPureBlack(pureBlack);
  final theme = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    fontFamily: fontFamily,
    fontFamilyFallback: appFontFamilyFallback(
      platform: defaultTargetPlatform,
      locales: locales,
    ),
    extensions: [
      if (brightness == Brightness.dark) ElevatedColorScheme(colors.elevated),
    ],
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
  ).withAppShapes.withAppSurfaces.withAppTypography;
  _appThemes[brightness] = (inputs: inputs, theme: theme);
  return theme;
}

class CommonMinFilledButtonTheme extends StatelessWidget {
  const CommonMinFilledButtonTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FilledButtonTheme(
    data: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ).merge(FilledButtonTheme.of(context).style),
    ),
    child: child,
  );
}

class CommonMinIconButtonTheme extends StatelessWidget {
  const CommonMinIconButtonTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => IconButtonTheme(
    data: IconButtonThemeData(
      style: IconButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        iconSize: 20.ap(context),
      ).merge(IconButtonTheme.of(context).style),
    ),
    child: child,
  );
}
