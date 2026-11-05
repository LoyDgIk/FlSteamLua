import 'package:flutter/material.dart';
import '../../core/steam_process_actions.dart';
import '../../core/storage_manager.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/localization.dart';
import 'cloud_service.dart';

String cloudProviderName(BuildContext context, String provider) =>
    switch (provider) {
      'folder' => context.l10n.localFolder,
      'gdrive' => 'Google Drive',
      'onedrive' => 'OneDrive',
      'r2' => 'Cloudflare R2',
      's3' => 'S3',
      'webdav' => 'WebDAV',
      _ => provider,
    };

String cloudLocationName(BuildContext context, String kind) => switch (kind) {
  'sync' || 'folder' => context.l10n.cloudFolderRepository,
  'cache' || 'legacy-cache' => context.l10n.cloudPluginCache,
  'userdata' => context.l10n.steamLocalSave,
  'remote' => context.l10n.remote,
  _ => kind,
};

String cloudBackupReason(BuildContext context, String reason) =>
    switch (reason) {
      'beforeDelete' => context.l10n.cloudBackupBeforeDelete,
      'beforeRestore' => context.l10n.cloudBackupBeforeRestore,
      'beforeUpload' => context.l10n.cloudBackupBeforeUpload,
      'beforeSync' => context.l10n.cloudBackupBeforeSync,
      _ => context.l10n.cloudBackupManual,
    };

/// One business confirmation using the shared side-sheet presentation.
Future<bool> confirmCloudOperation(
  BuildContext context, {
  required String title,
  required List<(String, String)> details,
  SteamProcessActions? steam,
  bool stopSteam = false,
  bool backup = false,
  String? explanation,
}) async {
  final running = stopSteam && steam != null && await steam.isRunning();
  if (!context.mounted) return false;
  final accepted = await ui.showModalSideSheet<bool>(
    context: context,
    builder: (sheet) => ui.SideSheetScaffold(
      title: title,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                ui.SideSheetScaffold.headerHeight + 16,
                16,
                24,
              ),
              children: [
                if (explanation != null) ui.ListFooter(text: explanation),
                ui.generateSection(
                  items: [
                    for (final (label, value) in details)
                      ui.DecorationListItem(
                        title: Text(label),
                        subtitle: SelectableText(value),
                      ),
                    if (backup)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.layers),
                        title: Text(sheet.l10n.cloudPreOperationBackup),
                      ),
                    if (stopSteam)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.info),
                        title: Text(sheet.l10n.cloudSteamMustStop),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 12,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ui.TonalButton(
                  label: sheet.l10n.cancel,
                  onPressed: () => Navigator.of(sheet).pop(false),
                ),
                Flexible(
                  child: ui.TonalButton(
                    key: const ValueKey('cloud-confirm-operation'),
                    label: running
                        ? sheet.l10n.cloudStopAndContinue
                        : sheet.l10n.confirm,
                    onPressed: () => Navigator.of(sheet).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (accepted != true) return false;
  if (stopSteam && steam != null && await steam.isRunning()) {
    await steam.stop();
    if (await steam.isRunning()) throw const SteamRunningException();
  }
  return true;
}

Future<bool> runCloudOperation(
  BuildContext context,
  CloudService service, {
  required String title,
  required Future<void> Function(TaskContext?) action,
  TaskCenter? tasks,
  int? appId,
  bool mutation = true,
  bool announce = true,
  String? success,
}) async {
  try {
    Future<void> execute(TaskContext? task) =>
        mutation ? service.runMutation(() => action(task)) : action(task);
    if (tasks != null) {
      await tasks.run(title, execute, appId: appId);
    } else {
      await execute(null);
    }
    if (announce && context.mounted) {
      ui.showAppSuccess(context, success ?? context.l10n.completed2);
    }
    return true;
  } on TaskCancelled {
    if (context.mounted) {
      ui.showAppFeedback(context, context.l10n.operationCancelled);
    }
  } catch (error) {
    if (context.mounted) ui.showAppError(context, error);
  }
  return false;
}

class CloudFilesSheet extends StatefulWidget {
  const CloudFilesSheet({super.key, required this.title, required this.load});
  final String title;
  final Future<List<CloudFileInfo>> Function() load;
  @override
  State<CloudFilesSheet> createState() => _CloudFilesSheetState();
}

class _CloudFilesSheetState extends State<CloudFilesSheet> {
  late Future<List<CloudFileInfo>> _files = widget.load();
  String _query = '';
  late final _search = ui.AppBarSearchState(
    onSearch: (v) => setState(() => _query = v.toLowerCase()),
  );
  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: widget.title,
    searchState: _search,
    actions: [
      ui.SideSheetHeaderButton(
        tooltip: context.l10n.refresh,
        icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
        onPressed: () => setState(() => _files = widget.load()),
      ),
    ],
    body: FutureBuilder(
      future: _files,
      builder: (context, snapshot) {
        final files = (snapshot.data ?? <CloudFileInfo>[])
            .where((v) => v.path.toLowerCase().contains(_query))
            .toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            ui.SideSheetScaffold.headerHeight + 16,
            16,
            16,
          ),
          child: ui.NullStatusSwitcher(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            isEmpty: snapshot.hasError || files.isEmpty,
            nullStatus: ui.NullStatus(
              label: snapshot.hasError
                  ? context.l10n.failed
                  : context.l10n.cloudNoFiles,
              description: snapshot.hasError ? '${snapshot.error}' : null,
            ),
            child: ui.CommonScrollBar(
              controller: null,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: files.length,
                itemBuilder: (_, i) => ui.DecorationListItem(
                  title: SelectableText(files[i].path),
                  subtitle: Text(
                    '${formatStorageBytes(files[i].size)}${files[i].modifiedAt == null ? '' : ' · ${files[i].modifiedAt!.toLocal()}'}',
                  ),
                  onPressed: files[i].sha256 == null
                      ? null
                      : () => ui.showModalSideSheet(
                          context: context,
                          builder: (_) => ui.SideSheetScaffold(
                            title: files[i].path,
                            body: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                ui.SideSheetScaffold.headerHeight + 16,
                                16,
                                16,
                              ),
                              children: [
                                SelectableText('SHA256\n${files[i].sha256}'),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
