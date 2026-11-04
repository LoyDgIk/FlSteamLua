import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../steam/steam_close_action.dart';
import 'kernel_backup_sheet.dart';
import 'kernel_residual_sheet.dart';
import 'kernel_manifest_settings_page.dart';
import 'kernel_toml_channel_page.dart';
import 'kernel_service.dart';
import 'kernel_toml_sheet.dart';

String _kernelSwitchMessage(BuildContext context, KernelPackage package) {
  final message = context.l10n
      .currentKernelFilesWillBeBackedUpBeforeInstallingCloseSteamFirst(
        package.displayName,
      );
  final notes = package.releaseNotes.trim();
  return notes.isEmpty
      ? message
      : '$message\n\n${context.l10n.releaseAnnouncement}\n$notes';
}

class KernelSettingsPage extends StatefulWidget {
  const KernelSettingsPage({
    super.key,
    required this.service,
    required this.tasks,
    required this.settings,
    this.steamProcess,
  });

  final KernelService service;
  final TaskCenter tasks;
  final SettingsStore settings;
  final SteamProcessActions? steamProcess;

  @override
  State<KernelSettingsPage> createState() => _KernelSettingsPageState();
}

class _KernelSettingsPageState extends State<KernelSettingsPage> {
  bool _busy = false;
  KernelUpdateInfo? _updateInfo;

