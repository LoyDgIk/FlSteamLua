import 'package:flutter/material.dart';

enum FadeEdgeSide { top, bottom }

/// Fades a scrolling surface where it meets a fixed header or footer.
class FadeEdge extends StatelessWidget {
  const FadeEdge({
    super.key,
    required this.child,
    this.extent = 24,
    this.side = FadeEdgeSide.top,
  });

  final Widget child;
  final double extent;
  final FadeEdgeSide side;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final fraction = bounds.height <= 0
            ? 0.0
            : (extent / bounds.height).clamp(0.0, 1.0);
        final top = side == FadeEdgeSide.top;
        if (fraction <= 0) {
          return const LinearGradient(
            colors: [Colors.white, Colors.white],
          ).createShader(bounds);
        }
        return LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Colors.transparent, Colors.white],
          stops: top ? [0, fraction] : [1 - fraction, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
