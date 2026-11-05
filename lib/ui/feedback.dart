// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Provider-driven queue adapted to a local status manager.
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'color.dart';
import 'context.dart';
import 'icons/icons.dart';
import 'shape.dart';
import 'surface.dart';
import 'typography.dart';
import 'localization.dart';
import 'dialogs.dart';
import '../core/task_center.dart';
import '../features/cloud/remote/remote_store.dart';

const _actionMinDuration = Duration(seconds: 6);
const _maxBufferedMessages = 8;
const _mobileMaxVisibleMessages = 2;
const _desktopMaxVisibleMessages = 4;
const _messageEnterDuration = Duration(milliseconds: 450);
const _messageExitDuration = Duration(milliseconds: 300);
const _messageCollapseDuration = Duration(milliseconds: 200);
const _messageSwipeOutDuration = Duration(milliseconds: 200);
const _messageSwipeBackDuration = Duration(milliseconds: 300);
const _messageEnterShift = -16.0;
const _messageEnterScale = 0.94;
const _swipeDismissFraction = 0.35;
const _swipeDismissVelocity = 700.0;
const _messageMaxWidth = 500.0;
const _messageMinHeight = 52.0;

final appFeedbackKey = GlobalKey<StatusManagerState>();

enum MessageLevel { info, success, warning, error }

extension MessageLevelExt on MessageLevel {
  Glyph? get glyph => switch (this) {
    MessageLevel.info => null,
    MessageLevel.success => AppGlyphs.checkCircle,
    MessageLevel.warning => AppGlyphs.warning,
    MessageLevel.error => AppGlyphs.error,
  };

  Color containerColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    return switch (this) {
      MessageLevel.error => colorScheme.errorContainer,
      _ => SurfaceLevel.floatingOf(colorScheme).colorOf(colorScheme),
    };
  }

  Color contentColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    return switch (this) {
      MessageLevel.error => colorScheme.onErrorContainer,
      _ => colorScheme.onSurfaceVariant,
    };
  }

  Color iconColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    return switch (this) {
      MessageLevel.info => colorScheme.onSurfaceVariant,
      MessageLevel.success => colorScheme.success,
      MessageLevel.warning => colorScheme.warning,
      MessageLevel.error => colorScheme.onErrorContainer,
    };
  }

  Duration get duration => switch (this) {
    MessageLevel.info || MessageLevel.success => const Duration(seconds: 3),
    MessageLevel.warning => const Duration(seconds: 5),
    MessageLevel.error => const Duration(seconds: 6),
  };
}

class MessageActionState {
  const MessageActionState({required this.actionText, required this.action});

  final String actionText;
  final VoidCallback action;
}

class CommonMessage {
  const CommonMessage({
    required this.id,
    required this.text,
    required this.level,
    required this.duration,
    this.actionState,
  });

  final String id;
  final String text;
  final MessageLevel level;
  final Duration duration;
  final MessageActionState? actionState;

  CommonMessage copyWith({String? id}) => CommonMessage(
    id: id ?? this.id,
    text: text,
    level: level,
    duration: duration,
    actionState: actionState,
  );
}

class StatusManager extends StatefulWidget {
  const StatusManager({super.key, required this.child, this.topOffset = 0});

  final Widget child;
  final double topOffset;

  @override
  State<StatusManager> createState() => StatusManagerState();
}

class StatusManagerState extends State<StatusManager> {
  final _entriesNotifier = ValueNotifier<List<_MessageEntry>>([]);
  final _bufferMessages = Queue<CommonMessage>();
  final _activeTimers = <String, Timer>{};
  var _serial = 0;
  String? _draggingId;