  KernelService get service => widget.service;

  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    widget.settings.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    try {
      await service.loadLocal();
      if (service.installed.installed &&
          service.sourceMode == KernelSourceMode.repository &&
          widget.settings.autoCheckKernelUpdate) {
        _updateInfo = service.updateInfo ?? await service.checkForUpdate();
      }
    } catch (error) {
      _showError(error);
    }
    if (mounted) setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    service.removeListener(_changed);
    widget.settings.removeListener(_changed);
    super.dispose();
  }

  Future<T?> _run<T>(
    String title,
    Future<T> Function(TaskContext task) action, {
    bool announce = true,
    bool requiresStoppedSteam = false,
  }) async {
    final localeText = context.l10n;
    final steam = widget.steamProcess;
    if (requiresStoppedSteam &&
        steam != null &&
        !await confirmAndStopSteam(context, steam)) {
      return null;
    }
    setState(() => _busy = true);
    Future<T> invoke() => widget.tasks.run(title, action);
    try {
      final result = await invoke();
      if (mounted && announce) {
        ui.showAppSuccess(context, localeText.operationCompleted);
      }
      return result;
    } on SteamRunningException {
      final steam = widget.steamProcess;
      if (steam == null || !mounted) {
        _showError(const SteamRunningException());
        return null;
      }
      try {
        if (!await confirmAndStopSteam(context, steam)) return null;
        final result = await invoke();
        if (mounted && announce) {
          ui.showAppSuccess(context, localeText.operationCompleted);
        }
        return result;
      } on TaskCancelled {
        if (mounted) {
          ui.showAppFeedback(context, localeText.operationCancelled);
        }
      } catch (error) {
        _showError(error);
      }
    } on TaskCancelled {
      if (mounted) {
        ui.showAppFeedback(context, localeText.operationCancelled);
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  Future<bool> _confirm(String title, String message) async =>
      await ui.AppDialogs.confirm(
        context,
        title: title,
        message: message,
        confirmText: context.l10n.continueLabel,
      ) ??
      false;

  Future<void> _refresh() async {
    if (service.sourceMode == KernelSourceMode.local) return;
    await _run(
      context.l10n.refreshKernelReleases,
      (task) => service.refresh(context: task),
    );
  }

  Future<void> _showAvailablePackages() async {
    await ui.showModalSideSheet<void>(
      context: context,
      builder: (_) => _KernelPackagesSheet(
        service: service,
        tasks: widget.tasks,
        steamProcess: widget.steamProcess,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _setSourceMode(KernelSourceMode mode) async {
    if (service.sourceMode == mode || _busy) return;
    await service.setSourceMode(mode);
    _updateInfo = null;
    if (mounted) setState(() {});
  }

  Future<void> _editRepository() async {
    final result = await ui.showFormSheet<String>(
      context: context,
      builder: (_) =>
          _KernelRepositoryForm(initialValue: service.repositorySlug),
    );
    if (result == null || !mounted) return;
    await service.setRepository(result);
    await _refresh();
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    await _run(
      context.l10n.importKernelPackage,
      (task) => service.importLocal(path, context: task),
    );
  }

  Future<void> _checkForUpdate() async {
    if (service.sourceMode == KernelSourceMode.local) {
      ui.showAppFeedback(context, context.l10n.kernelLocalNoUpdates);
      return;
    }
    final info = await _run(
      context.l10n.checkKernelUpdate,
      (task) => service.checkForUpdate(context: task),
      announce: false,
    );
    if (!mounted || info == null) return;
    _updateInfo = info;
    setState(() {});
    if (!info.hasUpdate) {
      ui.showAppFeedback(context, context.l10n.kernelNoUpdate);
    }
  }

  Future<void> _installOrUpdate() async {
    if (service.sourceMode == KernelSourceMode.local) {
      await _import();
      return;
    }
    final localeText = context.l10n;
    final info = await _run(
      localeText.checkKernelUpdate,
      (task) => service.checkForUpdate(context: task),
      announce: false,
    );
    if (!mounted || info == null) return;
    _updateInfo = info;
    if (!info.hasUpdate && service.installed.installed) {
      ui.showAppFeedback(context, localeText.kernelNoUpdate);
      return;
    }
    final package = info.package;
    if (!await _confirm(
      localeText.installOrUpdateKernel,
      _kernelSwitchMessage(context, package),
    )) {
      return;
    }
    await _switch(package, confirm: false);
  }

  Future<void> _switch(KernelPackage package, {bool confirm = true}) async {
    final localeText = context.l10n;
    if (confirm &&
        !await _confirm(
          localeText.switchKernel,
          _kernelSwitchMessage(context, package),
        )) {
      return;
    }
    final result = await _run(
      localeText.switchKernel,
      (task) => service.switchTo(package, context: task),
      announce: false,
      requiresStoppedSteam: true,
    );
    if (!mounted || result == null) return;
    if (result.success) {
      ui.showAppSuccess(context, result.message);
      await _checkForUpdate();
    } else {
      _showError(result.message);
    }
  }

  Future<void> _toggleKernel() async {
    final localeText = context.l10n;
    final installed = service.installed;
    final enabling = !installed.enabled;
    if (!await _confirm(
      enabling ? localeText.enableKernel : localeText.disableKernel,
      localeText.kernelFilesWillBeRenamedAfterSavingABackupCloseSteamFirst,
    )) {
      return;
    }
    await _run(
      enabling ? localeText.enableKernel : localeText.disableKernel,
      (_) => service.setEnabled(enabling),
      requiresStoppedSteam: true,
    );
  }

  Future<void> _setInjectionMode(InjectionMode mode) async {
    final localeText = context.l10n;
    if (!await _confirm(
      localeText.changeInjectionEntry,
      localeText.onlyTheSelectedEntryWillRemainActiveCloseSteamFirst,
    )) {
      return;
    }
    await _run(
      localeText.changeInjectionEntry,
      (_) => service.setInjectionMode(mode),
      requiresStoppedSteam: true,
    );
  }

  Future<void> _scanResiduals() async {
    final changed = await showKernelResidualSheet(
      context: context,
      service: service,
      tasks: widget.tasks,
      steamProcess: widget.steamProcess,
    );
    if (changed == true && mounted) {
      await service.loadLocal();
    }
  }

  Future<void> _showRecoveryBackups() async {
    final localeText = context.l10n;
    final backup = await showKernelBackupSheet(
      context: context,
      service: service,
    );
    if (!mounted || backup == null) return;
    if (!await _confirm(
      localeText.restoreKernelBackup,
      '${localeText.restoreTheseFilesAndRemoveKernelFilesAbsentFromThisSnapshotCloseSteamFirst}\n\n${backup.files.join('\n')}',
    )) {
      return;
    }
    await _run(
      localeText.restoreKernelBackup,
      (task) => service.restore(backup.id, context: task),
      requiresStoppedSteam: true,
    );
    if (mounted) setState(() {});
  }

  Future<void> _fetchToml() async {
    final localeText = context.l10n;
    final info = await _run(
      localeText.kernelTomlPreviewTitle,
      (_) => service.detectSteamDllInfo(),
      announce: false,
    );
    if (!mounted) return;
    if (info == null) {
      ui.showAppError(context, localeText.selectYourSteamFolderInSettingsFirst);
      return;
    }
    final proceed = await showKernelTomlPreviewSheet(
      context: context,
      info: info,
    );
    if (proceed != true || !mounted) return;
    final results = await _run(
      localeText.fetchSteamSignatures,
      (task) => service.fetchTomlFiles(context: task, info: info),
      announce: false,
      requiresStoppedSteam: true,
    );
    if (!mounted || results == null) return;
    if (results.every((result) => result.success)) {
      ui.showAppSuccess(context, localeText.operationCompleted);
    }
    await showKernelTomlResultSheet(context: context, results: results);
  }

  Future<void> _uninstall() async {
    final localeText = context.l10n;
    try {
      final files = await service.previewUninstall();
      if (!mounted) return;
      if (files.isEmpty) {
        ui.showAppError(context, localeText.noInstalledKernelFilesFound);
        return;
      }
      if (!await _confirm(
        localeText.uninstallKernel,
        '${localeText.onlyTheseFilesWillBeRemovedAfterSavingABackupCloseSteamFirst}\n\n${files.join('\n')}',
      )) {
        return;
      }
      await _run(
        localeText.uninstallKernel,
        (_) => service.uninstall(),
        requiresStoppedSteam: true,
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ui.showAppError(context, error);
    });
  }

  Future<void> _setAutoCheck(bool value) async {
    await widget.settings.set('autoCheckKernelUpdate', value);
  }

  String _stateLabel(BuildContext context) {
    final installed = service.installed;
    if (!installed.installed) return context.l10n.kernelStateNotInstalled;
    if (!installed.enabled) return context.l10n.kernelStateDisabled;
    return switch (installed.entryState) {
      InjectionEntryState.none => context.l10n.kernelStateMissingEntry,
      InjectionEntryState.bothActive => context.l10n.kernelStateConflict,
      _ => context.l10n.kernelStateHealthy,
    };
  }

  ui.TonalChip _stateChip(BuildContext context) {
    final colors = context.colorScheme;
    final installed = service.installed;
    final healthy =
        installed.installed &&
        installed.enabled &&
        installed.entryState != InjectionEntryState.none &&
        installed.entryState != InjectionEntryState.bothActive;
    final warning =
        installed.installed &&
        (!installed.enabled ||
            installed.entryState == InjectionEntryState.none ||
            installed.entryState == InjectionEntryState.bothActive);
    final (background, foreground) = healthy
        ? (colors.primaryContainer, colors.onPrimaryContainer)
        : warning
        ? (colors.tertiaryContainer, colors.onTertiaryContainer)
        : (colors.surfaceContainerHighest, colors.onSurfaceVariant);
    return ui.TonalChip(
      label: _stateLabel(context),
      color: background,
      foregroundColor: foreground,
    );
  }

  Widget _repositoryKindChip(BuildContext context) {
    final info = service.repositoryInfo;
    final fork = info?.fork == true;
    final colors = context.colorScheme;
    return ui.TonalChip(
      label: fork
          ? context.l10n.repositoryFork
          : context.l10n.repositoryMainline,
      color: fork ? colors.tertiaryContainer : colors.primaryContainer,
      foregroundColor: fork
          ? colors.onTertiaryContainer
          : colors.onPrimaryContainer,
    );
  }

  String _entryLabel(BuildContext context) =>
      switch (service.installed.entryState) {
        InjectionEntryState.dwmapi => 'dwmapi.dll',
        InjectionEntryState.version => 'version.dll',
        InjectionEntryState.bothActive => context.l10n.kernelStateConflict,
        InjectionEntryState.none => context.l10n.none,
      };

  String _manifestSummary(BuildContext context) {
    final modeName = widget.settings.get<String>(
      'kernelManifestMode',
      KernelManifestMode.builtIn.name,
    );
    final mode = KernelManifestMode.values
        .where((value) => value.name == modeName)
        .firstOrNull;
    return switch (mode) {
      KernelManifestMode.custom =>
        '${context.l10n.manifestModeCustom} · '
            '${widget.settings.get<String>('kernelManifestCustomUrl', '')}',
      KernelManifestMode.localProxy =>
        '${context.l10n.manifestModeLocalProxy} · '
            '${widget.settings.get<List<dynamic>>('kernelManifestSourceIds', const []).length}',
      _ =>
        '${context.l10n.manifestModeBuiltIn} · '
            '${widget.settings.get<String>('kernelManifestProvider', '20770407')}',
    };
  }

  Widget _warning(BuildContext context, String message) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ui.CommonCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: ui.AppShape.md,
        child: Row(
          children: [
            ui.GlyphIcon(
              ui.AppGlyphs.warning,
              size: 20,
              color: colors.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                message,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeText = context.l10n;
    final installed = service.installed;
    final canChangeEntry = installed.installed && installed.enabled && !_busy;
    final updateText = _updateInfo == null
        ? null
        : _updateInfo!.hasUpdate
        ? localeText.kernelUpdateAvailable(_updateInfo!.package.version)
        : localeText.kernelUpToDate;
    return ui.CommonScaffold(
      title: localeText.kernelManagement,
      isLoading: _busy,
      actions: [
        if (service.sourceMode == KernelSourceMode.repository)
          IconButton(
            tooltip: localeText.refreshKernelReleases,
            onPressed: _busy ? null : _refresh,
            icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
          )
        else
          IconButton(
            tooltip: localeText.importKernelPackage,
            onPressed: _busy ? null : _import,
            icon: const ui.GlyphIcon(ui.AppGlyphs.upload),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, ui.pageContentTopInset, 16, 28),
        children: [
          for (final warning in service.warnings) _warning(context, warning),
          ui.generateSection(
            title: localeText.kernelOverview,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.wrench),
                title: Text(localeText.currentKernel),
                trailing: _stateChip(context),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.verified),
                title: Text(localeText.kernelVersion),
                subtitle: Text(installed.version ?? localeText.unknownVersion),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.target),
                title: Text(localeText.injectionEntry),
                subtitle: Text(_entryLabel(context)),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.profiles),
                title: Text(localeText.localFolder),
                subtitle: SelectableText(
                  widget.settings.steamPath.isEmpty
                      ? localeText.selectYourSteamFolderInSettingsFirst
                      : widget.settings.steamPath,
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: localeText.injectionEntry,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.target),
                title: const Text('dwmapi.dll'),
                subtitle: Text(localeText.kernelEntryDwmapiDescription),
                onPressed:
                    canChangeEntry &&
                        installed.entryState != InjectionEntryState.dwmapi
                    ? () => _setInjectionMode(InjectionMode.dwmapi)
                    : null,
                trailing: installed.entryState == InjectionEntryState.dwmapi
                    ? const ui.SelectionCheck()
                    : null,
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.target),
                title: const Text('version.dll'),
                subtitle: Text(localeText.kernelEntryVersionDescription),
                onPressed:
                    canChangeEntry &&
                        installed.entryState != InjectionEntryState.version
                    ? () => _setInjectionMode(InjectionMode.version)
                    : null,
                trailing: installed.entryState == InjectionEntryState.version
                    ? const ui.SelectionCheck()
                    : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: ui.SegmentedControl<KernelSourceMode>(
              segments: [
                (
                  KernelSourceMode.repository,
                  localeText.repositorySubscription,
                ),
                (KernelSourceMode.local, localeText.localKernelPackage),
              ],
              value: service.sourceMode,
              onChanged: _busy ? (_) {} : _setSourceMode,
            ),
          ),
          AnimatedSize(
            duration: context.motionDuration(const Duration(milliseconds: 260)),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ui.FadeBox(
              child: KeyedSubtree(
                key: ValueKey(service.sourceMode),
                child: ui.generateSection(
                  title: localeText.kernelActions,
                  items: [
                    if (service.sourceMode == KernelSourceMode.repository) ...[
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.code),
                        title: Text(localeText.kernelRepository),
                        subtitle: Text(service.repositorySlug),
                        onPressed: _busy ? null : _editRepository,
                        trailing: service.repositoryInfo == null
                            ? const ui.GlyphIcon(
                                ui.AppGlyphs.chevronForward,
                                size: 18,
                              )
                            : _repositoryKindChip(context),
                      ),
                      if (service.repositoryInfo != null)
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(ui.AppGlyphs.connections),
                          title: Text(localeText.defaultBranch),
                          subtitle: Text(
                            [
                              service.repositoryInfo!.defaultBranch,
                              if (service.repositoryInfo!.parent != null)
                                '${localeText.repositoryFork}: '
                                    '${service.repositoryInfo!.parent}',
                              if (service.repositoryInfo!.pushedAt != null)
                                '${localeText.lastPush}: '
                                    '${service.repositoryInfo!.pushedAt!.toLocal().toString().split('.').first}',
                            ].join(' · '),
                          ),
                        ),
                      ui.ListItem.toggle(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.settings),
                        title: Text(localeText.kernelUpdateCheckOnStartup),
                        value: widget.settings.autoCheckKernelUpdate,
                        onChanged: _busy ? null : _setAutoCheck,
                      ),
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                        title: Text(localeText.installOrUpdateKernel),
                        subtitle: Text(
                          updateText ??
                              (_updateInfo?.package.version ??
                                  localeText.checkKernelUpdate),
                        ),
                        onPressed: _busy ? null : _installOrUpdate,
                        trailing: const ui.GlyphIcon(
                          ui.AppGlyphs.chevronForward,
                          size: 18,
                        ),
                      ),
                    ] else
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.upload),
                        title: Text(localeText.importKernelPackage),
                        subtitle: Text(localeText.kernelLocalNoUpdates),
                        onPressed: _busy ? null : _import,
                        trailing: const ui.GlyphIcon(
                          ui.AppGlyphs.chevronForward,
                          size: 18,
                        ),
                      ),
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.appsList),
                      title: Text(localeText.availablePackages),
                      subtitle: Text(
                        service.sourceMode == KernelSourceMode.repository
                            ? service.repositorySlug
                            : '${localeText.localKernelPackage} · '
                                  '${service.visiblePackages.length}',
                      ),
                      onPressed: _busy ? null : _showAvailablePackages,
                      trailing: const ui.GlyphIcon(
                        ui.AppGlyphs.chevronForward,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ui.generateSection(
            title: localeText.installAndRuntime,
            items: [
              ui.ListItem.toggle(
                leading: const ui.GlyphIcon(ui.AppGlyphs.settings),
                title: Text(
                  installed.enabled
                      ? localeText.disableKernel
                      : localeText.enableKernel,
                ),
                value: installed.installed && installed.enabled,
                onChanged: _busy || !installed.installed
                    ? null
                    : (_) => _toggleKernel(),
              ),
            ],
          ),
          ui.generateSection(
            title: localeText.maintenance,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                title: Text(localeText.manifestSettings),
                subtitle: Text(_manifestSummary(context)),
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          ui.buildAppPageRoute(
                            builder: (_) =>
                                KernelManifestSettingsPage(service: service),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.connections),
                title: Text(localeText.steamClientDataChannel),
                subtitle: Text(
                  '${service.tomlChannelSettings.repository} · '
                  '${service.tomlChannelSettings.channel}',
                ),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        ui.buildAppPageRoute(
                          builder: (_) => KernelTomlChannelPage(
                            service: service,
                            steamProcess: widget.steamProcess,
                          ),
                        ),
                      ),
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.verified),
                title: Text(localeText.fetchSteamSignatures),
                onPressed: _busy ? null : _fetchToml,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.search),
                title: Text(localeText.kernelResidualScan),
                subtitle: Text(localeText.kernelResidualScanDescription),
                onPressed: _busy ? null : _scanResiduals,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.undo),
                title: Text(localeText.switchAndRecoveryBackups),
                subtitle: Text(
                  '${service.backups.length} · ${localeText.backups}',
                ),
                onPressed: _busy ? null : _showRecoveryBackups,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.delete),
                title: Text(
                  localeText.uninstallKernel,
                  style: TextStyle(color: context.colorScheme.error),
                ),
                subtitle: Text(
                  localeText
                      .onlyTheseFilesWillBeRemovedAfterSavingABackupCloseSteamFirst,
                ),
                onPressed: _busy || service.installed.files.isEmpty
                    ? null
                    : _uninstall,
              ),
            ],
          ),
          ui.ListFooter(
            text: '${localeText.repository}: ${service.repositoryRoot}',
          ),
        ],
      ),
    );
  }
}

