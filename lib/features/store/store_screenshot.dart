import 'package:flutter/material.dart';

import '../../ui/ui.dart' as ui;

const _steamImageHeaders = {
  'User-Agent': 'Mozilla/5.0',
  'Referer': 'https://store.steampowered.com/',
};

class StoreScreenshot extends StatelessWidget {
  const StoreScreenshot({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ui.AppImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      headers: _steamImageHeaders,
      borderRadius: BorderRadius.circular(16),
      placeholder: const _ScreenshotPlaceholder(),
      errorBuilder: (_, _, _) => const _ScreenshotPlaceholder(error: true),
      onTap: onTap,
    );
  }
}

class StoreScreenshotPreview extends StatelessWidget {
  const StoreScreenshotPreview({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return ui.AppImagePreview(
      sheetKey: const ValueKey('store-screenshot-preview'),
      urls: urls,
      initialIndex: initialIndex,
      headers: _steamImageHeaders,
    );
  }
}

Future<void> showStoreScreenshotPreview(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  return ui.showModalSideSheet<void>(
    context: context,
    builder: (_) =>
        StoreScreenshotPreview(urls: urls, initialIndex: initialIndex),
  );
}

class _ScreenshotPlaceholder extends StatelessWidget {
  const _ScreenshotPlaceholder({this.error = false});

  final bool error;

  @override
  Widget build(BuildContext context) {
    if (!error) {
      return DecoratedBox(
        key: ValueKey('store-screenshot-loading'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHigh,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Center(
          child: ui.GlyphIcon(
            ui.AppGlyphs.photos,
            size: 32,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: .55),
          ),
        ),
      );
    }
    return ColoredBox(
      key: const ValueKey('store-screenshot-error'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: ui.GlyphIcon(
          ui.AppGlyphs.photos,
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
