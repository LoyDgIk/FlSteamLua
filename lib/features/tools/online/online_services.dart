// Ported from Fluent-Steam-Lua (zlib), Copyright (c) 2024 SteamLuaManager.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../core/app_paths.dart';
import '../../../core/settings_store.dart';
import '../../../core/task_center.dart';
import '../../library/process_observer.dart';

class TrainerEntry {
  const TrainerEntry({
    required this.name,
    required this.pageUrl,
    this.coverUrl = '',
    this.downloadUrl,
    this.description = '',
    this.version = '',
    this.updated = '',
    this.size = '',
    this.source = 'FLiNG',
  });
  final String name;
  final String pageUrl;
  final String coverUrl;
  final String? downloadUrl;
  final String description;
  final String version;
  final String updated;
  final String size;
  final String source;
}

class DownloadedTrainer {
  const DownloadedTrainer({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  bool get isExecutable => p.extension(path).toLowerCase() == '.exe';
}

class TrainerBinding {
  const TrainerBinding({
    required this.appId,
    required this.gameName,
    required this.gameExecutable,
    required this.trainerPath,
    this.enabled = true,
  });
  final int appId;
  final String gameName;
  final String gameExecutable;
  final String trainerPath;
  final bool enabled;

  Map<String, dynamic> toJson() => {
    'appId': appId,
    'gameName': gameName,
    'gameExecutable': gameExecutable,
    'trainerPath': trainerPath,
    'enabled': enabled,
  };
  factory TrainerBinding.fromJson(Map<String, dynamic> json) => TrainerBinding(
    appId: json['appId'] as int,
    gameName: json['gameName'] as String,
    gameExecutable: json['gameExecutable'] as String,
    trainerPath: json['trainerPath'] as String,
    enabled: json['enabled'] as bool? ?? true,
  );
}

typedef TrainerLauncher = Future<int> Function(String executable);
typedef TrainerStopper = Future<void> Function(int processId);

class TrainerService extends ChangeNotifier {
  TrainerService({
    required this.paths,
    required this.settings,
    http.Client? client,
    TrainerLauncher? launcher,
    this._stopper,
  }) : _http = client ?? http.Client(),
       _ownsClient = client == null,
       _launcher = launcher ?? _defaultLaunch;

  final AppPaths paths;
  final SettingsStore settings;
  final http.Client _http;
  final bool _ownsClient;
  final TrainerLauncher _launcher;
  final TrainerStopper? _stopper;
  final Map<int, (int, String)> _running = {};
  final Map<int, int> _sessions = {};
  final Set<int> _launching = {};
  final Map<String, (int, String)> _manualRunning = {};
  List<TrainerBinding> _bindings = [];
  List<TrainerBinding> get bindings => List.unmodifiable(_bindings);
  bool isRunning(String path) =>
      _manualRunning.containsKey(_pathKey(path)) ||
      _running.values.any((item) => _pathKey(item.$2) == _pathKey(path));

  static String _pathKey(String path) => p.normalize(path).toLowerCase();

  static Future<int> _defaultLaunch(String executable) async =>
      (await Process.start(
        executable,
        const [],
        workingDirectory: p.dirname(executable),
        mode: ProcessStartMode.detached,
      )).pid;
  Future<void> _stopTrainer(int processId, String executablePath) async {
    final stopper = _stopper;
    if (stopper != null) {
      await stopper(processId);
      return;
    }
    await stopObservedProcess(
      RunningProcess(pid: processId, executablePath: executablePath),
    );
  }

  Future<void> loadBindings() async {
    final file = File(paths.file('data/trainer-bindings.json'));
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('Invalid trainer bindings');
    }
    _bindings = decoded
        .map(
          (value) =>
              TrainerBinding.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList();
    notifyListeners();
  }

  Future<void> saveBinding(TrainerBinding binding) async {
    if (binding.appId <= 0 || !await File(binding.trainerPath).exists()) {
      throw const FileSystemException('Select an existing trainer executable');
    }
    if (!binding.enabled) await onGameStopped(binding.appId);
    _bindings.removeWhere((item) => item.appId == binding.appId);
    _bindings.add(binding);
    await _saveBindings();
  }

  Future<void> removeBinding(int appId) async {
    await onGameStopped(appId);
    _bindings.removeWhere((item) => item.appId == appId);
    await _saveBindings();
  }

  Future<void> _saveBindings() async {
    final file = File(paths.file('data/trainer-bindings.json'));
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(_bindings.map((b) => b.toJson()).toList()),
      flush: true,
    );
    await temp.rename(file.path);
    notifyListeners();
  }

  Future<int> launch(String path) async {
    if (!await File(path).exists()) {
      throw FileSystemException('Trainer not found', path);
    }
    return _launcher(path);
  }

  Future<void> startTrainer(String path) async {
    if (isRunning(path)) return;
    final processId = await launch(path);
    _manualRunning[_pathKey(path)] = (processId, path);
    notifyListeners();
  }

  Future<void> stopTrainer(String path) async {
    final manual = _manualRunning.remove(_pathKey(path));
    if (manual != null) await _stopTrainer(manual.$1, manual.$2);
    for (final appId in _running.keys.toList()) {
      if (_pathKey(_running[appId]!.$2) == _pathKey(path)) {
        await onGameStopped(appId);
      }
    }
    notifyListeners();
  }

  Future<List<DownloadedTrainer>> downloaded() async {
    final directory = paths.directory('downloads/trainers');
    if (!await directory.exists()) return [];
    final result = <DownloadedTrainer>[];
    await for (final file in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (file is! File ||
          !{
            '.exe',
            '.zip',
            '.7z',
            '.rar',
          }.contains(p.extension(file.path).toLowerCase())) {
        continue;
      }
      final stat = await file.stat();
      result.add(
        DownloadedTrainer(
          path: file.path,
          name: _stripTrainer(p.basenameWithoutExtension(file.path)),
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<void> deleteDownloaded(DownloadedTrainer item) async {
    final root = await paths
        .directory('downloads/trainers')
        .resolveSymbolicLinks();
    final file = File(item.path);
    final actual = await file.resolveSymbolicLinks();
    if (!p.isWithin(root, actual)) {
      throw ArgumentError('The file is outside the trainer download directory');
    }
    await stopTrainer(actual);
    _bindings.removeWhere(
      (binding) => _pathKey(binding.trainerPath) == _pathKey(actual),
    );
    await _saveBindings();
    await file.delete();
    notifyListeners();
  }

  Future<void> createDesktopShortcut(DownloadedTrainer item) async {
    final file = File(item.path);
    if (!await file.exists()) {
      throw FileSystemException('Trainer not found', item.path);
    }
    String quote(String value) => "'${value.replaceAll("'", "''")}'";
    final script =
        '''
\$ErrorActionPreference = 'Stop'
\$desktop = [Environment]::GetFolderPath('Desktop')
\$shell = New-Object -ComObject WScript.Shell
\$shortcut = \$shell.CreateShortcut([IO.Path]::Combine(\$desktop, ${quote('${p.basenameWithoutExtension(item.path)}.lnk')}))
\$shortcut.TargetPath = ${quote(file.absolute.path)}
\$shortcut.WorkingDirectory = ${quote(file.absolute.parent.path)}
\$shortcut.Save()
''';
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes.addAll([unit & 255, unit >> 8]);
    }
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      base64Encode(bytes),
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  Future<void> onGameStarted(int appId, {String? executablePath}) async {
    final matches = _bindings.where((b) => b.appId == appId && b.enabled);
    if (matches.isEmpty ||
        _running.containsKey(appId) ||
        !_launching.add(appId)) {
      return;
    }
    final session = _sessions[appId] ?? 0;
    try {
      final binding = matches.first;
      if (executablePath != null &&
          !p.equals(
            p.normalize(executablePath).toLowerCase(),
            p.normalize(binding.gameExecutable).toLowerCase(),
          )) {
        return;
      }
      final pid = await launch(binding.trainerPath);
      if ((_sessions[appId] ?? 0) != session) {
        await _stopTrainer(pid, binding.trainerPath);
        return;
      }
      _running[appId] = (pid, binding.trainerPath);
      notifyListeners();
    } finally {
      _launching.remove(appId);
    }
  }

  Future<void> onGameStopped(int appId) async {
    _sessions[appId] = (_sessions[appId] ?? 0) + 1;
    final process = _running.remove(appId);
    if (process != null) await _stopTrainer(process.$1, process.$2);
    notifyListeners();
  }

  Future<void> shutdown() async {
    for (final appId in {..._running.keys, ..._launching}) {
      await onGameStopped(appId);
    }
    for (final path in _manualRunning.values.map((item) => item.$2).toList()) {
      await stopTrainer(path);
    }
  }

  Future<List<TrainerEntry>> search(String query) async {
    if (query.trim().isEmpty) return all();
    var term = query.trim();
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(term)) {
      final translated =
          jsonDecode(
                await _get(
                  Uri.https('api.mymemory.translated.net', '/get', {
                    'q': term,
                    'langpair': 'zh-CN|en',
                  }),
                ),
              )
              as Map<String, dynamic>;
      final text =
          (translated['responseData'] as Map?)?['translatedText'] as String?;
      if (text != null &&
          text.trim().isNotEmpty &&
          !text.toUpperCase().contains('MYMEMORY WARNING')) {
        term = html.parseFragment(text).text!.trim();
      }
    }
    final uri = Uri.https('flingtrainer.com', '/', {'s': term});
    final doc = html.parse(await _get(uri));
    return doc
        .querySelectorAll('article.post-standard')
        .map((article) {
          final link = article.querySelector('h2.post-title a');
          if (link == null || link.attributes['href'] == null) return null;
          return TrainerEntry(
            name: _stripTrainer(link.text.trim()),
            pageUrl: uri.resolve(link.attributes['href']!).toString(),
            coverUrl: _image(article.querySelector('img.wp-post-image'), uri),
            updated:
                article.querySelector('time')?.attributes['datetime'] ?? '',
          );
        })
        .whereType<TrainerEntry>()
        .take(30)
        .toList();
  }

  Future<List<TrainerEntry>> recent({int count = 20}) async {
    final uri = Uri.https('flingtrainer.com', '/');
    final doc = html.parse(await _get(uri));
    final articles = doc.querySelectorAll('article.post-standard');
    return articles
        .map((article) {
          final link = article.querySelector('h2.post-title a');
          if (link?.attributes['href'] == null) return null;
          return TrainerEntry(
            name: _stripTrainer(link!.text.trim()),
            pageUrl: uri.resolve(link.attributes['href']!).toString(),
            coverUrl: _image(article.querySelector('img.wp-post-image'), uri),
            updated:
                article.querySelector('time')?.attributes['datetime'] ?? '',
          );
        })
        .whereType<TrainerEntry>()
        .take(count)
        .toList();
  }

  Future<List<TrainerEntry>> all({int? count}) async {
    final uri = Uri.parse('https://flingtrainer.com/all-trainers/');
    final doc = html.parse(await _get(uri));
    final seen = <String>{};
    return doc
        .querySelectorAll('a[href]')
        .where(
          (link) =>
              link.attributes['href']!.contains('/trainer/') &&
              link.text.trim().isNotEmpty,
        )
        .map(
          (link) => TrainerEntry(
            name: _stripTrainer(link.text.trim()),
            pageUrl: uri.resolve(link.attributes['href']!).toString(),
          ),
        )
        .where((entry) => seen.add(entry.pageUrl))
        .take(count ?? 0x7fffffff)
        .toList();
  }

  Future<List<TrainerEntry>> listArchive({int? count}) async {
    final uri = Uri.parse('https://archive.flingtrainer.com/');
    final doc = html.parse(await _get(uri));
    return doc
        .querySelectorAll('table tr')
        .map((row) {
          final link = row.querySelector('td a[href]');
          if (link == null) return null;
          final url = uri.resolve(link.attributes['href']!).toString();
          return TrainerEntry(
            name: _stripTrainer(link.text.trim()),
            pageUrl: url,
            downloadUrl: url,
            size:
                row.querySelectorAll('td').elementAtOrNull(1)?.text.trim() ??
                '',
            updated:
                row.querySelectorAll('td').elementAtOrNull(2)?.text.trim() ??
                '',
            source: 'FLiNG Archive',
          );
        })
        .whereType<TrainerEntry>()
        .take(count ?? 0x7fffffff)
        .toList();
  }

  Future<TrainerEntry> details(TrainerEntry entry) async {
    if (entry.downloadUrl != null) return entry;
    final uri = _webUri(entry.pageUrl);
    final doc = html.parse(await _get(uri));
    final body =
        doc.querySelector('.entry-content') ?? doc.querySelector('.entry');
    for (final node
        in body?.querySelectorAll('script, style, ins') ?? <Element>[]) {
      node.remove();
    }
    final text = body?.text.trim() ?? '';
    final download = doc.querySelector('a.attachment-link')?.attributes['href'];
    return TrainerEntry(
      name: _stripTrainer(doc.querySelector('h1')?.text.trim() ?? entry.name),
      pageUrl: entry.pageUrl,
      coverUrl:
          doc
              .querySelector('meta[property="og:image"]')
              ?.attributes['content'] ??
          entry.coverUrl,
      downloadUrl: download == null ? null : uri.resolve(download).toString(),
      description: text.length > 4000 ? text.substring(0, 4000) : text,
      version:
          RegExp(
            r'\bv[\d.]+(?:\s*-\s*v[\d.]+)?',
            caseSensitive: false,
          ).firstMatch(text)?.group(0) ??
          '',
      updated: doc.querySelector('time')?.attributes['datetime'] ?? '',
      size:
          RegExp(
            r'\d+(?:\.\d+)?\s*(?:KB|MB|GB)',
            caseSensitive: false,
          ).firstMatch(text)?.group(0) ??
          '',
      source: entry.source,
    );
  }

  Future<File> download(TrainerEntry entry, {TaskContext? task}) async {
    final info = entry.downloadUrl == null ? await details(entry) : entry;
    if (info.downloadUrl == null) {
      throw StateError('The source has no download attachment');
    }
    return _download(
      _http,
      _webUri(info.downloadUrl!),
      paths.directory('downloads/trainers'),
      referer: info.pageUrl,
      task: task,
    );
  }

  Future<String> _get(Uri uri) async {
    final response = await _http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _requireSuccess(response.statusCode, uri);
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  @override
  void dispose() {
    if (_ownsClient) _http.close();
    super.dispose();
  }
}

class OnlineFixEntry {
  const OnlineFixEntry({
    required this.title,
    required this.url,
    this.version = '',
    this.updated = '',
    this.coverUrl = '',
    this.tablet = '',
  });
  final String title;
  final String url;
  final String version;
  final String updated;
  final String coverUrl;
  final String tablet;
}

enum OnlineFixFeed { recent, popular }

class OnlineFixFeedPage {
  const OnlineFixFeedPage({
    required this.entries,
    required this.page,
    required this.pages,
  });

  final List<OnlineFixEntry> entries;
  final int page;
  final int pages;
}

class OnlineFixFile {
  const OnlineFixFile({
    required this.name,
    required this.url,
    this.size = '',
    this.isDirectory = false,
    this.updated = '',
  });
  final String name;
  final String url;
  final String size;
  final bool isDirectory;
  final String updated;
}

class OnlineFixDetail {
  const OnlineFixDetail({
    required this.entry,
    required this.instructions,
    required this.directoryUrl,
    required this.files,
  });
  final OnlineFixEntry entry;
  final String instructions;
  final String directoryUrl;
  final List<OnlineFixFile> files;
}

class OnlineFixService {
  OnlineFixService({
    required this.paths,
    http.Client? client,
    this.requestGap = const Duration(seconds: 3),
  }) : _http = client ?? http.Client(),
       _ownsClient = client == null;
  final AppPaths paths;
  final Duration requestGap;
  final http.Client _http;
  final bool _ownsClient;
  final Map<String, String> _cookies = {};
  DateTime? _lastRequest;
  Future<void> _queue = Future.value();

  Future<void> _pace() {
    final next = _queue.then((_) async {
      final last = _lastRequest;
      if (last != null) {
        final remaining = requestGap - DateTime.now().difference(last);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      _lastRequest = DateTime.now();
    });
    _queue = next;
    return next;
  }

  Future<http.Response> _get(Uri uri) async {
    await _pace();
    final response = await _http
        .get(
          uri,
          headers: {
            ..._headers,
            'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.8',
            if (_cookies.isNotEmpty)
              'Cookie': _cookies.entries
                  .map((e) => '${e.key}=${e.value}')
                  .join('; '),
          },
        )
        .timeout(const Duration(seconds: 60));
    final cookie = response.headers['set-cookie'];
    if (cookie != null) {
      for (final match in RegExp(
        r'(?:^|,\s*)([^\s=;,]+)=([^;]*)',
      ).allMatches(cookie)) {
        _cookies[match.group(1)!] = match.group(2)!;
      }
    }
    _requireSuccess(response.statusCode, uri);
    return response;
  }

  Future<Document> _document(Uri uri) async {
    final response = await _get(uri);
    final encoding = response.headers['content-type']?.toLowerCase() ?? '';
    final text = encoding.contains('utf-8')
        ? utf8.decode(response.bodyBytes, allowMalformed: true)
        : decodeWindows1251(response.bodyBytes);
    return html.parse(text);
  }

  Future<List<OnlineFixEntry>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final results = <String, OnlineFixEntry>{};
    for (final term in {
      query.trim(),
      query.trim().toLowerCase(),
      query.trim().toUpperCase(),
    }) {
      final uri = Uri.https('online-fix.me', '/index.php', {
        'do': 'search',
        'subaction': 'search',
        'story': term,
      });
      final doc = await _document(uri);
      for (final link in doc.querySelectorAll('.news-search a.big-link')) {
        final article = link.parent;
        final url = link.attributes['href'];
        final title = article?.querySelector('h2.title')?.text.trim();
        if (url == null || title == null || title.isEmpty) continue;
        final absolute = uri.resolve(url).toString();
        results.putIfAbsent(
          absolute,
          () => OnlineFixEntry(
            title: title,
            url: absolute,
            version: article?.querySelector('.edit')?.text.trim() ?? '',
            updated:
                article?.querySelector('time')?.attributes['datetime'] ?? '',
            coverUrl: _image(article?.querySelector('img'), uri),
            tablet:
                article
                    ?.querySelector(
                      'a[href*="/files/progs/"], a[href*="/programs/"]',
                    )
                    ?.text
                    .trim() ??
                '',
          ),
        );
      }
    }
    return results.values.toList();
  }

  Future<OnlineFixFeedPage> feed(OnlineFixFeed feed, {int page = 1}) async {
    final requested = page < 1 ? 1 : page;
    final uri = feed == OnlineFixFeed.popular || requested == 1
        ? Uri.https('online-fix.me', '/')
        : Uri.https('online-fix.me', '/page/$requested/');
    final doc = await _document(uri);
    final entries = feed == OnlineFixFeed.popular
        ? _popularEntries(doc, uri)
        : _recentEntries(doc, uri);
    return OnlineFixFeedPage(
      entries: entries,
      page: requested,
      pages: feed == OnlineFixFeed.popular ? 1 : _feedPageCount(doc),
    );
  }

  Future<OnlineFixDetail> details(String url) async {
    final uri = _webUri(url);
    final doc = await _document(uri);
    final title = doc.querySelector('#news-title')?.text.trim();
    if (title == null || title.isEmpty) {
      throw const FormatException('OnlineFix article title missing');
    }
    final links = doc.querySelectorAll('.quote a[href]');
    String? directory;
    for (final link in links) {
      final candidate = uri.resolve(link.attributes['href']!);
      final isOnlineFixHost =
          candidate.host == 'online-fix.me' ||
          candidate.host.endsWith('.online-fix.me');
      if (isOnlineFixHost &&
          candidate.port == 2053 &&
          candidate.path.contains('/uploads/') &&
          !candidate.path.contains('/torrents/')) {
        final base = candidate.toString().replaceFirst(RegExp(r'[?#].*$'), '');
        directory = '${base.endsWith('/') ? base : '$base/'}Fix%20Repair/';
        break;
      }
    }
    final body = doc.querySelector('[itemprop="articleBody"]');
    final text = body == null ? '' : _textWithBreaks(body).trim();
    return OnlineFixDetail(
      entry: OnlineFixEntry(
        title: title,
        url: url,
        version: doc.querySelector('.lightedited')?.text.trim() ?? '',
        updated:
            doc.querySelector('[itemprop="dateModified"]')?.text.trim() ?? '',
        coverUrl:
            doc
                .querySelector('meta[property="og:image"]')
                ?.attributes['content'] ??
            _image(doc.querySelector('[itemprop="articleBody"] img'), uri),
        tablet:
            doc
                .querySelector(
                  'a[href*="/files/progs/"], a[href*="/programs/"]',
                )
                ?.text
                .trim() ??
            '',
      ),
      instructions: text.length > 8000 ? text.substring(0, 8000) : text,
      directoryUrl: directory ?? '',
      files: directory == null ? [] : await listFiles(directory),
    );
  }

  Future<List<OnlineFixFile>> listFiles(String directoryUrl) async {
    final uri = _webUri(
      directoryUrl.endsWith('/') ? directoryUrl : '$directoryUrl/',
    );
    final doc = await _document(uri);
    final files = <OnlineFixFile>[];
    for (final link in doc.querySelectorAll('pre a[href]')) {
      final href = link.attributes['href']!;
      if (href == '../' || href.startsWith('?')) continue;
      final absolute = uri.resolve(href);
      if (absolute.host != uri.host || !absolute.path.startsWith(uri.path)) {
        continue;
      }
      files.add(
        OnlineFixFile(
          name: Uri.decodeComponent(href.replaceFirst(RegExp(r'/$'), '')),
          url: absolute.toString(),
          isDirectory: href.endsWith('/'),
          size:
              RegExp(
                r'\d{2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}\s+([\d.]+[KMG]?)',
              ).firstMatch(_nextText(link))?.group(1) ??
              '',
          updated:
              RegExp(
                r'\d{2}-[A-Za-z]{3}-\d{4}\s+\d{2}:\d{2}',
              ).firstMatch(_nextText(link))?.group(0) ??
              '',
        ),
      );
    }
    return files;
  }

  List<OnlineFixEntry> _recentEntries(Document doc, Uri base) {
    final results = <String, OnlineFixEntry>{};
    for (final link in doc.querySelectorAll('article.news a.big-link[href]')) {
      final article = link.parent;
      final href = link.attributes['href'];
      final title = article?.querySelector('h2.title')?.text.trim();
      if (href == null || title == null || title.isEmpty) continue;
      final url = base.resolve(href).toString();
      results.putIfAbsent(
        url,
        () => OnlineFixEntry(
          title: title,
          url: url,
          version: article?.querySelector('.edit')?.text.trim() ?? '',
          updated: article?.querySelector('time')?.attributes['datetime'] ?? '',
          coverUrl: _image(article?.querySelector('img'), base),
          tablet:
              article
                  ?.querySelector(
                    'a[href*="/files/progs/"], a[href*="/programs/"]',
                  )
                  ?.text
                  .trim() ??
              '',
        ),
      );
    }
    return results.values.toList();
  }

  List<OnlineFixEntry> _popularEntries(Document doc, Uri base) {
    final results = <String, OnlineFixEntry>{};
    for (final link in doc.querySelectorAll(
      '.game-rating .games-cont a[href]',
    )) {
      final href = link.attributes['href'];
      final title = link.querySelector('h3')?.text.trim();
      if (href == null || title == null || title.isEmpty) continue;
      final url = base.resolve(href).toString();
      results.putIfAbsent(
        url,
        () => OnlineFixEntry(
          title: title,
          url: url,
          updated: link.querySelector('p')?.text.trim() ?? '',
          coverUrl: _image(link.querySelector('img'), base),
        ),
      );
    }
    return results.values.toList();
  }

  int _feedPageCount(Document doc) {
    var pages = 1;
    final pattern = RegExp(r'/page/(\d+)/');
    for (final link in doc.querySelectorAll('nav.pagination a[href]')) {
      final value = link.attributes['href'];
      if (value == null) continue;
      final match = pattern.firstMatch(value);
      final page = int.tryParse(match?.group(1) ?? '');
      if (page != null && page > pages) pages = page;
    }
    return pages;
  }

  Future<File> download(
    OnlineFixFile file, {
    required String referer,
    TaskContext? task,
    OnlineFixDetail? detail,
  }) async {
    if (file.isDirectory) throw ArgumentError('Choose a file, not a directory');
    task?.checkCancelled();
    await _get(_webUri(referer));
    await _pace();
    final folder = detail == null
        ? paths.directory('downloads/onlinefix')
        : Directory(
            p.join(
              paths.file('downloads/onlinefix'),
              detail.entry.title
                  .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
                  .replaceFirst(RegExp(r'[. ]+$'), ''),
            ),
          );
    final saved = await _download(
      _http,
      _webUri(file.url),
      folder,
      referer: referer,
      headers: {
        if (_cookies.isNotEmpty)
          'Cookie': _cookies.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; '),
      },
      task: task,
    );
    if (detail != null) {
      await File(p.join(folder.path, '使用说明 (必看).txt')).writeAsString(
        '${detail.entry.title}\n${detail.entry.url}\n'
        '解压密码 / Archive password: online-fix.me\n\n${detail.instructions}\n',
        flush: true,
      );
    }
    return saved;
  }

  void dispose() {
    if (_ownsClient) _http.close();
  }
}

const _headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) FlSteamLua/0.1',
  'Accept': '*/*',
};

Uri _webUri(String value) {
  final uri = Uri.parse(value);
  if (!uri.hasAuthority || !{'https', 'http'}.contains(uri.scheme)) {
    throw FormatException('Invalid HTTP URL', value);
  }
  return uri;
}

void _requireSuccess(int status, Uri uri) {
  if (status < 200 || status >= 300) {
    throw HttpException('HTTP $status', uri: uri);
  }
}

Future<File> _download(
  http.Client client,
  Uri uri,
  Directory directory, {
  required String referer,
  Map<String, String> headers = const {},
  TaskContext? task,
}) async {
  final filename = Uri.decodeComponent(uri.pathSegments.last);
  if (filename.isEmpty ||
      p.basename(filename) != filename ||
      filename.contains('\\') ||
      filename.contains(':') ||
      filename == '.' ||
      filename == '..') {
    throw const FormatException('Invalid remote filename');
  }
  task?.checkCancelled();
  final request = http.Request('GET', uri)
    ..headers.addAll({..._headers, ...headers, 'Referer': referer});
  final response = await client
      .send(request)
      .timeout(const Duration(seconds: 60));
  _requireSuccess(response.statusCode, uri);
  await directory.create(recursive: true);
  final target = File(p.join(directory.path, filename));
  final partial = File('${target.path}.partial');
  final sink = partial.openWrite();
  var done = 0;
  try {
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 60),
    )) {
      task?.checkCancelled();
      sink.add(chunk);
      done += chunk.length;
      final total = response.contentLength;
      task?.report(
        'Downloading $filename ($done bytes)',
        total != null && total > 0 ? done / total : null,
      );
    }
    await sink.flush();
    await sink.close();
    task?.checkCancelled();
    return await partial.rename(target.path);
  } catch (_) {
    await sink.close();
    if (await partial.exists()) await partial.delete();
    rethrow;
  }
}

