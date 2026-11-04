import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/task_center.dart';
import '../../ui/context.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'content_import_service.dart';
import 'content_resolver.dart';
import 'content_source_registry.dart';
import 'content_sources_page.dart';

class ContentImportDlcOption {
  const ContentImportDlcOption({required this.appId, required this.name});

  final int appId;
  final String name;
}

Future<ContentImportResult?> showContentImportDialog(
  BuildContext context, {
  required ContentSourceRegistry registry,
  required ContentResolver resolver,
  required ContentImportService importer,
  required TaskCenter tasks,
  required int appId,
  required String gameName,
  List<ContentImportDlcOption> dlcOptions = const [],
}) => ui.showFormSheet<ContentImportResult>(
  context: context,
  builder: (_) => ContentImportDialog(
    registry: registry,
    resolver: resolver,
    importer: importer,
    tasks: tasks,
    appId: appId,
    gameName: gameName,
    dlcOptions: dlcOptions,
  ),
);

class ContentImportDialog extends StatefulWidget {
  const ContentImportDialog({
    super.key,
    required this.registry,
    required this.resolver,
    required this.importer,
    required this.tasks,
    required this.appId,
    required this.gameName,
    this.dlcOptions = const [],
  });
  final ContentSourceRegistry registry;
  final ContentResolver resolver;
  final ContentImportService importer;
  final TaskCenter tasks;
  final int appId;
  final String gameName;
  final List<ContentImportDlcOption> dlcOptions;

  @override
  State<ContentImportDialog> createState() => _ContentImportDialogState();
}

class _ContentImportDialogState extends State<ContentImportDialog> {
  String? _luaSource;
  String? _manifestSource;
  bool _manifestExplicit = false;
  final _selectedDlcIds = <int>{};
  bool _pinManifests = false;
  bool _refreshMetadata = true;
  bool _overwrite = false;
  bool _busy = true;
  String? _error;
  String? _taskId;
  ContentImportPreview? _preview;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.registry.initialize();
      final luaSources = widget.registry.sources
          .where(
            (source) =>
                source.enabled &&
                source.capabilities.contains(ContentCapability.lua),
          )
          .toList();
      final manifestSources = widget.registry.sources
          .where((source) => source.enabled && source.providesManifests)
          .toList();
      final remembered = widget.registry.importSelection();
      final rememberedLua = luaSources
          .where((source) => source.id == remembered?.luaSourceId)
          .firstOrNull;
      var manifestSource = manifestSources
          .where((source) => source.id == remembered?.manifestSourceId)
          .firstOrNull
          ?.id;
      final manifestExplicit = remembered?.manifestExplicit ?? false;
      if (!manifestExplicit) {
        manifestSource = rememberedLua?.providesManifests == true
            ? rememberedLua!.id
            : null;
      }
      if (!mounted) return;
      setState(() {
        _luaSource = rememberedLua?.id;
        _manifestSource = manifestSource;
        _manifestExplicit = manifestExplicit;
        _busy = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    _preview = null;
    _overwrite = false;
    _error = null;
  });

  void _rememberSelection() {
    unawaited(
      widget.registry.rememberImportSelection(
        ContentImportSelection(
          luaSourceId: _luaSource,
          manifestSourceId: _manifestSource,
          manifestExplicit: _manifestExplicit,
        ),
      ),
    );
  }

  bool get _allDlcSelected =>
      widget.dlcOptions.isNotEmpty &&
      _selectedDlcIds.length == widget.dlcOptions.length;

  void _toggleAllDlc() {
    setState(() {
      if (_allDlcSelected) {
        _selectedDlcIds.clear();
      } else {
        _selectedDlcIds.addAll(widget.dlcOptions.map((option) => option.appId));
      }
      _preview = null;
      _overwrite = false;
      _error = null;
    });
  }

  void _toggleDlc(int appId) {
    setState(() {
      if (!_selectedDlcIds.add(appId)) {
        _selectedDlcIds.remove(appId);
      }
      _preview = null;
      _overwrite = false;
      _error = null;
    });
  }

