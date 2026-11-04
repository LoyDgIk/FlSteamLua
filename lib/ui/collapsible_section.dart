// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// The box adapter reuses the same header and unfold motion.
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'context.dart';
import 'icons/icons.dart';
import 'inherited.dart';
import 'item_position.dart';
import 'loading.dart';
import 'shape.dart';
import 'surface.dart';
import 'typography.dart';

class SliverCollapsibleSection extends StatefulWidget {
  const SliverCollapsibleSection({
    super.key,
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.showCount = true,
    this.headerStyle,
  });

  final String label;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool showCount;
  final TextStyle? headerStyle;

  @override
  State<SliverCollapsibleSection> createState() =>
      _SliverCollapsibleSectionState();
}

class _SliverCollapsibleSectionState extends State<SliverCollapsibleSection>
    with SingleTickerProviderStateMixin {
  static const _estimatedEntryExtent = 64.0;

  late var _expanded = widget.initiallyExpanded;
  late final _controller = AnimationController(
    vsync: this,
    duration: UnfoldEntryTransition.duration,
    value: _isOpen(widget.collapsible) ? 1 : 0,
  );
  late final _size = UnfoldEntryTransition.curveOf(_controller);
  late final _turns = Tween<double>(begin: -.25, end: 0).animate(_size);
  late final _headerActions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => _handleToggle(),
    ),
  };
  var _headerFocused = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((_) => setState(() {}));
  }

  bool _isOpen(bool collapsible) => _expanded || !collapsible;

  void _animate() {
    _isOpen(widget.collapsible) ? _controller.forward() : _controller.reverse();
  }

  void _handleToggle() {
    setState(() => _expanded = !_expanded);
    _animate();
  }

  @override
  void didUpdateWidget(SliverCollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen(oldWidget.collapsible) != _isOpen(widget.collapsible)) {
      _animate();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _visibleCountOf(int count) {
    final fitting = MediaQuery.sizeOf(context).height / _estimatedEntryExtent;
    return math.min(count.toDouble(), fitting);
  }

  int _unfoldingCount(int count) {
    final fitting =
        MediaQuery.sizeOf(context).height ~/ kMinInteractiveDimension + 1;
    return math.min(count, fitting);
  }

  Widget _buildEntry(BuildContext context, int index) => ItemPositionProvider(
    position: ItemPosition.get(index, widget.itemCount),
    child: widget.itemBuilder(context, index),
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount;
    final visible = _visibleCountOf(count);
    final unfolding = _unfoldingCount(count);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _CollapsibleHeader(
            label: widget.label,
            itemCount: count,
            showCount: widget.showCount,
            headerStyle: widget.headerStyle,
            collapsible: widget.collapsible,
            expanded: _expanded,
            turns: _turns,
            focused: _headerFocused,
            actions: _headerActions,
            onFocusHighlight: (value) => setState(() => _headerFocused = value),
            onToggle: _handleToggle,
          ),
        ),
        if (_controller.isCompleted)
          SliverList.builder(itemCount: count, itemBuilder: _buildEntry)
        else if (!_controller.isDismissed)
          SliverToBoxAdapter(
            child: SizeTransition(
              sizeFactor: _size,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (var index = 0; index < unfolding; index++)
                    UnfoldEntryTransition(
                      animation: _size,
                      index: index,
                      visibleCount: visible,
                      child: _buildEntry(context, index),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The same folded section in a box so pages with an ordinary [ListView] can
/// use FlClash's header and unfold motion without changing their scroll model.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.label,
    required this.itemCount,
    required this.itemBuilder,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.loading = false,
    this.onExpandedChanged,
    this.showCount = true,
    this.headerStyle,
  });

  final String label;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool loading;
  final ValueChanged<bool>? onExpandedChanged;
  final bool showCount;
  final TextStyle? headerStyle;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  static const _estimatedEntryExtent = 64.0;

  late var _expanded = widget.initiallyExpanded;
  late final _controller = AnimationController(
    vsync: this,
    duration: UnfoldEntryTransition.duration,
    value: _isOpen(widget.collapsible) ? 1 : 0,
  );
  late final _size = UnfoldEntryTransition.curveOf(_controller);
  late final _turns = Tween<double>(begin: -.25, end: 0).animate(_size);
  late final _headerActions = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => _handleToggle(),
    ),
  };
  var _headerFocused = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((_) => setState(() {}));
  }

  bool _isOpen(bool collapsible) => _expanded || !collapsible;

  void _animate() {
    _isOpen(widget.collapsible) ? _controller.forward() : _controller.reverse();
  }

  void _handleToggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
    _animate();
  }

  @override
  void didUpdateWidget(CollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen(oldWidget.collapsible) != _isOpen(widget.collapsible)) {
      _animate();
    }
  }

  @override
  void dispose() {
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _visibleCountOf(int count) {
    final fitting = MediaQuery.sizeOf(context).height / _estimatedEntryExtent;
    return math.min(count.toDouble(), fitting);
  }

  int _unfoldingCount(int count) {
    final fitting =
        MediaQuery.sizeOf(context).height ~/ kMinInteractiveDimension + 1;
    return math.min(count, fitting);
  }

  Widget _buildEntry(BuildContext context, int index) => ItemPositionProvider(
    position: ItemPosition.get(index, widget.itemCount),
    child: widget.itemBuilder(context, index),
  );

  @override
  Widget build(BuildContext context) {
    final count = widget.itemCount;
    final visible = _visibleCountOf(count);
    final unfolding = _unfoldingCount(count);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CollapsibleHeader(
          label: widget.label,
          itemCount: count,
          showCount: widget.showCount,
          headerStyle: widget.headerStyle,
          collapsible: widget.collapsible,
          expanded: _expanded,
          turns: _turns,
          focused: _headerFocused,
          actions: _headerActions,
          loading: widget.loading,
          onFocusHighlight: (value) => setState(() => _headerFocused = value),
          onToggle: _handleToggle,
        ),
        AnimatedSize(
          duration: widget.loading
              ? context.motionDuration(UnfoldEntryTransition.duration)
              : UnfoldEntryTransition.duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _controller.isDismissed
              ? const SizedBox(width: double.infinity)
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < (_controller.isCompleted ? count : unfolding);
                      index++
                    )
                      UnfoldEntryTransition(
                        animation: _size,
                        index: index,
                        visibleCount: visible,
                        child: _buildEntry(context, index),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CollapsibleHeader extends StatelessWidget {
  const _CollapsibleHeader({
    required this.label,
    required this.itemCount,
    required this.showCount,
    required this.headerStyle,
    required this.collapsible,
    required this.expanded,
    required this.turns,
    required this.focused,
    required this.actions,
    required this.onFocusHighlight,
    required this.onToggle,
    this.loading = false,
  });

  final String label;
  final int itemCount;
  final bool showCount;
  final TextStyle? headerStyle;
  final bool collapsible;
  final bool expanded;
  final Animation<double> turns;
  final bool focused;
  final Map<Type, Action<Intent>> actions;
  final ValueChanged<bool> onFocusHighlight;
  final VoidCallback onToggle;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final active = collapsible && focused;
    return FocusableActionDetector(
      enabled: collapsible,
      actions: actions,
      mouseCursor: collapsible ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: onFocusHighlight,
      child: Semantics(
        button: collapsible,
        expanded: collapsible ? expanded : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: collapsible ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: AppShape.md.copyWith(
                  side: active ? focusRingSide(colorScheme) : BorderSide.none,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: label),
                            if (showCount)
                              TextSpan(
                                text: ' ($itemCount)',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: headerStyle ?? AppTextStyle.headline.of(context),
                      ),
                    ),
                    if (loading) const CommonCircleLoading(size: 20),
                    RotationTransition(
                      turns: turns,
                      child: GlyphIcon(
                        AppGlyphs.chevronDown,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UnfoldEntryTransition extends StatelessWidget {
  const UnfoldEntryTransition({
    super.key,
    required this.animation,
    required this.index,
    required this.visibleCount,
    required this.child,
  });

  static const duration = Duration(milliseconds: 240);
  static const _fade = .5;

  final Animation<double> animation;
  final int index;
  final double visibleCount;
  final Widget child;

  static CurvedAnimation curveOf(AnimationController controller) =>
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

  @override
  Widget build(BuildContext context) {
    final half = visibleCount / 2;
    final distance = (half - index - .5).abs() / half;
    final start = math.min(1.0, distance) * (1 - _fade);
    return SlideTransition(
      position: animation.drive(
        Tween(begin: Offset(0, -index - .5), end: Offset.zero),
      ),
      child: FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: Interval(start, start + _fade)),
        ),
        child: child,
      ),
    );
  }
}
