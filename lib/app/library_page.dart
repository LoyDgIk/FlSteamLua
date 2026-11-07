import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/game_entry.dart';
import '../core/settings_store.dart';
import '../features/library/library_service.dart';
import '../features/content_sources/content_import_dialog.dart';
import '../features/library/lua_editor_page.dart';
import '../features/lan_transfer/lan_transfer_page.dart';
import '../features/network/network_cover_image.dart';
import '../features/patching/ticket_authorization.dart';
import '../features/patching/ticket_page.dart';
import '../features/store/store_service.dart';
import '../ui/ui.dart' as ui;
import '../ui/context.dart';
import 'app_services.dart';
import 'support_sheet.dart';
import 'widgets.dart';
import '../ui/localization.dart';

Future<void> importLibraryFiles(
  BuildContext context,
  AppServices services, {
  List<String>? sourcePaths,
  bool overwrite = false,
}) async {
  final sources =
      sourcePaths ??
      (await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'lua',
          'bin',
          'manifest',
          'zip',
          '7z',
          'rar',
          'tar',
          'tgz',
          'gz',
          'txt',
        ],
      ))?.paths.whereType<String>().toList();
  if (sources == null || sources.isEmpty || !context.mounted) return;
  final ticketSources = sources
      .where((path) => p.extension(path).toLowerCase() == '.txt')
      .toList();
  if (ticketSources.isNotEmpty) {
    if (sources.length != 1) {
      ui.showAppError(
        context,
        FormatException(context.l10n.importOneTicketFileAtATime),
      );
      return;
    }
    try {
      final ticketFile = File(ticketSources.single);
      if (ticketFile.lengthSync() > 2 * 1024 * 1024) {
        throw const FormatException('Ticket file exceeds 2 MiB');
      }
      final ticket = AuthorizationTicket.parse(ticketFile.readAsStringSync());
      if (!context.mounted) return;
      final game =
          services.library.games
              .where((game) => game.appId == ticket.appId)
              .firstOrNull ??
          GameEntry(appId: ticket.appId, name: 'AppID ${ticket.appId}');
      await Navigator.of(context).push(
        ui.buildAppPageRoute(
          builder: (_) => TicketPage(
            settings: services.settings,
            paths: services.paths,
            tasks: services.tasks,
            game: game,
            games: services.library.games,
            initialTicket: ticket,
          ),
          reduceMotion: MediaQuery.disableAnimationsOf(context),
        ),
      );
    } catch (error) {
      if (context.mounted) ui.showAppError(context, error);
    }
    return;
  }
  await showLocalContentImportDialog(
    context,
    resolver: services.contentResolver,
    importer: services.contentImporter,
    tasks: services.tasks,
    paths: sources,
  );
}

