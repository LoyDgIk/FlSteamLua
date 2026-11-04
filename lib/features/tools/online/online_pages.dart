import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_paths.dart';
import '../../../core/game_entry.dart';
import '../../../core/settings_store.dart';
import '../../../core/task_center.dart';
import '../../../ui/context.dart';
import 'online_services.dart';
import 'online_widgets.dart';
import '../../../ui/localization.dart';
import '../../../ui/ui.dart' as ui;

export 'trainer_page.dart';

enum _OnlineFixMode { spacewar, fixes }

class OnlineFixToolsPage extends StatefulWidget {
  const OnlineFixToolsPage({
    super.key,
    required this.appPaths,
    required this.settings,
    required this.tasks,
    this.game,
    this.service,
  });
  final AppPaths appPaths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final GameEntry? game;
  final OnlineFixService? service;
  @override
  State<OnlineFixToolsPage> createState() => _OnlineFixToolsPageState();
}

class _OnlineFixToolsPageState extends State<OnlineFixToolsPage> {
  late final OnlineFixService _service;
  late final TextEditingController _query;
  final _scroll = ScrollController();
  List<OnlineFixEntry> _entries = [];
  bool _busy = false;
  bool _searched = false;
  int _feedPage = 0;
  int _feedPages = 1;
  _OnlineFixMode _mode = _OnlineFixMode.spacewar;
  OnlineFixFeed _feed = OnlineFixFeed.recent;
  Timer? _searchDebounce;
  late final ui.AppBarSearchState _searchState;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OnlineFixService(paths: widget.appPaths);
    _query = TextEditingController(text: widget.game?.name ?? '');
    _searchState = ui.AppBarSearchState(onSearch: _handleSearch);
    _mode = widget.game == null
        ? _OnlineFixMode.spacewar
        : _OnlineFixMode.fixes;
    _scroll.addListener(_handleScroll);
    if (widget.game != null) unawaited(_search());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _query.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  void _handleSearch(String value) {
    _query.text = value;
    if (mounted) setState(() {});
    _searchDebounce?.cancel();
    if (_mode != _OnlineFixMode.fixes) {
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 360),
      () => unawaited(_search()),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() {
    if (_query.text.trim().isEmpty) {
      setState(() => _feedPage = 0);
      return _loadFeed();
    }
    return _run(() async {
      final entries = await _service.search(_query.text);
      if (mounted) {
        setState(() {
          _entries = entries;
          _searched = true;
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    });
  }

  Future<void> _loadFeed({bool append = false}) => _run(() async {
    final target = append ? _feedPage + 1 : _feedPage;
    final page = await _service.feed(_feed, page: target + 1);
    if (!mounted) return;
    final seen = _entries.map((entry) => entry.url).toSet();
    setState(() {
      _entries = append
          ? [..._entries, ...page.entries.where((entry) => seen.add(entry.url))]
          : page.entries;
      _searched = false;
      _feedPage = page.page - 1;
      _feedPages = page.pages;
    });
    if (!append) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    _scheduleAutoLoad();
  });

  void _handleScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 360) return;
    unawaited(_loadMoreFeed());
  }

  Future<void> _loadMoreFeed() async {
    if (_busy || _searched || _hasSearchQuery || _feedPage + 1 >= _feedPages) {
      return;
    }
    await _loadFeed(append: true);
  }

  void _scheduleAutoLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.extentAfter <= 360) {
        unawaited(_loadMoreFeed());
      }
    });
  }

  Future<void> _showFeedJump() async {
    if (_feedPages <= 1) return;
    final page = await ui.showPageJumpSheet(
      context,
      currentPage: _feedPage + 1,
      totalPages: _feedPages,
    );
    if (page == null || !mounted) return;
    setState(() => _feedPage = page - 1);
    await _loadFeed();
  }

  Future<void> _setFeed(OnlineFixFeed feed) async {
    if (_busy || _feed == feed) return;
    setState(() {
      _feed = feed;
      _feedPage = 0;
      _entries = [];
    });
    await _loadFeed();
  }

  Future<void> _setMode(_OnlineFixMode mode) async {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == _OnlineFixMode.fixes &&
        _entries.isEmpty &&
        !_searched &&
        !_busy) {
      await _loadFeed();
    }
  }

  Future<void> _details(OnlineFixEntry entry) => ui.showModalSideSheet<void>(
    context: context,
    builder: (_) => _OnlineFixDetailSheet(
      service: _service,
      entry: entry,
      onDownload: _download,
    ),
  );

  Future<void> _download(
    OnlineFixDetail detail,
    OnlineFixFile file,
    String referer,
  ) async {
    try {
      final saved = await widget.tasks.run(
        '${context.l10n.downloadOnlineFix} · ${file.name}',
        (task) {
          return _service.download(
            file,
            referer: referer,
            detail: detail,
            task: task,
          );
        },
        appId: widget.game?.appId,
      );
      if (!mounted) return;
      ui.showAppFeedback(
        context,
        '${context.l10n.downloaded} · ${saved.path}',
        level: ui.MessageLevel.success,
        actionState: ui.MessageActionState(
          actionText: context.l10n.openFolder,
          action: () => launchUrl(Uri.directory(saved.parent.path)),
        ),
      );
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  bool get _hasSearchQuery => _query.text.trim().isNotEmpty;

  Widget _results() {
    if (_busy && _entries.isEmpty) {
      return const Center(child: ui.CommonCircleLoading.page());
    }
    if (_entries.isEmpty) {
      return ui.NullStatus(
        label: _searched
            ? context.l10n.noMatchingOnlineFixes
            : context.l10n.noOnlineFixesAvailable,
        illustration: _searched
            ? ui.NullStatusIllustration.search
            : ui.NullStatusIllustration.data,
        action: _searched
            ? ui.TonalButton(
                glyph: ui.AppGlyphs.openExternal,
                label: context.l10n.sourceOnlineFixMe,
                onPressed: () => launchUrl(
                  Uri.parse('https://online-fix.me/'),
                  mode: LaunchMode.externalApplication,
                ),
              )
            : ui.TonalButton(
                glyph: ui.AppGlyphs.refresh,
                label: context.l10n.reload3,
                onPressed: _loadFeed,
              ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        !_searched && _feedPages > 1 ? 80 : 24,
      ),
      children: [
        ui.generateSection(
          title: _searched
              ? context.l10n.onlineFixes
              : _feed == OnlineFixFeed.popular
              ? context.l10n.popular
              : context.l10n.recentUpdates,
          items: [
            for (final entry in _entries)
              ui.DecorationListItem(
                key: ValueKey('online-fix-${entry.url}'),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(ui.AppCorner.sm),
                  child: SizedBox(
                    width: 96,
                    height: 54,
                    child: OnlineCover(url: entry.coverUrl, height: 54),
                  ),
                ),
                title: Text(
                  entry.title,
                  key: ValueKey('online-fix-title-${entry.url}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    entry.tablet,
                    entry.version,
                    entry.updated,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _busy ? null : () => _details(entry),
                trailing: ui.CommonPopupBox(
                  targetBuilder: (open) => IconButton(
                    tooltip: context.l10n.fixActions,
                    onPressed: _busy ? null : open,
                    icon: const ui.GlyphIcon(ui.AppGlyphs.more, size: 20),
                  ),
                  popupBuilder: (_) => ui.CommonPopupMenu(
                    items: [
                      ui.CommonPopupMenuItem(
                        label: context.l10n.details,
                        onPressed: () => unawaited(_details(entry)),
                      ),
                      ui.CommonPopupMenuItem(
                        label: context.l10n.sourcePage,
                        onPressed: () => launchUrl(
                          Uri.parse(entry.url),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _patchView() => Stack(
    children: [
      Positioned.fill(child: _results()),
      if (!_searched && _feedPages > 1)
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Center(
            child: ui.PageProgressCapsule(
              page: _feedPage + 1,
              totalPages: _feedPages,
              loading: _busy,
              onPressed: () => unawaited(_showFeedJump()),
            ),
          ),
        ),
    ],
  );

  Widget _spacewarView() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      ui.generateSection(
        items: [
          ui.DecorationListItem(
            leading: const ui.GlyphIcon(ui.AppGlyphs.connections, size: 20),
            title: Text(context.l10n.spacewar480Multiplayer),
            subtitle: Text(
              context
                  .l10n
                  .withAKernelThatSupportsOst480MultiplayerLaunchOptionsMapTheGameToSpacewarBothPlayersM,
            ),
          ),
        ],
      ),
      ui.generateSection(
        title: context.l10n.setup,
        items: [
          ui.DecorationListItem(
            leading: const ui.GlyphIcon(ui.AppGlyphs.info, size: 20),
            title: Text(
              context
                  .l10n
                  .message1RightClickTheGameInSteamAndOpenProperties2AddTheOptionBelowToLaunchOptions3St,
            ),
          ),
          ui.DecorationListItem(
            leading: const ui.GlyphIcon(ui.AppGlyphs.keyboard, size: 20),
            title: const SelectableText('-onlinefix'),
            trailing: ui.CommonMinIconButtonTheme(
              child: IconButton(
                tooltip: context.l10n.copyLaunchOption,
                icon: const ui.GlyphIcon(ui.AppGlyphs.copy, size: 18),
                onPressed: () =>
                    Clipboard.setData(const ClipboardData(text: '-onlinefix')),
              ),
            ),
          ),
        ],
        footer: context
            .l10n
            .requiresACompatibleKernelAndLobbyBasedGameOnlyOneSuchGameCanRunAtATime,
      ),
    ],
  );

  Future<void> _openDownloads() async {
    final directory = widget.appPaths.directory('downloads/onlinefix');
    await directory.create(recursive: true);
    await launchUrl(Uri.directory(directory.path));
  }

  @override
  Widget build(BuildContext context) => ui.CommonScaffold(
    title: 'OnlineFix${widget.game == null ? '' : ' · ${widget.game!.name}'}',
    isLoading: _busy,
    searchState: _mode == _OnlineFixMode.fixes ? _searchState : null,
    searchHint: context.l10n.searchOnlineFixes,
    actions: [
      if (_mode == _OnlineFixMode.fixes && !_hasSearchQuery) ...[
        ui.DashboardIconButton(
          key: const ValueKey('online-fix-feed-recent'),
          glyph: ui.AppGlyphs.clock,
          tooltip: context.l10n.recentUpdates,
          selected: _feed == OnlineFixFeed.recent,
          onPressed: () => _setFeed(OnlineFixFeed.recent),
        ),
        ui.DashboardIconButton(
          key: const ValueKey('online-fix-feed-popular'),
          glyph: ui.AppGlyphs.star,
          tooltip: context.l10n.popular,
          selected: _feed == OnlineFixFeed.popular,
          onPressed: () => _setFeed(OnlineFixFeed.popular),
        ),
      ],
      IconButton(
        tooltip: context.l10n.downloads,
        onPressed: _openDownloads,
        icon: const ui.GlyphIcon(ui.AppGlyphs.resources, size: 20),
      ),
    ],
    body: Padding(
      padding: const EdgeInsets.only(top: ui.pageContentTopInset),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ui.SegmentedControl<_OnlineFixMode>(
              segments: [
                (_OnlineFixMode.spacewar, context.l10n.spacewar480),
                (_OnlineFixMode.fixes, context.l10n.onlineFixes),
              ],
              value: _mode,
              onChanged: _setMode,
            ),
          ),
          Expanded(
            child: ui.FadeEdge(
              extent: 24,
              child: AnimatedSwitcher(
                duration: context.motionDuration(ui.commonDuration),
                child: KeyedSubtree(
                  key: ValueKey(_mode),
                  child: _mode == _OnlineFixMode.spacewar
                      ? _spacewarView()
                      : _patchView(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OnlineFixDetailSheet extends StatefulWidget {
  const _OnlineFixDetailSheet({
    required this.service,
    required this.entry,
    required this.onDownload,
  });

  final OnlineFixService service;
  final OnlineFixEntry entry;
  final Future<void> Function(
    OnlineFixDetail detail,
    OnlineFixFile file,
    String referer,
  )
  onDownload;

  @override
  State<_OnlineFixDetailSheet> createState() => _OnlineFixDetailSheetState();
}

class _OnlineFixDetailSheetState extends State<_OnlineFixDetailSheet> {
  OnlineFixDetail? _detail;
  Object? _error;
  List<OnlineFixFile> _files = [];
  final List<(String, String)> _directories = [];
  var _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final detail = await widget.service.details(widget.entry.url);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _files = detail.files;
        _directories.clear();
        if (detail.directoryUrl.isNotEmpty) {
          _directories.add((context.l10n.fixFiles, detail.directoryUrl));
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _directory(String name, String url, {int? ancestor}) async {
    if (_loadingFiles) return;
    setState(() => _loadingFiles = true);
    try {
      final files = await widget.service.listFiles(url);
      if (!mounted) return;
      setState(() {
        _files = files;
        if (ancestor == null) {
          _directories.add((name, url));
        } else {
          _directories.removeRange(ancestor + 1, _directories.length);
        }
      });
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  void _download(OnlineFixDetail detail, OnlineFixFile file) {
    final referer = _directories.last.$2;
    Navigator.of(context).pop();
    unawaited(widget.onDownload(detail, file, referer));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final downloadable = _files
        .where((file) => !file.isDirectory)
        .toList(growable: false);
    return ui.SideSheetScaffold(
      title: detail?.entry.title ?? widget.entry.title,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.sourcePage,
          onPressed: () => launchUrl(
            Uri.parse(widget.entry.url),
            mode: LaunchMode.externalApplication,
          ),
          icon: const ui.GlyphIcon(ui.AppGlyphs.openExternal, size: 22),
        ),
        ui.SideSheetHeaderButton(
          tooltip: context.l10n.download,
          onPressed: detail == null || downloadable.isEmpty
              ? null
              : () => _download(detail, downloadable.first),
          icon: const ui.GlyphIcon(ui.AppGlyphs.cloudDownload, size: 22),
        ),
      ],
      body: _error != null
          ? ui.NullStatus(
              label: context.l10n.operationFailed,
              description: '$_error',
              illustration: ui.NullStatusIllustration.error,
            )
          : detail == null
          ? const Center(child: ui.CommonCircleLoading.page())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                ui.SideSheetScaffold.headerHeight + 16,
                16,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (detail.entry.coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ui.AppCorner.xl),
                    child: OnlineCover(url: detail.entry.coverUrl, height: 210),
                  ),
                ui.generateSection(
                  title: context.l10n.details,
                  items: [
                    if (detail.entry.version.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.code,
                          size: 20,
                        ),
                        title: Text(context.l10n.versionLabel),
                        subtitle: Text(
                          detail.entry.version,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (detail.entry.tablet.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.appsList,
                          size: 20,
                        ),
                        title: Text(context.l10n.platformLabel),
                        trailing: Text(detail.entry.tablet),
                      ),
                    if (detail.entry.updated.isNotEmpty)
                      ui.DecorationListItem(
                        leading: const ui.GlyphIcon(
                          ui.AppGlyphs.clock,
                          size: 20,
                        ),
                        title: Text(context.l10n.updatedLabel),
                        trailing: Text(detail.entry.updated),
                      ),
                    ui.DecorationListItem(
                      leading: const ui.GlyphIcon(ui.AppGlyphs.lock, size: 20),
                      title: Text(context.l10n.archivePasswordOnlineFixMe),
                      trailing: ui.CommonMinIconButtonTheme(
                        child: IconButton(
                          tooltip: context.l10n.copyPassword,
                          onPressed: () => Clipboard.setData(
                            const ClipboardData(text: 'online-fix.me'),
                          ),
                          icon: const ui.GlyphIcon(ui.AppGlyphs.copy, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                if (detail.instructions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ui.ExpandableTextCard(
                    title: context.l10n.instructionsOriginalText,
                    text: detail.instructions,
                    expandLabel: context.l10n.showMore,
                    collapseLabel: context.l10n.showLess,
                  ),
                ],
                if (_directories.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  if (_directories.length > 1) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (
                          var index = 0;
                          index < _directories.length;
                          index++
                        )
                          ui.TonalChip(
                            label: _directories[index].$1,
                            color: index == _directories.length - 1
                                ? context.colorScheme.primary.opacity15
                                : context.colorScheme.surfaceContainerHighest,
                            foregroundColor: index == _directories.length - 1
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurfaceVariant,
                            onPressed:
                                _loadingFiles ||
                                    index == _directories.length - 1
                                ? null
                                : () => _directory(
                                    _directories[index].$1,
                                    _directories[index].$2,
                                    ancestor: index,
                                  ),
                          ),
                      ],
                    ),
                    ui.generateSection(
                      items: [
                        ui.DecorationListItem(
                          leading: const ui.GlyphIcon(
                            ui.AppGlyphs.undo,
                            size: 20,
                          ),
                          title: Text(context.l10n.parentFolder),
                          onPressed: _loadingFiles
                              ? null
                              : () {
                                  final index = _directories.length - 2;
                                  unawaited(
                                    _directory(
                                      _directories[index].$1,
                                      _directories[index].$2,
                                      ancestor: index,
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  ui.CollapsibleSection(
                    label: context.l10n.fixFiles,
                    itemCount: _files.length,
                    loading: _loadingFiles,
                    initiallyExpanded: true,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return ui.DecorationListItem(
                        key: ValueKey('online-fix-file-${file.url}'),
                        leading: ui.GlyphIcon(
                          file.isDirectory
                              ? ui.AppGlyphs.resources
                              : ui.AppGlyphs.importFile,
                          size: 20,
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: file.size.isEmpty
                            ? null
                            : Text(
                                [
                                  file.updated,
                                  file.size,
                                ].where((item) => item.isNotEmpty).join(' · '),
                              ),
                        onPressed: file.isDirectory && !_loadingFiles
                            ? () => _directory(file.name, file.url)
                            : null,
                        trailing: file.isDirectory
                            ? const ui.GlyphIcon(
                                ui.AppGlyphs.chevronForward,
                                size: 18,
                              )
                            : IconButton(
                                tooltip: context.l10n.download,
                                onPressed: () => _download(detail, file),
                                icon: const ui.GlyphIcon(
                                  ui.AppGlyphs.cloudDownload,
                                  size: 20,
                                ),
                              ),
                      );
                    },
                  ),
                  if (!_loadingFiles && _files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.l10n.noFixFilesAreAvailableInThisDirectory,
                        style: context.listSubtitleStyle,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    context
                        .l10n
                        .filesAndInstructionsAreSavedInASeparateFolderForEachGame,
                    style: context.listSubtitleStyle,
                  ),
                ],
              ],
            ),
    );
  }
}
