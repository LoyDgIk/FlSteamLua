// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'color.dart';

enum FontFamily {
  twEmoji('Twemoji'),
  jetBrainsMono('JetBrainsMono');

  final String value;

  const FontFamily(this.value);
}

extension TextStyleExtension on TextStyle {
  TextStyle get toLight => copyWith(color: color?.opacity80);

  TextStyle get toLighter => copyWith(color: color?.opacity60);

  TextStyle get toJetBrainsMono =>
      copyWith(fontFamily: FontFamily.jetBrainsMono.value);

  TextStyle get toTabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
