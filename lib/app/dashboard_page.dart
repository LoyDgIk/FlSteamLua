import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

import '../core/game_entry.dart';
import '../core/task_center.dart';
import '../features/content_sources/content_models.dart';
import '../features/kernel/kernel_models.dart';
import '../features/network/network_cover_image.dart';
import '../ui/context.dart';
import '../ui/localization.dart';
import '../ui/ui.dart' as ui;
import 'app_services.dart';
import 'support_sheet.dart';
import 'task_panel.dart';
import 'widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.services,
    required this.onNavigate,
    required this.detailBuilder,
    required this.onSettings,
    this.onOpenFeature,
    this.onLibraryTab,
    this.onShowTasks,
  });

  final AppServices services;
  final void Function(int) onNavigate;
  final Widget Function(GameEntry) detailBuilder;
  final VoidCallback onSettings;
  final void Function(String)? onOpenFeature;
  final void Function(int)? onLibraryTab;
  final VoidCallback? onShowTasks;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppServices get services => widget.services;
  bool _kernelLoaded = false;
  String? _kernelError;
  var _editingPanels = false;
  final _hiddenPanels = <String>{};

  @override
  void initState() {
    super.initState();
    _readKernel();
  }

  Future<void> _readKernel() async {
    try {
      await services.kernel.loadLocal();
      if (mounted) setState(() => _kernelLoaded = true);
      if (services.kernel.installed.installed &&
          services.settings.autoCheckKernelUpdate) {
        try {
          await services.kernel.checkForUpdate();
          if (mounted) setState(() {});
        } catch (_) {}
      }
    } catch (error) {
      if (mounted) setState(() => _kernelError = '$error');
    }
  }

  void _library(int tab) {
    if (widget.onLibraryTab case final open?) {
      open(tab);
    } else {
      widget.onNavigate(1);
    }
  }

  void _feature(String name) {
    if (widget.onOpenFeature case final open?) {
      open(name);
    } else {
      widget.onSettings();
    }
  }

  void _tasks() {
    if (widget.onShowTasks case final open?) {
      open();
    } else {
      ui.showModalSideSheet<void>(
        context: context,
        builder: (_) => TaskPanel(tasks: services.tasks),
      );
    }
  }

  void _togglePanelEditing() {
    setState(() => _editingPanels = !_editingPanels);
  }

  void _setPanelVisible(String id, bool visible) {
    setState(() {
      if (visible) {
        _hiddenPanels.remove(id);
      } else {
        _hiddenPanels.add(id);
      }
    });
  }

  Future<void> _refreshLibrary() => showAction(
    context,
    () => services.tasks.run(
      context.l10n.refreshLibrary,
      (task) => services.library.scan(context: task),
    ),
  );

  Future<void> _gameAction(GameEntry game) => showAction(
    context,
    () => services.tasks.run(
      game.isRunning ? context.l10n.stopGame2 : context.l10n.launchGame,
      (_) => game.isRunning
          ? services.library.stop(game.appId)
          : services.library.launch(game.appId),
      appId: game.appId,
    ),
  );

  Future<void> _updateSources() => showAction(
    context,
    () =>
        services.tasks.run(context.l10n.updateSubscriptionCaches, (task) async {
          final sources = services.contentSources.sources.where(
            (source) =>
                source.enabled &&
                source.configurationComplete &&
                source.kind == ContentSourceKind.subscription,
          );
          for (final source in sources) {
            task.checkCancelled();
            await services.contentSources.update(source.id, task: task);
          }
        }),
  );

  Future<void> _toggleKernel(bool enabled) => showAction(
    context,
    () => services.tasks.run(
      enabled ? context.l10n.enableKernel : context.l10n.disableKernel,
      (_) => services.kernel.setEnabled(enabled),
    ),
  );

  Future<void> _toggleMonitor(bool enabled) async {
    if (enabled && services.settings.steamPath.isEmpty) {
      widget.onSettings();
      return;
    }
    await showAction(context, () async {
      if (enabled) {
        await services.tools.monitor.start(services.settings.steamPath);
      } else {
        services.tools.monitor.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      services.library,
      services.kernel,
      services.contentSources,
      services.tasks,
      services.cloud,
      services.settings,
    ]),
    builder: (context, _) {
      final games = services.library.games;
      final lua = games.where((game) => game.hasLua).toList();
      final installed = games.where((game) => game.isInstalled).toList();
      final enabledLua = lua.where((game) => game.luaEnabled).length;
      final running = games.where((game) => game.isRunning).toList();
      final recent = installed.where((game) => game.lastPlayed != null).toList()
        ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
      final playable = [...running, ...recent.where((game) => !game.isRunning)];
      final sources = services.contentSources.sources;
      return ui.CommonScaffold(
        title: context.l10n.dashboard,
        actions: [
          const SupportAuthorButton(),
          ui.DashboardIconButton(
            glyph: ui.AppGlyphs.refresh,
            tooltip: context.l10n.refreshLibrary,
            onPressed: services.library.isScanning ? null : _refreshLibrary,
          ),
          ui.DashboardIconButton(
            glyph: _editingPanels ? ui.AppGlyphs.check : ui.AppGlyphs.settings,
            tooltip: _editingPanels ? context.l10n.done : context.l10n.settings,
            onPressed: _togglePanelEditing,
            selected: _editingPanels,
          ),
        ],
        body: LayoutBuilder(
          builder: (context, constraints) => _DashboardContent(
            context: context,
            services: services,
            connected: services.library.steamPath != null,
            currentGame: running.firstOrNull ?? playable.firstOrNull,
            lua: lua,
            installed: installed,
            enabledLua: enabledLua,
            running: running,
            playable: playable,
            sources: sources,
            enabledSources: sources.where((source) => source.enabled).length,
            subscriptions: sources.where(
              (source) =>
                  source.kind == ContentSourceKind.subscription &&
                  source.enabled &&
                  source.configurationComplete,
            ),
            activeTasks: services.tasks.tasks
                .where((task) => task.status == TaskStatus.running)
                .toList(),
            kernelLoaded: _kernelLoaded,
            kernelError: _kernelError,
            editingPanels: _editingPanels,
            hiddenPanels: _hiddenPanels,
            onLibrary: _library,
            onFeature: _feature,
            onSettings: widget.onSettings,
            onSetPanelVisible: _setPanelVisible,
            onTasks: _tasks,
            onGameAction: _gameAction,
            onUpdateSources: _updateSources,
            onToggleKernel: _toggleKernel,
            onToggleMonitor: _toggleMonitor,
          ).build(constraints.maxWidth),
        ),
      );
    },
  );
}