  Future<void> _prepare() async {
    final sourceId = _luaSource;
    if (sourceId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final preview = await widget.tasks.run(context.l10n.previewContent, (
        task,
      ) async {
        _taskId = task.task.id;
        final bundle = await widget.resolver.resolve(
          widget.appId,
          ContentPlan(
            luaSourceId: sourceId,
            manifestSourceId: _manifestSource,
            dlcIds: Set.unmodifiable(_selectedDlcIds),
          ),
          pinManifests: _pinManifests,
          refreshMetadata: _refreshMetadata,
          task: task,
        );
        task.checkCancelled();
        return widget.importer.preview(bundle);
      }, appId: widget.appId);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _taskId = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.tasks.run(context.l10n.importContent, (
        task,
      ) async {
        _taskId = task.task.id;
        return widget.importer.commit(
          preview,
          overwrite: _overwrite,
          task: task,
        );
      }, appId: widget.appId);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _taskId = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.registry,
    builder: (context, _) {
      final luaSources = widget.registry.sources
          .where(
            (s) => s.enabled && s.capabilities.contains(ContentCapability.lua),
          )
          .toList();
      final manifestSources = widget.registry.sources
          .where((s) => s.enabled && s.providesManifests)
          .toList();
      final selectedLua = luaSources
          .where((s) => s.id == _luaSource)
          .firstOrNull;
      final preview = _preview;
      final canSave =
          !_busy &&
          selectedLua != null &&
          (preview == null || !preview.hasConflicts || _overwrite);
      return ui.FormPage(
        title: context.l10n.contentImport,
        onSave: preview == null ? _prepare : _commit,
        saveLabel: preview == null
            ? context.l10n.previewContent
            : context.l10n.importContent,
        saving: _busy,
        canSave: canSave,
        error: _error,
        onCancel: () {
          final id = _taskId;
          if (_busy && id != null) {
            widget.tasks.cancel(id);
          } else {
            Navigator.of(context).pop();
          }
        },
        children: [
          ui.generateSection(
            title: context.l10n.game,
            items: [
              ui.FormRow(
                title: context.l10n.game,
                trailing: Text(widget.gameName),
              ),
              ui.FormRow(title: 'AppID', trailing: Text('${widget.appId}')),
            ],
          ),
          if (luaSources.isEmpty && !_busy)
            ui.ListFooter(text: context.l10n.contentImportNoLuaSource),
          ui.generateSection(
            title: context.l10n.contentSources,
            items: [
              ui.FormRowSelect<String>(
                key: const ValueKey('content-import-lua-source'),
                title: context.l10n.luaContentSource,
                value: selectedLua?.id,
                options: [
                  for (final source in luaSources) (source.id, source.name),
                ],
                enabled: !_busy,
                onChanged: (value) {
                  _changed(() {
                    _luaSource = value;
                    if (!_manifestExplicit) {
                      final source = luaSources.firstWhere(
                        (source) => source.id == value,
                      );
                      _manifestSource = source.providesManifests
                          ? source.id
                          : null;
                    }
                  });
                  _rememberSelection();
                },
              ),
              ui.FormRowSelect<String>(
                key: const ValueKey('content-import-manifest-source'),
                title: context.l10n.manifestContentSource,
                value: _manifestSource ?? '',
                options: [
                  ('', context.l10n.noManifestSource),
                  for (final source in manifestSources)
                    (source.id, source.name),
                ],
                enabled: !_busy,
                onChanged: (value) {
                  _changed(() {
                    _manifestSource = value == '' ? null : value;
                    _manifestExplicit = true;
                  });
                  _rememberSelection();
                },
              ),
            ],
          ),
          if (widget.dlcOptions.isNotEmpty &&
              selectedLua?.kind == ContentSourceKind.subscription)
            ui.generateSection(
              title: context.l10n.includeDlc,
              items: [
                ui.FormRow(
                  key: const ValueKey('content-import-dlc-all'),
                  title: context.l10n.selectAll,
                  onPressed: _busy ? null : _toggleAllDlc,
                  trailing: ui.CommonCheckBox(
                    value: _allDlcSelected,
                    isCircle: true,
                    onChanged: _busy ? null : (_) => _toggleAllDlc(),
                  ),
                ),
                for (final option in widget.dlcOptions)
                  ui.FormRow(
                    key: ValueKey('content-import-dlc-${option.appId}'),
                    title: option.name,
                    onPressed: _busy ? null : () => _toggleDlc(option.appId),
                    trailing: ui.CommonCheckBox(
                      value: _selectedDlcIds.contains(option.appId),
                      isCircle: true,
                      onChanged: _busy ? null : (_) => _toggleDlc(option.appId),
                    ),
                  ),
              ],
            ),
          ui.generateSection(
            title: context.l10n.advanced,
            items: [
              ui.FormRowSwitch(
                title: context.l10n.pinManifestVersions,
                value: _pinManifests,
                onChanged: _busy
                    ? null
                    : (value) => _changed(() => _pinManifests = value),
              ),
              if (selectedLua?.kind == ContentSourceKind.subscription)
                ui.FormRowSwitch(
                  title: context.l10n.refreshContentMetadata,
                  value: _refreshMetadata,
                  onChanged: _busy
                      ? null
                      : (value) => _changed(() => _refreshMetadata = value),
                ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.settings),
                title: Text(context.l10n.configureContentSources),
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                        ui.buildAppPageRoute<void>(
                          builder: (_) => ContentSourcesPage(
                            registry: widget.registry,
                            tasks: widget.tasks,
                            onImportLocal: () async {
                              final selected = await FilePicker.platform
                                  .pickFiles(
                                    allowMultiple: true,
                                    type: FileType.custom,
                                    allowedExtensions: const [
                                      'lua',
                                      'zip',
                                      '7z',
                                      'rar',
                                      'tar',
                                      'tgz',
                                      'gz',
                                    ],
                                  );
                              if (selected == null || !context.mounted) return;
                              await showLocalContentImportDialog(
                                context,
                                resolver: widget.resolver,
                                importer: widget.importer,
                                tasks: widget.tasks,
                                paths: selected.paths
                                    .whereType<String>()
                                    .toList(),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (preview != null) ...[
            ui.generateSection(
              title: context.l10n.contentPreview,
              items: [
                for (final entry in preview.entries)
                  ui.DecorationListItem(
                    leading: ui.GlyphIcon(
                      entry.artifact.capability == ContentCapability.lua
                          ? ui.AppGlyphs.code
                          : ui.AppGlyphs.resources,
                    ),
                    title: SelectableText(entry.path),
                    subtitle: Text(
                      entry.exists
                          ? context.l10n.existingFilesLeftUnchanged
                          : entry.artifact.capability == ContentCapability.lua
                          ? 'Lua'
                          : context.l10n.manifestFiles,
                    ),
                  ),
              ],
            ),
            if (preview.hasConflicts)
              ui.generateSection(
                items: [
                  ui.FormRowSwitch(
                    title: context.l10n.contentImportReplace,
                    value: _overwrite,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _overwrite = value),
                  ),
                ],
              ),
            if (preview.bundle.lua != null)
              ui.CollapsibleSection(
                label: 'Lua',
                itemCount: 1,
                initiallyExpanded: false,
                itemBuilder: (_, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    utf8.decode(preview.bundle.lua!.bytes),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}

Future<List<ContentImportResult>?> showLocalContentImportDialog(
  BuildContext context, {
  required ContentResolver resolver,
  required ContentImportService importer,
  required TaskCenter tasks,
  required List<String> paths,
}) => ui.showFormSheet<List<ContentImportResult>>(
  context: context,
  builder: (_) => LocalContentImportDialog(
    resolver: resolver,
    importer: importer,
    tasks: tasks,
    paths: paths,
  ),
);

class LocalContentImportDialog extends StatefulWidget {
  const LocalContentImportDialog({
    super.key,
    required this.resolver,
    required this.importer,
    required this.tasks,
    required this.paths,
  });
  final ContentResolver resolver;
  final ContentImportService importer;
  final TaskCenter tasks;
  final List<String> paths;
  @override
  State<LocalContentImportDialog> createState() =>
      _LocalContentImportDialogState();
}

class _LocalContentImportDialogState extends State<LocalContentImportDialog> {
  final List<ContentImportPreview> _previews = [];
  final Map<int, ContentImportResult> _results = {};
  final Map<int, String> _failures = {};
  bool _busy = true;
  bool _overwrite = false;
  String? _error;
  String? _taskId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    final l10n = context.l10n;
    try {
      await widget.tasks.run(context.l10n.previewContent, (task) async {
        _taskId = task.task.id;
        final games = await widget.resolver.discoverLocalGames(
          widget.paths,
          task: task,
        );
        if (games.isEmpty) {
          throw FormatException(l10n.contentImportNoLocalLua);
        }
        for (final appId in games) {
          task.checkCancelled();
          final bundle = await widget.resolver.resolveLocal(
            appId,
            widget.paths,
            task: task,
          );
          _previews.add(await widget.importer.preview(bundle));
        }
      });
    } on TaskCancelled {
      _previews.clear();
    } catch (error) {
      _previews.clear();
      if (mounted) setState(() => _error = '$error');
    } finally {
      _taskId = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.tasks.run(context.l10n.importContent, (task) async {
        _taskId = task.task.id;
        for (final preview in _previews.where(
          (p) => !_results.containsKey(p.bundle.appId),
        )) {
          task.checkCancelled();
          try {
            final result = await widget.importer.commit(
              preview,
              overwrite: _overwrite,
              task: task,
            );
            _results[preview.bundle.appId] = result;
            _failures.remove(preview.bundle.appId);
          } on TaskCancelled {
            rethrow;
          } catch (error) {
            _failures[preview.bundle.appId] = '$error';
          }
          if (mounted) setState(() {});
        }
        if (_failures.isNotEmpty) {
          throw StateError(
            _failures.entries
                .map((entry) => 'AppID ${entry.key}: ${entry.value}')
                .join('\n'),
          );
        }
      });
      if (_failures.isEmpty && mounted) {
        Navigator.pop(context, _results.values.toList());
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _taskId = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        !_busy &&
        _error == null &&
        _previews.isNotEmpty &&
        (!_previews.any((preview) => preview.hasConflicts) || _overwrite);
    return ui.FormPage(
      title: context.l10n.importLocalContent,
      onSave: _commit,
      saveLabel: context.l10n.importContent,
      saving: _busy,
      canSave: canSave,
      error: _error,
      onCancel: () {
        final id = _taskId;
        if (_busy && id != null) {
          widget.tasks.cancel(id);
        } else {
          Navigator.pop(
            context,
            _results.isEmpty ? null : _results.values.toList(),
          );
        }
      },
      children: [
        ui.ListFooter(text: context.l10n.contentImportPerGame),
        for (final path in widget.paths) ui.ListFooter(text: path),
        for (final preview in _previews)
          ui.CollapsibleSection(
            label: 'AppID ${preview.bundle.appId}',
            itemCount:
                preview.entries.length +
                (_failures[preview.bundle.appId] == null ? 0 : 1),
            initiallyExpanded: _previews.length == 1,
            itemBuilder: (context, index) {
              if (index < preview.entries.length) {
                final entry = preview.entries[index];
                return ui.DecorationListItem(
                  leading: ui.GlyphIcon(
                    _results[preview.bundle.appId]?.wroteLua == true
                        ? ui.AppGlyphs.checkCircle
                        : entry.exists
                        ? ui.AppGlyphs.sync
                        : ui.AppGlyphs.code,
                  ),
                  title: SelectableText(entry.path),
                  subtitle: Text(
                    entry.exists
                        ? context.l10n.existingFilesLeftUnchanged
                        : context.l10n.manifestFiles,
                  ),
                );
              }
              return ui.DecorationListItem(
                leading: ui.GlyphIcon(
                  ui.AppGlyphs.error,
                  color: context.colorScheme.error,
                ),
                title: SelectableText(_failures[preview.bundle.appId]!),
              );
            },
          ),
        if (_previews.any((preview) => preview.hasConflicts))
          ui.generateSection(
            items: [
              ui.FormRowSwitch(
                title: context.l10n.contentImportReplace,
                value: _overwrite,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _overwrite = value),
              ),
            ],
          ),
      ],
    );
  }
}
