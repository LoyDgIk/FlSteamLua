import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/localization.dart';
import '../ui/ui.dart' as ui;

const feedbackGroupNumber = '745268752';

Future<void> showSupportAuthorSheet(BuildContext context) =>
    ui.showModalSideSheet<void>(
      context: context,
      builder: (_) => const SupportAuthorSheet(),
    );

Future<void> showFeedbackGroupSheet(BuildContext context) =>
    ui.showModalSideSheet<void>(
      context: context,
      builder: (context) => ui.SideSheetScaffold(
        key: const ValueKey('feedback-group-sheet'),
        title: context.l10n.feedbackGroup,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            24,
            ui.SideSheetScaffold.headerHeight + 24,
            24,
            24,
          ),
          children: [
            SelectableText(
              feedbackGroupNumber,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(context.l10n.feedbackGroupHint),
            const SizedBox(height: 24),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ui.TonalButton(
                key: const ValueKey('copy-feedback-group'),
                glyph: ui.AppGlyphs.copy,
                label: context.l10n.copyGroupNumber,
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: feedbackGroupNumber),
                  );
                  if (context.mounted) {
                    ui.showAppSuccess(context, context.l10n.groupNumberCopied);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );

class SupportAuthorButton extends StatelessWidget {
  const SupportAuthorButton({super.key});

  @override
  Widget build(BuildContext context) => ui.DashboardIconButton(
    glyph: ui.AppGlyphs.coffee,
    tooltip: context.l10n.supportAuthor,
    onPressed: () => showSupportAuthorSheet(context),
  );
}

class SupportAuthorSheet extends StatefulWidget {
  const SupportAuthorSheet({super.key});

  @override
  State<SupportAuthorSheet> createState() => _SupportAuthorSheetState();
}

class _SupportAuthorSheetState extends State<SupportAuthorSheet> {
  var _method = 0;

  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    key: const ValueKey('support-author-sheet'),
    title: context.l10n.supportAuthor,
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        24,
        ui.SideSheetScaffold.headerHeight + 24,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          context.l10n.supportAuthorThanks,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        ui.SegmentedControl<int>(
          value: _method,
          segments: [(0, context.l10n.wechatPay), (1, context.l10n.alipay)],
          onChanged: (value) => setState(() => _method = value),
        ),
        const SizedBox(height: 20),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Image.asset(
              _method == 0
                  ? 'assets/support/wechat.png'
                  : 'assets/support/alipay.jpg',
              key: ValueKey(_method),
              fit: BoxFit.contain,
              semanticLabel: _method == 0
                  ? context.l10n.wechatPay
                  : context.l10n.alipay,
            ),
          ),
        ),
      ],
    ),
  );
}
