import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_paths.dart';
import '../core/storage_manager.dart';
import '../ui/context.dart';
import '../ui/localization.dart';
import '../ui/ui.dart' as ui;
import 'app_services.dart';
import 'widgets.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({super.key, required this.services});

  final AppServices services;

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  final Map<String, StorageUsage> _usage = {};
  ({int bytes, int files})? _lanCache;
  bool _loading = true;
  String? _busy;

  AppServices get services => widget.services;
  AppPaths get paths => services.paths;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final usage = await Future.wait([
        for (final name in appStorageDirectories)
          measureStorageDirectory(
            paths.storageLocation(name),
          ).then((value) => MapEntry(name, value)),
      ]);
      ({int bytes, int files})? lanCache;
      try {
        lanCache = await services.lanTransfer.chunkCacheStats();
      } catch (_) {
        lanCache = null;
      }
      if (!mounted) return;
      setState(() {
        _usage
          ..clear()
          ..addEntries(usage);
        _lanCache = lanCache;
      });
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalBytes =>
      _usage.values.fold(0, (sum, value) => sum + value.bytes);

  int get _totalFiles =>
      _usage.values.fold(0, (sum, value) => sum + value.files);

  List<String> get _categories {
    final values = [...appStorageDirectories];
    if (_usage.isEmpty) return values;
    values.sort((a, b) {
      final bySize = (_usage[b]?.bytes ?? 0).compareTo(_usage[a]?.bytes ?? 0);
      return bySize != 0
          ? bySize
          : appStorageDirectories
                .indexOf(a)
                .compareTo(appStorageDirectories.indexOf(b));
    });
    return values;
  }

  Color _categoryColor(BuildContext context, String name) {
    final base = switch (name) {
      'cache' => const Color(0xff4c8df6),
      'backups' => const Color(0xfff2a03f),
      'downloads' => const Color(0xff41ba6d),
      'logs' => const Color(0xff45b7d2),
      _ => const Color(0xff8b98a5),
    };
    return Color.lerp(base, Theme.of(context).colorScheme.primary, .16)!;
  }

  String _percent(int bytes) {
    if (_totalBytes <= 0 || bytes <= 0) return '0%';
    final value = bytes * 100 / _totalBytes;
    return value < 1 ? '<1%' : '${value.round()}%';
  }

  String _label(BuildContext context, String name) => switch (name) {
    'cache' => context.l10n.appCache,
    'backups' => context.l10n.backups,
    'downloads' => context.l10n.downloads,
    'logs' => context.l10n.logs,
    _ => context.l10n.appData,
  };

  bool _editable(String name) => name != 'data';

  Future<void> _openFolder(String name) async {
    final directory = Directory(paths.storageLocation(name));
    await directory.create(recursive: true);
    if (!await launchUrl(Uri.directory(directory.path))) {
      throw StateError('Could not open folder');
    }
  }

  Future<void> _changeFolder(String name) async {
    if (!_canRunStorageOperation()) return;
    final current = paths.storageLocation(name);
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: context.l10n.chooseStorageFolder,
      initialDirectory: Directory(p.dirname(current)).existsSync()
          ? p.dirname(current)
          : null,
    );
    if (selected == null || !mounted) return;
    await _moveFolder(name, selected);
  }

  Future<void> _useDefaultFolder(String name) async {
    if (!_canRunStorageOperation()) return;
    await _moveFolder(name, p.join(paths.root, name));
  }

  bool _canRunStorageOperation() {
    if (services.tasks.runningCount == 0) return true;
    ui.showAppFeedback(
      context,
      context.l10n.storageChangeBlockedByTasks,
      level: ui.MessageLevel.warning,
    );
    return false;
  }

  Future<void> _moveFolder(String name, String destination) async {
    final source = paths.storageLocation(name);
    final target = p.normalize(p.absolute(destination));
    final localeText = context.l10n;
    final label = _label(context, name);
    if (p.equals(source, target)) return;
    if (p.isWithin(source, target) || p.isWithin(target, source)) {
      ui.showAppError(context, context.l10n.chooseSeparateStorageFolder);
      return;
    }
    final sourceDirectory = Directory(source);
    final targetDirectory = Directory(target);
    if (await sourceDirectory.exists() &&
        await targetDirectory.exists() &&
        !await sourceDirectory.list().isEmpty &&
        !await targetDirectory.list().isEmpty) {
      if (!mounted) return;
      ui.showAppError(context, context.l10n.chooseEmptyStorageFolder);
      return;
    }
    if (!mounted) return;
    final confirmed =
        await ui.AppDialogs.confirm(
          context,
          title: localeText.moveStorageData(label),
          message: localeText.moveStorageDataDescription,
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = name);
    try {
      await services.tasks.run(localeText.moveStorageData(label), (task) async {
        task.report(localeText.preparingStorageFolder);
        await moveStorageDirectory(source, target, task: task);
        try {
          await services.setStorageLocation(name, target);
        } catch (_) {
          await moveStorageDirectory(target, source);
          rethrow;
        }
      });
      if (mounted) {
        ui.showAppSuccess(context, context.l10n.storageFolderUpdated);
        await _refresh();
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _clearCache() async {
    if (!_canRunStorageOperation()) return;
    final localeText = context.l10n;
    final confirmed =
        await ui.AppDialogs.confirm(
          context,
          title: localeText.clearCache,
          message:
              '${localeText.clearCacheConfirmation}\n\n${localeText.lanClearChunkCacheConfirmation}',
          destructive: true,
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busy = 'clear');
    try {
      await services.tasks.run(localeText.clearCache, (task) async {
        task.report(localeText.clearingCache);
        await services.lanTransfer.clearChunkCache();
        await clearStorageDirectory(paths.storageLocation('cache'));
        services.keyCache.clearMemoryCache();
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
      });
      if (mounted) {
        ui.showAppSuccess(context, context.l10n.cacheCleared);
        await _refresh();
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.dataManagement,
    isLoading: _loading,
    actions: [
      ui.DashboardIconButton(
        glyph: ui.AppGlyphs.refresh,
        tooltip: context.l10n.refresh,
        onPressed: _loading ? null : _refresh,
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
        _storageOverview(context),
        const SizedBox(height: 16),
        ui.generateSection(
          title: context.l10n.storageLocations,
          items: [for (final name in _categories) _storageRow(context, name)],
          footer: context.l10n.storageLocationsDescription,
        ),
        const SizedBox(height: 16),
        ui.generateSection(
          title: context.l10n.cleanup,
          items: [
            ui.DecorationListItem(
              leading: const ui.GlyphIcon(ui.AppGlyphs.broom, size: 20),
              title: Text(context.l10n.appCache),
              subtitle: Text(
                _usage['cache'] == null
                    ? context.l10n.scanningStorage
                    : formatStorageBytes(_usage['cache']!.bytes),
              ),
            ),
            if (_lanCache case final stats?)
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.devices, size: 20),
                title: Text(context.l10n.lanTransferCache),
                subtitle: Text(
                  '${formatStorageBytes(stats.bytes)} · ${stats.files} ${context.l10n.files}\n${context.l10n.lanChunkCacheDescription}',
                ),
              ),
          ],
          footer: context.l10n.clearCacheDescription,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ui.TonalButton(
            glyph: ui.AppGlyphs.broom,
            label:
                '${context.l10n.clearCache} · ${formatStorageBytes((_usage['cache']?.bytes ?? 0) + (_lanCache?.bytes ?? 0))}',
            onPressed: _busy == null && _usage.isNotEmpty ? _clearCache : null,
          ),
        ),
      ],
    ),
  );

  Widget _storageOverview(BuildContext context) {
    final categories = _categories;
    final total = _totalBytes;
    final colorScheme = Theme.of(context).colorScheme;
    return ui.CommonCard(
      inert: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.storageUsage,
                      style: ui.AppTextStyle.subheadline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _loading
                          ? context.l10n.scanningStorage
                          : '$_totalFiles ${context.l10n.files}',
                      style: ui.AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const ui.SkeletonPill(width: 112, height: 32)
              else
                Text(
                  formatStorageBytes(total),
                  style: ui.AppTextStyle.title1.of(context, emphasized: true),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 12,
            child: _loading
                ? const ui.SkeletonPill(width: double.infinity, height: 12)
                : CustomPaint(
                    key: const ValueKey('storage-usage-bar'),
                    painter: _StorageBarPainter(
                      segments: [
                        for (final name in categories)
                          if ((_usage[name]?.bytes ?? 0) > 0)
                            (
                              color: _categoryColor(context, name),
                              bytes: _usage[name]!.bytes,
                            ),
                      ],
                      emptyColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
          ),
          if (!_loading && total > 0) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (final name in categories)
                  if ((_usage[name]?.bytes ?? 0) > 0)
                    _StorageLegend(
                      color: _categoryColor(context, name),
                      label: _label(context, name),
                      value: _percent(_usage[name]!.bytes),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _storageRow(BuildContext context, String name) {
    final usage = _usage[name];
    final path = paths.storageLocation(name);
    final editable = _editable(name);
    return ui.DecorationListItem(
      key: ValueKey('storage-location-$name'),
      leading: SizedBox.square(
        dimension: 20,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _categoryColor(context, name),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 10),
          ),
        ),
      ),
      title: Text(_label(context, name)),
      subtitle: Text(
        usage == null
            ? context.l10n.scanningStorage
            : '${usage.files} ${context.l10n.files}\n$path',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () => showAction(context, () => _openFolder(name)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                usage == null ? '—' : formatStorageBytes(usage.bytes),
                style: ui.AppTextStyle.subheadline.of(
                  context,
                  emphasized: true,
                ),
              ),
              if (usage != null)
                Text(
                  _percent(usage.bytes),
                  style: ui.AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(width: 6),
          SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: editable
                ? ui.CommonPopupBox(
                    targetBuilder: (open) => Center(
                      child: IconButton(
                        tooltip: context.l10n.manage,
                        onPressed: _busy == null ? open : null,
                        icon: _busy == name
                            ? const SizedBox.square(
                                dimension: 18,
                                child: ui.CommonCircleLoading(size: 18),
                              )
                            : const ui.GlyphIcon(ui.AppGlyphs.more, size: 20),
                      ),
                    ),
                    popupBuilder: (_) => ui.CommonPopupMenu(
                      items: [
                        ui.CommonPopupMenuItem(
                          label: context.l10n.changeStorageFolder,
                          glyph: ui.AppGlyphs.edit,
                          onPressed: () => _changeFolder(name),
                        ),
                        ui.CommonPopupMenuItem(
                          label: context.l10n.openFolder,
                          glyph: ui.AppGlyphs.resources,
                          onPressed: () =>
                              showAction(context, () => _openFolder(name)),
                        ),
                        ui.CommonPopupMenuItem(
                          label: context.l10n.restoreDefault,
                          glyph: ui.AppGlyphs.reset,
                          section: const ui.CommonPopupMenuSection(),
                          onPressed: () => _useDefaultFolder(name),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _StorageLegend extends StatelessWidget {
  const _StorageLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 8),
      ),
      const SizedBox(width: 6),
      Text(label, style: ui.AppTextStyle.caption1.of(context)),
      const SizedBox(width: 5),
      Text(
        value,
        style: ui.AppTextStyle.caption1
            .of(context)
            .copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    ],
  );
}

class _StorageBarPainter extends CustomPainter {
  _StorageBarPainter({required this.segments, required this.emptyColor});

  final List<({Color color, int bytes})> segments;
  final Color emptyColor;

  static const _gap = 3.0;
  static const _minimumWidth = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final radius = Radius.circular(size.height / 2);
    final total = segments.fold<int>(0, (sum, segment) => sum + segment.bytes);
    if (segments.isEmpty || total <= 0) {
      paint.color = emptyColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, radius),
        paint,
      );
      return;
    }
    final usable = (size.width - _gap * (segments.length - 1)).clamp(
      0.0,
      double.infinity,
    );
    final widths = [
      for (final segment in segments) usable * segment.bytes / total,
    ];
    var deficit = 0.0;
    for (var index = 0; index < widths.length; index++) {
      if (widths[index] < _minimumWidth) {
        deficit += _minimumWidth - widths[index];
        widths[index] = _minimumWidth;
      }
    }
    if (deficit > 0) {
      var widest = 0;
      for (var index = 1; index < widths.length; index++) {
        if (widths[index] > widths[widest]) widest = index;
      }
      widths[widest] = (widths[widest] - deficit).clamp(
        _minimumWidth,
        double.infinity,
      );
    }
    var x = 0.0;
    for (var index = 0; index < segments.length; index++) {
      paint.color = segments[index].color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, widths[index], size.height),
          radius,
        ),
        paint,
      );
      x += widths[index] + _gap;
    }
  }

  @override
  bool shouldRepaint(_StorageBarPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.emptyColor != emptyColor;
}
