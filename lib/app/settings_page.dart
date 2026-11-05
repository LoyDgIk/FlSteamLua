import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_changelog.dart';
import '../core/app_release.dart';
import '../core/settings_store.dart';
import '../features/cloud/cloud_redirect_plugin_page.dart';
import '../features/kernel/kernel_settings_page.dart';
import '../features/library/lua_directories_page.dart';
import '../features/library/library_service.dart';
import '../features/network/network_preferences.dart';
import '../features/network/network_settings_page.dart';
import '../features/preferences/preferences_controller.dart';
import '../features/preferences/preferences_page.dart';
import '../features/steam/steam_close_action.dart';
import '../platform/desktop/update_service.dart';
import '../ui/localization.dart';
import '../ui/ui.dart' as ui;
import '../ui/context.dart';
import 'app_services.dart';
import 'data_management_page.dart';
import 'quick_start_page.dart';
import 'theme_settings_page.dart';
import 'widgets.dart';

String _themeValue(BuildContext context, String theme) => switch (theme) {
  'light' => context.l10n.light,
  'dark' => context.l10n.dark,
  _ => context.l10n.followSystem,
};

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.services,
    required this.onOpenPage,
  });

  final AppServices services;
  final void Function(Widget) onOpenPage;

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final locale = resolveAppLocale(settings.language);
    final coverSourceId = settings.get<String>('coverCdn', 'heybox');
    final coverSource = NetworkPreferences.coverSources.firstWhere(
      (source) => source.id == coverSourceId,
      orElse: () => NetworkPreferences.coverSources.first,
    );
    final kernel = services.kernel.installed;
    return ui.CommonScaffold(
      title: context.l10n.settings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.settings,
            items: [
              _SettingsRow(
                key: const ValueKey('quick-start-settings'),
                glyph: ui.AppGlyphs.layers,
                title: context.l10n.quickStart,
                onPressed: () => onOpenPage(QuickStartPage(services: services)),
              ),
              ui.ListItem<Locale>.options(
                key: const ValueKey('language-selector'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.language, size: 20),
                title: Text(context.l10n.displayLanguage),
                options: AppLocalizations.supportedLocales,
                value: locale,
                textBuilder: (option) =>
                    lookupAppLocalizations(option).languageName,
                onChanged: (option) => showAction(
                  context,
                  () => settings.set('language', option.toLanguageTag()),
                ),
              ),
              _SettingsRow(
                key: const ValueKey('theme-settings'),
                glyph: ui.AppGlyphs.paintbrush,
                title: context.l10n.theme,
                subtitle: Text(_themeValue(context, settings.theme)),
                onPressed: () =>
                    onOpenPage(ThemeSettingsPage(settings: settings)),
              ),
              _SettingsRow(
                key: const ValueKey('general-settings'),
                glyph: ui.AppGlyphs.settings,
                title: context.l10n.general,
                onPressed: () =>
                    onOpenPage(_GeneralSettingsPage(settings: settings)),
              ),
              _SettingsRow(
                key: const ValueKey('steam-file-settings'),
                glyph: ui.AppGlyphs.resources,
                title: context.l10n.steamAndGameFiles,
                subtitle: Text(
                  settings.steamPath.isEmpty
                      ? context.l10n.notConfigured
                      : settings.steamPath,
                ),
                onPressed: () => onOpenPage(SteamFilesPage(services: services)),
              ),
              _SettingsRow(
                key: const ValueKey('application-update-settings'),
                glyph: ui.AppGlyphs.cloudDownload,
                title: context.l10n.applicationUpdates,
                subtitle: Text('v$appVersion'),
                onPressed: () =>
                    onOpenPage(_UpdateSettingsPage(services: services)),
              ),
              _SettingsRow(
                key: const ValueKey('data-management-settings'),
                glyph: ui.AppGlyphs.broom,
                title: context.l10n.dataManagement,
                subtitle: Text(services.paths.root),
                onPressed: () =>
                    onOpenPage(DataManagementPage(services: services)),
              ),
            ],
            footer: context
                .l10n
                .automaticRefreshUpdateChecksFriendPresenceStartupAndOfflineMode,
          ),
          ui.generateSection(
            title: context.l10n.coreAndPlugins,
            items: [
              _SettingsRow(
                glyph: ui.AppGlyphs.memory,
                title: context.l10n.openSteamtoolCore,
                subtitle: Text(
                  kernel.installed
                      ? kernel.version ?? context.l10n.unknownVersion
                      : context.l10n.notInstalled,
                ),
                onPressed: () => onOpenPage(
                  KernelSettingsPage(
                    service: services.kernel,
                    tasks: services.tasks,
                    settings: settings,
                    steamProcess: services.library.processActions,
                  ),
                ),
              ),
              _SettingsRow(
                glyph: ui.AppGlyphs.cloudSync,
                title: context.l10n.cloudRedirectPlugin,
                subtitle: Text(
                  services.cloud.status.enabled
                      ? services.cloud.provider
                      : context.l10n.disabled,
                ),
                onPressed: () => onOpenPage(
                  CloudRedirectPluginPage(
                    service: services.cloud,
                    tasks: services.tasks,
                    steamProcess: services.library.processActions,
                  ),
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: context.l10n.downloadsAndNetwork,
            items: [
              _SettingsRow(
                glyph: ui.AppGlyphs.vpn,
                title: context.l10n.networkAndDownloadSources,
                subtitle: Text(coverSource.label(context.l10n)),
                onPressed: () => onOpenPage(
                  NetworkSettingsPage(
                    settings: settings,
                    tasks: services.tasks,
                  ),
                ),
              ),
              _SettingsRow(
                glyph: ui.AppGlyphs.sliders,
                title: context.l10n.backgroundAndSteamPreferences,
                onPressed: () => onOpenPage(
                  PreferencesPage(
                    controller: services.preferences,
                    settings: settings,
                  ),
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: context.l10n.other,
            items: [
              _SettingsRow(
                key: const ValueKey('about-settings'),
                glyph: ui.AppGlyphs.info,
                title: context.l10n.aboutFlsteamlua,
                subtitle: Text('v$appVersion'),
                onPressed: () => onOpenPage(const _AboutPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.glyph,
    required this.title,
    this.subtitle,
    required this.onPressed,
  });

  final ui.Glyph glyph;
  final String title;
  final Widget? subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ui.ListItem<void>(
    leading: ui.GlyphIcon(glyph, size: 20),
    title: Text(title),
    subtitle: subtitle,
    onTap: onPressed,
    trailing: ui.GlyphIcon(
      ui.AppGlyphs.chevronForward,
      size: 18,
      color: context.colorScheme.onSurfaceVariant,
    ),
  );
}

class _GeneralSettingsPage extends StatelessWidget {
  const _GeneralSettingsPage({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => ui.CommonScaffold(
      title: context.l10n.general,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: context.l10n.appearanceAndInteraction,
            items: [
              ui.ListItem.toggle(
                key: const ValueKey('sidebar-switch'),
                title: Text(context.l10n.expandedSidebar),
                value: settings.sidebarExpanded,
                onChanged: (value) => showAction(
                  context,
                  () => settings.set('sidebarExpanded', value),
                ),
              ),
              ui.ListItem.toggle(
                key: const ValueKey('tray-switch'),
                title: Text(context.l10n.keepRunningInTheTray),
                value: settings.minimizeToTray,
                onChanged: (value) => showAction(
                  context,
                  () => settings.set('minimizeToTray', value),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class SteamFilesPage extends StatefulWidget {
  const SteamFilesPage({super.key, required this.services});

  final AppServices services;

  @override
  State<SteamFilesPage> createState() => _SteamFilesPageState();
}

class _SteamFilesPageState extends State<SteamFilesPage> {
  late final TextEditingController _steamPath;
  String? _pathError;
  bool _saving = false;
  SteamUpdateControlSettings _updateControl =
      const SteamUpdateControlSettings();
  bool _updatesLoaded = false;
  bool _updatesBusy = false;

  SettingsStore get settings => widget.services.settings;

  @override
  void initState() {
    super.initState();
    _steamPath = TextEditingController(text: settings.steamPath);
    unawaited(_loadUpdateControl());
  }

  @override
  void dispose() {
    _steamPath.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory(TextEditingController controller) async {
    final localeText = context.l10n;
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: localeText.chooseAFolder,
      initialDirectory:
          controller.text.isNotEmpty &&
              await Directory(controller.text).exists()
          ? controller.text
          : null,
    );
    if (selected != null && mounted) setState(() => controller.text = selected);
  }

  Future<void> _editPath(
    TextEditingController controller,
    String title,
    String hint,
  ) async {
    final value = await ui.showFlDialog<String>(
      context: context,
      builder: (context) =>
          ui.InputDialog(title: title, value: controller.text, hintText: hint),
    );
    if (value != null && mounted) {
      setState(() => controller.text = value.trim());
    }
  }

  Future<void> _savePaths() async {
    final localeText = context.l10n;
    setState(() {
      _saving = true;
      _pathError = null;
    });
    try {
      final steam = _steamPath.text.trim();
      if (steam.isEmpty || !await File(p.join(steam, 'steam.exe')).exists()) {
        throw FormatException(
          localeText.chooseTheSteamInstallationFolderContainingSteamExe,
        );
      }
      await settings.set('steamPath', p.normalize(p.absolute(steam)));
      await widget.services.tasks.run(
        localeText.refreshGameLibrary,
        (task) => widget.services.library.scan(context: task),
      );
      await widget.services.kernel.syncManifestConfiguration();
      await widget.services.lanTransfer.refreshDirectories();
      await widget.services.preferences.refreshPlatformState();
      await _loadUpdateControl();
      if (mounted) {
        ui.showAppSuccess(
          context,
          localeText.pathsSavedAndGameLibraryRefreshed,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _pathError = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadUpdateControl() async {
    try {
      final value = await widget.services.library.readSteamUpdateControl();
      if (mounted) {
        setState(() {
          _updateControl = value;
          _updatesLoaded = true;
        });
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  Future<void> _setUpdateControl({
    bool? disableUpdateCheck,
    bool? disableForcedUpdate,
  }) async {
    if (_updatesBusy || !_updatesLoaded) return;
    try {
      if (!await confirmAndStopSteam(
        context,
        widget.services.library.processActions,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() => _updatesBusy = true);
      final value = await widget.services.library.setSteamUpdateControl(
        _updateControl.copyWith(
          disableUpdateCheck: disableUpdateCheck,
          disableForcedUpdate: disableForcedUpdate,
        ),
      );
      if (!mounted) return;
      setState(() => _updateControl = value);
      ui.showAppSuccess(context, context.l10n.operationCompleted);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _updatesBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.steamAndGameFiles,
    isLoading: _saving || _updatesBusy,
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        ui.pageContentTopInset,
        16,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        ui.generateSection(
          title: context.l10n.steamInstallationFolder,
          items: [
            ui.ListItem<void>(
              key: const ValueKey('steam-path-row'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
              title: Text(context.l10n.steamInstallationFolder),
              subtitle: Text(
                _steamPath.text.isEmpty
                    ? context.l10n.notConfigured
                    : _steamPath.text,
              ),
              onTap: () =>
                  showAction(context, () => _pickDirectory(_steamPath)),
              trailing: IconButton(
                key: const ValueKey('steam-path-field'),
                tooltip: context.l10n.edit,
                onPressed: () => _editPath(
                  _steamPath,
                  context.l10n.steamInstallationFolder,
                  context.l10n.theFolderContainingSteamExe,
                ),
                icon: const ui.GlyphIcon(ui.AppGlyphs.edit, size: 18),
              ),
            ),
            ui.ListItem<void>(
              key: const ValueKey('save-paths'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
              title: Text(context.l10n.saveAndRefreshLibrary),
              onTap: _saving ? null : _savePaths,
              trailing: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: ui.CommonCircleLoading(size: 18),
                    )
                  : const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
            ),
          ],
          footer:
              context.l10n.chooseTheSteamInstallationFolderContainingSteamExe,
        ),
        if (_pathError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ui.CommonCard(
              isError: true,
              inert: true,
              padding: const EdgeInsets.all(16),
              child: SelectableText(_pathError!),
            ),
          ),
        ui.generateSection(
          items: [
            ui.DecorationListItem(
              key: const ValueKey('lua-directories-settings'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.code),
              title: Text(context.l10n.luaDirectories),
              onPressed: settings.steamPath.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      ui.buildAppPageRoute(
                        builder: (_) => LuaDirectoriesPage(
                          steamPath: settings.steamPath,
                          onSaved: () async {
                            await widget.services.library.scan();
                            await widget.services.lanTransfer
                                .refreshDirectories();
                          },
                        ),
                      ),
                    ),
              trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
            ),
          ],
        ),
        ui.generateSection(
          title: context.l10n.steamUpdateControl,
          items: [
            ui.ListItem.toggle(
              key: const ValueKey('disable-steam-update-check'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.refresh),
              title: Text(context.l10n.steamUpdateChecks),
              subtitle: Text(
                _updateControl.disableUpdateCheck
                    ? context.l10n.blockedSetting
                    : context.l10n.allowedSetting,
              ),
              value: !_updateControl.disableUpdateCheck,
              onChanged: _updatesBusy || !_updatesLoaded
                  ? null
                  : (value) => _setUpdateControl(disableUpdateCheck: !value),
            ),
            ui.ListItem.toggle(
              key: const ValueKey('disable-steam-forced-update'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
              title: Text(context.l10n.steamForcedUpdates),
              subtitle: Text(
                _updateControl.disableForcedUpdate
                    ? context.l10n.blockedSetting
                    : context.l10n.allowedSetting,
              ),
              value: !_updateControl.disableForcedUpdate,
              onChanged: _updatesBusy || !_updatesLoaded
                  ? null
                  : (value) => _setUpdateControl(disableForcedUpdate: !value),
            ),
          ],
          footer: context.l10n.steamUpdateControlDescription,
        ),
      ],
    ),
  );
}

class _UpdateSettingsPage extends StatefulWidget {
  const _UpdateSettingsPage({required this.services});

  final AppServices services;

  @override
  State<_UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<_UpdateSettingsPage> {
  bool _checking = false;
  AppChangelog? _changelog;

  PreferencesController get preferences => widget.services.preferences;
  SettingsStore get settings => widget.services.settings;

  @override
  void initState() {
    super.initState();
    preferences.addListener(_changed);
    _loadChangelog();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadChangelog() async {
    try {
      final changelog = await loadLatestAppChangelog();
      if (mounted) setState(() => _changelog = changelog);
    } catch (error) {
      debugPrint('Could not load CHANGELOG.md: $error');
    }
  }

  @override
  void dispose() {
    preferences.removeListener(_changed);
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final release = await preferences.checkUpdates();
      if (!mounted) return;
      if (release == null) {
        ui.showAppFeedback(
          context,
          context.l10n.youAreUsingTheLatestPublishedVersion,
          level: ui.MessageLevel.success,
        );
      } else {
        await _showRelease(release);
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showRelease(ApplicationRelease release) async {
    final download = await ui.showFlDialog<bool>(
      context: context,
      builder: (context) => ui.CommonDialog(
        title: 'FlSteamLua ${release.version}',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.later),
          ),
          TextButton(
            onPressed: () => showAction(context, () async {
              if (!await launchUrl(
                release.url,
                mode: LaunchMode.externalApplication,
              )) {
                throw StateError('Cannot open release page');
              }
            }),
            child: Text(context.l10n.releasePage),
          ),
          if (release.windowsAsset != null)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.downloadUpdate),
            ),
        ],
        child: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: ui.ReleaseNotes(
              baseUrl: release.url,
              data: release.notes.isEmpty
                  ? context.l10n.noReleaseNotesWereProvided
                  : release.notes,
            ),
          ),
        ),
      ),
    );
    if (download != true || !mounted) return;
    final service = UpdateService(
      repository: appRepository,
      client: NetworkHttpClient(settings: settings),
      closeClient: true,
    );
    try {
      final file = await widget.services.tasks.run(
        context.l10n.downloadApplicationUpdate,
        (task) => service.downloadRelease(
          release,
          widget.services.paths.directory('downloads/updates'),
          task: task,
        ),
      );
      if (!mounted) return;
      final installer =
          Platform.isWindows && p.extension(file.path).toLowerCase() == '.exe';
      if (installer) {
        final install = await ui.showFlDialog<bool>(
          context: context,
          builder: (dialogContext) => ui.CommonDialog(
            title: context.l10n.updateReadyTitle,
            actions: [
              ui.CommonDialogAction(
                label: context.l10n.later,
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              ui.CommonDialogAction(
                label: context.l10n.installUpdateNow,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
            child: Text(context.l10n.updateReadyDescription),
          ),
        );
        if (install == true && mounted) {
          await Process.start(
            file.path,
            const [],
            mode: ProcessStartMode.detached,
          );
          return;
        }
      }
      if (mounted) {
        ui.showAppFeedback(
          context,
          context.l10n.updateDownloaded((file.path).toString()),
          level: ui.MessageLevel.success,
          actionState: ui.MessageActionState(
            actionText: context.l10n.openFolder2,
            action: () => Process.start('explorer.exe', [
              file.parent.path,
            ], mode: ProcessStartMode.detached),
          ),
        );
      }
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      service.dispose();
    }
  }

  Widget _changelogSection(BuildContext context, AppChangelog changelog) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ui.ListHeader(
          title: context.l10n.updateChangelog,
          trailing: ui.MetaChip(label: 'v${changelog.version}'),
        ),
        ui.CommonCard(
          key: const ValueKey('app-changelog'),
          inert: true,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (changelog.date case final date?)
                Text(
                  date,
                  style: ui.AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 16),
              ui.ReleaseNotes(
                data: changelog.markdown,
                baseUrl: Uri.https(
                  'github.com',
                  '/$appRepository/releases/tag/v${changelog.version}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.applicationUpdates,
    isLoading: _checking || preferences.isCheckingUpdate,
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        ui.pageContentTopInset,
        16,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        ui.generateSection(
          title: context.l10n.applicationUpdates,
          items: [
            ui.ListItem<void>(
              key: const ValueKey('check-update'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
              title: Text(context.l10n.checkForUpdates),
              subtitle: Text('v$appVersion'),
              onTap: _checking || preferences.isCheckingUpdate
                  ? null
                  : _checkUpdate,
              trailing: _checking || preferences.isCheckingUpdate
                  ? const SizedBox.square(
                      dimension: 18,
                      child: ui.CommonCircleLoading(size: 18),
                    )
                  : const ui.GlyphIcon(ui.AppGlyphs.refresh, size: 18),
            ),
            if (preferences.updateRelease != null)
              ui.ListItem<void>(
                key: const ValueKey('view-available-update'),
                leading: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload),
                title: Text(
                  context.l10n.viewNewVersion(
                    (preferences.updateRelease!.version).toString(),
                  ),
                ),
                onTap: () => _showRelease(preferences.updateRelease!),
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
          ],
        ),
        if (preferences.updateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ui.CommonCard(
              isError: true,
              inert: true,
              padding: const EdgeInsets.all(16),
              child: SelectableText('${preferences.updateError}'),
            ),
          ),
        if (_changelog case final changelog?) ...[
          const SizedBox(height: 18),
          _changelogSection(context, changelog),
        ],
      ],
    ),
  );
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: context.l10n.aboutFlsteamlua,
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        ui.pageContentTopInset,
        16,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            children: [
              Image.asset(
                'assets/branding/app.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.square(
                  dimension: 96,
                  child: ui.GlyphIcon(ui.AppGlyphs.appsList, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'FlSteamLua',
                style: ui.AppTextStyle.title2.of(context, emphasized: true),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ui.DashboardChip(
                    label: 'v$appVersion',
                    tone: ui.DashboardChipTone.ok,
                  ),
                  const ui.DashboardChip(label: 'GPL-3.0'),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  context
                      .l10n
                      .anOpenSourceDesktopCompanionForYourLibraryAchievementsAndSaves,
                  textAlign: TextAlign.center,
                  style: ui.AppTextStyle.subheadline
                      .of(context)
                      .copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
        ui.generateSection(
          title: context.l10n.other,
          items: [
            ui.ListItem<void>(
              key: const ValueKey('open-licenses'),
              leading: const ui.GlyphIcon(ui.AppGlyphs.resources),
              title: Text(context.l10n.openSourceLicenses),
              onTap: () => Navigator.of(context).push(
                ui.buildAppPageRoute(builder: (_) => const ui.AppLicensePage()),
              ),
              trailing: const ui.GlyphIcon(
                ui.AppGlyphs.chevronForward,
                size: 18,
              ),
            ),
            ui.ListItem<void>(
              leading: const ui.GlyphIcon(ui.AppGlyphs.code),
              title: const Text('FlClash'),
              onTap: () => showAction(context, () async {
                if (!await launchUrl(
                  Uri.parse('https://github.com/chen08209/FlClash'),
                  mode: LaunchMode.externalApplication,
                )) {
                  throw StateError('Cannot open FlClash');
                }
              }),
              trailing: const ui.GlyphIcon(ui.AppGlyphs.openExternal, size: 18),
            ),
            ui.ListItem<void>(
              leading: const ui.GlyphIcon(ui.AppGlyphs.clock),
              title: const Text('Fluent-Steam-Lua'),
              onTap: () => showAction(context, () async {
                if (!await launchUrl(
                  Uri.parse('https://github.com/huanyuejue/Fluent-Steam-Lua'),
                  mode: LaunchMode.externalApplication,
                )) {
                  throw StateError('Cannot open Fluent-Steam-Lua');
                }
              }),
              trailing: const ui.GlyphIcon(ui.AppGlyphs.openExternal, size: 18),
            ),
          ],
        ),
      ],
    ),
  );
}
