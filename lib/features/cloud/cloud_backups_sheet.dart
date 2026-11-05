import 'package:flutter/material.dart';
import '../../core/steam_process_actions.dart';
import '../../core/storage_manager.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/localization.dart';
import 'cloud_service.dart';
import 'cloud_workflows.dart';

class CloudBackupsSheet extends StatefulWidget {
  const CloudBackupsSheet({
    super.key,
    required this.service,
    required this.gameName,
    this.appId,
    this.tasks,
    this.steam,
  });
  final CloudService service;
  final String Function(int) gameName;
  final int? appId;
  final TaskCenter? tasks;
  final SteamProcessActions? steam;
  @override
  State<CloudBackupsSheet> createState() => _CloudBackupsSheetState();
}

class _CloudBackupsSheetState extends State<CloudBackupsSheet> {
  late Future<List<CloudBackup>> _backups = widget.service.backups(
    appId: widget.appId,
  );
  String _query = '';
  late final _search = ui.AppBarSearchState(
    onSearch: (v) => setState(() => _query = v.toLowerCase()),
  );
  void _reload() {
    if (mounted) {
      setState(() => _backups = widget.service.backups(appId: widget.appId));
    }
  }

  Future<void> _clean(int appId) async {
    final rule = widget.service.settings.get<Map>('cloudRetention:$appId', {});
    final values = await ui.showFormSheet<(int, int)>(
      context: context,
      builder: (_) => _RetentionForm(
        keep: rule['keep'] as int? ?? 10,
        maxBytes: rule['maxBytes'] as int? ?? 0,
      ),
    );
    if (values == null || !mounted) return;
    try {
      await widget.service.saveRetention(appId, values.$1, values.$2);
      final remove = await widget.service.retentionCandidates(
        appId: appId,
        keep: values.$1,
        maxBytes: values.$2,
      );
      if (!mounted) return;
      if (remove.isEmpty) {
        ui.showAppFeedback(context, context.l10n.cloudNothingToClean);
        return;
      }
      if (!await confirmCloudOperation(
        context,
        title: context.l10n.cloudRetention,
        details: [
          for (final v in remove)
            (
              v.createdAt.toLocal().toString(),
              '${formatStorageBytes(v.size)} · ${v.note}\n${v.path}',
            ),
        ],
      )) {
        return;
      }
      if (!mounted) return;
      await runCloudOperation(
        context,
        widget.service,
        title: context.l10n.cloudRetention,
        tasks: widget.tasks,
        action: (_) => widget.service.removeBackups(remove),
      );
      _reload();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _details(CloudBackup backup) async {
    await ui.showModalSideSheet(
      context: context,
      builder: (_) => _BackupDetailSheet(
        service: widget.service,
        initial: backup,
        gameName: widget.gameName(backup.appId),
        tasks: widget.tasks,
        steam: widget.steam,
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: context.l10n.saveBackups,
    searchState: _search,
    actions: [
      ui.SideSheetHeaderButton(
        tooltip: context.l10n.refresh,
        icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
        onPressed: _reload,
      ),
    ],
    body: FutureBuilder(
      future: _backups,
      builder: (context, snapshot) {
        final records = (snapshot.data ?? <CloudBackup>[]).where(
          (v) =>
              '${widget.gameName(v.appId)} ${v.appId} ${v.note} ${v.createdAt} ${v.locations.map((l) => l.accountId).join(' ')}'
                  .toLowerCase()
                  .contains(_query),
        );
        final groups = <int, List<CloudBackup>>{};
        for (final v in records) {
          groups.putIfAbsent(v.appId, () => []).add(v);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            ui.SideSheetScaffold.headerHeight + 16,
            16,
            16,
          ),
          child: ui.NullStatusSwitcher(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            isEmpty: snapshot.hasError || groups.isEmpty,
            nullStatus: ui.NullStatus(
              label: snapshot.hasError
                  ? context.l10n.failed
                  : _query.isEmpty
                  ? context.l10n.noBackupsYet
                  : context.l10n.noSearchResults,
              description: snapshot.hasError ? '${snapshot.error}' : null,
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in groups.entries) ...[
                  ui.generateSection(
                    title: widget.gameName(group.key),
                    items: [
                      ui.DecorationListItem(
                        title: Text(context.l10n.cloudRetention),
                        leading: const ui.GlyphIcon(ui.AppGlyphs.delete),
                        onPressed: () => _clean(group.key),
                      ),
                      for (final backup in group.value)
                        ui.DecorationListItem(
                          key: ValueKey(backup.path),
                          title: Text(
                            backup.createdAt
                                .toLocal()
                                .toString()
                                .split('.')
                                .first,
                          ),
                          subtitle: Text(
                            '${cloudBackupReason(context, backup.reason)} · ${backup.fileCount} ${context.l10n.files} · ${formatStorageBytes(backup.size)}\n${backup.note.isEmpty ? backup.locations.map((v) => v.accountId).toSet().join(', ') : backup.note}',
                          ),
                          trailing: backup.pinned
                              ? ui.MetaChip(
                                  label: context.l10n.cloudBackupPinned,
                                )
                              : const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                          onPressed: () => _details(backup),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _BackupDetailSheet extends StatefulWidget {
  const _BackupDetailSheet({
    required this.service,
    required this.initial,
    required this.gameName,
    this.tasks,
    this.steam,
  });
  final CloudService service;
  final CloudBackup initial;
  final String gameName;
  final TaskCenter? tasks;
  final SteamProcessActions? steam;
  @override
  State<_BackupDetailSheet> createState() => _BackupDetailSheetState();
}

class _BackupDetailSheetState extends State<_BackupDetailSheet> {
  late CloudBackup _backup = widget.initial;
  bool _busy = false;
  Future<void> _reload() async {
    final found = (await widget.service.backups(
      appId: _backup.appId,
    )).where((v) => v.path == _backup.path).firstOrNull;
    if (mounted && found != null) setState(() => _backup = found);
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext?) action,
  ) async {
    setState(() => _busy = true);
    await runCloudOperation(
      context,
      widget.service,
      title: title,
      action: action,
      tasks: widget.tasks,
      appId: _backup.appId,
    );
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    try {
      final targets = widget.service.restoreLocations(_backup);
      if (!await confirmCloudOperation(
        context,
        title: context.l10n.restoreBackup,
        steam: widget.steam,
        stopSteam: true,
        backup: true,
        details: [
          if (_backup.target != null)
            (context.l10n.cloudDestination, _backup.target!.summary),
          for (final t in targets)
            (
              cloudLocationName(context, t.location.kind),
              '${t.location.accountId}\n${t.path}',
            ),
        ],
      )) {
        return;
      }
      if (!mounted) return;
      await _run(
        context.l10n.restoreSaves,
        (task) => widget.service.restore(_backup, context: task),
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _edit() async {
    final values = await ui.showFormSheet<(String, bool)>(
      context: context,
      builder: (_) => _BackupEditForm(backup: _backup),
    );
    if (values != null && mounted) {
      await _run(
        context.l10n.save,
        (_) => widget.service.updateBackup(
          _backup,
          note: values.$1,
          pinned: values.$2,
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (!await confirmCloudOperation(
      context,
      title: context.l10n.delete,
      details: [(widget.gameName, _backup.path)],
    )) {
      return;
    }
    if (!mounted) return;
    final removed = await runCloudOperation(
      context,
      widget.service,
      title: context.l10n.delete,
      tasks: widget.tasks,
      action: (_) => widget.service.removeBackups([_backup]),
    );
    if (removed && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: context.l10n.cloudBackupDetails,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        ui.SideSheetScaffold.headerHeight + 16,
        16,
        24,
      ),
      children: [
        ui.generateSection(
          items: [
            ui.DecorationListItem(
              title: Text(widget.gameName),
              subtitle: Text(
                '${_backup.createdAt.toLocal()}\n${cloudBackupReason(context, _backup.reason)} · ${formatStorageBytes(_backup.size)}',
              ),
            ),
            ui.DecorationListItem(
              title: Text(context.l10n.cloudBackupNote),
              subtitle: Text(
                _backup.note.isEmpty ? context.l10n.optional : _backup.note,
              ),
              trailing: _backup.pinned
                  ? ui.MetaChip(label: context.l10n.cloudBackupPinned)
                  : null,
              onPressed: _busy ? null : _edit,
            ),
            if (_backup.target != null)
              ui.DecorationListItem(
                title: Text(context.l10n.cloudDestination),
                subtitle: SelectableText(_backup.target!.summary),
              ),
            for (final loc in _backup.locations)
              ui.DecorationListItem(
                title: Text(cloudLocationName(context, loc.kind)),
                subtitle: SelectableText('${loc.accountId}\n${loc.sourcePath}'),
              ),
            ui.DecorationListItem(
              title: Text(context.l10n.cloudLoadFiles),
              subtitle: Text('${_backup.fileCount} ${context.l10n.files}'),
              onPressed: () => ui.showModalSideSheet(
                context: context,
                builder: (_) => CloudFilesSheet(
                  title: context.l10n.cloudLoadFiles,
                  load: () => widget.service.backupFiles(_backup),
                ),
              ),
            ),
            ui.DecorationListItem(
              title: Text(context.l10n.cloudVerifyBackup),
              subtitle: _backup.verifiedAt == null
                  ? null
                  : Text(
                      '${context.l10n.cloudBackupVerified} · ${_backup.verifiedAt!.toLocal()}',
                    ),
              onPressed: _busy
                  ? null
                  : () => _run(
                      context.l10n.cloudVerifyBackup,
                      (_) => widget.service.verifyBackup(_backup),
                    ),
            ),
            ui.DecorationListItem(
              title: Text(context.l10n.restoreBackup),
              leading: const ui.GlyphIcon(ui.AppGlyphs.undo),
              onPressed: _busy ? null : _restore,
            ),
            ui.DecorationListItem(
              title: Text(context.l10n.delete),
              leading: const ui.GlyphIcon(ui.AppGlyphs.delete),
              onPressed: _busy || _backup.pinned ? null : _delete,
            ),
          ],
        ),
      ],
    ),
  );
}

class _BackupEditForm extends StatefulWidget {
  const _BackupEditForm({required this.backup});
  final CloudBackup backup;
  @override
  State<_BackupEditForm> createState() => _BackupEditFormState();
}

class _BackupEditFormState extends State<_BackupEditForm> {
  late final _note = TextEditingController(text: widget.backup.note);
  late bool _pinned = widget.backup.pinned;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: context.l10n.cloudBackupDetails,
    onSave: () => Navigator.of(context).pop((_note.text, _pinned)),
    children: [
      ui.generateSection(
        items: [
          ui.FormRow(
            title: context.l10n.cloudBackupNote,
            trailing: ui.FormRowTextField(controller: _note, maxLines: 3),
          ),
          ui.FormRowSwitch(
            title: context.l10n.cloudBackupPinned,
            value: _pinned,
            onChanged: (v) => setState(() => _pinned = v),
          ),
        ],
      ),
    ],
  );
}

class _RetentionForm extends StatefulWidget {
  const _RetentionForm({required this.keep, required this.maxBytes});
  final int keep, maxBytes;
  @override
  State<_RetentionForm> createState() => _RetentionFormState();
}

class _RetentionFormState extends State<_RetentionForm> {
  late final _keep = TextEditingController(text: '${widget.keep}');
  late final _size = TextEditingController(
    text: '${widget.maxBytes ~/ (1024 * 1024)}',
  );
  String? _error;
  @override
  void dispose() {
    _keep.dispose();
    _size.dispose();
    super.dispose();
  }

  void _save() {
    final keep = int.tryParse(_keep.text), size = int.tryParse(_size.text);
    if (keep == null || size == null || keep < 0 || size < 0) {
      setState(() => _error = context.l10n.cloudInvalidRetention);
      return;
    }
    Navigator.of(context).pop((keep, size * 1024 * 1024));
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: context.l10n.cloudRetention,
    onSave: _save,
    error: _error,
    children: [
      ui.generateSection(
        footer: context.l10n.cloudRetentionHint,
        items: [
          ui.FormRow(
            title: context.l10n.cloudRetentionCount,
            trailing: ui.FormRowTextField(
              controller: _keep,
              keyboardType: TextInputType.number,
            ),
          ),
          ui.FormRow(
            title: context.l10n.cloudRetentionSize,
            trailing: ui.FormRowTextField(
              controller: _size,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    ],
  );
}
