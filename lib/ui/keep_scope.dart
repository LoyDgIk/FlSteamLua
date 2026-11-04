// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/widgets.dart';

class KeepScope extends StatefulWidget {
  const KeepScope({super.key, required this.keep, required this.child});

  final bool keep;
  final Widget child;

  @override
  State<KeepScope> createState() => _KeepScopeState();
}

class _KeepScopeState extends State<KeepScope> {
  @override
  Widget build(BuildContext context) =>
      Offstage(offstage: !widget.keep, child: widget.child);
}
