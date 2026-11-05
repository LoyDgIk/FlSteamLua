// Dashboard card vocabulary from FlClash
// 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7, with application-neutral data.
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import 'context.dart';
import 'elastic_press.dart';
import 'icons/icons.dart';
import 'shape.dart';
import 'surface.dart';
import 'switch.dart';
import 'typography.dart';

enum DashboardDensity {
  standard,
  compact,
  mobile;

  bool get isDesktop => this != mobile;
  bool get isCompact => this == compact;

  static DashboardDensity of(double width) {
    if (width < 640) return mobile;
    if (width < 1040) return compact;
    return standard;
  }
}

EdgeInsets dashboardCardPadding(DashboardDensity density) => switch (density) {
  DashboardDensity.standard => const EdgeInsets.symmetric(
    horizontal: 22,
    vertical: 20,
  ),
  DashboardDensity.compact => const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 16,
  ),
  DashboardDensity.mobile => const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 18,
  ),
};

double dashboardCardRadius(DashboardDensity density) =>
    density.isDesktop ? 32 : 34;

class DashboardColors {
  const DashboardColors._({
    required this.page,
    required this.card,
    required this.tone,
    required this.tone2,
    required this.ok,
    required this.okContainer,
    required this.onOkContainer,
    required this.warn,
    required this.warnContainer,
    required this.onWarnContainer,
  });

  factory DashboardColors.of(BuildContext context) {
    final colorScheme = context.colorScheme;
    final card = SurfaceLevel.card.colorOf(colorScheme);
    return DashboardColors._(
      page: SurfaceLevel.page.colorOf(colorScheme),
      card: card,
      tone: SurfaceLevel.block.colorOf(colorScheme),
      tone2: SurfaceLevel.inset.colorOf(colorScheme),
      ok: const Color(0xff1b8d55),
      okContainer: colorScheme.primaryContainer,
      onOkContainer: colorScheme.onPrimaryContainer,
      warn: colorScheme.error,
      warnContainer: colorScheme.errorContainer,
      onWarnContainer: colorScheme.onErrorContainer,
    );
  }

  final Color page;
  final Color card;
  final Color tone;
  final Color tone2;
  final Color ok;
  final Color okContainer;
  final Color onOkContainer;
  final Color warn;
  final Color warnContainer;
  final Color onWarnContainer;
}

abstract final class DashboardShadows {
  static List<BoxShadow> e1(BuildContext context) =>
      context.colorScheme.brightness == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Color(0x8c000000),
            offset: Offset(0, 10),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0d000000),
            offset: Offset(0, 0.5),
            blurRadius: 1,
          ),
          BoxShadow(
            color: Color(0x0a000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
          BoxShadow(
            color: Color(0x17000000),
            offset: Offset(0, 12),
            blurRadius: 24,
            spreadRadius: -7,
          ),
        ];
}

abstract final class DashboardText {
  static TextStyle cardTitle(BuildContext context) => AppTextStyle.footnote
      .of(context, emphasized: true)
      .copyWith(color: context.colorScheme.onSurfaceVariant);

  static TextStyle label(BuildContext context, {Color? color}) => AppTextStyle
      .caption1
      .of(context)
      .copyWith(
        color: color ?? context.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle figure(BuildContext context, AppTextStyle style) => style
      .of(context, emphasized: true)
      .copyWith(
        letterSpacing: -0.02 * style.size,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle rowTitle(BuildContext context) =>
      AppTextStyle.subheadline.of(context, emphasized: true);
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    this.padding,
    this.onTap,
    this.semanticLabel,
    this.clipBehavior = Clip.none,
    required this.child,
  });

  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Clip clipBehavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensity.of(MediaQuery.sizeOf(context).width);
    final shape = AppShape.all(dashboardCardRadius(density));
    final content = Padding(
      padding: padding ?? dashboardCardPadding(density),
      child: child,
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        clipBehavior: clipBehavior,
        decoration: ShapeDecoration(
          color: DashboardColors.of(context).card,
          shape: shape,
          shadows: DashboardShadows.e1(context),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: onTap == null
              ? content
              : FocusRing(
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: onTap,
                    child: content,
                  ),
                ),
        ),
      ),
    );
  }
}

class DashboardCardHeader extends StatelessWidget {
  const DashboardCardHeader({
    super.key,
    this.glyph,
    required this.title,
    this.leading = const [],
    this.trailing = const [],
    this.chevron = false,
  });

  static const height = 24.0;
  static const glyphSize = 18.0;

