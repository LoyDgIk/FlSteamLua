import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/game_entry.dart';
import '../../core/storage_manager.dart';
import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import '../steam/steam_close_action.dart';
import 'cloud_service.dart';
import 'cloud_redirect_plugin_page.dart';
import '../../ui/localization.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({
    super.key,
    required this.service,
    this.game,
    this.games = const [],
    this.tasks,
    this.steamProcess,
  });
  final CloudService service;
  final GameEntry? game;
  final List<GameEntry> games;
  final TaskCenter? tasks;
  final SteamProcessActions? steamProcess;

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  late final ui.AppBarSearchState _search = ui.AppBarSearchState(
    onSearch: (value) => setState(() => _query = value.trim().toLowerCase()),
  );
  String _query = '';

  CloudService get service => widget.service;

  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _run(
            context.l10n.loadCloudSaves,
            (_) => service.refresh(),
            announce: false,
          ),
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant CloudPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != service) {
      oldWidget.service.removeListener(_changed);
      service.addListener(_changed);
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

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext?) action, {
    bool announce = true,
    bool requiresStoppedSteam = false,
  }) async {
    final localeText = context.l10n;
    final steam = widget.steamProcess;
    if (requiresStoppedSteam &&
        steam != null &&
        !await confirmAndStopSteam(context, steam)) {
      return;
    }
    try {
      if (widget.tasks != null) {
        await widget.tasks!.run(
          title,
          (context) => action(context),
          appId: widget.game?.appId,
        );
      } else {
        await action(null);
      }
      if (mounted && announce) {
        ui.showAppSuccess(context, localeText.completed2);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  String _gameName(int appId) => widget.game?.appId == appId
      ? widget.game!.name
      : widget.games.where((game) => game.appId == appId).firstOrNull?.name ??
            'App $appId';

  @override
  Widget build(BuildContext context) {
    final saves = service.saves
        .where(
          (save) => widget.game == null || save.appId == widget.game!.appId,
        )
        .toList();
    final visible = saves.where(_matchesSearch).toList();
    visible.sort((a, b) {
      final gameOrder = _gameName(
        a.appId,
      ).toLowerCase().compareTo(_gameName(b.appId).toLowerCase());
      if (gameOrder != 0) return gameOrder;
      if (a.isRemote == b.isRemote) {
        return b.modifiedAt?.compareTo(a.modifiedAt ?? DateTime(0)) ?? 0;
      }
      return a.isRemote ? 1 : -1;
    });
    final searching = _query.isNotEmpty;
    return ui.CommonScaffold(
      title: widget.game == null
          ? context.l10n.cloudSaves
          : '${widget.game!.name} · ${context.l10n.cloudSaves}',
      searchState: _search,
      searchHint: context.l10n.searchGamesOrAppid,
      isLoading: service.loading,
      actions: [
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.clock,
          tooltip: context.l10n.saveBackups,
          onPressed: _showBackups,
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.refresh,
          tooltip: context.l10n.refresh,
          onPressed: service.loading
              ? null
              : () => _run(
                  context.l10n.refreshCloudSaves,
                  (context) => service.refresh(context: context),
                ),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.localSaveRedirection,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudSync),
                title: Text(context.l10n.localSaveRedirection),
                subtitle: Text(
                  service.status.enabled
                      ? context.l10n.enabledRestartSteamAfterChanges
                      : context
                            .l10n
                            .disabledEnablingDownloadsAndVerifiesTheCloudredirectDll,
                ),
                onPressed: () async {
                  final enabled = !service.status.enabled;
                  final localeText = context.l10n;
                  if (enabled &&
                      !await _confirm(
                        localeText.enableSaveRedirection,
                        localeText
                            .downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards,
                      )) {
                    return;
                  }
                  await _run(
                    localeText.configureRedirection,
                    (context) => enabled
                        ? service.enableRedirect(context: context)
                        : service.disableRedirect(),
                    requiresStoppedSteam: true,
                  );
                },
                trailing: ui.CommonSwitch(
                  value: service.status.enabled,
                  onChanged: (enabled) async {
                    final localeText = context.l10n;
                    if (enabled &&
                        !await _confirm(
                          localeText.enableSaveRedirection,
                          localeText
                              .downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards,
                        )) {
                      return;
                    }
                    await _run(
                      localeText.configureRedirection,
                      (context) => enabled
                          ? service.enableRedirect(context: context)
                          : service.disableRedirect(),
                      requiresStoppedSteam: true,
                    );
                  },
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                title: Text(context.l10n.localSaveFolder),
                subtitle: SelectableText(service.syncPath),
                onPressed: _choosePath,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                key: const ValueKey('cloud-plugin-management'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.layers),
                title: Text(context.l10n.cloudRedirectPlugin),
                subtitle: Text(
                  service.status.enabled
                      ? context.l10n.enabled
                      : context.l10n.notInstalled,
                ),
                onPressed: () => Navigator.of(context).push(
                  ui.buildAppPageRoute(
                    builder: (_) => CloudRedirectPluginPage(
                      service: service,
                      tasks: widget.tasks,
                      steamProcess: widget.steamProcess,
                    ),
                  ),
                ),
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: context.l10n.remoteStorage,
            items: [
              ui.DecorationListItem(
                key: const ValueKey('cloud-configure'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                title: Text(context.l10n.remoteStorage),
                subtitle: Text(
                  '${_providerName(context, service.provider)} · ${service.status.remoteSyncConfigured ? context.l10n.configured : context.l10n.remoteSyncIsNotConfigured}',
                ),
                onPressed: _configure,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              if (service.provider != 'folder') ...[
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.speed),
                  title: Text(context.l10n.testConnection),
                  onPressed: () => _run(
                    context.l10n.testCloudConnection,
                    (_) => service.testConnection(),
                  ),
                  trailing: const ui.GlyphIcon(
                    ui.AppGlyphs.chevronForward,
                    size: 18,
                  ),
                ),
                if (['gdrive', 'onedrive'].contains(service.provider))
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.account),
                    title: Text(context.l10n.authorize),
                    onPressed: () => _run(
                      context.l10n.connectCloudAccount,
                      (context) =>
                          service.authorize(service.provider, context: context),
                    ),
                    trailing: const ui.GlyphIcon(
                      ui.AppGlyphs.chevronForward,
                      size: 18,
                    ),
                  ),
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.close),
                  title: Text(context.l10n.disconnect),
                  onPressed: () async {
                    final localeText = context.l10n;
                    if (await _confirm(
                      localeText.disconnectAccount,
                      localeText.removeLocalCredentialsRemoteSavesRemain,
                    )) {
                      await _run(
                        localeText.disconnectAccount2,
                        (_) => service.signOut(service.provider),
                      );
                    }
                  },
                  trailing: const ui.GlyphIcon(
                    ui.AppGlyphs.chevronForward,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
          if (service.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ui.CommonCard(
                isError: true,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(service.lastError!),
                ),
              ),
            ),
          if (visible.isEmpty && !service.loading)
            SizedBox(
              height: 360,
              child: ui.NullStatus(
                label: searching
                    ? context.l10n.noSearchResults
                    : context.l10n.noRedirectedSavesFound,
                description: searching
                    ? context.l10n.searchGamesOrAppid
                    : context
                          .l10n
                          .chooseAFolderOrConnectRemoteStoragePlayAGameWithRedirectionEnabledToCreateSaves,
                illustration: searching
                    ? ui.NullStatusIllustration.search
                    : ui.NullStatusIllustration.data,
              ),
            )
          else
            ui.generateSection(
              title: context.l10n.gameSaves,
              items: [for (final save in visible) _saveRow(save)],
            ),
        ],
      ),
    );
  }

  bool _matchesSearch(CloudSave save) {
    if (_query.isEmpty) return true;
    final gameName = _gameName(save.appId).toLowerCase();
    return gameName.contains(_query) ||
        save.appId.toString().contains(_query) ||
        save.accountId.toLowerCase().contains(_query) ||
        save.path.toLowerCase().contains(_query) ||
        (save.isRemote ? context.l10n.remote : context.l10n.local)
            .toLowerCase()
            .contains(_query);
  }

  Widget _saveRow(CloudSave save) => ui.DecorationListItem(
    leading: ui.GlyphIcon(
      save.isRemote ? ui.AppGlyphs.cloudDownload : ui.AppGlyphs.resources,
      size: 20,
    ),
    title: Text(_gameName(save.appId)),
    subtitle: Text(
      '${save.isRemote ? context.l10n.remote : context.l10n.local} · ${save.accountId} · ${save.fileCount} ${context.l10n.files} · ${formatStorageBytes(save.size)}\n${save.path}',
    ),
    onPressed: () => _saveAction(save.isRemote ? 'download' : 'open', save),
    trailing: ui.CommonPopupBox(
      targetBuilder: (open) => IconButton(
        tooltip: context.l10n.manage,
        onPressed: open,
        icon: const ui.GlyphIcon(ui.AppGlyphs.more, size: 20),
      ),
      popupBuilder: (_) => ui.CommonPopupMenu(
        items: [
          if (!save.isRemote)
            ui.CommonPopupMenuItem(
              label: context.l10n.openFolder,
              glyph: ui.AppGlyphs.resources,
              onPressed: () => _saveAction('open', save),
            ),
          ui.CommonPopupMenuItem(
            label: context.l10n.backUpThisGame,
            glyph: ui.AppGlyphs.layers,
            onPressed: () => _saveAction('backup', save),
          ),
          if (save.isRemote)
            ui.CommonPopupMenuItem(
              label: context.l10n.downloadToFolder,
              glyph: ui.AppGlyphs.cloudDownload,
              onPressed: () => _saveAction('download', save),
            ),
          if (!save.isRemote && service.provider != 'folder')
            ui.CommonPopupMenuItem(
              label: context.l10n.uploadToRemote,
              glyph: ui.AppGlyphs.upload,
              onPressed: () => _saveAction('upload', save),
            ),
          ui.CommonPopupMenuItem(
            label: context.l10n.previewDeletion,
            glyph: ui.AppGlyphs.delete,
            danger: true,
            onPressed: () => _saveAction('delete', save),
          ),
        ],
      ),
    ),
  );

  Future<bool> _confirm(String title, String message) async =>
      await ui.AppDialogs.confirm(context, title: title, message: message) ??
      false;

  Future<void> _choosePath() async {
    final localeText = context.l10n;
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: localeText.chooseSaveFolder,
    );
    if (path == null) return;
    if (!await _confirm(
      localeText.changeSaveFolder,
      localeText
          .closeSteamAndAllGamesThenChooseAnEmptyFolderCurrentSavesWillBeCopiedToTheNewFolderAnd,
    )) {
      return;
    }
    await _run(
      localeText.setSaveFolder,
      (context) => service.setSyncPath(path, context: context),
    );
  }

  Future<void> _saveAction(String action, CloudSave save) async {
    final localeText = context.l10n;
    if (action == 'open') {
      try {
        await service.openSave(save);
      } catch (error) {
        if (mounted) ui.showAppError(context, error);
      }
      return;
    }
    if (action == 'backup') {
      await _run(localeText.backUpSaves, (context) async {
        await service.backup(save.appId, context: context);
      });
      return;
    }
    if (action == 'download') {
      final folder = await FilePicker.platform.getDirectoryPath();
      if (folder != null) {
        await _run(
          localeText.downloadSaves,
          (context) => service.download(
            save,
            p.join(folder, save.accountId, '${save.appId}'),
            context: context,
          ),
        );
      }
      return;
    }
    if (action == 'upload') {
      if (await _confirm(
        localeText.uploadSaves,
        localeText.remoteFilesWithTheSameNamesWillBeReplacedCloseTheGameFirst,
      )) {
        await _run(
          localeText.uploadSaves,
          (context) => service.upload(save, context: context),
        );
      }
      return;
    }
    if (action == 'delete') {
      await _run(localeText.prepareDeletionPreview, (task) async {
        final preview = await service.previewDelete(save.appId, context: task);
        if (!mounted) return;
        final confirmed = await _confirm(
          localeText.deleteThisGameSSaves,
          '${localeText.aCompleteBackupIsCreatedBeforeDeleting}\n\n${preview.targets.map((target) => '${target.kind}: ${target.path}\n${target.fileCount} files · ${target.size} bytes').join('\n\n')}\n\n${localeText.backupLocation}: ${preview.backupDirectory}',
        );
        if (confirmed) await service.delete(preview, context: task);
      });
    }
  }

  Future<void> _showBackups() async {
    final localeText = context.l10n;
    try {
      final backup = await ui.showModalSideSheet<CloudBackup>(
        context: context,
        builder: (_) => _CloudBackupsSheet(
          service: service,
          appId: widget.game?.appId,
          gameName: _gameName,
        ),
      );
      if (backup == null || !mounted) return;
      if (await _confirm(
        localeText.restoreBackup,
        localeText
            .restoreToTheCurrentConfiguredLocationsExistingLocalSavesArePreservedInAPreRestoreBack,
      )) {
        await _run(
          localeText.restoreSaves,
          (task) => service.restore(backup, context: task),
        );
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _configure() async {
    final localeText = context.l10n;
    try {
      final selected = service.provider;
      final initial = selected == 'folder'
          ? <String, dynamic>{}
          : await service.providerConfiguration(selected) ?? {};
      if (!mounted) return;
      final values = await ui.showFormSheet<(String, Map<String, dynamic>)>(
        context: context,
        builder: (_) => _CloudProviderForm(
          initialProvider: selected,
          initialValues: initial,
        ),
      );
      if (values != null) {
        await _run(
          localeText.saveCloudConfiguration,
          (_) => service.configureProvider(values.$1, values.$2),
        );
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }
}

class _CloudBackupsSheet extends StatefulWidget {
  const _CloudBackupsSheet({
    required this.service,
    required this.appId,
    required this.gameName,
  });

  final CloudService service;
  final int? appId;
  final String Function(int appId) gameName;

  @override
  State<_CloudBackupsSheet> createState() => _CloudBackupsSheetState();
}

class _CloudBackupsSheetState extends State<_CloudBackupsSheet> {
  late final ui.AppBarSearchState _search = ui.AppBarSearchState(
    onSearch: (value) => setState(() => _query = value.trim().toLowerCase()),
  );
  late Future<List<CloudBackup>> _backups = widget.service.backups(
    appId: widget.appId,
  );
  String _query = '';

  void _reload() {
    setState(() {
      _backups = widget.service.backups(appId: widget.appId);
    });
  }

  bool _matches(CloudBackup backup) {
    if (_query.isEmpty) return true;
    return widget.gameName(backup.appId).toLowerCase().contains(_query) ||
        backup.appId.toString().contains(_query) ||
        backup.path.toLowerCase().contains(_query) ||
        backup.createdAt.toLocal().toString().toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CloudBackup>>(
    future: _backups,
    builder: (context, snapshot) {
      final all = snapshot.data ?? const <CloudBackup>[];
      final backups = all.where(_matches).toList();
      final grouped = <int, List<CloudBackup>>{};
      for (final backup in backups) {
        grouped.putIfAbsent(backup.appId, () => []).add(backup);
      }
      final groups = grouped.entries.toList()
        ..sort(
          (a, b) => widget
              .gameName(a.key)
              .toLowerCase()
              .compareTo(widget.gameName(b.key).toLowerCase()),
        );
      return ui.SideSheetScaffold(
        title: context.l10n.saveBackups,
        searchState: _search,
        actions: [
          ui.SideSheetHeaderButton(
            tooltip: context.l10n.refresh,
            onPressed: snapshot.connectionState == ConnectionState.waiting
                ? null
                : _reload,
            icon: const ui.GlyphIcon(ui.AppGlyphs.refresh, size: 24),
          ),
        ],
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            ui.SideSheetScaffold.headerHeight + 16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: ui.NullStatusSwitcher(
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            isEmpty: all.isEmpty || snapshot.hasError,
            isSearching: _query.isNotEmpty && !snapshot.hasError,
            nullStatus: snapshot.hasError
                ? ui.NullStatus(
                    label: context.l10n.failed,
                    description: '${snapshot.error}',
                    illustration: ui.NullStatusIllustration.error,
                  )
                : ui.NullStatus(
                    label: context.l10n.noBackupsYet,
                    illustration: ui.NullStatusIllustration.data,
                  ),
            searchStatus: ui.NullStatus(
              label: context.l10n.noSearchResults,
              illustration: ui.NullStatusIllustration.search,
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in groups) ...[
                  ui.generateSection(
                    title: widget.gameName(group.key),
                    items: [
                      for (final backup in group.value)
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.layers,
                            size: 20,
                          ),
                          title: Text(backup.createdAt.toLocal().toString()),
                          subtitle: Text(
                            '${backup.fileCount} ${context.l10n.files} · ${formatStorageBytes(backup.size)}\n${backup.path}',
                          ),
                          onPressed: () => Navigator.of(context).pop(backup),
                          trailing: ui.TonalButton(
                            size: ui.TonalButtonSize.compact,
                            glyph: ui.AppGlyphs.undo,
                            label: context.l10n.restore,
                            onPressed: () => Navigator.of(context).pop(backup),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _CloudProviderForm extends StatefulWidget {
  const _CloudProviderForm({
    required this.initialProvider,
    required this.initialValues,
  });

  final String initialProvider;
  final Map<String, dynamic> initialValues;

  @override
  State<_CloudProviderForm> createState() => _CloudProviderFormState();
}

class _CloudProviderFormState extends State<_CloudProviderForm> {
  static const _fields = [
    'url',
    'username',
    'password',
    'bearer_token',
    'account_id',
    'access_key_id',
    'secret_access_key',
    'bucket',
    'endpoint',
    'region',
    'key_prefix',
    'extra_headers',
    'timeout_sec',
  ];

  static const _connectionFields = {
    'webdav': ['url'],
    's3': ['endpoint', 'region', 'bucket'],
    'r2': ['account_id', 'endpoint', 'bucket'],
  };

  static const _credentialFields = {
    'webdav': ['username', 'password', 'bearer_token'],
    's3': ['access_key_id', 'secret_access_key'],
    'r2': ['access_key_id', 'secret_access_key'],
  };

  static const _advancedFields = {
    'webdav': ['key_prefix', 'extra_headers', 'timeout_sec'],
    's3': ['key_prefix'],
    'r2': ['key_prefix'],
  };

  late String _provider = widget.initialProvider;
  late String _auth = widget.initialValues['auth'] as String? ?? 'basic';
  late bool _allowHttp = widget.initialValues['allow_insecure_http'] == true;
  late bool _allowInsecureTls =
      widget.initialValues['allow_insecure_tls'] == true;
  late bool _signPayload = widget.initialValues['sign_payload'] == true;
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      final value = widget.initialValues[field];
      _controllers[field] = TextEditingController(
        text: value is List ? value.join('\n') : value?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _fieldLabel(BuildContext context, String field) => switch (field) {
    'url' => context.l10n.url,
    'username' => context.l10n.accountName,
    'password' => context.l10n.password,
    'bearer_token' => 'Bearer token',
    'account_id' => context.l10n.accountId,
    'access_key_id' => context.l10n.accessKeyId,
    'secret_access_key' => context.l10n.secretAccessKey,
    'bucket' => context.l10n.bucket,
    'endpoint' => context.l10n.endpoint,
    'region' => context.l10n.region,
    'key_prefix' => context.l10n.keyPrefix,
    'extra_headers' => context.l10n.extraHeaders,
    'timeout_sec' => context.l10n.timeoutSeconds,
    _ => field,
  };

  Widget _fieldRow(String field) {
    final controller = _controllers[field]!;
    final secret = {
      'password',
      'bearer_token',
      'secret_access_key',
    }.contains(field);
    final fieldWidget = secret
        ? ui.FormRowSecretTextField(
            controller: controller,
            hintText: context.l10n.optional,
          )
        : ui.FormRowTextField(
            controller: controller,
            hintText: context.l10n.optional,
            keyboardType: field == 'timeout_sec'
                ? TextInputType.number
                : field == 'url' || field == 'endpoint'
                ? TextInputType.url
                : TextInputType.text,
            maxLines: field == 'extra_headers' ? 3 : 1,
          );
    return ui.FormRow(
      title: _fieldLabel(context, field),
      trailing: fieldWidget,
    );
  }

  Widget _section(String title, Iterable<String> fields) {
    return ui.generateSection(
      title: title,
      items: [for (final field in fields) _fieldRow(field)],
    );
  }

  void _save() {
    final fields = [
      ...?_connectionFields[_provider],
      ...?_credentialFields[_provider],
      ...?_advancedFields[_provider],
    ];
    final result = <String, dynamic>{
      for (final field in fields) field: _controllers[field]!.text,
    };
    if (_provider == 'webdav') {
      result['auth'] = _auth;
      result['allow_insecure_tls'] = _allowInsecureTls;
      final timeout = _controllers['timeout_sec']!.text.trim();
      result['timeout_sec'] = timeout.isEmpty
          ? 30
          : int.tryParse(timeout) ?? -1;
    }
    result['allow_insecure_http'] = _allowHttp;
    result['sign_payload'] = _signPayload;
    Navigator.of(context).pop((_provider, result));
  }

  @override
  Widget build(BuildContext context) {
    final connectionFields = _connectionFields[_provider] ?? const <String>[];
    final credentialFields = _credentialFields[_provider] ?? const <String>[];
    final advancedFields = _advancedFields[_provider] ?? const <String>[];
    return ui.FormPage(
      title: context.l10n.configureStorage,
      onSave: _save,
      children: [
        ui.generateSection(
          title: context.l10n.basicInfo,
          items: [
            ui.FormRowSelect<String>(
              title: context.l10n.provider,
              value: _provider,
              options: [
                for (final provider in CloudService.providers)
                  (provider, _providerName(context, provider)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _provider = value);
              },
            ),
            if (_provider == 'webdav')
              ui.FormRowSelect<String>(
                title: context.l10n.authentication,
                value: _auth,
                options: [
                  for (final value in [
                    'basic',
                    'auto',
                    'digest',
                    'ntlm',
                    'negotiate',
                    'bearer',
                    'none',
                  ])
                    (value, value),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _auth = value);
                },
              ),
            for (final field in connectionFields) _fieldRow(field),
          ],
        ),
        if (['gdrive', 'onedrive'].contains(_provider))
          ui.ListFooter(
            text: context.l10n.saveThenChooseAuthorizeToSignInUsingYourBrowser,
          ),
        if (_provider == 'webdav' && ['ntlm', 'negotiate'].contains(_auth))
          ui.ListFooter(
            text: context
                .l10n
                .usesTheWindowsCredentialsEnteredBelowDomainUsernameOrUsernameDomain,
          ),
        if (credentialFields.isNotEmpty)
          _section(context.l10n.credentials, credentialFields),
        if (advancedFields.isNotEmpty ||
            ['webdav', 's3', 'r2'].contains(_provider))
          ui.generateSection(
            title: context.l10n.advanced,
            items: [
              for (final field in advancedFields) _fieldRow(field),
              ui.FormRowSwitch(
                title: context
                    .l10n
                    .allowHttpCredentialsAndSavesAreSentWithoutEncryption,
                value: _allowHttp,
                onChanged: (value) => setState(() => _allowHttp = value),
              ),
              if (_provider == 'webdav')
                ui.FormRowSwitch(
                  title: context
                      .l10n
                      .skipTlsCertificateValidationUnsafeTrustedSelfHostedServersOnly,
                  value: _allowInsecureTls,
                  onChanged: (value) =>
                      setState(() => _allowInsecureTls = value),
                ),
              if (['s3', 'r2'].contains(_provider))
                ui.FormRowSwitch(
                  title: context.l10n.signRequestPayload,
                  value: _signPayload,
                  onChanged: (value) => setState(() => _signPayload = value),
                ),
            ],
          ),
      ],
    );
  }
}

String _providerName(BuildContext context, String provider) =>
    switch (provider) {
      'folder' => context.l10n.localFolder,
      'gdrive' => 'Google Drive',
      'onedrive' => 'OneDrive',
      'r2' => 'Cloudflare R2',
      's3' => 'S3',
      'webdav' => 'WebDAV',
      _ => provider,
    };
