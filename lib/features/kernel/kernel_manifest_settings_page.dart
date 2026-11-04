import 'package:flutter/material.dart';

import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'kernel_service.dart';

class KernelManifestSettingsPage extends StatefulWidget {
  const KernelManifestSettingsPage({super.key, required this.service});

  final KernelService service;

  @override
  State<KernelManifestSettingsPage> createState() =>
      _KernelManifestSettingsPageState();
}

class _KernelManifestSettingsPageState
    extends State<KernelManifestSettingsPage> {
  final _customUrl = TextEditingController();
  final _customHeader = TextEditingController();
  KernelManifestMode _mode = KernelManifestMode.builtIn;
  KernelManifestFormat _format = KernelManifestFormat.plain;
  String _provider = '20770407';
  Set<String> _sourceIds = {};
  bool _failover = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customUrl.dispose();
    _customHeader.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await widget.service.readManifestSettings();
      if (!mounted) return;
      setState(() {
        _mode = value.mode;
        _provider = value.provider;
        _format = value.format;
        _failover = value.failover;
        _customUrl.text = value.customUrl;
        _customHeader.text = value.customHeader;
        final available = widget.service.manifestCodeSources
            .map((source) => source.id)
            .toSet();
        _sourceIds = value.sourceIds.where(available.contains).toSet();
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final url = _customUrl.text.trim();
    if (_mode == KernelManifestMode.custom &&
        !RegExp(r'\{(?:gid|manifestId)\}').hasMatch(url)) {
      setState(() => _error = context.l10n.manifestCustomHint);
      return;
    }
    if (_mode == KernelManifestMode.localProxy && _sourceIds.isEmpty) {
      setState(() => _error = context.l10n.selectAtLeastOneManifestCodeSource);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveManifestSettings(
        KernelManifestSettings(
          mode: _mode,
          provider: _provider,
          customUrl: url,
          customHeader: _customHeader.text.trim(),
          format: _format,
          failover: _failover,
          sourceIds: _sourceIds.toList(),
        ),
      );
      if (mounted) {
        ui.showAppSuccess(context, context.l10n.operationCompleted);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.manifestSettings,
    isLoading: _saving,
    actions: [
      IconButton(
        tooltip: context.l10n.save,
        onPressed: _loading || _saving ? null : _save,
        icon: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
      ),
    ],
    body: _loading
        ? const Center(child: ui.CommonCircleLoading.page())
        : ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              ui.pageContentTopInset,
              16,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ui.CommonCard(
                    isError: true,
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(_error!),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ui.SegmentedControl<KernelManifestMode>(
                  segments: [
                    (
                      KernelManifestMode.builtIn,
                      context.l10n.manifestModeBuiltIn,
                    ),
                    (
                      KernelManifestMode.custom,
                      context.l10n.manifestModeCustom,
                    ),
                    (
                      KernelManifestMode.localProxy,
                      context.l10n.manifestModeLocalProxy,
                    ),
                  ],
                  value: _mode,
                  onChanged: _saving
                      ? (_) {}
                      : (value) => setState(() => _mode = value),
                ),
              ),
              ui.generateSection(
                title: _mode == KernelManifestMode.builtIn
                    ? context.l10n.manifestProvider
                    : context.l10n.manifestSettings,
                items: [
                  if (_mode == KernelManifestMode.builtIn)
                    ui.FormRowSelect<String>(
                      title: context.l10n.manifestProvider,
                      value: _provider,
                      options: [
                        for (final entry in kernelManifestProviders.entries)
                          (entry.key, entry.value),
                      ],
                      onChanged: _saving
                          ? (_) {}
                          : (value) {
                              if (value != null) {
                                setState(() => _provider = value);
                              }
                            },
                    ),
                  if (_mode == KernelManifestMode.custom)
                    ui.FormRow(
                      title: context.l10n.manifestUrlTemplate,
                      trailing: ui.FormRowTextField(
                        controller: _customUrl,
                        keyboardType: TextInputType.url,
                        hintText:
                            'https://server/manifest/{appId}/{depotId}/{gid}',
                      ),
                    ),
                  if (_mode == KernelManifestMode.custom)
                    ui.FormRow(
                      title: context.l10n.manifestHeader,
                      trailing: ui.FormRowTextField(
                        controller: _customHeader,
                        hintText: 'User-Agent: example',
                      ),
                    ),
                  if (_mode == KernelManifestMode.custom)
                    ui.FormRowSelect<KernelManifestFormat>(
                      title: context.l10n.manifestFormat,
                      value: _format,
                      options: const [
                        (KernelManifestFormat.plain, 'plain'),
                        (KernelManifestFormat.steamrun, 'steamrun'),
                        (KernelManifestFormat.jsonContent, 'json content'),
                      ],
                      onChanged: _saving
                          ? (_) {}
                          : (value) {
                              if (value != null) {
                                setState(() => _format = value);
                              }
                            },
                    ),
                  if (_mode == KernelManifestMode.localProxy) ...[
                    if (widget.service.manifestCodeSources.isEmpty)
                      ui.ListItem<void>(
                        leading: const ui.GlyphIcon(ui.AppGlyphs.info),
                        title: Text(context.l10n.noManifestCodeSources),
                        subtitle: Text(
                          context.l10n.manifestLocalProxyDescription,
                        ),
                      )
                    else
                      for (final source in widget.service.manifestCodeSources)
                        ui.ListItem.checkbox(
                          key: ValueKey('manifest-code-source-${source.id}'),
                          leading: const ui.GlyphIcon(ui.AppGlyphs.code),
                          title: Text(source.name),
                          subtitle: Text(
                            source.description.isEmpty
                                ? source.id
                                : source.description,
                          ),
                          value: _sourceIds.contains(source.id),
                          onChanged: _saving
                              ? null
                              : (selected) => setState(() {
                                  if (selected == true) {
                                    _sourceIds.add(source.id);
                                  } else {
                                    _sourceIds.remove(source.id);
                                  }
                                }),
                        ),
                    ui.FormRowSwitch(
                      title: context.l10n.manifestFailover,
                      value: _failover,
                      onChanged: _saving
                          ? (_) {}
                          : (value) => setState(() => _failover = value),
                    ),
                  ],
                ],
                footer: _mode == KernelManifestMode.localProxy
                    ? context.l10n.manifestLocalProxyDescription
                    : _mode == KernelManifestMode.custom
                    ? context.l10n.manifestCustomHint
                    : null,
              ),
            ],
          ),
  );
}
