// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation and localization imports adapted for FlSteamLua.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dialog.dart';
import 'localization.dart';

class InputDialog extends StatefulWidget {
  const InputDialog({
    super.key,
    required this.title,
    required this.value,
    this.suffixText,
    this.labelText,
    this.resetValue,
    this.hintText,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.obscureText = false,
    this.maxLength,
    this.inputFormatters,
    this.keyboardType,
    this.selectAll = false,
  });

  final String title;
  final String value;
  final String? suffixText;
  final String? labelText;
  final String? resetValue;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final bool obscureText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool selectAll;

  @override
  State<InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<InputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void initState() {
    super.initState();
    if (widget.selectAll) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.value.length,
      );
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() == false) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      suffixText: widget.suffixText,
      hintText: widget.hintText ?? widget.labelText,
    );
    return CommonDialog(
      title: widget.title,
      hasFields: true,
      actions: [
        ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) {
            final resetValue = widget.resetValue;
            if (resetValue != null && value.text != resetValue) {
              return TextButton(
                onPressed: () => Navigator.of(context).pop(resetValue),
                child: Text(context.l10n.reset),
              );
            }
            return TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            );
          },
        ),
        TextButton(onPressed: _submit, child: Text(context.l10n.confirm)),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: widget.autovalidateMode,
        child: TextFormField(
          autofocus: widget.selectAll,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          maxLines: widget.obscureText ? 1 : null,
          minLines: 1,
          controller: _controller,
          onFieldSubmitted: (_) => _submit(),
          decoration: decoration,
          validator: widget.validator,
        ),
      ),
    );
  }
}
