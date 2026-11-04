// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'inherited.dart';
import 'typography.dart';

extension BuildContextExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get disableAnimations => MediaQuery.disableAnimationsOf(this);
  Duration motionDuration(Duration duration) =>
      disableAnimations ? Duration.zero : duration;
  double get bottomInset =>
      BottomInsetScope.of(this) + MediaQuery.paddingOf(this).bottom;
  TextStyle get listTitleStyle =>
      AppTextStyle.body.of(this).copyWith(color: colorScheme.onSurface);
  TextStyle get listSubtitleStyle => AppTextStyle.subheadline
      .of(this)
      .copyWith(color: colorScheme.onSurfaceVariant);
  TextStyle get cardHeaderStyle => AppTextStyle.headline
      .of(this)
      .copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: .8));
}
