import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/game_entry.dart';
import '../../ui/context.dart';
import '../network/network_cover_image.dart';
import 'store_service.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;

class StorePage extends StatefulWidget {
  const StorePage({
    super.key,
    required this.service,
    required this.onOpenGame,
    this.onAddGame,
    this.language = 'zh',
  });

  final StoreService service;
  final ValueChanged<GameEntry> onOpenGame;
  final Future<void> Function(GameEntry)? onAddGame;
  final String language;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 25;
  static const _regions = [
    'CN',
    'HK',
    'TW',
    'US',
    'JP',
    'KR',
    'SG',
    'GB',
    'DE',
    'FR',
    'CA',
    'AU',
    'BR',
    'RU',
    'AR',
  ];

  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _items = <StoreGame>[];
  final _adding = <int>{};
  StoreCategory _category = StoreCategory.all;
  Completer<void>? _cancel;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _nextOffset = 0;
  int _total = 0;
  int _page = 1;
  String? _error;
  DateTime? _lastLoadMoreAttempt;
  int _generation = 0;
  Timer? _searchDebounce;
  late final ui.AppBarSearchState _searchState;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchState = ui.AppBarSearchState(
      onSearch: (query) {
        _search.text = query;
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 350), _reload);
      },
    );
    _scroll.addListener(_handleScroll);
    _reload();
  }

  int get _totalPages => _total <= 0 ? 1 : ((_total - 1) ~/ _pageSize) + 1;

  @override
  void didUpdateWidget(StorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) _reload();
  }

  Future<void> _reload() => _loadPage(1);

  Future<void> _loadPage(int targetPage) async {
    final generation = ++_generation;
    if (!(_cancel?.isCompleted ?? true)) _cancel!.complete();
    final cancel = _cancel = Completer<void>();
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _items.clear();
      _hasMore = false;
      _page = targetPage;
    });
    try {
      final page = await widget.service.search(
        _search.text,
        category: _category,
        offset: (targetPage - 1) * _pageSize,
        count: _pageSize,
        cancelled: cancel.future,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextOffset = page.nextOffset;
        _total = page.totalCount;
        _hasMore = page.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
      _scheduleAutoLoad();
    } on StoreRequestCancelled {
      // A newer query owns the page now.
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _more({bool retry = false}) async {
    if (_loadingMore || !_hasMore) return;
    if (_error != null && !retry) return;
    final generation = _generation;
    _lastLoadMoreAttempt = DateTime.now();
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await widget.service.search(
        _search.text,
        category: _category,
        offset: _nextOffset,
        count: _pageSize,
        cancelled: _cancel?.future,
      );
      if (!mounted || generation != _generation) return;
      final seen = _items.map((item) => item.appId).toSet();
      setState(() {
        _items.addAll(page.items.where((item) => seen.add(item.appId)));
        _nextOffset = page.nextOffset;
        _total = page.totalCount;
        _hasMore = page.hasMore;
        _page++;
      });
      _scheduleAutoLoad();
    } on StoreRequestCancelled {
      // A newer query owns the page now.
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _handleScroll() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 400) return;
    if (_error == null) {
      unawaited(_more());
      return;
    }
    final attempted = _lastLoadMoreAttempt;
    if (attempted == null ||
        DateTime.now().difference(attempted) >= const Duration(seconds: 1)) {
      unawaited(_more(retry: true));
    }
  }

  void _scheduleAutoLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.extentAfter <= 400) {
        unawaited(_more());
      }
    });
  }

  Future<void> _showPageJump() async {
    if (_totalPages <= 1) return;
    final page = await ui.showPageJumpSheet(
      context,
      currentPage: _page,
      totalPages: _totalPages,
    );
    if (page == null || !mounted || page == _page) return;
    await _loadPage(page);
  }

  Future<void> _retry() => _items.isEmpty ? _reload() : _more(retry: true);

  Future<void> _add(StoreGame game) async {
    final callback = widget.onAddGame;
    if (callback == null || !_adding.add(game.appId)) return;
    setState(() {});
    try {
      await callback(game.toGameEntry());
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      _adding.remove(game.appId);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    if (!(_cancel?.isCompleted ?? true)) _cancel!.complete();
    _searchDebounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ui.CommonScaffold(
      title: context.l10n.store,
      searchState: _searchState,
      searchHint: context.l10n.searchGameTitles,
      actions: [
        ui.CommonPopupBox(
          key: const ValueKey('store-region-menu'),
          targetBuilder: (open) => ui.DashboardIconButton(
            glyph: ui.AppGlyphs.language,
            tooltip:
                '${context.l10n.storeRegion} · '
                '${_regionText(context, widget.service.countryCode)}',
            onPressed: _loading ? null : open,
          ),
          popupBuilder: (_) => ui.CommonPopupMenu(
            items: [
              for (final region in _regions)
                ui.CommonPopupMenuItem(
                  label: '${_regionText(context, region)} · $region',
                  checked: region == widget.service.countryCode,
                  onPressed: () => unawaited(_setRegion(region)),
                ),
            ],
          ),
        ),
        ui.CommonPopupBox(
          key: const ValueKey('store-category-menu'),
          targetBuilder: (open) => ui.DashboardIconButton(
            glyph: _categoryGlyph,
            tooltip: _categoryLabel(context),
            onPressed: _loading ? null : open,
          ),
          popupBuilder: (_) => ui.CommonPopupMenu(
            items: [
              for (final category in StoreCategory.values)
                ui.CommonPopupMenuItem(
                  label: _categoryText(context, category),
                  checked: category == _category,
                  onPressed: () {
                    setState(() => _category = category);
                    _search.clear();
                    _reload();
                  },
                ),
            ],
          ),
        ),
        ui.DashboardIconButton(
          glyph: ui.AppGlyphs.refresh,
          tooltip: context.l10n.reload3,
          onPressed: _loading ? null : _reload,
        ),
        ui.DashboardIconButton(
          key: const ValueKey('store-adult-content'),
          glyph: _showAdultContent ? ui.AppGlyphs.eye : ui.AppGlyphs.eyeOff,
          tooltip: _showAdultContent
              ? context.l10n.hideAdultContent
              : context.l10n.showAdultContent,
          selected: _showAdultContent,
          onPressed: _loading ? null : _toggleAdultContent,
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: ui.pageContentTopInset,
                  bottom: 8,
                ),
                child: ui.CommonCard(
                  isError: true,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const ui.GlyphIcon(ui.AppGlyphs.wifiOff, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!)),
                      TextButton(
                        onPressed: () => unawaited(_retry()),
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ui.NullStatusSwitcher(
                      isLoading: _loading && _items.isEmpty,
                      isEmpty: !_loading && _items.isEmpty,
                      isSearching: _search.text.trim().isNotEmpty,
                      nullStatus: ui.NullStatus(
                        label: _error == null
                            ? context.l10n.noMatchingGames2
                            : context.l10n.storeUnavailable,
                        illustration: ui.NullStatusIllustration.steam,
                        action: FilledButton.icon(
                          onPressed: _reload,
                          icon: const ui.GlyphIcon(
                            ui.AppGlyphs.refresh,
                            size: 18,
                          ),
                          label: Text(context.l10n.reload3),
                        ),
                      ),
                      searchStatus: ui.NullStatus(
                        label: context.l10n.noMatchingGames2,
                        illustration: ui.NullStatusIllustration.search,
                      ),
                      child: _content(
                        context,
                        topPadding: _error == null ? ui.pageContentTopInset : 0,
                      ),
                    ),
                  ),
                  if (_totalPages > 1 && _items.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: ui.PageProgressCapsule(
                          page: _page,
                          totalPages: _totalPages,
                          loading: _loadingMore,
                          onPressed: () => unawaited(_showPageJump()),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ui.Glyph get _categoryGlyph => switch (_category) {
    StoreCategory.all => ui.AppGlyphs.appsList,
    StoreCategory.popular => ui.AppGlyphs.star,
    StoreCategory.newReleases => ui.AppGlyphs.addCircle,
    StoreCategory.specials => ui.AppGlyphs.filter,
    StoreCategory.comingSoon => ui.AppGlyphs.clock,
  };

  String _categoryLabel(BuildContext context) =>
      _categoryText(context, _category);

  String _categoryText(BuildContext context, StoreCategory category) =>
      switch (category) {
        StoreCategory.all => context.l10n.allGames,
        StoreCategory.popular => context.l10n.popular,
        StoreCategory.newReleases => context.l10n.newReleases,
        StoreCategory.specials => context.l10n.specials,
        StoreCategory.comingSoon => context.l10n.comingSoon,
      };

  String _regionText(BuildContext context, String region) => switch (region) {
    'CN' => context.l10n.regionChinaMainland,
    'HK' => context.l10n.regionHongKong,
    'TW' => context.l10n.regionTaiwan,
    'US' => context.l10n.regionUnitedStates,
    'JP' => context.l10n.regionJapan,
    'KR' => context.l10n.regionSouthKorea,
    'SG' => context.l10n.regionSingapore,
    'GB' => context.l10n.regionUnitedKingdom,
    'DE' => context.l10n.regionGermany,
    'FR' => context.l10n.regionFrance,
    'CA' => context.l10n.regionCanada,
    'AU' => context.l10n.regionAustralia,
    'BR' => context.l10n.regionBrazil,
    'RU' => context.l10n.regionRussia,
    'AR' => context.l10n.regionArgentina,
    _ => region,
  };

  Future<void> _setRegion(String region) async {
    if (region == widget.service.countryCode) return;
    try {
      await widget.service.setCountryCode(region);
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    }
  }

  bool get _showAdultContent =>
      widget.service.settings?.get<bool>('storeShowAdultContent', false) ??
      false;

  Future<void> _toggleAdultContent() async {
    final settings = widget.service.settings;
    if (settings == null) return;
    await settings.set('storeShowAdultContent', !_showAdultContent);
    if (mounted) await _reload();
  }

  Widget _content(BuildContext context, {required double topPadding}) {
    if (_items.isEmpty) return const SizedBox.expand();
    return CustomScrollView(
      controller: _scroll,
      key: const PageStorageKey('store-grid'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: 4 + topPadding, bottom: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              context.l10n.ofGames(
                (_items.length).toString(),
                (_total).toString(),
              ),
            ),
          ),
        ),
        SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 560,
            mainAxisExtent:
                164 + (MediaQuery.textScalerOf(context).scale(100) - 100),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) => _card(context, _items[index]),
        ),
        SliverPadding(
          padding: EdgeInsets.only(top: 24, bottom: _totalPages > 1 ? 76 : 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: _loadingMore
                  ? const ui.CommonCircleLoading(size: 24)
                  : const SizedBox(height: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, StoreGame game) {
    return ui.CommonCard(
      radius: 26,
      onPressed: () => widget.onOpenGame(game.toGameEntry()),
      enterActionsOnRight: true,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 146,
                height: 96,
                child: widget.service.settings == null
                    ? ui.AppImage(
                        url: game.headerImage,
                        fit: BoxFit.cover,
                        placeholderGlyph: ui.AppGlyphs.photos,
                      )
                    : NetworkCoverImage(
                        settings: widget.service.settings!,
                        appId: game.appId,
                        url: game.headerImage,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => _storeImageFallback(context),
                      ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ui.AppTextStyle.headline.of(
                      context,
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    game.isFree
                        ? context.l10n.free
                        : game.priceText.isEmpty
                        ? context.l10n.viewStorePrice
                        : game.priceText,
                    style: ui.AppTextStyle.subheadline
                        .of(context, emphasized: true)
                        .copyWith(color: context.colorScheme.primary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'AppID ${game.appId}',
                          style: ui.AppTextStyle.caption1
                              .of(context)
                              .copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onOpenGame(game.toGameEntry()),
                        child: Text(context.l10n.details),
                      ),
                      if (widget.onAddGame != null)
                        IconButton(
                          tooltip: context.l10n.addToLibrary,
                          onPressed: _adding.contains(game.appId)
                              ? null
                              : () => _add(game),
                          icon: _adding.contains(game.appId)
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: ui.CommonCircleLoading(size: 16),
                                )
                              : const ui.GlyphIcon(
                                  ui.AppGlyphs.addCircle,
                                  size: 20,
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
  }

  Widget _storeImageFallback(BuildContext context) => ColoredBox(
    color: context.colorScheme.surfaceContainerHighest,
    child: Center(
      child: ui.GlyphIcon(
        ui.AppGlyphs.photos,
        size: 32,
        color: context.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
