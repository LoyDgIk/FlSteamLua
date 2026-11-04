import 'package:flutter/material.dart';

import '../../core/steam_process_actions.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../steam/steam_close_action.dart';
import 'kernel_service.dart';

Future<bool?> showKernelResidualSheet({
  required BuildContext context,
  required KernelService service,
  required TaskCenter tasks,
  SteamProcessActions? steamProcess,
}) => ui.showModalSideSheet<bool>(
  context: context,
  builder: (_) => _KernelResidualSheet(
    service: service,
    tasks: tasks,
    steamProcess: steamProcess,
  ),
);

class _KernelResidualSheet extends StatefulWidget {
  const _KernelResidualSheet({
    required this.service,
    required this.tasks,
    this.steamProcess,
  });

  final KernelService service;
  final TaskCenter tasks;
  final SteamProcessActions? steamProcess;

  @override
  State<_KernelResidualSheet> createState() => _KernelResidualSheetState();
}

class _KernelResidualSheetState extends State<_KernelResidualSheet> {
  KernelScanResult? _result;
  final _selected = <String>{};
  var _scanning = true;
  var _cleaning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final result = await widget.service.scanResiduals();
      if (!mounted) return;
      setState(() {
        _result = result;
        _selected.removeWhere(
          (id) => !result.items.any((item) => item.id == id && item.canClean),
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _toggle(KernelResidualItem item) {
    if (!item.canClean) return;
    setState(() {
      if (!_selected.add(item.id)) {
        _selected.remove(item.id);
      }
    });
  }

  void _selectCleanable() {
    final result = _result;
    if (result == null) return;
    final cleanable = {
      for (final item in result.items)
        if (item.canClean) item.id,
    };
    setState(() {
      if (_selected.containsAll(cleanable)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(cleanable);
      }
    });
  }

  Future<void> _clean() async {
    if (_selected.isEmpty || _cleaning) return;
    final plan = widget.service.createResidualCleanupPlan(_selected);
    if (plan.isEmpty) return;
    final localeText = context.l10n;
    final steam = widget.steamProcess;
    if (steam != null && !await confirmAndStopSteam(context, steam)) return;
    setState(() {
      _cleaning = true;
      _error = null;
    });
    try {
      final result = await widget.tasks.run(
        localeText.kernelResidualBackupAndClean,
        (task) => widget.service.executeResidualCleanup(plan, context: task),
      );
      if (!mounted) return;
      if (!result.success) {
        setState(
          () => _error = localeText.kernelResidualCleanupPartial(
            result.deletedCount,
            result.failedCount,
          ),
        );
        return;
      }
      ui.showAppSuccess(
        context,
        localeText.kernelResidualCleanupCompleted(result.deletedCount),
      );
      Navigator.of(context).pop(true);
    } on TaskCancelled {
      if (mounted) {
        ui.showAppFeedback(context, localeText.operationCancelled);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  String _categoryLabel(
    BuildContext context,
    KernelResidualCategory category,
  ) => switch (category) {
    KernelResidualCategory.openSteamTool =>
      context.l10n.kernelResidualOpenSteamTool,
    KernelResidualCategory.steamTools => context.l10n.kernelResidualSteamTools,
    KernelResidualCategory.tbBiao => context.l10n.kernelResidualTbBiao,
    KernelResidualCategory.steamConfig =>
      context.l10n.kernelResidualSteamConfig,
  };

  String _severityLabel(
    BuildContext context,
    KernelResidualSeverity severity,
  ) => switch (severity) {
    KernelResidualSeverity.info => context.l10n.kernelResidualInfo,
    KernelResidualSeverity.warning => context.l10n.kernelResidualWarning,
    KernelResidualSeverity.high => context.l10n.kernelResidualHigh,
  };

  ui.Glyph _categoryGlyph(KernelResidualCategory category) =>
      switch (category) {
        KernelResidualCategory.openSteamTool => ui.AppGlyphs.wrench,
        KernelResidualCategory.steamTools => ui.AppGlyphs.resources,
        KernelResidualCategory.tbBiao => ui.AppGlyphs.warning,
        KernelResidualCategory.steamConfig => ui.AppGlyphs.settings,
      };

  String _categoryDescription(
    BuildContext context,
    KernelResidualCategory category,
  ) => switch (category) {
    KernelResidualCategory.openSteamTool =>
      context.l10n.kernelResidualOpenSteamToolDescription,
    KernelResidualCategory.steamTools =>
      context.l10n.kernelResidualSteamToolsDescription,
    KernelResidualCategory.tbBiao =>
      context.l10n.kernelResidualTbBiaoDescription,
    KernelResidualCategory.steamConfig =>
      context.l10n.kernelResidualSteamConfigDescription,
  };

  ui.TonalChip _severityChip(
    BuildContext context,
    KernelResidualSeverity severity,
  ) {
    final colors = context.colorScheme;
    final (color, foreground) = switch (severity) {
      KernelResidualSeverity.high => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      KernelResidualSeverity.warning => (
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      KernelResidualSeverity.info => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return ui.TonalChip(
      label: _severityLabel(context, severity),
      color: color,
      foregroundColor: foreground,
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

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final cleanable = result?.cleanableCount ?? 0;
    return ui.SideSheetScaffold(
      title: context.l10n.kernelScanTitle,
      actions: [
        IconButton(
          tooltip: context.l10n.kernelResidualRescan,
          onPressed: _scanning || _cleaning ? null : _scan,
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ui.NullStatusSwitcher(
              isLoading: _scanning,
              isEmpty: result?.hasResiduals != true,
              nullStatus: ui.NullStatus(
                label: context.l10n.kernelResidualNoResults,
                illustration: ui.NullStatusIllustration.data,
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  ui.pageToolbarHeight + 12,
                  16,
                  24,
                ),
                children: [
                  if (result != null)
                    ui.ListFooter(
                      text: context.l10n.kernelScanSummary(
                        result.items.length,
                        result.cleanableCount,
                        _size(result.totalBytes),
                      ),
                    ),
                  for (final category in KernelResidualCategory.values)
                    if (result?.items.any(
                          (item) => item.category == category,
                        ) ==
                        true)
                      ui.generateSection(
                        title: _categoryLabel(context, category),
                        items: [
                          for (final item in result!.items)
                            if (item.category == category)
                              ui.DecorationListItem(
                                leading: ui.GlyphIcon(_categoryGlyph(category)),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _severityChip(context, item.severity),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.relativePath),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${item.isDirectory ? context.l10n.kernelResidualDirectory : context.l10n.kernelResidualFile} · '
                                        '${_size(item.sizeBytes)} · ${item.fileCount} ${context.l10n.files}',
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _categoryDescription(
                                          context,
                                          item.category,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                onPressed: item.canClean
                                    ? () => _toggle(item)
                                    : null,
                                trailing: item.canClean
                                    ? ui.CommonCheckBox(
                                        value: _selected.contains(item.id),
                                        isCircle: true,
                                        onChanged: (_) => _toggle(item),
                                      )
                                    : Tooltip(
                                        message: context
                                            .l10n
                                            .kernelResidualReportOnly,
                                        child: const ui.GlyphIcon(
                                          ui.AppGlyphs.lock,
                                          size: 20,
                                        ),
                                      ),
                              ),
                        ],
                      ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: ui.SurfaceLevel.page.colorOf(context.colorScheme),
              border: Border(
                top: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _cleaning
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(context.l10n.cancel),
                  ),
                  TextButton(
                    onPressed: result != null && cleanable > 0 && !_cleaning
                        ? _selectCleanable
                        : null,
                    child: Text(context.l10n.kernelResidualSelectCleanable),
                  ),
                  FilledButton(
                    onPressed: _selected.isNotEmpty && !_cleaning
                        ? _clean
                        : null,
                    child: _cleaning
                        ? const ui.CommonCircleLoading(size: 18)
                        : Text(
                            '${context.l10n.kernelResidualBackupAndClean} '
                            '(${_selected.length})',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