  @override
  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _bufferMessages.clear();
    _entriesNotifier.dispose();
    super.dispose();
  }

  int get _maxVisibleMessages => MediaQuery.sizeOf(context).width < 600
      ? _mobileMaxVisibleMessages
      : _desktopMaxVisibleMessages;

  List<_MessageEntry> get _entries => _entriesNotifier.value;

  Iterable<_MessageEntry> get _visibleEntries =>
      _entries.where((entry) => entry.visible);

  void message(
    String text, {
    MessageLevel level = MessageLevel.info,
    MessageActionState? actionState,
  }) {
    if (text.isEmpty) return;
    final commonMessage = CommonMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_serial++}',
      text: text,
      level: level,
      duration: _resolveDuration(level, actionState),
      actionState: actionState,
    );
    if (_mergeMessage(commonMessage)) return;
    _bufferMessages.add(commonMessage);
    _trimBuffer();
    _processQueue();
  }

  Duration _resolveDuration(
    MessageLevel level,
    MessageActionState? actionState,
  ) {
    final duration = level.duration;
    if (actionState == null || duration >= _actionMinDuration) return duration;
    return _actionMinDuration;
  }

  bool _isSameMessage(CommonMessage a, CommonMessage b) =>
      a.text == b.text && a.level == b.level;

  bool _mergeMessage(CommonMessage message) {
    final entries = _entries;
    final index = entries.indexWhere(
      (entry) => entry.visible && _isSameMessage(entry.message, message),
    );
    if (index != -1) {
      final merged = message.copyWith(id: entries[index].message.id);
      _entriesNotifier.value = List<_MessageEntry>.from(entries)
        ..[index] = entries[index].copyWith(message: merged);
      _startTimer(merged);
      return true;
    }
    return _bufferMessages.any((buffered) => _isSameMessage(buffered, message));
  }

  void _trimBuffer() {
    while (_bufferMessages.length > _maxBufferedMessages) {
      final dropped = _bufferMessages.firstWhere(
        (message) => message.level != MessageLevel.error,
        orElse: () => _bufferMessages.first,
      );
      _bufferMessages.remove(dropped);
    }
  }

  void _processQueue() {
    if (_draggingId != null) return;
    while (_bufferMessages.isNotEmpty) {
      final visible = _visibleEntries.toList();
      if (visible.length < _maxVisibleMessages) {
        _showMessage(_bufferMessages.removeFirst());
        continue;
      }
      CommonMessage? error;
      for (final message in _bufferMessages) {
        if (message.level == MessageLevel.error) {
          error = message;
          break;
        }
      }
      if (error == null) return;
      _MessageEntry? preempted;
      for (final entry in visible.reversed) {
        if (entry.message.level != MessageLevel.error) {
          preempted = entry;
          break;
        }
      }
      if (preempted == null) return;
      _hideMessage(preempted.id);
      _bufferMessages.remove(error);
      _showMessage(error);
    }
  }

  void _showMessage(CommonMessage message) {
    _entriesNotifier.value = List<_MessageEntry>.from(_entries)
      ..insert(0, _MessageEntry(message: message, visible: true));
    _startTimer(message);
  }

  void _startTimer(CommonMessage message) {
    _activeTimers.remove(message.id)?.cancel();
    if (_draggingId != null) return;
    _activeTimers[message.id] = Timer(message.duration, () {
      _hideMessage(message.id);
      _processQueue();
    });
  }

  void _hideMessage(String id, {bool swiped = false}) {
    _activeTimers.remove(id)?.cancel();
    final entries = _entries;
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index == -1 || !entries[index].visible) return;
    _entriesNotifier.value = List<_MessageEntry>.from(entries)
      ..[index] = entries[index].copyWith(visible: false, swiped: swiped);
  }

  void _cancelMessage(String id, {bool swiped = false}) {
    if (_draggingId == id) _draggingId = null;
    _bufferMessages.removeWhere((message) => message.id == id);
    _hideMessage(id, swiped: swiped);
    _resumeTimers();
    _processQueue();
  }

  void _setDragging(String id, bool dragging) {
    if (dragging) {
      if (_draggingId == id) return;
      _draggingId = id;
      for (final timer in _activeTimers.values) {
        timer.cancel();
      }
      _activeTimers.clear();
      return;
    }
    if (_draggingId != id) return;
    _draggingId = null;
    _resumeTimers();
    _processQueue();
  }

  void _resumeTimers() {
    for (final entry in _visibleEntries.toList()) {
      if (_activeTimers.containsKey(entry.id)) continue;
      _startTimer(entry.message);
    }
  }

  void _removeMessage(String id) {
    if (!mounted) return;
    final entries = _entries;
    if (!entries.any((entry) => entry.id == id)) return;
    _entriesNotifier.value = entries
        .where((entry) => entry.id != id)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => FeedbackScope(
    manager: this,
    child: Stack(
      children: [
        widget.child,
        Positioned(
          top: widget.topOffset + MediaQuery.viewPaddingOf(context).top + 8,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ValueListenableBuilder(
                valueListenable: _entriesNotifier,
                builder: (_, entries, _) => Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in entries)
                      _MessageTransition(
                        key: Key(entry.id),
                        visible: entry.visible,
                        swiped: entry.swiped,
                        onHidden: () => _removeMessage(entry.id),
                        child: _MessageCard(
                          message: entry.message,
                          onDismiss: _cancelMessage,
                          onDragging: _setDragging,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class FeedbackScope extends InheritedWidget {
  const FeedbackScope({super.key, required this.manager, required super.child});

  final StatusManagerState manager;

  static StatusManagerState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeedbackScope>()?.manager;

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) =>
      manager != oldWidget.manager;
}

extension FeedbackContext on BuildContext {
  void showFeedback(
    String text, {
    MessageLevel level = MessageLevel.info,
    MessageActionState? actionState,
  }) {
    final manager = FeedbackScope.maybeOf(this) ?? appFeedbackKey.currentState;
    manager?.message(text, level: level, actionState: actionState);
  }
}

void showAppFeedback(
  BuildContext context,
  String text, {
  MessageLevel level = MessageLevel.info,
  MessageActionState? actionState,
}) => context.showFeedback(text, level: level, actionState: actionState);

void showAppSuccess(BuildContext context, String text) =>
    showAppFeedback(context, text, level: MessageLevel.success);

String appErrorText(BuildContext context, Object error) {
  final texts = context.l10n;
  if (error is TaskCancelled) return texts.operationCancelled;
  if (error is SocketException || error is TimeoutException) {
    return texts.connectionFailedRetry;
  }
  if (error is FileSystemException) return texts.fileOperationFailedHint;
  if (error is RemoteStoreException) {
    return switch (error.statusCode) {
      401 || 403 => texts.remoteCredentialsRejected,
      404 => texts.remoteLocationMissing,
      _ => texts.remoteOperationFailedHint,
    };
  }
  final message = error is FormatException
      ? error.message
      : error is StateError
      ? error.message
      : '$error';
  // Localized validation messages keep their actionable wording. Technical
  // exceptions remain available through Details instead of becoming UI copy.
  if (error is String || RegExp(r'[\u4e00-\u9fff]').hasMatch(message)) {
    return message;
  }
  return error is FormatException
      ? texts.invalidInputHint
      : texts.operationFailedDetails;
}

void showAppError(BuildContext context, Object error) {
  final text = appErrorText(context, error);
  final details = '$error';
  showAppFeedback(
    context,
    text,
    level: error is TaskCancelled ? MessageLevel.info : MessageLevel.error,
    actionState: error is TaskCancelled || text == details
        ? null
        : MessageActionState(
            actionText: context.l10n.details,
            action: () => AppDialogs.alert(
              context,
              title: context.l10n.operationFailed,
              message: details,
            ),
          ),
  );
}

class _MessageEntry {
  const _MessageEntry({
    required this.message,
    required this.visible,
    this.swiped = false,
  });

  final CommonMessage message;
  final bool visible;
  final bool swiped;

  String get id => message.id;

  _MessageEntry copyWith({
    CommonMessage? message,
    bool? visible,
    bool? swiped,
  }) => _MessageEntry(
    message: message ?? this.message,
    visible: visible ?? this.visible,
    swiped: swiped ?? this.swiped,
  );
}

class _MessageTransition extends StatefulWidget {
  const _MessageTransition({
    super.key,
    required this.visible,
    required this.swiped,
    required this.onHidden,
    required this.child,
  });

  final bool visible;
  final bool swiped;
  final VoidCallback onHidden;
  final Widget child;

  @override
  State<_MessageTransition> createState() => _MessageTransitionState();
}

class _MessageTransitionState extends State<_MessageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _size;
  late final CurvedAnimation _opacity;
  late final CurvedAnimation _settle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _messageEnterDuration,
      reverseDuration: _messageExitDuration,
      vsync: this,
    )..addStatusListener(_handleAnimationStatus);
    _size = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .8, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0, .6, curve: Curves.easeInCubic),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .5, curve: Curves.easeOut),
      reverseCurve: const Interval(.5, 1, curve: Curves.easeIn),
    );
    _settle = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: const Interval(.4, 1, curve: Curves.easeInCubic),
    );
    if (widget.visible) {
      _controller.forward();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.visible) widget.onHidden();
    });
  }

  @override
  void didUpdateWidget(_MessageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _controller.forward();
      return;
    }
    if (widget.swiped) {
      _size.reverseCurve = Curves.easeInCubic;
      _controller.reverseDuration = _messageCollapseDuration;
    }
    _controller.reverse();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && !widget.visible) {
      widget.onHidden();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _size.dispose();
    _opacity.dispose();
    _settle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) {
      final settle = widget.swiped ? 1.0 : _settle.value;
      return Align(
        alignment: AlignmentDirectional.topEnd,
        widthFactor: 1,
        heightFactor: _size.value,
        child: Transform.translate(
          offset: Offset(0, _messageEnterShift * (1 - settle)),
          child: Transform.scale(
            scale: _messageEnterScale + (1 - _messageEnterScale) * settle,
            child: child,
          ),
        ),
      );
    },
    child: FadeTransition(
      opacity: _opacity,
      child: IgnorePointer(ignoring: !widget.visible, child: widget.child),
    ),
  );
}

