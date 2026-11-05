import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_paths.dart';
import '../../../core/game_entry.dart';
import '../../../core/settings_store.dart';
import '../../../core/task_center.dart';
import '../../../ui/context.dart';
import 'online_services.dart';
import 'online_widgets.dart';
import '../../../ui/localization.dart';
import '../../../ui/ui.dart' as ui;

enum _TrainerMode { browse, downloads, bindings }

enum _TrainerSource { recent, all, archive }

class TrainerToolsPage extends StatefulWidget {
  const TrainerToolsPage({
    super.key,
    required this.appPaths,
    required this.settings,
    required this.tasks,
    this.game,
    this.games = const [],
    this.service,
  });
  final AppPaths appPaths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final GameEntry? game;
  final List<GameEntry> games;
  final TrainerService? service;
  @override
  State<TrainerToolsPage> createState() => _TrainerToolsPageState();
}

class _TrainerToolsPageState extends State<TrainerToolsPage> {
  late final TrainerService _service;
  late final TextEditingController _query;
  List<TrainerEntry> _entries = [];
  List<DownloadedTrainer> _downloads = [];
  final Map<String, String> _downloadTasks = {};
  _TrainerMode _mode = _TrainerMode.browse;
  _TrainerSource _source = _TrainerSource.recent;
  bool _busy = false;
  Timer? _searchDebounce;
  late final ui.AppBarSearchState _searchState;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        TrainerService(paths: widget.appPaths, settings: widget.settings);
    _query = TextEditingController(text: widget.game?.name ?? '');
    _searchState = ui.AppBarSearchState(onSearch: _handleSearch);
    _service.addListener(_changed);
    widget.tasks.addListener(_changed);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _action(() async {
      await _service.loadBindings();
      await _refreshDownloads();
    });
    if (mounted) await _browse();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _query.dispose();
    _service.removeListener(_changed);
    widget.tasks.removeListener(_changed);
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  Future<void> _refreshDownloads() async {
    final files = await _service.downloaded();
    if (mounted) setState(() => _downloads = files);
  }

