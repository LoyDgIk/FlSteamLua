import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/store/store_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Steam Store search', () {
    test(
      'parses categories, prices and entities without claiming ownership',
      () async {
        final service = StoreService(
          client: MockClient((request) async {
            expect(request.url.path, '/search/results/');
            expect(request.url.queryParameters['filter'], 'specials');
            expect(request.url.queryParameters['cc'], 'CN');
            return _json({
              'total_count': '2',
              'results_html': '''
            <a class="search_result_row" data-ds-appid="440">
              <div class="search_capsule"><img src="https://cdn.example/440.jpg"></div>
              <div class="search_name"><span class="title">Team &amp; Fortress</span><span class="platform_img win"></span><span class="platform_img linux"></span></div>
              <div class="search_price"><strike>¥ 98</strike><div class="discount_final_price">¥ 49</div></div>
              <div class="search_released">10 Oct, 2007</div>
            </a>
          ''',
            });
          }),
        );
        final page = await service.search('', category: StoreCategory.specials);
        expect(page.items.single.name, 'Team & Fortress');
        expect(page.items.single.priceText, '¥ 49');
        expect(page.items.single.platforms, ['Windows', 'Linux']);
        expect(
          page.items.single.toGameEntry().ownership,
          GameOwnership.unknown,
        );
        expect(page.nextOffset, 1);
        expect(page.hasMore, isTrue);
      },
    );

    test(
      'paginates by raw rows including unsupported packages and duplicates',
      () async {
        final service = StoreService(
          client: MockClient((request) async {
            expect(request.url.queryParameters['start'], '25');
            expect(request.url.queryParameters['term'], 'Portal 2');
            expect(request.url.queryParameters.containsKey('filter'), isFalse);
            return _json({
              'total_count': 28,
              'results_html': '''
            <a class="search_result_row" data-ds-packageid="1"><span class="title">Bundle</span></a>
            <a class="search_result_row" data-ds-appid="620"><span class="title">Portal 2</span></a>
            <a class="search_result_row" data-ds-appid="620"><span class="title">Portal 2</span></a>
          ''',
            });
          }),
        );
        final page = await service.search('Portal 2', offset: 25);
        expect(page.items, hasLength(1));
        expect(page.nextOffset, 28);
        expect(page.hasMore, isFalse);
      },
    );

    test('empty result terminates pagination despite a stale total', () async {
      final service = StoreService(
        client: MockClient(
          (_) async => _json({'total_count': 100, 'results_html': ''}),
        ),
      );
      expect((await service.search('missing')).hasMore, isFalse);
    });

    test(
      'all games omits filter and mature mode adds session cookies',
      () async {
        final temp = await Directory.systemTemp.createTemp('flsl-store-');
        final paths = AppPaths(temp.path);
        await paths.initialize();
        final settings = SettingsStore(paths);
        await settings.load();
        await settings.set('storeShowAdultContent', true);
        String? cookie;
        final service = StoreService(
          settings: settings,
          client: MockClient((request) async {
            expect(request.url.queryParameters.containsKey('filter'), isFalse);
            cookie = request.headers['Cookie'];
            return _json({'total_count': 0, 'results_html': ''});
          }),
        );

        await service.search('', category: StoreCategory.all);
        expect(cookie, contains('mature_content=1'));
        expect(cookie, contains('wants_mature_content=1'));
        service.dispose();
        settings.dispose();
        await temp.delete(recursive: true);
      },
    );

    test(
      'adult search falls back to the global catalog for regional titles',
      () async {
        final temp = await Directory.systemTemp.createTemp('flsl-store-');
        final paths = AppPaths(temp.path);
        await paths.initialize();
        final settings = SettingsStore(paths);
        await settings.load();
        await settings.set('storeShowAdultContent', true);
        final service = StoreService(
          settings: settings,
          client: MockClient((request) async {
            if (request.url.path == '/search/results/') {
              return _json({'total_count': 0, 'results_html': ''});
            }
            expect(request.url.path, '/api/storesearch/');
            expect(request.url.queryParameters['term'], '重生酒馆');
            expect(request.headers['Cookie'], contains('mature_content=1'));
            if (request.url.queryParameters['cc'] == 'CN') {
              return _json({'total': 0, 'items': []});
            }
            expect(request.url.queryParameters['cc'], 'US');
            return _json({
              'total': 2,
              'items': [
                {
                  'type': 'app',
                  'name': '重生酒馆',
                  'id': 3236900,
                  'price': {'currency': 'USD', 'initial': 1799, 'final': 1799},
                  'tiny_image': 'https://cdn.example/3236900.jpg',
                  'platforms': {'windows': true},
                },
                {
                  'type': 'app',
                  'name': '重生酒馆 Demo',
                  'id': 4848020,
                  'price': {'currency': 'USD', 'initial': 0, 'final': 0},
                  'tiny_image': 'https://cdn.example/4848020.jpg',
                  'platforms': {'windows': true},
                },
              ],
            });
          }),
        );

        final page = await service.search('重生酒馆');
        expect(page.items.map((item) => item.appId), [3236900, 4848020]);
        expect(page.items.first.name, '重生酒馆');
        expect(page.items.first.priceText, r'$17.99');
        expect(page.items.last.isFree, isTrue);
        expect(page.totalCount, 2);
        expect(page.hasMore, isFalse);
        service.dispose();
        settings.dispose();
        await temp.delete(recursive: true);
      },
    );

    test('selected region is persisted and used by catalog search', () async {
      final temp = await Directory.systemTemp.createTemp('flsl-store-');
      final paths = AppPaths(temp.path);
      await paths.initialize();
      final settings = SettingsStore(paths);
      await settings.load();
      final countries = <String>[];
      final service = StoreService(
        settings: settings,
        client: MockClient((request) async {
          if (request.url.path == '/search/results/') {
            return _json({'total_count': 0, 'results_html': ''});
          }
          expect(request.url.path, '/api/storesearch/');
          countries.add(request.url.queryParameters['cc']!);
          return _json({
            'total': 1,
            'items': [
              {
                'type': 'app',
                'name': 'Rebirth Pub',
                'id': 3236900,
                'tiny_image': 'https://cdn.example/3236900.jpg',
              },
            ],
          });
        }),
      );

      await service.setCountryCode('us');
      expect(service.countryCode, 'US');
      expect(settings.get<String>('storeCountryCode', ''), 'US');
      final page = await service.search('Rebirth Pub');
      expect(countries, ['US']);
      expect(page.items.single.appId, 3236900);
      service.dispose();
      settings.dispose();
      await temp.delete(recursive: true);
    });

    test('rejects malformed data and exposes HTTP status', () async {
      final malformed = StoreService(
        client: MockClient((_) async => _json({'results_html': 7})),
      );
      await expectLater(malformed.search('x'), throwsA(isA<StoreException>()));
      final throttled = StoreService(
        client: MockClient((_) async => http.Response('rate limit', 429)),
      );
      await expectLater(
        throttled.search('x'),
        throwsA(
          isA<StoreException>().having((e) => e.statusCode, 'status', 429),
        ),
      );
    });

    test('times out and cancels without manufacturing empty results', () async {
      final service = StoreService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return _json({});
        }),
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        service.search('x'),
        throwsA(
          isA<StoreException>().having(
            (e) => e.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
      final cancelled = Completer<void>();
      final waiting = StoreService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return _json({});
        }),
      );
      final result = waiting.search('x', cancelled: cancelled.future);
      cancelled.complete();
      await expectLater(result, throwsA(isA<StoreRequestCancelled>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });

  group('Steam details and DLC', () {
    test(
      'retains exact minor units and localized price, parses DLC and metadata',
      () async {
        final service = StoreService(
          client: MockClient((request) async {
            final id = request.url.queryParameters['appids']!;
            return _json({
              id: {
                'success': true,
                'data': {
                  'name': 'Test title',
                  'steam_appid': int.parse(id),
                  'type': id == '10' ? 'game' : 'dlc',
                  'header_image': 'https://cdn.example/$id.jpg',
                  'short_description': 'A &amp; B<br>Another line',
                  'price_overview': {
                    'currency': 'CNY',
                    'initial': 9900,
                    'final': 4950,
                    'discount_percent': 50,
                    'initial_formatted': '¥ 99',
                    'final_formatted': '¥ 49.50',
                  },
                  'platforms': {'windows': true, 'mac': false, 'linux': true},
                  'release_date': {'coming_soon': false, 'date': '1 Jan, 2020'},
                  'dlc': id == '10' ? [11, 12, 12] : [],
                  'developers': ['Developer'],
                  'publishers': ['Publisher'],
                  'genres': [
                    {'id': '1', 'description': 'Action'},
                  ],
                  'achievements': {'total': 12},
                  'required_age': '18',
                  'website': 'https://example.com',
                },
              },
            });
          }),
        );
        final game = await service.details(10);
        expect(game.price!.finalMinor, 4950);
        expect(game.priceText, '¥ 49.50');
        expect(game.dlcIds, [11, 12]);
        expect(game.description, 'A & B Another line');
        expect(game.requiredAge, 18);
        expect(game.achievementCount, 12);
        expect((await service.dlc(10)).map((item) => item.appId), [11, 12]);
      },
    );

    test('free and unavailable titles are distinguished', () async {
      final free = StoreService(
        client: MockClient(
          (_) async => _json({
            '440': {
              'success': true,
              'data': {'name': 'Free game', 'is_free': true},
            },
          }),
        ),
      );
      final details = await free.details(440);
      expect(details.isFree, isTrue);
      expect(details.priceText, isEmpty);
      final unavailable = StoreService(
        client: MockClient(
          (_) async => _json({
            '440': {'success': false},
          }),
        ),
      );
      await expectLater(
        unavailable.details(440),
        throwsA(isA<StoreException>()),
      );
    });

    test('adult details retry against the global catalog region', () async {
      final temp = await Directory.systemTemp.createTemp('flsl-store-');
      final paths = AppPaths(temp.path);
      await paths.initialize();
      final settings = SettingsStore(paths);
      await settings.load();
      await settings.set('storeShowAdultContent', true);
      final countries = <String>[];
      final service = StoreService(
        settings: settings,
        client: MockClient((request) async {
          final country = request.url.queryParameters['cc']!;
          countries.add(country);
          if (country == 'CN') {
            return _json({
              '3236900': {'success': false},
            });
          }
          return _json({
            '3236900': {
              'success': true,
              'data': {
                'name': '重生酒馆',
                'type': 'game',
                'header_image': 'https://cdn.example/3236900.jpg',
              },
            },
          });
        }),
      );

      final game = await service.details(3236900);
      expect(game.name, '重生酒馆');
      expect(countries, ['CN', 'US']);
      service.dispose();
      settings.dispose();
      await temp.delete(recursive: true);
    });
  });
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
