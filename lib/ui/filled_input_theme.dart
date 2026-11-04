// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'context.dart';
import 'shape.dart';
import 'surface.dart';

class FilledInputTheme extends StatelessWidget {
  const FilledInputTheme({
    super.key,
    this.borderRadius = AppRadius.full,
    this.contentPadding,
    this.fillColor,
    required this.child,
  });

  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? contentPadding;

  /// In place of the raised surface's.
  final Color? fillColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final shape = AppShape.input.copyWith(borderRadius: borderRadius);
    final none = shape.copyWith(borderSide: BorderSide.none);
    return InputDecorationTheme(
      data: InputDecorationTheme.of(context).copyWith(
        filled: true,
        fillColor: fillColor ?? context.raisedSurfaceLevel.colorOf(colorScheme),
        hoverColor: Colors.transparent,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: contentPadding,
        border: none,
        enabledBorder: none,
        disabledBorder: none,
        errorBorder: none,
        focusedBorder: shape.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        focusedErrorBorder: shape.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      child: child,
    );
  }
}
