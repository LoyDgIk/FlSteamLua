import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/steam_process_actions.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../steam/steam_close_action.dart';
import 'kernel_service.dart';
import 'local_toml_builder.dart';

Future<void> showLocalTomlBuildSheet({
  required BuildContext context,
  required KernelService service,
  SteamProcessActions? steamProcess,
}) => ui.showModalSideSheet<void>(
  context: context,
  builder: (_) =>
      _LocalTomlBuildSheet(service: service, steamProcess: steamProcess),
);

class _LocalTomlBuildSheet extends StatefulWidget {
  const _LocalTomlBuildSheet({required this.service, this.steamProcess});

  final KernelService service;
  final SteamProcessActions? steamProcess;

  @override
  State<_LocalTomlBuildSheet> createState() => _LocalTomlBuildSheetState();
}

class _LocalTomlBuildSheetState extends State<_LocalTomlBuildSheet> {
  final _scroll = ScrollController();
  final _events = <LocalTomlBuildEvent>[];
  SteamDllTomlInfo? _info;
  LocalTomlBuildReport? _report;
  String? _error;
  bool _detecting = true;
  bool _building = false;

  @override
  void initState() {
    super.initState();
    unawaited(_detect());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      final info = await widget.service.detectSteamDllInfo();
      if (!mounted) return;
      setState(() {
        _info = info;
        _detecting = false;
        _error = info == null
            ? context.l10n.selectYourSteamFolderInSettingsFirst
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detecting = false;
        _error = '$error';
      });
    }
  }

  Future<void> _build() async {
    setState(() {
      _building = true;
      _error = null;
      _report = null;
      _events.clear();
    });
    Future<LocalTomlBuildReport> runBuild() =>
        widget.service.buildLocalTomlFiles(
          onEvent: (event) {
            if (!mounted) return;
            setState(() => _events.add(event));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _scroll.hasClients) {
                _scroll.animateTo(
                  _scroll.position.maxScrollExtent,
                  duration: context.motionDuration(
                    const Duration(milliseconds: 180),
                  ),
                  curve: Curves.easeOutCubic,
                );
              }
            });
          },
        );
    try {
      LocalTomlBuildReport report;
      try {
        report = await runBuild();
      } on SteamRunningException {
        final steam = widget.steamProcess;
        if (steam == null || !mounted) rethrow;
        if (!await confirmAndStopSteam(context, steam)) return;
        report = await runBuild();
      }
      if (!mounted) return;
      setState(() => _report = report);
      final message = context.l10n.localBuildCompleted(
        '${report.writtenCount}',
        '${report.components.length}',
      );
      if (report.writtenCount == report.components.length) {
        ui.showAppSuccess(context, message);
      } else {
        ui.showAppFeedback(context, message, level: ui.MessageLevel.warning);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _building = false);
    }
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

  String _eventText(LocalTomlBuildEvent event) => switch (event.kind) {
    LocalTomlBuildEventKind.dllLocated => context.l10n.localBuildDllLocated(
      event.name,
      _size(event.size),
      event.value,
    ),
    LocalTomlBuildEventKind.hashComputed => context.l10n.localBuildHashComputed(
      event.name,
      event.value,
    ),
    LocalTomlBuildEventKind.patternScan => context.l10n.localBuildPatternScan(
      event.component,
    ),
    LocalTomlBuildEventKind.hookResolved => context.l10n.localBuildHookResolved(
      event.name,
      event.value,
      '${event.size}',
    ),
    LocalTomlBuildEventKind.hookMissing => context.l10n.localBuildHookMissing(
      event.name,
    ),
    LocalTomlBuildEventKind.componentWritten =>
      context.l10n.localBuildComponentWritten(
        event.component,
        '${event.resolved}',
        '${event.total}',
      ),
    LocalTomlBuildEventKind.componentRejected =>
      context.l10n.localBuildComponentRejected(
        event.component,
        '${event.resolved}',
        '${event.total}',
      ),
    LocalTomlBuildEventKind.ipcWrapper => context.l10n.localBuildIpcWrapper(
      event.name,
      event.value,
    ),
    LocalTomlBuildEventKind.ipcVtable => context.l10n.localBuildIpcVtable(
      event.name,
      event.value,
    ),
    LocalTomlBuildEventKind.completed => context.l10n.localBuildCompleted(
      '${event.resolved}',
      '${event.total}',
    ),
  };

  ui.GlyphIcon _eventIcon(LocalTomlBuildEvent event) {
    final colors = context.colorScheme;
    return switch (event.kind) {
      LocalTomlBuildEventKind.hookMissing ||
      LocalTomlBuildEventKind.componentRejected => ui.GlyphIcon(
        ui.AppGlyphs.error,
        color: colors.error,
      ),
      LocalTomlBuildEventKind.componentWritten ||
      LocalTomlBuildEventKind.completed => ui.GlyphIcon(
        ui.AppGlyphs.checkCircle,
        color: colors.primary,
      ),
      LocalTomlBuildEventKind.patternScan => const ui.GlyphIcon(
        ui.AppGlyphs.code,
      ),
      _ => const ui.GlyphIcon(ui.AppGlyphs.info),
    };
  }

  @override
  Widget build(BuildContext context) {
    final canBuild = !_detecting && !_building && _info != null;
    return ui.SideSheetScaffold(
      title: context.l10n.localBuildTitle,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: _report == null
              ? context.l10n.localBuildStart
              : context.l10n.localBuildRestart,
          onPressed: canBuild ? _build : null,
          icon: const ui.GlyphIcon(ui.AppGlyphs.bolt, size: 22),
        ),
      ],
      body: _detecting
          ? const Center(child: ui.CommonCircleLoading.page())
          : _error != null && _info == null
          ? ui.NullStatus(
              label: context.l10n.operationFailed,
              description: _error!,
              illustration: ui.NullStatusIllustration.error,
              action: ui.TonalButton(
                glyph: ui.AppGlyphs.refresh,
                label: context.l10n.refresh,
                onPressed: _detect,
              ),
            )
          : ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                16,
                ui.SideSheetScaffold.headerHeight + 16,
                16,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ui.generateSection(
                  title: context.l10n.localBuildSteamDlls,
                  items: [
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.code),
                      title: const Text('steamclient64.dll'),
                      subtitle: SelectableText(
                        _info?.clientSha ?? context.l10n.unknownVersion,
                      ),
                      trailing: ui.CommonChip(
                        label: _size(_info?.clientSize ?? 0),
                      ),
                    ),
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.code),
                      title: const Text('SteamUI.dll'),
                      subtitle: SelectableText(
                        _info?.uiSha ?? context.l10n.unknownVersion,
                      ),
                      trailing: ui.CommonChip(label: _size(_info?.uiSize ?? 0)),
                    ),
                  ],
                ),
                ui.generateSection(
                  items: [
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.warning),
                      title: Text(context.l10n.localTemporaryBuild),
                      subtitle: Text(
                        '${context.l10n.localTemporaryBuildDescription}\n'
                        '${context.l10n.localBuildCloseSteam}',
                      ),
                    ),
                  ],
                ),
                if (_events.isNotEmpty)
                  ui.generateSection(
                    title: context.l10n.localBuildLog,
                    items: [
                      for (final event in _events)
                        ui.DecorationListItem(
                          leading: _eventIcon(event),
                          title: SelectableText(_eventText(event)),
                        ),
                    ],
                  )
                else
                  ui.generateSection(
                    items: [
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.info),
                        title: Text(context.l10n.localBuildIdleDescription),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
