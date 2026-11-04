// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'color.dart';
import 'context.dart';
import 'dialog.dart';
import 'shape.dart';
import 'surface.dart';

const double _width = 440;
const double _maxHeight = 720;
const double _margin = 40;

/// A form in a card centered over the navigator, moving as a dialog does.
class FormSheetRoute<T> extends PopupRoute<T>
    with AlertMotionRouteMixin<T>, AlertHostRoute<T> {
  FormSheetRoute({
    required this.builder,
    required this.barrierColor,
    required this.barrierLabel,
    this.backgroundColor,
  });

  final WidgetBuilder builder;
  final Color? backgroundColor;

  @override
  final Color barrierColor;

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ElevatedSurfaceTheme(
      child: _FormSheet(backgroundColor: backgroundColor, builder: builder),
    );
  }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.backgroundColor, required this.builder});

  final Color? backgroundColor;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(
            _margin,
          ).copyWith(bottom: _margin + keyboard),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _width,
                maxHeight: _maxHeight,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color:
                      backgroundColor ??
                      SurfaceLevel.page.colorOf(theme.colorScheme),
                  shape: AppShape.xxl,
                  clipBehavior: Clip.antiAlias,
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: SurfaceScope(
                      level: SurfaceLevel.page,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showFormSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
}) {
  return Navigator.of(context).push<T>(
    FormSheetRoute<T>(
      builder: builder,
      backgroundColor: backgroundColor,
      barrierColor: context.colorScheme.modalScrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}
