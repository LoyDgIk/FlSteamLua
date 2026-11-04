// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'context.dart';
import 'fade_box.dart';
import 'shape.dart';
import 'surface.dart';

const commonCardIconSize = 20.0;

class CommonCard extends StatelessWidget {
  const CommonCard({
    super.key,
    bool? isSelected,
    this.onPressed,
    this.radius,
    this.padding,
    this.enterAnimated = false,
    this.shape,
    this.isError = false,
    this.enterActionsOnRight = false,
    this.statesController,
    this.inert = false,
    this.fillsSelection = false,
    this.focusRing = true,
    required this.child,
  }) : isSelected = isSelected ?? false;

  /// Ignores presses in the enabled colors, so toggling it animates nothing.
  final bool inert;
  final bool enterAnimated;
  final bool enterActionsOnRight;

  /// A selected card keeps its fill unless [fillsSelection]; callers mark it.
  final bool isSelected;
  final bool fillsSelection;
  final bool isError;
  final bool focusRing;
  final void Function()? onPressed;
  final Widget child;
  final EdgeInsets? padding;
  final double? radius;
  final OutlinedBorder? shape;
  final WidgetStatesController? statesController;

  BorderSide _buildBorderSide(
    BuildContext context,
    Set<WidgetState> states, {
    required bool ringed,
  }) {
    if (!ringed || !focusRing || !states.contains(WidgetState.focused)) {
      return BorderSide.none;
    }
    final colorScheme = context.colorScheme;
    final side = focusRingSide(colorScheme);
    return isError ? side.copyWith(color: colorScheme.error) : side;
  }

  bool get _filled => isSelected && fillsSelection;

  Color _buildBackgroundColor(BuildContext context, SurfaceLevel level) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.errorContainer;
    }
    if (_filled) {
      return colorScheme.primary;
    }
    return level.colorOf(colorScheme);
  }

  Color _buildForegroundColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.onErrorContainer;
    }
    if (_filled) {
      return colorScheme.onPrimary;
    }
    return colorScheme.onSurfaceVariant;
  }

  Color _buildIconColor(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (isError) {
      return colorScheme.onErrorContainer;
    }
    if (_filled) {
      return colorScheme.onPrimary;
    }
    return colorScheme.primary;
  }

  Widget _buildButton(BuildContext context, SurfaceLevel level) {
    final iconColor = _buildIconColor(context);
    final foregroundColor = _buildForegroundColor(context);
    return FilledButton(
      statesController: statesController,
      clipBehavior: Clip.antiAlias,
      style:
          FilledButton.styleFrom(
            padding: padding ?? EdgeInsets.zero,
            shape: shape ?? AppShape.all(radius ?? AppCorner.md),
            iconSize: commonCardIconSize,
            iconColor: iconColor,
            foregroundColor: foregroundColor,
            disabledIconColor: inert ? iconColor : null,
            disabledForegroundColor: inert ? foregroundColor : null,
            elevation: 0,
          ).copyWith(
            backgroundColor: WidgetStatePropertyAll(
              _buildBackgroundColor(context, level),
            ),
            side: WidgetStateProperty.resolveWith(
              (states) => _buildBorderSide(context, states, ringed: true),
            ),
          ),
      onPressed: inert ? null : onPressed,
      child: Semantics(
        selected: isSelected ? true : null,
        child: SurfaceScope(level: level, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context, context.raisedSurfaceLevel);
    final card = !enterActionsOnRight
        ? button
        : Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent ||
                  event.logicalKey != LogicalKeyboardKey.arrowRight) {
                return KeyEventResult.ignored;
              }
              final focusNode = FocusManager.instance.primaryFocus;
              final context = focusNode?.context;
              if (focusNode == null || context == null) {
                return KeyEventResult.ignored;
              }
              final action = focusNode.descendants
                  .where((node) => node.skipTraversal && node.canRequestFocus)
                  .firstOrNull;
              if (action != null) {
                action.requestFocus();
                return KeyEventResult.handled;
              }
              if (focusNode.skipTraversal ||
                  context.findAncestorWidgetOfExactType<IconButton>() != null) {
                return KeyEventResult.ignored;
              }
              return focusNode.nextFocus()
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            },
            child: button,
          );

    return switch (enterAnimated) {
      true => FadeScaleEnterBox(child: card),
      false => card,
    };
  }
}

/// A focus node left out of the traversal that walks between cards: a card
/// that must not be a stop, or an action inside a card reached by arrow right.
class SkipTraversalFocusNode extends FocusNode {
  @override
  bool get skipTraversal => true;
}
