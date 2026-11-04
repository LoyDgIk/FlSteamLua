import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/ui.dart' as ui;
import 'network_preferences.dart';
import 'network_probe_sheet.dart';
import '../../ui/localization.dart';

class NetworkSettingsPage extends StatefulWidget {
  const NetworkSettingsPage({
    super.key,
    required this.settings,
    required this.tasks,
  });

  final SettingsStore settings;
  final TaskCenter tasks;

  @override
  State<NetworkSettingsPage> createState() => _NetworkSettingsPageState();
}

class _NetworkSettingsPageState extends State<NetworkSettingsPage> {
  late final NetworkPreferences _preferences;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preferences = NetworkPreferences(widget.settings);
    widget.settings.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_changed);
    _preferences.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCustomMirror() async {
    final value = await ui.showFlDialog<String>(
      context: context,
      builder: (context) => ui.InputDialog(
        title: context.l10n.customGithubMirror,
        value: _preferences.customMirror,
        hintText: context.l10n.githubMirrorHint,
      ),
    );
    if (value == null || !mounted) return;
    if (NetworkPreferences.normalizeMirror(value) == null) {
      setState(() => _error = context.l10n.githubMirrorHint);
      return;
    }
    await _save(
      () => _preferences.setMirror(
        NetworkPreferences.customMirrorId,
        custom: value,
      ),
    );
  }

  Future<void> _selectMirror(String? value) async {
    if (value == null) return;
    if (value == NetworkPreferences.customMirrorId) {
      await _editCustomMirror();
      return;
    }
    await _save(() => _preferences.setMirror(value));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving;
    final coverSource = NetworkPreferences.coverSources.firstWhere(
      (source) => source.id == _preferences.coverSourceId,
    );
    return ui.CommonScaffold(
      title: context.l10n.networkAndDownloadSources,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.gameCovers,
            items: [
              ui.ListItem<String>.options(
                key: const ValueKey('cover-source-selector'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.photos, size: 20),
                title: Text(context.l10n.preferredSource),
                options: [
                  for (final source in NetworkPreferences.coverSources)
                    source.id,
                ],
                value: coverSource.id,
                textBuilder: (id) => NetworkPreferences.coverSources
                    .firstWhere((source) => source.id == id)
                    .label(context.l10n),
                onChanged: busy
                    ? null
                    : (value) =>
                          _save(() => _preferences.setCoverSource(value)),
              ),
              ui.ListItem<void>(
                key: const ValueKey('test-cover-sources'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.speed, size: 20),
                title: Text(context.l10n.testCoverSources),
                onTap: () => showCoverProbeSheet(
                  context: context,
                  preferences: _preferences,
                  tasks: widget.tasks,
                ),
              ),
            ],
            footer: context
                .l10n
                .byDefaultUseTheOfficialImageUrlFromGameDetailsThisPreferenceAffectsArtworkOnlyNotStea,
          ),
          ui.generateSection(
            title: context.l10n.githubDownloads,
            items: [
              ui.ListItem<String>.options(
                key: const ValueKey('github-mirror-selector'),
                leading: const ui.GlyphIcon(
                  ui.AppGlyphs.cloudDownload,
                  size: 20,
                ),
                title: Text(context.l10n.preferredPublicDownloadSource),
                options: NetworkPreferences.mirrorOptions,
                value: _preferences.mirrorSelection,
                textBuilder: (host) => switch (host) {
                  'direct' => context.l10n.directDefault,
                  NetworkPreferences.customMirrorId =>
                    _preferences.customMirror.isEmpty
                        ? context.l10n.customGithubMirror
                        : _preferences.customMirror,
                  _ => host,
                },
                onChanged: busy ? null : (value) => _selectMirror(value),
              ),
              if (_preferences.mirrorSelection ==
                  NetworkPreferences.customMirrorId)
                ui.ListItem<void>(
                  key: const ValueKey('custom-github-mirror'),
                  leading: const ui.GlyphIcon(ui.AppGlyphs.link, size: 20),
                  title: Text(context.l10n.customGithubMirror),
                  subtitle: Text(
                    _preferences.customMirror.isEmpty
                        ? context.l10n.notConfigured
                        : _preferences.customMirror,
                  ),
                  onTap: busy ? null : _editCustomMirror,
                  trailing: IconButton(
                    tooltip: context.l10n.edit,
                    onPressed: busy ? null : _editCustomMirror,
                    icon: const ui.GlyphIcon(ui.AppGlyphs.edit, size: 18),
                  ),
                ),
              ui.ListItem<void>(
                key: const ValueKey('test-github-mirrors'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.speed, size: 20),
                title: Text(context.l10n.testPublicDownloadSources),
                onTap: () => showMirrorProbeSheet(
                  context: context,
                  preferences: _preferences,
                  tasks: widget.tasks,
                ),
              ),
            ],
            footer: context
                .l10n
                .mirrorsApplyOnlyToAnonymousPublicGithubFileDownloadsSignInApiTokenAndCredentialBearin,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ui.CommonCard(
              isError: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_error!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
