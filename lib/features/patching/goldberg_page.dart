import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'emulator_service.dart';
import 'goldberg_config.dart';
import 'patching_service.dart';

class GoldbergPage extends StatefulWidget {
  const GoldbergPage({
    super.key,
    required this.paths,
    required this.settings,
    required this.tasks,
    required this.game,
  });

  final AppPaths paths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final GameEntry game;

  @override
  State<GoldbergPage> createState() => _GoldbergPageState();
}

class _GoldbergPageState extends State<GoldbergPage> {
  late final PatchingService _patching;
  late final GoldbergConfigService _goldberg;
  late final EmulatorService _emulator;
  GoldbergConfig _config = GoldbergConfig();
  String? _installedVersion;
  bool _busy = false;
  int _formRevision = 0;

  String get _directory => widget.game.installPath ?? '';

  @override
  void initState() {
    super.initState();
    _patching = PatchingService(paths: widget.paths, settings: widget.settings);
    _goldberg = GoldbergConfigService(_patching);
    _emulator = EmulatorService(paths: widget.paths, patching: _patching);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (_directory.isEmpty) {
      if (mounted) {
        ui.showAppError(
          context,
          FormatException(context.l10n.gameDirectoryUnavailable),
        );
      }
      return;
    }
    try {
      final loaded = await _goldberg.load(_directory);
      final version = await _emulator.installedVersion();
      if (!mounted) return;
      setState(() {
        _config = loaded.config;
        if (_config.appId.isEmpty) _config.appId = '${widget.game.appId}';
        _installedVersion = version;
        _formRevision++;
      });
      if (loaded.warnings.isNotEmpty && mounted) {
        ui.showAppFeedback(
          context,
          loaded.warnings.join('\n'),
          level: ui.MessageLevel.warning,
        );
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _run(
    String title,
    Future<void> Function(TaskContext task) action,
  ) async {
    setState(() {
      _busy = true;
    });
    try {
      await widget.tasks.run(title, action, appId: widget.game.appId);
      if (mounted) ui.showAppSuccess(context, title);
      await _load();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await ui.AppDialogs.confirm(context, title: title, message: message) ??
      false;

  Future<void> _download() async {
    final texts = context.l10n;
    setState(() {
      _busy = true;
    });
    try {
      final release = await _emulator.latestRelease();
      if (!mounted ||
          !await _confirm(
            texts.downloadEmulator,
            '${release.version}\n${release.filename}\n'
            '${(release.size / 1048576).toStringAsFixed(1)} MiB\n'
            '${release.url}',
          )) {
        return;
      }
      await widget.tasks.run(
        texts.downloadUpdateEmulator,
        (task) => _emulator.download(release, context: task),
        appId: widget.game.appId,
      );
      if (mounted) {
        ui.showAppSuccess(
          context,
          texts.currentEmulatorVersion(release.version),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deploy() async {
    final texts = context.l10n;
    if (_directory.isEmpty) {
      ui.showAppError(context, FormatException(texts.gameDirectoryUnavailable));
      return;
    }
    if (!await _confirm(
      texts.deployGoldberg,
      texts
          .replaceSteamApiDllsInThisGameDirectoryOriginalFilesWillBeSavedInApplicationBackups,
    )) {
      return;
    }
    await _run(texts.deployToThisGame, (task) async {
      await _emulator.deploy(_directory, context: task);
    });
  }

  Future<void> _save() =>
      _run(context.l10n.saveGoldbergConfiguration, (task) async {
        await _goldberg.save(_directory, _config, context: task);
      });

  Future<void> _editJson() async {
    final texts = context.l10n;
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert({
        'achievements': _config.achievements,
        'stats': _config.stats,
        'items': _config.items,
        'default_items': _config.defaultItems,
      }),
    );
    String? error;
    final value = await ui.showFormSheet<Map<String, dynamic>>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => ui.FormPage(
          title: texts.editJsonDefinitions,
          error: error,
          onSave: () {
            try {
              final decoded = jsonDecode(controller.text);
              if (decoded is! Map<String, dynamic> ||
                  decoded['achievements'] is! List ||
                  decoded['stats'] is! List ||
                  decoded['items'] is! Map<String, dynamic> ||
                  decoded['default_items'] is! Map<String, dynamic>) {
                throw const FormatException(
                  'Expected achievements/stats arrays and items/default_items objects',
                );
              }
              Navigator.pop(sheetContext, decoded);
            } catch (exception) {
              update(() => error = '$exception');
            }
          },
          children: [
            ui.generateSection(
              title: texts.achievementsStatsItemsJson,
              items: [
                ui.FormRow(
                  title: texts.jsonDefinitions,
                  trailing: SizedBox(
                    width: 360,
                    child: ui.FormRowTextField(
                      controller: controller,
                      maxLines: 14,
                      enabled: !_busy,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() {
      _config.achievements = value['achievements'] as List;
      _config.stats = value['stats'] as List;
      _config.items = value['items'] as Map<String, dynamic>;
      _config.defaultItems = value['default_items'] as Map<String, dynamic>;
    });
  }

  Future<void> _exportConfig() async {
    final texts = context.l10n;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: texts.exportConfiguration,
      fileName: 'steam_settings.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (path == null) return;
    await _run(
      texts.exportGoldbergConfiguration,
      (task) => _goldberg.exportZip(_directory, path),
    );
  }

  Future<void> _importConfig() async {
    final texts = context.l10n;
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = selected?.files.single.path;
    if (path == null ||
        !await _confirm(
          texts.importConfiguration,
          texts.existingConfigurationWillBeBackedUpBeforeReplacementContinue,
        )) {
      return;
    }
    await _run(
      texts.importGoldbergConfiguration,
      (task) => _goldberg.importZip(_directory, path, context: task),
    );
  }

  List<int> _parseIds(String value) => value
      .split(RegExp(r'[,\s]+'))
      .where((item) => item.isNotEmpty)
      .map(int.tryParse)
      .whereType<int>()
      .toList();

  List<String> _parseLines(String value) => value
      .split(RegExp(r'[,\n]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Widget _field(
    String value,
    ValueChanged<String> onChanged, {
    bool obscure = false,
  }) => SizedBox(
    width: 300,
    child: obscure
        ? ui.FormRowTextField(
            initialValue: value,
            obscureText: true,
            enabled: !_busy,
            onChanged: onChanged,
          )
        : ui.FormRowTextField(
            initialValue: value,
            enabled: !_busy,
            onChanged: onChanged,
          ),
  );

  Widget _switch(String title, bool value, ValueChanged<bool> changed) =>
      ui.FormRow(
        title: title,
        onPressed: _busy ? null : () => setState(() => changed(!value)),
        trailing: ui.CommonSwitch(
          value: value,
          onChanged: _busy ? null : changed,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    final configKey = ValueKey(_formRevision);
    return ui.CommonScaffold(
      title: texts.goldbergSettings,
      actions: [
        IconButton(
          tooltip: texts.saveConfiguration,
          onPressed: _busy || _directory.isEmpty ? null : _save,
          icon: const ui.GlyphIcon(ui.AppGlyphs.check),
        ),
        IconButton(
          tooltip: texts.refresh,
          onPressed: _busy ? null : _load,
          icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
        ),
      ],
      body: ListView(
        key: configKey,
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
            title: texts.goldbergEmulator,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(
                  ui.AppGlyphs.cloudDownload,
                  size: 20,
                ),
                title: Text(texts.downloadUpdateEmulator),
                subtitle: Text(
                  _installedVersion == null
                      ? texts.emulatorNotDownloaded
                      : texts.currentEmulatorVersion(_installedVersion!),
                ),
                onPressed: _busy ? null : _download,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.puzzle, size: 20),
                title: Text(texts.deployToThisGame),
                subtitle: Text(texts.goldbergDeployDescription),
                onPressed: _busy || _directory.isEmpty ? null : _deploy,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
            ],
            footer: texts.goldbergDescription,
          ),
          ui.generateSection(
            title: texts.connectionAndIdentity,
            items: [
              ui.FormRow(
                title: 'AppID',
                trailing: _field(_config.appId, (v) => _config.appId = v),
              ),
              ui.FormRow(
                title: texts.accountName,
                trailing: _field(
                  _config.accountName,
                  (v) => _config.accountName = v,
                ),
              ),
              ui.FormRow(
                title: texts.steamId,
                trailing: _field(_config.steamId, (v) => _config.steamId = v),
              ),
              ui.FormRow(
                title: texts.applicationTicketBase64,
                trailing: _field(
                  _config.ticket,
                  (v) => _config.ticket = v,
                  obscure: true,
                ),
              ),
              ui.FormRow(
                title: texts.languageCode,
                trailing: _field(_config.language, (v) => _config.language = v),
              ),
              ui.FormRow(
                title: texts.listenPort,
                trailing: _field(
                  '${_config.listenPort}',
                  (v) => _config.listenPort = int.tryParse(v) ?? 0,
                ),
              ),
              ui.FormRow(
                title: texts.localSavePath,
                trailing: _field(
                  _config.localSavePath,
                  (v) => _config.localSavePath = v,
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: texts.contentConfiguration,
            items: [
              ui.FormRow(
                title: texts.dlcIds,
                trailing: _field(
                  _config.dlcIds.join(', '),
                  (v) => _config.dlcIds = _parseIds(v),
                ),
              ),
              ui.FormRow(
                title: texts.depotIds,
                trailing: _field(
                  _config.depotIds.join(', '),
                  (v) => _config.depotIds = _parseIds(v),
                ),
              ),
              ui.FormRow(
                title: texts.supportedLanguages,
                trailing: _field(
                  _config.languages.join(', '),
                  (v) => _config.languages = _parseLines(v),
                ),
              ),
              ui.FormRow(
                title: texts.steamInterfaces,
                trailing: _field(
                  _config.interfaces.join(', '),
                  (v) => _config.interfaces = _parseLines(v),
                ),
              ),
              ui.FormRow(
                title: texts.customBroadcasts,
                trailing: _field(
                  _config.broadcasts,
                  (v) => _config.broadcasts = v,
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: texts.behavior,
            items: [
              _switch(
                texts.disableNetworking,
                _config.disableNetworking,
                (v) => _config.disableNetworking = v,
              ),
              _switch(
                texts.offlineMode,
                _config.offline,
                (v) => _config.offline = v,
              ),
              _switch(
                texts.allDlc,
                _config.unlockAllDlc,
                (v) => _config.unlockAllDlc = v,
              ),
              _switch(
                texts.steamInput,
                _config.steamInput,
                (v) => _config.steamInput = v,
              ),
              _switch(
                texts.emulatedCloudSaves,
                _config.cloudSaves,
                (v) => _config.cloudSaves = v,
              ),
              _switch(
                texts.createCloudDirectory,
                _config.createCloudDirectory,
                (v) => _config.createCloudDirectory = v,
              ),
              _switch(
                texts.experimentalOverlay,
                _config.overlay,
                (v) => _config.overlay = v,
              ),
            ],
          ),
          ui.generateSection(
            title: texts.configurationActions,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.code, size: 20),
                title: Text(texts.achievementsStatsItemsJson),
                onPressed: _busy ? null : _editJson,
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.export, size: 20),
                title: Text(texts.exportZip),
                onPressed: _busy || _directory.isEmpty ? null : _exportConfig,
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.importFile, size: 20),
                title: Text(texts.importConfigurationZip),
                onPressed: _busy || _directory.isEmpty ? null : _importConfig,
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.refresh, size: 20),
                title: Text(texts.reload2),
                onPressed: _busy ? null : _load,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emulator.close();
    super.dispose();
  }
}
