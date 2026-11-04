import 'package:flutter/material.dart';

import '../../core/game_entry.dart';
import '../../ui/context.dart';
import '../../ui/ui.dart' as ui;
import 'achievement_models.dart';
import 'achievement_service.dart';
import '../../ui/localization.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({
    super.key,
    required this.service,
    required this.games,
    required this.steamPath,
    this.selectedGame,
    this.language = 'zh',
  });
  final AchievementService service;
  final List<GameEntry> games;
  final String steamPath;
  final GameEntry? selectedGame;
  final String language;

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final _gameSearch = TextEditingController();
  final _achievementSearch = TextEditingController();
  final _statsSearch = TextEditingController();
  String _search = '';
  String _statSearch = '';
  String _filter = 'all';
  String _gameSort = 'name';
  bool _gameGrid = true;
  bool _editorOpen = false;
  int _segment = 0;
  late final ui.AppBarSearchState _searchState;

  @override
  void initState() {
    super.initState();
    _searchState = ui.AppBarSearchState(
      onSearch: (value) {
        if (!_editorOpen) {
          _gameSearch.text = value;
        } else if (_segment == 0) {
          _achievementSearch.text = value;
          _search = value;
        } else {
          _statsSearch.text = value;
          _statSearch = value;
        }
        setState(() {});
      },
    );
    if (widget.selectedGame != null) {
      _editorOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(widget.selectedGame!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AchievementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGame != null &&
        widget.selectedGame?.appId != oldWidget.selectedGame?.appId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openGame(widget.selectedGame!);
      });
    }
  }

  @override
  void dispose() {
    _gameSearch.dispose();
    _achievementSearch.dispose();
    _statsSearch.dispose();
    super.dispose();
  }

  Future<void> _openGame(GameEntry game) async {
    if (widget.service.game?.appId == game.appId &&
        widget.service.data != null) {
      setState(() => _editorOpen = true);
      return;
    }
    await _load(game);
  }

  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        ui.showAppError(context, error);
      }
      return false;
    }
  }

  Future<void> _load(GameEntry game) async {
    final localeText = context.l10n;
    if (widget.service.isLoading || widget.service.isSaving) return;
    if (widget.service.hasChanges) {
      final discard = await ui.showFlDialog<bool>(
        context: context,
        builder: (context) => ui.CommonDialog(
          title: localeText.discardPendingChanges,
          destructive: true,
          actions: [
            ui.CommonDialogAction(
              label: localeText.keepEditing,
              onPressed: () => Navigator.pop(context, false),
            ),
            ui.CommonDialogAction(
              label: localeText.discardAndContinue,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
          child: Text(
            localeText
                .reloadingOrSwitchingGamesDiscardsUnsavedAchievementAndStatisticChanges,
          ),
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      _editorOpen = true;
      _filter = 'all';
      _search = '';
      _statSearch = '';
      _achievementSearch.clear();
      _statsSearch.clear();
    });
    await _run(() => widget.service.load(game, steamPath: widget.steamPath));
  }

  void _batch(String action) {
    final service = widget.service;
    for (final item in service.data!.achievements) {
      if ((item.permission & 3) != 0) continue;
      final current = service.pending[item.id] ?? item.achieved;
      service.setAchievement(item.id, switch (action) {
        'unlock' => true,
        'lock' => false,
        _ => !current,
      });
    }
  }

  Widget _cover(GameEntry game, {double? width, double? height}) => ui.AppImage(
    url: game.imageUrl,
    width: width,
    height: height,
    fit: BoxFit.cover,
    borderRadius: BorderRadius.circular(8),
    placeholderGlyph: ui.AppGlyphs.photos,
  );

  Widget _gameBrowser(BuildContext context, List<GameEntry> allGames) {
    final service = widget.service;
    final busy = service.isLoading || service.isSaving;
    final contentTopPadding = service.hasChanges ? 0.0 : ui.pageContentTopInset;
    final query = _gameSearch.text.trim().toLowerCase();
    final games = allGames.where((game) {
      return query.isEmpty ||
          game.name.toLowerCase().contains(query) ||
          '${game.appId}'.contains(query);
    }).toList();
    games.sort(
      (a, b) => switch (_gameSort) {
        'name_desc' => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        'appid' => a.appId.compareTo(b.appId),
        'appid_desc' => b.appId.compareTo(a.appId),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      },
    );
    Widget fadeList(Widget child) => service.hasChanges
        ? ui.FadeEdge(
            key: const ValueKey('achievement-game-list-fade'),
            extent: 24,
            child: child,
          )
        : child;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (service.hasChanges &&
              service.game != null &&
              service.data != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: ui.pageContentTopInset),
              child: ui.generateGroup([
                ui.DecorationListItem(
                  key: const ValueKey('achievement-continue-editing'),
                  leading: const ui.GlyphIcon(ui.AppGlyphs.edit),
                  title: Text(
                    context.l10n.continueEditing(
                      (service.game!.name).toString(),
                    ),
                  ),
                  subtitle: Text(
                    '${service.pending.length + service.pendingStats.length} ${context.l10n.pendingChanges}',
                  ),
                  onPressed: busy ? null : () => _openGame(service.game!),
                  trailing: const ui.GlyphIcon(
                    ui.AppGlyphs.chevronForward,
                    size: 18,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: games.isEmpty
                ? ui.NullStatus(
                    label: allGames.isEmpty
                        ? context.l10n.yourLibraryHasNoGamesYet
                        : context.l10n.noMatchingGames,
                    illustration: allGames.isEmpty
                        ? ui.NullStatusIllustration.achievement
                        : ui.NullStatusIllustration.search,
                  )
                : _gameGrid
                ? fadeList(
                    GridView.builder(
                      padding: EdgeInsets.fromLTRB(0, contentTopPadding, 0, 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            childAspectRatio: 1.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        return ui.CommonCard(
                          key: ValueKey('achievement-game-${game.appId}'),
                          onPressed: busy ? null : () => _openGame(game),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _cover(game)),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  2,
                                ),
                                child: Text(
                                  game.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  10,
                                ),
                                child: Text(
                                  'AppID ${game.appId}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : fadeList(
                    ListView.separated(
                      padding: EdgeInsets.fromLTRB(0, contentTopPadding, 0, 24),
                      itemCount: games.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final game = games[index];
                        return ui.CommonCard(
                          key: ValueKey('achievement-game-${game.appId}'),
                          onPressed: busy ? null : () => _openGame(game),
                          child: ui.ListItem(
                            leading: _cover(game, width: 88, height: 42),
                            title: Text(game.name),
                            subtitle: Text('AppID ${game.appId}'),
                            trailing: const ui.GlyphIcon(
                              ui.AppGlyphs.chevronForward,
                              size: 18,
                            ),
                            onTap: busy ? null : () => _openGame(game),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final localeText = context.l10n;
    final service = widget.service;
    final count = service.pending.length + service.pendingStats.length;
    final confirmed = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: localeText.saveChanges((count).toString()),
        actions: [
          ui.CommonDialogAction(
            label: localeText.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ui.CommonDialogAction(
            label: localeText.saveToSteam,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.game!.name,
                  style: ui.AppTextStyle.headline.of(context),
                ),
                const SizedBox(height: 16),
                ui.generateGroup([
                  for (final item in service.data!.achievements)
                    if (service.pending.containsKey(item.id))
                      ui.DecorationListItem(
                        leading: ui.GlyphIcon(
                          service.pending[item.id]!
                              ? ui.AppGlyphs.lockOpen
                              : ui.AppGlyphs.lock,
                        ),
                        title: Text(item.name),
                        subtitle: Text(item.id),
                        trailing: Text(
                          service.pending[item.id]!
                              ? localeText.unlock
                              : localeText.lock,
                        ),
                      ),
                  for (final stat in service.data!.stats)
                    if (service.pendingStats.containsKey(stat.id))
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.status),
                        title: Text(stat.name),
                        subtitle: Text(stat.id),
                        trailing: Text(
                          '${stat.value} → ${service.pendingStats[stat.id]}',
                        ),
                      ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await _run(service.save);
    if (mounted && saved) {
      ui.showAppSuccess(
        context,
        localeText.savedAndConfirmedByReadingBackFromSteam,
      );
    }
  }

  Widget _achievementIcon(Achievement item, bool current) {
    final preferred = current ? item.iconUrl : item.lockedIconUrl;
    final alternate = current ? item.lockedIconUrl : item.iconUrl;
    final url = preferred?.isNotEmpty == true ? preferred : alternate;
    return ui.AppImage(
      url: url ?? '',
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(6),
      placeholderGlyph: current ? ui.AppGlyphs.star : ui.AppGlyphs.lock,
    );
  }

  Future<void> _editStat(GameStat stat) async {
    final value = await ui.showFormSheet<num>(
      context: context,
      builder: (context) => _StatEditDialog(
        stat: stat,
        initialValue: widget.service.pendingStats[stat.id] ?? stat.value,
      ),
    );
    if (value != null) {
      try {
        widget.service.setStat(stat.id, value);
      } catch (error) {
        if (mounted) {
          ui.showAppError(context, error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.service,
    builder: (context, _) {
      final service = widget.service;
      final busy = service.isLoading || service.isSaving;
      final snapshot = service.data;
      final allGames = <int, GameEntry>{
        for (final game in widget.games) game.appId: game,
        if (service.game != null) service.game!.appId: service.game!,
      };
      final sortedGames = allGames.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (!_editorOpen) {
        return ui.CommonScaffold(
          title: context.l10n.achievements,
          searchState: _searchState,
          searchHint: context.l10n.searchGamesOrAppid,
          actions: [
            ui.CommonPopupBox(
              key: const ValueKey('achievement-filter'),
              targetBuilder: (open) => ui.DashboardIconButton(
                glyph: ui.AppGlyphs.sort,
                tooltip: context.l10n.sort,
                onPressed: open,
              ),
              popupBuilder: (_) => ui.CommonPopupMenu(
                items: [
                  for (final option in [
                    ('name', context.l10n.nameAscending),
                    ('name_desc', context.l10n.nameDescending),
                    ('appid', context.l10n.appidAscending),
                    ('appid_desc', context.l10n.appidDescending),
                  ])
                    ui.CommonPopupMenuItem(
                      label: option.$2,
                      checked: _gameSort == option.$1,
                      onPressed: () => setState(() => _gameSort = option.$1),
                    ),
                ],
              ),
            ),
            ui.DashboardIconButton(
              glyph: _gameGrid ? ui.AppGlyphs.appsList : ui.AppGlyphs.dashboard,
              tooltip: _gameGrid
                  ? context.l10n.listView
                  : context.l10n.gridView,
              onPressed: () => setState(() => _gameGrid = !_gameGrid),
            ),
          ],
          body: _gameBrowser(context, sortedGames),
        );
      }
      final game = service.game ?? widget.selectedGame;
      final unlocked =
          snapshot?.achievements
              .where((item) => service.pending[item.id] ?? item.achieved)
              .length ??
          0;
      final total = snapshot?.achievements.length ?? 0;
      final stats =
          snapshot?.stats
              .where(
                (stat) => '${stat.name} ${stat.id}'.toLowerCase().contains(
                  _statSearch.trim().toLowerCase(),
                ),
              )
              .toList() ??
          <GameStat>[];
      final achievements =
          snapshot?.achievements.where((achievement) {
            final current =
                service.pending[achievement.id] ?? achievement.achieved;
            if (_filter == 'unlocked' && !current) return false;
            if (_filter == 'locked' && current) return false;
            if (_filter == 'pending' &&
                !service.pending.containsKey(achievement.id)) {
              return false;
            }
            final query = _search.toLowerCase();
            return '${achievement.name} ${achievement.id} ${achievement.description}'
                .toLowerCase()
                .contains(query);
          }).toList() ??
          [];
      final canBatch =
          !busy &&
          snapshot != null &&
          snapshot.achievements.any((item) => (item.permission & 3) == 0);
      return ui.CommonScaffold(
        title: context.l10n.achievements,
        backAction: service.isSaving
            ? null
            : () => setState(() => _editorOpen = false),
        searchState: _searchState,
        searchHint: _segment == 0
            ? context.l10n.searchAchievements
            : context.l10n.searchStatisticNameOrId,
        actions: [
          if (_segment == 0)
            ui.CommonPopupBox(
              targetBuilder: (open) => ui.DashboardIconButton(
                glyph: ui.AppGlyphs.filter,
                tooltip: context.l10n.filter,
                onPressed: open,
              ),
              popupBuilder: (_) => ui.CommonPopupMenu(
                items: [
                  for (final filter in [
                    ('all', context.l10n.all),
                    ('unlocked', context.l10n.unlocked2),
                    ('locked', context.l10n.locked),
                    ('pending', context.l10n.pending),
                  ])
                    ui.CommonPopupMenuItem(
                      label: filter.$2,
                      checked: _filter == filter.$1,
                      onPressed: () => setState(() => _filter = filter.$1),
                    ),
                ],
              ),
            ),
          ui.DashboardIconButton(
            key: const ValueKey('achievement-reload'),
            glyph: ui.AppGlyphs.refresh,
            tooltip: context.l10n.reload,
            onPressed: busy || game == null ? null : () => _load(game),
          ),
          if (_segment == 0 && snapshot != null) ...[
            ui.DashboardIconButton(
              key: const ValueKey('achievement-unlock-all'),
              glyph: ui.AppGlyphs.lockOpen,
              tooltip: context.l10n.unlockAll,
              onPressed: canBatch ? () => _batch('unlock') : null,
            ),
            ui.DashboardIconButton(
              key: const ValueKey('achievement-lock-all'),
              glyph: ui.AppGlyphs.lock,
              tooltip: context.l10n.lockAll,
              onPressed: canBatch ? () => _batch('lock') : null,
            ),
            ui.DashboardIconButton(
              key: const ValueKey('achievement-invert'),
              glyph: ui.AppGlyphs.sync,
              tooltip: context.l10n.invert,
              onPressed: canBatch ? () => _batch('invert') : null,
            ),
          ],
          if (service.hasChanges)
            ui.CommonPopupBox(
              key: const ValueKey('achievement-more'),
              targetBuilder: (open) => ui.DashboardIconButton(
                glyph: ui.AppGlyphs.more,
                tooltip: context.l10n.more,
                onPressed: busy ? null : open,
              ),
              popupBuilder: (_) => ui.CommonPopupMenu(
                items: [
                  ui.CommonPopupMenuItem(
                    glyph: ui.AppGlyphs.delete,
                    label: context.l10n.discard,
                    danger: true,
                    onPressed: busy ? null : service.discardChanges,
                  ),
                ],
              ),
            ),
        ],
        trailingAction: ui.DashboardIconButton(
          key: const ValueKey('achievement-save'),
          glyph: ui.AppGlyphs.check,
          tooltip: context.l10n.saveChanges2,
          onPressed: busy || !service.hasChanges ? null : _save,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                ui.pageContentTopInset,
                16,
                12,
              ),
              child: ui.CommonCard(
                radius: 24,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      if (game != null) ...[
                        _cover(game, width: 120, height: 68),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game?.name ?? context.l10n.achievements,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'AppID ${game?.appId ?? ''}${snapshot == null ? '' : ' · $unlocked / $total ${context.l10n.unlocked}'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (snapshot != null) ...[
                              const SizedBox(height: 8),
                              ui.CommonProgressBar(
                                value: total == 0 ? 0 : unlocked / total,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (busy) const ui.CommonProgressBar(value: null, height: 2),
            if (service.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ui.CommonNotice(message: '${service.error}'),
              ),
            if (snapshot == null && busy)
              const Expanded(child: _AchievementLoadingSkeleton())
            else if (snapshot == null && !busy)
              Expanded(
                child: ui.NullStatus(
                  label: context.l10n.couldNotLoadAchievements,
                  description: context.l10n.startSteamSignInThenSelectReload,
                  illustration: ui.NullStatusIllustration.achievement,
                ),
              )
            else if (snapshot != null)
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ui.SegmentedControl<int>(
                        segments: [
                          (
                            0,
                            '${context.l10n.achievements} (${snapshot.achievements.length})',
                          ),
                          (
                            1,
                            '${context.l10n.statistics} (${snapshot.stats.length})',
                          ),
                        ],
                        value: _segment,
                        onChanged: (value) => setState(() => _segment = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ui.FadeEdge(
                        key: const ValueKey('achievement-list-fade'),
                        extent: 24,
                        child: IndexedStack(
                          index: _segment,
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: achievements.isEmpty
                                      ? ui.NullStatus(
                                          label: context
                                              .l10n
                                              .noMatchingAchievements,
                                          illustration:
                                              ui.NullStatusIllustration.search,
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            24,
                                          ),
                                          itemCount: achievements.length,
                                          itemBuilder: (context, index) {
                                            final item = achievements[index];
                                            final staged = service.pending
                                                .containsKey(item.id);
                                            final current =
                                                service.pending[item.id] ??
                                                item.achieved;
                                            final protected =
                                                (item.permission & 3) != 0;
                                            return ui.ItemPositionProvider(
                                              position: ui.ItemPosition.get(
                                                index,
                                                achievements.length,
                                              ),
                                              child: ui.DecorationListItem(
                                                key: ValueKey(
                                                  'achievement-toggle-${item.id}',
                                                ),
                                                leading: _achievementIcon(
                                                  item,
                                                  current,
                                                ),
                                                isSelected: staged,
                                                title: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(item.name),
                                                    ),
                                                    if (staged) ...[
                                                      const SizedBox(width: 8),
                                                      ui.TonalChip(
                                                        label: context
                                                            .l10n
                                                            .pending,
                                                        color: context
                                                            .colorScheme
                                                            .tertiaryContainer,
                                                        foregroundColor: context
                                                            .colorScheme
                                                            .onTertiaryContainer,
                                                      ),
                                                    ],
                                                    if (protected)
                                                      ui.CommonTooltip(
                                                        message: context
                                                            .l10n
                                                            .thisAchievementIsManagedByTheGameServer,
                                                        child:
                                                            const ui.GlyphIcon(
                                                              ui
                                                                  .AppGlyphs
                                                                  .verified,
                                                              size: 16,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                                subtitle: Text(
                                                  [
                                                        item.description,
                                                        item.id,
                                                        if (item.hidden)
                                                          context
                                                              .l10n
                                                              .hiddenAchievement,
                                                        if (item.unlockedAt !=
                                                            null)
                                                          item.unlockedAt!
                                                              .toLocal()
                                                              .toString()
                                                              .split('.')
                                                              .first,
                                                      ]
                                                      .where(
                                                        (s) => s.isNotEmpty,
                                                      )
                                                      .join(' · '),
                                                ),
                                                onPressed: busy || protected
                                                    ? null
                                                    : () => service
                                                          .setAchievement(
                                                            item.id,
                                                            !current,
                                                          ),
                                                trailing: ui.CommonSwitch(
                                                  value: current,
                                                  onChanged: busy || protected
                                                      ? null
                                                      : (value) => service
                                                            .setAchievement(
                                                              item.id,
                                                              value,
                                                            ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Expanded(
                                  child: stats.isEmpty
                                      ? ui.NullStatus(
                                          label: snapshot.stats.isEmpty
                                              ? context
                                                    .l10n
                                                    .noReadableLocalStatisticsForThisGame
                                              : context
                                                    .l10n
                                                    .noMatchingStatistics,
                                          illustration:
                                              ui.NullStatusIllustration.data,
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: stats.length,
                                          itemBuilder: (context, index) {
                                            final stat = stats[index];
                                            final staged = service.pendingStats
                                                .containsKey(stat.id);
                                            return ui.ItemPositionProvider(
                                              position: ui.ItemPosition.get(
                                                index,
                                                stats.length,
                                              ),
                                              child: ui.DecorationListItem(
                                                isSelected: staged,
                                                leading: const ui.GlyphIcon(
                                                  ui.AppGlyphs.status,
                                                ),
                                                title: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(stat.name),
                                                    ),
                                                    if (staged) ...[
                                                      const SizedBox(width: 8),
                                                      ui.TonalChip(
                                                        label: context
                                                            .l10n
                                                            .pending,
                                                        color: context
                                                            .colorScheme
                                                            .tertiaryContainer,
                                                        foregroundColor: context
                                                            .colorScheme
                                                            .onTertiaryContainer,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                subtitle: Text(stat.id),
                                                onPressed: busy
                                                    ? null
                                                    : () => _editStat(stat),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${service.pendingStats[stat.id] ?? stat.value}',
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ui.CommonTooltip(
                                                      message: context
                                                          .l10n
                                                          .editStatistic,
                                                      child: const ui.GlyphIcon(
                                                        ui.AppGlyphs.edit,
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _AchievementLoadingSkeleton extends StatelessWidget {
  const _AchievementLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motionDuration(const Duration(milliseconds: 280)),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        itemCount: 5,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ui.SkeletonPill(width: 48, height: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ui.SkeletonPill(width: 220, height: 16),
                    const SizedBox(height: 8),
                    const ui.SkeletonPill(width: 320, height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const ui.SkeletonPill(width: 52, height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatEditDialog extends StatefulWidget {
  const _StatEditDialog({required this.stat, required this.initialValue});

  final GameStat stat;
  final num initialValue;

  @override
  State<_StatEditDialog> createState() => _StatEditDialogState();
}

class _StatEditDialogState extends State<_StatEditDialog> {
  late final TextEditingController _controller;
  String? _validation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = num.tryParse(_controller.text.trim());
    final stat = widget.stat;
    if (parsed == null ||
        !parsed.isFinite ||
        (stat.type == StatType.integer && parsed != parsed.round()) ||
        (stat.minimum != null && parsed < stat.minimum!) ||
        (stat.maximum != null && parsed > stat.maximum!)) {
      setState(() => _validation = context.l10n.enterAValidValueInRange);
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final localeText = context.l10n;
    final stat = widget.stat;
    return ui.FormPage(
      title: stat.name,
      onSave: _submit,
      saveLabel: localeText.stageChange,
      error: _validation,
      children: [
        ui.generateSection(
          title: localeText.editStatistic,
          items: [
            ui.FormRow(
              title: stat.type == StatType.integer
                  ? localeText.integerValue
                  : localeText.value,
              trailing: ui.FormRowTextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  signed: true,
                  decimal: stat.type == StatType.floating,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        ui.ListFooter(text: '${stat.minimum ?? '−∞'} … ${stat.maximum ?? '∞'}'),
      ],
    );
  }
}
