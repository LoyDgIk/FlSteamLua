import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/system_appearance.dart';
import '../features/content_sources/content_sources_page.dart';
import '../features/kernel/kernel_settings_page.dart';
import '../features/library/lua_directories.dart';
import '../features/library/lua_directories_page.dart';
import '../features/network/network_settings_page.dart';
import '../ui/context.dart';
import '../ui/localization.dart';
import '../ui/ui.dart' as ui;
import 'app_services.dart';
import 'library_page.dart' show importLibraryFiles;
import 'settings_page.dart' show SteamFilesPage;
import 'theme_settings_page.dart';
import 'widgets.dart';

/// Owns the desktop caption and setup routes before the main shell is mounted.
class QuickStartWindow extends StatelessWidget {
  const QuickStartWindow({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const ui.WindowHeader(),
        Expanded(
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) =>
                  QuickStartPage(services: services, firstRun: true),
            ),
          ),
        ),
      ],
    ),
  );
}

class QuickStartPage extends StatefulWidget {
  const QuickStartPage({
    super.key,
    required this.services,
    this.firstRun = false,
  });

  final AppServices services;
  final bool firstRun;

  @override
  State<QuickStartPage> createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  int _step = 0;
  bool _leaving = false;
  bool _reading = true;
  bool _steamAvailable = false;
  String? _luaDirectory;

