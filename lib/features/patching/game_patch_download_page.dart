import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'game_patch_source.dart';

class GamePatchDownloadPage extends StatefulWidget {
  const GamePatchDownloadPage({
    super.key,
    required this.paths,
    required this.tasks,
    required this.game,
  });

  final AppPaths paths;
  final TaskCenter tasks;
  final GameEntry game;

  @override
  State<GamePatchDownloadPage> createState() => _GamePatchDownloadPageState();
}

class _GamePatchDownloadPageState extends State<GamePatchDownloadPage> {
  late final GamePatchSourceService _service;
  List<GamePatchOption> _options = const [];
  GamePatchOption? _active;
  final List<({DateTime at, String level, String message})> _logs = [];
  bool _loading = false;
  bool _busy = false;
  double? _progress;
  String? _resultDirectory;

  @override
  void initState() {
    super.initState();
    _service = GamePatchSourceService(paths: widget.paths);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final texts = context.l10n;
    setState(() {
      _loading = true;
    });
    try {
      final options = await widget.tasks.run(
        texts.loadPatches,
        (task) => _service.loadPatches(widget.game.appId, context: task),
        appId: widget.game.appId,
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _active = null;
        _progress = null;
        _logs
          ..clear()
          ..add((
            at: DateTime.now(),
            level: 'info',
            message: texts.patchSourceLoaded('${options.length}'),
          ));
      });
    } catch (error) {
      if (!mounted) return;
      ui.showAppError(context, error);
      setState(
        () =>
            _logs.add((at: DateTime.now(), level: 'error', message: '$error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(GamePatchOption option) async {
    final texts = context.l10n;
    setState(() {
      _busy = true;
      _progress = null;
      _active = option;
      _resultDirectory = null;
      _logs
        ..clear()
        ..add((
          at: DateTime.now(),
          level: 'info',
          message: texts.downloadingPatch(_patchLabel(option)),
        ));
    });
    try {
      final result = await widget.tasks.run(texts.downloadPatch, (task) async {
        final result = await _service.downloadAndExtract(
          widget.game.appId,
          option,
          context: task,
        );
        task.report(result.directory, 1);
        return result;
      }, appId: widget.game.appId);
      if (!mounted) return;
      setState(() {
        _resultDirectory = result.directory;
        _progress = 1;
        _logs.add((
          at: DateTime.now(),
          level: 'success',
          message: texts.patchDownloadComplete(
            '${result.files}',
            _formatBytes(result.bytes),
            result.directory,
          ),
        ));
      });
      ui.showAppSuccess(
        context,
        texts.patchDownloadComplete(
          '${result.files}',
          _formatBytes(result.bytes),
          result.directory,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ui.showAppError(context, error);
      setState(() {
        _logs.add((
          at: DateTime.now(),
          level: 'error',
          message: texts.patchDownloadFailed('$error'),
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _openResult() async {
    final path = _resultDirectory;
    if (path == null) return;
    try {
      await _service.openDirectory(path);
    } catch (_) {
      if (mounted) {
        ui.showAppError(
          context,
          FormatException(context.l10n.outputDirectoryDoesNotExist),
        );
      }
    }
  }

  Future<void> _openGameFolder() async {
    final path = widget.game.installPath;
    if (path == null) return;
    try {
      await _service.openDirectory(path);
    } catch (_) {
      if (mounted) {
        ui.showAppError(
          context,
          FormatException(context.l10n.outputDirectoryDoesNotExist),
        );
      }
    }
  }

  String _patchLabel(GamePatchOption option) => switch (option.kind) {
    GamePatchKind.vm => context.l10n.virtualMachinePatch(option.buildId ?? ''),
    GamePatchKind.v38 => context.l10n.v38Patch,
    GamePatchKind.fix => context.l10n.onlinePatch,
    GamePatchKind.crack => context.l10n.offlinePatch,
    GamePatchKind.vbs => context.l10n.vbsPatch,
  };

  ui.Glyph _patchGlyph(GamePatchOption option) => switch (option.kind) {
    GamePatchKind.vm => ui.AppGlyphs.layers,
    GamePatchKind.v38 => ui.AppGlyphs.layers,
    GamePatchKind.fix => ui.AppGlyphs.link,
    GamePatchKind.crack => ui.AppGlyphs.puzzle,
    GamePatchKind.vbs => ui.AppGlyphs.devices,
  };

  static String _formatBytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    return ui.CommonScaffold(
      title: texts.gamePatchDownload,
      actions: [
        IconButton(
          tooltip: texts.openGameFolder,
          onPressed: _loading || _busy || widget.game.installPath == null
              ? null
              : _openGameFolder,
          icon: const ui.GlyphIcon(ui.AppGlyphs.openExternal),
        ),
        IconButton(
          tooltip: texts.refresh,
          onPressed: _loading || _busy ? null : _load,
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
            title: texts.game,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.profiles, size: 20),
                title: Text(
                  widget.game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'AppID ${widget.game.appId}'
                  '${widget.game.installPath == null ? '' : ' · ${p.basename(widget.game.installPath!)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ui.MetaChip(label: texts.networkSource),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const ui.CommonCard(
              inert: true,
              padding: EdgeInsets.all(18),
              child: ui.CommonCircleLoading(size: 22),
            ),
          if (_busy)
            ui.CommonCard(
              inert: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.downloadingPatch(
                      _active == null ? '' : _patchLabel(_active!),
                    ),
                    style: ui.AppTextStyle.subheadline.of(
                      context,
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ui.CommonProgressBar(value: _progress),
                ],
              ),
            ),
          if (_options.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ui.NullStatus(
                label: texts.noPatchesAvailable,
                description: texts.noPatchesAvailableDescription,
                illustration: ui.NullStatusIllustration.search,
                action: ui.TonalButton(
                  glyph: ui.AppGlyphs.refresh,
                  label: texts.retry,
                  onPressed: _busy ? null : _load,
                ),
              ),
            )
          else
            ui.generateSection(
              title: texts.patchType,
              items: [
                for (final option in _options)
                  ui.DecorationListItem(
                    leading: ui.GlyphIcon(_patchGlyph(option), size: 20),
                    title: Text(_patchLabel(option)),
                    subtitle: Text(
                      option.url.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: ui.TonalButton(
                      size: ui.TonalButtonSize.compact,
                      glyph: ui.AppGlyphs.cloudDownload,
                      label: texts.download,
                      onPressed: _loading || _busy
                          ? null
                          : () => _download(option),
                    ),
                  ),
              ],
              footer: texts.gamePatchDownloadFooter,
            ),
          if (_resultDirectory case final directory?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ui.CommonCard(
                inert: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ui.GlyphIcon(ui.AppGlyphs.checkCircle, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            texts.patchExtracted,
                            style: ui.AppTextStyle.subheadline.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                        ),
                        ui.TonalButton(
                          size: ui.TonalButtonSize.compact,
                          glyph: ui.AppGlyphs.openExternal,
                          label: texts.openFolder,
                          onPressed: _openResult,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      directory,
                      style: ui.AppTextStyle.caption1
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          if (_logs.isNotEmpty)
            ui.generateSection(
              title: texts.activityLog,
              items: [
                for (final log in _logs.reversed)
                  ui.LogRecordCard(
                    time: _formatTime(log.at),
                    level: log.level,
                    message: log.message,
                    tone: log.level == 'error'
                        ? ui.RecordTone.error
                        : log.level == 'success'
                        ? ui.RecordTone.neutral
                        : ui.RecordTone.neutral,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
