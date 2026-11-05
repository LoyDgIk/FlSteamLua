// Adapted from FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7 lib/ui/sortable.dart.
// SPDX-License-Identifier: GPL-3.0-only
// Uses the application's localization and shared glyphs.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'context.dart';
import 'icons/icons.dart';
import 'localization.dart';
import 'shape.dart';

class SortHandle extends StatefulWidget {
  const SortHandle({super.key, required this.index});

  final int index;

  @override
  State<SortHandle> createState() => _SortHandleState();
}

class _SortHandleState extends State<SortHandle> {
  var _focused = false;
  var _lifted = false;

  @override
  void didUpdateWidget(SortHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index || !_focused) {
      return;
    }
    final policy = widget.index > oldWidget.index
        ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
        : ScrollPositionAlignmentPolicy.keepVisibleAtStart;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: policy,
          duration: context.motionDuration(kThemeAnimationDuration),
        );
      }
    });
  }

  void _handleFocusChange(bool focused) {
    setState(() {
      _focused = focused;
      _lifted = _lifted && focused;
    });
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if ({
          LogicalKeyboardKey.select,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.gameButtonA,
        }.contains(key) ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        setState(() {
          _lifted = !_lifted;
        });
      }
      return KeyEventResult.handled;
    }
    if (!_lifted || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _lifted = false;
      });
      return KeyEventResult.handled;
    }
    final offset = switch (key) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.arrowRight => 0,
      _ => null,
    };
    if (offset == null) {
      return KeyEventResult.ignored;
    }
    final list = SliverReorderableList.maybeOf(context)?.widget;
    final target = widget.index + offset;
    if (offset != 0 && list != null && target >= 0 && target < list.itemCount) {
      list.onReorderItem?.call(widget.index, target);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    const dimension = kMinInteractiveDimension;
    return Semantics(
      button: true,
      label: context.l10n.sort,
      child: Focus(
        onFocusChange: _handleFocusChange,
        onKeyEvent: _handleKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: ColoredBox(
            color: Colors.transparent,
            child: SizedBox.square(
              dimension: dimension,
              child: Center(
                child: AnimatedContainer(
                  duration: context.motionDuration(kThemeAnimationDuration),
                  width: dimension - 8,
                  height: dimension - 8,
                  decoration: ShapeDecoration(
                    shape: AppShape.circle,
                    color: colorScheme.onSurface.withValues(
                      alpha: _lifted
                          ? 0.16
                          : _focused
                          ? 0.12
                          : 0,
                    ),
                  ),
                  child: Center(
                    child: GlyphIcon(
                      AppGlyphs.dragHandle,
                      color: _lifted ? colorScheme.primary : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