  AppServices get services => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshConfiguration());
  }

  Future<void> _refreshConfiguration() async {
    try {
      final steamPath = services.settings.steamPath;
      final available =
          steamPath.isNotEmpty &&
          await File(p.join(steamPath, 'steam.exe')).exists();
      final lua = available ? LuaDirectories(steamPath).read().first : null;
      await services.kernel.loadLocal();
      if (!mounted) return;
      setState(() {
        _steamAvailable = available;
        _luaDirectory = lua;
      });
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      ui.buildAppPageRoute<void>(
        builder: (_) => page,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
    if (mounted) await _refreshConfiguration();
  }

  void _set(String key, Object value) =>
      unawaited(showAction(context, () => services.settings.set(key, value)));

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await services.settings.set('quickStartDismissed', true);
      if (mounted && !widget.firstRun) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Widget _openRow({
    required String id,
    required ui.Glyph glyph,
    required String title,
    required String value,
    required VoidCallback? onPressed,
  }) => ui.DecorationListItem(
    key: ValueKey('quick-start-$id'),
    leading: ui.GlyphIcon(glyph, size: 24),
    title: Text(title),
    subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward, size: 18),
    onPressed: onPressed,
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(label, style: ui.AppTextStyle.headline.of(context)),
  );

  Widget _appearance() {
    final settings = services.settings;
    final texts = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            texts.displayLanguage,
            style: ui.AppTextStyle.headline.of(context),
          ),
        ),
        ui.SegmentedControl<Locale>(
          key: const ValueKey('quick-start-language'),
          segments: [
            for (final locale in AppLocalizations.supportedLocales)
              (locale, lookupAppLocalizations(locale).languageName),
          ],
          value: resolveAppLocale(settings.language),
          onChanged: (locale) => _set('language', locale.toLanguageTag()),
        ),
        _sectionLabel(texts.themeMode),
        ui.SegmentedControl<String>(
          key: const ValueKey('quick-start-theme-mode'),
          segments: [
            ('system', texts.followSystem),
            ('light', texts.light),
            ('dark', texts.dark),
          ],
          value: settings.theme,
          onChanged: (value) => _set('theme', value),
        ),
        _sectionLabel(texts.themeColor),
        ThemeColorSwatches(
          key: const ValueKey('quick-start-colors'),
          colors: settings.themeColors.isEmpty
              ? defaultThemeColors
              : settings.themeColors,
          selected: settings.themeFollowSystem ? null : settings.themeSeed,
          systemColor: Color(systemAccentColor()),
          onSelect: (color) => unawaited(
            showAction(context, () async {
              if (color != null) await settings.set('themeSeed', color);
              await settings.set('themeFollowSystem', color == null);
            }),
          ),
        ),
        _sectionLabel(texts.navigationBarStyle),
        ui.SegmentedControl<bool>(
          key: const ValueKey('quick-start-sidebar-style'),
          segments: [(false, texts.docked), (true, texts.floating)],
          value: settings.sidebarFloating,
          onChanged: (value) => _set('sidebarFloating', value),
        ),
        const SizedBox(height: 12),
        ui.generateGroup([
          ui.ListItem.toggle(
            key: const ValueKey('quick-start-expanded-sidebar'),
            title: Text(texts.expandedSidebar),
            value: settings.sidebarExpanded,
            onChanged: (value) => _set('sidebarExpanded', value),
          ),
        ]),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            key: const ValueKey('quick-start-more-theme'),
            onPressed: () => _open(ThemeSettingsPage(settings: settings)),
            child: Text(texts.quickStartMoreAppearance),
          ),
        ),
      ],
    );
  }

  Widget _folders() {
    final texts = context.l10n;
    return ui.generateGroup([
      _openRow(
        id: 'steam',
        glyph: ui.AppGlyphs.resources,
        title: texts.steamInstallationFolder,
        value: services.settings.steamPath.isEmpty
            ? texts.notConfigured
            : services.settings.steamPath,
        onPressed: () => _open(SteamFilesPage(services: services)),
      ),
      _openRow(
        id: 'lua',
        glyph: ui.AppGlyphs.code,
        title: texts.luaDirectories,
        value: _luaDirectory ?? texts.selectYourSteamFolderInSettingsFirst,
        onPressed: !_steamAvailable
            ? null
            : () => _open(
                LuaDirectoriesPage(
                  steamPath: services.settings.steamPath,
                  onSaved: () async {
                    await services.library.scan();
                    await services.lanTransfer.refreshDirectories();
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _prepare() {
    final texts = context.l10n;
    final kernel = services.kernel.installed;
    final sources = services.contentSources.sources
        .where((source) => source.enabled && source.configurationComplete)
        .length;
    return ui.generateGroup([
      _openRow(
        id: 'kernel',
        glyph: ui.AppGlyphs.memory,
        title: texts.openSteamtoolCore,
        value: !_steamAvailable
            ? texts.selectYourSteamFolderInSettingsFirst
            : kernel.installed
            ? '${kernel.version ?? texts.unknownVersion} · ${kernel.enabled ? texts.configurationEnabled : texts.disabled}'
            : texts.notInstalled,
        onPressed: !_steamAvailable
            ? null
            : () => _open(
                KernelSettingsPage(
                  service: services.kernel,
                  tasks: services.tasks,
                  settings: services.settings,
                  steamProcess: services.library.processActions,
                ),
              ),
      ),
      _openRow(
        id: 'sources',
        glyph: ui.AppGlyphs.link,
        title: texts.contentSources,
        value: texts.quickStartSources(sources),
        onPressed: () => _open(
          ContentSourcesPage(
            registry: services.contentSources,
            tasks: services.tasks,
            onImportLocal: () => importLibraryFiles(context, services),
          ),
        ),
      ),
      _openRow(
        id: 'network',
        glyph: ui.AppGlyphs.vpn,
        title: texts.networkAndDownloadSources,
        value: texts.quickStartNetworkHint,
        onPressed: () => _open(
          NetworkSettingsPage(
            settings: services.settings,
            tasks: services.tasks,
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      services.settings,
      services.kernel,
      services.contentSources,
    ]),
    builder: (context, _) {
      final texts = context.l10n;
      final titles = [
        texts.quickStartAppearance,
        texts.quickStartFolders,
        texts.quickStartPrepare,
      ];
      final headings = [
        texts.quickStartAppearanceTitle,
        texts.quickStartFoldersTitle,
        texts.quickStartPrepareTitle,
      ];
      final descriptions = [
        texts.quickStartAppearanceHint,
        texts.quickStartFoldersHint,
        texts.quickStartPrepareHint,
      ];
      final glyphs = [
        ui.AppGlyphs.paintbrush,
        ui.AppGlyphs.resources,
        ui.AppGlyphs.layers,
      ];
      return ui.CommonScaffold(
        title: texts.quickStart,
        isLoading: _leaving || _reading,
        actions: [
          TextButton(
            key: const ValueKey('quick-start-skip'),
            onPressed: _leaving ? null : _finish,
            child: Text(widget.firstRun ? texts.quickStartSkip : texts.close),
          ),
        ],
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final inset = constraints.maxWidth < 600 ? 20.0 : 40.0;
                final content = AnimatedSwitcher(
                  duration: context.motionDuration(
                    const Duration(milliseconds: 260),
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final child in previous)
                        ExcludeFocus(child: IgnorePointer(child: child)),
                      ?current,
                    ],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: animation.drive(
                        Tween(begin: const Offset(0, .025), end: Offset.zero),
                      ),
                      child: child,
                    ),
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey('quick-start-step-$_step'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide) ...[
                          Text(
                            headings[_step],
                            style: ui.AppTextStyle.title1.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        switch (_step) {
                          0 => _appearance(),
                          1 => _folders(),
                          _ => _prepare(),
                        },
                      ],
                    ),
                  ),
                );
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    ui.pageContentTopInset + 12,
                    inset,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: [
                      ui.SegmentedControl<int>(
                        key: const ValueKey('quick-start-steps'),
                        segments: [
                          for (var i = 0; i < titles.length; i++)
                            (i, titles[i]),
                        ],
                        value: _step,
                        onChanged: (value) {
                          if (!_leaving) setState(() => _step = value);
                        },
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (wide) ...[
                              SizedBox(
                                width: 290,
                                child: _WelcomePanel(
                                  title: headings[_step],
                                  description: descriptions[_step],
                                  glyph: glyphs[_step],
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                            Expanded(child: content),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        key: const ValueKey('quick-start-navigation'),
                        children: [
                          SizedBox(
                            width: 104,
                            child: _step == 0
                                ? null
                                : TextButton(
                                    key: const ValueKey('quick-start-back'),
                                    onPressed: _leaving
                                        ? null
                                        : () => setState(() => _step--),
                                    child: Text(texts.quickStartBack),
                                  ),
                          ),
                          Expanded(
                            child: Text(
                              texts.quickStartStep(_step + 1, titles.length),
                              textAlign: TextAlign.center,
                              style: ui.AppTextStyle.caption1.of(context),
                            ),
                          ),
                          FilledButton(
                            key: const ValueKey('quick-start-next'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 48),
                            ),
                            onPressed: _leaving
                                ? null
                                : _step == 2
                                ? _finish
                                : () => setState(() => _step++),
                            child: Text(
                              _step == 2
                                  ? (widget.firstRun
                                        ? texts.quickStartEnter
                                        : texts.done)
                                  : texts.quickStartNext,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.title,
    required this.description,
    required this.glyph,
  });

  final String title;
  final String description;
  final ui.Glyph glyph;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.colorScheme.primaryContainer,
                context.colorScheme.surface,
              ],
            ),
            shape: ui.AppShape.xxl,
          ),
          child: AnimatedSwitcher(
            duration: context.motionDuration(const Duration(milliseconds: 200)),
            child: ui.GlyphIcon(
              glyph,
              key: ValueKey(title),
              size: 36,
              color: context.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'FlSteamLua',
          style: ui.AppTextStyle.subheadline
              .of(context)
              .copyWith(color: context.colorScheme.primary),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: ui.AppTextStyle.largeTitle.of(context, emphasized: true),
        ),
        const SizedBox(height: 18),
        Text(
          description,
          style: ui.AppTextStyle.callout
              .of(context)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