  void _handleSearch(String value) {
    _query.text = value;
    _searchDebounce?.cancel();
    if (_mode != _TrainerMode.browse) {
      setState(() {});
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 320),
      () => unawaited(_browse(search: value.trim().isNotEmpty)),
    );
  }

  void _setMode(_TrainerMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    if (mode == _TrainerMode.downloads) {
      unawaited(_action(_refreshDownloads));
    }
  }

  void _setSource(_TrainerSource source) {
    if (_busy || _source == source) return;
    setState(() => _source = source);
    unawaited(_browse());
  }

  Future<void> _browse({bool search = false}) async {
    setState(() => _busy = true);
    try {
      final entries = switch (_source) {
        _TrainerSource.archive => await _service.listArchive(),
        _TrainerSource.all when !search || _query.text.trim().isEmpty =>
          await _service.all(),
        _ when search && _query.text.trim().isNotEmpty => await _service.search(
          _query.text,
        ),
        _ => await _service.recent(),
      };
      final term = _query.text.trim().toLowerCase();
      if (mounted) {
        setState(() {
          _entries =
              search && _source == _TrainerSource.archive && term.isNotEmpty
              ? entries
                    .where((entry) => entry.name.toLowerCase().contains(term))
                    .toList()
              : entries;
        });
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _download(TrainerEntry entry) => _action(() async {
    if (_taskFor(entry)?.status == TaskStatus.running) return;
    final file = await widget.tasks.run(
      '${context.l10n.downloadTrainer} · ${entry.name}',
      (task) {
        _downloadTasks[entry.pageUrl] = task.task.id;
        _changed();
        return _service.download(entry, task: task);
      },
      appId: widget.game?.appId,
    );
    await _refreshDownloads();
    if (!mounted) return;
    final downloaded = _downloads
        .where((item) => p.equals(item.path, file.path))
        .firstOrNull;
    ui.showAppFeedback(
      context,
      '${context.l10n.downloaded} · ${p.basename(file.path)}${downloaded?.isExecutable == true ? '' : '\n${context.l10n.extractTrainerBeforeBinding}'}',
      level: ui.MessageLevel.success,
      actionState: ui.MessageActionState(
        actionText: downloaded?.isExecutable == true
            ? context.l10n.bindToGame
            : context.l10n.openFolder,
        action: downloaded?.isExecutable == true
            ? () => unawaited(_editBinding(trainer: downloaded))
            : () => launchUrl(Uri.directory(file.parent.path)),
      ),
    );
  });

  TaskProgress? _taskFor(TrainerEntry entry) => widget.tasks.tasks
      .where((task) => task.id == _downloadTasks[entry.pageUrl])
      .firstOrNull;

  Future<void> _details(TrainerEntry entry) => ui.showModalSideSheet<void>(
    context: context,
    builder: (_) => _TrainerDetailSheet(
      service: _service,
      entry: entry,
      onDownload: _download,
    ),
  );

  Future<void> _editBinding({
    TrainerBinding? binding,
    DownloadedTrainer? trainer,
  }) async {
    final game = widget.game;
    final appId = TextEditingController(
      text: '${binding?.appId ?? game?.appId ?? ''}',
    );
    final name = TextEditingController(
      text: binding?.gameName ?? game?.name ?? '',
    );
    final gamePath = TextEditingController(
      text: binding?.gameExecutable ?? game?.executablePath ?? '',
    );
    final trainerPath = TextEditingController(
      text: binding?.trainerPath ?? trainer?.path ?? '',
    );
    var enabled = binding?.enabled ?? true;
    String? formError;
    Future<void> pick(TextEditingController controller, String title) async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['exe'],
        dialogTitle: title,
      );
      final path = result?.files.single.path;
      if (path != null) controller.text = path;
    }

    final result = await ui.showFormSheet<TrainerBinding>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) {
          void save() {
            final parsedAppId = int.tryParse(appId.text.trim());
            final next = TrainerBinding(
              appId: parsedAppId ?? 0,
              gameName: name.text.trim(),
              gameExecutable: gamePath.text.trim(),
              trainerPath: trainerPath.text.trim(),
              enabled: enabled,
            );
            final error = parsedAppId == null || parsedAppId <= 0
                ? context.l10n.enterAValidAppid2
                : next.gameName.isEmpty
                ? context.l10n.enterTheGameName
                : next.gameExecutable.isEmpty
                ? context.l10n.chooseGameExecutable
                : next.trainerPath.isEmpty
                ? context.l10n.chooseTrainerExecutable
                : null;
            if (error != null) {
              update(() => formError = error);
              return;
            }
            Navigator.of(sheetContext).pop(next);
          }

          Widget pathField(TextEditingController controller, String tooltip) =>
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ui.FormRowTextField(
                      controller: controller,
                      hintText: context.l10n.notSelected,
                      onChanged: (_) => update(() => formError = null),
                    ),
                  ),
                  ui.CommonMinIconButtonTheme(
                    child: IconButton(
                      tooltip: tooltip,
                      onPressed: () => pick(controller, tooltip),
                      icon: const ui.GlyphIcon(
                        ui.AppGlyphs.resources,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              );

          return ui.FormPage(
            title: binding == null
                ? context.l10n.addGameBinding
                : context.l10n.editGameBinding,
            onSave: save,
            error: formError,
            children: [
              if (widget.games.isNotEmpty)
                ui.generateSection(
                  title: context.l10n.chooseAGame,
                  items: [
                    ui.FormRowSelect<int>(
                      title: context.l10n.chooseFromLibrary,
                      value: null,
                      options: [
                        for (final item in widget.games)
                          (item.appId, item.name),
                      ],
                      onChanged: (id) {
                        if (id == null) return;
                        final selected = widget.games.firstWhere(
                          (item) => item.appId == id,
                        );
                        appId.text = '${selected.appId}';
                        name.text = selected.name;
                        gamePath.text = selected.executablePath ?? '';
                        update(() => formError = null);
                      },
                    ),
                  ],
                ),
              ui.generateSection(
                title: context.l10n.basicInfo,
                items: [
                  ui.FormRow(
                    title: 'AppID',
                    trailing: ui.FormRowTextField(
                      controller: appId,
                      hintText: 'AppID',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => update(() => formError = null),
                    ),
                  ),
                  ui.FormRow(
                    title: context.l10n.gameName,
                    trailing: ui.FormRowTextField(
                      controller: name,
                      hintText: context.l10n.gameName,
                      onChanged: (_) => update(() => formError = null),
                    ),
                  ),
                  ui.FormRow(
                    title: context.l10n.gameExecutable,
                    trailing: pathField(
                      gamePath,
                      context.l10n.chooseGameExecutable,
                    ),
                  ),
                  ui.FormRow(
                    title: context.l10n.trainerExecutable,
                    trailing: pathField(
                      trainerPath,
                      context.l10n.chooseTrainerExecutable,
                    ),
                  ),
                  if (_downloads.any((item) => item.isExecutable))
                    ui.FormRowSelect<String>(
                      title: context.l10n.useADownloadedTrainer,
                      value: null,
                      options: [
                        for (final item in _downloads.where(
                          (item) => item.isExecutable,
                        ))
                          (item.path, item.name),
                      ],
                      onChanged: (path) {
                        if (path == null) return;
                        trainerPath.text = path;
                        update(() => formError = null);
                      },
                    ),
                  ui.FormRowSwitch(
                    title: context.l10n.startAndStopWithTheGame,
                    value: enabled,
                    onChanged: (value) => update(() => enabled = value),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    appId.dispose();
    name.dispose();
    gamePath.dispose();
    trainerPath.dispose();
    if (result != null) {
      await _action(() async {
        if (binding != null && binding.appId != result.appId) {
          await _service.removeBinding(binding.appId);
        }
        await _service.saveBinding(result);
      });
    }
  }

  Future<void> _delete(DownloadedTrainer item) async {
    final confirmed = await ui.AppDialogs.confirm(
      context,
      title: context.l10n.deleteTrainer,
      message:
          '${p.basename(item.path)}\n\n${context.l10n.associatedGameBindingsWillAlsoBeRemoved}',
      destructive: true,
    );
    if (confirmed == true) {
      await _action(() async {
        await _service.deleteDownloaded(item);
        await _refreshDownloads();
      });
    }
  }

  Widget _browseView() => _entries.isEmpty
      ? ui.NullStatus(
          label: _busy
              ? context.l10n.loadingFling
              : context.l10n.noMatchingTrainers,
          illustration: ui.NullStatusIllustration.search,
          action: _busy
              ? null
              : ui.TonalButton(
                  glyph: ui.AppGlyphs.refresh,
                  label: context.l10n.reload3,
                  onPressed: () => _browse(),
                ),
        )
      : LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 220,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final task = _taskFor(entry);
                final running = task?.status == TaskStatus.running;
                return ui.CommonCard(
                  key: ValueKey('trainer-${entry.pageUrl}'),
                  padding: EdgeInsets.zero,
                  shape: ui.AppShape.all(ui.AppCorner.xl),
                  onPressed: () => _details(entry),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ui.AppCorner.xl),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: ui.SurfaceLevel.card.colorOf(
                            context.colorScheme,
                          ),
                        ),
                        OnlineCover(url: entry.coverUrl, fit: BoxFit.cover),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, .32, .68, 1],
                              colors: [
                                Colors.transparent,
                                ui.SurfaceLevel.card
                                    .colorOf(context.colorScheme)
                                    .withValues(alpha: .08),
                                ui.SurfaceLevel.card
                                    .colorOf(context.colorScheme)
                                    .withValues(alpha: .78),
                                ui.SurfaceLevel.card
                                    .colorOf(context.colorScheme)
                                    .withValues(alpha: .96),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: ui.MetaChip(label: entry.source),
                              ),
                              const Spacer(),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: ui.AppTextStyle.subheadline.of(
                                            context,
                                            emphasized: true,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          [entry.updated, entry.size]
                                              .where((item) => item.isNotEmpty)
                                              .join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: ui.AppTextStyle.caption1
                                              .of(context)
                                              .copyWith(
                                                color: context
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ui.TonalButtonGroup(
                                    size: ui.TonalButtonSize.section,
                                    children: [
                                      IconButton(
                                        tooltip: context.l10n.details,
                                        onPressed: () => _details(entry),
                                        icon: const ui.GlyphIcon(
                                          ui.AppGlyphs.info,
                                          size: 18,
                                        ),
                                      ),
                                      if (running)
                                        IconButton(
                                          tooltip: context.l10n.cancelDownload,
                                          onPressed: () =>
                                              widget.tasks.cancel(task!.id),
                                          icon: const ui.GlyphIcon(
                                            ui.AppGlyphs.close,
                                            size: 18,
                                          ),
                                        )
                                      else
                                        IconButton(
                                          tooltip:
                                              task?.status ==
                                                  TaskStatus.succeeded
                                              ? context.l10n.downloadAgain
                                              : context.l10n.download,
                                          onPressed: () => _download(entry),
                                          icon: ui.GlyphIcon(
                                            task?.status == TaskStatus.succeeded
                                                ? ui.AppGlyphs.refresh
                                                : ui.AppGlyphs.cloudDownload,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (running)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ui.CommonProgressBar(
                              value: task?.progress,
                              height: 2,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

  Widget _downloadView() => _downloads.isEmpty
      ? ui.NullStatus(
          label: context.l10n.noDownloadedTrainers,
          description: context
              .l10n
              .downloadFromBrowseThenOpenArchivesToExtractAndBindAnExecutable,
          illustration: ui.NullStatusIllustration.data,
          action: ui.TonalButton(
            glyph: ui.AppGlyphs.resources,
            label: context.l10n.openFolder,
            onPressed: () =>
                _openFolder(widget.appPaths.file('downloads/trainers')),
          ),
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ui.generateSection(
              title: context.l10n.myTrainers,
              items: [
                for (final item in _downloads)
                  Builder(
                    builder: (context) {
                      final running = _service.isRunning(item.path);
                      return ui.DecorationListItem(
                        leading: ui.GlyphIcon(
                          item.isExecutable
                              ? ui.AppGlyphs.tools
                              : ui.AppGlyphs.importFile,
                          size: 20,
                        ),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${p.basename(item.path)} · ${onlineFileSize(item.size)}'
                          '${running ? ' · ${context.l10n.running}' : ''}${item.isExecutable ? '' : '\n${context.l10n.extractTrainerBeforeBinding}'}',
                        ),
                        onPressed: item.isExecutable
                            ? () => unawaited(_editBinding(trainer: item))
                            : () => _openFolder(p.dirname(item.path)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: running
                                  ? context.l10n.stop3
                                  : context.l10n.open,
                              icon: ui.GlyphIcon(
                                running
                                    ? ui.AppGlyphs.block
                                    : ui.AppGlyphs.bolt,
                                size: 20,
                              ),
                              onPressed: () => _action(() async {
                                if (running) {
                                  await _service.stopTrainer(item.path);
                                } else if (item.isExecutable) {
                                  await _service.startTrainer(item.path);
                                } else {
                                  await launchUrl(
                                    Uri.file(item.path),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              }),
                            ),
                            ui.CommonPopupBox(
                              targetBuilder: (open) => IconButton(
                                tooltip: context.l10n.manageTrainer,
                                onPressed: open,
                                icon: const ui.GlyphIcon(
                                  ui.AppGlyphs.more,
                                  size: 20,
                                ),
                              ),
                              popupBuilder: (_) => ui.CommonPopupMenu(
                                items: [
                                  if (item.isExecutable)
                                    ui.CommonPopupMenuItem(
                                      label: context.l10n.bindToGame,
                                      onPressed: () => unawaited(
                                        _editBinding(trainer: item),
                                      ),
                                    ),
                                  ui.CommonPopupMenuItem(
                                    label: context.l10n.openContainingFolder,
                                    onPressed: () => unawaited(
                                      _openFolder(p.dirname(item.path)),
                                    ),
                                  ),
                                  ui.CommonPopupMenuItem(
                                    label: context.l10n.createDesktopShortcut,
                                    onPressed: () => unawaited(
                                      _action(
                                        () => _service.createDesktopShortcut(
                                          item,
                                        ),
                                      ),
                                    ),
                                  ),
                                  ui.CommonPopupMenuItem(
                                    label: context.l10n.delete,
                                    danger: true,
                                    onPressed: () => unawaited(_delete(item)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
              footer: context
                  .l10n
                  .downloadFromBrowseThenOpenArchivesToExtractAndBindAnExecutable,
            ),
          ],
        );

  Widget _bindingsView() => _service.bindings.isEmpty
      ? ui.NullStatus(
          label: context.l10n.bindALocalTrainerToAGame,
          description: context
              .l10n
              .enabledTrainersStartAndStopWithTheDetectedGameProcess,
          illustration: ui.NullStatusIllustration.data,
          action: ui.TonalButton(
            glyph: ui.AppGlyphs.add,
            label: context.l10n.addBinding,
            onPressed: _editBinding,
          ),
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ui.generateSection(
              title: context.l10n.gameAndTrainerBindings,
              items: [
                for (final binding in _service.bindings)
                  Builder(
                    builder: (context) {
                      final running = _service.isRunning(binding.trainerPath);
                      return ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.connections,
                          size: 20,
                        ),
                        title: Text(binding.gameName),
                        subtitle: Text(
                          'AppID ${binding.appId} · '
                          '${p.basename(binding.trainerPath)}'
                          '${running ? ' · ${context.l10n.running}' : ''}',
                        ),
                        onPressed: () => _editBinding(binding: binding),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ui.CommonSwitch(
                              value: binding.enabled,
                              onChanged: (enabled) => _action(
                                () => _service.saveBinding(
                                  TrainerBinding(
                                    appId: binding.appId,
                                    gameName: binding.gameName,
                                    gameExecutable: binding.gameExecutable,
                                    trainerPath: binding.trainerPath,
                                    enabled: enabled,
                                  ),
                                ),
                              ),
                            ),
                            ui.CommonPopupBox(
                              targetBuilder: (open) => IconButton(
                                tooltip: context.l10n.manageTrainer,
                                onPressed: open,
                                icon: const ui.GlyphIcon(
                                  ui.AppGlyphs.more,
                                  size: 20,
                                ),
                              ),
                              popupBuilder: (_) => ui.CommonPopupMenu(
                                items: [
                                  ui.CommonPopupMenuItem(
                                    glyph: running
                                        ? ui.AppGlyphs.block
                                        : ui.AppGlyphs.bolt,
                                    label: running
                                        ? context.l10n.stop3
                                        : context.l10n.launch2,
                                    onPressed: () => _action(
                                      () => running
                                          ? _service.stopTrainer(
                                              binding.trainerPath,
                                            )
                                          : _service.startTrainer(
                                              binding.trainerPath,
                                            ),
                                    ),
                                  ),
                                  ui.CommonPopupMenuItem(
                                    glyph: ui.AppGlyphs.edit,
                                    label: context.l10n.editBinding,
                                    onPressed: () =>
                                        _editBinding(binding: binding),
                                  ),
                                  ui.CommonPopupMenuItem(
                                    glyph: ui.AppGlyphs.delete,
                                    label: context.l10n.removeBinding,
                                    danger: true,
                                    onPressed: () => _action(
                                      () =>
                                          _service.removeBinding(binding.appId),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
              footer: context
                  .l10n
                  .enabledTrainersStartAndStopWithTheDetectedGameProcess,
            ),
          ],
        );

  Future<void> _openFolder(String path) async {
    await _service.paths
        .directory(p.relative(path, from: widget.appPaths.root))
        .create(recursive: true);
    await launchUrl(Uri.directory(path));
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.trainers,
    isLoading: _busy,
    searchState: _mode == _TrainerMode.browse ? _searchState : null,
    searchHint: context.l10n.searchGameNames,
    actions: switch (_mode) {
      _TrainerMode.browse => [
        ui.DashboardIconButton(
          key: const ValueKey('trainer-source-recent'),
          glyph: ui.AppGlyphs.clock,
          tooltip: context.l10n.recentUpdates,
          selected: _source == _TrainerSource.recent,
          onPressed: _busy ? null : () => _setSource(_TrainerSource.recent),
        ),
        ui.DashboardIconButton(
          key: const ValueKey('trainer-source-all'),
          glyph: ui.AppGlyphs.appsList,
          tooltip: context.l10n.allTrainers,
          selected: _source == _TrainerSource.all,
          onPressed: _busy ? null : () => _setSource(_TrainerSource.all),
        ),
        ui.DashboardIconButton(
          key: const ValueKey('trainer-source-archive'),
          glyph: ui.AppGlyphs.layers,
          tooltip: context.l10n.archive,
          selected: _source == _TrainerSource.archive,
          onPressed: _busy ? null : () => _setSource(_TrainerSource.archive),
        ),
        ui.MetaChip(
          key: const ValueKey('trainer-count'),
          label: '${_entries.length}',
        ),
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: _busy ? null : () => _browse(),
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh, size: 20),
        ),
      ],
      _TrainerMode.downloads => [
        IconButton(
          tooltip: context.l10n.refresh,
          onPressed: () => _action(_refreshDownloads),
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh, size: 20),
        ),
        IconButton(
          tooltip: context.l10n.downloadFolder,
          onPressed: () =>
              _openFolder(widget.appPaths.file('downloads/trainers')),
          icon: const ui.GlyphIcon(ui.AppGlyphs.resources, size: 20),
        ),
      ],
      _TrainerMode.bindings => [
        IconButton(
          tooltip: context.l10n.addBinding,
          onPressed: _editBinding,
          icon: const ui.GlyphIcon(ui.AppGlyphs.add, size: 20),
        ),
      ],
    },
    body: Padding(
      padding: const EdgeInsets.only(top: ui.pageContentTopInset),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ui.SegmentedControl<_TrainerMode>(
              segments: [
                (_TrainerMode.browse, context.l10n.browse),
                (_TrainerMode.downloads, context.l10n.myTrainers),
                (_TrainerMode.bindings, context.l10n.gameBindings),
              ],
              value: _mode,
              onChanged: _setMode,
            ),
          ),
          Expanded(
            child: ui.FadeEdge(
              extent: 24,
              child: AnimatedSwitcher(
                duration: context.motionDuration(ui.commonDuration),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey(_mode),
                  child: switch (_mode) {
                    _TrainerMode.browse => _browseView(),
                    _TrainerMode.downloads => _downloadView(),
                    _TrainerMode.bindings => _bindingsView(),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrainerDetailSheet extends StatefulWidget {
  const _TrainerDetailSheet({
    required this.service,
    required this.entry,
    required this.onDownload,
  });

  final TrainerService service;
  final TrainerEntry entry;
  final Future<void> Function(TrainerEntry entry) onDownload;

  @override
  State<_TrainerDetailSheet> createState() => _TrainerDetailSheetState();
}

class _TrainerDetailSheetState extends State<_TrainerDetailSheet> {
  TrainerEntry? _detail;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final detail = await widget.service.details(widget.entry);
      if (mounted) {
        setState(() => _detail = detail);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return ui.SideSheetScaffold(
      title: detail?.name ?? widget.entry.name,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.sourcePage,
          onPressed: () => launchUrl(
            Uri.parse(widget.entry.pageUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const ui.GlyphIcon(ui.AppGlyphs.openExternal, size: 22),
        ),
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.download,
          onPressed: detail == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  unawaited(widget.onDownload(detail));
                },
          icon: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload, size: 22),
        ),
      ],
      body: _error != null
          ? ui.NullStatus(
              label: context.l10n.operationFailed,
              description: '$_error',
              illustration: ui.NullStatusIllustration.error,
            )
          : detail == null
          ? const Center(child: ui.CommonCircleLoading.page())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                ui.SideSheetScaffold.headerHeight + 16,
                16,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (detail.coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ui.AppCorner.xl),
                    child: OnlineCover(url: detail.coverUrl, height: 210),
                  ),
                ui.generateSection(
                  title: context.l10n.details,
                  items: [
                    if (detail.source.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.dns, size: 20),
                        title: Text(context.l10n.sourcePage),
                        trailing: Text(detail.source),
                      ),
                    if (detail.version.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.code,
                          size: 20,
                        ),
                        title: Text(context.l10n.versionLabel),
                        subtitle: Text(
                          detail.version,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (detail.size.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.layers,
                          size: 20,
                        ),
                        title: Text(context.l10n.fileSizeLabel),
                        trailing: Text(detail.size),
                      ),
                    if (detail.updated.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.clock,
                          size: 20,
                        ),
                        title: Text(context.l10n.updatedLabel),
                        trailing: Text(detail.updated),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ui.ExpandableTextCard(
                  title: context.l10n.descriptionLabel,
                  text: detail.description.isEmpty
                      ? context.l10n.thisArchiveIsAvailableForDirectDownload
                      : detail.description,
                  expandLabel: context.l10n.showMore,
                  collapseLabel: context.l10n.showLess,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ui.TonalButton(
                    glyph: ui.AppGlyphs.cloudDownload,
                    label: context.l10n.download,
                    onPressed: detail.downloadUrl == null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            unawaited(widget.onDownload(detail));
                          },
                  ),
                ),
              ],
            ),
    );
  }
}
