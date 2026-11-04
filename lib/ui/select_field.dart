// FlClash popup-backed select field, replacing Material dropdown routes.
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';

import 'icons/icons.dart';
import 'popup.dart';

class CommonSelectField<T> extends StatelessWidget {
  const CommonSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
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
    return CommonPopupBox(
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
      targetBuilder: (open) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: active ? open : null,
        child: InputDecorator(
          isEmpty: current == null,
          decoration: InputDecoration(
            hintText: label,
            enabled: active,
            contentPadding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  current ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const GlyphIcon(AppGlyphs.picker, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
