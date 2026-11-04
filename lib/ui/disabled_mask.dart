// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

class DisabledMask extends StatefulWidget {
  const DisabledMask({super.key, required this.disabled, required this.child});

  final bool disabled;
  final Widget child;

  @override
  State<DisabledMask> createState() => _DisabledMaskState();
}

class _DisabledMaskState extends State<DisabledMask>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: widget.disabled ? 1 : 0,
  );

  @override
  void didUpdateWidget(DisabledMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.disabled != widget.disabled) {
      widget.disabled ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.disabled,
            child: FadeTransition(
              opacity: _controller,
              child: ColoredBox(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .48),
                child: const AbsorbPointer(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
