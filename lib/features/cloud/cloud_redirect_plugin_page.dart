import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../steam/steam_close_action.dart';
import 'cloud_service.dart';

class CloudRedirectPluginPage extends StatefulWidget {
  const CloudRedirectPluginPage({
    super.key,
    required this.service,
    this.tasks,
    this.steamProcess,
  });

  final CloudService service;
  final TaskCenter? tasks;
  final SteamProcessActions? steamProcess;

  @override
  State<CloudRedirectPluginPage> createState() =>
      _CloudRedirectPluginPageState();
}

class _CloudRedirectPluginPageState extends State<CloudRedirectPluginPage> {
  CloudPluginStatus? _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await widget.service.inspectPlugin();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext? task) action, {
    bool announce = true,
    bool requiresStoppedSteam = false,
  }) async {
    final steam = widget.steamProcess;
    if (requiresStoppedSteam &&
        steam != null &&
        !await confirmAndStopSteam(context, steam)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tasks = widget.tasks;
      if (tasks == null) {
        await action(null);
      } else {
        await tasks.run(title, (task) => action(task));
      }
      if (mounted && announce) {
        ui.showAppSuccess(context, context.l10n.operationCompleted);
      }
      await _load();
    } on TaskCancelled {
      if (mounted) ui.showAppFeedback(context, context.l10n.operationCancelled);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _installOrUpdate() => _run(
    context.l10n.installOrUpdatePlugin,
    (task) => widget.service.enableRedirect(context: task),
    requiresStoppedSteam: true,
  );

  Future<void> _toggle(bool enabled) async {
    if (enabled && !(_status?.installed ?? false)) {
      await _installOrUpdate();
      return;
    }
    if (enabled) {
      await _run(
        context.l10n.enableKernel,
        (_) => widget.service.enableRedirect(),
        requiresStoppedSteam: true,
      );
    } else {
      await _run(
        context.l10n.disableKernel,
        (_) => widget.service.disableRedirect(),
        requiresStoppedSteam: true,
      );
    }
  }

  Future<void> _remove() async {
    final localeText = context.l10n;
    final confirmed = await ui.AppDialogs.confirm(
      context,
      title: localeText.removeCloudRedirectPlugin,
      message: localeText.removeCloudRedirectPluginDescription,
      confirmText: localeText.uninstall,
      destructive: true,
    );
    if (confirmed != true) return;
    await _run(
      localeText.uninstall,
      (task) => widget.service.removePlugin(context: task),
      requiresStoppedSteam: true,
    );
  }

  Future<void> _openFolder() async {
    final path = _status?.path;
    if (path == null || path.isEmpty) return;
    final directory = Directory(p.dirname(path));
    await directory.create(recursive: true);
    await launchUrl(Uri.directory(directory.path));
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

  ui.TonalChip _stateChip(BuildContext context, CloudPluginStatus status) {
    final scheme = context.colorScheme;
    final (label, background, foreground) = !status.installed
        ? (
            context.l10n.notInstalled,
            scheme.surfaceContainerHighest,
            scheme.onSurfaceVariant,
          )
        : status.enabled
        ? (
            context.l10n.enabled,
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
          )
        : (
            context.l10n.disabled,
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer,
          );
    return ui.TonalChip(
      label: label,
      color: background,
      foregroundColor: foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return ui.CommonScaffold(
      title: context.l10n.cloudRedirectPlugin,
      isLoading: _busy,
      actions: [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: _busy ? null : _load,
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
        ),
        IconButton(
          tooltip: context.l10n.installOrUpdatePlugin,
          onPressed: _busy ? null : _installOrUpdate,
          icon: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ui.CommonCard(
                isError: true,
                padding: const EdgeInsets.all(14),
                child: SelectableText(_error!),
              ),
            ),
          ui.generateSection(
            title: context.l10n.pluginManagement,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.layers),
                title: Text(context.l10n.cloudRedirectPlugin),
                subtitle: Text(context.l10n.cloudRedirectPluginDescription),
                trailing: status == null
                    ? const ui.CommonCircleLoading(size: 18)
                    : _stateChip(context, status),
              ),
              if (status != null)
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.settings),
                  title: Text(context.l10n.localSaveRedirection),
                  subtitle: Text(
                    status.installed
                        ? context
                              .l10n
                              .downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards
                        : context.l10n.installOrUpdatePlugin,
                  ),
                  onPressed: _busy || !status.installed
                      ? null
                      : () => _toggle(!status.enabled),
                  trailing: ui.CommonSwitch(
                    value: status.enabled,
                    onChanged: _busy ? null : _toggle,
                  ),
                ),
              if (status != null && status.installed) ...[
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                  title: Text(context.l10n.path),
                  subtitle: SelectableText(status.path),
                ),
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.layers),
                  title: Text(context.l10n.fileSizeLabel),
                  trailing: Text(_size(status.size)),
                ),
                if (status.modifiedAt != null)
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.clock),
                    title: Text(context.l10n.updatedLabel),
                    trailing: Text(
                      status.modifiedAt!.toLocal().toString().split('.').first,
                    ),
                  ),
              ],
            ],
          ),
          ui.generateSection(
            title: context.l10n.kernelIntegration,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.wrench),
                title: Text(context.l10n.openSteamtoolCore),
                subtitle: Text(
                  status?.enabled == true
                      ? context.l10n.enabledRestartSteamAfterChanges
                      : context.l10n.disabled,
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: context.l10n.actions,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                title: Text(context.l10n.installOrUpdatePlugin),
                onPressed: _busy ? null : _installOrUpdate,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
                title: Text(context.l10n.openFolder),
                onPressed: _busy || status == null || status.path.isEmpty
                    ? null
                    : _openFolder,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.delete),
                title: Text(
                  context.l10n.removeCloudRedirectPlugin,
                  style: TextStyle(color: context.colorScheme.error),
                ),
                subtitle: Text(
                  context.l10n.removeCloudRedirectPluginDescription,
                ),
                onPressed: _busy || !(status?.installed ?? false)
                    ? null
                    : _remove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
