// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'context.dart';
import 'inherited.dart';
import 'liquid_glass.dart';
import 'shape.dart';
import 'surface.dart';

class FloatingFootBar extends StatelessWidget {
  const FloatingFootBar({super.key, required this.bar, required this.body});

  static const _margin = BottomInsetScope.dockedSearchMargin;

  final Widget bar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final level = SurfaceLevel.floatingOf(colorScheme);
    final content = SurfaceScope(
      level: level,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: BottomInsetScope.dockedSearchHeight,
        ),
        child: bar,
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        BottomInsetScope(
          inset:
              BottomInsetScope.of(context) + BottomInsetScope.dockedSearchInset,
          child: body,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _margin,
              0,
              _margin,
              _margin + context.bottomInset,
            ),
            child: LiquidGlassScope.of(context)
                ? LiquidGlass(
                    style: LiquidGlassStyle.pill(colorScheme),
                    child: content,
                  )
                : DecoratedBox(
                    decoration: ShapeDecoration(
                      color: level.colorOf(colorScheme),
                      shape: AppShape.full,
                      shadows: _dockShadows(colorScheme),
                    ),
                    child: content,
                  ),
          ),
        ),
      ],
    );
  }
}

List<BoxShadow> _dockShadows(ColorScheme colorScheme) {
  final strength = colorScheme.brightness == Brightness.dark ? 3.0 : 1.0;
  return [
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: .08 * strength),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: .04 * strength),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}
