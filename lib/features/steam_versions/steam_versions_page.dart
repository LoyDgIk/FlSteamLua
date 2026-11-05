import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/storage_manager.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/localization.dart';
import 'steam_version_service.dart';

class SteamVersionsPage extends StatefulWidget {
  const SteamVersionsPage({
    super.key,
    required this.service,
    required this.tasks,
  });
  final SteamVersionService service;
  final TaskCenter tasks;
  @override
  State<SteamVersionsPage> createState() => _SteamVersionsPageState();
}

class _SteamVersionsPageState extends State<SteamVersionsPage> {
  String _arch = 'all', _query = '';
  late final _search = ui.AppBarSearchState(
    onSearch: (v) => setState(() => _query = v.toLowerCase()),
  );
  SteamVersionService get service => widget.service;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _run(
            context.l10n.steamVersionRefreshLocal,
            (_) => service.load(),
            announce: false,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<bool> _run(
    String title,
    Future<void> Function(TaskContext) action, {
    bool announce = true,
    String? success,
  }) async {
    try {
      await widget.tasks.run(title, action);
      if (mounted && announce) {
        ui.showAppSuccess(context, success ?? context.l10n.completed2);
      }
      return true;
    } on TaskCancelled {
      if (mounted) ui.showAppFeedback(context, context.l10n.operationCancelled);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
    return false;
  }

  Future<void> _history() async {
    final options = await ui.showFormSheet<(String, String, String, int, bool)>(
      context: context,
      builder: (_) => _HistoryForm(arch: _arch == 'all' ? 'win64' : _arch),
    );
    if (options == null || !mounted) return;
    await _run(
      context.l10n.steamVersionHistory,
      (task) => service.history(
        arch: options.$1,
        from: options.$2,
        to: options.$3,
        limit: options.$4,
        forceRefresh: options.$5,
        context: task,
      ),
    );
  }

  Future<void> _waybackSettings() async {
    await ui.showFormSheet(
      context: context,
      builder: (_) => _WaybackSettingsForm(service: service),
    );
  }

  Future<void> _import() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null || !mounted) return;
    await _run(
      context.l10n.steamVersionImport,
      (task) => service.importDirectory(folder, context: task),
    );
  }