  final Glyph? glyph;
  final String title;
  final List<Widget> leading;
  final List<Widget> trailing;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = AppTextStyle.footnote
        .of(context, emphasized: true)
        .copyWith(color: colorScheme.onSurfaceVariant);
    final start = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        ...leading,
      ],
    );
    return SizedBox(
      height: height,
      child: Row(
        spacing: 8,
        children: [
          if (glyph case final glyph?)
            GlyphIcon(
              glyph,
              size: glyphSize,
              color: colorScheme.onSurfaceVariant,
            ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: start),
                if (trailing.isNotEmpty || chevron)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      ...trailing,
                      if (chevron)
                        GlyphIcon(
                          AppGlyphs.chevronForward,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardBlock extends StatelessWidget {
  const DashboardBlock({
    super.key,
    required this.radius,
    this.color,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.semanticLabel,
    required this.child,
  });

  final double radius;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = AppShape.all(radius);
    final content = Padding(padding: padding, child: child);
    return Container(
      decoration: ShapeDecoration(
        color: color ?? DashboardColors.of(context).tone,
        shape: shape,
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: Semantics(
                button: true,
                label: semanticLabel,
                child: FocusRing(
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: onTap,
                    child: content,
                  ),
                ),
              ),
            ),
    );
  }
}

class ShapeBadge extends StatelessWidget {
  const ShapeBadge({
    super.key,
    required this.shape,
    required this.color,
    required this.size,
    this.rotation = 0,
    this.ring,
    this.child,
  });

  final RoundedPolygon shape;
  final Color color;
  final double size;
  final double rotation;
  final BorderSide? ring;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: ShapePainter(
      path: shapePathOf(shape),
      color: color,
      rotation: rotation,
      ring: ring,
    ),
    child: SizedBox.square(
      dimension: size,
      child: child == null ? null : Center(child: child),
    ),
  );
}

final _shapePaths = Expando<Path>();

Path shapePathOf(RoundedPolygon shape) => _shapePaths[shape] ??= shape.toPath();

class ShapePainter extends CustomPainter {
  const ShapePainter({
    required this.path,
    required this.color,
    this.rotation = 0,
    this.ring,
  });

  final Path path;
  final Color color;
  final double rotation;
  final BorderSide? ring;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(rotation)
      ..scale(size.width, size.height)
      ..translate(-0.5, -0.5)
      ..drawPath(path, Paint()..color = color);
    if (ring case final ring?) {
      _strokeUnitShape(canvas, path, size.width, ring);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShapePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.rotation != rotation ||
      oldDelegate.ring != ring;
}

void _strokeUnitShape(
  Canvas canvas,
  Path path,
  double extent,
  BorderSide side,
) {
  final scale = 1 + side.width * side.strokeAlign / extent;
  canvas
    ..save()
    ..translate(0.5, 0.5)
    ..scale(scale)
    ..translate(-0.5, -0.5)
    ..drawPath(path, side.toPaint()..strokeWidth = side.width / extent / scale)
    ..restore();
}

enum DashboardChipTone { idle, ok, warn }

class DashboardChip extends StatelessWidget {
  const DashboardChip({
    super.key,
    required this.label,
    this.tone = DashboardChipTone.idle,
    this.dot = false,
  });

  final String label;
  final DashboardChipTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final (background, foreground) = switch (tone) {
      DashboardChipTone.idle => (colors.tone, colorScheme.onSurfaceVariant),
      DashboardChipTone.ok => (colors.okContainer, colors.onOkContainer),
      DashboardChipTone.warn => (colors.warnContainer, colors.onWarnContainer),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(color: background, shape: AppShape.full),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (dot)
            DecoratedBox(
              decoration: ShapeDecoration(
                color: foreground,
                shape: AppShape.circle,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption1
                  .of(context, emphasized: true)
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardSwitchRow extends StatelessWidget {
  const DashboardSwitchRow({
    super.key,
    required this.glyph,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconSize = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.radius = 20,
  });

  final Glyph glyph;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DashboardBlock(
      radius: radius,
      padding: padding,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: title,
      child: Row(
        spacing: 12,
        children: [
          AnimatedContainer(
            duration: context.motionDuration(const Duration(milliseconds: 220)),
            width: iconSize,
            height: iconSize,
            decoration: ShapeDecoration(
              color: value
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerLowest,
              shape: value ? AppShape.all(13) : AppShape.circle,
            ),
            child: Center(
              child: GlyphIcon(
                glyph,
                size: iconSize * 0.5,
                color: value
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: CommonSwitch.trackWidth,
            height: CommonSwitch.trackHeight,
            child: OverflowBox(
              alignment: Alignment.center,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: CommonSwitch(
                value: value,
                onChanged: onChanged,
                semanticLabel: title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardConnectedGroup extends StatelessWidget {
  const DashboardConnectedGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 3,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

class DashboardConnectedButton extends StatelessWidget {
  const DashboardConnectedButton({
    super.key,
    required this.selected,
    required this.first,
    required this.last,
    required this.background,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final bool selected;
  final bool first;
  final bool last;
  final Color background;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const outer = 20.0;
    const inner = 4.0;
    final startRest = first ? outer : inner;
    final endRest = last ? outer : inner;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        child: ElasticPress(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: selected ? 1 : 0),
            duration: context.motionDuration(const Duration(milliseconds: 240)),
            curve: Curves.easeOutCubic,
            builder: (context, amount, child) {
              final start = lerpDouble(startRest, outer, amount)!;
              final end = lerpDouble(endRest, outer, amount)!;
              final shape = AppShape.of(
                BorderRadius.horizontal(
                  left: Radius.circular(rtl ? end : start),
                  right: Radius.circular(rtl ? start : end),
                ),
              );
              return FocusRing(
                shape: shape,
                standsOff: selected,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: Color.lerp(background, colorScheme.primary, amount),
                    shape: shape,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: shape,
                      onTap: onTap,
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: DefaultTextStyle.merge(
              style: AppTextStyle.subheadline
                  .of(context, emphasized: true)
                  .copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 18,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardIconButton extends StatelessWidget {
  const DashboardIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.icon,
    this.iconSize = 18,
  });

  final Glyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final Widget? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final duration = context.motionDuration(const Duration(milliseconds: 220));
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        color: selected ? colorScheme.primary : Colors.transparent,
        shape: const CircleBorder(),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: iconSize,
        style: IconButton.styleFrom(
          padding: icon == null ? null : EdgeInsets.zero,
          minimumSize: const Size.square(40),
          fixedSize: const Size.square(40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: selected
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
          shape: const CircleBorder(),
        ),
        icon: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: icon ?? GlyphIcon(glyph, key: ValueKey(glyph), size: iconSize),
        ),
      ),
    );
  }
}

String dashboardCount(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
