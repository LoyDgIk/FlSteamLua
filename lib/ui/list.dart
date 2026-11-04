// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Desktop grouped-row adapter. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'card.dart';
import 'context.dart';
import 'dialog.dart';
import 'icons/icons.dart';
import 'inherited.dart';
import 'input.dart';
import 'item_position.dart';
import 'metrics.dart';
import 'popup.dart';
import 'shape.dart';
import 'switch.dart';
import 'typography.dart';

part 'list_selected.dart';
part 'list_row_separator.dart';

sealed class _ListItemAction {
  const _ListItemAction();
}

final class _DefaultAction extends _ListItemAction {
  const _DefaultAction();
}

final class _ToggleAction extends _ListItemAction {
  const _ToggleAction({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;
}

final class _CheckboxAction extends _ListItemAction {
  const _CheckboxAction({required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;
}

final class _OptionsAction<T> extends _ListItemAction {
  const _OptionsAction({
    required this.options,
    required this.value,
    required this.textBuilder,
    required this.onChanged,
  });

  final List<T> options;
  final T value;
  final String Function(T value) textBuilder;
  final ValueChanged<T>? onChanged;
}

final class _InputAction extends _ListItemAction {
  const _InputAction({
    required this.title,
    required this.value,
    this.suffixText,
    this.resetValue,
    this.validator,
    this.maxLength,
    this.inputFormatters,
    this.keyboardType,
    required this.onChanged,
  });

  final String title;
  final String value;
  final String? suffixText;
  final String? resetValue;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final ValueChanged<String?>? onChanged;
}

/// FlClash's ordinary row; grouped rows retain its shared surface and separator.
class ListItem<T> extends StatelessWidget {
  const ListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.horizontalTitleGap,
    this.color,
    this.minTileHeight,
    this.minVerticalPadding = listRowVerticalPadding,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = const _DefaultAction();

  ListItem.toggle({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    required bool value,
    ValueChanged<bool>? onChanged,
    this.horizontalTitleGap,
    this.color,
    this.minTileHeight,
    this.minVerticalPadding = listRowVerticalPadding,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _ToggleAction(value: value, onChanged: onChanged),
       trailing = null,
       onTap = null;

  ListItem.checkbox({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    bool value = false,
    ValueChanged<bool?>? onChanged,
    this.horizontalTitleGap,
    this.color,
    this.minTileHeight,
    this.minVerticalPadding = listRowVerticalPadding,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _CheckboxAction(value: value, onChanged: onChanged),
       trailing = null,
       onTap = null;

  ListItem.options({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.only(left: 16, right: 8),
    required List<T> options,
    required T value,
    required String Function(T value) textBuilder,
    ValueChanged<T>? onChanged,
    this.horizontalTitleGap,
    this.color,
    this.minTileHeight,
    this.minVerticalPadding = listRowVerticalPadding,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _OptionsAction<T>(
         options: options,
         value: value,
         textBuilder: textBuilder,
         onChanged: onChanged,
       ),
       trailing = null,
       onTap = null;

  ListItem.input({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.trailing,
    required String dialogTitle,
    required String value,
    String? suffixText,
    String? resetValue,
    FormFieldValidator<String>? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    ValueChanged<String?>? onChanged,
    this.horizontalTitleGap,
    this.color,
    this.minTileHeight,
    this.minVerticalPadding = listRowVerticalPadding,
    this.tileTitleAlignment = ListTileTitleAlignment.center,
  }) : _action = _InputAction(
         title: dialogTitle,
         value: value,
         suffixText: suffixText,
         resetValue: resetValue,
         validator: validator,
         maxLength: maxLength,
         inputFormatters: inputFormatters,
         keyboardType: keyboardType,
         onChanged: onChanged,
       ),
       onTap = null;

  final _ListItemAction _action;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double? horizontalTitleGap;
  final Color? color;
  final double? minTileHeight;
  final double minVerticalPadding;
  final ListTileTitleAlignment tileTitleAlignment;

  Widget _buildRow(
    BuildContext context, {
    VoidCallback? onPressed,
    Widget? trailing,
    Widget? leading,
  }) {
    return DecorationListItem(
      title: title,
      subtitle: subtitle,
      leading: leading ?? this.leading,
      trailing: trailing ?? this.trailing,
      onPressed: onPressed,
      contentPadding: padding,
      horizontalTitleGap: horizontalTitleGap,
      minVerticalPadding: minVerticalPadding,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required VoidCallback? onPressed,
    Widget? trailing,
  }) {
    final effectiveTrailing = trailing ?? this.trailing;
    if (ItemPositionProvider.of(context) != null) {
      return _buildRow(
        context,
        onPressed: onPressed,
        trailing: effectiveTrailing,
      );
    }
    return ListTile(
      key: key,
      tileColor: color,
      titleTextStyle: context.listTitleStyle,
      subtitleTextStyle: context.listSubtitleStyle,
      leading: leading,
      horizontalTitleGap: horizontalTitleGap,
      title: title,
      minTileHeight: minTileHeight ?? listRowMinHeight,
      minVerticalPadding: minVerticalPadding,
      subtitle: subtitle,
      titleAlignment: tileTitleAlignment,
      onTap: onPressed,
      trailing: effectiveTrailing,
      contentPadding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_action) {
      case _DefaultAction():
        return _buildContent(context, onPressed: onTap);
      case final _ToggleAction action:
        final enabled = action.onChanged != null;
        return _buildContent(
          context,
          onPressed: enabled ? () => action.onChanged!(!action.value) : null,
          trailing: CommonSwitch(
            value: action.value,
            onChanged: action.onChanged,
          ),
        );
      case final _CheckboxAction action:
        final enabled = action.onChanged != null;
        return _buildContent(
          context,
          onPressed: enabled ? () => action.onChanged!(!action.value) : null,
          trailing: CommonCheckBox(
            value: action.value,
            onChanged: action.onChanged,
          ),
        );
      case final _OptionsAction action:
        final options = action as _OptionsAction<T>;
        PopupOpen? openMenu;
        return _buildContent(
          context,
          onPressed: options.onChanged == null ? null : () => openMenu?.call(),
          trailing: CommonPopupBox(
            targetBuilder: (open) {
              openMenu = open;
              return _OptionsValueButton(
                label: options.textBuilder(options.value),
                onPressed: options.onChanged == null ? null : open,
              );
            },
            popupBuilder: (_) => CommonPopupMenu(
              items: [
                for (final option in options.options)
                  CommonPopupMenuItem(
                    label: options.textBuilder(option),
                    checked: option == options.value,
                    onPressed: () => options.onChanged?.call(option),
                  ),
              ],
            ),
          ),
        );
      case final _InputAction action:
        return _buildContent(
          context,
          onPressed: action.onChanged == null
              ? null
              : () async {
                  final value = await showFlDialog<String>(
                    context: Navigator.of(context, rootNavigator: true).context,
                    builder: (_) => InputDialog(
                      title: action.title,
                      value: action.value,
                      suffixText: action.suffixText,
                      resetValue: action.resetValue,
                      validator: action.validator,
                      maxLength: action.maxLength,
                      inputFormatters: action.inputFormatters,
                      keyboardType: action.keyboardType,
                    ),
                  );
                  action.onChanged!(value);
                },
        );
    }
  }
}

class _OptionsValueButton extends StatelessWidget {
  const _OptionsValueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
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
              label,
              alignment: AlignmentDirectional.centerEnd,
            ),
          ),
          const GlyphIcon(AppGlyphs.picker),
        ],
      ),
    );
  }
}

class CommonCheckBox extends StatelessWidget {
  const CommonCheckBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.isCircle = false,
  });
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool isCircle;
  @override
  Widget build(BuildContext context) => Checkbox(
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    shape: isCircle ? AppShape.circle : null,
    value: value,
    onChanged: onChanged,
  );
}

Widget generateGroup(Iterable<Widget> items) {
  final rows = items.toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, item) in rows.indexed)
        ItemPositionProvider(
          position: ItemPosition.get(index, rows.length),
          child: item,
        ),
    ],
  );
}

/// A section title above FlClash's grouped rows.
class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.title,
    this.padding,
    this.trailing,
  });

  final String title;
  final EdgeInsets? padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final padding = this.padding ?? listHeaderPaddingOf(context);
    return Padding(
      padding: padding,
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.headline
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class ListFooter extends StatelessWidget {
  const ListFooter({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      text,
      style: AppTextStyle.footnote
          .of(context)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    ),
  );
}

class ListSectionGap extends StatelessWidget {
  const ListSectionGap({super.key});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: listHeaderPaddingOf(context).top);
}

Widget generateSection({
  String? title,
  required Iterable<Widget> items,
  Widget? trailing,
  String? footer,
}) {
  final rows = items.toList();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (rows.isNotEmpty)
        title == null
            ? const ListSectionGap()
            : ListHeader(title: title, trailing: trailing),
      generateGroup(rows),
      if (rows.isNotEmpty && footer != null) ListFooter(text: footer),
    ],
  );
}
