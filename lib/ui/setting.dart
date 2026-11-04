// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'card.dart';
import 'context.dart';
import 'typography.dart';

class SettingTextCard extends StatelessWidget {
  const SettingTextCard(
    this.text, {
    super.key,
    this.isSelected,
    required this.onPressed,
  });

  final String text;
  final bool? isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CommonCard(
    onPressed: onPressed,
    isSelected: isSelected,
    fillsSelection: true,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AppTextStyle.subheadline
            .of(context)
            .copyWith(
              color: isSelected == true ? context.colorScheme.onPrimary : null,
            ),
      ),
    ),
  );
}
