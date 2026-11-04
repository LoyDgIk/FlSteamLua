// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'dart:ui';

import 'package:flutter/material.dart';

import 'icons/icons.dart';
import 'inherited.dart';

class CommonExpandIcon extends StatefulWidget {
  const CommonExpandIcon({super.key, this.expand = false});

  final bool expand;

  @override
  State<CommonExpandIcon> createState() => _CommonExpandIconState();
}

class _CommonExpandIconState extends State<CommonExpandIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _iconTurns;

  static final Animatable<double> _iconTurnTween = Tween<double>(
    begin: 0,
    end: .5,
  ).chain(CurveTween(curve: Curves.fastOutSlowIn));

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = _animationController.drive(_iconTurnTween);
    if (widget.expand) {
      _animationController.value = 1;
    }
  }

  @override
  void didUpdateWidget(CommonExpandIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expand == widget.expand) {
      return;
    }
    widget.expand
        ? _animationController.forward()
        : _animationController.reverse();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animationController.view,
    builder: (_, child) => RotationTransition(turns: _iconTurns, child: child),
    child: const GlyphIcon(AppGlyphs.caretDown, fill: 1),
  );
}

Widget commonProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (_, child) {
      final value = Curves.easeInOut.transform(animation.value);
      final scale = lerpDouble(1, 1.02, value)!;
      return ProxyDecoratorProvider(
        isProxyDecorator: true,
        lift: value,
        child: Transform.scale(scale: scale, child: child),
      );
    },
    child: child,
  );
}
