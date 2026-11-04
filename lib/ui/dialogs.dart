// FlClash dialog facade for all application-owned modal interactions.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'dialog.dart';
import 'input.dart';
import 'localization.dart';

abstract final class AppDialogs {
  static Future<T?> show<T>(
    BuildContext context,
    Widget child, {
    bool dismissible = true,
  }) => showFloatingDialog<T>(
    context: context,
    child: child,
    dismissible: dismissible,
  );

  static Future<bool?> confirm(
    BuildContext context, {
    required String message,
    String? title,
    String? confirmText,
    String? cancelText,
    bool destructive = false,
  }) => show<bool>(
    context,
    Builder(
      builder: (dialogContext) => CommonDialog(
        title: title ?? dialogContext.l10n.tip,
        destructive: destructive,
        actions: [
          CommonDialogAction(
            label: cancelText ?? dialogContext.l10n.cancel,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          CommonDialogAction(
            label: confirmText ?? dialogContext.l10n.confirm,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
        child: SelectableText(message),
      ),
    ),
  );

  static Future<void> alert(
    BuildContext context, {
    required String message,
    String? title,
  }) => show<void>(
    context,
    Builder(
      builder: (dialogContext) => CommonDialog(
        title: title ?? dialogContext.l10n.tip,
        actions: [
          CommonDialogAction(
            label: dialogContext.l10n.confirm,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
        child: SelectableText(message),
      ),
    ),
  );

  static Future<String?> input(
    BuildContext context, {
    required String title,
    String value = '',
    String? labelText,
    String? hintText,
    String? suffixText,
    String? resetValue,
    bool obscureText = false,
    int? maxLength,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) => show<String>(
    context,
    InputDialog(
      title: title,
      value: value,
      labelText: labelText,
      hintText: hintText,
      suffixText: suffixText,
      resetValue: resetValue,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      validator: validator,
      selectAll: true,
    ),
  );
}
