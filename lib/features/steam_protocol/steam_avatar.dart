import 'dart:io';

import 'package:flutter/material.dart';

import '../../ui/icons/icons.dart';

class SteamAvatar extends StatelessWidget {
  const SteamAvatar({super.key, required this.path, this.size = 32});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? _fallback(context)
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: GlyphIcon(
        AppGlyphs.account,
        size: size * .58,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
