import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../achievements/achievement_service.dart';
import '../patching/ticket_authorization.dart';
import '../patching/ticket_page.dart';
import '../steam_protocol/steam_protocol_service.dart';

typedef _ExtractionLog = ({DateTime at, String level, String message});

class LuaExtractionPage extends StatefulWidget {
  const LuaExtractionPage({
    super.key,
    required this.paths,
    required this.settings,
    required this.tasks,
    required this.steam,
    this.game,
  });

  final AppPaths paths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final SteamProtocolService steam;
  final GameEntry? game;

  @override
  State<LuaExtractionPage> createState() => _LuaExtractionPageState();
}

class _LuaExtractionPageState extends State<LuaExtractionPage> {
  late final TextEditingController _appId;
  final List<_ExtractionLog> _logs = [];
  String? _output;
  SteamExtractionResult? _result;
  bool _busy = false;
  bool _includeDlc = true;
  bool _downloadManifests = true;
  bool _pinManifests = false;
  bool _copyAchievements = true;

  @override
  void initState() {
    super.initState();
    _appId = TextEditingController(text: widget.game?.appId.toString() ?? '');
  }

  @override
  void dispose() {
    _appId.dispose();
    super.dispose();
  }

  void _log(String level, String message) {
    _logs.add((at: DateTime.now(), level: level, message: message));
  }

