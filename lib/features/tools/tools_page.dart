import 'package:flutter/material.dart';

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../lan_transfer/lan_transfer_page.dart';
import '../lan_transfer/lan_transfer_service.dart';
import '../achievements/achievement_service.dart';
import '../patching/ticket_page.dart';
import '../steam_protocol/steam_protocol_service.dart';
import 'manifest_monitor.dart';
import 'online/online_pages.dart';
import 'online/online_services.dart';
import 'steam_extraction_pages.dart';
import 'tool_pages.dart';
import 'tools_service.dart';

class ToolsController {
  ToolsController({
    required AppPaths appPaths,
    required SettingsStore settings,
    required TaskCenter tasks,
  }) : service = ToolsService(paths: appPaths, settings: settings),
       downloader = ManifestCdnDownloader(),
       trainers = TrainerService(paths: appPaths, settings: settings),
       onlineFix = OnlineFixService(paths: appPaths) {
    monitor = ManifestMonitor(
      tasks: tasks,
      download: (request, task) async {
        await downloader.download(settings.steamPath, request, task);
      },
    );
  }

  final ToolsService service;
  final ManifestCdnDownloader downloader;
  final TrainerService trainers;
  final OnlineFixService onlineFix;
  late final ManifestMonitor monitor;

  Future<void> initialize() => trainers.loadBindings();

  Future<void> shutdown() async {
    monitor.stop();
    await trainers.shutdown();
  }

  void dispose() {
    monitor.dispose();
    downloader.dispose();
    service.dispose();
    trainers.dispose();
    onlineFix.dispose();
  }
}

class ToolDestination {
  const ToolDestination({
    required this.glyph,
    required this.label,
    required this.description,
    required this.onPressed,
  });

  final ui.Glyph glyph;
  final String label;
  final String description;
  final VoidCallback onPressed;
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({
    super.key,
    required this.appPaths,
    required this.settings,
    required this.tasks,
    this.selectedGame,
    this.games = const [],
    this.controller,
    this.lanTransfer,
    this.steam,
    this.achievements,
    this.destinations = const [],
    this.onGameChanged,
  });

