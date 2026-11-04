import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'card.dart';
import 'form_page.dart';
import 'form_row.dart';
import 'form_sheet.dart';
import 'icons/icons.dart';
import 'list.dart';
import 'localization.dart';
import 'loading.dart';
import 'shape.dart';
import 'typography.dart';

class PageProgressCapsule extends StatelessWidget {
  const PageProgressCapsule({
    super.key,
    required this.page,
    required this.totalPages,
    required this.loading,
    required this.onPressed,
  });

  final int page;
  final int totalPages;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.goToPage,
    child: Tooltip(
      message: context.l10n.goToPage,
      child: CommonCard(
        shape: AppShape.full,
        padding: EdgeInsets.zero,
        onPressed: loading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CommonCircleLoading(size: 16)
              else
                const GlyphIcon(AppGlyphs.layers, size: 16),
              const SizedBox(width: 7),
              Text(
                '$page / $totalPages',
                style: AppTextStyle.caption1.of(context, emphasized: true),
              ),
              const SizedBox(width: 4),
              const GlyphIcon(AppGlyphs.chevronForward, size: 14),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<int?> showPageJumpSheet(
  BuildContext context, {
  required int currentPage,
  required int totalPages,
}) => showFormSheet<int>(
  context: context,
  builder: (_) =>
      _PageJumpSheet(currentPage: currentPage, totalPages: totalPages),
);

class _PageJumpSheet extends StatefulWidget {
  const _PageJumpSheet({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  State<_PageJumpSheet> createState() => _PageJumpSheetState();
}

class _PageJumpSheetState extends State<_PageJumpSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentPage}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final page = int.tryParse(_controller.text.trim());
    if (page == null || page < 1 || page > widget.totalPages) {
      setState(() => _error = context.l10n.pageOutOfRange(widget.totalPages));
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) => FormPage(
    title: context.l10n.goToPage,
    saveLabel: context.l10n.goToPage,
    onSave: _save,
    error: _error,
    children: [
      generateSection(
        items: [
          FormRow(
            title: context.l10n.pageNumber,
            trailing: SizedBox(
              width: 120,
              child: FormRowTextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                hintText: '1 - ${widget.totalPages}',
                onChanged: (_) => setState(() => _error = null),
                onFieldSubmitted: (_) => _save(),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
