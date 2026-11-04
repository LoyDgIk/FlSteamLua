import 'package:flutter/material.dart';
import '../../../ui/ui.dart' as ui;

class OnlineCover extends StatelessWidget {
  const OnlineCover({
    super.key,
    required this.url,
    this.height,
    this.fit = BoxFit.cover,
  });
  final String url;
  final double? height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    return ui.AppImage(
      url: url,
      height: height,
      fit: fit,
      placeholderGlyph: ui.AppGlyphs.photos,
    );
  }
}

String onlineFileSize(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(1)} KB';
