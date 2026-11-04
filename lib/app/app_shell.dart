import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_entry.dart';
import '../features/achievements/achievements_page.dart';
import '../features/cloud/cloud_page.dart';
import '../features/dlc_analysis/dlc_analysis_page.dart';
import '../features/kernel/kernel_settings_page.dart';
import '../features/lan_transfer/lan_transfer_models.dart';
import '../features/lan_transfer/lan_transfer_page.dart';
import '../features/patching/patching_page.dart';
import '../features/patching/game_patch_download_page.dart';
import '../features/steam_protocol/steam_account_page.dart';
import '../features/steam_protocol/steam_avatar.dart';
import '../features/store/store_page.dart';
import '../features/store/store_service.dart';
import '../features/tools/tools_page.dart';
import '../features/tools/steam_extraction_pages.dart';
import '../features/tools/online/online_pages.dart';
import '../features/content_sources/content_import_dialog.dart';
import '../features/content_sources/content_sources_page.dart';
import '../ui/ui.dart' as ui;
import 'app_services.dart';
import 'dashboard_page.dart';
import 'game_detail_page.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'task_panel.dart';
import 'widgets.dart';
import '../ui/localization.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});
  final AppServices services;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigators = List.generate(8, (_) => GlobalKey<NavigatorState>());
  final _visited = <int>{0};
  int _index = 0;
  int _navigationDirection = 1;
  int _navigationNonce = 0;
  int _libraryTab = 0;
  int _libraryTabRequest = 0;
  late bool _sidebarExpanded;
  late bool _sidebarPersisted;
  final Set<String> _promptedLanOffers = {};
  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    _sidebarExpanded = services.settings.sidebarExpanded;
    _sidebarPersisted = _sidebarExpanded;
    services.settings.addListener(_settingsChanged);
    services.lanTransfer.addListener(_lanTransferChanged);
  }

  void _settingsChanged() {
    final persisted = services.settings.sidebarExpanded;
    if (persisted == _sidebarPersisted) return;
    _sidebarPersisted = persisted;
    if (mounted) setState(() => _sidebarExpanded = persisted);
  }

  void _lanTransferChanged() {
    if (!mounted) return;
    final pending = services.lanTransfer.offers
        .where(
          (offer) =>
              !offer.trusted && !_promptedLanOffers.contains(offer.bundleId),
        )
        .firstOrNull;
    if (pending == null) return;
    _promptedLanOffers.add(pending.bundleId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openIncomingLanTransfer(pending));
    });
  }

  Future<void> _openIncomingLanTransfer(LanTransferOffer offer) async {
    final session = await showLanTransferReceiveSheet(
      context,
      service: services.lanTransfer,
      offer: offer,
    );
    if (session == null || !mounted) return;
    _push(
      LanTransferSessionPage(
        service: services.lanTransfer,
        settings: services.settings,
        session: session,
      ),
    );
  }

  void _toggleSidebar() {
    final next = !_sidebarExpanded;
    setState(() => _sidebarExpanded = next);
    _sidebarPersisted = next;
    unawaited(services.settings.set('sidebarExpanded', next));
  }

  @override
  void dispose() {
    services.settings.removeListener(_settingsChanged);
    services.lanTransfer.removeListener(_lanTransferChanged);
    super.dispose();
  }

  void _select(int index) => setState(() {
    if (_index != index) {
      _navigationDirection = index > _index ? 1 : -1;
      _navigationNonce++;
    }
    _index = index;
    _visited.add(index);
  });

  void _openLibrary(int tab) => setState(() {
    _libraryTab = tab;
    _libraryTabRequest++;
    _index = 1;
    _navigationDirection = 1;
    _navigationNonce++;
    _visited.add(1);
  });

  void _push(Widget page) => _navigators[_index].currentState!.push(
    ui.buildAppPageRoute(
      builder: (_) => page,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    ),
  );

  Widget _secondary(String title, Widget page) => Scaffold(body: page);

  Widget _detail(GameEntry game) => GameDetailPage(
    services: services,
    game: game,
    onDestination: _destination,
  );

  void _destination(String destination, GameEntry game) {
    final target = switch (destination) {
      'achievements' => 3,
      'cloud' => 4,
      _ => -1,
    };
    if (target >= 0) {
      _select(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _navigators[target].currentState?.push(
          ui.buildAppPageRoute(
            builder: (_) => _secondary(
              target == 3 ? context.l10n.achievements : context.l10n.cloudSaves,
              target == 3
                  ? AchievementsPage(
                      service: services.achievements,
                      games: services.library.games,
                      steamPath: services.settings.steamPath,
                      selectedGame: game,
                      language: services.settings.language,
                    )
                  : CloudPage(
                      service: services.cloud,
                      game: game,
                      games: services.library.games,
                      tasks: services.tasks,
                      steamProcess: services.library.processActions,
                    ),
            ),
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          ),
        );
      });
    } else if (destination == 'dlc_analysis') {
      _openDlcAnalysis(game);
    } else if (destination == 'key_cache') {
      _openKeyCache(game);
    } else if (destination == 'patch_settings') {
      _push(
        PatchSettingsPage(
          paths: services.paths,
          settings: services.settings,
          tasks: services.tasks,
          tools: services.tools.service,
          game: game,
        ),
      );
    } else if (destination == 'patch_download') {
      _push(
        GamePatchDownloadPage(
          paths: services.paths,
          tasks: services.tasks,
          game: game,
        ),
      );
    } else if (destination == 'lua_extraction') {
      _push(
        LuaExtractionPage(
          paths: services.paths,
          settings: services.settings,
          tasks: services.tasks,
          steam: services.steam,
          game: game,
        ),
      );
    } else if (destination == 'denuvo_extraction') {
      _push(
        DenuvoExtractionPage(
          paths: services.paths,
          settings: services.settings,
          tasks: services.tasks,
          achievements: services.achievements,
          game: game,
          games: services.library.games,
        ),
      );
    } else if (destination == 'trainers') {
      _openTrainers(game);
    } else if (destination == 'onlinefix') {
      _openOnlineFix(game);
    } else if (destination == 'manifest_sources') {
      _openManifestSources();
    } else {
      _openTools(game);
    }
  }

  void _settings() => _select(6);

  void _showTasks() => ui.showModalSideSheet<void>(
    context: context,
    builder: (_) => TaskPanel(
      tasks: services.tasks,
      onTaskPressed: (task) {
        final sessionId = task.actionId;
        if (sessionId == null) return;
        final session = services.lanTransfer.sessions
            .where((value) => value.id == sessionId)
            .firstOrNull;
        if (session == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _push(
            LanTransferSessionPage(
              service: services.lanTransfer,
              settings: services.settings,
              session: session,
            ),
          );
        });
      },
      onCancelTask: (task) {
        final sessionId = task.actionId;
        if (sessionId != null) {
          unawaited(services.lanTransfer.cancel(sessionId));
        }
      },
    ),
  );

  void _openDlcAnalysis([GameEntry? game]) => _push(
    DlcAnalysisPage(
      paths: services.paths,
      settings: services.settings,
      tasks: services.tasks,
      game: game,
      protocol: services.steam,
      contentSources: services.contentSources,
      onChanged: () => services.library.scan(),
    ),
  );

  void _openKeyCache([GameEntry? game]) {
    if (game == null) {
      _openManifestSources();
    } else {
      _addStoreGame(game);
    }
  }

  void _openManifestSources() => _select(7);

  void _openTrainers([GameEntry? game]) => _push(
    TrainerToolsPage(
      appPaths: services.paths,
      settings: services.settings,
      tasks: services.tasks,
      game: game,
      games: services.library.games,
      service: services.tools.trainers,
    ),
  );

  void _openOnlineFix([GameEntry? game]) => _push(
    OnlineFixToolsPage(
      appPaths: services.paths,
      settings: services.settings,
      tasks: services.tasks,
      game: game,
      service: services.tools.onlineFix,
    ),
  );

  void _openFeature(String feature) {
    switch (feature) {
      case 'content_sources':
      case 'manifests':
      case 'subscriptions':
        _openManifestSources();
      case 'key_cache':
        _openKeyCache();
      case 'trainers':
        _openTrainers();
      case 'onlinefix':
        _openOnlineFix();
      case 'kernel':
        _push(
          KernelSettingsPage(
            service: services.kernel,
            tasks: services.tasks,
            settings: services.settings,
            steamProcess: services.library.processActions,
          ),
        );
      case 'cloud':
        _select(4);
      case 'achievements':
        _select(3);
      case 'settings':
        _settings();
      default:
        _openTools();
    }
  }

  void _openTools([GameEntry? game]) {
    if (game == null) {
      _select(5);
      return;
    }
    _push(
      _secondary(
        context.l10n.tools2,
        ToolsPage(
          appPaths: services.paths,
          settings: services.settings,
          tasks: services.tasks,
          selectedGame: game,
          games: services.library.games,
          controller: services.tools,
          lanTransfer: services.lanTransfer,
          steam: services.steam,
          achievements: services.achievements,
          onGameChanged: () => services.library.scan(),
          destinations: _toolDestinations(game),
        ),
      ),
    );
  }

  List<ToolDestination> _toolDestinations([GameEntry? game]) => [
    ToolDestination(
      glyph: ui.AppGlyphs.dataUsage,
      label: context.l10n.dlcAnalysis,
      description: context.l10n.dlcAnalysisDescription,
      onPressed: () => _openDlcAnalysis(game),
    ),
    if (game != null)
      ToolDestination(
        glyph: ui.AppGlyphs.puzzle,
        label: context.l10n.patchSettings,
        description: context.l10n.patchSettingsDescription,
        onPressed: () => _push(
          PatchSettingsPage(
            paths: services.paths,
            settings: services.settings,
            tasks: services.tasks,
            tools: services.tools.service,
            game: game,
          ),
        ),
      ),
    if (game != null)
      ToolDestination(
        glyph: ui.AppGlyphs.cloudDownload,
        label: context.l10n.gamePatchDownload,
        description: context.l10n.gamePatchDownloadDescription,
        onPressed: () => _push(
          GamePatchDownloadPage(
            paths: services.paths,
            tasks: services.tasks,
            game: game,
          ),
        ),
      ),
  ];

  Future<void> _addStoreGame(GameEntry game) async {
    if (services.settings.steamPath.isEmpty) {
      _settings();
      return;
    }
    StoreGameDetails? details;
    try {
      details = await services.store.details(game.appId);
    } on Object {
      details = null;
    }
    if (!mounted) return;
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
          ContentImportDlcOption(appId: id, name: 'DLC $id'),
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

  Widget _page(int index) => switch (index) {
    0 => DashboardPage(
      services: services,
      onNavigate: _select,
      detailBuilder: _detail,
      onSettings: _settings,
      onOpenFeature: _openFeature,
      onLibraryTab: _openLibrary,
      onShowTasks: _showTasks,
    ),
    1 => LibraryPage(
      services: services,
      detailBuilder: _detail,
      onSettings: _settings,
      onDestination: _destination,
      initialTab: _libraryTab,
      tabRequest: _libraryTabRequest,
    ),
    2 => StorePage(
      service: services.store,
      language: services.settings.language,
      onOpenGame: (game) => _navigators[2].currentState?.push(
        ui.buildAppPageRoute(builder: (_) => _detail(game)),
      ),
      onAddGame: _addStoreGame,
    ),
    3 => AchievementsPage(
      service: services.achievements,
      games: services.library.games,
      steamPath: services.settings.steamPath,
      language: services.settings.language,
    ),
    4 => CloudPage(
      service: services.cloud,
      games: services.library.games,
      tasks: services.tasks,
      steamProcess: services.library.processActions,
    ),
    5 => ToolsPage(
      appPaths: services.paths,
      settings: services.settings,
      tasks: services.tasks,
      games: services.library.games,
      controller: services.tools,
      lanTransfer: services.lanTransfer,
      steam: services.steam,
      achievements: services.achievements,
      onGameChanged: () => services.library.scan(),
      destinations: _toolDestinations(),
    ),
    6 => SettingsPage(services: services, onOpenPage: _push),
    _ => ContentSourcesPage(
      registry: services.contentSources,
      tasks: services.tasks,
      onImportLocal: () => importLibraryFiles(context, services),
    ),
  };

  Widget _taskFooter(double progress) {
    final count = services.tasks.runningCount;
    return _FooterButton(
      icon: Icons.download_outlined,
      glyph: ui.AppGlyphs.cloudDownload,
      label: context.l10n.tasks,
      progress: progress,
      trailing: count == 0
          ? null
          : Badge(
              label: Text('$count'),
              child: const SizedBox.square(dimension: 20),
            ),
      onTap: _showTasks,
    );
  }

  Widget _accountFooter(double progress) {
    final current = services.library.accounts
        .where((account) => account.mostRecent)
        .firstOrNull;
    final label = current == null
        ? context.l10n.steamAccount
        : current.personaName.isEmpty
        ? current.accountName
        : current.personaName;
    return ui.CommonPopupBox(
      popupBuilder: (_) => ui.CommonPopupMenu(
        items: [
          for (final account in services.library.accounts)
            ui.CommonPopupMenuItem(
              label: account.personaName.isEmpty
                  ? account.accountName
                  : account.personaName,
              subtitle: account.accountName,
              leading: SteamAvatar(
                path: services.library.avatarPath(account),
                size: 20,
              ),
              checked: account.mostRecent,
              onPressed: () => showAction(
                context,
                () => services.library.switchAccount(account.accountName),
              ),
            ),
          ui.CommonPopupMenuItem(
            label: context.l10n.accountManagement,
            section: services.library.accounts.isEmpty
                ? null
                : const ui.CommonPopupMenuSection(),
            onPressed: () =>
                _push(SteamAccountManagerPage(library: services.library)),
          ),
          ui.CommonPopupMenuItem(
            label: context.l10n.addSteamAccount,
            onPressed: () =>
                showAction(context, () => services.library.openSteamLogin()),
          ),
        ],
      ),
      targetBuilder: (open) => ui.SidebarFooterButton(
        icon: SteamAvatar(
          path: current == null ? null : services.library.avatarPath(current),
          size: 20,
        ),
        label: label,
        progress: progress,
        onTap: open,
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      services.settings,
      services.library,
      services.tasks,
    ]),
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      final expanded =
          _sidebarExpanded && MediaQuery.sizeOf(context).width >= 900;
      final destinations = [
        ui.SidebarDestination(
          icon: Icons.space_dashboard_outlined,
          glyph: ui.AppGlyphs.dashboard,
          label: context.l10n.dashboard,
        ),
        ui.SidebarDestination(
          icon: Icons.grid_view_outlined,
          glyph: ui.AppGlyphs.profiles,
          label: context.l10n.library,
        ),
        ui.SidebarDestination(
          icon: Icons.storefront_outlined,
          glyph: ui.AppGlyphs.resources,
          label: context.l10n.store,
        ),
        ui.SidebarDestination(
          icon: Icons.emoji_events_outlined,
          glyph: ui.AppGlyphs.star,
          label: context.l10n.achievements,
        ),
        ui.SidebarDestination(
          icon: Icons.cloud_outlined,
          glyph: ui.AppGlyphs.cloudSync,
          label: context.l10n.cloudSaves,
        ),
      ];
      return Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.digit1, control: true):
              _NavigateIntent(0),
          SingleActivator(LogicalKeyboardKey.digit2, control: true):
              _NavigateIntent(1),
          SingleActivator(LogicalKeyboardKey.digit3, control: true):
              _NavigateIntent(2),
          SingleActivator(LogicalKeyboardKey.digit4, control: true):
              _NavigateIntent(3),
          SingleActivator(LogicalKeyboardKey.digit5, control: true):
              _NavigateIntent(4),
        },
        child: Actions(
          actions: {
            _NavigateIntent: CallbackAction<_NavigateIntent>(
              onInvoke: (intent) {
                _select(intent.index);
                return null;
              },
            ),
          },
          child: Scaffold(
            body: Column(
              children: [
                const ui.WindowHeader(),
                Expanded(
                  child: Stack(
                    children: [
                      if (services.settings.sidebarBlur)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-.8, -.85),
                                radius: 1.35,
                                colors: [
                                  scheme.primary.withValues(alpha: .12),
                                  scheme.surface,
                                ],
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          _buildSidebar(
                            context,
                            scheme,
                            expanded,
                            destinations,
                          ),
                          Expanded(child: _buildPageArea(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildSidebar(
    BuildContext context,
    ColorScheme scheme,
    bool expanded,
    List<ui.SidebarDestination> destinations,
  ) {
    final floating = services.settings.sidebarFloating;
    final blur = services.settings.sidebarBlur;
    final radius = BorderRadius.circular(floating ? 20 : 0);
    Widget pane = Material(
      color: blur
          ? scheme.chromeSurface.withValues(alpha: .78)
          : scheme.chromeSurface,
      shape: floating
          ? RoundedSuperellipseBorder(borderRadius: radius)
          : BorderDirectional(end: Divider.createBorderSide(context)),
      clipBehavior: Clip.antiAlias,
      child: ui.NavigationSidebar(
        destinations: destinations,
        selectedIndex: _index < destinations.length ? _index : -1,
        expanded: expanded,
        onSelected: _select,
        onToggle: _toggleSidebar,
        footerBuilder: (progress) => _sidebarFooter(progress),
      ),
    );
    if (blur) {
      pane = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: pane,
        ),
      );
    }
    return Padding(
      key: const ValueKey('sidebar-shell'),
      padding: floating
          ? const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8)
          : EdgeInsets.zero,
      child: pane,
    );
  }

  Widget _sidebarFooter(double progress) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _FooterButton(
        icon: Icons.rss_feed,
        glyph: ui.AppGlyphs.link,
        label: context.l10n.contentSources,
        progress: progress,
        selected: _index == 7,
        onTap: _openManifestSources,
      ),
      _FooterButton(
        icon: Icons.widgets_outlined,
        glyph: ui.AppGlyphs.tools,
        label: context.l10n.tools2,
        progress: progress,
        selected: _index == 5,
        onTap: _openTools,
      ),
      _taskFooter(progress),
      _FooterButton(
        icon: Icons.settings_outlined,
        glyph: ui.AppGlyphs.settings,
        label: context.l10n.settings,
        progress: progress,
        selected: _index == 6,
        onTap: _settings,
      ),
      _accountFooter(progress),
      const SizedBox(height: 10),
    ],
  );

  Widget _buildPageArea(BuildContext context) => Column(
    children: [
      if (services.startupErrors.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ui.CommonCard(
            isError: true,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(services.startupErrors.join('\n')),
                ),
                TextButton(
                  onPressed: _settings,
                  child: Text(context.l10n.settings),
                ),
              ],
            ),
          ),
        ),
      Expanded(child: _buildAnimatedPages(context)),
    ],
  );

  Widget _buildAnimatedPages(BuildContext context) {
    final content = Stack(
      children: [
        for (var index = 0; index < _navigators.length; index++)
          if (_visited.contains(index))
            Offstage(
              offstage: _index != index,
              child: TickerMode(
                enabled: _index == index,
                child: ExcludeFocus(
                  excluding: _index != index,
                  child: Navigator(
                    key: _navigators[index],
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => ListenableBuilder(
                        listenable: Listenable.merge([
                          services.settings,
                          services.library,
                        ]),
                        builder: (_, _) => _page(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        services.settings.tabAnimation == 'none';
    return TweenAnimationBuilder<double>(
      key: ValueKey('page-$_index-$_navigationNonce'),
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final slide = services.settings.tabAnimation == 'slide';
        return Opacity(
          opacity: slide ? .82 + .18 * value : value,
          child: Transform.translate(
            offset: slide
                ? Offset(18 * _navigationDirection * (1 - value), 0)
                : Offset.zero,
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

class _NavigateIntent extends Intent {
  const _NavigateIntent(this.index);
  final int index;
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.progress,
    required this.onTap,
    this.glyph,
    this.trailing,
    this.selected = false,
  });

  final IconData icon;
  final ui.Glyph? glyph;
  final String label;
  final double progress;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;

  Widget get _icon =>
      glyph == null ? Icon(icon, size: 20) : ui.GlyphIcon(glyph!, size: 20);

  @override
  Widget build(BuildContext context) => ui.SidebarFooterButton(
    icon: _icon,
    label: label,
    progress: progress,
    onTap: onTap,
    trailing: trailing,
    selected: selected,
  );
}
