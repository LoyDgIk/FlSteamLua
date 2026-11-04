import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../network/network_cover_image.dart';
import 'lua_vdf_converter.dart';
import 'manifest_monitor.dart';
import 'tools_service.dart';

class ToolConverterPage extends StatefulWidget {
  const ToolConverterPage({
    super.key,
    required this.service,
    required this.tasks,
    this.game,
    this.initialFolderMode = false,
  });

  final ToolsService service;
  final TaskCenter tasks;
  final GameEntry? game;
  final bool initialFolderMode;

  @override
  State<ToolConverterPage> createState() => _ToolConverterPageState();
}

class _ToolConverterPageState extends State<ToolConverterPage> {
  late bool _folderMode = widget.initialFolderMode;
  late final TextEditingController _appId = TextEditingController(
    text: widget.game?.appId.toString() ?? '',
  );
  final List<String> _files = [];
  String? _sourceFolder;
  String? _outputFolder;
  bool _includeManifestPins = false;
  bool _busy = false;
  String? _error;
  List<ConversionResult> _results = const [];

  @override
  void dispose() {
    _appId.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final selection = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['lua', 'vdf', 'acf'],
    );
    if (selection == null || !mounted) return;
    setState(() {
      _files
        ..clear()
        ..addAll(selection.paths.whereType<String>());
      _error = null;
    });
  }

  Future<void> _pickFolder({required bool source}) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: source
          ? context.l10n.chooseSourceFolder
          : context.l10n.chooseOutputFolder,
      initialDirectory: source ? _sourceFolder : _outputFolder,
    );
    if (path == null || !mounted) return;
    setState(() {
      if (source) {
        _sourceFolder = path;
      } else {
        _outputFolder = path;
      }
      _error = null;
    });
  }

  Future<void> _convert() async {
    final localeText = context.l10n;
    if (_outputFolder == null) {
      setState(() => _error = localeText.selectAnOutputFolder);
      return;
    }
    final input = _folderMode ? _sourceFolder : null;
    if (_folderMode && input == null) {
      setState(() => _error = localeText.chooseSourceFolder);
      return;
    }
    if (!_folderMode && _files.isEmpty) {
      setState(() => _error = localeText.chooseFilesToConvert);
      return;
    }
    final appIdText = _appId.text.trim();
    final appId = appIdText.isEmpty ? null : int.tryParse(appIdText);
    if (appIdText.isNotEmpty && (appId == null || appId <= 0)) {
      setState(() => _error = localeText.enterAValidAppid3);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      final files = _folderMode
          ? await Directory(input!)
                .list()
                .where(
                  (entry) =>
                      entry is File &&
                      const {
                        '.lua',
                        '.vdf',
                        '.acf',
                      }.contains(p.extension(entry.path).toLowerCase()),
                )
                .map((entry) => entry.path)
                .toList()
          : List<String>.from(_files);
      if (files.isEmpty) {
        throw FormatException(localeText.noSupportedFilesFound);
      }
      final results = await widget.tasks.run(
        _folderMode ? localeText.batchConversion : localeText.convertFiles,
        (task) => widget.service.converter.convertFiles(
          files,
          outputDirectory: _outputFolder!,
          appId: appId,
          includeManifestIds: _includeManifestPins,
          task: task,
        ),
      );
      if (!mounted) return;
      setState(() => _results = results);
      final failed = results.where((result) => !result.succeeded);
      if (failed.isEmpty) {
        ui.showAppSuccess(
          context,
          localeText.convertedFileCount('${results.length}'),
        );
      } else {
        ui.showAppError(
          context,
          FormatException(
            failed.map((result) => result.error ?? result.source).join('\n'),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: _folderMode
        ? context.l10n.convertAFolder
        : context.l10n.luaVdfConversion,
    isLoading: _busy,
    body: ui.FloatingFootBar(
      bar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          spacing: 12,
          children: [
            const ui.GlyphIcon(ui.AppGlyphs.swap, size: 20),
            Expanded(
              child: Text(
                _outputFolder == null
                    ? context.l10n.chooseOutputFolder
                    : '${_folderMode ? context.l10n.convertAFolder : context.l10n.fileCount('${_files.length}')}'
                          ' · ${p.basename(_outputFolder!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ui.TonalButton(
              size: ui.TonalButtonSize.compact,
              glyph: ui.AppGlyphs.swap,
              label: context.l10n.convert,
              onPressed: _busy ? null : _convert,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          104 + context.bottomInset,
        ),
        children: [
          ui.SegmentedControl<bool>(
            segments: [
              (false, context.l10n.convertFiles),
              (true, context.l10n.convertAFolder),
            ],
            value: _folderMode,
            onChanged: _busy
                ? (_) {}
                : (value) => setState(() {
                    _folderMode = value;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 16),
          ui.generateSection(
            title: context.l10n.sourceLabel,
            items: [
              if (_folderMode)
                _PathPickerCard(
                  icon: ui.AppGlyphs.resources,
                  title: context.l10n.chooseSourceFolder,
                  path: _sourceFolder,
                  onPressed: _busy ? null : () => _pickFolder(source: true),
                )
              else
                _FilePickerCard(
                  files: _files,
                  busy: _busy,
                  onPressed: _pickFiles,
                ),
            ],
          ),
          ui.generateSection(
            title: context.l10n.destinationLabel,
            items: [
              _PathPickerCard(
                icon: ui.AppGlyphs.cloudDownload,
                title: context.l10n.chooseOutputFolder,
                path: _outputFolder,
                onPressed: _busy ? null : () => _pickFolder(source: false),
              ),
            ],
          ),
          ui.generateSection(
            title: context.l10n.conversionOptions,
            items: [
              ui.FormRow(
                title: context.l10n.appidOptional,
                trailing: SizedBox(
                  width: 180,
                  child: ui.FormRowTextField(
                    controller: _appId,
                    hintText: context.l10n.appidOptional,
                    keyboardType: TextInputType.number,
                    enabled: !_busy,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ),
              ui.FormRow(
                title: context.l10n.includeManifestPinsWhenConvertingVdf,
                onPressed: _busy
                    ? null
                    : () => setState(
                        () => _includeManifestPins = !_includeManifestPins,
                      ),
                trailing: SizedBox(
                  width: 56,
                  child: ui.CommonSwitch(
                    value: _includeManifestPins,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _includeManifestPins = value),
                  ),
                ),
              ),
            ],
            footer: context
                .l10n
                .writesNewFilesWithoutOverwritingLuaToVdfRequiresAnAppid,
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ui.CommonCard(
                isError: true,
                inert: true,
                padding: const EdgeInsets.all(16),
                child: SelectableText(error),
              ),
            ),
          if (_results.isNotEmpty)
            ui.generateSection(
              title: context.l10n.conversionResults,
              items: [
                for (final result in _results)
                  ui.DecorationListItem(
                    leading: ui.GlyphIcon(
                      result.succeeded
                          ? ui.AppGlyphs.checkCircle
                          : ui.AppGlyphs.error,
                      size: 20,
                      color: result.succeeded
                          ? context.colorScheme.primary
                          : context.colorScheme.error,
                    ),
                    title: Text(p.basename(result.source)),
                    subtitle: SelectableText(
                      result.output ?? result.error ?? '',
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class ManifestMonitorPage extends StatefulWidget {
  const ManifestMonitorPage({
    super.key,
    required this.monitor,
    required this.steamPath,
  });

  final ManifestMonitor monitor;
  final String steamPath;

  @override
  State<ManifestMonitorPage> createState() => _ManifestMonitorPageState();
}

class _ManifestMonitorPageState extends State<ManifestMonitorPage> {
  final _scrollController = ScrollController();
  late final ui.AppBarSearchState _searchState;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchState = ui.AppBarSearchState(
      onSearch: (value) => setState(() => _query = value),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!widget.monitor.isRunning && widget.steamPath.isEmpty) {
      ui.showAppError(
        context,
        FormatException(context.l10n.selectTheSteamFolderFirst),
      );
      return;
    }
    try {
      if (widget.monitor.isRunning) {
        widget.monitor.stop();
      } else {
        await widget.monitor.start(widget.steamPath);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.monitor,
    builder: (context, _) {
      final running = widget.monitor.isRunning;
      final query = _query.trim().toLowerCase();
      final logs = widget.monitor.logs
          .where((log) => query.isEmpty || log.toLowerCase().contains(query))
          .toList();
      return ui.CommonScaffold(
        title: context.l10n.manifestMonitoring,
        searchState: _searchState,
        searchHint: context.l10n.search,
        actions: [
          IconButton(
            tooltip: running
                ? context.l10n.stopMonitoring
                : context.l10n.startMonitoring,
            onPressed: _toggle,
            icon: ui.GlyphIcon(
              running ? ui.AppGlyphs.block : ui.AppGlyphs.bolt,
              fill: 1,
            ),
          ),
        ],
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            ui.pageContentTopInset,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: [
              _StatusCard(
                glyph: running ? ui.AppGlyphs.sync : ui.AppGlyphs.clock,
                title: running
                    ? context.l10n.monitorRunning
                    : context.l10n.monitorStopped,
                subtitle: widget.steamPath.isEmpty
                    ? context.l10n.selectTheSteamFolderFirst
                    : p.join(widget.steamPath, 'logs', 'content_log.txt'),
                tone: running
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
                trailing: ui.TonalChip(
                  label: '${widget.monitor.logs.length}',
                  color: context.colorScheme.primary.opacity15,
                  foregroundColor: context.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ui.CommonCard(
                  inert: true,
                  padding: EdgeInsets.zero,
                  radius: ui.AppCorner.xl,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.activityLog,
                                style: ui.AppTextStyle.subheadline.of(
                                  context,
                                  emphasized: true,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.clear,
                              onPressed: widget.monitor.logs.isEmpty
                                  ? null
                                  : widget.monitor.clearLogs,
                              icon: const ui.GlyphIcon(
                                ui.AppGlyphs.clearAll,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: context.colorScheme.outlineVariant.withValues(
                          alpha: .45,
                        ),
                      ),
                      Expanded(
                        child: logs.isEmpty
                            ? ui.NullStatus(
                                label: context.l10n.noLogEntriesYet,
                                illustration: ui.NullStatusIllustration.search,
                              )
                            : ui.CommonScrollBar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: logs.length,
                                  itemBuilder: (context, index) => Text(
                                    logs[index],
                                    style: ui.AppTextStyle.caption1
                                        .of(context)
                                        .copyWith(
                                          height: 1.6,
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontFamily: 'Consolas',
                                        ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ManifestPinsPage extends StatefulWidget {
  const ManifestPinsPage({
    super.key,
    required this.service,
    required this.tasks,
    required this.game,
    this.onChanged,
  });

  final ToolsService service;
  final TaskCenter tasks;
  final GameEntry game;
  final VoidCallback? onChanged;

  @override
  State<ManifestPinsPage> createState() => _ManifestPinsPageState();
}

class _ManifestPinsPageState extends State<ManifestPinsPage> {
  List<LuaDepot> _depots = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final depots = await widget.service.depots(widget.game);
      if (mounted) setState(() => _depots = depots);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      await widget.tasks.run(title, action, appId: widget.game.appId);
      if (!mounted) return;
      ui.showAppSuccess(context, title);
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pinInstalled() {
    final noMatches = context.l10n.noMatchingManifestsFound;
    return _run(context.l10n.updateManifestPins2, (task) async {
      final ids = await widget.service.installedManifests(widget.game);
      if (ids.isEmpty) {
        throw FormatException(noMatches);
      }
      task.checkCancelled();
      await widget.service.pinManifests(widget.game, ids);
      task.report('${ids.length} manifests', 1);
    });
  }

  Future<void> _pinLatest() {
    final noMatches = context.l10n.noMatchingManifestsFound;
    return _run(context.l10n.pinLatestPublicVersion, (task) async {
      final depotIds = (await widget.service.depots(
        widget.game,
      )).map((depot) => depot.id);
      final ids = await widget.service.latestManifests(
        widget.game.appId,
        depotIds,
      );
      if (ids.isEmpty) {
        throw FormatException(noMatches);
      }
      task.checkCancelled();
      await widget.service.pinManifests(widget.game, ids);
      task.report('${ids.length} manifests', 1);
    });
  }

  Future<void> _unpin() =>
      _run(context.l10n.unpinKeepCommentedRecords, (task) async {
        task.checkCancelled();
        await widget.service.unpinManifests(widget.game);
      });

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.manifestVersionPins,
    isLoading: _loading,
    actions: [
      IconButton(
        tooltip: context.l10n.refresh,
        onPressed: _loading || _busy ? null : _load,
        icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
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
        _StatusCard(
          glyph: ui.AppGlyphs.pin,
          title: widget.game.name,
          subtitle:
              'AppID ${widget.game.appId} · ${context.l10n.depotEntryCount('${_depots.length}')}',
          tone: context.colorScheme.primary,
        ),
        ui.generateSection(
          title: context.l10n.actionsLabel,
          items: [
            _ToolActionCard(
              glyph: ui.AppGlyphs.pin,
              title: context.l10n.pinCurrentlyInstalledManifests,
              subtitle: context.l10n.pinInstalledDescription,
              onPressed: _busy ? null : _pinInstalled,
            ),
            _ToolActionCard(
              glyph: ui.AppGlyphs.cloudDownload,
              title: context.l10n.pinLatestPublicManifests,
              subtitle: context.l10n.latestPublicDescription,
              onPressed: _busy ? null : _pinLatest,
            ),
            _ToolActionCard(
              glyph: ui.AppGlyphs.undo,
              title: context.l10n.unpinKeepCommentedRecords,
              subtitle: context.l10n.unpinDescription,
              onPressed: _busy ? null : _unpin,
            ),
          ],
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          ui.CommonCard(
            isError: true,
            inert: true,
            padding: const EdgeInsets.all(16),
            child: SelectableText(error),
          ),
        ],
        ui.generateSection(
          title: context.l10n.depotEntries,
          items: [
            for (final depot in _depots)
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.layers, size: 20),
                title: Text('Depot ${depot.id}'),
                subtitle: Text(
                  'Manifest ${depot.manifestId ?? context.l10n.notConfigured}'
                  '${depot.key == null ? '' : ' · Key'}',
                ),
                trailing: ui.MetaChip(
                  label: depot.pinned
                      ? context.l10n.pinned
                      : context.l10n.notPinned,
                ),
              ),
          ],
          footer: _depots.isEmpty
              ? context.l10n.noDepotEntries
              : context.l10n.manifestPinFooter,
        ),
      ],
    ),
  );
}

class DlcEditorPage extends StatefulWidget {
  const DlcEditorPage({
    super.key,
    required this.service,
    required this.tasks,
    required this.game,
    this.onChanged,
  });

  final ToolsService service;
  final TaskCenter tasks;
  final GameEntry game;
  final VoidCallback? onChanged;

  @override
  State<DlcEditorPage> createState() => _DlcEditorPageState();
}

class _DlcEditorPageState extends State<DlcEditorPage> {
  final _ids = TextEditingController();
  List<LuaDepot> _depots = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ids.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final depots = await widget.service.depots(widget.game);
      if (mounted) setState(() => _depots = depots);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<int> _parsedIds() {
    final values = _ids.text.trim().split(RegExp(r'[\s,，;；]+'));
    if (values.length == 1 && values.single.isEmpty) return const [];
    final ids = values.map(int.tryParse).toList();
    if (ids.any((id) => id == null || id <= 0)) return const [];
    return ids.cast<int>().toSet().toList();
  }

  Future<void> _add() async {
    final ids = _parsedIds();
    if (ids.isEmpty) {
      setState(() => _error = context.l10n.enterValidDlcAppIds);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await widget.tasks.run(context.l10n.addDlc, (task) async {
        final count = await widget.service.addDlc(widget.game, ids);
        task.report('$count entries', 1);
        return count;
      }, appId: widget.game.appId);
      if (!mounted) return;
      _ids.clear();
      widget.onChanged?.call();
      await _load();
      if (mounted) {
        ui.showAppSuccess(context, context.l10n.addedDlcCount('$count'));
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(LuaDepot depot) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.tasks.run(context.l10n.removeDlc, (task) async {
        await widget.service.removeDlc(widget.game, [depot.id]);
        task.report('${depot.id}', 1);
      }, appId: widget.game.appId);
      if (!mounted) return;
      widget.onChanged?.call();
      await _load();
      if (mounted) {
        ui.showAppSuccess(context, context.l10n.removedDlcEntry('${depot.id}'));
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.addDlcAppids,
    isLoading: _loading,
    actions: [
      IconButton(
        tooltip: context.l10n.refresh,
        onPressed: _loading || _busy ? null : _load,
        icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
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
        _StatusCard(
          glyph: ui.AppGlyphs.puzzle,
          title: widget.game.name,
          subtitle:
              context.l10n.appendDlcEntriesWithoutDuplicatingExistingRecords,
          tone: context.colorScheme.primary,
        ),
        ui.generateSection(
          title: context.l10n.addDlc,
          items: [
            ui.FormRow(
              title: context.l10n.addDlcAppids,
              trailing: SizedBox(
                width: 360,
                child: ui.FormRowTextField(
                  controller: _ids,
                  hintText:
                      context.l10n.dlcAppidsSeparatedBySpacesCommasOrNewlines,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  enabled: !_busy,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ),
          ],
          footer:
              context.l10n.appendDlcEntriesWithoutDuplicatingExistingRecords,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ui.TonalButton(
            glyph: ui.AppGlyphs.add,
            label: context.l10n.addToLua,
            onPressed: _busy ? null : _add,
          ),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          ui.CommonCard(
            isError: true,
            inert: true,
            padding: const EdgeInsets.all(16),
            child: SelectableText(error),
          ),
        ],
        ui.generateSection(
          title: context.l10n.luaEntries,
          items: [
            for (final depot in _depots)
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.layers, size: 20),
                title: Text('${depot.id}'),
                subtitle: Text(
                  depot.manifestId == null
                      ? context.l10n.notConfigured
                      : 'Manifest ${depot.manifestId}',
                ),
                trailing: IconButton(
                  tooltip: context.l10n.removeDlc,
                  onPressed: _busy ? null : () => _remove(depot),
                  icon: const ui.GlyphIcon(ui.AppGlyphs.delete, size: 18),
                ),
              ),
          ],
          footer: _depots.isEmpty ? context.l10n.noDepotEntries : null,
        ),
      ],
    ),
  );
}

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.service});

  final ToolsService service;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  List<DiagnosticItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.service.diagnose();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = _items.where((item) => item.ok).length;
    return ui.CommonScaffold(
      title: context.l10n.environmentDiagnostics,
      isLoading: _loading,
      actions: [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: _loading ? null : _load,
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
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
          _StatusCard(
            glyph: passed == _items.length
                ? ui.AppGlyphs.verified
                : ui.AppGlyphs.warning,
            title: context.l10n.diagnosticsSummary(
              '$passed',
              '${_items.length}',
            ),
            subtitle: context.l10n.steamPathClientAndDataDirectories,
            tone: passed == _items.length
                ? context.colorScheme.primary
                : context.colorScheme.error,
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ui.CommonCard(
                isError: true,
                inert: true,
                padding: const EdgeInsets.all(16),
                child: SelectableText(error),
              ),
            ),
          ui.generateSection(
            title: context.l10n.diagnostics,
            items: [
              for (final item in _items)
                ui.DecorationListItem(
                  leading: ui.GlyphIcon(
                    item.ok ? ui.AppGlyphs.checkCircle : ui.AppGlyphs.error,
                    size: 20,
                    color: item.ok
                        ? context.colorScheme.primary
                        : context.colorScheme.error,
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ui.MetaChip(
                    label: item.ok
                        ? context.l10n.available
                        : context.l10n.missing,
                  ),
                ),
            ],
            footer: _items.isEmpty
                ? context.l10n.noDiagnosticsFound
                : context.l10n.diagnosticsFooter,
          ),
        ],
      ),
    );
  }
}

class ToolFoldersPage extends StatelessWidget {
  const ToolFoldersPage({
    super.key,
    required this.service,
    required this.logsPath,
    required this.backupsPath,
  });

  final ToolsService service;
  final String logsPath;
  final String backupsPath;

  Future<void> _open(BuildContext context, String path) async {
    try {
      await service.openPath(path);
    } catch (error) {
      if (context.mounted) ui.showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.applicationFolders,
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        ui.pageContentTopInset,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        ui.generateSection(
          title: context.l10n.applicationFolders,
          items: [
            _FolderCard(
              glyph: ui.AppGlyphs.logs,
              title: context.l10n.logFolder,
              path: logsPath,
              onPressed: () => _open(context, logsPath),
            ),
            _FolderCard(
              glyph: ui.AppGlyphs.cloudSync,
              title: context.l10n.backupFolder,
              path: backupsPath,
              onPressed: () => _open(context, backupsPath),
            ),
          ],
          footer: context.l10n.applicationFoldersFooter,
        ),
      ],
    ),
  );
}

class CoverDownloadPage extends StatefulWidget {
  const CoverDownloadPage({
    super.key,
    required this.service,
    required this.tasks,
    required this.settings,
    required this.game,
    this.onChanged,
  });

  final ToolsService service;
  final TaskCenter tasks;
  final SettingsStore settings;
  final GameEntry game;
  final VoidCallback? onChanged;

  @override
  State<CoverDownloadPage> createState() => _CoverDownloadPageState();
}

class _CoverDownloadPageState extends State<CoverDownloadPage> {
  bool _busy = false;
  String? _savedPath;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await widget.tasks.run(
        context.l10n.downloadCover,
        (task) => widget.service.downloadCover(widget.game.appId, task: task),
        appId: widget.game.appId,
      );
      if (!mounted) return;
      setState(() => _savedPath = file.path);
      widget.onChanged?.call();
      ui.showAppSuccess(context, context.l10n.downloadCover);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.downloadCover,
    isLoading: _busy,
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        ui.pageContentTopInset,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: NetworkCoverImage(
              settings: widget.settings,
              appId: widget.game.appId,
              url: widget.game.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: context.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: ui.GlyphIcon(
                    ui.AppGlyphs.photos,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StatusCard(
          glyph: ui.AppGlyphs.photos,
          title: widget.game.name,
          subtitle: context.l10n.saveToTheApplicationCoverCache,
          tone: context.colorScheme.primary,
        ),
        if (_savedPath case final savedPath?) ...[
          const SizedBox(height: 12),
          ui.CommonCard(
            inert: true,
            padding: const EdgeInsets.all(16),
            child: SelectableText(savedPath),
          ),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          ui.CommonCard(
            isError: true,
            inert: true,
            padding: const EdgeInsets.all(16),
            child: SelectableText(error),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ui.TonalButton(
            glyph: ui.AppGlyphs.cloudDownload,
            label: context.l10n.downloadCover,
            onPressed: _busy ? null : _download,
          ),
        ),
      ],
    ),
  );
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({
    required this.files,
    required this.busy,
    required this.onPressed,
  });

  final List<String> files;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ui.DecorationListItem(
    leading: const ui.GlyphIcon(ui.AppGlyphs.importFile, size: 20),
    title: Text(
      files.isEmpty
          ? context.l10n.noFilesSelected
          : context.l10n.fileCount('${files.length}'),
    ),
    subtitle: Text(
      files.isEmpty
          ? context.l10n.chooseLuaVdfOrAcfFiles
          : files.take(3).map(p.basename).join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    onPressed: busy ? null : onPressed,
    trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
  );
}

class _PathPickerCard extends StatelessWidget {
  const _PathPickerCard({
    required this.icon,
    required this.title,
    required this.path,
    required this.onPressed,
  });

  final ui.Glyph icon;
  final String title;
  final String? path;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ui.DecorationListItem(
    leading: ui.GlyphIcon(icon, size: 20),
    title: Text(title),
    subtitle: Text(
      path ?? context.l10n.notSelected,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    onPressed: onPressed,
    trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
  );
}

class _ToolActionCard extends StatelessWidget {
  const _ToolActionCard({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final ui.Glyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ui.DecorationListItem(
    leading: ui.GlyphIcon(glyph, size: 20),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    onPressed: onPressed,
    trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.trailing,
  });

  final ui.Glyph glyph;
  final String title;
  final String subtitle;
  final Color tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ui.CommonCard(
    inert: true,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        _IconTile(glyph: glyph, color: tone),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ui.AppTextStyle.headline.of(context, emphasized: true),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ui.AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (trailing case final trailing?) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.glyph, this.color});

  final ui.Glyph glyph;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colorScheme.primary;
    return Container(
      width: 44,
      height: 44,
      decoration: ShapeDecoration(
        color: color.opacity15,
        shape: ui.AppShape.all(14),
      ),
      child: Center(child: ui.GlyphIcon(glyph, size: 22, color: color)),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.glyph,
    required this.title,
    required this.path,
    required this.onPressed,
  });

  final ui.Glyph glyph;
  final String title;
  final String path;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ui.DecorationListItem(
    leading: ui.GlyphIcon(glyph, size: 20),
    title: Text(title),
    subtitle: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
    onPressed: onPressed,
    trailing: const ui.GlyphIcon(ui.AppGlyphs.openExternal, size: 20),
  );
}
