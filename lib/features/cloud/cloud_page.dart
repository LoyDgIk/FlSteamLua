import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/game_entry.dart';
import '../../core/steam_process_actions.dart';
import '../../core/storage_manager.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/localization.dart';
import '../patching/ticket_authorization.dart';
import '../library/library_service.dart';
import '../steam_protocol/steam_avatar.dart';
import 'cloud_service.dart';
import 'cloud_backups_sheet.dart';
import 'cloud_storage_page.dart';
import 'cloud_redirect_plugin_page.dart';
import 'cloud_workflows.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({
    super.key,
    required this.service,
    this.game,
    this.games = const [],
    this.tasks,
    this.steamProcess,
    this.library,
  });
  final CloudService service;
  final GameEntry? game;
  final List<GameEntry> games;
  final TaskCenter? tasks;
  final SteamProcessActions? steamProcess;
  final LibraryService? library;
  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  late final _search = ui.AppBarSearchState(
    onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
  );
  String _query = '', _account = '', _location = 'all';
  CloudService get service => widget.service;
  Map<String, ({SteamLocalAccount account, String? avatar})> _accounts = {};
  void _readAccounts() {
    final library = widget.library;
    _accounts = {
      if (library != null)
        for (final account in library.accounts)
          (BigInt.parse(account.steamId) & BigInt.from(0xffffffff)).toString():
              (account: account, avatar: library.avatarPath(account)),
    };
  }

  void _accountsChanged() {
    if (mounted) setState(_readAccounts);
  }

  String _accountLabel(String id) {
    final account = _accounts[id]?.account;
    return account == null
        ? id
        : account.personaName.isNotEmpty
        ? account.personaName
        : account.accountName;
  }

  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    _readAccounts();
    widget.library?.addListener(_accountsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialLoad());
    });
  }

  Future<void> _initialLoad() async {
    if (widget.steamProcess != null && await widget.steamProcess!.isRunning()) {
      final steamId = WindowsTicketRegistry.activeSteamId();
      if (steamId != null && mounted) {
        _account = (BigInt.parse(steamId) & BigInt.from(0xffffffff)).toString();
      }
    }
    if (!mounted) return;
    await _refresh();
  }

  @override
  void didUpdateWidget(covariant CloudPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library != widget.library) {
      oldWidget.library?.removeListener(_accountsChanged);
      widget.library?.addListener(_accountsChanged);
      _readAccounts();
    }
    if (oldWidget.service != service) {
      oldWidget.service.removeListener(_changed);
      service.addListener(_changed);
    }
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    widget.library?.removeListener(_accountsChanged);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await runCloudOperation(
      context,
      service,
      title: context.l10n.refreshCloudSaves,
      tasks: widget.tasks,
      appId: widget.game?.appId,
      mutation: false,
      announce: false,
      action: (task) =>
          service.refresh(appId: widget.game?.appId, context: task),
    );
  }

  String _gameName(int id) => widget.game?.appId == id
      ? widget.game!.name
      : widget.games.where((v) => v.appId == id).firstOrNull?.name ?? 'App $id';
  void _backups([int? appId]) => ui.showModalSideSheet(
    context: context,
    builder: (_) => CloudBackupsSheet(
      service: service,
      appId: appId ?? widget.game?.appId,
      gameName: _gameName,
      tasks: widget.tasks,
      steam: widget.steamProcess,
    ),
  );
  Future<void> _storages() async {
    final browsed = await Navigator.of(context).push(
      ui.buildAppPageRoute(
        builder: (_) => CloudStoragePage(
          service: service,
          appId: widget.game?.appId,
          tasks: widget.tasks,
          steam: widget.steamProcess,
        ),
      ),
    );
    if (mounted && browsed != true) await _refresh();
  }

  void _showGame(int appId, String account) => ui.showModalSideSheet(
    context: context,
    builder: (_) => _GameSaveSheet(
      service: service,
      appId: appId,
      account: account,
      name: _gameName(appId),
      tasks: widget.tasks,
      steam: widget.steamProcess,
    ),
  );
  Future<void> _filterAccount() async {
    final accounts = {
      ..._accounts.keys,
      ...service.saves.map((v) => v.accountId),
    }.toList()..sort();
    final selected = await ui.showModalSideSheet<String>(
      context: context,
      builder: (sheet) => ui.SideSheetScaffold(
        title: context.l10n.cloudAccountFilter,
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
                for (final id in ['', ...accounts])
                  ui.DecorationListItem(
                    leading: id.isEmpty
                        ? const ui.GlyphIcon(ui.AppGlyphs.account)
                        : SteamAvatar(path: _accounts[id]?.avatar, size: 28),
                    title: Text(
                      id.isEmpty
                          ? sheet.l10n.cloudAllAccounts
                          : _accountLabel(id),
                    ),
                    subtitle: id.isNotEmpty && _accounts.containsKey(id)
                        ? Text(id)
                        : null,
                    trailing: id == _account
                        ? const ui.GlyphIcon(ui.AppGlyphs.checkCircle)
                        : null,
                    onPressed: () => Navigator.of(sheet).pop(id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _account = selected);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <(int, String), List<CloudSave>>{};
    for (final save in service.saves) {
      if (widget.game != null && save.appId != widget.game!.appId ||
          save.storageId != service.browsingStorageId ||
          _account.isNotEmpty && save.accountId != _account) {
        continue;
      }
      if (_location == 'local' && save.isRemote ||
          _location == 'remote' && !save.isRemote) {
        continue;
      }
      if (!'${_gameName(save.appId)} ${save.appId} ${save.accountId}'
          .toLowerCase()
          .contains(_query)) {
        continue;
      }
      groups.putIfAbsent((save.appId, save.accountId), () => []).add(save);
    }
    final rows = groups.entries.toList()
      ..sort((a, b) => _gameName(a.key.$1).compareTo(_gameName(b.key.$1)));
    final status = service.status;
    return ui.CommonScaffold(
      title: widget.game == null
          ? context.l10n.cloudSaves
          : '${widget.game!.name} · ${context.l10n.cloudSaves}',
      searchState: _search,
      searchHint: context.l10n.searchGamesOrAppid,
      isLoading: service.loading,
      actions: [
        ui.DashboardIconButton(
          key: const ValueKey('cloud-account-filter'),
          glyph: ui.AppGlyphs.account,
          selected: _account.isNotEmpty,
          iconSize: _account.isEmpty ? 18 : 28,
          icon: _account.isEmpty
              ? null
              : SteamAvatar(
                  key: ValueKey('cloud-avatar-$_account'),
                  path: _accounts[_account]?.avatar,
                  size: 28,
                ),
          tooltip: _account.isEmpty
              ? context.l10n.cloudAllAccounts
              : '${context.l10n.cloudAccountFilter} · ${_accountLabel(_account)} ($_account)',
          onPressed: _filterAccount,
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.clock,
          tooltip: context.l10n.saveBackups,
          onPressed: () => _backups(),
        ),
        ui.DashboardIconButton(
          key: const ValueKey('cloud-configure'),
          glyph: ui.AppGlyphs.settings,
          tooltip: context.l10n.cloudStorages,
          onPressed: service.busy ? null : _storages,
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.refresh,
          tooltip: context.l10n.refresh,
          onPressed: service.loading || service.busy ? null : _refresh,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, ui.pageContentTopInset, 16, 24),
        children: [
          ui.generateSection(
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                title: Text(
                  '${context.l10n.cloudBrowsing} · ${service.browsingStorage.name}',
                ),
                subtitle: Text(
                  '${context.l10n.cloudActiveTarget} · ${service.storage(service.activeStorageId).name}',
                ),
                onPressed: service.busy ? null : _storages,
                trailing: ui.MetaChip(
                  label: status.pendingRestart
                      ? context.l10n.cloudPendingRestart
                      : status.enabled
                      ? context.l10n.configurationEnabled
                      : context.l10n.disabled,
                ),
              ),
              ui.DecorationListItem(
                key: const ValueKey('cloud-plugin-management'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.layers),
                title: Text(context.l10n.cloudRedirectPlugin),
                subtitle: Text(
                  !status.pluginInstalled
                      ? context.l10n.notInstalled
                      : !status.coreReady
                      ? context.l10n.cloudCoreMissing
                      : context.l10n.cloudCoreReady,
                ),
                trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                onPressed: () => Navigator.of(context).push(
                  ui.buildAppPageRoute(
                    builder: (_) => CloudRedirectPluginPage(
                      service: service,
                      tasks: widget.tasks,
                      steamProcess: widget.steamProcess,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ui.SegmentedControl<String>(
              segments: [
                ('all', context.l10n.cloudAllLocations),
                ('local', context.l10n.local),
                ('remote', context.l10n.remote),
              ],
              value: _location,
              onChanged: (v) => setState(() => _location = v),
            ),
          ),
          if (service.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ui.CommonCard(
                isError: true,
                inert: true,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  '${context.l10n.cloudLoadFailedRetained}\n${service.lastError}',
                ),
              ),
            ),
          if (rows.isEmpty && !service.loading)
            SizedBox(
              height: 300,
              child: ui.NullStatus(
                label: _query.isNotEmpty
                    ? context.l10n.noSearchResults
                    : context.l10n.noRedirectedSavesFound,
                illustration: _query.isNotEmpty
                    ? ui.NullStatusIllustration.search
                    : ui.NullStatusIllustration.data,
              ),
            ),
          ui.AnimatedEntries(
            grouped: true,
            children: [
              for (final row in rows)
                ui.DecorationListItem(
                  key: ValueKey('cloud-game-${row.key.$1}-${row.key.$2}'),
                  leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                  title: Text(_gameName(row.key.$1)),
                  subtitle: Text(
                    '${row.key.$2} · ${row.value.map((v) => cloudLocationName(context, v.location.name)).join(' / ')}',
                  ),
                  trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                  onPressed: () => _showGame(row.key.$1, row.key.$2),
                ),
            ],
          ),
          if (service.checkedAt != null)
            ui.ListFooter(
              text:
                  '${context.l10n.cloudLastChecked} · ${service.checkedAt!.toLocal().toString().split('.').first}',
            ),
        ],
      ),
    );
  }
}

class _GameSaveSheet extends StatefulWidget {
  const _GameSaveSheet({
    required this.service,
    required this.appId,
    required this.account,
    required this.name,
    this.tasks,
    this.steam,
  });
  final CloudService service;
  final int appId;
  final String account, name;
  final TaskCenter? tasks;
  final SteamProcessActions? steam;
  @override
  State<_GameSaveSheet> createState() => _GameSaveSheetState();
}

class _GameSaveSheetState extends State<_GameSaveSheet> {
  CloudService get service => widget.service;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<CloudSave> get _saves => service.saves
      .where(
        (v) =>
            v.appId == widget.appId &&
            v.accountId == widget.account &&
            v.storageId == service.browsingStorageId,
      )
      .toList();
  Future<void> _action(String action, CloudSave save) async {
    setState(() => _busy = true);
    try {
      if (action == 'open') {
        await service.openSave(save);
        return;
      }
      if (action == 'files') {
        await ui.showModalSideSheet(
          context: context,
          builder: (_) => CloudFilesSheet(
            title: context.l10n.cloudLoadFiles,
            load: () => service.inspectSave(save),
          ),
        );
        return;
      }
      String title;
      Future<void> Function(TaskContext?) operation;
      var backup = false;
      var stop = false;
      String? explanation;
      final details = <(String, String)>[
        (context.l10n.cloudGameAccount, '${widget.name} · ${save.accountId}'),
        (cloudLocationName(context, save.location.name), save.path),
      ];
      if (action == 'backup') {
        title = context.l10n.backUpThisGame;
        stop = !save.isRemote;
        operation = (task) async {
          await service.backup(save.appId, selection: save, context: task);
        };
      } else if (action == 'delete') {
        title = context.l10n.deleteThisGameSSaves;
        stop = true;
        backup = true;
        final preview = await service.previewDelete(
          save.appId,
          selection: save,
        );
        if (!mounted) return;
        details.add((
          context.l10n.files,
          '${preview.fileCount} · ${formatStorageBytes(preview.size)}',
        ));
        details.add((context.l10n.backupFolder, preview.backupDirectory));
        operation = (task) async {
          await service.delete(preview, context: task);
        };
      } else if (action == 'export') {
        title = context.l10n.cloudExportRepository;
        explanation = context.l10n.cloudExportHint;
        final folder = await FilePicker.platform.getDirectoryPath();
        if (folder == null || !mounted) return;
        final destination = p.join(folder, save.accountId, '${save.appId}');
        details.add((context.l10n.cloudDestination, destination));
        operation = (task) =>
            service.download(save, destination, context: task);
      } else if (action == 'upload') {
        title = context.l10n.cloudRepositoryCopy;
        stop = true;
        backup = true;
        final target = await service.targetFor(service.activeStorageId);
        if (!mounted) return;
        details.add((context.l10n.cloudDestination, target.summary));
        operation = (task) => service.upload(save, context: task);
      } else {
        title = context.l10n.cloudPull;
        stop = true;
        backup = true;
        explanation = context.l10n.cloudPullHint;
        final target = await service.targetFor(save.storageId);
        if (!mounted) return;
        details.add((
          context.l10n.cloudDestination,
          '${target.summary}\n${p.join(service.settings.steamPath, 'cloud_redirect', 'storage', save.accountId, '${save.appId}')}',
        ));
        operation = (task) async {
          await service.synchronize(save, context: task);
        };
      }
      if (!mounted) return;
      if (!await confirmCloudOperation(
        context,
        title: title,
        details: details,
        steam: widget.steam,
        stopSteam: stop,
        backup: backup,
        explanation: explanation,
      )) {
        return;
      }
      if (!mounted) return;
      await runCloudOperation(
        context,
        service,
        title: title,
        action: operation,
        tasks: widget.tasks,
        appId: save.appId,
        success: action == 'pull' ? context.l10n.cloudSyncVerified : null,
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _compare(CloudSave local, CloudSave remote) async {
    setState(() => _busy = true);
    try {
      final result = await service.compareRepository(local, remote);
      if (!mounted) return;
      await ui.showModalSideSheet(
        context: context,
        builder: (sheet) => ui.SideSheetScaffold(
          title: sheet.l10n.cloudCompare,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              ui.SideSheetScaffold.headerHeight + 16,
              16,
              24,
            ),
            children: [
              ui.ListFooter(text: sheet.l10n.cloudCompareHint),
              if (result.localOnly.isEmpty &&
                  result.remoteOnly.isEmpty &&
                  result.changed.isEmpty)
                ui.NullStatus(label: sheet.l10n.cloudManifestEqual),
              for (final group in [
                (sheet.l10n.cloudLocalOnly, result.localOnly),
                (sheet.l10n.cloudRemoteOnly, result.remoteOnly),
                (sheet.l10n.cloudChangedFiles, result.changed),
              ])
                if (group.$2.isNotEmpty)
                  ui.generateSection(
                    title: group.$1,
                    items: [
                      for (final file in group.$2)
                        ui.DecorationListItem(title: SelectableText(file)),
                    ],
                  ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saves = _saves;
    final local =
        saves.where((v) => v.location == CloudSaveLocation.cache).firstOrNull ??
        saves.where((v) => !v.isRemote).firstOrNull;
    final remote = saves.where((v) => v.isRemote).firstOrNull;
    final busy = _busy || service.busy;
    return ui.SideSheetScaffold(
      title: widget.name,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.saveBackups,
          icon: const ui.GlyphIcon(ui.AppGlyphs.clock),
          onPressed: () => ui.showModalSideSheet(
            context: context,
            builder: (_) => CloudBackupsSheet(
              service: service,
              appId: widget.appId,
              gameName: (_) => widget.name,
              tasks: widget.tasks,
              steam: widget.steam,
            ),
          ),
        ),
      ],
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
                title: Text(context.l10n.accountId),
                subtitle: Text('${widget.account} · App ${widget.appId}'),
              ),
            ],
          ),
          if (saves.isEmpty)
            ui.NullStatus(label: context.l10n.noRedirectedSavesFound),
          for (final save in saves)
            ui.generateSection(
              title: cloudLocationName(context, save.location.name),
              items: [
                ui.DecorationListItem(
                  title: SelectableText(save.path),
                  subtitle: Text(
                    save.detailsLoaded
                        ? '${save.fileCount} ${context.l10n.files} · ${formatStorageBytes(save.size)}'
                        : context.l10n.cloudLoadFiles,
                  ),
                  onPressed: busy ? null : () => _action('files', save),
                  trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                ),
                if (service.locationErrors[save.id] != null)
                  ui.DecorationListItem(
                    title: Text(context.l10n.failed),
                    subtitle: Text(service.locationErrors[save.id]!),
                  ),
                if (service.syncResults[save.id] != null)
                  ui.DecorationListItem(
                    title: Text(context.l10n.cloudSyncVerified),
                    subtitle: Text(
                      '${service.syncResults[save.id]!.at.toLocal()}',
                    ),
                  ),
                if (!save.isRemote)
                  ui.DecorationListItem(
                    title: Text(context.l10n.openFolder),
                    onPressed: busy ? null : () => _action('open', save),
                  ),
                ui.DecorationListItem(
                  title: Text(context.l10n.backUpThisGame),
                  onPressed: busy ? null : () => _action('backup', save),
                ),
                ui.DecorationListItem(
                  title: Text(context.l10n.cloudExportRepository),
                  onPressed: busy ? null : () => _action('export', save),
                ),
                if (save.isRemote)
                  ui.DecorationListItem(
                    title: Text(context.l10n.cloudPull),
                    subtitle: Text(
                      save.storageId != service.activeStorageId
                          ? context.l10n.cloudSyncActiveOnly
                          : context.l10n.cloudPullHint,
                    ),
                    onPressed:
                        busy ||
                            save.storageId != service.activeStorageId ||
                            !service.status.pluginInstalled
                        ? null
                        : () => _action('pull', save),
                  ),
                if (save.location == CloudSaveLocation.folder &&
                    service.provider != 'folder')
                  ui.DecorationListItem(
                    title: Text(context.l10n.cloudRepositoryCopy),
                    onPressed: busy ? null : () => _action('upload', save),
                  ),
                ui.DecorationListItem(
                  title: Text(context.l10n.previewDeletion),
                  onPressed: busy ? null : () => _action('delete', save),
                ),
              ],
            ),
          if (local != null && remote != null)
            ui.generateSection(
              items: [
                ui.DecorationListItem(
                  title: Text(context.l10n.cloudCompare),
                  onPressed: busy ? null : () => _compare(local, remote),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
