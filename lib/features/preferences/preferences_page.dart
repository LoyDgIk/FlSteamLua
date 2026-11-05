import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../ui/ui.dart' as ui;
import 'preferences_controller.dart';
import '../../ui/localization.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({
    super.key,
    required this.controller,
    required this.settings,
  });

  final PreferencesController controller;
  final SettingsStore settings;

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.settings.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.settings.removeListener(_changed);
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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ui.CommonScaffold(
      title: context.l10n.backgroundAndSteamPreferences,
      isLoading: _saving,
      actions: [
        ui.DashboardIconButton(
          key: const ValueKey('refresh-preference-state'),
          glyph: ui.AppGlyphs.refresh,
          tooltip: context.l10n.readSteamAndStartupState,
          onPressed: _saving
              ? null
              : () => _save(controller.refreshPlatformState),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.automaticTasks,
            items: [
              ui.ListItem.toggle(
                key: const ValueKey('auto-library-refresh'),
                title: Text(context.l10n.refreshTheLibraryAutomatically),
                value: controller.autoRefresh,
                onChanged: _saving
                    ? null
                    : (value) => _save(() => controller.setAutoRefresh(value)),
              ),
              _intervalRow(controller),
              ui.ListItem.toggle(
                key: const ValueKey('auto-update-check'),
                title: Text(
                  context.l10n.checkForApplicationUpdatesAutomatically,
                ),
                value: controller.autoUpdateCheck,
                onChanged: _saving
                    ? null
                    : (value) =>
                          _save(() => controller.setAutoUpdateCheck(value)),
              ),
              ui.ListItem.toggle(
                key: const ValueKey('auto-key-cache-update'),
                title: Text(context.l10n.updateKeySubscriptionsAutomatically),
                value: controller.autoKeyCacheUpdate,
                onChanged: _saving
                    ? null
                    : (value) =>
                          _save(() => controller.setAutoKeyCacheUpdate(value)),
              ),
              if (controller.updateRelease != null)
                ui.ListItem<void>(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                  title: Text(
                    context.l10n.newVersion(
                      (controller.updateRelease!.version).toString(),
                    ),
                  ),
                ),
            ],
          ),
          if (controller.updateError != null)
            _errorCard('${controller.updateError}'),
          ui.generateSection(
            title: context.l10n.startupAndSteam,
            items: [
              ui.ListItem.toggle(
                key: const ValueKey('startup-switch'),
                title: Text(context.l10n.launchFlsteamluaAtSignIn),
                value: controller.startupEnabled ?? false,
                onChanged: _saving || !controller.supportsStartup
                    ? null
                    : (value) =>
                          _save(() => controller.setStartupEnabled(value)),
              ),
              ui.ListItem.toggle(
                key: const ValueKey('steam-offline-switch'),
                title: Text(context.l10n.steamOfflineMode),
                value: controller.offlineEnabled ?? false,
                onChanged: _saving || controller.offlineEnabled == null
                    ? null
                    : (value) => _save(() => controller.setOfflineMode(value)),
              ),
              if (controller.offlineEnabled == null)
                ui.ListItem<void>(
                  leading: const ui.GlyphIcon(ui.AppGlyphs.info),
                  title: Text(
                    context
                        .l10n
                        .noRecentSteamAccountWasReadSignInToSteamThenRefreshTheState,
                  ),
                ),
            ],
          ),
          if (_error != null) _errorCard(_error!),
          if (controller.platformError != null)
            _errorCard('${controller.platformError}'),
          if (controller.backgroundError != null)
            _errorCard(
              context.l10n.lastBackgroundTaskFailure(
                (controller.backgroundError).toString(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _intervalRow(PreferencesController controller) {
    final enabled = !_saving && controller.autoRefresh;
    return ui.ListItem<int>.options(
      key: const ValueKey('library-refresh-interval'),
      title: Text(context.l10n.refreshInterval),
      options: const [15, 30, 60, 300],
      value: controller.refreshSeconds,
      textBuilder: (seconds) => context.l10n.seconds('$seconds'),
      onChanged: enabled
          ? (seconds) => _save(() => controller.setRefreshSeconds(seconds))
          : null,
    );
  }

  Widget _errorCard(String error) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ui.CommonCard(
      isError: true,
      inert: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(error),
      ),
    ),
  );
}
