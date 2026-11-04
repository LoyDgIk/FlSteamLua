import 'dart:async';
import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../../core/settings_store.dart';
import 'store_models.dart';

export 'store_models.dart';

class StoreService {
  static const _globalFallbackCountry = 'US';

  StoreService({
    http.Client? client,
    this.settings,
    String countryCode = 'CN',
    this.language = 'schinese',
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       countryCode = countryCode.trim().toUpperCase();

  final http.Client _client;
  final SettingsStore? settings;
  final bool _ownsClient;
  String countryCode;
  String language;
  final Duration timeout;

  Future<StorePageResult> search(
    String query, {
    StoreCategory category = StoreCategory.popular,
    int offset = 0,
    int count = 25,
    Future<void>? cancelled,
  }) async {
    if (offset < 0 || count < 1 || count > 100) {
      throw ArgumentError('offset must be >= 0 and count between 1 and 100');
    }
    final term = query.trim();
    final queryParameters = <String, String>{
      'start': '$offset',
      'count': '$count',
      'infinite': '1',
      'l': language,
      'cc': countryCode,
      'sort_by': '_ASC',
      if (term.isEmpty && category.filter.isNotEmpty)
        'filter': category.filter
      else if (term.isNotEmpty)
        'term': term,
    };
    final root = await _getJson(
      Uri.https('store.steampowered.com', '/search/results/', {
        ...queryParameters,
      }),
      cancelled: cancelled,
    );
    if (root['success'] == false || root['success'] == 0) {
      throw const StoreException('Steam could not complete the search request');
    }
    final resultHtml = root['results_html'];
    if (resultHtml is! String) {
      throw const StoreException('Steam returned an invalid search response');
    }
    final document = html.parseFragment(resultHtml);
    final rows = document.querySelectorAll('a.search_result_row');
    final seen = <int>{};
    final items = <StoreGame>[];
    for (final row in rows) {
      final appId = int.tryParse(
        (row.attributes['data-ds-appid'] ?? '').split(',').first.trim(),
      );
      final name = _clean(row.querySelector('.title')?.text ?? '');
      if (appId == null || appId <= 0 || name.isEmpty || !seen.add(appId)) {
        continue;
      }
      final image = row.querySelector('.search_capsule img');
      final price =
          row.querySelector('.discount_final_price') ??
          row.querySelector('.search_price');
      final platforms = <String>[];
      for (final node in row.querySelectorAll('.platform_img')) {
        if (node.classes.contains('win')) platforms.add('Windows');
        if (node.classes.contains('mac')) platforms.add('macOS');
        if (node.classes.contains('linux')) platforms.add('Linux');
      }
      items.add(
        StoreGame(
          appId: appId,
          name: name,
          headerImage: _image(
            image?.attributes['src'] ?? image?.attributes['data-src'],
            appId,
          ),
          priceText: _clean(price?.text ?? ''),
          releaseDate: _clean(
            row.querySelector('.search_released')?.text ?? '',
          ),
          platforms: List.unmodifiable(platforms.toSet()),
          comingSoon: category == StoreCategory.comingSoon && term.isEmpty,
        ),
      );
    }

    var resultItems = items;
    if (offset == 0 && term.isNotEmpty) {
      try {
        final catalogItems = await _searchCatalog(
          term,
          countryCode,
          cancelled: cancelled,
        );
        if (catalogItems.isNotEmpty) {
          final seen = items.map((item) => item.appId).toSet();
          resultItems = [
            ...catalogItems.where((item) => seen.add(item.appId)),
            ...items,
          ];
        }
        if (_includeAdultContent &&
            catalogItems.isEmpty &&
            countryCode != _globalFallbackCountry) {
          final globalItems = await _searchCatalog(
            term,
            _globalFallbackCountry,
            cancelled: cancelled,
          );
          if (globalItems.isNotEmpty) {
            resultItems = globalItems;
          }
        }
      } on StoreRequestCancelled {
        rethrow;
      } on StoreException {
        // The regional index is still usable when catalog search fails.
      }
    }

    // Steam counts search rows, including packages and bundles, not only apps.
    final nextOffset = offset + rows.length;
    final regionalTotal = _integer(root['total_count']) ?? nextOffset;
    final totalCount = resultItems.length > regionalTotal
        ? resultItems.length
        : regionalTotal;
    return StorePageResult(
      items: List.unmodifiable(resultItems),
      totalCount: totalCount,
      nextOffset: nextOffset,
      hasMore: rows.isNotEmpty && nextOffset < totalCount,
    );
  }

  Future<StoreGameDetails> details(int appId, {Future<void>? cancelled}) async {
    if (appId <= 0) throw ArgumentError.value(appId, 'appId');
    var root = await _getJson(
      Uri.https('store.steampowered.com', '/api/appdetails', {
        'appids': '$appId',
        'l': language,
        'cc': countryCode,
      }),
      cancelled: cancelled,
    );
    var envelope = _map(root['$appId']);
    if (envelope['success'] != true &&
        _includeAdultContent &&
        countryCode.toUpperCase() != _globalFallbackCountry) {
      root = await _getJson(
        Uri.https('store.steampowered.com', '/api/appdetails', {
          'appids': '$appId',
          'l': language,
          'cc': _globalFallbackCountry,
        }),
        cancelled: cancelled,
      );
      envelope = _map(root['$appId']);
    }
    if (envelope['success'] != true) {
      throw StoreException('Steam has no available details for AppID $appId');
    }
    final data = _map(envelope['data']);
    final name = data['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const StoreException('Steam returned invalid game details');
    }
    final release = _map(data['release_date']);
    final platformMap = _map(data['platforms']);
    final priceData = _map(data['price_overview']);
    StorePrice? price;
    if (priceData.isNotEmpty) {
      final initialMinor = _integer(priceData['initial']);
      final finalMinor = _integer(priceData['final']);
      if (initialMinor != null && finalMinor != null) {
        price = StorePrice(
          currency: _string(priceData['currency']),
          initialMinor: initialMinor,
          finalMinor: finalMinor,
          discountPercent: _integer(priceData['discount_percent']) ?? 0,
          initialFormatted: _string(priceData['initial_formatted']),
          finalFormatted: _string(priceData['final_formatted']),
        );
      }
    }
    final isFree = data['is_free'] == true;
    final websiteString = _string(data['website']);
    final website = Uri.tryParse(websiteString);
    return StoreGameDetails(
      appId: appId,
      name: name,
      headerImage: _image(data['header_image'], appId),
      price: price,
      priceText: price?.finalFormatted ?? '',
      releaseDate: _string(release['date']),
      comingSoon: release['coming_soon'] == true,
      isFree: isFree,
      platforms: [
        if (platformMap['windows'] == true) 'Windows',
        if (platformMap['mac'] == true) 'macOS',
        if (platformMap['linux'] == true) 'Linux',
      ],
      description: _clean(
        html
                .parseFragment(
                  _string(
                    data['short_description'],
                  ).replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' '),
                )
                .text ??
            '',
      ),
      type: _string(data['type'], 'game'),
      website:
          website != null &&
              (website.scheme == 'http' || website.scheme == 'https')
          ? website
          : null,
      dlcIds: _list(data['dlc'])
          .map(_integer)
          .whereType<int>()
          .where((id) => id > 0)
          .toSet()
          .toList(growable: false),
      screenshots: _list(data['screenshots'])
          .map((item) => _string(_map(item)['path_full']))
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      developers: _strings(data['developers']),
      publishers: _strings(data['publishers']),
      genres: _list(data['genres'])
          .map((item) => _string(_map(item)['description']))
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      achievementCount: _integer(_map(data['achievements'])['total']) ?? 0,
      controllerSupport: data['controller_support'] is String
          ? data['controller_support'] as String
          : null,
      requiredAge: _integer(data['required_age']) ?? 0,
    );
  }

  Future<List<StoreGame>> dlc(int appId, {Future<void>? cancelled}) async {
    final game = await details(appId, cancelled: cancelled);
    final result = <StoreGame>[];
    // Bound concurrent Store API calls to avoid bursts for games with many DLCs.
    for (var offset = 0; offset < game.dlcIds.length; offset += 4) {
      result.addAll(
        await Future.wait(
          game.dlcIds
              .skip(offset)
              .take(4)
              .map((id) => details(id, cancelled: cancelled)),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Future<void>? cancelled,
  }) async {
    try {
      final request = _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'FlSteamLua/0.1 (Windows; Flutter)',
              if (_includeAdultContent)
                'Cookie':
                    'birthtime=28800; mature_content=1; wants_mature_content=1; lastagecheckage=1-0-1990',
            },
          )
          .timeout(timeout);
      final response = cancelled == null
          ? await request
          : await Future.any<http.Response>([
              request,
              cancelled.then<http.Response>(
                (_) => throw const StoreRequestCancelled(),
              ),
            ]);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StoreException(
          'Steam request failed (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const StoreException('Steam returned invalid JSON data');
      }
      return decoded;
    } on StoreRequestCancelled {
      rethrow;
    } on StoreException {
      rethrow;
    } on TimeoutException catch (error) {
      throw StoreException('Steam request timed out', cause: error);
    } on http.ClientException catch (error) {
      throw StoreException(
        'Could not connect to Steam: ${error.message}',
        cause: error,
      );
    } on FormatException catch (error) {
      throw StoreException('Steam returned invalid JSON data', cause: error);
    }
  }

  Future<List<StoreGame>> _searchCatalog(
    String term,
    String country, {
    Future<void>? cancelled,
  }) async {
    final root = await _getJson(
      Uri.https('store.steampowered.com', '/api/storesearch/', {
        'term': term,
        'l': language,
        'cc': country,
      }),
      cancelled: cancelled,
    );
    final result = <StoreGame>[];
    for (final value in _list(root['items'])) {
      final item = _map(value);
      final appId = _integer(item['id']);
      final name = _clean(_string(item['name']));
      if (appId == null || appId <= 0 || name.isEmpty) continue;
      final platforms = _map(item['platforms']);
      final price = _map(item['price']);
      final isFree = price.isNotEmpty && _integer(price['final']) == 0;
      result.add(
        StoreGame(
          appId: appId,
          name: name,
          headerImage: _image(item['tiny_image'], appId),
          priceText: _formatCatalogPrice(price),
          platforms: [
            if (platforms['windows'] == true) 'Windows',
            if (platforms['mac'] == true) 'macOS',
            if (platforms['linux'] == true) 'Linux',
          ],
          isFree: isFree,
        ),
      );
    }
    return result;
  }

  Future<void> setCountryCode(String value) async {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
      throw const FormatException('Store region must be a two-letter code');
    }
    countryCode = normalized;
    await settings?.set('storeCountryCode', normalized);
  }

  bool get _includeAdultContent =>
      settings?.get<bool>('storeShowAdultContent', false) ?? false;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};
  static List<dynamic> _list(Object? value) => value is List ? value : const [];
  static List<String> _strings(Object? value) =>
      _list(value).whereType<String>().toList(growable: false);
  static String _string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;
  static int? _integer(Object? value) => value is num
      ? value.toInt()
      : value is String
      ? int.tryParse(value)
      : null;
  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _formatCatalogPrice(Map<String, dynamic> price) {
    final value = _integer(price['final']);
    if (value == null || value <= 0) return '';
    final currency = _string(price['currency']).toUpperCase();
    final symbol = switch (currency) {
      'USD' => r'$',
      'CNY' => '¥',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      _ => '',
    };
    final amount = (value / 100).toStringAsFixed(value % 100 == 0 ? 0 : 2);
    return symbol.isEmpty ? '$currency $amount' : '$symbol$amount';
  }

  static String _image(Object? value, int appId) {
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri.toString()
        : 'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$appId/header.jpg';
  }
}
