// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'inherited.dart';

class CommonPopScope extends StatelessWidget {
  const CommonPopScope({
    super.key,
    required this.child,
    this.onPop,
    this.onPopSuccess,
  });

  final Widget child;
  final FutureOr<bool> Function(BuildContext context)? onPop;
  final FutureOr<void> Function()? onPopSuccess;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final hasBackLayer = route?.willHandlePopInternally == true;
    return PopScope(
      canPop: onPop == null || hasBackLayer,
      onPopInvokedWithResult: onPop == null
          ? null
          : (didPop, _) async {
              if (didPop) {
                return;
              }
              if (route?.willHandlePopInternally == true) {
                Navigator.of(context).pop();
                return;
              }
              if (!await onPop!(context) || !context.mounted) {
                return;
              }
              Navigator.of(context).pop();
              await onPopSuccess?.call();
            },
      child: child,
    );
  }
}

class BackLayerScope extends StatefulWidget {
  const BackLayerScope({
    super.key,
    required this.onBack,
    required this.child,
    @visibleForTesting this.schedulePostFrameCallback,
  });

  final Widget child;
  final VoidCallback onBack;
  @visibleForTesting
  final void Function(void Function(Duration) callback)?
  schedulePostFrameCallback;

  @override
  State<BackLayerScope> createState() => _BackLayerScopeState();
}

class _BackLayerScopeState extends State<BackLayerScope> {
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _entry;
  bool _isDetaching = false;
  bool _isPageActive = true;
  int _syncRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final isPageActive = PageActivityScope.isActiveOf(context);
    if (identical(_route, route) && _isPageActive == isPageActive) {
      return;
    }
    _detach();
    _route = route;
    _isPageActive = isPageActive;
    final revision = ++_syncRevision;
    final schedule =
        widget.schedulePostFrameCallback ??
        WidgetsBinding.instance.addPostFrameCallback;
    schedule((_) {
      if (!mounted || revision != _syncRevision) {
        return;
      }
      if (!_isPageActive) {
        widget.onBack();
        return;
      }
      if (route == null) {
        return;
      }
      final entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: _handleRemove,
      );
      _entry = entry;
      route.addLocalHistoryEntry(entry);
    });
  }

  void _handleRemove() {
    _entry = null;
    if (!_isDetaching && mounted) {
      widget.onBack();
    }
  }

  void _detach() {
    final entry = _entry;
    if (entry == null) {
      return;
    }
    _entry = null;
    _isDetaching = true;
    entry.remove();
    _isDetaching = false;
  }

  @override
  void dispose() {
    _syncRevision++;
    _detach();
    _route = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
