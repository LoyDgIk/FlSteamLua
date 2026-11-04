// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Focus and input-limit adapters reduced for FlSteamLua.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'icons/icons.dart';
import 'localization.dart';
import 'shape.dart';
import 'typography.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.height,
    this.fill,
    this.glyph = AppGlyphs.search,
    this.hintText,
    this.trailing,
    this.onSubmitted,
  });

  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final double? height;
  final Color? fill;
  final Glyph glyph;
  final String? hintText;
  final Widget? trailing;
  final VoidCallback? onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  TextEditingController? _ownedController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pill = AppShape.input.copyWith(borderRadius: AppRadius.full);
    return ListenableBuilder(
      listenable: _controller,
      builder: (_, _) {
        final empty = _controller.text.isEmpty;
        final trailing = widget.trailing;
        return TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          maxLines: 1,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          style: AppTextStyle.body.of(context),
          onChanged: widget.onChanged,
          onSubmitted: (_) => widget.onSubmitted?.call(),
          decoration: InputDecoration(
            constraints: BoxConstraints.tightFor(height: widget.height ?? 44),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: widget.fill != null,
            fillColor: widget.fill,
            hintText: widget.hintText ?? context.l10n.search,
            border: pill.copyWith(borderSide: BorderSide.none),
            enabledBorder: pill.copyWith(borderSide: BorderSide.none),
            focusedBorder: pill.copyWith(borderSide: BorderSide.none),
            contentPadding: EdgeInsetsDirectional.only(
              end: empty && trailing == null ? 12 : 0,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: GlyphIcon(widget.glyph, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints.tightFor(width: 41),
            suffixIcon: empty && trailing == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ?trailing,
                      if (!empty)
                        SizedBox(
                          width: 49,
                          child: IconButton(
                            tooltip: context.l10n.clear,
                            onPressed: _clear,
                            style: IconButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              overlayColor: Colors.transparent,
                              splashFactory: NoSplash.splashFactory,
                            ),
                            icon: const GlyphIcon(
                              AppGlyphs.clearField,
                              size: 24,
                              fill: 1,
                            ),
                          ),
                        ),
                      if (empty) const SizedBox(width: 8),
                    ],
                  ),
            suffixIconConstraints: const BoxConstraints(),
          ),
        );
      },
    );
  }
}
