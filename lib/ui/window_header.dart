// Ported from FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// The window plugin is adapted to window_manager. SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'context.dart';
import 'icons/icons.dart';
import 'localization.dart';
import 'shape.dart';
import 'surface.dart';

const double windowHeaderHeight = 32;
const double captionButtonWidth = 46;
const double _pinIconSize = 16;

class WindowCaptionState {
  const WindowCaptionState({
    this.isPinned = false,
    this.isMaximized = false,
    this.isFullScreen = false,
  });

  final bool isPinned;
  final bool isMaximized;
  final bool isFullScreen;

  WindowCaptionState copyWith({
    bool? isPinned,
    bool? isMaximized,
    bool? isFullScreen,
  }) => WindowCaptionState(
    isPinned: isPinned ?? this.isPinned,
    isMaximized: isMaximized ?? this.isMaximized,
    isFullScreen: isFullScreen ?? this.isFullScreen,
  );
}

/// The FlClash desktop caption bar, backed by window_manager.
class WindowHeader extends StatefulWidget {
  const WindowHeader({super.key});

  @override
  State<WindowHeader> createState() => _WindowHeaderState();
}

class _WindowHeaderState extends State<WindowHeader> with WindowListener {
  WindowCaptionState _state = const WindowCaptionState();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    unawaited(_syncState());
  }

  Future<void> _syncState() async {
    try {
      final values = await Future.wait<bool>([
        windowManager.isAlwaysOnTop(),
        windowManager.isMaximized(),
        windowManager.isFullScreen(),
      ]);
      if (!mounted) return;
      setState(() {
        _state = WindowCaptionState(
          isPinned: values[0],
          isMaximized: values[1],
          isFullScreen: values[2],
        );
      });
    } catch (_) {
      // The title bar also renders in widget tests and remote desktop sessions.
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _state = _state.copyWith(isMaximized: true));
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _state = _state.copyWith(isMaximized: false));
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _state = _state.copyWith(isFullScreen: true));
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _state = _state.copyWith(isFullScreen: false));
  }

  Future<void> _toggleMaximized() async {
    try {
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      } else if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {}
  }

  Future<void> _togglePinned() async {
    try {
      final pinned = await windowManager.isAlwaysOnTop();
      await windowManager.setAlwaysOnTop(!pinned);
      if (mounted) {
        setState(() => _state = _state.copyWith(isPinned: !pinned));
      }
    } catch (_) {}
  }

  Future<void> _drag() async {
    try {
      await windowManager.startDragging();
    } catch (_) {}
  }

  Future<void> _minimize() async {
    try {
      await windowManager.minimize();
    } catch (_) {}
  }

  Future<void> _close() async {
    try {
      await windowManager.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WindowHeaderBar(
      state: _state,
      onDragStart: _drag,
      onDoubleTap: _toggleMaximized,
      onPin: _togglePinned,
      onMinimize: _minimize,
      onMaximize: _toggleMaximized,
      onClose: _close,
    );
  }
}

class _WindowHeaderBar extends StatelessWidget {
  const _WindowHeaderBar({
    required this.state,
    required this.onDragStart,
    required this.onDoubleTap,
    required this.onPin,
    required this.onMinimize,
    required this.onMaximize,
    required this.onClose,
  });

  final WindowCaptionState state;
  final Future<void> Function() onDragStart;
  final Future<void> Function() onDoubleTap;
  final Future<void> Function() onPin;
  final Future<void> Function() onMinimize;
  final Future<void> Function() onMaximize;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Material(
      color: colorScheme.chromeSurface,
      shape: Border(bottom: Divider.createBorderSide(context)),
      child: SizedBox(
        height: windowHeaderHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => unawaited(onDragStart()),
                onDoubleTap: () => unawaited(onDoubleTap()),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const WidgetStatePropertyAll(
                      Size(captionButtonWidth, windowHeaderHeight),
                    ),
                    maximumSize: const WidgetStatePropertyAll(
                      Size(captionButtonWidth, windowHeaderHeight),
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    shape: const WidgetStatePropertyAll(AppShape.none),
                    foregroundColor: WidgetStatePropertyAll(
                      colorScheme.onSurface,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: IconButton(
                        tooltip: state.isPinned
                            ? context.l10n.unpinWindow
                            : context.l10n.pinWindow,
                        style: const ButtonStyle(
                          shape: WidgetStatePropertyAll(CircleBorder()),
                          minimumSize: WidgetStatePropertyAll(Size.zero),
                          maximumSize: WidgetStatePropertyAll(Size.infinite),
                          iconSize: WidgetStatePropertyAll(_pinIconSize),
                        ),
                        onPressed: () => unawaited(onPin()),
                        icon: AnimatedGlyph(
                          glyph: AppGlyphs.pin,
                          filled: state.isPinned,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.minimizeWindow,
                      onPressed: () => unawaited(onMinimize()),
                      icon: const CaptionIcon(CaptionGlyph.minimize),
                    ),
                    IconButton(
                      tooltip: state.isMaximized || state.isFullScreen
                          ? context.l10n.restoreWindow
                          : context.l10n.maximizeWindow,
                      onPressed: () => unawaited(onMaximize()),
                      icon: CaptionIcon(
                        state.isMaximized || state.isFullScreen
                            ? CaptionGlyph.restore
                            : CaptionGlyph.maximize,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.closeWindow,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              states.any(
                                (state) =>
                                    state == WidgetState.hovered ||
                                    state == WidgetState.pressed,
                              )
                              ? colorScheme.error
                              : null,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              states.any(
                                (state) =>
                                    state == WidgetState.hovered ||
                                    state == WidgetState.pressed,
                              )
                              ? colorScheme.onError
                              : null,
                        ),
                      ),
                      onPressed: () => unawaited(onClose()),
                      icon: const CaptionIcon(CaptionGlyph.close),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
