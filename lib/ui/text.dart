// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:emoji_regex/emoji_regex.dart';
import 'package:flutter/material.dart';
import 'card.dart';
import 'effect.dart';
import 'measure.dart';
import 'shape.dart';
import 'text_style.dart';
import 'typography.dart';

class CommonTooltip extends StatelessWidget {
  const CommonTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    waitDuration: const Duration(milliseconds: 450),
    preferBelow: false,
    child: child,
  );
}

class TooltipText extends StatelessWidget {
  const TooltipText({super.key, required this.text});

  final Text text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflow = MeasureScope.of(
          context,
        ).computeTextIsOverflow(text, maxWidth: constraints.maxWidth);
        if (!overflow) {
          return text;
        }
        return Tooltip(
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: false,
          message: text.data,
          child: text,
        );
      },
    );
  }
}

class TooltipLabel extends StatelessWidget {
  const TooltipLabel(this.text, {super.key, this.style, this.maxLines = 2});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TooltipText(
    text: Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
  );
}

class ExpandableText extends StatefulWidget {
  const ExpandableText({
    super.key,
    required this.text,
    required this.expandLabel,
    required this.collapseLabel,
    this.collapsedLines = 5,
    this.style,
  });

  final String text;
  final String expandLabel;
  final String collapseLabel;
  final int collapsedLines;
  final TextStyle? style;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? AppTextStyle.subheadline.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectionArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Text(
                  widget.text,
                  maxLines: _expanded ? null : widget.collapsedLines,
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            if (overflows)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Semantics(
                  button: true,
                  expanded: _expanded,
                  child: Material(
                    type: MaterialType.transparency,
                    shape: AppShape.full,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: AppShape.full,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded
                                  ? widget.collapseLabel
                                  : widget.expandLabel,
                              style: AppTextStyle.subheadline
                                  .of(context, emphasized: true)
                                  .copyWith(color: colorScheme.primary),
                            ),
                            const SizedBox(width: 4),
                            CommonExpandIcon(expand: _expanded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ExpandableTextCard extends StatelessWidget {
  const ExpandableTextCard({
    super.key,
    required this.title,
    required this.text,
    required this.expandLabel,
    required this.collapseLabel,
    this.collapsedLines = 6,
  });

  final String title;
  final String text;
  final String expandLabel;
  final String collapseLabel;
  final int collapsedLines;

  @override
  Widget build(BuildContext context) => CommonCard(
    inert: true,
    radius: AppCorner.xl,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyle.headline.of(context)),
        const SizedBox(height: 8),
        ExpandableText(
          text: text,
          expandLabel: expandLabel,
          collapseLabel: collapseLabel,
          collapsedLines: collapsedLines,
        ),
      ],
    ),
  );
}

class EmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const EmojiText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.style,
  });

  /// The spans [EmojiText] lays [text] out in, emoji in their own font.
  static TextSpan spanOf(String text, TextStyle? style) {
    final List<TextSpan> spans = [];
    final matches = emojiRegex().allMatches(text);

    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: (style ?? const TextStyle()).copyWith(
            fontFamily: FontFamily.twEmoji.value,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }

    return TextSpan(children: spans);
  }

  /// The width [EmojiText] lays [text] out at on one line under [style].
  static double widthOf(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        style: MediaQuery.boldTextOf(context)
            ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
            : style,
        children: [spanOf(text, null)],
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    try {
      return painter.maxIntrinsicWidth;
    } finally {
      painter.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      spanOf(text, style),
      style: style,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
