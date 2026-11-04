import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/ui.dart' as ui;
import '../content_sources/content_source_registry.dart';
import '../steam_protocol/steam_protocol_service.dart';
import 'dlc_analysis_service.dart';
import '../../ui/localization.dart';

class DlcAnalysisPage extends StatefulWidget {
  const DlcAnalysisPage({
    super.key,
    required this.paths,
    required this.settings,
    required this.tasks,
    this.game,
    this.protocol,
    this.service,
    required this.contentSources,
    this.onChanged,
  });
  final AppPaths paths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final GameEntry? game;
  final SteamProtocolService? protocol;
  final DlcAnalysisService? service;
  final ContentSourceRegistry contentSources;
  final VoidCallback? onChanged;

  @override
  State<DlcAnalysisPage> createState() => _DlcAnalysisPageState();
}

class _DlcAnalysisPageState extends State<DlcAnalysisPage> {
  late final DlcAnalysisService _service;
  late final ContentSourceRegistry _contentSources;
  late final TextEditingController _appId;
  late final TextEditingController _luaPath;
  DlcAnalysisResult? _result;
  final Set<int> _selected = {};
  DlcDepotKind? _filter;
  bool _busy = false;
  bool _deferredDispose = false;
  String? _sourceId;

  @override
  void initState() {
    super.initState();
    _contentSources = widget.contentSources;
    _contentSources.addListener(_sourcesChanged);
    _loadSources();
    _service =
        widget.service ??
        DlcAnalysisService(
          paths: widget.paths,
          settings: widget.settings,
          protocol: widget.protocol,
          readCache: _contentSources.readKeyCache,
        );
    _appId = TextEditingController(text: widget.game?.appId.toString() ?? '');
    _luaPath = TextEditingController(text: widget.game?.luaPath ?? '');
  }

