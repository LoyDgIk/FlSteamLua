// FlClash-style inline status notice. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'context.dart';
import 'feedback.dart';
import 'icons/icons.dart';
import 'shape.dart';
import 'typography.dart';

class CommonNotice extends StatelessWidget {
  const CommonNotice({
    super.key,
    required this.message,
    this.level = MessageLevel.error,
  });

  final String message;
  final MessageLevel level;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (background, foreground, glyph) = switch (level) {
      MessageLevel.info => (
        colorScheme.surfaceContainerHigh,
        colorScheme.onSurface,
        AppGlyphs.info,
      ),
      MessageLevel.success => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        AppGlyphs.checkCircle,
      ),
      MessageLevel.warning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        AppGlyphs.warning,
      ),
      MessageLevel.error => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        AppGlyphs.error,
      ),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: background, shape: AppShape.md),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlyphIcon(glyph, size: 20, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
