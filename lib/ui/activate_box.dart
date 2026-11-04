// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/widgets.dart';

class ActivateBox extends StatelessWidget {
  const ActivateBox({super.key, required this.child, this.active = false});

  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(ignoring: !active, child: child);
}