class _KernelPackagesSheet extends StatefulWidget {
  const _KernelPackagesSheet({
    required this.service,
    required this.tasks,
    this.steamProcess,
  });

  final KernelService service;
  final TaskCenter tasks;
  final SteamProcessActions? steamProcess;

  @override
  State<_KernelPackagesSheet> createState() => _KernelPackagesSheetState();
}

class _KernelPackagesSheetState extends State<_KernelPackagesSheet> {
  bool _busy = false;
  String? _error;

  KernelService get service => widget.service;

  @override
  void initState() {
    super.initState();
    service.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_pull());
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

  Future<void> _pull() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (service.sourceMode == KernelSourceMode.repository) {
        await widget.tasks.run(
          context.l10n.refreshKernelReleases,
          (task) => service.refresh(context: task),
        );
      } else {
        await service.loadLocal();
      }
    } on TaskCancelled {
      // The task panel owns cancellation feedback.
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext task) action,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.tasks.run(title, action);
    } on TaskCancelled {
      // The task panel owns cancellation feedback.
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch(KernelPackage package) async {
    if (service.activePackageId == package.id || _busy) return;
    final confirmed = await ui.AppDialogs.confirm(
      context,
      title: context.l10n.switchKernel,
      message: _kernelSwitchMessage(context, package),
    );
    if (confirmed != true || !mounted) return;
    final steam = widget.steamProcess;
    if (steam != null) {
      if (!await confirmAndStopSteam(context, steam) || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.tasks.run(
        context.l10n.switchKernel,
        (task) => service.switchTo(package, context: task),
      );
      if (!mounted) return;
      if (result.success) {
        ui.showAppSuccess(context, result.message);
      } else {
        setState(() => _error = result.message);
      }
    } on TaskCancelled {
      // The task panel owns cancellation feedback.
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(KernelPackage package) => _run(
    context.l10n.downloadKernel,
    (task) => service.download(package, context: task),
  );

  Future<void> _delete(KernelPackage package) async {
    final confirmed = await ui.AppDialogs.confirm(
      context,
      title: context.l10n.deleteCache,
      message: context.l10n.deleteTheCachedPackageBackupsArePreserved(
        package.displayName,
      ),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    await _run(context.l10n.deleteCache, (_) => service.deletePackage(package));
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    await _run(
      context.l10n.importKernelPackage,
      (task) => service.importLocal(path, context: task),
    );
  }

  String _size(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} '
        '${units[unit]}';
  }

  ui.TonalChip _badge(
    BuildContext context,
    String label, {
    bool primary = false,
  }) {
    final colors = context.colorScheme;
    return ui.TonalChip(
      label: label,
      color: primary ? colors.primaryContainer : colors.surfaceContainerHighest,
      foregroundColor: primary
          ? colors.onPrimaryContainer
          : colors.onSurfaceVariant,
    );
  }

  @override
  Widget build(BuildContext context) => ui.SideSheetScaffold(
    title: context.l10n.availablePackages,
    actions: [
      ui.SideSheetHeaderButton(
        tooltip: context.l10n.refresh,
        onPressed: _busy ? null : _pull,
        icon: const ui.GlyphIcon(ui.AppGlyphs.refresh, size: 22),
      ),
      ui.SideSheetHeaderButton(
        tooltip: context.l10n.importKernelPackage,
        onPressed: _busy ? null : _import,
        icon: const ui.GlyphIcon(ui.AppGlyphs.upload, size: 22),
      ),
    ],
    body: _error != null
        ? ui.NullStatus(
            label: context.l10n.operationFailed,
            description: _error!,
            illustration: ui.NullStatusIllustration.error,
            action: ui.TonalButton(
              glyph: ui.AppGlyphs.refresh,
              label: context.l10n.refresh,
              onPressed: _pull,
            ),
          )
        : _busy && service.visiblePackages.isEmpty
        ? const Center(child: ui.CommonCircleLoading.page())
        : ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              ui.SideSheetScaffold.headerHeight + 16,
              16,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (service.visiblePackages.isEmpty)
                ui.NullStatus(
                  label: context.l10n.availablePackages,
                  description: service.sourceMode == KernelSourceMode.local
                      ? context.l10n.kernelLocalNoUpdates
                      : context
                            .l10n
                            .refreshToLoadOfficialReleasesOrImportALocalKernelZip,
                  illustration: ui.NullStatusIllustration.lua,
                  action: ui.TonalButton(
                    glyph: ui.AppGlyphs.upload,
                    label: context.l10n.importKernelPackage,
                    onPressed: _import,
                  ),
                )
              else
                ui.generateSection(
                  title: context.l10n.availablePackages,
                  items: [
                    for (final package in service.visiblePackages)
                      ui.DecorationListItem(
                        leading: ui.GlyphIcon(
                          package.source == KernelSource.local
                              ? ui.AppGlyphs.resources
                              : ui.AppGlyphs.cloudDownload,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                package.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (service.activePackageId == package.id) ...[
                              const SizedBox(width: 8),
                              _badge(
                                context,
                                context.l10n.active,
                                primary: true,
                              ),
                            ],
                            if (service.isCached(package)) ...[
                              const SizedBox(width: 6),
                              _badge(context, context.l10n.cached),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${package.version} · '
                          '${package.source == KernelSource.local ? context.l10n.local2 : context.l10n.official} · '
                          '${_size(package.sizeBytes)}',
                        ),
                        onPressed:
                            _busy || service.activePackageId == package.id
                            ? null
                            : () => _switch(package),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!service.isCached(package))
                              IconButton(
                                tooltip: context.l10n.downloadOnly,
                                onPressed: _busy
                                    ? null
                                    : () => _download(package),
                                icon: const ui.GlyphIcon(
                                  ui.AppGlyphs.cloudDownload,
                                  size: 20,
                                ),
                              ),
                            if (service.isCached(package) &&
                                service.activePackageId != package.id)
                              IconButton(
                                tooltip: context.l10n.deleteCache,
                                onPressed: _busy
                                    ? null
                                    : () => _delete(package),
                                icon: const ui.GlyphIcon(
                                  ui.AppGlyphs.delete,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
  );
}

class _KernelRepositoryForm extends StatefulWidget {
  const _KernelRepositoryForm({required this.initialValue});

  final String initialValue;

  @override
  State<_KernelRepositoryForm> createState() => _KernelRepositoryFormState();
}

class _KernelRepositoryFormState extends State<_KernelRepositoryForm> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    final uri = Uri.tryParse(value);
    final validUrl =
        uri != null &&
        uri.host.toLowerCase() == 'github.com' &&
        uri.pathSegments.length == 2;
    final validSlug = RegExp(r'^[^/\s]+/[^/\s]+$').hasMatch(value);
    if (!validUrl && !validSlug) {
      setState(() => _error = context.l10n.kernelRepositoryHint);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: context.l10n.kernelRepository,
    onSave: _save,
    error: _error,
    children: [
      ui.generateSection(
        items: [
          ui.FormRow(
            title: context.l10n.kernelRepository,
            trailing: ui.FormRowTextField(
              controller: _controller,
              autofocus: true,
              hintText: context.l10n.kernelRepositoryHint,
              onChanged: (_) => setState(() => _error = null),
            ),
          ),
        ],
        footer: context.l10n.kernelRepositoryHint,
      ),
    ],
  );
}
