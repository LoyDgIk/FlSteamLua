// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'color.dart';
import 'context.dart';
import 'icons/icons.dart';
import 'shape.dart';

class CommonCircleLoading extends StatefulWidget {
  const CommonCircleLoading({
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  const CommonCircleLoading.page({super.key, this.color, this.semanticLabel})
    : size = 48;

  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  State<CommonCircleLoading> createState() => _CommonCircleLoadingState();
}

class CommonProgressBar extends StatelessWidget {
  const CommonProgressBar({super.key, required this.value, this.height = 4});

  final double? value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final progress = value?.clamp(0.0, 1.0);
    if (progress == null) {
      return _IndeterminateProgressBar(height: height);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: context.motionDuration(const Duration(milliseconds: 220)),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => ClipRRect(
        borderRadius: AppRadius.full,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.colorScheme.surfaceContainerHighest),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: animated,
                  heightFactor: 1,
                  child: ColoredBox(color: context.colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndeterminateProgressBar extends StatefulWidget {
  const _IndeterminateProgressBar({required this.height});

  final double height;

  @override
  State<_IndeterminateProgressBar> createState() =>
      _IndeterminateProgressBarState();
}

class _IndeterminateProgressBarState extends State<_IndeterminateProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: AppRadius.full,
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _IndeterminateProgressPainter(
              progress: _controller.value,
              animated: !reducedMotion,
              color: context.colorScheme.primary,
              trackColor: context.colorScheme.primary.withValues(alpha: .18),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndeterminateProgressPainter extends CustomPainter {
  _IndeterminateProgressPainter({
    required this.progress,
    required this.animated,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final bool animated;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final paint = Paint();
    paint.color = animated ? trackColor : color.withValues(alpha: .48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      paint,
    );
    if (!animated || size.width <= 0) return;
    final bandWidth = size.width * .46;
    final travel = size.width + bandWidth;
    final left = -bandWidth + travel * progress;
    final rect = Rect.fromLTWH(left, 0, bandWidth, size.height);
    paint.shader = LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: .82),
        color.withValues(alpha: 0),
      ],
      stops: const [0, .5, 1],
    ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
  }

  @override
  bool shouldRepaint(_IndeterminateProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.animated != animated ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class _CommonCircleLoadingState extends State<CommonCircleLoading>
    with SingleTickerProviderStateMixin {
  static const _turnDuration = Duration(milliseconds: 1000);

  late final AnimationController _turns;

  @override
  void initState() {
    super.initState();
    _turns = AnimationController(vsync: this, duration: _turnDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.size ?? IconTheme.of(context).size ?? Glyph.size;
    return Semantics(
      label: widget.semanticLabel,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(side),
          painter: _CometRingPainter(
            turns: _turns,
            color: widget.color ?? context.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _CometRingPainter extends CustomPainter {
  _CometRingPainter({required this.turns, required this.color})
    : super(repaint: turns);

  static const _liveArea = 20 / 24;
  static const _minStrokeWidth = 1.5;
  static const _tail = 0.72;

  final Animation<double> turns;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final strokeWidth = math.max(side / 12, _minStrokeWidth);
    final radius = (side * _liveArea - strokeWidth) / 2;
    if (radius <= 0) {
      return;
    }
    final ring = Rect.fromCircle(center: Offset.zero, radius: radius);
    const sweep = _tail * 2 * math.pi;
    Paint stroke() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawCircle(Offset.zero, radius, stroke()..color = color.opacity12);
    canvas.rotate(turns.value * 2 * math.pi);
    canvas.drawArc(
      ring,
      0,
      sweep,
      false,
      stroke()
        ..shader = SweepGradient(
          colors: [color.opacity0, color.opacity30, color, color.opacity0],
          stops: const [0, _tail / 2, _tail, _tail],
        ).createShader(ring),
    );
    canvas.drawCircle(
      Offset(math.cos(sweep), math.sin(sweep)) * radius,
      strokeWidth / 2,
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CometRingPainter oldDelegate) =>
      oldDelegate.turns != turns || oldDelegate.color != color;
}
