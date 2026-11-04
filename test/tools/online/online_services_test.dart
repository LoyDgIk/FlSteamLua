import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/tools/online/online_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory temp;
  late AppPaths paths;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('flsl-online-');
    paths = AppPaths(temp.path);
    await paths.initialize();
  });
  tearDown(() async => temp.delete(recursive: true));

  test(
    'game closing during trainer launch does not leave a trainer running',
    () async {
      final trainer = File(paths.file('trainer.exe'));
      await trainer.writeAsBytes([1]);
      final launched = Completer<int>();
      final stopped = <int>[];
      final service = TrainerService(
        paths: paths,
        settings: SettingsStore(paths),
        launcher: (_) => launched.future,
        stopper: (pid) async {
          stopped.add(pid);
        },
      );
      await service.saveBinding(
        TrainerBinding(
          appId: 10,
          gameName: 'Game',
          gameExecutable: 'game.exe',
          trainerPath: trainer.path,
        ),
      );
      final starting = service.onGameStarted(10);
      await Future<void>.delayed(Duration.zero);
      await service.onGameStopped(10);
      launched.complete(99);
      await starting;
      expect(stopped, [99]);
      service.dispose();
    },
  );

  test('trainer search parses lazy image and attachment download', () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.queryParameters.containsKey('s')) {
        return http.Response(
          '<article class="post-standard"><h2 class="post-title">'
          '<a href="/trainer/game/">Game Plus 12 Trainer</a></h2>'
          '<img class="wp-post-image" src="data:image/gif;base64,a" data-src="https://image.test/game.jpg"/></article>',
          200,
        );
      }
      if (request.url.path == '/trainer/game/') {
        return http.Response(
          '<h1>Game Trainer</h1><div class="entry-content">v1.5 Notes</div>'
          '<a class="attachment-link" href="https://files.test/trainer.zip">Download</a>',
          200,
        );
      }
      expect(
        request.headers['Referer'],
        'https://flingtrainer.com/trainer/game/',
      );
      return http.Response.bytes([1, 2, 3], 200);
    });
    final service = TrainerService(
      paths: paths,
      settings: SettingsStore(paths),
      client: client,
    );
    final entries = await service.search('Game');
    expect(entries.single.name, 'Game');
    expect(entries.single.coverUrl, 'https://image.test/game.jpg');
    final downloaded = await service.download(entries.single);
    expect(await downloaded.readAsBytes(), [1, 2, 3]);
    expect(requests.length, 3);
    service.dispose();
  });

  test('bindings persist, launch only once, and stop with game', () async {
    final trainer = File(paths.file('trainer.exe'));
    await trainer.writeAsBytes([1]);
    final started = <String>[];
    final stopped = <int>[];
    final settings = SettingsStore(paths);
    final service = TrainerService(
      paths: paths,
      settings: settings,
      launcher: (path) async {
        started.add(path);
        return 42;
      },
      stopper: (pid) async {
        stopped.add(pid);
      },
    );
    await service.saveBinding(
      TrainerBinding(
        appId: 10,
        gameName: 'Game',
        gameExecutable: r'C:\Games\game.exe',
        trainerPath: trainer.path,
      ),
    );
    await service.onGameStarted(10, executablePath: r'C:\Other\game.exe');
    expect(started, isEmpty);
    await service.onGameStarted(10, executablePath: r'C:\Games\game.exe');
    await service.onGameStarted(10);
    expect(started, [trainer.path]);
    await service.onGameStopped(10);
    expect(stopped, [42]);
    final restored = TrainerService(paths: paths, settings: settings);
    await restored.loadBindings();
    expect(restored.bindings.single.appId, 10);
    await restored.removeBinding(10);
    expect(restored.bindings, isEmpty);
    service.dispose();
    restored.dispose();
  });

  test('OnlineFix feed reads recent articles and popular games', () async {
    final service = OnlineFixService(
      paths: paths,
      requestGap: Duration.zero,
      client: MockClient(
        (request) async => http.Response(
          '''
<article class="news"><div class="article">
  <a class="big-link" href="/games/survival/game.html"></a>
  <img data-src="https://online-fix.me/uploads/poster.jpg">
  <h2 class="title">Recent Game</h2>
  <div class="edit">Version 1.2</div>
  <time datetime="2026-11-03"></time>
</div></article>
<div class="game-rating"><div class="games-cont">
  <a href="/games/action/popular.html">
    <img src="https://online-fix.me/uploads/popular.jpg">
    <p>2 November 2026</p><h3>Popular Game</h3>
  </a>
</div></div>
<nav class="pagination"><a href="/page/2/">2</a><a href="/page/9/">9</a></nav>
''',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      ),
    );
    final recent = await service.feed(OnlineFixFeed.recent);
    expect(recent.entries.single.title, 'Recent Game');
    expect(recent.entries.single.version, 'Version 1.2');
    expect(
      recent.entries.single.coverUrl,
      'https://online-fix.me/uploads/poster.jpg',
    );
    expect(recent.pages, 9);
    final popular = await service.feed(OnlineFixFeed.popular);
    expect(popular.entries.single.title, 'Popular Game');
    expect(
      popular.entries.single.url,
      'https://online-fix.me/games/action/popular.html',
    );
    service.dispose();
  });

  test(
    'OnlineFix handles CP1251, search variants, directory session and referer',
    () async {
      final searchTerms = <String>[];
      var warmed = false;
      final client = MockClient((request) async {
        if (request.url.path == '/index.php') {
          searchTerms.add(request.url.queryParameters['story']!);
          return http.Response.bytes(
            latin1.encode(
              '<div class="news-search"><div>'
              '<a class="big-link" href="/games/test.html"></a><h2 class="title">Game</h2>'
              '<div class="edit">v1</div></div></div>',
            ),
            200,
          );
        }
        if (request.url.path == '/games/test.html') {
          return http.Response(
            '<h1 id="news-title">Game</h1><div class="quote">'
            '<a href="https://uploads.online-fix.me:2053/uploads/Game/">Files</a></div>'
            '<div itemprop="articleBody"><p>Step one<br>Step two</p></div>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith('/')) {
          warmed = true;
          return http.Response(
            '<pre><a href="../">Parent</a><a href="fix.zip">fix.zip</a> 12 MB</pre>',
            200,
            headers: {'set-cookie': 'session=fixture; Path=/'},
          );
        }
        expect(warmed, isTrue);
        expect(request.headers['Cookie'], 'session=fixture');
        expect(
          request.headers['Referer'],
          'https://uploads.online-fix.me:2053/uploads/Game/Fix%20Repair/',
        );
        return http.Response.bytes([7, 8], 200);
      });
      final service = OnlineFixService(
        paths: paths,
        client: client,
        requestGap: Duration.zero,
      );
      final found = await service.search('GaMe');
      expect(searchTerms, ['GaMe', 'game', 'GAME']);
      expect(found.length, 1);
      final detail = await service.details(found.single.url);
      expect(detail.instructions, contains('Step one\nStep two'));
      expect(detail.files.single.name, 'fix.zip');
      final file = await service.download(
        detail.files.single,
        referer: detail.directoryUrl,
      );
      expect(await file.readAsBytes(), [7, 8]);
      expect(decodeWindows1251([0xcf, 0xf0, 0xe8, 0xe2, 0xe5, 0xf2]), 'Привет');
      service.dispose();
    },
  );

  test('download cancellation leaves no partial file', () async {
    final client = MockClient(
      (request) async => http.Response.bytes([1, 2], 200),
    );
    final service = TrainerService(
      paths: paths,
      settings: SettingsStore(paths),
      client: client,
    );
    final task = TaskProgress('1', 'cancel')..cancellationRequested = true;
    await expectLater(
      service.download(
        const TrainerEntry(
          name: 'game',
          pageUrl: 'https://flingtrainer.com/trainer/game/',
          downloadUrl: 'https://files.test/a.zip',
        ),
        task: TaskContext(task, () {}),
      ),
      throwsA(isA<TaskCancelled>()),
    );
    expect(await paths.directory('downloads/trainers').exists(), isFalse);
    service.dispose();
  });

  test(
    'HTTP failure is surfaced and encoded filenames cannot escape download root',
    () async {
      final service = TrainerService(
        paths: paths,
        settings: SettingsStore(paths),
        client: MockClient((request) async => http.Response('Denied', 403)),
      );
      await expectLater(service.search('game'), throwsA(isA<HttpException>()));
      await expectLater(
        service.download(
          const TrainerEntry(
            name: 'game',
            pageUrl: 'https://source.test/',
            downloadUrl: 'https://files.test/%2e%2e%2fsecret.zip',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      service.dispose();
    },
  );
  test('catalogues retain every entry and archive metadata', () async {
    final service = TrainerService(
      paths: paths,
      settings: SettingsStore(paths),
      client: MockClient((request) async {
        if (request.url.host == 'archive.flingtrainer.com') {
          return http.Response(
            '<table><tr><td><a href="a.zip">A Trainer</a></td>'
            '<td>12 MB</td><td>2026-10-31</td></tr></table>',
            200,
          );
        }
        return http.Response(
          List.generate(
            200,
            (index) =>
                '<a href="/trainer/game-$index/">Game $index Trainer</a>',
          ).join(),
          200,
        );
      }),
    );
    expect((await service.all()).length, 200);
    final archive = (await service.listArchive()).single;
    expect(archive.size, '12 MB');
    expect(archive.updated, '2026-10-31');
    expect(archive.downloadUrl, 'https://archive.flingtrainer.com/a.zip');
    service.dispose();
  });

  test('Chinese trainer search translates before querying FLiNG', () async {
    final queries = <String>[];
    final service = TrainerService(
      paths: paths,
      settings: SettingsStore(paths),
      client: MockClient((request) async {
        if (request.url.host == 'api.mymemory.translated.net') {
          expect(request.url.queryParameters['langpair'], 'zh-CN|en');
          return http.Response(
            jsonEncode({
              'responseData': {'translatedText': 'Test Game'},
            }),
            200,
          );
        }
        queries.add(request.url.queryParameters['s']!);
        return http.Response('', 200);
      }),
    );
    await service.search('测试游戏');
    expect(queries, ['Test Game']);
    service.dispose();
  });

  test(
    'downloaded executables can run, stop and remove associated bindings',
    () async {
      final file = File(paths.file('downloads/trainers/Game Trainer.exe'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2]);
      final stopped = <int>[];
      final service = TrainerService(
        paths: paths,
        settings: SettingsStore(paths),
        launcher: (_) async => 88,
        stopper: (pid) async => stopped.add(pid),
      );
      final downloaded = (await service.downloaded()).single;
      expect(downloaded.isExecutable, isTrue);
      await service.saveBinding(
        TrainerBinding(
          appId: 10,
          gameName: 'Game',
          gameExecutable: 'game.exe',
          trainerPath: file.path,
        ),
      );
      await service.startTrainer(file.path);
      expect(service.isRunning(file.path), isTrue);
      await service.deleteDownloaded(downloaded);
      expect(stopped, [88]);
      expect(service.bindings, isEmpty);
      expect(await file.exists(), isFalse);
      expect(await service.downloaded(), isEmpty);
      service.dispose();
    },
  );

  test(
    'online fixes with equal filenames keep separate game files and instructions',
    () async {
      final service = OnlineFixService(
        paths: paths,
        requestGap: Duration.zero,
        client: MockClient(
          (request) async => request.url.path.endsWith('/')
              ? http.Response('<pre></pre>', 200)
              : http.Response.bytes([
                  request.url.path.contains('first') ? 1 : 2,
                ], 200),
        ),
      );
      OnlineFixDetail detail(String game) => OnlineFixDetail(
        entry: OnlineFixEntry(
          title: game,
          url: 'https://online-fix.me/$game.html',
        ),
        instructions: 'Install $game',
        directoryUrl: 'https://online-fix.me:2053/uploads/$game/',
        files: const [],
      );
      final first = await service.download(
        const OnlineFixFile(
          name: 'fix.zip',
          url: 'https://online-fix.me:2053/uploads/first/fix.zip',
        ),
        referer: 'https://online-fix.me:2053/uploads/first/',
        detail: detail('First'),
      );
      final second = await service.download(
        const OnlineFixFile(
          name: 'fix.zip',
          url: 'https://online-fix.me:2053/uploads/second/fix.zip',
        ),
        referer: 'https://online-fix.me:2053/uploads/second/',
        detail: detail('Second'),
      );
      expect(first.parent.path, isNot(second.parent.path));
      expect(await first.readAsBytes(), [1]);
      expect(await second.readAsBytes(), [2]);
      final instructions = await first.parent
          .list()
          .where((item) => item is File && item.path.endsWith('.txt'))
          .cast<File>()
          .single;
      expect(await instructions.readAsString(), contains('Install First'));
      expect(await instructions.readAsString(), contains('online-fix.me'));
      service.dispose();
    },
  );
}
