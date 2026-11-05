import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/game_entry.dart';
import '../core/task_center.dart';
import '../features/content_sources/content_import_dialog.dart';
import '../features/network/network_cover_image.dart';
import '../features/store/store_screenshot.dart';
import '../features/store/store_service.dart';
import '../ui/ui.dart' as ui;
import 'app_services.dart';
import 'widgets.dart';
import '../ui/localization.dart';

class GameDetailPage extends StatefulWidget {
  const GameDetailPage({
    super.key,
    required this.services,
    required this.game,
    required this.onDestination,
  });
  final AppServices services;
  final GameEntry game;
  final void Function(String, GameEntry) onDestination;

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  StoreGameDetails? _details;
  String? _detailsError;
  String? _dlcError;
  bool _loadingDetails = true;
  bool _loadingDlc = false;
  final Map<int, StoreGame> _dlc = {};
  final Set<int> _loadedDlc = {};
  Completer<void> _cancel = Completer<void>();

  AppServices get services => widget.services;
  GameEntry get game =>
      services.library.games
          .where((item) => item.appId == widget.game.appId)
          .firstOrNull ??
      GameEntry(
        appId: widget.game.appId,
        name: widget.game.name,
        coverUrl: widget.game.coverUrl,
        ownership: widget.game.ownership,
      );
  bool get _inLibrary =>
      services.library.games.any((item) => item.appId == widget.game.appId);
  bool get _busy => services.tasks.tasks.any(
    (task) =>
        task.appId == widget.game.appId && task.status == TaskStatus.running,
  );

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void didUpdateWidget(GameDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.appId != widget.game.appId ||
        oldWidget.services != widget.services) {
      _cancel.complete();
      _cancel = Completer<void>();
      _details = null;
      _detailsError = null;
      _dlc.clear();
      _loadedDlc.clear();
      _loadDetails();
    }
  }

  @override
  void dispose() {
    if (!_cancel.isCompleted) _cancel.complete();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final token = _cancel;
    setState(() {
      _loadingDetails = true;
      _detailsError = null;
    });
    try {
      final details = await services.store.details(
        widget.game.appId,
        cancelled: token.future,
      );
      if (mounted && identical(token, _cancel)) {
        setState(() => _details = details);
        await showAction(
          context,
          () => services.library.updateGameMetadata(
            details.appId,
            name: details.name,
            coverUrl: details.headerImage,
          ),
        );
      }
    } on StoreRequestCancelled {
      return;
    } catch (error) {
      if (mounted && identical(token, _cancel)) {
        setState(() => _detailsError = '$error');
      }
    } finally {
      if (mounted && identical(token, _cancel)) {
        setState(() => _loadingDetails = false);
      }
    }
  }

  Future<void> _loadDlc() async {
    final details = _details;
    if (details == null ||
        _loadingDlc ||
        details.dlcIds.every(_loadedDlc.contains)) {
      return;
    }
    final token = _cancel;
    setState(() {
      _loadingDlc = true;
      _dlcError = null;
    });
    try {
      for (final id in details.dlcIds.where((id) => !_loadedDlc.contains(id))) {
        final item = await services.store.details(id, cancelled: token.future);
        if (!mounted || !identical(token, _cancel)) return;
        setState(() {
          _dlc[id] = item;
          _loadedDlc.add(id);
        });
      }
    } on StoreRequestCancelled {
      return;
    } catch (error) {
      if (mounted && identical(token, _cancel)) {
        setState(() => _dlcError = '$error');
      }
    } finally {
      if (mounted && identical(token, _cancel)) {
        setState(() => _loadingDlc = false);
      }
    }
  }

  Future<void> _run(String title, Future<void> Function(TaskContext) action) =>
      showAction(
        context,
        () => services.tasks.run(title, action, appId: game.appId),
      );

  Future<void> _launch() async {
    final current = game;
    await _run(context.l10n.launch((current.name).toString()), (task) async {
      task.checkCancelled();
      await services.library.launch(current.appId);
    });
  }

  Future<void> _stop() async {
    final current = game;
    await _run(context.l10n.stop((current.name).toString()), (_) async {
      await services.library.stop(current.appId);
    });
  }

  Future<void> _download() async {
    final details = _details;
    final result = await showContentImportDialog(
      context,
      registry: services.contentSources,
      resolver: services.contentResolver,
      importer: services.contentImporter,
      tasks: services.tasks,
      appId: game.appId,
      gameName: game.name,
      dlcOptions: [
        for (final id in details?.dlcIds ?? const <int>[])
          ContentImportDlcOption(appId: id, name: _dlc[id]?.name ?? 'DLC $id'),
      ],
    );
    if (result != null && result.written.isNotEmpty) {
      await services.library.updateGameMetadata(
        game.appId,
        name: game.name,
        coverUrl: game.coverUrl,
      );
    }
  }

  Future<void> _deleteLua() async {
    final current = game;
    final accepted = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: context.l10n.deleteLuaRecord,
        destructive: true,
        actions: [
          ui.CommonDialogAction(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ui.CommonDialogAction(
            label: context.l10n.deleteRecord,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: SizedBox(
          width: 440,
          child: Text(
            '${context.l10n.onlyThisLuaFileIsRemovedTheGameStaysInstalledAndABackupIsSavedFirst}\n\n${current.luaPath}',
          ),
        ),
      ),
    );
    if (accepted == true && mounted) {
      await _run(
        context.l10n.deleteLuaRecord2,
        (_) => services.library.deleteLua(current.appId),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      services.library,
      services.tasks,
      services.settings,
    ]),
    builder: (context, _) {
      final current = game;
      final colors = Theme.of(context).colorScheme;
      return ui.CommonScaffold(
        title: current.name,
        actions: [
          IconButton(
            onPressed: !_inLibrary
                ? null
                : () => showAction(
                    context,
                    () => services.library.setFavorite(
                      current.appId,
                      !current.isFavorite,
                    ),
                  ),
            tooltip: (current.isFavorite
                ? context.l10n.unfavorite
                : context.l10n.favorite),
            icon: Icon(
              current.isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
          ),
          ui.CommonPopupBox(
            targetBuilder: (open) => IconButton(
              tooltip: context.l10n.manage,
              onPressed: open,
              icon: const Icon(Icons.more_vert),
            ),
            popupBuilder: (_) => ui.CommonPopupMenu(
              items: [
                for (final action in [
                  ('cloud', context.l10n.manageSaves),
                  ('achievements', context.l10n.manageAchievements),
                  ('trainers', context.l10n.trainers),
                  ('onlinefix', context.l10n.onlineFixes),
                  ('dlc_analysis', context.l10n.dlcAnalysis),
                  ('key_cache', context.l10n.keySubscriptionsOfflineLua),
                  ('tools', context.l10n.gameToolsAndVersionManagement),
                  ('patch_settings', context.l10n.patchSettings),
                  ('patch_download', context.l10n.gamePatchDownload),
                  ('lua_extraction', context.l10n.luaExtraction),
                  ('denuvo_extraction', context.l10n.denuvoTicketExtraction),
                ])
                  ui.CommonPopupMenuItem(
                    label: action.$2,
                    onPressed: () => widget.onDestination(action.$1, current),
                  ),
              ],
            ),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            28,
            ui.pageContentTopInset,
            28,
            32,
          ),
          children: [
            ui.CommonCard(
              radius: 28,
              inert: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cover = SizedBox(
                    width: constraints.maxWidth > 760
                        ? 330
                        : constraints.maxWidth,
                    height: 185,
                    child: NetworkCoverImage(
                      settings: services.settings,
                      appId: current.appId,
                      url: _details?.headerImage ?? current.imageUrl,
                      fit: BoxFit.cover,
                      previewable: true,
                      errorBuilder: (_, _, _) => DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primaryContainer,
                              colors.secondaryContainer,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.sports_esports_outlined,
                          size: 60,
                          color: colors.primary.withValues(alpha: .4),
                        ),
                      ),
                    ),
                  );
                  final content = Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ui.DashboardChip(label: 'AppID ${current.appId}'),
                            if (current.isRunning)
                              ui.DashboardChip(
                                label: context.l10n.running,
                                tone: ui.DashboardChipTone.ok,
                                dot: true,
                              ),
                            if (current.isInstalled)
                              ui.DashboardChip(label: context.l10n.installed),
                            if (current.hasLua)
                              ui.DashboardChip(
                                label: current.luaEnabled
                                    ? context.l10n.luaConfigured
                                    : context.l10n.luaDisabled,
                                tone: current.luaEnabled
                                    ? ui.DashboardChipTone.ok
                                    : ui.DashboardChipTone.idle,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (current.isInstalled)
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : current.isRunning
                                    ? _stop
                                    : _launch,
                                icon: Icon(
                                  current.isRunning
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                label: Text(
                                  (current.isRunning
                                      ? context.l10n.stopGame
                                      : context.l10n.play),
                                ),
                              )
                            else
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        context.l10n.installWithSteam,
                                        (_) => services.library.install(
                                          current.appId,
                                        ),
                                      ),
                                icon: const Icon(Icons.download_outlined),
                                label: Text(context.l10n.installWithSteam),
                              ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _download,
                              icon: const Icon(Icons.add),
                              label: Text(
                                (current.hasLua
                                    ? context.l10n.getLuaManifests
                                    : context.l10n.addToLibrary),
                              ),
                            ),
                            if (current.installPath != null)
                              IconButton.outlined(
                                onPressed: () => _run(
                                  context.l10n.openGameFolder,
                                  (_) => services.library.openDirectory(
                                    current.appId,
                                  ),
                                ),
                                tooltip: context.l10n.openGameFolder,
                                icon: const Icon(Icons.folder_open_outlined),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                  return constraints.maxWidth > 760
                      ? Row(
                          children: [
                            cover,
                            Expanded(child: content),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [cover, content],
                        );
                },
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  context,
                  Icons.schedule,
                  context.l10n.playtime,
                  formatGamePlaytime(context.l10n, current.playtimeMinutes),
                ),
                _metric(
                  context,
                  Icons.history,
                  context.l10n.lastPlayed,
                  current.lastPlayed == null
                      ? context.l10n.notRecorded
                      : _date(current.lastPlayed!),
                ),
                if (current.sizeOnDisk > 0)
                  _metric(
                    context,
                    Icons.storage_outlined,
                    context.l10n.diskSpace,
                    '${(current.sizeOnDisk / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
                  ),
                if (_details?.isFree == true ||
                    _details?.priceText.isNotEmpty == true)
                  _metric(
                    context,
                    Icons.local_offer_outlined,
                    context.l10n.storePrice,
                    _details!.isFree ? context.l10n.free : _details!.priceText,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 720
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _destination(
                      context,
                      width,
                      Icons.emoji_events_outlined,
                      context.l10n.achievements,
                      context.l10n.viewAndManageGameAchievements,
                      'achievements',
                    ),
                    _destination(
                      context,
                      width,
                      Icons.cloud_outlined,
                      context.l10n.cloudSaves,
                      context.l10n.backUpSyncAndRestoreProgress,
                      'cloud',
                    ),
                    _destination(
                      context,
                      width,
                      Icons.build_outlined,
                      context.l10n.gameManagement,
                      context.l10n.trainersMultiplayerAndMore,
                      'tools',
                    ),
                  ],
                );
              },
            ),
            if (current.hasLua) ...[
              const SizedBox(height: 24),
              ui.generateSection(
                title: context.l10n.luaRecord,
                items: [
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.code),
                    title: Text(context.l10n.luaRecord),
                    subtitle: Text(
                      current.luaEnabled
                          ? context.l10n.enabledTakesEffectAfterRestartingSteam
                          : context.l10n.disabledFileIsPreserved,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(
                            context.l10n.changeLuaState,
                            (_) => services.library.toggleLua(
                              current.appId,
                              !current.luaEnabled,
                            ),
                          ),
                    trailing: ui.CommonSwitch(
                      value: current.luaEnabled,
                      onChanged: _busy
                          ? null
                          : (value) => _run(
                              context.l10n.changeLuaState,
                              (_) => services.library.toggleLua(
                                current.appId,
                                value,
                              ),
                            ),
                    ),
                  ),
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.delete),
                    title: Text(context.l10n.deleteRecord),
                    subtitle: SelectableText(current.luaPath!),
                    onPressed: _busy ? null : _deleteLua,
                    trailing: const ui.GlyphIcon(
                      ui.AppGlyphs.chevronForward,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.aboutThisGame,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showAction(context, () async {
                    if (!await launchUrl(
                      Uri.https(
                        'store.steampowered.com',
                        '/app/${current.appId}/',
                      ),
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StateError('Could not open Steam store');
                    }
                  }),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(context.l10n.steamStore),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingDetails)
              const _StoreDetailsLoading()
            else if (_detailsError != null)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 300),
                child: ui.NullStatus(
                  label: context.l10n.steamStore,
                  description: context
                      .l10n
                      .storeDetailsAreUnavailableLocalGameActionsRemainAvailable,
                  illustration: ui.NullStatusIllustration.error,
                  scrollable: false,
                  action: ui.TonalButton(
                    glyph: ui.AppGlyphs.refresh,
                    label: context.l10n.retry,
                    onPressed: _loadDetails,
                  ),
                ),
              )
            else if (_details != null) ...[
              ui.CommonCard(
                padding: EdgeInsets.zero,
                inert: true,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_details!.description.isNotEmpty)
                        SelectableText(
                          _details!.description,
                          style: const TextStyle(height: 1.8),
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final genre in _details!.genres)
                            ui.DashboardChip(label: genre),
                        ],
                      ),
                      if (_details!.developers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '${context.l10n.developer}: ${_details!.developers.join(', ')}',
                          ),
                        ),
                      if (_details!.releaseDate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${context.l10n.released}: ${_details!.releaseDate}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_details!.screenshots.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _details!.screenshots.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => StoreScreenshot(
                      url: _details!.screenshots[index],
                      width: 320,
                      height: 190,
                      onTap: () => showStoreScreenshotPreview(
                        context,
                        urls: _details!.screenshots,
                        initialIndex: index,
                      ),
                    ),
                  ),
                ),
              ],
              if (_details!.dlcIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                ui.CollapsibleSection(
                  key: const ValueKey('game-dlc-section'),
                  label: 'DLC',
                  itemCount: _details!.dlcIds.length,
                  initiallyExpanded: false,
                  loading: _loadingDlc,
                  onExpandedChanged: (expanded) {
                    if (expanded) _loadDlc();
                  },
                  itemBuilder: (context, index) {
                    final id = _details!.dlcIds[index];
                    return ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.dataUsage),
                      title: Text(_dlc[id]?.name ?? 'DLC $id'),
                      subtitle: Text('AppID $id'),
                    );
                  },
                ),
                if (_dlcError != null) ui.ListFooter(text: _dlcError!),
              ],
            ],
          ],
        ),
      );
    },
  );

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => ui.CommonCard(
    padding: EdgeInsets.zero,
    inert: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _destination(
    BuildContext context,
    double width,
    IconData icon,
    String title,
    String description,
    String destination,
  ) => SizedBox(
    width: width,
    child: ui.CommonCard(
      padding: EdgeInsets.zero,
      inert: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onDestination(destination, game),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    ),
  );

  static String _date(DateTime date) =>
      '${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}';
}

class _StoreDetailsLoading extends StatelessWidget {
  const _StoreDetailsLoading();

  @override
  Widget build(BuildContext context) => ui.CommonCard(
    key: const ValueKey('store-details-loading'),
    padding: EdgeInsets.zero,
    inert: true,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ui.SkeletonPill(width: width, height: 14),
              const SizedBox(height: 10),
              ui.SkeletonPill(width: width * .92, height: 14),
              const SizedBox(height: 10),
              ui.SkeletonPill(width: width * .78, height: 14),
              const SizedBox(height: 22),
              ui.SkeletonPill(width: width * .34, height: 22),
            ],
          );
        },
      ),
    ),
  );
}
