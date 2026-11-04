import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'ticket_authorization.dart';

class TicketPage extends StatefulWidget {
  const TicketPage({
    super.key,
    required this.paths,
    required this.tasks,
    this.game,
    this.games = const [],
    this.initialTicket,
  });

  final AppPaths paths;
  final TaskCenter tasks;
  final GameEntry? game;
  final List<GameEntry> games;
  final AuthorizationTicket? initialTicket;

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  late final TicketAuthorizationStore _store;
  AuthorizationTicket? _ticket;
  List<int> _saved = const [];
  bool? _luaFound;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store = TicketAuthorizationStore(paths: widget.paths);
    _ticket = widget.initialTicket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadSaved());
      if (_ticket case final ticket?) {
        unawaited(_checkLua(ticket.appId));
      }
    });
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await _store.list();
      if (mounted) setState(() => _saved = saved);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext task) action, {
    String? successMessage,
  }) async {
    setState(() {
      _busy = true;
    });
    try {
      await widget.tasks.run(
        title,
        action,
        appId: _ticket?.appId ?? widget.game?.appId,
      );
      if (mounted) ui.showAppSuccess(context, successMessage ?? title);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await ui.AppDialogs.confirm(context, title: title, message: message) ??
      false;

  GameEntry? _matchingGame(int appId) =>
      widget.games.where((game) => game.appId == appId).firstOrNull ??
      (widget.game?.appId == appId ? widget.game : null);

  String _gameName(int appId) => _matchingGame(appId)?.name ?? 'AppID $appId';

  Future<bool> _checkLua(int appId) async {
    final path = _matchingGame(appId)?.luaPath;
    final exists = path != null && await File(path).exists();
    if (mounted && _ticket?.appId == appId) {
      setState(() => _luaFound = exists);
    }
    return exists;
  }

  Future<void> _setTicket(AuthorizationTicket ticket) async {
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _luaFound = null;
      });
    }
    await _checkLua(ticket.appId);
  }

  Future<void> _import() async {
    final texts = context.l10n;
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    final path = selected?.files.single.path;
    if (path == null) return;
    await _run(texts.validateTicketFile, (task) async {
      final file = File(path);
      if (await file.length() > 2 * 1024 * 1024) {
        throw const FormatException('Ticket file exceeds 2 MiB');
      }
      task.checkCancelled();
      final ticket = AuthorizationTicket.parse(await file.readAsString());
      await _setTicket(ticket);
    });
  }

  Future<void> _apply() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final texts = context.l10n;
    if (!await _confirm(
      texts.applySteamTicket,
      'AppID ${ticket.appId}\nSteamID ${ticket.steamId}\n'
      '${texts.thisReplacesExistingAppticketAndEticketValuesForThisGame}',
    )) {
      return;
    }
    final luaFound = await _checkLua(ticket.appId);
    await _run(
      texts.applyTicket,
      (task) async {
        task.checkCancelled();
        _store.apply(ticket);
      },
      successMessage:
          '${texts.applyTicket} · ${luaFound ? texts.matchingLuaFound : texts.matchingLuaMissing}',
    );
  }

  Future<void> _saveBackup() async {
    final ticket = _ticket;
    if (ticket == null) return;
    await _run(context.l10n.saveTicketBackup, (task) => _store.save(ticket));
    await _loadSaved();
  }

  Future<void> _export() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final texts = context.l10n;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: texts.exportPlaintextTicket,
      fileName: 'tickets.txt',
    );
    if (path == null) return;
    await _run(texts.exportTicket, (task) async {
      task.checkCancelled();
      await File(path).writeAsString(ticket.exportText(), flush: true);
    });
  }

  Future<void> _loadSavedTicket(int appId) async {
    try {
      final ticket = await _store.load(appId);
      await _setTicket(ticket);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _deleteSavedTicket(int appId) async {
    final texts = context.l10n;
    if (!await _confirm(texts.deleteTicketBackup, 'AppID $appId')) return;
    await _run(texts.deleteTicketBackup, (task) async {
      task.checkCancelled();
      await _store.delete(appId);
    });
    await _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    final ticket = _ticket;
    final game = ticket == null ? null : _matchingGame(ticket.appId);
    return ui.CommonScaffold(
      title: texts.authorizationTickets,
      actions: [
        ui.DashboardIconButton(
          tooltip: texts.importTicketsTxt,
          onPressed: _busy ? null : _import,
          glyph: ui.AppGlyphs.importFile,
        ),
        ui.DashboardIconButton(
          tooltip: texts.refresh,
          onPressed: _busy ? null : _loadSaved,
          glyph: ui.AppGlyphs.refresh,
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
          if (_busy)
            ui.CommonCard(
              inert: true,
              padding: const EdgeInsets.all(14),
              child: const ui.CommonProgressBar(value: null),
            ),
          ui.generateSection(
            title: texts.authorizationTickets,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.importFile, size: 20),
                title: Text(texts.importTicketsTxt),
                subtitle: Text(texts.authorizationTicketDescription),
                onPressed: _busy ? null : _import,
              ),
              if (ticket != null)
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.key, size: 20),
                  title: Text(_gameName(ticket.appId)),
                  subtitle: Text(
                    'AppID ${ticket.appId} · SteamID ${ticket.steamId} · '
                    'AppTicket ${ticket.appTicket.length} bytes · '
                    'ETicket ${ticket.eTicket.length} bytes',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ui.MetaChip(label: texts.load),
                ),
              if (ticket != null && _luaFound != null)
                ui.DecorationListItem(
                  leading: ui.GlyphIcon(
                    _luaFound! ? ui.AppGlyphs.checkCircle : ui.AppGlyphs.code,
                    size: 20,
                  ),
                  title: Text(texts.matchingLua),
                  subtitle: Text(
                    _luaFound!
                        ? '${texts.matchingLuaFound}${game?.luaPath == null ? '' : '\n${game!.luaPath}'}'
                        : texts.matchingLuaMissing,
                  ),
                ),
            ],
          ),
          if (ticket != null)
            ui.generateSection(
              title: texts.ticketActions,
              items: [
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(
                    ui.AppGlyphs.checkCircle,
                    size: 20,
                  ),
                  title: Text(texts.applySteamTicket),
                  subtitle: Text(
                    texts
                        .thisReplacesExistingAppticketAndEticketValuesForThisGame,
                  ),
                  onPressed: _busy ? null : _apply,
                ),
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.cloudSync, size: 20),
                  title: Text(texts.saveTicketBackup),
                  onPressed: _busy ? null : _saveBackup,
                ),
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.export, size: 20),
                  title: Text(texts.exportPlaintextFile),
                  onPressed: _busy ? null : _export,
                ),
              ],
            ),
          if (_saved.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: ui.NullStatus(
                label: texts.noSavedTickets,
                illustration: ui.NullStatusIllustration.data,
              ),
            )
          else
            ui.generateSection(
              title: texts.encryptedBackups,
              items: [
                for (final appId in _saved)
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.key, size: 20),
                    title: Text(_gameName(appId)),
                    subtitle: Text('AppID $appId'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: texts.loadTicket,
                          onPressed: _busy
                              ? null
                              : () => _loadSavedTicket(appId),
                          icon: const ui.GlyphIcon(
                            ui.AppGlyphs.openExternal,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: texts.deleteEncryptedBackup,
                          onPressed: _busy
                              ? null
                              : () => _deleteSavedTicket(appId),
                          icon: const ui.GlyphIcon(
                            ui.AppGlyphs.delete,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