  final AppPaths appPaths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final GameEntry? selectedGame;
  final List<GameEntry> games;
  final ToolsController? controller;
  final LanTransferService? lanTransfer;
  final SteamProtocolService? steam;
  final AchievementService? achievements;
  final List<ToolDestination> destinations;
  final VoidCallback? onGameChanged;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

enum _ToolGroup { files, authorization, game, maintenance }

class _ToolEntry {
  const _ToolEntry({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final ui.Glyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
}

class _ToolsPageState extends State<ToolsPage> {
  late final ToolsController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        ToolsController(
          appPaths: widget.appPaths,
          settings: widget.settings,
          tasks: widget.tasks,
        );
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _push(Widget page) => Navigator.of(context).push(
    ui.buildAppPageRoute(
      builder: (_) => page,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    ),
  );

  List<_ToolEntry> _entries(_ToolGroup group) {
    final game = widget.selectedGame;
    return switch (group) {
      _ToolGroup.files => [
        _ToolEntry(
          glyph: ui.AppGlyphs.swap,
          title: context.l10n.luaVdfConversion,
          subtitle:
              context.l10n.convertLuaVdfAndAcfFilesToASeparateOutputFolder,
          onPressed: () => _push(
            ToolConverterPage(
              service: _controller.service,
              tasks: widget.tasks,
              game: game,
            ),
          ),
        ),
        _ToolEntry(
          glyph: ui.AppGlyphs.resources,
          title: context.l10n.convertAFolder,
          subtitle: context.l10n.processAllSupportedFilesInAFolder,
          onPressed: () => _push(
            ToolConverterPage(
              service: _controller.service,
              tasks: widget.tasks,
              game: game,
              initialFolderMode: true,
            ),
          ),
        ),
        _ToolEntry(
          glyph: ui.AppGlyphs.cloudDownload,
          title: context.l10n.manifestMonitoring,
          subtitle: context.l10n.fetchMissingManifestsRequestedBySteam,
          onPressed: () => _push(
            ManifestMonitorPage(
              monitor: _controller.monitor,
              steamPath: widget.settings.steamPath,
            ),
          ),
        ),
        if (widget.lanTransfer case final transfer?)
          _ToolEntry(
            glyph: ui.AppGlyphs.devices,
            title: context.l10n.lanTransfer,
            subtitle: context.l10n.lanTransferDescription,
            onPressed: () => _push(
              LanTransferPage(
                service: transfer,
                settings: widget.settings,
                games: widget.games,
              ),
            ),
          ),
      ],
      _ToolGroup.authorization => [
        _ToolEntry(
          glyph: ui.AppGlyphs.key,
          title: context.l10n.denuvoAuthorization,
          subtitle: context.l10n.authorizationTicketDescription,
          onPressed: () => _push(
            TicketPage(
              paths: widget.appPaths,
              tasks: widget.tasks,
              game: game,
              games: widget.games,
            ),
          ),
        ),
        if (widget.achievements case final achievements?)
          _ToolEntry(
            glyph: ui.AppGlyphs.export,
            title: context.l10n.denuvoTicketExtraction,
            subtitle: context.l10n.denuvoTicketExtractionDescription,
            onPressed: () => _push(
              DenuvoExtractionPage(
                paths: widget.appPaths,
                settings: widget.settings,
                tasks: widget.tasks,
                achievements: achievements,
                game: game,
                games: widget.games,
              ),
            ),
          ),
      ],
      _ToolGroup.game => [
        if (widget.steam != null) ...[
          _ToolEntry(
            glyph: ui.AppGlyphs.export,
            title: context.l10n.luaExtraction,
            subtitle: context.l10n.luaExtractionDescription,
            onPressed: () => _push(
              LuaExtractionPage(
                paths: widget.appPaths,
                settings: widget.settings,
                tasks: widget.tasks,
                steam: widget.steam!,
                game: game,
              ),
            ),
          ),
        ],
        if (game?.hasLua == true)
          _ToolEntry(
            glyph: ui.AppGlyphs.pin,
            title: context.l10n.manifestVersionPins,
            subtitle:
                context.l10n.installedManifestsLatestPublicManifestsOrUnpin,
            onPressed: () => _push(
              ManifestPinsPage(
                service: _controller.service,
                tasks: widget.tasks,
                game: game!,
                onChanged: widget.onGameChanged,
              ),
            ),
          ),
        if (game?.hasLua == true)
          _ToolEntry(
            glyph: ui.AppGlyphs.puzzle,
            title: context.l10n.addDlcAppids,
            subtitle:
                context.l10n.appendDlcEntriesWithoutDuplicatingExistingRecords,
            onPressed: () => _push(
              DlcEditorPage(
                service: _controller.service,
                tasks: widget.tasks,
                game: game!,
                onChanged: widget.onGameChanged,
              ),
            ),
          ),
        if (game != null)
          _ToolEntry(
            glyph: ui.AppGlyphs.photos,
            title: context.l10n.downloadCover,
            subtitle: context.l10n.saveToTheApplicationCoverCache,
            onPressed: () => _push(
              CoverDownloadPage(
                service: _controller.service,
                tasks: widget.tasks,
                settings: widget.settings,
                game: game,
                onChanged: widget.onGameChanged,
              ),
            ),
          ),
        _ToolEntry(
          glyph: ui.AppGlyphs.sliders,
          title: context.l10n.trainers,
          subtitle: context.l10n.searchDownloadAndBindTrainers,
          onPressed: () => _push(
            TrainerToolsPage(
              appPaths: widget.appPaths,
              settings: widget.settings,
              tasks: widget.tasks,
              game: game,
              games: widget.games,
              service: _controller.trainers,
            ),
          ),
        ),
        _ToolEntry(
          glyph: ui.AppGlyphs.devices,
          title: 'OnlineFix',
          subtitle: context.l10n.findOnlineFixesAndDownloadFiles,
          onPressed: () => _push(
            OnlineFixToolsPage(
              appPaths: widget.appPaths,
              settings: widget.settings,
              tasks: widget.tasks,
              game: game,
              service: _controller.onlineFix,
            ),
          ),
        ),
        for (final destination in widget.destinations)
          _ToolEntry(
            glyph: destination.glyph,
            title: destination.label,
            subtitle: destination.description,
            onPressed: destination.onPressed,
          ),
      ],
      _ToolGroup.maintenance => [
        _ToolEntry(
          glyph: ui.AppGlyphs.verified,
          title: context.l10n.diagnostics,
          subtitle: context.l10n.steamPathClientAndDataDirectories,
          onPressed: () => _push(DiagnosticsPage(service: _controller.service)),
        ),
        _ToolEntry(
          glyph: ui.AppGlyphs.logs,
          title: context.l10n.applicationFolders,
          subtitle: context.l10n.openLogsAndBackups,
          onPressed: () => _push(
            ToolFoldersPage(
              service: _controller.service,
              logsPath: widget.appPaths.file('logs'),
              backupsPath: widget.appPaths.file('backups'),
            ),
          ),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final files = _entries(_ToolGroup.files);
    final authorization = _entries(_ToolGroup.authorization);
    final game = _entries(_ToolGroup.game);
    final maintenance = _entries(_ToolGroup.maintenance);
    final selectedGame = widget.selectedGame;
    return ui.CommonScaffold(
      title: context.l10n.tools,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.filesAndManifests,
            items: [for (final entry in files) _ToolRow(entry: entry)],
            footer:
                context.l10n.convertLuaVdfAndAcfFilesToASeparateOutputFolder,
          ),
          if (authorization.isNotEmpty)
            ui.generateSection(
              title: context.l10n.authorization,
              items: [
                for (final entry in authorization) _ToolRow(entry: entry),
              ],
            ),
          ui.generateSection(
            title: context.l10n.gameTools,
            items: [
              if (selectedGame != null)
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.profiles, size: 20),
                  title: Text(
                    selectedGame.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'AppID ${selectedGame.appId}'
                    '${selectedGame.isInstalled ? ' · ${context.l10n.installed}' : ''}',
                  ),
                  trailing: ui.MetaChip(label: context.l10n.game),
                ),
              for (final entry in game) _ToolRow(entry: entry),
            ],
            footer: selectedGame == null
                ? context.l10n.selectAGameToShowGameTools
                : null,
          ),
          ui.generateSection(
            title: context.l10n.maintenance,
            items: [for (final entry in maintenance) _ToolRow(entry: entry)],
            footer: context.l10n.steamPathClientAndDataDirectories,
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.entry});

  final _ToolEntry entry;

  @override
  Widget build(BuildContext context) {
    return ui.DecorationListItem(
      leading: ui.GlyphIcon(entry.glyph, size: 20),
      title: Text(entry.title),
      subtitle: Text(
        entry.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
      onPressed: entry.onPressed,
    );
  }
}
