import 'package:flutter/material.dart';

import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'kernel_service.dart';

Future<KernelBackup?> showKernelBackupSheet({
  required BuildContext context,
  required KernelService service,
}) => ui.showModalSideSheet<KernelBackup>(
  context: context,
  builder: (_) => _KernelBackupSheet(service: service),
);

class _KernelBackupSheet extends StatelessWidget {
  const _KernelBackupSheet({required this.service});

  final KernelService service;

  @override
  Widget build(BuildContext context) {
    return ui.SideSheetScaffold(
      title: context.l10n.switchAndRecoveryBackups,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (service.backups.isEmpty)
            ui.NullStatus(
              label: context.l10n.switchAndRecoveryBackups,
              description: context
                  .l10n
                  .aRecoverableSnapshotIsSavedBeforeSwitchingOrUninstalling,
              illustration: ui.NullStatusIllustration.data,
            )
          else
            ui.generateSection(
              title: context.l10n.switchAndRecoveryBackups,
              items: [
                for (final backup in service.backups)
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.undo),
                    title: Text(backup.reason),
                    subtitle: Text(
                      '${backup.createdAt.toLocal().toString().split('.').first} · '
                      '${backup.files.length} ${context.l10n.files}',
                    ),
                    onPressed: () => Navigator.of(context).pop(backup),
                    trailing: const ui.GlyphIcon(
                      ui.AppGlyphs.chevronForward,
                      size: 18,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
