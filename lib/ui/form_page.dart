// From FlClash 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// Presentation imports adapted for FlSteamLua. SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'context.dart';
import 'dialog.dart';
import 'form_row.dart';
import 'icons/icons.dart';
import 'localization.dart';
import 'loading.dart';
import 'metrics.dart';
import 'sheet_header.dart';
import 'shape.dart';
import 'surface.dart';
import 'switch.dart';
import 'typography.dart';

const double _headerHeight = 68;
const double _headerActionSize = 44;
const double _sectionsTopPadding = 44;

class FormPageAction {
  const FormPageAction({
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
  });

  final Glyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
}

/// A form shown by [showFormSheet]: grouped rows under a floating bar with
/// cancel and save fixed at its foot.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.onSave,
    required this.children,
    this.saveLabel,
    this.actions = const [],
    this.error,
    this.saving = false,
    this.canSave = true,
    this.onCancel,
  });

  final String title;
  final VoidCallback onSave;
  final List<FormPageAction> actions;
  final String? error;
  final bool saving;
  final bool canSave;
  final VoidCallback? onCancel;
  final String? saveLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: _FormBody(
            title: title,
            actions: actions,
            error: error,
            children: children,
          ),
        ),
        _FormActions(
          onSave: onSave,
          saving: saving,
          canSave: canSave,
          saveLabel: saveLabel,
          onCancel: onCancel,
        ),
      ],
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.title,
    required this.actions,
    required this.error,
    required this.children,
  });

  final String title;
  final List<FormPageAction> actions;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pageColor = SurfaceLevel.page.colorOf(context.colorScheme);
    return Stack(
      children: [
        ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, _sectionsTopPadding, 16, 20),
          children: [
            _FormErrorBanner(message: error),
            ...children,
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _headerHeight,
          child: FloatingHeader(
            backgroundColor: pageColor,
            child: _FormHeader(title: title, actions: actions),
          ),
        ),
      ],
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.title, required this.actions});

  final String title;
  final List<FormPageAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.headline.of(context),
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in actions)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: _FormActionButton(action: action),
                  ),
              ],
            ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _FormActionButton extends StatelessWidget {
  const _FormActionButton({required this.action});

  final FormPageAction action;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(_headerActionSize),
        fixedSize: const Size.square(_headerActionSize),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: context.raisedSurfaceLevel.colorOf(
          context.colorScheme,
        ),
        foregroundColor: context.colorScheme.onSurfaceVariant,
        shape: AppShape.circle,
      ),
      icon: GlyphIcon(action.glyph, size: 20),
    );
  }
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.onSave,
    required this.saving,
    required this.canSave,
    required this.saveLabel,
    required this.onCancel,
  });

  final VoidCallback onSave;
  final bool saving;
  final bool canSave;
  final String? saveLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AlertActions(
        actions: [
          TextButton(
            onPressed: saving && onCancel == null
                ? null
                : onCancel ?? () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: saving || !canSave ? null : onSave,
            child: saving
                ? const CommonCircleLoading(size: 18)
                : Text(saveLabel ?? context.l10n.save),
          ),
        ],
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return AnimatedSize(
      duration: context.motionDuration(midDuration),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: context.colorScheme.errorContainer,
                  shape: AppShape.md,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlyphIcon(
                        AppGlyphs.error,
                        size: 20,
                        color: context.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: AppTextStyle.body
                              .of(context)
                              .copyWith(
                                color: context.colorScheme.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class FormRowSwitch extends StatelessWidget {
  const FormRowSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FormRow(
      title: title,
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      trailing: CommonSwitch(value: value, onChanged: onChanged),
    );
  }
}
