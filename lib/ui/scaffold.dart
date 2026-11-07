// FlClash's page frame reduced to the presentation API used by FlSteamLua.
// Source: 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'button.dart';
import 'context.dart';
import 'icons/icons.dart';
import 'loading.dart';
import 'metrics.dart';
import 'popup.dart';
import 'shape.dart';
import 'surface.dart';
import 'search_state.dart';
import 'toolbar_search.dart';
import 'typography.dart';

class CommonScaffold extends StatelessWidget {
  const CommonScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.titleMenuItems = const [],
    this.actions = const [],
    this.trailingAction,
    this.bottom,
    this.backgroundColor,
    this.backAction,
    this.isLoading = false,
    this.searchState,
    this.searchHint,
  }) : assert(title != null || titleWidget != null);

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<CommonPopupMenuItem> titleMenuItems;
  final List<Widget> actions;
  final Widget? trailingAction;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final VoidCallback? backAction;
  final bool isLoading;
  final AppBarSearchState? searchState;
  final String? searchHint;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final canGoBack =
        backAction != null || (route?.impliesAppBarDismissal ?? false);
    final pageColor =
        backgroundColor ?? SurfaceLevel.page.colorOf(context.colorScheme);
    final titleContent =
        titleWidget ??
        (titleMenuItems.isEmpty
            ? AnimatedSwitcher(
                duration: context.motionDuration(midDuration),
                child: Text(
                  title!,
                  key: ValueKey(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.pageTitle.of(context),
                ),
              )
            : CommonPopupBox(
                placement: PopupPlacement.overAnchorStart,
                targetBuilder: (open) =>
                    _TitleMenuButton(title: title!, onPressed: open),
                popupBuilder: (_) => CommonPopupMenu(items: titleMenuItems),
              ));
    return Scaffold(
      backgroundColor: pageColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                ?bottom,
                Expanded(child: body),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pageContentTopInset,
            child: IgnorePointer(
              child: _HeaderScrim(
                key: const ValueKey('common-scaffold-header-scrim'),
                color: pageColor,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: pageToolbarHeight,
            child: ToolbarSearchBar(
              title: titleContent,
              leading: canGoBack
                  ? BackButton(
                      onPressed:
                          backAction ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
              actions: actions,
              trailingAction: trailingAction,
              actionsBuilder: (actions) =>
                  CommonToolbarGroup(children: actions),
              searchState: searchState,
              searchHint: searchHint,
            ),
          ),
          if (isLoading)
            const Positioned(
              top: pageToolbarHeight,
              left: 0,
              right: 0,
              child: CommonProgressBar(value: null, height: 2),
            ),
        ],
      ),
    );
  }
}

class _TitleMenuButton extends StatelessWidget {
  const _TitleMenuButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('scaffold-title-menu'),
    onTap: onPressed,
    customBorder: AppShape.sm,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.pageTitle.of(context),
          ),
        ),
        GlyphIcon(
          AppGlyphs.chevronDown,
          size: 20,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ],
    ),
  );
}

class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim({super.key, required this.color});

  static const _alpha = .9;
  static const _fadeSteps = 8;

  final Color color;

  @override
  Widget build(BuildContext context) {
    const start = .5;
    final stops = <double>[0];
    final colors = <Color>[color.withValues(alpha: _alpha)];
    for (var i = 0; i <= _fadeSteps; i++) {
      final t = i / _fadeSteps;
      stops.add(start + (1 - start) * t);
      colors.add(
        color.withValues(alpha: _alpha * (1 - Curves.easeInOut.transform(t))),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: stops,
          colors: colors,
        ),
      ),
    );
  }
}

class CommonToolbarGroup extends StatelessWidget {
  const CommonToolbarGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => TonalButtonGroup(children: children);
}
