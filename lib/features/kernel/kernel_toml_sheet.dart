import 'package:flutter/material.dart';

import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'kernel_service.dart';

Future<bool?> showKernelTomlPreviewSheet({
  required BuildContext context,
  required SteamDllTomlInfo info,
}) => ui.showModalSideSheet<bool>(
  context: context,
  builder: (_) => _KernelTomlPreviewSheet(info: info),
);

Future<void> showKernelTomlResultSheet({
  required BuildContext context,
  required List<TomlFetchResult> results,
}) => ui.showModalSideSheet<void>(
  context: context,
  builder: (_) => _KernelTomlResultSheet(results: results),
);

class _KernelTomlPreviewSheet extends StatelessWidget {
  const _KernelTomlPreviewSheet({required this.info});

  final SteamDllTomlInfo info;

  @override
  Widget build(BuildContext context) {
    final files = [
      'pattern/steamclient/${info.clientSha}.toml',
      'pattern/steamui/${info.uiSha}.toml',
      'ipc/steamclient/${info.clientSha}.toml',
    ];
    return ui.SideSheetScaffold(
      title: context.l10n.kernelTomlPreviewTitle,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                ui.pageToolbarHeight + 12,
                16,
                20,
              ),
              children: [
                ui.generateSection(
                  title: context.l10n.fetchSteamSignatures,
                  items: [
                    ui.FormRow(
                      title: context.l10n.kernelBuildId,
                      trailing: Text(
                        info.buildId ?? context.l10n.unknownVersion,
                      ),
                    ),
                    ui.FormRow(
                      title: context.l10n.kernelClientSha,
                      trailing: Text(
                        info.clientSha,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ui.FormRow(
                      title: context.l10n.kernelUiSha,
                      trailing: Text(
                        info.uiSha,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                ui.generateSection(
                  title: context.l10n.kernelTomlFiles,
                  items: [
                    for (final file in files)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.code),
                        title: Text(
                          file,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ui.AlertActions(
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.kernelStartFetch),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KernelTomlResultSheet extends StatelessWidget {
  const _KernelTomlResultSheet({required this.results});

  final List<TomlFetchResult> results;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return ui.SideSheetScaffold(
      title: context.l10n.kernelTomlResults,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                ui.pageToolbarHeight + 12,
                16,
                20,
              ),
              children: [
                ui.generateSection(
                  title: context.l10n.kernelTomlResults,
                  items: [
                    for (final result in results)
                      ui.DecorationListItem(
                        leading: ui.GlyphIcon(
                          result.success
                              ? ui.AppGlyphs.checkCircle
                              : ui.AppGlyphs.error,
                          color: result.success ? colors.primary : colors.error,
                        ),
                        title: Text(result.relativePath),
                        subtitle: Text(
                          result.success
                              ? context.l10n.kernelTomlReady
                              : result.notFound
                              ? context.l10n.kernelTomlNoUpstream
                              : '${context.l10n.kernelTomlFailed}: ${result.error ?? ''}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