class _MessageCard extends StatefulWidget {
  const _MessageCard({
    required this.message,
    required this.onDismiss,
    required this.onDragging,
  });

  final CommonMessage message;
  final void Function(String id, {bool swiped}) onDismiss;
  final void Function(String id, bool dragging) onDragging;

  @override
  State<_MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<_MessageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );
  double _width = 0;
  bool _leaving = false;

  String get _id => widget.message.id;

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    if (_leaving) return;
    _width = context.size?.width ?? 0;
    _drag.stop();
    widget.onDragging(_id, true);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_leaving) _drag.value += details.primaryDelta ?? 0;
  }

  Future<void> _release(double velocity) async {
    if (_leaving) return;
    final offset = _drag.value;
    final flung =
        velocity.abs() >= _swipeDismissVelocity && velocity.sign == offset.sign;
    if (_width > 0 &&
        (flung || offset.abs() >= _width * _swipeDismissFraction)) {
      _leaving = true;
      await _drag.animateTo(
        offset.sign * math.max(_width, offset.abs()),
        duration: _messageSwipeOutDuration,
        curve: Curves.easeOut,
      );
      if (mounted) widget.onDismiss(_id, swiped: true);
      return;
    }
    widget.onDragging(_id, false);
    _drag.animateTo(
      0,
      duration: _messageSwipeBackDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 8),
      child: AnimatedBuilder(
        animation: _drag,
        builder: (_, child) {
          final offset = _drag.value;
          final progress = _width > 0 ? offset.abs() / _width : 0.0;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Opacity(opacity: 1 - progress.clamp(0.0, 1.0), child: child),
          );
        },
        child: GestureDetector(
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: (details) =>
              _release(details.primaryVelocity ?? 0),
          onHorizontalDragCancel: () => _release(0),
          child: Material(
            color: message.level.containerColor(context),
            surfaceTintColor: Colors.transparent,
            shadowColor: colorScheme.shadow.withValues(alpha: .6),
            elevation: 3,
            shape: AppShape.lg,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _messageMinHeight,
                maxWidth: _messageMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: SurfaceScope(
                  level: SurfaceLevel.floatingOf(colorScheme),
                  child: _MessageContent(
                    message: message,
                    onDismiss: widget.onDismiss,
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

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.onDismiss});

  final CommonMessage message;
  final void Function(String id, {bool swiped}) onDismiss;

  @override
  Widget build(BuildContext context) {
    final actionState = message.actionState;
    final level = message.level;
    final glyph = level.glyph;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph != null) ...[
          GlyphIcon(glyph, size: 20, color: level.iconColor(context)),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            message.text,
            maxLines: 3,
            style: AppTextStyle.subheadline
                .of(context, emphasized: true)
                .copyWith(color: level.contentColor(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionState != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              onDismiss(message.id);
              actionState.action();
            },
            child: Text(actionState.actionText),
          ),
        ],
      ],
    );
  }
}
