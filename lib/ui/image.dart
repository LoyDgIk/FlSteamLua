import 'package:flutter/material.dart';

import 'icons/icons.dart';
import 'localization.dart';
import 'side_sheet.dart';

const _defaultHeaders = <String, String>{};

/// Shared network image surface with one placeholder, cache identity and
/// optional full-size preview.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.headers,
    this.placeholder,
    this.placeholderGlyph = AppGlyphs.photos,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    this.color,
    this.colorBlendMode,
    this.cacheWidth,
    this.cacheHeight,
    this.excludeFromSemantics = true,
    this.previewable = false,
    this.previewUrls,
    this.previewIndex = 0,
    this.onTap,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final BorderRadiusGeometry? borderRadius;
  final Map<String, String>? headers;
  final Widget? placeholder;
  final Glyph placeholderGlyph;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final Color? color;
  final BlendMode? colorBlendMode;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool excludeFromSemantics;
  final bool previewable;
  final List<String>? previewUrls;
  final int previewIndex;
  final VoidCallback? onTap;

  Widget _placeholder(BuildContext context, {bool error = false}) =>
      placeholder ??
      AppImagePlaceholder(
        glyph: placeholderGlyph,
        width: width,
        height: height,
        error: error,
      );

  Widget _buildImage(BuildContext context) {
    if (url.isEmpty) return _placeholder(context);
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      headers: headers ?? _defaultHeaders,
      color: color,
      colorBlendMode: colorBlendMode,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return loadingBuilder?.call(context, child, progress) ??
            _placeholder(context);
      },
      errorBuilder: (context, error, stack) =>
          errorBuilder?.call(context, error, stack) ??
          _placeholder(context, error: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = url.isEmpty
        ? _placeholder(context)
        : SizedBox(
            width: width,
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: constraints.hasBoundedWidth && constraints.hasBoundedHeight
                    ? StackFit.expand
                    : StackFit.loose,
                children: [_placeholder(context), _buildImage(context)],
              ),
            ),
          );
    final image = borderRadius == null
        ? content
        : ClipRRect(borderRadius: borderRadius!, child: content);
    final preview =
        onTap ??
        (previewable && url.isNotEmpty
            ? () => showImagePreview(
                context,
                urls: previewUrls ?? [url],
                initialIndex: previewIndex,
                headers: headers,
              )
            : null);
    if (preview == null) return image;
    return Semantics(
      button: true,
      label: context.l10n.previewImage,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: preview, child: image),
      ),
    );
  }
}

class AppImagePlaceholder extends StatelessWidget {
  const AppImagePlaceholder({
    super.key,
    required this.glyph,
    this.width,
    this.height,
    this.error = false,
  });

  final Glyph glyph;
  final double? width;
  final double? height;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Center(
          child: GlyphIcon(
            glyph,
            size: 32,
            color: error
                ? colors.onSurfaceVariant
                : colors.onSurfaceVariant.withValues(alpha: .55),
          ),
        ),
      ),
    );
  }
}

class AppImagePreview extends StatefulWidget {
  const AppImagePreview({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.headers,
    this.sheetKey,
  });

  final List<String> urls;
  final int initialIndex;
  final Map<String, String>? headers;
  final Key? sheetKey;

  @override
  State<AppImagePreview> createState() => _AppImagePreviewState();
}

class _AppImagePreviewState extends State<AppImagePreview> {
  late var _index = widget.initialIndex.clamp(0, widget.urls.length - 1);

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final hasMany = urls.length > 1;
    return SideSheetScaffold(
      key: widget.sheetKey,
      title: context.l10n.previewImage,
      actions: [
        if (hasMany)
          SideSheetHeaderButton(
            tooltip: context.l10n.previousImage,
            onPressed: _index == 0 ? null : () => setState(() => _index--),
            icon: const GlyphIcon(AppGlyphs.chevronBack, size: 24),
          ),
        if (hasMany)
          SideSheetHeaderButton(
            tooltip: context.l10n.nextImage,
            onPressed: _index == urls.length - 1
                ? null
                : () => setState(() => _index++),
            icon: const GlyphIcon(AppGlyphs.chevronForward, size: 24),
          ),
      ],
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          SideSheetScaffold.headerHeight + 16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: LayoutBuilder(
                  builder: (context, constraints) => InteractiveViewer(
                    minScale: .8,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(80),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: AppImage(
                        url: urls[_index],
                        headers: widget.headers,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hasMany) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: urls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => SizedBox(
                    width: 112,
                    height: 72,
                    child: AppImage(
                      url: urls[index],
                      headers: widget.headers,
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _index = index),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showImagePreview(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
  Map<String, String>? headers,
}) {
  if (urls.isEmpty) return Future.value();
  return showModalSideSheet<void>(
    context: context,
    builder: (_) => AppImagePreview(
      urls: urls,
      initialIndex: initialIndex,
      headers: headers,
    ),
  );
}