class _PanelVisibilityButton extends StatelessWidget {
  const _PanelVisibilityButton({
    super.key,
    required this.hidden,
    required this.tooltip,
    required this.onPressed,
  });

  final bool hidden;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final duration = context.motionDuration(const Duration(milliseconds: 220));
    return Tooltip(
      message: tooltip,
      child: ui.ElasticPress(
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: 40,
          height: 40,
          decoration: ShapeDecoration(
            color: hidden
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            shape: ui.AppShape.circle,
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: ui.GlyphIcon(
                    hidden ? ui.AppGlyphs.eye : ui.AppGlyphs.eyeOff,
                    key: ValueKey(hidden),
                    size: 18,
                    color: hidden
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardPanel {
  const _DashboardPanel({
    required this.id,
    required this.span,
    required this.height,
    required this.child,
  });

  final String id;
  final int span;
  final double height;
  final Widget child;
}

class _PanelPlacement {
  const _PanelPlacement({required this.panel, required this.span});

  final _DashboardPanel panel;
  final int span;

  _PanelPlacement widen() => _PanelPlacement(panel: panel, span: span + 1);
}

class _DashboardContent {
  const _DashboardContent({
    required this.context,
    required this.services,
    required this.connected,
    required this.currentGame,
    required this.lua,
    required this.installed,
    required this.enabledLua,
    required this.running,
    required this.playable,
    required this.sources,
    required this.enabledSources,
    required this.subscriptions,
    required this.activeTasks,
    required this.kernelLoaded,
    required this.kernelError,
    required this.editingPanels,
    required this.hiddenPanels,
    required this.onLibrary,
    required this.onFeature,
    required this.onSettings,
    required this.onSetPanelVisible,
    required this.onTasks,
    required this.onGameAction,
    required this.onUpdateSources,
    required this.onToggleKernel,
    required this.onToggleMonitor,
  });

  final BuildContext context;
  final AppServices services;
  final bool connected;
  final GameEntry? currentGame;
  final List<GameEntry> lua;
  final List<GameEntry> installed;
  final int enabledLua;
  final List<GameEntry> running;
  final List<GameEntry> playable;
  final List<ContentSourceDefinition> sources;
  final int enabledSources;
  final Iterable<ContentSourceDefinition> subscriptions;
  final List<TaskProgress> activeTasks;
  final bool kernelLoaded;
  final String? kernelError;
  final bool editingPanels;
  final Set<String> hiddenPanels;
  final void Function(int) onLibrary;
  final void Function(String) onFeature;
  final VoidCallback onSettings;
  final void Function(String, bool) onSetPanelVisible;
  final VoidCallback onTasks;
  final Future<void> Function(GameEntry) onGameAction;
  final Future<void> Function() onUpdateSources;
  final Future<void> Function(bool) onToggleKernel;
  final Future<void> Function(bool) onToggleMonitor;

  Widget build(double width) {
    final compact = width >= 600;
    final start = compact ? 16.0 : 12.0;
    final end = compact ? 24.0 : 12.0;
    final available = math.max(0.0, width - start - end);
    final columns = available >= 1040
        ? 4
        : available >= 620
        ? 2
        : 1;
    final panels = _panels().where((panel) => visible(panel.id)).toList();
    final ids = panels.map((panel) => panel.id).join('-');
    final duration = context.motionDuration(const Duration(milliseconds: 320));
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(
        start,
        ui.pageContentTopInset,
        end,
        24,
      ),
      child: AnimatedSize(
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -.012),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween(begin: .988, end: 1.0).animate(curved),
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            );
          },
          child: _grid(
            key: ValueKey('dashboard-grid-$columns-$ids'),
            columns: columns,
            panels: panels,
          ),
        ),
      ),
    );
  }

