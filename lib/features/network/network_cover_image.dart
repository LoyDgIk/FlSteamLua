import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../ui/icons/icons.dart';
import '../../ui/image.dart';
import 'network_preferences.dart';

/// Resolves the selected cover source and retains the original image fallback.
class NetworkCoverImage extends StatefulWidget {
  const NetworkCoverImage({
    super.key,
    required this.settings,
    required this.appId,
    required this.url,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    this.alignment = Alignment.center,
    this.excludeFromSemantics = false,
    this.previewable = false,
  });
  final SettingsStore settings;
  final int appId;
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final AlignmentGeometry alignment;
  final bool excludeFromSemantics;
  final bool previewable;

  @override
  State<NetworkCoverImage> createState() => _NetworkCoverImageState();
}

class _NetworkCoverImageState extends State<NetworkCoverImage> {
  late NetworkPreferences _preferences;
  late Future<List<String>> _urls;
  String _source = '';

  @override
  void initState() {
    super.initState();
    _preferences = NetworkPreferences(widget.settings);
    widget.settings.addListener(_changed);
    _resolve();
  }

  void _resolve() {
    _source = '${_preferences.coverSourceId}:${widget.settings.language}';
    _urls = _preferences.coverUrls(widget.appId, fallback: widget.url);
  }

  void _changed() {
    final source = '${_preferences.coverSourceId}:${widget.settings.language}';
    if (_source != source) setState(_resolve);
  }

  @override
  void didUpdateWidget(NetworkCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.removeListener(_changed);
      _preferences.dispose();
      _preferences = NetworkPreferences(widget.settings);
      widget.settings.addListener(_changed);
      _resolve();
    } else if (oldWidget.appId != widget.appId || oldWidget.url != widget.url) {
      _resolve();
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_changed);
    _preferences.dispose();
    super.dispose();
  }

  Widget _image(List<String> urls, int index) => AppImage(
    url: urls[index],
    width: widget.width,
    height: widget.height,
    fit: widget.fit,
    color: widget.color,
    colorBlendMode: widget.colorBlendMode,
    alignment: widget.alignment,
    excludeFromSemantics: widget.excludeFromSemantics,
    previewable: widget.previewable,
    previewUrls: urls,
    previewIndex: index,
    placeholderGlyph: AppGlyphs.photos,
    frameBuilder: widget.frameBuilder,
    loadingBuilder: widget.loadingBuilder,
    errorBuilder: (context, error, stack) => index + 1 < urls.length
        ? _image(urls, index + 1)
        : widget.errorBuilder?.call(context, error, stack) ??
              AppImagePlaceholder(
                glyph: AppGlyphs.photos,
                width: widget.width,
                height: widget.height,
                error: true,
              ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _urls,
    builder: (context, snapshot) => _image(snapshot.data ?? [widget.url], 0),
  );
}
