// Record row adapted from FlClash's connection/log presentation.
// Source: 7fd417fb9a9a277c6a9339a8ac87f907df7c25f7.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'chip.dart';
import 'context.dart';
import 'shape.dart';
import 'surface.dart';
import 'typography.dart';

enum RecordTone { neutral, warning, error }

extension RecordToneColors on RecordTone {
  Color labelColor(BuildContext context) {
    final scheme = context.colorScheme;
    return switch (this) {
      RecordTone.neutral => scheme.onSurfaceVariant,
      RecordTone.warning => scheme.onTertiaryContainer,
      RecordTone.error => scheme.onErrorContainer,
    };
  }

  Color labelContainerColor(BuildContext context) {
    final scheme = context.colorScheme;
    return switch (this) {
      RecordTone.neutral => context.raisedSurfaceLevel.colorOf(scheme),
      RecordTone.warning => scheme.tertiaryContainer,
      RecordTone.error => scheme.errorContainer,
    };
  }
}

class RecordHeader extends StatelessWidget {
  const RecordHeader({super.key, required this.children, this.trailing});

  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: AppTextStyle.caption1
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant),
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: children,
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

class RecordTimestamp extends StatelessWidget {
  const RecordTimestamp(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) => Text(value, maxLines: 1);
}

class RecordLabel extends StatelessWidget {
  const RecordLabel({
    super.key,
    required this.label,
    this.tone = RecordTone.neutral,
    this.onPressed,
  });

  final String label;
  final RecordTone tone;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TonalChip(
    label: label,
    color: tone.labelContainerColor(context),
    foregroundColor: tone.labelColor(context),
    onPressed: onPressed,
  );
}

class RecordListItem extends StatelessWidget {
  const RecordListItem({
    super.key,
    required this.header,
    required this.body,
    this.onTap,
  });

  final Widget header;
  final Widget body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final level = context.raisedSurfaceLevel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: level.colorOf(context.colorScheme),
            shape: AppShape.xl,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, const SizedBox(height: 6), body],
            ),
          ),
        ),
      ),
    );
  }
}

class LogRecordCard extends StatelessWidget {
  const LogRecordCard({
    super.key,
    required this.time,
    required this.level,
    required this.message,
    this.tone = RecordTone.neutral,
    this.onLevelPressed,
  });

  final String time;
  final String level;
  final String message;
  final RecordTone tone;
  final VoidCallback? onLevelPressed;

  @override
  Widget build(BuildContext context) => RecordListItem(
    header: RecordHeader(
      children: [
        RecordTimestamp(time),
        RecordLabel(label: level, tone: tone, onPressed: onLevelPressed),
      ],
    ),
    body: SelectableText(
      message,
      style: AppTextStyle.subheadline
          .of(context)
          .copyWith(color: context.colorScheme.onSurface),
    ),
  );
}
