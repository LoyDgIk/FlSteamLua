import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../../ui/context.dart';
import '../key_cache/key_cache_service.dart';
import '../manifests/manifest_source_service.dart';
import '../manifests/manifest_script_parser.dart';
import 'content_source_registry.dart';
import 'script_source_editor_page.dart';

const _dynamicSubscriptionScriptExample = r'''async function download(ctx) {
  const response = await ctx.http.get("https://example.com/addresses.txt", {
    responseType: "text",
    timeout: 30,
    allowNonSuccess: true
  });
  if (!response.ok) throw new Error("HTTP " + response.status);
  return {
    depotKeysUrl: "https://example.com/depotkeys.json",
    tokenKeysUrl: "https://example.com/appaccesstokens.json"
  };
}
''';

class ContentSourcesPage extends StatefulWidget {
  const ContentSourcesPage({
    super.key,
    required this.registry,
    required this.tasks,
    this.onImportLocal,
    this.initialSourceId,
  });
  final ContentSourceRegistry registry;
  final TaskCenter tasks;
  final VoidCallback? onImportLocal;
  final String? initialSourceId;

  @override
  State<ContentSourcesPage> createState() => _ContentSourcesPageState();
}

class _ContentSourcesPageState extends State<ContentSourcesPage> {
  String _filter = 'all';
  String _density = 'standard';
  String _search = '';
  bool _busy = false;
  late final ui.AppBarSearchState _searchState;

  @override
  void initState() {
    super.initState();
    _searchState = ui.AppBarSearchState(
      onSearch: (value) => setState(() => _search = value),
    );
    _run(() async {
      await widget.registry.initialize();
      if (mounted && widget.initialSourceId != null) {
        await _edit(widget.registry.source(widget.initialSourceId!));
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ui.showAppError(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([ContentSourceDefinition? source]) async {
    if (source == null || source.kind == ContentSourceKind.subscription) {
      final id = source?.id.substring('subscription:'.length);
      final existing = id == null
          ? null
          : widget.registry.keyCache.subscriptions
                .where((subscription) => subscription.id == id)
                .firstOrNull;
      if (id != null && existing == null) {
        if (mounted) {
          ui.showAppError(
            context,
            StateError(context.l10n.sourceDefinitionNotFound(id)),
          );
        }
        return;
      }
      final result = await ui.showFormSheet<KeyCacheSubscription>(
        context: context,
        builder: (_) => SubscriptionSourceEditor(
          source: existing,
          settings: widget.registry.settings,
        ),
      );
      if (result != null) {
        await _run(() async {
          await widget.registry.keyCache.upsert(result);
          await widget.registry.initialize();
        });
      }
    } else if (source.kind == ContentSourceKind.script) {
      final id = source.id.substring('script:'.length);
      final definition = widget.registry.manifests.sources
          .where((definition) => definition.id == id)
          .firstOrNull;
      if (definition == null) {
        if (mounted) {
          ui.showAppError(
            context,
            StateError(context.l10n.sourceDefinitionNotFound(id)),
          );
        }
        return;
      }
      await ui.showFormSheet<void>(
        context: context,
        builder: (_) => ScriptSourceEditor(
          service: widget.registry.manifests,
          source: definition,
        ),
      );
      await _run(() => widget.registry.initialize());
    }
  }

  String _scriptId(ContentSourceDefinition source) =>
      source.id.substring('script:'.length);

  Future<void> _editScript(ContentSourceDefinition source) async {
    await Navigator.of(context).push(
      ui.buildAppPageRoute(
        builder: (_) => ScriptSourceEditorPage(
          service: widget.registry.manifests,
          sourceId: _scriptId(source),
          title: source.name,
        ),
      ),
    );
    await _run(() => widget.registry.initialize());
  }

  void _validateScript(ContentSourceDefinition source) {
    try {
      final definition = ManifestScriptParser.parse(
        widget.registry.manifests.scriptFor(_scriptId(source)),
      );
      if (definition.id != _scriptId(source)) {
        throw FormatException('Script ID changed to ${definition.id}');
      }
      ui.showAppSuccess(context, context.l10n.scriptIsValid);
    } catch (error) {
      ui.showAppError(context, error);
    }
  }

  Future<void> _restoreScript(ContentSourceDefinition source) async {
    final accepted = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: context.l10n.restoreBuiltInScript,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.restore),
          ),
        ],
        child: Text(source.name),
      ),
    );
    if (accepted == true) {
      await _run(
        () => widget.registry.manifests.restoreBuiltInScript(_scriptId(source)),
      );
      await _run(() => widget.registry.initialize());
    }
  }