  Future<void> _selectOutput() async {
    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: context.l10n.chooseOutputFolder,
    );
    if (folder != null && mounted) setState(() => _output = folder);
  }

  Future<void> _extract() async {
    final texts = context.l10n;
    final id = int.tryParse(_appId.text.trim());
    if (id == null || id <= 0) {
      ui.showAppError(context, FormatException(texts.enterAValidAppid));
      return;
    }
    final output =
        _output ?? widget.paths.file(p.join('downloads', 'lua', '$id'));
    setState(() {
      _busy = true;
      _result = null;
      _logs.clear();
    });
    try {
      final result = await widget.tasks.run(texts.extractLua, (task) async {
        if (!widget.steam.isLoggedOn) {
          final local = await widget.steam.restoreLocalSession(task: task);
          if (!local && !widget.steam.hasSavedSession) {
            throw StateError(texts.steamLoginRequired);
          }
          if (!local) await widget.steam.restoreSession();
        }
        task.checkCancelled();
        if (widget.settings.steamPath.isEmpty) {
          throw StateError(texts.selectTheSteamFolderFirst);
        }
        task.report(texts.extractingLua('$id'));
        return widget.steam.extractApp(
          id,
          output,
          task: task,
          includeDlc: _includeDlc,
          downloadManifests: _downloadManifests,
          pinManifests: _pinManifests,
          copyAchievements: _copyAchievements,
        );
      }, appId: id);
      if (!mounted) return;
      setState(() {
        _result = result;
        _log(
          'success',
          texts.luaExtractionComplete(
            '${result.keyCount}',
            '${result.manifests.length}',
          ),
        );
      });
      ui.showAppSuccess(
        context,
        texts.luaExtractionComplete(
          '${result.keyCount}',
          '${result.manifests.length}',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyError(error, texts);
      setState(() => _log('error', message));
      ui.showAppError(context, FormatException(message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openResult() async {
    final path = _result == null ? _output : p.dirname(_result!.luaFile);
    if (path == null) return;
    if (!await Directory(path).exists()) {
      if (mounted) {
        ui.showAppError(
          context,
          FormatException(context.l10n.outputDirectoryDoesNotExist),
        );
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [
        path,
      ], mode: ProcessStartMode.detached);
    }
  }

  String _friendlyError(Object error, AppLocalizations texts) {
    final value = '$error';
    if (value.contains('Steam session') ||
        value.contains('Steam pipe') ||
        value.contains('steamclient64.dll') ||
        value.contains('signed-in Steam user')) {
      return texts.steamMustBeRunningAndSignedIn;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    return ui.CommonScaffold(
      title: texts.luaExtraction,
      isLoading: _busy,
      actions: [
        IconButton(
          tooltip: texts.extractLua,
          onPressed: _busy ? null : _extract,
          icon: const ui.GlyphIcon(ui.AppGlyphs.export),
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
          ui.CommonNotice(
            message: texts.realOwnershipRequiredNotice,
            level: ui.MessageLevel.warning,
          ),
          const SizedBox(height: 12),
          ui.CommonCard(
            inert: true,
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ui.GlyphIcon(ui.AppGlyphs.account, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.steam.isLoggedOn
                                ? (widget.steam.currentAccountName ??
                                      texts.connectedToSteam)
                                : texts.notSignedIn,
                            style: ui.AppTextStyle.headline.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                          Text(
                            widget.steam.isLoggedOn
                                ? texts.connectedToSteam
                                : texts.luaLoginDescription,
                            style: ui.AppTextStyle.caption1
                                .of(context)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    ui.MetaChip(
                      label: widget.steam.isLoggedOn
                          ? texts.connectedToSteam
                          : texts.notSignedIn,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  texts.appIdForExtraction,
                  style: ui.AppTextStyle.subheadline.of(
                    context,
                    emphasized: true,
                  ),
                ),
                const SizedBox(height: 6),
                ui.FilledInputTheme(
                  borderRadius: ui.AppRadius.lg,
                  child: TextField(
                    controller: _appId,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'AppID'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const ui.GlyphIcon(ui.AppGlyphs.resources, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            texts.outputDirectory,
                            style: ui.AppTextStyle.subheadline.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                          Text(
                            _output ?? texts.useDefaultOutputDirectory,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ui.AppTextStyle.caption1
                                .of(context)
                                .copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    ui.TonalButton(
                      size: ui.TonalButtonSize.compact,
                      glyph: ui.AppGlyphs.resources,
                      label: texts.chooseOutputFolder,
                      onPressed: _busy ? null : _selectOutput,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  texts.extractionOptions,
                  style: ui.AppTextStyle.subheadline.of(
                    context,
                    emphasized: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _option(
                      texts.includeAccessibleDlc,
                      _includeDlc,
                      (value) => setState(() => _includeDlc = value),
                    ),
                    _option(
                      texts.downloadManifestFiles,
                      _downloadManifests,
                      (value) => setState(() => _downloadManifests = value),
                    ),
                    _option(
                      texts.pinCurrentPublicManifestVersions,
                      _pinManifests,
                      (value) => setState(() => _pinManifests = value),
                    ),
                    _option(
                      texts.copyAchievements,
                      _copyAchievements,
                      (value) => setState(() => _copyAchievements = value),
                    ),
                    ui.ListFooter(text: texts.copyAchievementsHint),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ui.TonalButton(
                    glyph: ui.AppGlyphs.export,
                    label: texts.extractLua,
                    onPressed: _busy ? null : _extract,
                  ),
                ),
              ],
            ),
          ),
          if (_result case final result?) ...[
            const SizedBox(height: 12),
            ui.CommonCard(
              inert: true,
              radius: 22,
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
                          p.basename(result.luaFile),
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
                  Text(
                    texts.luaExtractionComplete(
                      '${result.keyCount}',
                      '${result.manifests.length}',
                    ),
                    style: ui.AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                  if (result.warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      result.warnings.join('\n'),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: ui.AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: context.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                        : ui.RecordTone.neutral,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _option(String title, bool value, ValueChanged<bool> changed) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title),
      const SizedBox(width: 6),
      ui.CommonSwitch(value: value, onChanged: _busy ? null : changed),
    ],
  );
}

class DenuvoExtractionPage extends StatefulWidget {
  const DenuvoExtractionPage({
    super.key,
    required this.paths,
    required this.settings,
    required this.tasks,
    required this.achievements,
    this.game,
    this.games = const [],
  });

  final AppPaths paths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final AchievementService achievements;
  final GameEntry? game;
  final List<GameEntry> games;

  @override
  State<DenuvoExtractionPage> createState() => _DenuvoExtractionPageState();
}

class _DenuvoExtractionPageState extends State<DenuvoExtractionPage> {
  late final TextEditingController _appId;
  late final TicketAuthorizationStore _tickets;
  final List<_ExtractionLog> _logs = [];
  String? _resultFile;
  AuthorizationTicket? _resultTicket;
  bool _busy = false;
  bool _saveEncrypted = true;

  @override
  void initState() {
    super.initState();
    _appId = TextEditingController(text: widget.game?.appId.toString() ?? '');
    _tickets = TicketAuthorizationStore(paths: widget.paths);
  }

  @override
  void dispose() {
    _appId.dispose();
    super.dispose();
  }

  void _log(String level, String message) {
    _logs.add((at: DateTime.now(), level: level, message: message));
  }

  Future<void> _extract() async {
    final texts = context.l10n;
    final id = int.tryParse(_appId.text.trim());
    if (id == null || id <= 0) {
      ui.showAppError(context, FormatException(texts.enterAValidAppid));
      return;
    }
    if (widget.settings.steamPath.isEmpty) {
      ui.showAppError(
        context,
        FormatException(texts.selectTheSteamFolderFirst),
      );
      return;
    }
    setState(() {
      _busy = true;
      _resultFile = null;
      _resultTicket = null;
      _logs.clear();
    });
    try {
      final result = await widget.tasks.run(texts.extractDenuvoTicket, (
        task,
      ) async {
        final tickets = await widget.achievements.extractTickets(
          appId: id,
          steamPath: widget.settings.steamPath,
        );
        task.checkCancelled();
        final ticket = AuthorizationTicket(
          appId: id,
          steamId: BigInt.parse(tickets.steamId),
          appTicket: base64Decode(tickets.appTicketBase64),
          eTicket: base64Decode(tickets.encryptedTicketBase64),
        );
        final file = File(
          widget.paths.file(p.join('cache', 'denuvo', '$id', 'tickets.txt')),
        );
        await file.parent.create(recursive: true);
        await file.writeAsString(ticket.exportText(), flush: true);
        if (_saveEncrypted) await _tickets.save(ticket);
        return (path: file.path, ticket: ticket);
      }, appId: id);
      if (!mounted) return;
      setState(() {
        _resultFile = result.path;
        _resultTicket = result.ticket;
        _log('success', texts.ticketExtractionComplete(result.path));
      });
      ui.showAppFeedback(
        context,
        texts.ticketExtractionComplete(result.path),
        level: ui.MessageLevel.success,
        actionState: ui.MessageActionState(
          actionText: texts.reviewExtractedTickets,
          action: _openTicketPage,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyError(error, texts);
      setState(() => _log('error', message));
      ui.showAppError(context, FormatException(message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openResult() async {
    final path = _resultFile;
    if (path == null) return;
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [
        p.dirname(path),
      ], mode: ProcessStartMode.detached);
    }
  }

  Future<void> _openTicketPage() async {
    final id = _resultTicket?.appId ?? int.tryParse(_appId.text.trim());
    final games = [...widget.games];
    if (widget.game case final game?) {
      if (!games.any((entry) => entry.appId == game.appId)) games.add(game);
    }
    final game =
        (widget.game?.appId == id ? widget.game : null) ??
        (id == null || id <= 0
            ? null
            : games.where((entry) => entry.appId == id).firstOrNull ??
                  GameEntry(appId: id, name: 'AppID $id'));
    await Navigator.of(context).push(
      ui.buildAppPageRoute(
        builder: (_) => TicketPage(
          settings: widget.settings,
          paths: widget.paths,
          tasks: widget.tasks,
          game: game,
          games: games,
          initialTicket: _resultTicket,
        ),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  String _friendlyError(Object error, AppLocalizations texts) {
    final value = '$error';
    if (value.contains('Steam session') ||
        value.contains('Steam pipe') ||
        value.contains('steamclient64.dll') ||
        value.contains('signed-in Steam user')) {
      return texts.steamMustBeRunningAndSignedIn;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    return ui.CommonScaffold(
      title: texts.denuvoTicketExtraction,
      isLoading: _busy,
      actions: [
        IconButton(
          tooltip: texts.openAuthorizationPage,
          onPressed: _busy ? null : _openTicketPage,
          icon: const ui.GlyphIcon(ui.AppGlyphs.layers),
        ),
        IconButton(
          tooltip: texts.extractDenuvoTicket,
          onPressed: _busy ? null : _extract,
          icon: const ui.GlyphIcon(ui.AppGlyphs.key),
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
          ui.CommonNotice(
            message: texts.realOwnershipRequiredNotice,
            level: ui.MessageLevel.warning,
          ),
          const SizedBox(height: 12),
          ui.CommonCard(
            inert: true,
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts.appIdForExtraction,
                  style: ui.AppTextStyle.subheadline.of(
                    context,
                    emphasized: true,
                  ),
                ),
                const SizedBox(height: 6),
                ui.FilledInputTheme(
                  borderRadius: ui.AppRadius.lg,
                  child: TextField(
                    controller: _appId,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'AppID'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const ui.GlyphIcon(ui.AppGlyphs.key, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        texts.denuvoTicketExtractionDescription,
                        style: ui.AppTextStyle.caption1
                            .of(context)
                            .copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(texts.saveTicketBackup),
                    const Spacer(),
                    ui.CommonSwitch(
                      value: _saveEncrypted,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _saveEncrypted = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ui.TonalButton(
                    glyph: ui.AppGlyphs.cloudDownload,
                    label: texts.extractDenuvoTicket,
                    onPressed: _busy ? null : _extract,
                  ),
                ),
              ],
            ),
          ),
          if (_resultFile case final file?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ui.CommonCard(
                inert: true,
                radius: 22,
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
                            p.basename(file),
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
                    const SizedBox(height: 12),
                    ui.TonalButton(
                      key: const ValueKey('review-extracted-ticket'),
                      glyph: ui.AppGlyphs.key,
                      label: texts.reviewExtractedTickets,
                      onPressed: _openTicketPage,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      file,
                      style: ui.AppTextStyle.caption1
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ui.TonalButton(
                        size: ui.TonalButtonSize.compact,
                        glyph: ui.AppGlyphs.key,
                        label: texts.openAuthorizationPage,
                        onPressed: _busy ? null : _openTicketPage,
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
                        : ui.RecordTone.neutral,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
