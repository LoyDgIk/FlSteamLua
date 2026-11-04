// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import 'context.dart';
import 'dashboard_card.dart' show ShapeBadge;
import 'icons/icons.dart';
import 'loading.dart';
import 'typography.dart';

enum NullStatusIllustration { data, search, lua, steam, achievement, error }

class NullStatusSwitcher extends StatelessWidget {
  const NullStatusSwitcher({
    super.key,
    this.isLoading = false,
    this.isEmpty = false,
    this.isSearching = false,
    this.nullStatus,
    this.searchStatus,
    required this.child,
  });

  final bool isLoading;
  final bool isEmpty;
  final bool isSearching;
  final NullStatus? nullStatus;
  final NullStatus? searchStatus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slot = isLoading
        ? 'loading'
        : !isEmpty
        ? 'content'
        : isSearching
        ? 'search'
        : 'empty';
    final duration = context.motionDuration(const Duration(milliseconds: 280));
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(Tween(begin: .94, end: 1.0)),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(slot),
        child: switch (slot) {
          'loading' => const Center(child: CommonCircleLoading.page()),
          'search' => searchStatus ?? const SizedBox.expand(),
          'empty' => nullStatus ?? const SizedBox.expand(),
          _ => child,
        },
      ),
    );
  }
}

class NullStatus extends StatefulWidget {
  const NullStatus({
    super.key,
    this.label,
    this.description,
    this.action,
    this.illustration = NullStatusIllustration.data,
    this.scrollable = true,
  });

  final String? label;
  final String? description;
  final Widget? action;
  final NullStatusIllustration illustration;
  final bool scrollable;

  @override
  State<NullStatus> createState() => _NullStatusState();
}

class _NullStatusState extends State<NullStatus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isDismissed && !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: const Interval(0, .75, curve: Curves.easeOut),
            ),
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: const Interval(0, .8, curve: Curves.easeOutBack),
              ),
              child: _illustration(context),
            ),
          ),
          if (widget.label case final label?) ...[
            const SizedBox(height: 18),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: const Interval(.2, .85, curve: Curves.easeOut),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyle.headline.of(context),
              ),
            ),
          ],
          if (widget.description case final description?) ...[
            const SizedBox(height: 8),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: const Interval(.32, 1, curve: Curves.easeOut),
              ),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
          if (widget.action case final action?) ...[
            const SizedBox(height: 24),
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: const Interval(.45, 1, curve: Curves.easeOut),
              ),
              child: action,
            ),
          ],
        ],
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    return Align(
      alignment: const Alignment(0, -.18),
      child: widget.scrollable
          ? SingleChildScrollView(padding: padding, child: content)
          : Padding(padding: padding, child: content),
    );
  }

  Widget _illustration(BuildContext context) {
    final (shape, glyph) = switch (widget.illustration) {
      NullStatusIllustration.data => (
        MaterialShapes.cookie12Sided,
        AppGlyphs.resources,
      ),
      NullStatusIllustration.search => (
        MaterialShapes.flower,
        AppGlyphs.search,
      ),
      NullStatusIllustration.lua => (
        MaterialShapes.cookie6Sided,
        AppGlyphs.code,
      ),
      NullStatusIllustration.steam => (
        MaterialShapes.sunny,
        AppGlyphs.profiles,
      ),
      NullStatusIllustration.achievement => (
        MaterialShapes.cookie9Sided,
        AppGlyphs.star,
      ),
      NullStatusIllustration.error => (
        MaterialShapes.softBurst,
        AppGlyphs.error,
      ),
    };
    return ShapeBadge(
      shape: shape,
      color: context.colorScheme.primaryContainer,
      size: 156,
      rotation: .08,
      child: GlyphIcon(
        glyph,
        size: 54,
        fill: .12,
        color: context.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