String _stripTrainer(String value) => value
    .replaceFirst(
      RegExp(
        r'\s+(?:v[\d.]+.*?\s+)?(?:Plus\s+\d+\s+)?Trainer.*$',
        caseSensitive: false,
      ),
      '',
    )
    .replaceFirst(RegExp(r'-FLiNG$', caseSensitive: false), '')
    .trim();

String _image(Element? image, Uri base) {
  if (image == null) return '';
  for (final key in ['data-src', 'data-lazy-src', 'data-original', 'src']) {
    final value = image.attributes[key];
    if (value != null && !value.startsWith('data:')) {
      return base.resolve(value).toString();
    }
  }
  return '';
}

String _textWithBreaks(Node node) {
  if (node.nodeType == Node.TEXT_NODE) return node.text ?? '';
  if (node is Element && node.localName == 'br') return '\n';
  final content = node.nodes.map(_textWithBreaks).join();
  return node is Element &&
          {'p', 'div', 'li', 'h1', 'h2', 'h3'}.contains(node.localName)
      ? '\n$content\n'
      : content;
}

String _nextText(Node node) {
  final siblings = node.parentNode?.nodes;
  if (siblings == null) return '';
  final next = siblings.indexOf(node) + 1;
  return next < siblings.length ? siblings[next].text?.trim() ?? '' : '';
}

String decodeWindows1251(List<int> bytes) {
  const extended =
      '\u0402\u0403\u201a\u0453\u201e\u2026\u2020\u2021\u20ac\u2030\u0409\u2039\u040a\u040c\u040b\u040f'
      '\u0452\u2018\u2019\u201c\u201d\u2022\u2013\u2014\ufffd\u2122\u0459\u203a\u045a\u045c\u045b\u045f'
      '\u00a0\u040e\u045e\u0408\u00a4\u0490\u00a6\u00a7\u0401\u00a9\u0404\u00ab\u00ac\u00ad\u00ae\u0407'
      '\u00b0\u00b1\u0406\u0456\u0491\u00b5\u00b6\u00b7\u0451\u2116\u0454\u00bb\u0458\u0405\u0455\u0457';
  return String.fromCharCodes(
    bytes.map(
      (byte) => byte < 128
          ? byte
          : byte >= 192
          ? 0x410 + byte - 192
          : extended.codeUnitAt(byte - 128),
    ),
  );
}