  bool visible(String id) => !hiddenPanels.contains(id) || editingPanels;

  List<_DashboardPanel> _panels() => [
    _DashboardPanel(id: 'status', span: 2, height: 208, child: _statusCard()),
    _DashboardPanel(
      id: 'lua',
      span: 1,
      height: 164,
      child: _libraryCard(luaCard: true),
    ),
    _DashboardPanel(
      id: 'steam',
      span: 1,
      height: 164,
      child: _libraryCard(luaCard: false),
    ),
    _DashboardPanel(id: 'sources', span: 2, height: 176, child: _sourceCard()),
    _DashboardPanel(id: 'kernel', span: 1, height: 176, child: _kernelTile()),
    _DashboardPanel(id: 'monitor', span: 1, height: 176, child: _monitorTile()),
    _DashboardPanel(id: 'tools', span: 1, height: 176, child: _toolsCard()),
    _DashboardPanel(id: 'tasks', span: 1, height: 176, child: _tasksCard()),
    _DashboardPanel(id: 'cloud', span: 2, height: 176, child: _cloudCard()),
    _DashboardPanel(id: 'recent', span: 2, height: 160, child: _recentCard()),
    _DashboardPanel(id: 'system', span: 2, height: 160, child: _systemCard()),
  ];

  Widget _grid({
    required Key key,
    required int columns,
    required List<_DashboardPanel> panels,
  }) {
    final gap = columns == 1 ? 12.0 : 16.0;
    final rows = _pack(panels, columns);
    return Column(
      key: key,
      spacing: gap,
      children: [
        for (final row in rows)
          SizedBox(
            height: row
                .map((placement) => placement.panel.height)
                .reduce(math.max),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                for (final placement in row)
                  Expanded(
                    flex: placement.span,
                    child: panel(placement.panel.id, placement.panel.child),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<List<_PanelPlacement>> _pack(List<_DashboardPanel> panels, int columns) {
    final rows = <List<_PanelPlacement>>[];
    var index = 0;
    while (index < panels.length) {
      final row = <_PanelPlacement>[];
      var used = 0;
      while (index < panels.length) {
        final panel = panels[index];
        final span = math.min(panel.span, columns);
        if (row.isNotEmpty && used + span > columns) break;
        row.add(_PanelPlacement(panel: panel, span: span));
        used += span;
        index++;
      }
      var extra = columns - used;
      var cursor = row.length - 1;
      while (extra > 0) {
        if (cursor < 0) cursor = row.length - 1;
        row[cursor] = row[cursor].widen();
        cursor--;
        extra--;
      }
      rows.add(row);
    }
    return rows;
  }

  Widget panel(String id, Widget child) {
    final hidden = hiddenPanels.contains(id);
    final duration = context.motionDuration(const Duration(milliseconds: 220));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          ignoring: editingPanels,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOutCubic,
            opacity: editingPanels && hidden ? .48 : 1,
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeOutCubic,
              scale: editingPanels && hidden ? .985 : 1,
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IgnorePointer(
            ignoring: !editingPanels,
            child: ExcludeSemantics(
              excluding: !editingPanels,
              child: AnimatedOpacity(
                duration: duration,
                curve: Curves.easeOutCubic,
                opacity: editingPanels ? 1 : 0,
                child: AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOutBack,
                  alignment: Alignment.topRight,
                  scale: editingPanels ? 1 : .72,
                  child: AnimatedSlide(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    offset: editingPanels ? Offset.zero : const Offset(0, -.08),
                    child: _PanelVisibilityButton(
                      key: ValueKey('dashboard-panel-toggle-$id'),
                      hidden: hidden,
                      tooltip: hidden
                          ? context.l10n.showPanel
                          : context.l10n.hidePanel,
                      onPressed: () => onSetPanelVisible(id, hidden),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCard() {
    final game = currentGame;
    final colorScheme = Theme.of(context).colorScheme;
    final colors = ui.DashboardColors.of(context);
    final action = !connected
        ? onSettings
        : game == null
        ? () => onLibrary(1)
        : () => onGameAction(game);
    final actionLabel = !connected
        ? context.l10n.chooseSteamFolder
        : game == null
        ? context.l10n.openLibrary
        : game.isRunning
        ? context.l10n.stopGame2
        : context.l10n.launchGame;
    return ui.DashboardCard(
      semanticLabel: context.l10n.status,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            end: -62,
            top: -96,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: game?.isRunning == true ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (_, progress, _) => Transform.rotate(
                angle: 0.18 + progress * 0.12,
                child: Transform.scale(
                  scale: 1 + progress * 0.035,
                  child: ui.ShapeBadge(
                    shape: MaterialShapes.cookie12Sided,
                    color: Color.alphaBlend(
                      colorScheme.primary.withValues(
                        alpha: 0.055 + progress * 0.045,
                      ),
                      colors.tone,
                    ),
                    size: 300,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ui.DashboardCardHeader(
                        glyph: ui.AppGlyphs.status,
                        title: context.l10n.steamGames,
                        leading: [
                          ui.DashboardChip(
                            label: connected
                                ? context.l10n.connectedToSteam
                                : context.l10n.steamIsNotConnected,
                            tone: connected
                                ? ui.DashboardChipTone.ok
                                : ui.DashboardChipTone.warn,
                            dot: connected,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        game?.name ??
                            (connected
                                ? context.l10n.steamLibrary
                                : context.l10n.connectYourSteamLibrary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ui.AppTextStyle.title1.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game == null
                            ? (connected
                                  ? context
                                        .l10n
                                        .installedGamesAreReadFromSteamAppmanifestFilesLuaConfigurationsAreInTheFirstTab
                                  : context
                                        .l10n
                                        .chooseYourSteamInstallationToReadLuaConfigurationsAndInstalledGames)
                            : game.isRunning
                            ? context.l10n.running
                            : context.l10n.recentlyPlayed,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ui.AppTextStyle.subheadline
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (game != null) ...[
                            ui.DashboardChip(label: 'AppID ${game.appId}'),
                            ui.DashboardChip(
                              label: game.isInstalled
                                  ? context.l10n.installed
                                  : context.l10n.notInstalled,
                              tone: game.isInstalled
                                  ? ui.DashboardChipTone.ok
                                  : ui.DashboardChipTone.idle,
                            ),
                          ] else
                            ui.DashboardChip(
                              label: connected
                                  ? context.l10n.steamLibrary
                                  : context.l10n.chooseASteamFolderFirst,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 108,
                  child: Center(
                    child: Tooltip(
                      message: actionLabel,
                      child: Material(
                        color: game?.isRunning == true
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: game == null
                              ? null
                              : ValueKey('dashboard-game-${game.appId}'),
                          customBorder: const CircleBorder(),
                          onTap: action,
                          child: SizedBox.square(
                            dimension: 88,
                            child: Icon(
                              !connected
                                  ? Icons.folder_open_outlined
                                  : game == null
                                  ? Icons.grid_view_rounded
                                  : game.isRunning
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 34,
                              color: game?.isRunning == true
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _libraryCard({required bool luaCard}) {
    final count = luaCard ? lua.length : installed.length;
    final detail = luaCard
        ? context.l10n.enabled3('$enabledLua')
        : context.l10n.running2('${running.length}');
    final ratio = luaCard
        ? (lua.isEmpty ? 0.0 : enabledLua / lua.length)
        : (installed.isEmpty ? 0.0 : running.length / installed.length);
    return ui.DashboardCard(
      key: ValueKey(
        luaCard ? 'dashboard-lua-library' : 'dashboard-steam-library',
      ),
      onTap: () => onLibrary(luaCard ? 0 : 1),
      semanticLabel: luaCard
          ? context.l10n.luaLibrary
          : context.l10n.steamLibrary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ui.DashboardCardHeader(
            glyph: luaCard ? ui.AppGlyphs.code : ui.AppGlyphs.profiles,
            title: luaCard
                ? context.l10n.luaLibrary
                : context.l10n.steamLibrary,
            chevron: true,
          ),
          const Spacer(),
          Text(
            ui.dashboardCount(count),
            style: ui.DashboardText.figure(context, ui.AppTextStyle.display),
          ),
          const SizedBox(height: 4),
          Text(detail, style: ui.DashboardText.label(context)),
          const SizedBox(height: 16),
          ui.CommonProgressBar(value: ratio, height: 5),
        ],
      ),
    );
  }

  Widget _kernelTile() {
    final kernel = services.kernel.installed;
    final value = kernel.installed && kernel.enabled;
    return ui.DashboardCard(
      onTap: () => onFeature('kernel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ui.DashboardCardHeader(
            glyph: ui.AppGlyphs.wrench,
            title: context.l10n.kernel,
            chevron: true,
          ),
          const Spacer(),
          Text(
            kernel.installed
                ? kernel.version ?? context.l10n.unknownVersion
                : context.l10n.notInstalled,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ui.DashboardText.figure(context, ui.AppTextStyle.title2),
          ),
          const SizedBox(height: 4),
          Text(
            kernelError != null
                ? context.l10n.couldNotReadKernel
                : !kernelLoaded
                ? context.l10n.detectingKernel
                : services.kernel.updateInfo?.hasUpdate == true
                ? context.l10n.kernelUpdateAvailable(
                    services.kernel.updateInfo!.package.version,
                  )
                : kernel.disabled
                ? context.l10n.disabled
                : kernel.installed &&
                      kernel.entryState == InjectionEntryState.none
                ? context.l10n.kernelStateMissingEntry
                : kernel.entryState == InjectionEntryState.bothActive
                ? context.l10n.kernelStateConflict
                : value
                ? context.l10n.configurationEnabled
                : context.l10n.disabled,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ui.DashboardText.label(context),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.enableKernel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ui.DashboardText.rowTitle(context),
                ),
              ),
              ui.CommonSwitch(
                value: value,
                onChanged: kernel.installed
                    ? onToggleKernel
                    : (_) => onFeature('kernel'),
                semanticLabel: context.l10n.enableKernel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monitorTile() => ListenableBuilder(
    listenable: services.tools.monitor,
    builder: (context, _) {
      final running = services.tools.monitor.isRunning;
      return ui.DashboardCard(
        onTap: () => onFeature('tools'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ui.DashboardCardHeader(
              glyph: ui.AppGlyphs.cloudDownload,
              title: context.l10n.manifestMonitoring,
              chevron: true,
            ),
            const Spacer(),
            Text(
              running ? context.l10n.running : context.l10n.disabled,
              style: ui.DashboardText.figure(context, ui.AppTextStyle.title2),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.fetchMissingManifestsRequestedBySteam,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ui.DashboardText.label(context),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.startMonitoring,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui.DashboardText.rowTitle(context),
                  ),
                ),
                ui.CommonSwitch(
                  value: running,
                  onChanged: onToggleMonitor,
                  semanticLabel: context.l10n.manifestMonitoring,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _sourceCard() {
    final errors = sources.where((source) => source.hasError).length;
    return ui.DashboardCard(
      key: const ValueKey('dashboard-content-sources'),
      onTap: () => onFeature('content_sources'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ui.DashboardCardHeader(
            glyph: ui.AppGlyphs.link,
            title: context.l10n.contentSources,
            chevron: true,
            trailing: [
              if (subscriptions.isNotEmpty)
                Tooltip(
                  message: context.l10n.updateCaches,
                  child: InkWell(
                    onTap: onUpdateSources,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ui.GlyphIcon(
                        ui.AppGlyphs.refresh,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            ui.dashboardCount(sources.length),
            style: ui.DashboardText.figure(context, ui.AppTextStyle.largeTitle),
          ),
          Text(
            context.l10n.enabled4('$enabledSources'),
            style: ui.DashboardText.label(context),
          ),
          const Spacer(),
          ui.DashboardChip(
            label: errors == 0
                ? context.l10n.enabled
                : context.l10n.failedSources,
            tone: errors == 0
                ? ui.DashboardChipTone.ok
                : ui.DashboardChipTone.warn,
          ),
        ],
      ),
    );
  }

  Widget _toolsCard() => ui.DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ui.DashboardCardHeader(
          glyph: ui.AppGlyphs.tools,
          title: context.l10n.gameTools,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _toolTile(
                key: const ValueKey('dashboard-trainers'),
                ui.AppGlyphs.wrench,
                context.l10n.trainers,
                () => onFeature('trainers'),
              ),
              _toolTile(
                key: const ValueKey('dashboard-onlinefix'),
                ui.AppGlyphs.link,
                context.l10n.onlineFixes,
                () => onFeature('onlinefix'),
              ),
              _toolTile(
                key: const ValueKey('dashboard-achievements'),
                ui.AppGlyphs.star,
                context.l10n.achievements,
                () => onFeature('achievements'),
              ),
              _toolTile(
                key: const ValueKey('dashboard-cloud'),
                ui.AppGlyphs.cloudSync,
                context.l10n.cloudSaves,
                () => onFeature('cloud'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _toolTile(
    ui.Glyph glyph,
    String title,
    VoidCallback onTap, {
    Key? key,
  }) => ui.DashboardBlock(
    key: key,
    radius: 16,
    onTap: onTap,
    semanticLabel: title,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        ui.GlyphIcon(glyph, size: 18),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  Widget _tasksCard() {
    final task = activeTasks.firstOrNull;
    return ui.DashboardCard(
      key: const ValueKey('dashboard-tasks'),
      onTap: onTasks,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ui.DashboardCardHeader(
            glyph: ui.AppGlyphs.cloudDownload,
            title: context.l10n.tasks,
            chevron: true,
          ),
          const Spacer(),
          Text(
            ui.dashboardCount(activeTasks.length),
            style: ui.DashboardText.figure(context, ui.AppTextStyle.largeTitle),
          ),
          Text(
            task?.title ??
                (activeTasks.isEmpty
                    ? context.l10n.viewTasks
                    : context.l10n.activeTasks),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ui.DashboardText.label(context),
          ),
          const Spacer(),
          if (task != null) ...[
            ui.CommonProgressBar(
              key: const ValueKey('dashboard-task-progress'),
              value: task.progress,
            ),
            const SizedBox(height: 8),
            if (task.cancellationRequested)
              Text(
                context.l10n.cancelling2,
                style: ui.DashboardText.label(context),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ui.DashboardText.label(context),
                    ),
                  ),
                  InkWell(
                    onTap: () => services.tasks.cancel(task.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        context.l10n.cancelTask,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ] else
            Text(
              context.l10n.viewTasks,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cloudCard() {
    final status = services.cloud.status;
    final active = status.pluginInstalled && status.enabled;
    return ui.DashboardCard(
      onTap: () => onFeature('cloud'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ui.DashboardCardHeader(
            glyph: ui.AppGlyphs.cloudSync,
            title: context.l10n.cloudSaves,
            chevron: true,
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            child: ui.DashboardChip(
              key: ValueKey(active),
              label: active
                  ? context.l10n.configurationEnabled
                  : status.remoteSyncConfigured
                  ? context.l10n.configured
                  : context.l10n.disabled,
              tone: active
                  ? ui.DashboardChipTone.ok
                  : ui.DashboardChipTone.idle,
              dot: active,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            status.remoteSyncConfigured
                ? status.provider
                : context.l10n.cloudSaves,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ui.DashboardText.label(context),
          ),
        ],
      ),
    );
  }

  Widget _recentCard() => ui.DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ui.DashboardCardHeader(
          glyph: ui.AppGlyphs.clock,
          title: context.l10n.recentlyPlayed,
          trailing: [
            InkWell(
              onTap: () => onLibrary(1),
              child: Text(
                context.l10n.allGames,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (playable.isEmpty)
          Expanded(
            child: Center(
              child: TextButton.icon(
                onPressed: () => onLibrary(1),
                icon: const ui.GlyphIcon(ui.AppGlyphs.profiles),
                label: Text(context.l10n.openLibrary),
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                for (final game in playable.take(2))
                  Expanded(child: _recentGame(game)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _recentGame(GameEntry game) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ui.DashboardBlock(
      key: ValueKey('dashboard-recent-game-${game.appId}'),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      onTap: () => onGameAction(game),
      semanticLabel: game.name,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 66,
              height: 28,
              child: NetworkCoverImage(
                settings: services.settings,
                appId: game.appId,
                url: game.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.sports_esports_outlined, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              game.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ui.AppTextStyle.subheadline.of(context, emphasized: true),
            ),
          ),
          Icon(
            game.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 20,
          ),
        ],
      ),
    ),
  );

  Widget _systemCard() => ui.DashboardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ui.DashboardCardHeader(
          glyph: ui.AppGlyphs.settings,
          title: context.l10n.settings,
          chevron: true,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ui.DashboardBlock(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        services.settings.steamPath.isEmpty
                            ? context.l10n.steamIsNotConnected
                            : services.settings.steamPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ui.AppTextStyle.subheadline.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.steamInstallationFolder,
                        style: ui.DashboardText.label(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: onSettings,
                  icon: const ui.GlyphIcon(ui.AppGlyphs.settings, size: 18),
                  label: Text(context.l10n.settings),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