  Future<void> _importScript() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['js'],
    );
    final path = selection?.files.single.path;
    if (path != null) {
      await _run(() async {
        await widget.registry.manifests.importScript(File(path));
        await widget.registry.initialize();
      });
    }
  }

  Future<void> _delete(ContentSourceDefinition source) async {
    final accepted = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: context.l10n.deleteSource,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.deleteSource),
          ),
        ],
        child: Text(context.l10n.deleteSourceConfirm),
      ),
    );
    if (accepted == true) await _run(() => widget.registry.remove(source.id));
  }

  List<ui.CommonPopupMenuItem> _actions(ContentSourceDefinition source) => [
    if (source.kind == ContentSourceKind.script) ...[
      ui.CommonPopupMenuItem(
        glyph: ui.AppGlyphs.code,
        label: context.l10n.editScript,
        onPressed: () => _editScript(source),
      ),
      ui.CommonPopupMenuItem(
        glyph: ui.AppGlyphs.settings,
        label: context.l10n.configureSource,
        onPressed: () => _edit(source),
      ),
      ui.CommonPopupMenuItem(
        glyph: ui.AppGlyphs.verified,
        label: context.l10n.validateScript,
        onPressed: () => _validateScript(source),
      ),
      if (source.builtIn)
        ui.CommonPopupMenuItem(
          glyph: ui.AppGlyphs.undo,
          label: context.l10n.restoreBuiltInScript,
          onPressed: () => _restoreScript(source),
        ),
    ],
    if (source.kind != ContentSourceKind.script)
      ui.CommonPopupMenuItem(
        glyph: ui.AppGlyphs.edit,
        label: context.l10n.editSource,
        onPressed: () => _edit(source),
      ),
    if (source.kind == ContentSourceKind.subscription ||
        widget.registry.manifests.supportsTest(_scriptId(source)))
      ui.CommonPopupMenuItem(
        label: source.kind == ContentSourceKind.subscription
            ? context.l10n.testAndUpdateSubscription
            : context.l10n.testSource,
        onPressed: () => _run(() async {
          await widget.tasks.run(context.l10n.testSource, (task) async {
            final result = await widget.registry.testSource(
              source.id,
              task: task,
            );
            if (!result.success) throw StateError(result.message);
            return result;
          });
          if (mounted) {
            ui.showAppSuccess(
              context,
              context.l10n.sourceTestPassed(source.name),
            );
          }
        }),
      ),
    if (source.kind == ContentSourceKind.subscription)
      ui.CommonPopupMenuItem(
        label: context.l10n.updateSource,
        onPressed: () => _run(() async {
          await widget.tasks.run(
            context.l10n.updateSource,
            (task) => widget.registry.update(source.id, task: task),
          );
        }),
      ),
    ui.CommonPopupMenuItem(
      label: source.enabled
          ? context.l10n.disableSource
          : context.l10n.enableSource,
      onPressed: () =>
          _run(() => widget.registry.setEnabled(source.id, !source.enabled)),
    ),
    if (!source.builtIn)
      ui.CommonPopupMenuItem(
        label: context.l10n.deleteSource,
        danger: true,
        onPressed: () => _delete(source),
      ),
  ];

  String _kind(ContentSourceKind kind) => switch (kind) {
    ContentSourceKind.subscription => context.l10n.subscriptionSource,
    ContentSourceKind.script => context.l10n.scriptSource,
    ContentSourceKind.local => context.l10n.localSource,
  };
  String _capability(ContentCapability capability) => switch (capability) {
    ContentCapability.lua => 'Lua',
    ContentCapability.manifestIds => context.l10n.manifestIds,
    ContentCapability.manifestFiles => context.l10n.manifestFiles,
    ContentCapability.manifestRequestCodes => context.l10n.manifestRequestCodes,
  };
  bool _matches(ContentSourceDefinition source) {
    final query = _search.trim().toLowerCase();
    final matchesSearch =
        query.isEmpty ||
        '${source.name} ${source.description}'.toLowerCase().contains(query);
    return matchesSearch &&
        switch (_filter) {
          'lua' => source.capabilities.contains(ContentCapability.lua),
          'manifest' => source.providesManifests,
          'enabled' => source.enabled,
          'error' => source.hasError,
          _ => true,
        };
  }

  Widget _statusIcon(BuildContext context, ContentSourceDefinition source) {
    final (glyph, color, message) = !source.enabled
        ? (
            ui.AppGlyphs.block,
            context.colorScheme.onSurfaceVariant,
            context.l10n.disabled2,
          )
        : !source.configurationComplete
        ? (
            ui.AppGlyphs.warning,
            context.colorScheme.error,
            context.l10n.sourceConfigurationRequired,
          )
        : source.lastTestSucceeded == false
        ? (
            ui.AppGlyphs.error,
            context.colorScheme.error,
            source.lastTestMessage ?? context.l10n.failed,
          )
        : source.lastTestSucceeded == true
        ? (
            ui.AppGlyphs.checkCircle,
            context.colorScheme.primary,
            source.lastTestMessage ?? context.l10n.sourceConfigured,
          )
        : source.kind == ContentSourceKind.script
        ? (
            ui.AppGlyphs.info,
            context.colorScheme.onSurfaceVariant,
            context.l10n.sourceNotTested,
          )
        : source.lastUpdated == null
        ? (
            ui.AppGlyphs.clock,
            context.colorScheme.onSurfaceVariant,
            context.l10n.sourceNeverUpdated,
          )
        : (
            ui.AppGlyphs.checkCircle,
            context.colorScheme.primary,
            source.lastTestMessage ?? context.l10n.sourceConfigured,
          );
    return Tooltip(
      message: message,
      child: ui.GlyphIcon(glyph, size: 16, color: color),
    );
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.contentSources,
    isLoading: _busy,
    searchState: _searchState,
    trailingAction: ui.CommonPopupBox(
      key: const ValueKey('content-source-add'),
      targetBuilder: (open) => ui.DashboardIconButton(
        glyph: ui.AppGlyphs.add,
        tooltip: context.l10n.addContentSource,
        onPressed: _busy ? null : open,
      ),
      popupBuilder: (_) => ui.CommonPopupMenu(
        items: [
          ui.CommonPopupMenuItem(
            label: context.l10n.addSubscriptionSource,
            onPressed: _edit,
          ),
          ui.CommonPopupMenuItem(
            label: context.l10n.importScriptSource,
            onPressed: _importScript,
          ),
          if (widget.onImportLocal != null)
            ui.CommonPopupMenuItem(
              label: context.l10n.importLocalContent,
              onPressed: widget.onImportLocal,
            ),
        ],
      ),
    ),
    actions: [
      ui.DashboardIconButton(
        glyph: ui.AppGlyphs.refresh,
        tooltip: MaterialLocalizations.of(
          context,
        ).refreshIndicatorSemanticLabel,
        onPressed: _busy
            ? null
            : () => _run(() => widget.registry.initialize()),
      ),
      ui.CommonPopupBox(
        key: const ValueKey('content-source-filter'),
        targetBuilder: (open) => ui.DashboardIconButton(
          glyph: ui.AppGlyphs.filter,
          tooltip: context.l10n.filter,
          onPressed: open,
        ),
        popupBuilder: (_) => ui.CommonPopupMenu(
          items: [
            for (final item in [
              ('all', context.l10n.allSources),
              ('lua', context.l10n.luaSources),
              ('manifest', context.l10n.manifestSources),
              ('enabled', context.l10n.enabledSources),
              ('error', context.l10n.failedSources),
            ])
              ui.CommonPopupMenuItem(
                label: item.$2,
                checked: _filter == item.$1,
                onPressed: () => setState(() => _filter = item.$1),
              ),
          ],
        ),
      ),
      ui.CommonPopupBox(
        targetBuilder: (open) => ui.DashboardIconButton(
          glyph: ui.AppGlyphs.sort,
          tooltip: context.l10n.layout,
          onPressed: _busy ? null : open,
        ),
        popupBuilder: (_) => ui.CommonPopupMenu(
          items: [
            for (final option in [
              ('comfortable', context.l10n.comfortable),
              ('standard', context.l10n.standard),
              ('compact', context.l10n.compact),
            ])
              ui.CommonPopupMenuItem(
                label: option.$2,
                checked: _density == option.$1,
                onPressed: () => setState(() => _density = option.$1),
              ),
          ],
        ),
      ),
    ],
    body: ListenableBuilder(
      listenable: widget.registry,
      builder: (context, _) {
        final sources = widget.registry.sources.where(_matches).toList();
        final padding = switch (_density) {
          'comfortable' => 18.0,
          'compact' => 12.0,
          _ => 14.0,
        };
        final gap = switch (_density) {
          'comfortable' => 16.0,
          'compact' => 8.0,
          _ => 10.0,
        };
        final descriptionLines = switch (_density) {
          'comfortable' => 3,
          'compact' => 1,
          _ => 2,
        };
        final topPadding = ui.pageContentTopInset;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            _density == 'compact' ? 16 : 20,
            0,
            _density == 'compact' ? 16 : 20,
            0,
          ),
          child: Column(
            children: [
              Expanded(
                child: ui.NullStatusSwitcher(
                  isEmpty: sources.isEmpty,
                  isSearching: _search.trim().isNotEmpty || _filter != 'all',
                  nullStatus: ui.NullStatus(
                    label: context.l10n.noContentSources,
                    illustration: ui.NullStatusIllustration.data,
                    action: FilledButton.icon(
                      onPressed: _busy ? null : _edit,
                      icon: const ui.GlyphIcon(
                        ui.AppGlyphs.addCircle,
                        size: 18,
                      ),
                      label: Text(context.l10n.addContentSource),
                    ),
                  ),
                  searchStatus: ui.NullStatus(
                    label: context.l10n.noSearchResults,
                    illustration: ui.NullStatusIllustration.search,
                  ),
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(0, topPadding, 0, 24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 500,
                      mainAxisExtent: switch (_density) {
                        'comfortable' => 148,
                        'compact' => 110,
                        _ => 130,
                      },
                      crossAxisSpacing: gap,
                      mainAxisSpacing: gap,
                    ),
                    itemCount: sources.length,
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      final actions = _actions(source);
                      final description = source.description.isNotEmpty
                          ? source.description
                          : source.kind == ContentSourceKind.subscription
                          ? context.l10n.dynamicSubscriptionSource
                          : '';
                      return ui.ContextMenuRegion(
                        menuItems: actions,
                        child: ui.CommonCard(
                          key: ValueKey('content-source-${source.id}'),
                          padding: EdgeInsets.all(padding),
                          radius: 18,
                          enterActionsOnRight: true,
                          onPressed: () => _edit(source),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: context.colorScheme.primaryContainer
                                      .withValues(alpha: .42),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: ui.GlyphIcon(switch (source.kind) {
                                  ContentSourceKind.subscription =>
                                    ui.AppGlyphs.key,
                                  ContentSourceKind.script => ui.AppGlyphs.code,
                                  ContentSourceKind.local =>
                                    ui.AppGlyphs.resources,
                                }, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            source.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ui.AppTextStyle.headline.of(
                                              context,
                                              emphasized: true,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _statusIcon(context, source),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 5,
                                      children: [
                                        ui.MetaChip(label: _kind(source.kind)),
                                        for (final capability
                                            in source.capabilities)
                                          ui.MetaChip(
                                            label: _capability(capability),
                                          ),
                                      ],
                                    ),
                                    if (description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          description,
                                          maxLines: descriptionLines,
                                          overflow: TextOverflow.ellipsis,
                                          style: ui.AppTextStyle.caption1
                                              .of(context)
                                              .copyWith(
                                                color: context
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: .72),
                                              ),
                                        ),
                                      ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        ui.GlyphIcon(
                                          ui.AppGlyphs.clock,
                                          size: 13,
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: .58),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          source.lastUpdated == null
                                              ? context.l10n.sourceNeverUpdated
                                              : MaterialLocalizations.of(
                                                  context,
                                                ).formatMediumDate(
                                                  source.lastUpdated!.toLocal(),
                                                ),
                                          style: ui.AppTextStyle.caption2
                                              .of(context)
                                              .copyWith(
                                                color: context
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: .62),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class SubscriptionSourceEditor extends StatefulWidget {
  const SubscriptionSourceEditor({super.key, this.source, this.settings});
  final SettingsStore? settings;
  final KeyCacheSubscription? source;
  @override
  State<SubscriptionSourceEditor> createState() =>
      _SubscriptionSourceEditorState();
}

class _SubscriptionSourceEditorState extends State<SubscriptionSourceEditor> {
  late final _name = TextEditingController(text: widget.source?.name ?? '');
  late final _depots = TextEditingController(
    text: widget.source?.depotKeysUrl ?? '',
  );
  late final _tokens = TextEditingController(
    text: widget.source?.tokenKeysUrl ?? '',
  );
  late final _dynamic = TextEditingController(
    text: widget.source?.dynamicScript ?? '',
  );
  late final _interval = TextEditingController(
    text: '${widget.source?.intervalHours ?? 24}',
  );
  late bool _enabled = widget.source?.enabled ?? true;
  late KeySubscriptionAddressMode _mode =
      widget.source?.addressMode ??
      ((widget.source?.dynamicScript.trim().isNotEmpty ?? false)
          ? KeySubscriptionAddressMode.script
          : KeySubscriptionAddressMode.links);
  String? _error;
  var _nameInvalid = false;
  var _depotsInvalid = false;
  var _tokensInvalid = false;
  var _dynamicInvalid = false;
  var _intervalInvalid = false;
  final _modeKey = GlobalKey();

  @override
  void dispose() {
    _name.dispose();
    _depots.dispose();
    _tokens.dispose();
    _dynamic.dispose();
    _interval.dispose();
    super.dispose();
  }

  String? _url(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.fragment.isNotEmpty
        ? context.l10n.httpsUrlRequired
        : null;
  }

  Future<void> _editDynamicScript() async {
    final value = await Navigator.of(context).push<String>(
      ui.buildAppPageRoute(
        builder: (_) => DynamicSubscriptionScriptPage(
          script: _dynamic.text.trim().isEmpty
              ? _dynamicSubscriptionScriptExample
              : _dynamic.text,
        ),
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      _dynamic.text = value;
      _dynamicInvalid = false;
      _error = null;
    });
  }

  void _setMode(KeySubscriptionAddressMode value) {
    setState(() {
      _mode = value;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _modeKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: .25,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _save() {
    final name = _name.text.trim();
    final dynamicScript = _dynamic.text.trim();
    final scriptMode = _mode == KeySubscriptionAddressMode.script;
    final depotError = scriptMode ? null : _url(_depots.text);
    final tokenError = scriptMode ? null : _url(_tokens.text);
    final dynamicInvalid =
        scriptMode &&
        !RegExp(r'\bfunction\s+download\s*\(').hasMatch(dynamicScript);
    final interval = int.tryParse(_interval.text.trim());
    final intervalInvalid = interval == null || interval < 0 || interval > 8760;
    final nameInvalid = name.isEmpty;
    if (nameInvalid ||
        depotError != null ||
        tokenError != null ||
        dynamicInvalid ||
        intervalInvalid) {
      setState(() {
        _nameInvalid = nameInvalid;
        _depotsInvalid = depotError != null;
        _tokensInvalid = tokenError != null;
        _dynamicInvalid = dynamicInvalid;
        _intervalInvalid = intervalInvalid;
        _error = nameInvalid
            ? context.l10n.requiredField
            : dynamicInvalid
            ? context.l10n.dynamicSubscriptionScriptDescription
            : depotError ?? tokenError ?? context.l10n.invalidUpdateInterval;
      });
      return;
    }
    final source = widget.source;
    Navigator.pop(
      context,
      KeyCacheSubscription(
        id: source?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        depotKeysUrl: scriptMode ? '' : _depots.text.trim(),
        tokenKeysUrl: scriptMode ? '' : _tokens.text.trim(),
        dynamicScript: dynamicScript,
        addressMode: _mode,
        intervalHours: interval,
        enabled: _enabled,
        lastUpdated: source?.lastUpdated,
        depotCount: source?.depotCount ?? 0,
        tokenCount: source?.tokenCount ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: widget.source == null
        ? context.l10n.addSubscriptionSource
        : context.l10n.editSource,
    onSave: _save,
    error: _error,
    children: [
      KeyedSubtree(
        key: _modeKey,
        child: ui.generateSection(
          title: context.l10n.addressSourceMode,
          items: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ui.SegmentedControl<KeySubscriptionAddressMode>(
                value: _mode,
                segments: [
                  (
                    KeySubscriptionAddressMode.links,
                    context.l10n.useFixedLinks,
                  ),
                  (
                    KeySubscriptionAddressMode.script,
                    context.l10n.useDynamicScript,
                  ),
                ],
                onChanged: _setMode,
              ),
            ),
            if (_mode == KeySubscriptionAddressMode.script) ...[
              ui.DecorationListItem(
                key: const ValueKey('dynamic-subscription-script-edit'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.code, size: 20),
                title: Text(context.l10n.dynamicSubscriptionSource),
                subtitle: Text(
                  _dynamic.text.trim().isEmpty
                      ? context.l10n.dynamicSubscriptionScriptNotConfigured
                      : context.l10n.dynamicSubscriptionScriptConfigured,
                ),
                invalid: _dynamicInvalid,
                onPressed: _editDynamicScript,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
            ],
          ],
          footer: _mode == KeySubscriptionAddressMode.script
              ? context.l10n.dynamicSubscriptionScriptDescription
              : null,
        ),
      ),
      ui.generateSection(
        title: context.l10n.basicInfo,
        items: [
          ui.FormRow(
            title: context.l10n.sourceName,
            invalid: _nameInvalid,
            trailing: ui.FormRowTextField(
              controller: _name,
              hintText: context.l10n.requiredField,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                _nameInvalid = false;
                _error = null;
              }),
            ),
          ),
          if (_mode == KeySubscriptionAddressMode.links) ...[
            ui.FormRow(
              title: context.l10n.depotKeysUrl,
              invalid: _depotsInvalid,
              trailing: ui.FormRowTextField(
                controller: _depots,
                hintText: 'https://',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {
                  _depotsInvalid = false;
                  _error = null;
                }),
              ),
            ),
            ui.FormRow(
              title: context.l10n.appTokensUrl,
              invalid: _tokensInvalid,
              trailing: ui.FormRowTextField(
                controller: _tokens,
                hintText: 'https://',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {
                  _tokensInvalid = false;
                  _error = null;
                }),
              ),
            ),
          ],
          ui.FormRow(
            title: context.l10n.sourceUpdateInterval,
            invalid: _intervalInvalid,
            trailing: ui.FormRowTextField(
              controller: _interval,
              hintText: '24',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {
                _intervalInvalid = false;
                _error = null;
              }),
            ),
          ),
          if (widget.settings case final settings?)
            ListenableBuilder(
              listenable: settings,
              builder: (context, _) => ui.ListItem.toggle(
                title: Text(context.l10n.updateKeySubscriptionsAutomatically),
                subtitle: Text(context.l10n.subscriptionAutoUpdateScope),
                value: settings.get<bool>('autoUpdateKeyCache', false),
                onChanged: (value) async {
                  try {
                    await settings.set('autoUpdateKeyCache', value);
                  } catch (error) {
                    if (context.mounted) ui.showAppError(context, error);
                  }
                },
              ),
            ),
          ui.FormRowSwitch(
            title: context.l10n.sourceEnabled,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
        ],
        footer: context.l10n.subscriptionIntervalDescription,
      ),
    ],
  );
}

class DynamicSubscriptionScriptPage extends StatefulWidget {
  const DynamicSubscriptionScriptPage({super.key, required this.script});

  final String script;

  @override
  State<DynamicSubscriptionScriptPage> createState() =>
      _DynamicSubscriptionScriptPageState();
}

class _DynamicSubscriptionScriptPageState
    extends State<DynamicSubscriptionScriptPage> {
  late final TextEditingController _editor;
  late final FocusNode _focus;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController(text: widget.script);
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _editor.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, _editor.text.trim());
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.dynamicSubscriptionSource,
    actions: [
      ui.DashboardIconButton(
        key: const ValueKey('dynamic-subscription-script-save'),
        glyph: ui.AppGlyphs.check,
        tooltip: context.l10n.save,
        onPressed: _dirty ? _save : null,
      ),
    ],
    body: Padding(
      padding: const EdgeInsets.fromLTRB(20, ui.pageContentTopInset, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.dynamicSubscriptionScriptDescription,
            style: ui.AppTextStyle.caption1
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ui.FilledInputTheme(
              borderRadius: ui.AppRadius.lg,
              child: TextField(
                key: const ValueKey('dynamic-subscription-script-editor'),
                controller: _editor,
                focusNode: _focus,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  height: 1.6,
                ),
                decoration: const InputDecoration(
                  hintText: 'async function download(ctx) {}',
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (_) {
                  setState(() {
                    _dirty = _editor.text.trim() != widget.script.trim();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_editor.text.split('\n').length} lines',
            style: ui.AppTextStyle.caption1
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

class ScriptSourceEditor extends StatefulWidget {
  const ScriptSourceEditor({
    super.key,
    required this.service,
    required this.source,
  });
  final ManifestSourceService service;
  final ManifestSourceDefinition source;
  @override
  State<ScriptSourceEditor> createState() => _ScriptSourceEditorState();
}

class _ScriptSourceEditorState extends State<ScriptSourceEditor> {
  final _controllers = <String, TextEditingController>{};
  final _invalid = <String>{};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final values = widget.service.configFor(widget.source.id).values;
    for (final parameter in widget.source.parameters.where((p) => !p.isAppId)) {
      _controllers[parameter.key] = TextEditingController(
        text: values[parameter.key] ?? parameter.defaultValue,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final invalid = {
      for (final parameter in widget.source.parameters)
        if (!parameter.isAppId &&
            parameter.required &&
            _controllers[parameter.key]!.text.trim().isEmpty)
          parameter.key,
    };
    if (invalid.isNotEmpty) {
      setState(() {
        _invalid
          ..clear()
          ..addAll(invalid);
        _error = context.l10n.requiredField;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.saveConfig(widget.source.id, {
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = ui.appErrorText(context, error));
        ui.showAppError(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _parameterLabel(ManifestParameter parameter) {
    if (!widget.source.builtIn) return parameter.label;
    return switch (parameter.key) {
      'fileType' => context.l10n.sourceOutputType,
      'source' => context.l10n.manifestContentSource,
      'gameName' => context.l10n.gameName,
      'depotid' => 'Depot ID',
      'manifestid' => 'Manifest ID',
      _ => parameter.label,
    };
  }

  String _parameterDescription(ManifestParameter parameter) {
    if (!widget.source.builtIn) return parameter.description;
    return switch (parameter.key) {
      'apiKey' ||
      'apikey' ||
      'authKey' ||
      'token' => context.l10n.sourceCredentialHint,
      'fileType' => context.l10n.sourceOutputHint,
      'source' => context.l10n.sourceProviderHint,
      'gameName' => context.l10n.sourceGameNameHint,
      'depotid' || 'manifestid' => context.l10n.sourceDepotManifestHint,
      _ => parameter.description,
    };
  }

  List<(String, String)>? _options(ManifestParameter parameter) {
    if (!widget.source.builtIn) return null;
    return switch (parameter.key) {
      'fileType' => [('lua', 'Lua'), ('zip', context.l10n.sourceArchiveOutput)],
      'source' when widget.source.id == 'luatools' => [
        for (final value in [
          'Ryuu',
          'Sushi',
          'Skyflare',
          'TwentyTwo Cloud',
          'Sadie (Morrenus)',
        ])
          (value, value),
      ],
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) => ui.FormPage(
    title: widget.source.name,
    onSave: _save,
    error: _error,
    saving: _busy,
    children: [
      if (widget.source.homepage.isNotEmpty)
        ui.generateSection(
          items: [
            ui.DecorationListItem(
              leading: const ui.GlyphIcon(ui.AppGlyphs.openExternal),
              title: Text(context.l10n.openSourceWebsite),
              subtitle: Text(widget.source.homepage),
              onPressed: () async {
                try {
                  await launchUrl(
                    Uri.parse(widget.source.homepage),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (error) {
                  if (context.mounted) ui.showAppError(context, error);
                }
              },
            ),
          ],
        ),
      if (widget.source.description.isNotEmpty)
        ui.ListFooter(text: widget.source.description),
      ui.ListHeader(title: context.l10n.basicInfo),
      for (final parameter in widget.source.parameters.where(
        (parameter) => !parameter.isAppId,
      ))
        ui.generateSection(
          items: [
            if (_options(parameter) case final options?)
              ui.FormRowSelect<String>(
                title: _parameterLabel(parameter),
                value: _controllers[parameter.key]!.text,
                options: options,
                enabled: !_busy,
                onChanged: (value) =>
                    setState(() => _controllers[parameter.key]!.text = value!),
              )
            else if (parameter.type == ManifestParameterType.boolean)
              ui.FormRowSwitch(
                title: _parameterLabel(parameter),
                value: _controllers[parameter.key]!.text == 'true',
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => _controllers[parameter.key]!.text = '$value',
                      ),
              )
            else
              ui.FormRow(
                title: _parameterLabel(parameter),
                invalid: _invalid.contains(parameter.key),
                trailing: parameter.isSecret
                    ? ui.FormRowSecretTextField(
                        controller: _controllers[parameter.key]!,
                        hintText: parameter.required
                            ? context.l10n.requiredField
                            : context.l10n.optional,
                        enabled: !_busy,
                        keyboardType:
                            parameter.type == ManifestParameterType.number
                            ? TextInputType.number
                            : TextInputType.text,
                        onChanged: (_) => setState(() {
                          _invalid.remove(parameter.key);
                          _error = null;
                        }),
                      )
                    : ui.FormRowTextField(
                        controller: _controllers[parameter.key]!,
                        hintText: parameter.required
                            ? context.l10n.requiredField
                            : context.l10n.optional,
                        enabled: !_busy,
                        keyboardType:
                            parameter.type == ManifestParameterType.number
                            ? TextInputType.number
                            : TextInputType.text,
                        onChanged: (_) => setState(() {
                          _invalid.remove(parameter.key);
                          _error = null;
                        }),
                      ),
              ),
          ],
          footer: _parameterDescription(parameter).isEmpty
              ? null
              : _parameterDescription(parameter),
        ),
    ],
  );
}
