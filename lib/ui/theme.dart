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

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  Color seedColor = const Color(0xff007aff),
  ColorStyle colorStyle = ColorStyle.vivid,
  bool pureBlack = false,
  String? fontFamily,
}) {
  final colors = seededColorScheme(
    seedColor: seedColor,
    brightness: brightness,
    style: colorStyle,
  ).toPureBlack(pureBlack);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    fontFamily: fontFamily,
    fontFamilyFallback: appFontFamilyFallback(
      platform: defaultTargetPlatform,
      locales: [
        const Locale('zh'),
        ...WidgetsBinding.instance.platformDispatcher.locales,
      ],
    ),
    extensions: [
      if (brightness == Brightness.dark) ElevatedColorScheme(colors.elevated),
    ],
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
  ).withAppShapes.withAppSurfaces.withAppTypography;
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
