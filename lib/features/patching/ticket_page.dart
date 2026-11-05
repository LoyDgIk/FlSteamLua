import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/steam_process_actions.dart';
import '../library/library_service.dart';
import '../library/lua_directories.dart';
import 'ticket_confirmation_sheet.dart';
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
    required this.settings,
    this.store,
    this.steamProcess,
    this.currentAccountReader,
    this.game,
    this.games = const [],
    this.initialTicket,
  });

  final AppPaths paths;
  final TaskCenter tasks;
  final SettingsStore settings;
  final TicketAuthorizationStore? store;
  final SteamProcessActions? steamProcess;
  final Future<String?> Function()? currentAccountReader;
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
  late final LibraryService _library;
  SteamProcessActions get _steam =>
      widget.steamProcess ?? _library.processActions;
  TicketApplyPlan? _plan;
  String? _currentAccount;
  String? _warning;
  List<TicketCredentialBackup> _credentialBackups = [];

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? TicketAuthorizationStore(paths: widget.paths);
    _library = LibraryService(paths: widget.paths, settings: widget.settings);
    _ticket = widget.initialTicket;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadSaved());
      if (_ticket case final ticket?) {
        unawaited(_refreshContext(ticket));
      }
    });
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await _store.list();
      final backups = await _store.credentialBackups();
      if (mounted) {
        setState(() {
          _saved = saved;
          _credentialBackups = backups;
        });
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, _errorText(error));
    }
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext task) action, {
    String? successMessage,
    bool announce = true,
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
      if (mounted && announce) {
        ui.showAppSuccess(context, successMessage ?? title);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, _errorText(error));
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

  @override
  void dispose() {
    _library.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    final texts = context.l10n;
    if (error is TicketLuaCleanupException) return texts.ticketLuaManualCleanup;
    return error is TicketOperationException
        ? switch (error.failure) {
            TicketOperationFailure.stalePreview => texts.ticketPreviewChanged,
            TicketOperationFailure.luaChanged => texts.ticketLuaChanged,
            TicketOperationFailure.invalidBackup => texts.ticketInvalidBackup,
            TicketOperationFailure.verification => texts.ticketWriteNotVerified,
            TicketOperationFailure.rollback => texts.ticketRollbackIncomplete,
            TicketOperationFailure.busy => texts.ticketOperationBusy,
          }
        : '$error';
  }

  Future<TicketApplyPlan> _readPlan(AuthorizationTicket ticket) async {
    final paths = <String>{};
    final explicit = _matchingGame(ticket.appId)?.luaPath;
    if (explicit != null) paths.add(explicit);
    if (widget.settings.steamPath.isNotEmpty) {
      for (final root in LuaDirectories(widget.settings.steamPath).loadOrder) {
        paths.add(p.join(root, '${ticket.appId}.lua'));
        paths.add(p.join(root, 'Disable', '${ticket.appId}.lua'));
      }
    }
    final existing = <String>[];
    for (final path in paths) {
      if (await File(path).exists()) existing.add(path);
    }
    final plan = await _store.prepare(ticket, luaPaths: existing);
    final current = widget.currentAccountReader != null
        ? await widget.currentAccountReader!()
        : await _steam.isRunning()
        ? WindowsTicketRegistry.activeSteamId()
        : null;
    if (mounted && _ticket?.appId == ticket.appId) {
      setState(() {
        _luaFound = existing.isNotEmpty;
        _plan = plan;
        _currentAccount = current;
        _warning = plan.before.identityMismatch(ticket.steamId)
            ? context.l10n.ticketCachedIdentityWarning
            : null;
      });
    }
    return plan;
  }

  Future<void> _refreshContext(AuthorizationTicket ticket) async {
    try {
      await _readPlan(ticket);
    } catch (error) {
      if (mounted) ui.showAppError(context, _errorText(error));
    }
  }

  Future<void> _refresh() async {
    await _loadSaved();
    if (_ticket case final ticket?) await _refreshContext(ticket);
  }

  Future<void> _setTicket(AuthorizationTicket ticket) async {
    if (!mounted) return;
    setState(() {
      _ticket = ticket;
      _luaFound = null;
      _plan = null;
      _warning = null;
    });
    await _readPlan(ticket);
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
    try {
      final plan = await _readPlan(ticket);
      final stopSteam = plan.lua.isNotEmpty && await _steam.isRunning();
      if (!mounted) return;
      final synchronize = await showTicketApplySheet(
        context,
        plan: plan,
        currentAccount: _currentAccount,
        stopSteam: stopSteam,
      );
      if (synchronize == null || !mounted) return;
      await _run(texts.applyTicket, (task) async {
        task.checkCancelled();
        if (stopSteam) await _steam.stop();
        final result = await _store.apply(
          ticket,
          synchronizeIdentity: synchronize,
          plan: plan,
        );
        await _refreshContext(ticket);
        await _loadSaved();
        if (!mounted) return;
        ui.showAppSuccess(context, texts.ticketWrittenVerified);
        if (result.identityMismatch) {
          ui.showAppFeedback(
            context,
            texts.ticketCachedIdentityWarning,
            level: ui.MessageLevel.warning,
          );
        }
      }, announce: false);
    } catch (error) {
      if (mounted) ui.showAppError(context, _errorText(error));
    }
  }

  Future<void> _restore(TicketCredentialBackup backup) async {
    final texts = context.l10n;
    try {
      final plan = await _store.prepareRestore(backup);
      final stopSteam = plan.lua.isNotEmpty && await _steam.isRunning();
      if (!mounted) return;
      final accepted = await showTicketRestoreSheet(
        context,
        plan: plan,
        gameName: _gameName(backup.appId),
        stopSteam: stopSteam,
      );
      if (accepted != true || !mounted) return;
      await _run(
        texts.restorePreApplyCredentials,
        (task) async {
          task.checkCancelled();
          if (stopSteam) await _steam.stop();
          await _store.restoreCredentials(plan);
          if (_ticket != null) await _refreshContext(_ticket!);
          await _loadSaved();
        },
        successMessage: texts.ticketCredentialsRestored,
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, _errorText(error));
    }
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
      if (mounted) ui.showAppError(context, _errorText(error));
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
      isLoading: _busy,
      actions: [
        ui.DashboardIconButton(
          tooltip: texts.importTicketsTxt,
          onPressed: _busy ? null : _import,
          glyph: ui.AppGlyphs.importFile,
        ),
        ui.DashboardIconButton(
          tooltip: texts.refresh,
          onPressed: _busy ? null : _refresh,
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
                    'AppID ${ticket.appId} · '
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
          if (ticket != null) ...[
            ui.generateSection(
              items: [
                ui.DecorationListItem(
                  title: Text(texts.currentSteamLoginAccount),
                  subtitle: Text(
                    _currentAccount ?? texts.ticketAccountUnavailable,
                  ),
                ),
                ui.DecorationListItem(
                  title: Text(texts.ticketOwnerAccount),
                  subtitle: Text(ticket.steamId.toString()),
                ),
                ui.DecorationListItem(
                  title: Text(texts.cachedAuthorizationIdentity),
                  subtitle: Text(
                    _plan == null
                        ? texts.ticketAccountUnavailable
                        : _plan!.before.steamId ?? texts.ticketIdentityNotSet,
                  ),
                ),
              ],
            ),
            if (_warning != null)
              ui.LogRecordCard(
                key: const ValueKey('ticket-identity-warning'),
                time: '',
                level: texts.ticketIdentityWarningLabel,
                message: _warning!,
                tone: ui.RecordTone.warning,
              ),
            if (_plan != null && _plan!.lua.isNotEmpty)
              ui.generateSection(
                title: texts.ticketLuaCleanup,
                items: [
                  for (final edit in _plan!.lua)
                    ui.DecorationListItem(
                      title: Text(p.basename(edit.path)),
                      subtitle: Text(
                        texts.ticketLuaRemovalCount(
                          edit.statements.length.toString(),
                        ),
                      ),
                    ),
                ],
              ),
          ],
          if (ticket != null)
            ui.generateSection(
              title: texts.ticketActions,
              items: [
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(
                    ui.AppGlyphs.checkCircle,
                    size: 20,
                  ),
                  key: const ValueKey('apply-ticket'),
                  title: Text(texts.applyTicketPreserveIdentity),
                  subtitle: Text(
                    texts
                        .thisReplacesExistingAppticketAndEticketValuesForThisGame,
                  ),
                  onPressed: _busy || _plan == null ? null : _apply,
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
          if (_credentialBackups.isNotEmpty)
            ui.generateSection(
              title: texts.restorePreApplyCredentials,
              items: [
                for (final backup in _credentialBackups)
                  ui.DecorationListItem(
                    key: ValueKey('restore-credentials-${backup.path}'),
                    title: Text(_gameName(backup.appId)),
                    subtitle: Text(backup.createdAt.toLocal().toString()),
                    onPressed: _busy ? null : () => _restore(backup),
                    trailing: const ui.GlyphIcon(ui.AppGlyphs.undo),
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
