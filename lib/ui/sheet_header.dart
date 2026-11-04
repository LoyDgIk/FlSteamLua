// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'context.dart';
import 'inherited.dart';
import 'metrics.dart';
import 'shape.dart';

class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  static const height = _topPadding + _thickness;

  static const _topPadding = 6.0;
  static const _thickness = 4.0;
  static const _width = 28.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: _topPadding),
    child: Container(
      alignment: Alignment.center,
      height: _thickness,
      width: _width,
      decoration: ShapeDecoration(
        color: context.colorScheme.onSurfaceVariant,
        shape: AppShape.all(_thickness / 2),
      ),
    ),
  );
}

class SheetToolBar extends StatelessWidget {
  const SheetToolBar({super.key, required this.appBar, this.dragHandle = true});

  static const _trailing =
      sheetAppBarHeight - SheetDragHandle.height - sheetToolbarHeight;

  final Widget appBar;
  final bool dragHandle;

  @override
  Widget build(BuildContext context) {
    final bar = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dragHandle
            ? const SheetDragHandle()
            : const SizedBox(height: SheetDragHandle.height),
        appBar,
        const SizedBox(height: _trailing),
      ],
    );
    return dragHandle
        ? GestureDetector(behavior: HitTestBehavior.opaque, child: bar)
        : bar;
  }
}

class FloatingHeader extends StatelessWidget {
  const FloatingHeader({
    super.key,
    required this.backgroundColor,
    this.fadeStart = .5,
    this.overhang = 0,
    required this.child,
  });

  static const _alpha = .9;
  static const _fadeSteps = 8;

  final Color backgroundColor;
  final double fadeStart;
  final double overhang;
  final Widget child;

  Gradient _scrimOf(double height) {
    final start = (height - overhang) * fadeStart / height;
    final stops = <double>[0];
    final colors = <Color>[backgroundColor.withValues(alpha: _alpha)];
    for (var i = 0; i <= _fadeSteps; i++) {
      final t = i / _fadeSteps;
      stops.add(start + (1 - start) * t);
      colors.add(
        backgroundColor.withValues(
          alpha: _alpha * (1 - Curves.easeInOut.transform(t)),
        ),
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: stops,
      colors: colors,
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: -overhang,
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (_, constraints) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: _scrimOf(constraints.maxHeight),
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class FloatingHeaderBody extends StatelessWidget {
  const FloatingHeaderBody({
    super.key,
    required this.backgroundColor,
    required this.header,
    required this.body,
    this.footer,
  });

  final Color backgroundColor;
  final Widget header;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: body,
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: FloatingHeader(backgroundColor: backgroundColor, child: header),
      ),
      if (footer != null)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SheetOverhangLift(
            child: Material(type: MaterialType.transparency, child: footer),
          ),
        ),
    ],
  );
}

class SheetOverhangLift extends SingleChildRenderObjectWidget {
  const SheetOverhangLift({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSheetOverhangLift(SheetOverhangScope.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSheetOverhangLift).overhang = SheetOverhangScope.of(
      context,
    );
  }
}

class _RenderSheetOverhangLift extends RenderTransform {
  _RenderSheetOverhangLift(this._overhang)
    : super(transform: Matrix4.identity(), transformHitTests: true) {
    _overhang?.addListener(_syncTransform);
  }

  ValueListenable<double>? _overhang;

  set overhang(ValueListenable<double>? value) {
    if (_overhang == value) {
      return;
    }
    _overhang?.removeListener(_syncTransform);
    _overhang = value;
    _overhang?.addListener(_syncTransform);
    _syncTransform();
  }

  @override
  void performLayout() {
    super.performLayout();
    _syncTransform();
  }

  @override
  void dispose() {
    _overhang?.removeListener(_syncTransform);
    super.dispose();
  }

  void _syncTransform() {
    transform = Matrix4.translationValues(0, -(_overhang?.value ?? 0), 0);
  }
}
