// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'context.dart';
import 'icons/icons.dart';
import 'list.dart';
import 'localization.dart';
import 'metrics.dart';
import 'popup.dart';
import 'text.dart';
import 'typography.dart';

class FormRow extends StatelessWidget {
  static const _spacing = 16.0;
  static const _titleMaxLines = 2;
  static const _titleMaxWidthFactor = 0.5;

  const FormRow({
    super.key,
    required this.title,
    this.titleStyle,
    this.leading,
    this.trailing,
    this.invalid = false,
    this.onPressed,
  });

  final String title;
  final TextStyle? titleStyle;
  final Widget? leading;
  final Widget? trailing;
  final bool invalid;
  final VoidCallback? onPressed;

  Widget _buildTitle(double maxWidth) {
    final text = TooltipLabel(
      title,
      maxLines: _titleMaxLines,
      style: titleStyle,
    );
    if (trailing == null) {
      return Flexible(child: text);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (maxWidth - _spacing) * _titleMaxWidthFactor,
      ),
      child: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      invalid: invalid,
      onPressed: onPressed,
      focusRing: false,
      minVerticalPadding: trailing == null ? null : 0,
      leading: leading,
      title: LayoutBuilder(
        builder: (context, constraints) => Row(
          spacing: _spacing,
          children: [
            _buildTitle(constraints.maxWidth),
            if (trailing != null)
              Flexible(
                child: IconTheme(
                  data: IconThemeData(
                    size: 16.ap(context),
                    color: context.colorScheme.onSurfaceVariant.withValues(
                      alpha: .6,
                    ),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: trailing!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A bare text field set against the end of a [FormRow], as iOS and macOS set
/// one in a grouped form; the row's focus ring is the only outline it gets.
class FormRowTextField extends StatelessWidget {
  static const _cursorWidth = 2.0;
  static const _caretMargin = 1 + _cursorWidth;

  const FormRowTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onFieldSubmitted,
  }) : assert(controller == null || initialValue == null);

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final towardEnd = switch (Directionality.of(context)) {
      TextDirection.ltr => 1.0,
      TextDirection.rtl => -1.0,
    };
    return InputDecorationTheme(
      data: InputDecorationTheme.of(
        context,
      ).copyWith(floatingLabelBehavior: FloatingLabelBehavior.never),
      child: Transform.translate(
        offset: Offset(_caretMargin * towardEnd, 0),
        child: _buildField(context),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    final hintText = this.hintText;
    final decoration =
        InputDecoration.collapsed(
          border: const _NoInputBorder(),
          hintText: null,
          hint: hintText == null
              ? null
              : Padding(
                  padding: const EdgeInsetsDirectional.only(end: _caretMargin),
                  child: Text(
                    hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppTextStyle.body
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ),
        ).copyWith(
          enabledBorder: const _NoInputBorder(),
          focusedBorder: const _NoInputBorder(),
          disabledBorder: const _NoInputBorder(),
          errorBorder: const _NoInputBorder(),
          focusedErrorBorder: const _NoInputBorder(),
        );
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enabled: enabled,
      maxLines: maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textAlign: TextAlign.end,
      cursorWidth: _cursorWidth,
      style: AppTextStyle.body
          .of(context)
          .copyWith(
            color: enabled
                ? context.colorScheme.onSurfaceVariant
                : context.colorScheme.onSurface.withValues(alpha: .38),
          ),
      decoration: decoration,
    );
  }
}

/// A [FormRowTextField] for a secret, with the button that shows it.
class FormRowSecretTextField extends StatefulWidget {
  const FormRowSecretTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<FormRowSecretTextField> createState() => _FormRowSecretTextFieldState();
}

class _FormRowSecretTextFieldState extends State<FormRowSecretTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FormRowTextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            hintText: widget.hintText,
            keyboardType: widget.keyboardType,
            obscureText: _obscure,
            textInputAction: widget.textInputAction,
            autocorrect: false,
            enableSuggestions: false,
            enabled: widget.enabled,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
          ),
        ),
        IconButton(
          tooltip: _obscure
              ? context.l10n.showPassword
              : context.l10n.hidePassword,
          onPressed: widget.enabled
              ? () {
                  setState(() {
                    _obscure = !_obscure;
                  });
                }
              : null,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(40),
            fixedSize: const Size.square(40),
            padding: EdgeInsets.zero,
          ),
          icon: GlyphIcon(_obscure ? AppGlyphs.eye : AppGlyphs.eyeOff),
        ),
      ],
    );
  }
}

class FormRowSelect<T> extends StatelessWidget {
  const FormRowSelect({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final T? value;
  final List<(T?, String)> options;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = options
        .where((option) => option.$1 == value)
        .map((option) => option.$2)
        .firstOrNull;
    final active = enabled && onChanged != null;
    PopupOpen? openMenu;
    return FormRow(
      title: title,
      onPressed: active ? () => openMenu?.call() : null,
      trailing: CommonPopupBox(
        popupBuilder: (_) => CommonPopupMenu(
          items: [
            for (final option in options)
              CommonPopupMenuItem(
                label: option.$2,
                checked: option.$1 == value,
                onPressed: () => onChanged?.call(option.$1),
              ),
          ],
        ),
        targetBuilder: (open) {
          openMenu = open;
          return TextButton(
            onPressed: active ? open : null,
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.onSurfaceVariant,
              textStyle: context.listTitleStyle,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: PopupValueText(
                    current ?? '',
                    alignment: AlignmentDirectional.centerEnd,
                  ),
                ),
                const GlyphIcon(AppGlyphs.picker),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoInputBorder extends InputBorder {
  const _NoInputBorder() : super(borderSide: BorderSide.none);

  @override
  _NoInputBorder copyWith({BorderSide? borderSide}) => const _NoInputBorder();

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  _NoInputBorder scale(double t) => const _NoInputBorder();

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawRect(rect, paint);
  }

  @override
  bool get preferPaintInterior => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {}
}
