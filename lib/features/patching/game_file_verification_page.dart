import 'package:flutter/material.dart';

import '../../core/game_entry.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../tools/tools_service.dart';
import 'game_file_verification.dart';

enum _VerificationFilter { all, issues, unexpected }

class GameFileVerificationPage extends StatefulWidget {
  const GameFileVerificationPage({
    super.key,
    required this.game,
    required this.tools,
    required this.tasks,
  });

  final GameEntry game;
  final ToolsService tools;
  final TaskCenter tasks;

  @override
  State<GameFileVerificationPage> createState() =>
      _GameFileVerificationPageState();
}

class _GameFileVerificationPageState extends State<GameFileVerificationPage> {
  late final GameFileVerificationService _service;
  late final ui.AppBarSearchState _searchState;
  _VerificationFilter _filter = _VerificationFilter.all;
  GameFileVerificationResult? _result;
  bool _busy = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _service = GameFileVerificationService(tools: widget.tools);
    _searchState = ui.AppBarSearchState(
      onSearch: (value) => setState(() => _query = value),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    final texts = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.tasks.run(
        texts.verifyGameFiles,
        (task) => _service.verify(widget.game, context: task),
        appId: widget.game.appId,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      ui.showAppError(context, error);
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<GameFileCheck> _visibleFiles(GameFileVerificationResult result) {
    final query = _query.trim().toLowerCase();
    return result.files.where((file) {
      final matchesQuery =
          query.isEmpty || file.path.toLowerCase().contains(query);
      if (!matchesQuery) return false;
      return switch (_filter) {
        _VerificationFilter.all => true,
        _VerificationFilter.issues =>
          file.state == GameFileState.missing ||
              file.state == GameFileState.changed ||
              file.state == GameFileState.unverified,
        _VerificationFilter.unexpected =>
          file.state == GameFileState.unexpected,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    final result = _result;
    final filtered = result == null
        ? const <GameFileCheck>[]
        : _visibleFiles(result);
    return ui.CommonScaffold(
      title: texts.gameFileVerification,
      searchState: _searchState,
      searchHint: texts.searchFiles,
      actions: [
        IconButton(
          tooltip: texts.refresh,
          onPressed: _busy ? null : _run,
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: texts.verificationTarget,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.profiles, size: 20),
                title: Text(
                  widget.game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  widget.game.installPath ?? texts.gameDirectoryUnavailable,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ui.MetaChip(
                  label: widget.game.isInstalled
                      ? texts.installed
                      : texts.notInstalled,
                ),
              ),
            ],
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ui.CommonCard(
                inert: true,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texts.verifyGameFiles,
                      style: ui.AppTextStyle.subheadline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ui.CommonProgressBar(value: null),
                  ],
                ),
              ),
            ),
          if (result != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _summary(result),
            ),
            if (result.warnings.isNotEmpty)
              ui.generateSection(
                title: texts.manifestNotes,
                items: [
                  for (final warning in result.warnings)
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(
                        ui.AppGlyphs.warning,
                        size: 20,
                      ),
                      title: Text(
                        warning,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                footer: texts.manifestVerificationWarning,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ui.SegmentedControl<_VerificationFilter>(
                segments: [
                  (_VerificationFilter.all, texts.allFiles),
                  (_VerificationFilter.issues, texts.issuesOnly),
                  (_VerificationFilter.unexpected, texts.unexpectedFiles),
                ],
                value: _filter,
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ui.NullStatus(
                  label: texts.noMatchingFiles,
                  illustration: ui.NullStatusIllustration.search,
                ),
              )
            else
              ui.generateSection(
                title: texts.verificationResults,
                items: [for (final file in filtered) _fileRow(file)],
                footer:
                    '${texts.unexpectedFilesHint}\n${texts.unverifiedFilesHint}',
              ),
          ] else if (!_busy && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: ui.NullStatus(
                label: texts.verifyGameFiles,
                description: texts.verificationEmptyDescription,
                illustration: ui.NullStatusIllustration.steam,
                action: ui.TonalButton(
                  glyph: ui.AppGlyphs.verified,
                  label: texts.startVerification,
                  onPressed: _run,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summary(GameFileVerificationResult result) => ui.CommonCard(
    inert: true,
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ui.GlyphIcon(ui.AppGlyphs.verified, size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.manifestCount == 0
                    ? context.l10n.manifestInventoryOnly
                    : result.manifestCount < result.depotCount
                    ? context.l10n.manifestPartialSummary
                    : result.issueCount == 0
                    ? context.l10n.filesMatchManifests
                    : context.l10n.filesNeedAttention('${result.issueCount}'),
                style: ui.AppTextStyle.headline.of(context, emphasized: true),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ui.MetaChip(
                    label: context.l10n.verifiedCount(
                      '${result.verifiedCount}',
                    ),
                  ),
                  ui.MetaChip(
                    label: context.l10n.missingCount('${result.missingCount}'),
                  ),
                  ui.MetaChip(
                    label: context.l10n.changedCount('${result.changedCount}'),
                  ),
                  ui.MetaChip(
                    label: context.l10n.unexpectedCount(
                      '${result.unexpectedCount}',
                    ),
                  ),
                  if (result.unverifiedCount > 0)
                    ui.MetaChip(
                      label: context.l10n.unverifiedCount(
                        '${result.unverifiedCount}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.manifestSummary(
                  '${result.depotCount}',
                  '${result.manifestCount}',
                ),
                style: ui.AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _fileRow(GameFileCheck file) {
    final (label, glyph, color) = switch (file.state) {
      GameFileState.verified => (
        context.l10n.verified,
        ui.AppGlyphs.checkCircle,
        context.colorScheme.primary,
      ),
      GameFileState.missing => (
        context.l10n.missing,
        ui.AppGlyphs.error,
        context.colorScheme.error,
      ),
      GameFileState.changed => (
        context.l10n.changed,
        ui.AppGlyphs.warning,
        context.colorScheme.error,
      ),
      GameFileState.unexpected => (
        context.l10n.unexpected,
        ui.AppGlyphs.info,
        context.colorScheme.onSurfaceVariant,
      ),
      GameFileState.unverified => (
        context.l10n.unverified,
        ui.AppGlyphs.info,
        context.colorScheme.onSurfaceVariant,
      ),
    };
    final details = <String>[
      if (file.depotId != null) 'Depot ${file.depotId}',
      if (file.expectedSize != null)
        context.l10n.expectedSize('${file.expectedSize}'),
      if (file.actualSize != null)
        context.l10n.actualSize('${file.actualSize}'),
    ];
    return ui.DecorationListItem(
      leading: ui.GlyphIcon(glyph, size: 20, color: color),
      title: Text(file.path, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: ui.MetaChip(label: label),
    );
  }
}