  Future<void> _loadSources() async {
    try {
      await _contentSources.loadKeyCacheSources();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  void _sourcesChanged() {
    if (!mounted) return;
    setState(() {
      if (!_contentSources.keyCacheSources.any(
        (source) => source.id == _sourceId && source.enabled,
      )) {
        _sourceId = null;
      }
      _result = null;
    });
  }

  @override
  void dispose() {
    _appId.dispose();
    _luaPath.dispose();
    _contentSources.removeListener(_sourcesChanged);
    if (_busy) {
      _deferredDispose = true;
    } else {
      _disposeOwnedResources();
    }
    super.dispose();
  }

  void _disposeOwnedResources() {
    if (widget.service == null) _service.dispose();
  }

  Future<void> _analyze() async {
    final localeText = context.l10n;
    final appId = int.tryParse(_appId.text.trim());
    if (appId == null || appId <= 0 || appId > 0xffffffff) {
      ui.showAppError(context, FormatException(localeText.enterAValidAppid3));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.tasks.run(
        localeText.dlcAnalysis2((appId).toString()),
        (task) => _service.analyze(
          appId,
          luaPath: _luaPath.text.trim(),
          sourceId: _sourceId,
          task: task,
        ),
        appId: appId,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _selected
          ..clear()
          ..addAll(
            result.items
                .where((item) => item.suggestions.isNotEmpty)
                .map((item) => item.appId),
          );
      });
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (_deferredDispose) _disposeOwnedResources();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickLua() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lua'],
    );
    if (selected != null && mounted) {
      setState(() {
        _luaPath.text = selected.files.single.path ?? '';
        _result = null;
      });
    }
  }

  Future<void> _apply() async {
    final localeText = context.l10n;
    final result = _result!;
    final selected = Set<int>.of(_selected);
    final preview = result.preview(selected);
    final confirm = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: localeText.confirmDlcAdditions,
        actions: [
          ui.CommonDialogAction(
            label: localeText.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ui.CommonDialogAction(
            label: localeText.backUpAndAppend,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localeText
                      .theExistingLuaWillBeBackedUpOnlyTheSelectedLinesBelowAreAppendedExistingScriptsKeysAn,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  preview,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final count = await widget.tasks.run(
        localeText.saveDlcSuggestions((result.appId).toString()),
        (task) => _service.apply(result, selected, task: task),
        appId: result.appId,
      );
      widget.onChanged?.call();
      if (mounted) {
        setState(() => _result = null);
        ui.showAppSuccess(
          context,
          localeText.appendedLinesAnalyzeAgainToVerifyTheCurrentConfiguration(
            (count).toString(),
          ),
        );
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (_deferredDispose) _disposeOwnedResources();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _kindLabel(DlcDepotKind kind) => switch (kind) {
    DlcDepotKind.unknown => context.l10n.queryFailedUnknown,
    DlcDepotKind.noDepot => context.l10n.noIndependentDepot,
    DlcDepotKind.singleDepot => context.l10n.singleDepot,
    DlcDepotKind.multiDepot => context.l10n.multipleDepots,
    DlcDepotKind.inMainDepot => context.l10n.inTheMainGame,
  };

  Iterable<DlcAnalysisItem> _selectableItems(DlcAnalysisResult result) =>
      result.items.where((item) => item.suggestions.isNotEmpty);

  void _selectAllItems() {
    final result = _result;
    if (result == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(_selectableItems(result).map((item) => item.appId));
    });
  }

  void _clearSelectedItems() => setState(_selected.clear);

  Future<void> _showPreview(String preview) => ui.showModalSideSheet<void>(
    context: context,
    builder: (_) => ui.SideSheetScaffold(
      title: context.l10n.previewDlcChanges,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.copySuggestions,
          onPressed: () => Clipboard.setData(ClipboardData(text: preview)),
          icon: const ui.GlyphIcon(ui.AppGlyphs.copy, size: 24),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.CommonCard(
            inert: true,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              preview,
              style: ui.AppTextStyle.caption1
                  .of(context)
                  .copyWith(fontFamily: 'Consolas', height: 1.6),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    final result = _result;
    final preview = result?.preview(_selected) ?? '';
    final filteredItems =
        result?.items
            .where((item) => _filter == null || item.kind == _filter)
            .toList() ??
        const <DlcAnalysisItem>[];
    return ui.CommonScaffold(
      title: texts.dlcAnalysis,
      isLoading: _busy,
      actions: [
        ui.DashboardIconButton(
          key: const ValueKey('dlc-analysis-start'),
          glyph: ui.AppGlyphs.refresh,
          tooltip: texts.analyzeDlc,
          onPressed: _busy ? null : _analyze,
        ),
        if (result != null)
          ui.DashboardIconButton(
            glyph: ui.AppGlyphs.selectAll,
            tooltip: texts.selectAll,
            onPressed: _busy ? null : _selectAllItems,
          ),
        if (_selected.isNotEmpty)
          ui.DashboardIconButton(
            glyph: ui.AppGlyphs.clearAll,
            tooltip: texts.clearSelection,
            onPressed: _busy ? null : _clearSelectedItems,
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
          _configurationSection(texts),
          if (result != null) ...[
            const SizedBox(height: 18),
            _resultSummary(result),
            for (final warning in result.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ui.CommonNotice(
                  message: warning,
                  level: ui.MessageLevel.warning,
                ),
              ),
            const SizedBox(height: 12),
            ui.generateSection(
              title: texts.allDlc,
              items: [
                ui.FormRowSelect<DlcDepotKind>(
                  title: texts.dlcDepotStructure,
                  value: _filter,
                  options: [
                    (null, texts.allDlcStructures),
                    for (final kind in DlcDepotKind.values)
                      (kind, _kindLabel(kind)),
                  ],
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ],
            ),
            if (result.items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ui.NullStatus(
                  label: texts.steamReturnedNoDlcForThisGame,
                  illustration: ui.NullStatusIllustration.data,
                ),
              )
            else if (filteredItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: ui.NullStatus(
                  label: texts.noSearchResults,
                  illustration: ui.NullStatusIllustration.search,
                ),
              )
            else
              ui.generateSection(
                items: [
                  for (final item in filteredItems) _dlcItemRow(item, texts),
                ],
              ),
            if (result.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              _selectionActions(result, preview, texts),
            ],
          ] else if (!_busy)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ui.NullStatus(
                label: texts.dlcAnalysis,
                illustration: ui.NullStatusIllustration.lua,
                action: ui.TonalButton(
                  key: const ValueKey('dlc-analysis-empty-refresh'),
                  glyph: ui.AppGlyphs.refresh,
                  label: texts.analyzeDlc,
                  onPressed: _analyze,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _configurationSection(AppLocalizations texts) => ui.generateSection(
    title: texts.dlcManagementAndAnalysis,
    items: [
      if (widget.game case final game?)
        ui.DecorationListItem(
          leading: const ui.GlyphIcon(ui.AppGlyphs.profiles, size: 20),
          title: Text(game.name),
          subtitle: Text('AppID ${game.appId}'),
          trailing: const ui.MetaChip(label: 'DLC'),
        ),
      ui.FormRowSelect<String>(
        key: const ValueKey('dlc-analysis-content-source'),
        title: texts.contentSourceSubscriptionOptional,
        value: _sourceId ?? '',
        options: [
          ('', texts.doNotUseASubscriptionCache),
          for (final source in _contentSources.keyCacheSources.where(
            (source) => source.enabled,
          ))
            (source.id, source.name),
        ],
        enabled: !_busy,
        onChanged: (value) => setState(() {
          _sourceId = value == null || value.isEmpty ? null : value;
          _result = null;
        }),
      ),
      ui.FormRow(
        title: 'AppID',
        leading: const ui.GlyphIcon(ui.AppGlyphs.appsList, size: 20),
        trailing: ui.FormRowTextField(
          key: const ValueKey('dlc-analysis-app-id'),
          controller: _appId,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          hintText: 'AppID',
          onChanged: (_) => setState(() => _result = null),
        ),
      ),
      ui.DecorationListItem(
        leading: const ui.GlyphIcon(ui.AppGlyphs.code, size: 20),
        title: Text(
          _luaPath.text.isEmpty ? texts.existingLuaFile : _luaPath.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _luaPath.text.isEmpty ? null : Text(texts.existingLuaFile),
        onPressed: _busy ? null : _pickLua,
        trailing: IconButton(
          tooltip: texts.chooseLua,
          onPressed: _busy ? null : _pickLua,
          icon: const ui.GlyphIcon(ui.AppGlyphs.importFile, size: 20),
        ),
      ),
    ],
  );

  Widget _resultSummary(DlcAnalysisResult result) {
    final configured = result.items.where((item) => item.isConfigured).length;
    return ui.CommonCard(
      inert: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ui.AppTextStyle.title2.of(context, emphasized: true),
                ),
              ),
              ui.MetaChip(label: '${result.items.length} DLC'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ui.MetaChip(label: 'AppID ${result.appId}'),
              if (result.luaPath != null)
                ui.MetaChip(label: context.l10n.luaFile),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.mainDepotsDlcReferencedByLua(
              '${result.mainDepotCount}',
              '$configured',
            ),
            style: ui.AppTextStyle.caption1
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
          if (result.luaPath case final path?) ...[
            const SizedBox(height: 10),
            SelectableText(
              path,
              style: ui.AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dlcItemRow(DlcAnalysisItem item, AppLocalizations texts) {
    final selectable = item.suggestions.isNotEmpty;
    final details = [
      if (item.depotIds.isNotEmpty) 'Depot ${item.depotIds.join(', ')}',
      if (item.missingKeys.isNotEmpty)
        texts.missingKeysSkipped(item.missingKeys.join(', ')),
      if (item.error != null) item.error!,
    ];
    return ui.SelectedDecorationListItem(
      isSelected: _selected.contains(item.appId),
      invalid: item.error != null,
      onSelected: selectable && !_busy
          ? () => setState(() {
              if (_selected.contains(item.appId)) {
                _selected.remove(item.appId);
              } else {
                _selected.add(item.appId);
              }
            })
          : () {},
      onPressed: selectable && !_busy
          ? () => setState(() {
              if (_selected.contains(item.appId)) {
                _selected.remove(item.appId);
              } else {
                _selected.add(item.appId);
              }
            })
          : () {},
      leading: ui.GlyphIcon(
        item.isConfigured ? ui.AppGlyphs.checkCircle : ui.AppGlyphs.puzzle,
        size: 20,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ui.MetaChip(label: '${item.appId}'),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ui.MetaChip(label: _kindLabel(item.kind)),
              ui.MetaChip(
                label: item.isConfigured
                    ? texts.referenced
                    : texts.notConfigured,
              ),
              if (selectable)
                ui.MetaChip(
                  label: texts.luaSuggestedLines(
                    item.isConfigured ? texts.referenced : texts.notConfigured,
                    '${item.suggestions.length}',
                  ),
                ),
            ],
          ),
          if (details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                details.join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: ui.AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionActions(
    DlcAnalysisResult result,
    String preview,
    AppLocalizations texts,
  ) => ui.CommonCard(
    inert: true,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ui.GlyphIcon(ui.AppGlyphs.code, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${texts.selectedAdditions} · ${_selected.length}',
                style: ui.AppTextStyle.headline.of(context, emphasized: true),
              ),
            ),
          ],
        ),
        if (preview.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              texts.noLinesSelected,
              style: ui.AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ui.TonalButton(
              size: ui.TonalButtonSize.compact,
              glyph: ui.AppGlyphs.copy,
              label: texts.copySuggestions,
              onPressed: preview.isEmpty
                  ? null
                  : () => Clipboard.setData(ClipboardData(text: preview)),
            ),
            ui.TonalButton(
              size: ui.TonalButtonSize.compact,
              glyph: ui.AppGlyphs.eye,
              label: texts.previewDlcChanges,
              onPressed: preview.isEmpty ? null : () => _showPreview(preview),
            ),
            ui.TonalButton(
              key: const ValueKey('dlc-analysis-apply'),
              glyph: ui.AppGlyphs.check,
              label: texts.previewAndAppendToLua,
              onPressed: _busy || preview.isEmpty || result.luaPath == null
                  ? null
                  : _apply,
            ),
          ],
        ),
      ],
    ),
  );
}