Future<bool?> _showLibraryResult(
  BuildContext context,
  ImportResult result, {
  required String title,
  bool allowOverwrite = false,
}) => ui.showFlDialog<bool>(
  context: context,
  builder: (context) => ui.CommonDialog(
    title: title,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(context.l10n.close),
      ),
      if (allowOverwrite && result.skipped.isNotEmpty)
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.backUpAndReimportWithOverwrite),
        ),
    ],
    child: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.completedSkippedFailed(
                (result.written.length).toString(),
                (result.skipped.length).toString(),
                (result.errors.length).toString(),
              ),
            ),
            for (final group in [
              (context.l10n.completed, result.written),
              (context.l10n.existingFilesLeftUnchanged, result.skipped),
              (
                context.l10n.errors,
                result.errors.entries
                    .map((entry) => '${entry.key}\n${entry.value}')
                    .toList(),
              ),
            ])
              if (group.$2.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(group.$1, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SelectableText(group.$2.join('\n')),
              ],
          ],
        ),
      ),
    ),
  ),
);

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.services,
    required this.detailBuilder,
    required this.onSettings,
    this.onDestination,
    this.initialTab = 0,
    this.tabRequest = 0,
  });
  final AppServices services;
  final Widget Function(GameEntry) detailBuilder;
  final VoidCallback onSettings;
  final void Function(String destination, GameEntry game)? onDestination;
  final int initialTab;
  final int tabRequest;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _search = TextEditingController();
  final _selected = <int>{};
  final _metadataAttempted = <int>{};
  final _metadataErrors = <int, String>{};
  final _metadataCancellation = Completer<void>();
  late final ui.AppBarSearchState _searchState;
  int _scope = 0;
  String _filter = 'all';
  String _sort = 'name';
  String _view = 'grid';
  bool _selectionMode = false;
  bool _dragging = false;
  bool _importing = false;
  bool _metadataBusy = false;
  bool _metadataScheduled = false;

  LibraryService get _library => widget.services.library;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialTab;
    _searchState = ui.AppBarSearchState(
      onSearch: (query) {
        _search.text = query;
        setState(() {});
      },
    );
    _library.addListener(_libraryChanged);
    _scheduleMetadata();
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab ||
        oldWidget.tabRequest != widget.tabRequest) {
      _scope = widget.initialTab;
      _filter = 'all';
      _selected.clear();
    }
    if (oldWidget.services.library != _library) {
      oldWidget.services.library.removeListener(_libraryChanged);
      _library.addListener(_libraryChanged);
      _metadataAttempted.clear();
      _metadataErrors.clear();
      _scheduleMetadata();
    }
  }

  void _libraryChanged() => _scheduleMetadata();

  void _scheduleMetadata() {
    if (_metadataScheduled || _metadataBusy) return;
    _metadataScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metadataScheduled = false;
      if (mounted) _fetchMetadata();
    });
  }

  Future<void> _fetchMetadata({bool refresh = false}) async {
    final localeText = context.l10n;
    if (_metadataBusy) return;
    final candidates = _library.games
        .where(
          (game) => refresh
              ? (_scope == 0 ? game.hasLua : game.isInstalled)
              : game.hasLua &&
                    game.name == 'App ${game.appId}' &&
                    !_metadataAttempted.contains(game.appId),
        )
        .toList();
    if (candidates.isEmpty) return;
    setState(() => _metadataBusy = true);
    _metadataAttempted.addAll(candidates.map((game) => game.appId));
    final errors = <int, String>{};
    try {
      await widget.services.tasks.run(localeText.fetchGameNamesAndCovers, (
        task,
      ) async {
        for (var i = 0; i < candidates.length; i++) {
          task.checkCancelled();
          if (!mounted) throw const StoreRequestCancelled();
          final game = candidates[i];
          try {
            final detail = await widget.services.store.details(
              game.appId,
              cancelled: _metadataCancellation.future,
            );
            if (!mounted) return;
            if (_library.games.any((entry) => entry.appId == game.appId)) {
              await _library.updateGameMetadata(
                game.appId,
                name: detail.name,
                coverUrl: detail.headerImage,
              );
            }
            _metadataErrors.remove(game.appId);
          } on StoreRequestCancelled {
            rethrow;
          } catch (error) {
            errors[game.appId] = '$error';
            _metadataErrors[game.appId] = '$error';
          }
          task.report(
            '${game.appId}: ${errors[game.appId] ?? game.name}',
            (i + 1) / candidates.length,
          );
        }
        if (errors.isNotEmpty) {
          throw StateError(
            errors.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n'),
          );
        }
      });
    } catch (error) {
      if (mounted && errors.isEmpty) {
        _metadataErrors[candidates.first.appId] = '$error';
      }
    } finally {
      if (mounted) {
        setState(() => _metadataBusy = false);
        _scheduleMetadata();
      }
    }
  }

  @override
  void dispose() {
    _library.removeListener(_libraryChanged);
    _metadataCancellation.complete();
    _search.dispose();
    super.dispose();
  }

  void _selectScope(int scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _filter = 'all';
      _selected.clear();
      _selectionMode = false;
    });
  }

  List<GameEntry> _scopeGames(LibraryService library) => library.games
      .where((game) => _scope == 0 ? game.hasLua : game.isInstalled)
      .toList();

  List<GameEntry> _filtered(LibraryService library) {
    final term = _search.text.trim().toLowerCase();
    final games = _scopeGames(library)
        .where(
          (game) =>
              (term.isEmpty ||
                  game.name.toLowerCase().contains(term) ||
                  '${game.appId}'.contains(term)) &&
              switch (_filter) {
                'enabled' => game.luaEnabled,
                'disabled' => !game.luaEnabled,
                'running' => game.isRunning,
                'favorites' => game.isFavorite,
                _ => true,
              },
        )
        .toList();
    games.sort(
      (a, b) => switch (_sort) {
        'name-desc' => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        'app-id' => a.appId.compareTo(b.appId),
        'app-id-desc' => b.appId.compareTo(a.appId),
        'recent' => (b.lastPlayed ?? DateTime(1970)).compareTo(
          a.lastPlayed ?? DateTime(1970),
        ),
        'playtime' => (b.playtimeMinutes ?? -1).compareTo(
          a.playtimeMinutes ?? -1,
        ),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      },
    );
    return games;
  }

  void _toggleSelection(GameEntry game) => setState(() {
    if (!_selected.add(game.appId)) _selected.remove(game.appId);
  });

  Future<void> _import(List<String>? sources) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await importLibraryFiles(context, widget.services, sourcePaths: sources);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFolder() async {
    final localeText = context.l10n;
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: localeText.chooseALuaAndManifestFolder,
    );
    if (path != null && mounted) await _import([path]);
  }

  void _openDetails(GameEntry game) => Navigator.of(context).push(
    ui.buildAppPageRoute(
      builder: (_) => widget.detailBuilder(game),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    ),
  );

  Future<void> _export(Iterable<GameEntry> games) async {
    final localeText = context.l10n;
    final entries = games.toList();
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: localeText.exportLuaToFolder,
    );
    if (directory == null || !mounted) return;
    await showAction(context, () async {
      final result = await widget.services.tasks.run(
        localeText.exportLua,
        (task) => _library.exportLua(
          entries.map((game) => game.appId),
          directory,
          context: task,
        ),
      );
      if (mounted) {
        await _showLibraryResult(
          context,
          result,
          title: localeText.exportResults,
        );
      }
    });
  }

  Future<void> _batch(String operation, List<GameEntry> games) async {
    final localeText = context.l10n;
    final targets = games
        .where(
          (game) =>
              game.hasLua &&
              (operation == 'delete' ||
                  game.luaEnabled != (operation == 'enable')),
        )
        .toList();
    if (targets.isEmpty) return;
    final title = switch (operation) {
      'enable' => localeText.enableSelectedLua,
      'disable' => localeText.disableSelectedLua,
      _ => localeText.deleteLua,
    };
    if (operation == 'delete') {
      final accepted = await ui.showFlDialog<bool>(
        context: context,
        builder: (context) => ui.CommonDialog(
          title: localeText.deleteLuaFiles((targets.length).toString()),
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localeText.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(localeText.backUpAndDelete),
            ),
          ],
          child: Text(
            localeText
                .luaFilesAreBackedUpBeforeDeletionSteamGamesAndSavesAreKept(
                  (targets.map((game) => game.name).join('\n')).toString(),
                ),
          ),
        ),
      );
      if (accepted != true || !mounted) return;
    }
    await showAction(context, () async {
      final ids = targets.map((game) => game.appId).toList();
      final result = await widget.services.tasks.run(
        title,
        (task) => operation == 'delete'
            ? _library.deleteLuaFiles(ids, context: task)
            : _library.setLuaEnabled(ids, operation == 'enable', context: task),
      );
      if (!mounted) return;
      setState(() {
        for (final game in targets) {
          if (!result.errors.containsKey('${game.appId}')) {
            _selected.remove(game.appId);
          }
        }
      });
      if (result.errors.isNotEmpty) {
        await _showLibraryResult(context, result, title: title);
      } else {
        ui.showAppSuccess(context, '$title · ${result.written.length}');
      }
    });
  }

  ui.CommonPopupMenuItem _menuItem(
    String action,
    GameEntry game,
    String label,
    ui.Glyph glyph, {
    bool danger = false,
    ui.CommonPopupMenuSection? section,
  }) => ui.CommonPopupMenuItem(
    label: label,
    glyph: glyph,
    section: section,
    danger: danger,
    onPressed: () => _action(action, game),
  );

  List<ui.CommonPopupMenuItem> _menuItems(GameEntry game) {
    final luaActions = [
      if (game.hasLua)
        _menuItem('export', game, context.l10n.exportLua, ui.AppGlyphs.export),
      if (game.hasLua)
        _menuItem(
          'lua-folder',
          game,
          context.l10n.openLuaFolder,
          ui.AppGlyphs.resources,
        ),
      if (game.hasLua)
        _menuItem(
          'pin-latest',
          game,
          context.l10n.pinLatestPublicVersion,
          ui.AppGlyphs.pin,
        ),
      if (game.hasLua && game.isInstalled)
        _menuItem(
          'pin-installed',
          game,
          context.l10n.pinInstalledVersion,
          ui.AppGlyphs.pin,
        ),
      if (game.hasLua)
        _menuItem(
          'unpin',
          game,
          context.l10n.unpinVersion,
          ui.AppGlyphs.lockOpen,
        ),
    ];
    final managementActions = [
      _menuItem(
        'clear-manifests',
        game,
        context.l10n.clearDownloadedManifests,
        ui.AppGlyphs.delete,
      ),
      if (widget.onDestination != null) ...[
        if (game.hasLua)
          _menuItem(
            'dlc_analysis',
            game,
            context.l10n.dlcManagementAndAnalysis,
            ui.AppGlyphs.addCircle,
          ),
        _menuItem(
          'cloud',
          game,
          context.l10n.manageGameSaves,
          ui.AppGlyphs.cloudSync,
        ),
        _menuItem(
          'achievements',
          game,
          context.l10n.editAchievements,
          ui.AppGlyphs.star,
        ),
        _menuItem(
          'patch_settings',
          game,
          context.l10n.patchSettings,
          ui.AppGlyphs.tools,
        ),
        _menuItem(
          'patch_download',
          game,
          context.l10n.gamePatchDownload,
          ui.AppGlyphs.cloudDownload,
        ),
        _menuItem(
          'lua_extraction',
          game,
          context.l10n.luaExtraction,
          ui.AppGlyphs.export,
        ),
        _menuItem(
          'denuvo_extraction',
          game,
          context.l10n.denuvoTicketExtraction,
          ui.AppGlyphs.key,
        ),
        _menuItem('trainers', game, context.l10n.trainers, ui.AppGlyphs.tools),
      ],
    ];
    final moreActions = [
      if (game.isInstalled)
        _menuItem(
          'game-folder',
          game,
          context.l10n.openGameFolder,
          ui.AppGlyphs.resources,
        ),
      if (game.isInstalled)
        _menuItem(
          'lan-send',
          game,
          context.l10n.lanSendToLan,
          ui.AppGlyphs.send,
        ),
      _menuItem('copy-id', game, context.l10n.copyAppid, ui.AppGlyphs.copy),
      if (game.hasLua)
        _menuItem(
          'delete',
          game,
          context.l10n.deleteLua,
          ui.AppGlyphs.delete,
          danger: true,
        ),
    ];
    return [
      _menuItem('detail', game, context.l10n.gameDetails, ui.AppGlyphs.info),
      if (game.hasLua) ...[
        _menuItem('edit', game, context.l10n.editLua, ui.AppGlyphs.edit),
        _menuItem(
          'toggle',
          game,
          game.luaEnabled ? context.l10n.disableLua : context.l10n.enableLua,
          game.luaEnabled ? ui.AppGlyphs.block : ui.AppGlyphs.checkCircle,
        ),
      ],
      _menuItem(
        'favorite',
        game,
        game.isFavorite ? context.l10n.unfavorite : context.l10n.favorite,
        ui.AppGlyphs.star,
      ),
      if (luaActions.isNotEmpty)
        ui.CommonPopupMenuItem(
          label: context.l10n.luaLibrary,
          glyph: ui.AppGlyphs.code,
          subItems: luaActions,
        ),
      if (managementActions.isNotEmpty)
        ui.CommonPopupMenuItem(
          label: context.l10n.gameManagement,
          glyph: ui.AppGlyphs.tools,
          subItems: managementActions,
        ),
      if (moreActions.isNotEmpty)
        ui.CommonPopupMenuItem(
          label: context.l10n.more,
          glyph: ui.AppGlyphs.more,
          subItems: moreActions,
        ),
    ];
  }

  Future<void> _action(String action, GameEntry game) async {
    final localeText = context.l10n;
    if (action == 'detail') {
      _openDetails(game);
    } else if (action == 'edit') {
      await Navigator.of(context).push(
        ui.buildAppPageRoute(
          builder: (_) => LuaEditorPage(library: _library, game: game),
        ),
      );
      if (mounted) await _library.scan();
    } else if (action == 'toggle') {
      await showAction(
        context,
        () => _library.toggleLua(game.appId, !game.luaEnabled),
      );
    } else if (action == 'export') {
      await _export([game]);
    } else if (action == 'delete') {
      await _batch('delete', [game]);
    } else if (action == 'lua-folder') {
      await showAction(
        context,
        () => _library.openLuaDirectory(appId: game.appId),
      );
    } else if (action == 'game-folder') {
      await showAction(context, () => _library.openDirectory(game.appId));
    } else if (action == 'lan-send') {
      final session = await showLanTransferSendSheet(
        context,
        service: widget.services.lanTransfer,
        settings: widget.services.settings,
        game: game,
      );
      if (session != null && mounted) {
        await openLanTransferSessionPage(
          context,
          service: widget.services.lanTransfer,
          settings: widget.services.settings,
          session: session,
        );
      }
    } else if (action == 'favorite') {
      await showAction(
        context,
        () => _library.setFavorite(game.appId, !game.isFavorite),
      );
    } else if (action == 'copy-id') {
      await Clipboard.setData(ClipboardData(text: '${game.appId}'));
    } else if (action == 'clear-manifests') {
      final accepted = await ui.showFlDialog<bool>(
        context: context,
        builder: (context) => ui.CommonDialog(
          title: localeText.clearDownloadedManifests,
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localeText.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(localeText.clear),
            ),
          ],
          child: Text(
            localeText.clearDownloadedManifestsDescription(game.name),
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      await showAction(context, () async {
        final count = await widget.services.tools.service
            .clearDepotcacheManifests(game);
        if (!mounted) return;
        if (count == 0) {
          ui.showAppFeedback(context, localeText.noDownloadedManifests);
        } else {
          ui.showAppSuccess(
            context,
            localeText.downloadedManifestsCleared('$count'),
          );
        }
      });
    } else if (action.startsWith('pin-') || action == 'unpin') {
      await showAction(
        context,
        () => widget.services.tasks.run(localeText.updateManifestPins, (
          task,
        ) async {
          final tools = widget.services.tools.service;
          if (action == 'unpin') {
            await tools.unpinManifests(game);
          } else {
            final ids = action == 'pin-installed'
                ? await tools.installedManifests(game)
                : await tools.latestManifests(
                    game.appId,
                    (await tools.depots(game)).map((depot) => depot.id),
                  );
            if (ids.isEmpty) {
              throw const FormatException(
                'No matching depot manifests were found',
              );
            }
            task.checkCancelled();
            await tools.pinManifests(game, ids);
          }
          await _library.scan();
        }, appId: game.appId),
      );
    } else {
      widget.onDestination?.call(action, game);
    }
  }

  Widget _actions(GameEntry game) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_scope == 1) ...[
        ui.CommonPopupBox(
          targetBuilder: (open) => IconButton(
            key: ValueKey('online-launch-${game.appId}'),
            tooltip: context.l10n.onlineLaunch,
            onPressed: game.isRunning ? null : open,
            icon: const ui.GlyphIcon(ui.AppGlyphs.connections, size: 19),
          ),
          popupBuilder: (_) => ui.CommonPopupMenu(
            items: [
              ui.CommonPopupMenuItem(
                label: context.l10n.onlineFixOnly,
                glyph: ui.AppGlyphs.connections,
                onPressed: () => showAction(
                  context,
                  () => _library.launch(
                    game.appId,
                    launchArguments: const ['-onlinefix'],
                  ),
                ),
              ),
              ui.CommonPopupMenuItem(
                label: context.l10n.onlineFixWithRealAppId,
                glyph: ui.AppGlyphs.link,
                onPressed: () => showAction(
                  context,
                  () => _library.launch(
                    game.appId,
                    launchArguments: const ['-onlinefix', '-realappid'],
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: (game.isRunning
              ? context.l10n.stopGame
              : context.l10n.launchGame),
          icon: ui.GlyphIcon(
            ui.AppGlyphs.playPause(game.isRunning ? 1 : 0),
            size: 20,
          ),
          onPressed: () => showAction(
            context,
            () => game.isRunning
                ? _library.stop(game.appId)
                : _library.launch(game.appId),
          ),
        ),
      ],
      if (_scope == 0 && game.hasLua) ...[
        IconButton(
          tooltip: context.l10n.editLua,
          icon: const ui.GlyphIcon(ui.AppGlyphs.edit, size: 19),
          onPressed: () => _action('edit', game),
        ),
        ui.CommonSwitch(
          value: game.luaEnabled,
          onChanged: (enabled) => showAction(
            context,
            () => _library.toggleLua(game.appId, enabled),
          ),
        ),
      ],
      ui.CommonPopupBox(
        targetBuilder: (open) => IconButton(
          tooltip: context.l10n.manage2((game.name).toString()),
          onPressed: open,
          icon: const ui.GlyphIcon(ui.AppGlyphs.more, size: 20),
        ),
        popupBuilder: (_) => ui.CommonPopupMenu(items: _menuItems(game)),
      ),
    ],
  );

  Widget _selectBox(GameEntry game) => Checkbox(
    value: _selected.contains(game.appId),
    onChanged: (_) => _toggleSelection(game),
  );

  Widget _card(GameEntry game) => ui.ContextMenuRegion(
    menuItems: _menuItems(game),
    child: Stack(
      children: [
        Positioned.fill(
          child: GameCard(
            game: game,
            settings: widget.services.settings,
            detailBuilder: widget.detailBuilder,
            onFavorite: () => _action('favorite', game),
            onTap: _selectionMode ? () => _toggleSelection(game) : null,
            footer: Row(
              children: [
                Expanded(
                  child: Text(
                    _scope == 0
                        ? 'AppID ${game.appId}'
                        : formatGamePlaytime(
                            context.l10n,
                            game.playtimeMinutes,
                          ),
                    style: ui.AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ),
                _actions(game),
              ],
            ),
          ),
        ),
        if (_selectionMode)
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: const CircleBorder(),
              child: _selectBox(game),
            ),
          ),
      ],
    ),
  );

  Widget _listTile(GameEntry game) => ui.ContextMenuRegion(
    menuItems: _menuItems(game),
    child: ui.CommonCard(
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectionMode) _selectBox(game),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 54,
                child: _GameImage(
                  game: game,
                  settings: widget.services.settings,
                ),
              ),
            ),
          ],
        ),
        title: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'AppID ${game.appId} · ${game.hasLua ? (game.luaEnabled ? context.l10n.luaEnabled : context.l10n.luaDisabled2) : context.l10n.installed}${game.isRunning ? ' · ${context.l10n.running}' : ''}',
        ),
        trailing: _actions(game),
        onTap: () =>
            _selectionMode ? _toggleSelection(game) : _openDetails(game),
      ),
    ),
  );

  Widget _table(List<GameEntry> games, {required double topPadding}) =>
      SingleChildScrollView(
        padding: EdgeInsets.only(top: topPadding),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: _selectionMode,
            columns: [
              DataColumn(label: Text(context.l10n.game)),
              const DataColumn(label: Text('AppID'), numeric: true),
              DataColumn(label: Text(context.l10n.status)),
              DataColumn(
                label: Text(
                  _scope == 0 ? context.l10n.luaFile : context.l10n.playtime,
                ),
              ),
              DataColumn(label: Text(context.l10n.manage)),
            ],
            rows: [
              for (final game in games)
                DataRow(
                  selected: _selected.contains(game.appId),
                  onSelectChanged: _selectionMode
                      ? (_) => _toggleSelection(game)
                      : null,
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 190,
                        child: Text(
                          game.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () => _openDetails(game),
                    ),
                    DataCell(Text('${game.appId}')),
                    DataCell(
                      Text(
                        game.hasLua
                            ? (game.luaEnabled
                                  ? context.l10n.luaEnabled
                                  : context.l10n.luaDisabled2)
                            : context.l10n.installed,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 210,
                        child: Text(
                          _scope == 0
                              ? game.luaPath!
                              : formatGamePlaytime(
                                  context.l10n,
                                  game.playtimeMinutes,
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_actions(game)),
                  ],
                ),
            ],
          ),
        ),
      );

  Widget _bulkBar(List<GameEntry> games) {
    final selected = games
        .where((game) => _selected.contains(game.appId))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            context.l10n.selected(
              (selected.length).toString(),
              (games.length).toString(),
            ),
          ),
          TextButton(
            onPressed: () => setState(
              () => _selected.addAll(games.map((game) => game.appId)),
            ),
            child: Text(context.l10n.selectAllFiltered),
          ),
          TextButton(
            onPressed: () => setState(_selected.clear),
            child: Text(context.l10n.clearSelection2),
          ),
          if (_scope == 0) ...[
            OutlinedButton(
              onPressed: selected.any((game) => !game.luaEnabled)
                  ? () => _batch('enable', selected)
                  : null,
              child: Text(context.l10n.enableSelected),
            ),
            OutlinedButton(
              onPressed: selected.any((game) => game.luaEnabled)
                  ? () => _batch('disable', selected)
                  : null,
              child: Text(context.l10n.disableSelected),
            ),
            OutlinedButton(
              onPressed: selected.isEmpty ? null : () => _export(selected),
              child: Text(context.l10n.export),
            ),
            OutlinedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => _batch('delete', selected),
              child: Text(context.l10n.deleteLua),
            ),
          ],
        ],
      ),
    );
  }

  ui.Glyph _viewGlyph() => switch (_view) {
    'list' => ui.AppGlyphs.appsList,
    'table' => ui.AppGlyphs.dragHandle,
    _ => ui.AppGlyphs.dashboard,
  };

  List<(String, String, int)> _filterValues(List<GameEntry> games) => [
    ('all', context.l10n.all, games.length),
    if (_scope == 0) ...[
      (
        'enabled',
        context.l10n.enabled,
        games.where((game) => game.luaEnabled).length,
      ),
      (
        'disabled',
        context.l10n.disabled,
        games.where((game) => !game.luaEnabled).length,
      ),
    ] else
      (
        'running',
        context.l10n.running,
        games.where((game) => game.isRunning).length,
      ),
    (
      'favorites',
      context.l10n.favorites,
      games.where((game) => game.isFavorite).length,
    ),
  ];

  List<(String, String)> _sortValues() => [
    ('name', context.l10n.nameAscending),
    ('name-desc', context.l10n.nameDescending),
    ('app-id', 'AppID ↑'),
    ('app-id-desc', 'AppID ↓'),
    ('recent', context.l10n.recentlyPlayed),
    ('playtime', context.l10n.playtime),
  ];

  Widget _viewMenu() => ui.CommonPopupBox(
    key: const ValueKey('library-view-menu'),
    targetBuilder: (open) => ui.DashboardIconButton(
      glyph: _viewGlyph(),
      tooltip: context.l10n.view,
      onPressed: open,
    ),
    popupBuilder: (_) => ui.CommonPopupMenu(
      items: [
        for (final view in [
          ('grid', context.l10n.gridView),
          ('list', context.l10n.listView),
          ('table', context.l10n.tableView),
        ])
          ui.CommonPopupMenuItem(
            label: view.$2,
            checked: _view == view.$1,
            onPressed: () => setState(() => _view = view.$1),
          ),
      ],
    ),
  );

  Widget _moreMenu(List<GameEntry> scopeGames) => ui.CommonPopupBox(
    key: const ValueKey('library-more-menu'),
    targetBuilder: (open) => ui.DashboardIconButton(
      glyph: ui.AppGlyphs.more,
      tooltip: context.l10n.libraryActions,
      onPressed: open,
    ),
    popupBuilder: (_) => ui.CommonPopupMenu(
      items: [
        ui.CommonPopupMenuItem(
          label: context.l10n.filter,
          glyph: ui.AppGlyphs.filter,
          subItems: [
            for (final filter in _filterValues(scopeGames))
              ui.CommonPopupMenuItem(
                label: '${filter.$2}  ${filter.$3}',
                checked: _filter == filter.$1,
                onPressed: () => setState(() => _filter = filter.$1),
              ),
          ],
        ),
        ui.CommonPopupMenuItem(
          label: context.l10n.sort,
          glyph: ui.AppGlyphs.sort,
          subItems: [
            for (final sort in _sortValues())
              ui.CommonPopupMenuItem(
                label: sort.$2,
                checked: _sort == sort.$1,
                onPressed: () => setState(() => _sort = sort.$1),
              ),
          ],
        ),
        ui.CommonPopupMenuItem(
          label: _selectionMode ? context.l10n.done : context.l10n.select,
          glyph: ui.AppGlyphs.checkCircle,
          checked: _selectionMode,
          onPressed: () => setState(() {
            _selectionMode = !_selectionMode;
            if (!_selectionMode) _selected.clear();
          }),
        ),
        ui.CommonPopupMenuItem(
          label: context.l10n.rescan,
          glyph: ui.AppGlyphs.refresh,
          onPressed: _library.isScanning
              ? null
              : () => showAction(context, () => _library.scan()),
        ),
        if (_scope == 0)
          ui.CommonPopupMenuItem(
            label: context.l10n.openLuaFolder,
            glyph: ui.AppGlyphs.resources,
            onPressed: () =>
                showAction(context, () => _library.openLuaDirectory()),
          ),
        ui.CommonPopupMenuItem(
          label: context.l10n.refreshGameInformation,
          glyph: ui.AppGlyphs.refresh,
          onPressed: _metadataBusy ? null : () => _fetchMetadata(refresh: true),
        ),
        if (_scope == 1)
          ui.CommonPopupMenuItem(
            label: widget.services.settings.get<bool>('offlineMode', false)
                ? context.l10n.disableSteamOfflineMode
                : context.l10n.enableSteamOfflineMode,
            onPressed: () => showAction(
              context,
              () => _library.setOfflineMode(
                !widget.services.settings.get<bool>('offlineMode', false),
              ),
            ),
          ),
      ],
    ),
  );

  ui.NullStatus _emptyStatus(LibraryService library) {
    final connected = library.steamPath != null;
    return ui.NullStatus(
      label: connected
          ? (_scope == 0
                ? context.l10n.noMatchingLuaConfigurations
                : context.l10n.noMatchingInstalledGames)
          : context.l10n.connectYourSteamLibrary,
      description: connected
          ? (_scope == 0
                ? context
                      .l10n
                      .dropLuaFilesManifestsOrArchivesHereOrChangeTheFilter
                : context
                      .l10n
                      .installedGamesAreReadFromSteamAppmanifestFilesLuaConfigurationsAreInTheFirstTab)
          : context
                .l10n
                .chooseYourSteamInstallationToReadLuaConfigurationsAndInstalledGames,
      illustration: _scope == 0
          ? ui.NullStatusIllustration.lua
          : ui.NullStatusIllustration.steam,
      action: connected
          ? FilledButton.icon(
              onPressed: _scope == 0
                  ? (_importing ? null : () => _import(null))
                  : (library.isScanning
                        ? null
                        : () => showAction(context, () => library.scan())),
              icon: ui.GlyphIcon(
                _scope == 0 ? ui.AppGlyphs.add : ui.AppGlyphs.refresh,
                size: 18,
              ),
              label: Text(
                _scope == 0 ? context.l10n.importLua : context.l10n.rescan,
              ),
            )
          : FilledButton(
              onPressed: widget.onSettings,
              child: Text(context.l10n.chooseSteamFolder),
            ),
    );
  }

  Widget _content(List<GameEntry> games, {required double topPadding}) =>
      switch (_view) {
        'table' => _table(games, topPadding: topPadding),
        'list' => ListView.builder(
          key: PageStorageKey('library-$_scope-list'),
          padding: EdgeInsets.fromLTRB(0, topPadding, 0, 24),
          itemCount: games.length,
          itemBuilder: (_, index) => _listTile(games[index]),
        ),
        _ => GridView.builder(
          key: PageStorageKey('library-$_scope-grid'),
          padding: EdgeInsets.fromLTRB(0, topPadding, 0, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 560,
            mainAxisExtent: 148,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: games.length,
          itemBuilder: (_, index) => _card(games[index]),
        ),
      };

  Widget _warnings(LibraryService library) => ui.CommonCard(
    isError: true,
    inert: true,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            library.warnings.isNotEmpty
                ? library.warnings.first
                : context.l10n
                      .informationCouldNotBeLoadedForGamesLocalRecordsAreKept(
                        (_metadataErrors.length).toString(),
                      ),
          ),
        ),
        TextButton(
          onPressed: () => ui.showFlDialog<void>(
            context: context,
            builder: (context) => ui.CommonDialog(
              title: context.l10n.libraryDetails,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.close),
                ),
              ],
              child: SingleChildScrollView(
                child: SelectableText(
                  [
                    ...library.warnings,
                    ..._metadataErrors.entries.map(
                      (entry) => '${entry.key}: ${entry.value}',
                    ),
                  ].join('\n'),
                ),
              ),
            ),
          ),
          child: Text(context.l10n.details),
        ),
        if (_metadataErrors.isNotEmpty)
          TextButton(
            onPressed: _metadataBusy
                ? null
                : () => _fetchMetadata(refresh: true),
            child: Text(context.l10n.retry),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _library,
    builder: (context, _) {
      final library = _library;
      final scopeGames = _scopeGames(library);
      final games = _filtered(library);
      final filtering = _search.text.trim().isNotEmpty || _filter != 'all';
      final colors = Theme.of(context).colorScheme;
      return ui.CommonScaffold(
        title: _scope == 0 ? context.l10n.luaLibrary : context.l10n.steamGames,
        titleMenuItems: [
          ui.CommonPopupMenuItem(
            label: context.l10n.luaLibrary,
            glyph: ui.AppGlyphs.code,
            checked: _scope == 0,
            onPressed: () => _selectScope(0),
          ),
          ui.CommonPopupMenuItem(
            label: context.l10n.steamGames,
            glyph: ui.AppGlyphs.profiles,
            checked: _scope == 1,
            onPressed: () => _selectScope(1),
          ),
        ],
        isLoading: library.isScanning || _importing || _metadataBusy,
        searchState: _searchState,
        searchHint: context.l10n.searchGameNamesOrAppid,
        trailingAction: _moreMenu(scopeGames),
        actions: [
          const SupportAuthorButton(),
          ui.CommonPopupBox(
            key: const ValueKey('library-import-menu'),
            targetBuilder: (open) => ui.TonalButton(
              size: ui.TonalButtonSize.compact,
              glyph: ui.AppGlyphs.add,
              label: context.l10n.import,
              onPressed: _importing ? null : open,
            ),
            popupBuilder: (_) => ui.CommonPopupMenu(
              items: [
                ui.CommonPopupMenuItem(
                  label: context.l10n.importFilesOrArchives,
                  onPressed: () => _import(null),
                ),
                ui.CommonPopupMenuItem(
                  label: context.l10n.importFolder,
                  onPressed: _importFolder,
                ),
              ],
            ),
          ),
          _viewMenu(),
        ],
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (_selectionMode ||
                  library.warnings.isNotEmpty ||
                  _metadataErrors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: ui.pageContentTopInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectionMode) _bulkBar(games),
                      if (library.warnings.isNotEmpty ||
                          _metadataErrors.isNotEmpty) ...[
                        _warnings(library),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: DropTarget(
                  onDragEntered: (_) => setState(() => _dragging = true),
                  onDragExited: (_) => setState(() => _dragging = false),
                  onDragDone: (details) {
                    setState(() => _dragging = false);
                    if (library.steamPath != null) {
                      _import(details.files.map((file) => file.path).toList());
                    }
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ui.NullStatusSwitcher(
                          isLoading:
                              library.isScanning &&
                              scopeGames.isEmpty &&
                              !filtering,
                          isEmpty: games.isEmpty,
                          isSearching: filtering,
                          nullStatus: _emptyStatus(library),
                          searchStatus: ui.NullStatus(
                            label: context.l10n.noSearchResults,
                            illustration: ui.NullStatusIllustration.search,
                          ),
                          child: games.isEmpty
                              ? const SizedBox.expand()
                              : _content(
                                  games,
                                  topPadding:
                                      _selectionMode ||
                                          library.warnings.isNotEmpty ||
                                          _metadataErrors.isNotEmpty
                                      ? 0
                                      : ui.pageContentTopInset,
                                ),
                        ),
                      ),
                      if (_dragging)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primaryContainer.withValues(
                                  alpha: .95,
                                ),
                                border: Border.all(
                                  color: colors.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ui.GlyphIcon(
                                      ui.AppGlyphs.upload,
                                      size: 44,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      library.steamPath == null
                                          ? context.l10n.chooseASteamFolderFirst
                                          : context
                                                .l10n
                                                .dropToImportLuaManifestsOrArchives,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ],
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

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.settings,
    required this.detailBuilder,
    this.onFavorite,
    this.onTap,
    this.footer,
  });
  final GameEntry game;
  final SettingsStore settings;
  final Widget Function(GameEntry) detailBuilder;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => ui.OpenContainer(
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    openBuilder: (_) => detailBuilder(game),
    closedBuilder: (context, open) => ui.CommonCard(
      radius: 26,
      enterActionsOnRight: true,
      onPressed: onTap ?? open,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 146,
                height: 96,
                child: _GameImage(game: game, settings: settings),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ui.AppTextStyle.headline.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                      if (onFavorite != null)
                        IconButton(
                          onPressed: onFavorite,
                          tooltip: game.isFavorite
                              ? context.l10n.unfavorite
                              : context.l10n.favorite,
                          visualDensity: VisualDensity.compact,
                          icon: ui.GlyphIcon(
                            ui.AppGlyphs.star,
                            size: 18,
                            fill: game.isFavorite ? 1 : 0,
                            color: game.isFavorite
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 6,
                      children: [
                        if (game.isRunning)
                          ui.DashboardChip(
                            label: context.l10n.running,
                            tone: ui.DashboardChipTone.ok,
                            dot: true,
                          ),
                        if (game.isInstalled && !game.isRunning)
                          ui.DashboardChip(label: context.l10n.installed),
                        if (game.hasLua)
                          ui.DashboardChip(
                            label: game.luaEnabled
                                ? 'Lua'
                                : context.l10n.luaDisabled,
                            tone: game.luaEnabled
                                ? ui.DashboardChipTone.ok
                                : ui.DashboardChipTone.idle,
                          ),
                        if (game.versionPinned)
                          ui.DashboardChip(
                            label: context.l10n.versionPinned,
                            tone: ui.DashboardChipTone.ok,
                          ),
                        if (game.ownership == GameOwnership.owned)
                          ui.DashboardChip(
                            label: context.l10n.owned,
                            tone: ui.DashboardChipTone.ok,
                          ),
                      ],
                    ),
                  ),
                  if (footer != null) ...[const SizedBox(height: 4), footer!],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GameImage extends StatelessWidget {
  const _GameImage({required this.game, required this.settings});
  final GameEntry game;
  final SettingsStore settings;
  @override
  Widget build(BuildContext context) => NetworkCoverImage(
    settings: settings,
    appId: game.appId,
    url: game.imageUrl,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Center(
        child: ui.GlyphIcon(
          ui.AppGlyphs.photos,
          size: 36,
          color: Theme.of(
            context,
          ).colorScheme.onPrimaryContainer.withValues(alpha: .55),
        ),
      ),
    ),
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: ui.GlyphIcon(
                ui.AppGlyphs.photos,
                size: 30,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
  );
}
