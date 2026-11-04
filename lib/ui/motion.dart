// Adapted from FlClash at 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

const sidebarExpandDuration = Duration(milliseconds: 250);
const sidebarIndicatorDuration = Duration(milliseconds: 320);
const containerTransitionDuration = Duration(milliseconds: 300);
const detailTransitionDuration = Duration(milliseconds: 450);
const fadeTabDuration = Duration(milliseconds: 220);
const fadeTabCurve = Curves.easeInOut;
const commonDuration = Duration(milliseconds: 300);

/// Upstream's spring curve settles its residual exactly at the route end.
class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring, {required this.seconds})
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final double seconds;
  final SpringSimulation _simulation;
  late final double _residual = 1 - _simulation.x(seconds);

  @override
  double transformInternal(double t) =>
      _simulation.x(t * seconds) + _residual * t;
}

final dropletSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 165,
  ratio: 0.8,
);

double riseAndFall(double time, double peak, double sharpness) {
  if (time <= 0) return 0;
  final x = time / peak;
  return math.pow(x, sharpness) * math.exp(sharpness * (1 - x));
}

bool reduceMotionOf(BuildContext context, {bool requested = false}) =>
    requested || MediaQuery.disableAnimationsOf(context);

Duration motionDuration(
  BuildContext context,
  Duration duration, {
  bool reduceMotion = false,
}) =>
    reduceMotionOf(context, requested: reduceMotion) ? Duration.zero : duration;
