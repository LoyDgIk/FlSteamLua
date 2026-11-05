import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import 'context.dart';
import 'feedback.dart';
import 'icons/icons.dart';
import 'localization.dart';
import 'shape.dart';
import 'typography.dart';

/// Shared Markdown presentation for bundled and upstream release notes.
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes({super.key, required this.data, this.baseUrl});

  final String data;
  final Uri? baseUrl;

  Uri? _webUri(String href) {
    final parsed = Uri.tryParse(href);
    if (parsed == null) return null;
    final uri = baseUrl?.resolveUri(parsed) ?? parsed;
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final openFailure = context.l10n.operationFailedDetails;
    final body = AppTextStyle.subheadline
        .of(context)
        .copyWith(color: colors.onSurface);
    return MarkdownBody(
      data: data,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: body,
        h1: AppTextStyle.title1.of(context, emphasized: true),
        h2: AppTextStyle.title2.of(context, emphasized: true),
        h3: AppTextStyle.headline.of(context),
        h4: body.copyWith(fontWeight: FontWeight.w600),
        a: body.copyWith(
          color: colors.primary,
          decoration: TextDecoration.underline,
        ),
        code: body.copyWith(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        blockSpacing: 12,
        listIndent: 22,
        listBullet: body,
        tableHead: body.copyWith(fontWeight: FontWeight.w600),
        tableBody: body,
        tableBorder: TableBorder.all(color: colors.outlineVariant),
        tableCellsPadding: const EdgeInsets.all(8),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: AppRadius.sm,
        ),
        blockquotePadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
      ),
      onTapLink: (_, href, _) async {
        final uri = href == null ? null : _webUri(href);
        if (uri == null) return;
        try {
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            throw StateError(openFailure);
          }
        } catch (error) {
          if (context.mounted) showAppError(context, error);
        }
      },
      imageBuilder: (uri, title, alt) {
        final image = _webUri(uri.toString());
        if (image == null) return Text(alt ?? title ?? '');
        return Image.network(
          image.toString(),
          semanticLabel: alt,
          errorBuilder: (_, _, _) => const GlyphIcon(AppGlyphs.wifiOff),
        );
      },
    );
  }
}
