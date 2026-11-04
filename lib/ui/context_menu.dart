// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'popup.dart';

import 'surface.dart';

const _touchDevices = {
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

/// A touch long press, the menu key and, on a remote, a held select key keep
/// the menu clear of the row, which a finger or the focus highlight would
/// otherwise leave covered.
class ContextMenuRegion extends StatefulWidget {
  final List<CommonPopupMenuItem>? menuItems;
  final Widget child;

  const ContextMenuRegion({super.key, this.menuItems, required this.child});

  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<ContextMenuRegion> {
  CommonPopupRoute<void>? _menu;

  bool get _enabled {
    final items = widget.menuItems;
    return items != null && items.isNotEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _closeUnlessEnabled();
  }

  @override
  void didUpdateWidget(ContextMenuRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _closeUnlessEnabled();
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  /// A row withdraws its menu while its item updates, which the open menu
  /// would otherwise still act on.
  void _closeUnlessEnabled() {
    if (_enabled) {
      return;
    }
    _closeMenu();
  }

  void _closeMenu() {
    final menu = _menu;
    if (menu == null) {
      return;
    }
    _menu = null;
    // This runs while the tree builds or unmounts, when nothing may pop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (menu.isCurrent) {
        menu.navigator!.pop();
      }
    });
  }

  void _open(Offset globalPosition, {bool avoid = false}) {
    final items = widget.menuItems;
    final navigator = Navigator.maybeOf(context);
    final navigatorBox = navigator?.context.findRenderObject();
    final box = context.findRenderObject();
    if (items == null ||
        items.isEmpty ||
        navigator == null ||
        navigatorBox is! RenderBox ||
        box is! RenderBox ||
        !box.hasSize) {
      return;
    }
    final point = navigatorBox.globalToLocal(globalPosition);
    final rowRect = MatrixUtils.transformRect(
      box.getTransformTo(navigatorBox),
      Offset.zero & box.size,
    );
    final menu = _menu = CommonPopupRoute<void>(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      placement: PopupPlacement.belowPoint,
      elevated: ElevatedSurfaceTheme.isIn(context),
      anchorOf: () => point & Size.zero,
      avoid: avoid ? rowRect : null,
      builder: (_) => CommonPopupMenu(items: items),
    );
    unawaited(
      navigator.push(menu).whenComplete(() {
        if (identical(_menu, menu)) {
          _menu = null;
        }
      }),
    );
  }

  void _openAtRow() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    _open(box.localToGlobal(box.size.bottomLeft(Offset.zero)), avoid: true);
  }

  KeyEventResult _handleKey(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed)) {
      if (event is KeyDownEvent) {
        _openAtRow();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: enabled ? (_, event) => _handleKey(event) : null,
      child: GestureDetector(
        onSecondaryTapUp: enabled
            ? (details) => _open(details.globalPosition)
            : null,
        child: GestureDetector(
          supportedDevices: _touchDevices,
          onLongPressStart: enabled
              ? (details) {
                  Feedback.forLongPress(context);
                  _open(details.globalPosition, avoid: true);
                }
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