  Future<void> _target() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null || !mounted) return;
    await _run(
      context.l10n.steamVersionTarget,
      (_) => service.selectTarget(folder),
      announce: false,
    );
  }

  Future<void> _details(SteamClientVersion version) => ui.showModalSideSheet(
    context: context,
    builder: (_) =>
        _VersionDetail(service: service, tasks: widget.tasks, version: version),
  );
  Future<void> _backups() async {
    try {
      final records = await service.backups();
      if (!mounted) return;
      final backup = await ui.showModalSideSheet<SteamClientBackup>(
        context: context,
        builder: (sheet) => ui.SideSheetScaffold(
          title: sheet.l10n.steamVersionBackups,
          body: records.isEmpty
              ? ui.NullStatus(label: sheet.l10n.noBackupsYet)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    ui.SideSheetScaffold.headerHeight + 16,
                    16,
                    24,
                  ),
                  children: [
                    ui.generateSection(
                      items: [
                        for (final item in records)
                          ui.DecorationListItem(
                            title: Text(
                              item.createdAt
                                  .toLocal()
                                  .toString()
                                  .split('.')
                                  .first,
                            ),
                            subtitle: Text(
                              '${item.target}\n${item.files} ${sheet.l10n.files} · ${item.build}',
                            ),
                            trailing: const ui.GlyphIcon(ui.AppGlyphs.undo),
                            onPressed: () => Navigator.of(sheet).pop(item),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      );
      if (backup == null || !mounted) return;
      final accepted = await _confirmSteamVersion(
        context,
        service,
        title: context.l10n.restoreBackup,
        description: context.l10n.steamVersionRestoreHint,
        target: backup.target,
      );
      if (accepted == null || !mounted) return;
      await _run(
        context.l10n.restoreBackup,
        (task) => service.restoreBackup(backup, context: task),
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.l10n;
    final versions = service.versions
        .where(
          (v) =>
              (_arch == 'all' || v.arch == _arch) &&
              '${v.arch} ${v.build} ${v.date}'.toLowerCase().contains(_query),
        )
        .toList();
    return ui.CommonScaffold(
      title: text.steamVersionTitle,
      searchState: _search,
      isLoading: service.busy,
      actions: [
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.settings,
          tooltip: text.steamVersionWaybackSettings,
          onPressed: service.busy ? null : _waybackSettings,
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.refresh,
          tooltip: text.steamVersionRefreshCatalog,
          onPressed: service.busy
              ? null
              : () => _run(
                  text.steamVersionRefreshCatalog,
                  (task) => service.refreshCatalog(context: task),
                ),
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.clock,
          tooltip: text.steamVersionHistory,
          onPressed: service.busy ? null : _history,
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.upload,
          tooltip: text.steamVersionImport,
          onPressed: service.busy ? null : _import,
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.undo,
          tooltip: text.steamVersionBackups,
          onPressed: service.busy ? null : _backups,
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              16,
              ui.pageContentTopInset,
              16,
              0,
            ),
            sliver: SliverList.list(
              children: [
                ui.generateSection(
                  items: [
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                      title: Text(text.steamVersionCurrent),
                      subtitle: Text(
                        service.installed?.build == null
                            ? text.steamVersionUnknown
                            : '${service.installed!.arch} · ${service.installed!.build}',
                      ),
                      trailing: ui.TonalButton(
                        size: ui.TonalButtonSize.compact,
                        label: text.steamVersionRefreshLocal,
                        onPressed: service.busy
                            ? null
                            : () => _run(
                                text.steamVersionRefreshLocal,
                                (_) => service.refreshLocal(),
                                announce: false,
                              ),
                      ),
                    ),
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                      title: Text(text.steamVersionTarget),
                      subtitle: Text(
                        service.settings.steamPath.isEmpty
                            ? text.steamVersionTargetRequired
                            : service.settings.steamPath,
                      ),
                      onPressed: service.busy ? null : _target,
                      trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ui.SegmentedControl<String>(
                    segments: [
                      ('all', text.all),
                      ('win64', 'win64'),
                      ('win32', 'win32'),
                    ],
                    value: _arch,
                    onChanged: (v) => setState(() => _arch = v),
                  ),
                ),
                if (service.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ui.CommonCard(
                      isError: true,
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(service.lastError!),
                    ),
                  ),
              ],
            ),
          ),
          if (versions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ui.NullStatus(
                scrollable: false,
                label: _query.isEmpty
                    ? text.steamVersionEmpty
                    : text.noSearchResults,
                illustration: _query.isEmpty
                    ? ui.NullStatusIllustration.data
                    : ui.NullStatusIllustration.search,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.list(
                children: [
                  ui.AnimatedEntries(
                    grouped: true,
                    children: [
                      for (final version in versions)
                        ui.DecorationListItem(
                          key: ValueKey(version.id),
                          leading: const ui.GlyphIcon(ui.AppGlyphs.layers),
                          title: Text(_versionTitle(context, version)),
                          subtitle: Text(
                            '${version.date.toLocal().toString().split('.').first} · ${_sourceName(context, version.source)}${version.hasManifest ? '\n${version.files.length} ${text.steamVersionPackages} · ${formatStorageBytes(version.size)}' : ''}',
                          ),
                          trailing: ui.MetaChip(
                            label:
                                service.installed?.build == version.build &&
                                    service.installed?.arch == version.arch
                                ? text.installed
                                : !version.hasManifest
                                ? text.steamVersionManifestPending
                                : (service.downloadedCounts[version.id] ?? 0) ==
                                      version.files.length
                                ? text.steamVersionReady
                                : text.steamVersionPartial(
                                    '${service.downloadedCounts[version.id] ?? 0}',
                                    '${version.files.length}',
                                  ),
                          ),
                          onPressed: () => _details(version),
                        ),
                    ],
                  ),
                  if (service.checkedAt != null)
                    ui.ListFooter(
                      text:
                          '${text.cloudLastChecked} · ${service.checkedAt!.toLocal().toString().split('.').first}',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _sourceName(BuildContext context, String source) => switch (source) {
  'official' => context.l10n.steamVersionOfficial,
  'archive' => context.l10n.steamVersionArchive,
  'builtin' => context.l10n.steamVersionBuiltin,
  _ => context.l10n.steamVersionLocal,
};

String _versionTitle(BuildContext context, SteamClientVersion version) =>
    '${version.build.isEmpty ? context.l10n.steamVersionSnapshot(version.date.toLocal().toString().split(' ').first) : version.build} · ${version.arch}';

class _VersionDetail extends StatefulWidget {
  const _VersionDetail({
    required this.service,
    required this.tasks,
    required this.version,
  });
  final SteamVersionService service;
  final TaskCenter tasks;
  final SteamClientVersion version;
  @override
  State<_VersionDetail> createState() => _VersionDetailState();
}

class _VersionDetailState extends State<_VersionDetail> {
  SteamVersionService get service => widget.service;
  late SteamClientVersion _version = widget.version;
  String? _error;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    if (!_version.hasManifest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadManifest());
      });
    }
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadManifest() async {
    setState(() => _error = null);
    try {
      final version = await widget.tasks.run(
        context.l10n.steamVersionLoadManifest,
        (task) => service.resolveVersion(_version, context: task),
      );
      if (mounted) setState(() => _version = version);
    } catch (error) {
      if (mounted) setState(() => _error = ui.appErrorText(context, error));
    }
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext) action, {
    String? success,
  }) async {
    try {
      await widget.tasks.run(title, action);
      if (mounted) {
        ui.showAppSuccess(context, success ?? context.l10n.completed2);
      }
    } on TaskCancelled {
      if (mounted) ui.showAppFeedback(context, context.l10n.operationCancelled);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _install() async {
    try {
      final accepted = await _confirmSteamVersion(
        context,
        service,
        title: context.l10n.steamVersionInstall,
        description: context.l10n.steamVersionInstallHint,
        target: service.settings.steamPath,
        version: _version,
      );
      if (accepted != true || !mounted) return;
      await _run(
        context.l10n.steamVersionInstall,
        (task) async {
          await service.install(_version, context: task);
        },
        success: context.l10n.steamVersionInstalled,
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _delete() async {
    if (await ui.AppDialogs.confirm(
              context,
              title: context.l10n.delete,
              message: context.l10n.steamVersionDeleteDownload,
              destructive: true,
            ) !=
            true ||
        !mounted) {
      return;
    }
    await _run(context.l10n.delete, (_) => service.removeDownload(_version));
  }

  @override
  Widget build(BuildContext context) {
    final v = _version, text = context.l10n;
    final complete =
        v.hasManifest &&
        (service.downloadedCounts[v.id] ?? 0) == v.files.length;
    return ui.SideSheetScaffold(
      title: _versionTitle(context, v),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          24,
        ),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ui.CommonCard(
                isError: true,
                padding: const EdgeInsets.all(16),
                child: SelectableText(_error!),
              ),
            ),
          if (!v.hasManifest)
            ui.generateSection(
              items: [
                ui.DecorationListItem(
                  title: Text(text.steamVersionLoadManifest),
                  onPressed: service.busy ? null : _loadManifest,
                  trailing: service.busy
                      ? const ui.CommonCircleLoading(size: 18)
                      : const ui.GlyphIcon(ui.AppGlyphs.refresh),
                ),
              ],
            ),
          ui.generateSection(
            items: [
              ui.DecorationListItem(
                title: Text(_sourceName(context, v.source)),
                subtitle: SelectableText(
                  v.manifestUrl.isEmpty ? service.directory(v) : v.manifestUrl,
                ),
              ),
              ui.DecorationListItem(
                title: Text(text.steamVersionDownload),
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                subtitle: v.hasManifest
                    ? Text(formatStorageBytes(v.size))
                    : null,
                onPressed: service.busy || !v.hasManifest
                    ? null
                    : () => _run(
                        text.steamVersionDownload,
                        (task) => service.download(v, context: task),
                        success: text.steamVersionDownloadedVerified,
                      ),
              ),
              ui.DecorationListItem(
                title: Text(text.steamVersionVerify),
                leading: const ui.GlyphIcon(ui.AppGlyphs.verified),
                onPressed: service.busy || !complete
                    ? null
                    : () => _run(
                        text.steamVersionVerify,
                        (task) => service.operation(
                          () => service.verify(v, context: task),
                        ),
                        success: text.steamVersionDownloadedVerified,
                      ),
              ),
              ui.DecorationListItem(
                title: Text(text.steamVersionInstall),
                leading: const ui.GlyphIcon(ui.AppGlyphs.swap),
                onPressed: service.busy || !complete ? null : _install,
              ),
              ui.DecorationListItem(
                title: Text(text.openFolder),
                leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                onPressed: () => _run(text.openFolder, (_) async {
                  await launchUrl(Uri.directory(service.directory(v)));
                }),
              ),
              ui.DecorationListItem(
                title: Text(text.delete),
                leading: const ui.GlyphIcon(ui.AppGlyphs.delete),
                onPressed: service.busy ? null : _delete,
              ),
            ],
          ),
          if (v.hasManifest)
            ui.CollapsibleSection(
              label: text.steamVersionPackages,
              itemCount: v.files.length,
              initiallyExpanded: false,
              itemBuilder: (_, i) => ui.DecorationListItem(
                title: SelectableText(v.files[i].name),
                subtitle: SelectableText(
                  '${formatStorageBytes(v.files[i].size)}\nSHA-256 ${v.files[i].sha256}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmSteamVersion(
  BuildContext context,
  SteamVersionService service, {
  required String title,
  required String description,
  required String target,
  SteamClientVersion? version,
}) async {
  final running = await service.library.isSteamRunning();
  if (!context.mounted) return null;
  final result = await ui.showModalSideSheet<bool>(
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
                ui.ListFooter(text: description),
                ui.generateSection(
                  items: [
                    ui.DecorationListItem(
                      title: Text(sheet.l10n.steamVersionTarget),
                      subtitle: SelectableText(target),
                    ),
                    if (version != null)
                      ui.DecorationListItem(
                        title: Text(sheet.l10n.steamVersionDetails),
                        subtitle: Text('${version.arch} · ${version.build}'),
                      ),
                    ui.DecorationListItem(
                      title: Text(sheet.l10n.steamVersionBackupBefore),
                    ),
                    ui.DecorationListItem(
                      title: Text(sheet.l10n.steamVersionStopSteam),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 12,
              children: [
                ui.TonalButton(
                  label: sheet.l10n.cancel,
                  onPressed: () => Navigator.of(sheet).pop(),
                ),
                Flexible(
                  child: ui.TonalButton(
                    label: running
                        ? sheet.l10n.closeAndContinue
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
  if (result == null) return null;
  if (await service.library.isSteamRunning()) await service.library.stopSteam();
  return result;
}

class _HistoryForm extends StatefulWidget {
  const _HistoryForm({required this.arch});
  final String arch;
  @override
  State<_HistoryForm> createState() => _HistoryFormState();
}

class _HistoryFormState extends State<_HistoryForm> {
  late String _arch = widget.arch;
  int _limit = 0;
  bool _force = false;
  final _from = TextEditingController(), _to = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _save() {
    final from = _from.text.trim(), to = _to.text.trim();
    if (!validSteamHistoryDates(from, to)) {
      setState(() => _error = context.l10n.steamVersionInvalidFilter);
      return;
    }
    Navigator.of(context).pop((_arch, from, to, _limit, _force));
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: context.l10n.steamVersionHistory,
    onSave: _save,
    error: _error,
    children: [
      ui.generateSection(
        footer: context.l10n.steamVersionCacheHint,
        items: [
          ui.FormRowSwitch(
            title: context.l10n.steamVersionForceHistory,
            value: _force,
            onChanged: (v) => setState(() => _force = v),
          ),
          ui.FormRowSelect<String>(
            title: context.l10n.steamVersionArchitecture,
            value: _arch,
            options: const [('win64', 'win64'), ('win32', 'win32')],
            onChanged: (v) {
              if (v != null) setState(() => _arch = v);
            },
          ),
          ui.FormRow(
            title: context.l10n.steamVersionStartDate,
            trailing: ui.FormRowTextField(
              controller: _from,
              hintText: 'YYYYMMDD',
            ),
          ),
          ui.FormRow(
            title: context.l10n.steamVersionEndDate,
            trailing: ui.FormRowTextField(
              controller: _to,
              hintText: 'YYYYMMDD',
            ),
          ),
          ui.FormRowSelect<int>(
            title: context.l10n.steamVersionHistoryLimit,
            value: _limit,
            options: [
              (0, context.l10n.all),
              (20, '20'),
              (50, '50'),
              (100, '100'),
              (400, '400'),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _limit = v);
            },
          ),
        ],
      ),
    ],
  );
}

class _WaybackSettingsForm extends StatefulWidget {
  const _WaybackSettingsForm({required this.service});
  final SteamVersionService service;
  @override
  State<_WaybackSettingsForm> createState() => _WaybackSettingsFormState();
}

class _WaybackSettingsFormState extends State<_WaybackSettingsForm> {
  late final _address = TextEditingController(text: widget.service.waybackBase);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.setWaybackBase(_address.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = ui.appErrorText(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: context.l10n.steamVersionWaybackSettings,
    onSave: _save,
    saving: _saving,
    error: _error,
    children: [
      ui.generateSection(
        footer: context.l10n.steamVersionWaybackHint,
        items: [
          ui.FormRow(
            title: context.l10n.steamVersionWaybackAddress,
            trailing: ui.FormRowTextField(
              key: const ValueKey('steam-wayback-address'),
              controller: _address,
              enabled: !_saving,
              keyboardType: TextInputType.url,
            ),
          ),
          ui.DecorationListItem(
            title: Text(context.l10n.steamVersionWaybackDefault),
            onPressed: _saving
                ? null
                : () => setState(
                    () =>
                        _address.text = SteamVersionService.defaultWaybackBase,
                  ),
          ),
        ],
      ),
      ui.ListFooter(text: context.l10n.steamVersionCacheHint),
    ],
  );
}
