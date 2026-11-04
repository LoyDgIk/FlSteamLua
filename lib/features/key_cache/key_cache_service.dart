// Functional reference: Fluent-Steam-Lua KeyCacheSubscriptionService and
// SteamDepotService. zlib notice: assets/licenses/Fluent-Steam-Lua-zlib.txt.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../platform/windows/dpapi.dart';
import '../steam_protocol/app_info.dart';
import '../steam_protocol/steam_protocol_service.dart'
    show SteamProtocolService;
import 'key_cache_models.dart';

export 'key_cache_models.dart';

typedef KeyCacheMetadataLoader =
    Future<SteamAppInfo> Function(int appId, String? accessToken);

class KeyCacheService extends ChangeNotifier {
  KeyCacheService({
    required this.paths,
    required this.settings,
    http.Client? httpClient,
    String Function(String)? protect,
    String Function(String)? unprotect,
    this.metadataLoader,
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _protect = protect ?? _protectData,
       _unprotect = unprotect ?? _unprotectData;

  final AppPaths paths;
  final SettingsStore settings;
  final http.Client _http;
  final bool _ownsHttp;
  final String Function(String) _protect;
  final String Function(String) _unprotect;
  final KeyCacheMetadataLoader? metadataLoader;
  final List<KeyCacheSubscription> _subscriptions = [];
  final Map<String, KeyCacheData> _cacheMemory = {};
  Future<void>? _loading;
  Future<void> _operations = Future.value();
  bool _disposed = false;

  List<KeyCacheSubscription> get subscriptions =>
      List.unmodifiable(_subscriptions);
  String get _configPath => paths.file('data/key-cache-subscriptions.json');
  String _cachePath(String id) =>
      paths.file('cache/key-subscriptions/$id/keys.json.dpapi');
  String _metadataPath(int appId, String sourceId) =>
      paths.file('cache/key-subscriptions/$sourceId/apps/$appId.json');

  static String _protectData(String value) =>
      WindowsDpapi.protectString(value, entropy: 'FlSteamLua:key-cache');
  static String _unprotectData(String value) =>
      WindowsDpapi.unprotectString(value, entropy: 'FlSteamLua:key-cache');

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _loading ??= _load();

  void clearMemoryCache() => _cacheMemory.clear();

  Future<void> _load() async {
    final file = File(_configPath);
    if (!await file.exists()) {
      _subscriptions.addAll(const [
        KeyCacheSubscription(
          id: 'default',
          name: '默认缓存',
          depotKeysUrl: 'https://api.993499094.xyz/depotkeys.json',
          tokenKeysUrl: 'https://api.993499094.xyz/appaccesstokens.json',
        ),
        KeyCacheSubscription(
          id: 'steam-toolbox',
          name: 'SteamToolbox 兼容缓存',
          depotKeysUrl: 'https://pan.qzyun.net/f/d/QQBkSX/depotkeys.json',
          tokenKeysUrl: 'https://pan.qzyun.net/f/d/z204cw/appaccesstokens.json',
        ),
      ]);
    } else {
      final raw = jsonDecode(_unprotect(await file.readAsString()));
      if (raw is! Map<String, dynamic> || raw['sources'] is! List) {
        throw const FormatException('Invalid key subscription configuration');
      }
      final ids = <String>{};
      for (final item in raw['sources'] as List) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid key subscription configuration');
        }
        final source = KeyCacheSubscription.fromJson(item);
        _validateSubscription(source);
        if (!ids.add(source.id)) {
          throw const FormatException('Duplicate key subscription ID');
        }
        _subscriptions.add(source);
      }
    }
    _changed();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _saveConfig(List<KeyCacheSubscription> sources) async {
    final content = jsonEncode({
      'sources': sources.map((source) => source.toJson()).toList(),
    });
    await _writeAtomic(File(_configPath), _protect(content));
    _subscriptions
      ..clear()
      ..addAll(sources);
    _changed();
  }

  Future<void> upsert(KeyCacheSubscription source) => _serialize(() async {
    await load();
    _validateSubscription(source);
    final list = [..._subscriptions];
    final index = list.indexWhere((item) => item.id == source.id);
    if (index < 0) {
      list.add(source);
    } else {
      list[index] = source;
    }
    await _saveConfig(list);
  });

  Future<void> remove(String id) => _serialize(() async {
    await load();
    _source(id);
    final list = _subscriptions.where((source) => source.id != id).toList();
    await _saveConfig(list);
    _cacheMemory.remove(id);
    final cache = Directory(p.dirname(_cachePath(id)));
    if (await cache.exists()) await cache.delete(recursive: true);
  });

  Future<void> update(String id, {TaskContext? task}) => _serialize(() async {
    await load();
    final source = _source(id);
    if (!source.enabled) throw StateError('This subscription is disabled');
    task?.report('Downloading depot keys');
    final downloads = await Future.wait([
      _download(Uri.parse(source.depotKeysUrl), task),
      _download(Uri.parse(source.tokenKeysUrl), task),
    ]);
    final depotText = downloads[0];
    final tokenText = downloads[1];
    task?.report('Validating key cache');
    final data = await _parseCacheAsync(depotText, tokenText);
    if (data.depotKeys.isEmpty || data.appTokens.isEmpty) {
      throw const FormatException(
        'A subscription must contain depot keys and app access tokens',
      );
    }
    task?.checkCancelled();
    final plain = jsonEncode({
      'depotKeys': {
        for (final entry in data.depotKeys.entries) '${entry.key}': entry.value,
      },
      'appTokens': {
        for (final entry in data.appTokens.entries) '${entry.key}': entry.value,
      },
    });
    final protected = await _transformAsync(plain, _protect);
    task?.checkCancelled();
    await _writeAtomic(File(_cachePath(id)), protected);
    _cacheMemory[id] = data;
    final updated = source.copyWith(
      lastUpdated: DateTime.now().toUtc(),
      depotCount: data.depotKeys.length,
      tokenCount: data.appTokens.length,
    );
    await _saveConfig([
      for (final value in _subscriptions) value.id == id ? updated : value,
    ]);
    task?.report(
      'Updated ${data.depotKeys.length} depot keys, ${data.appTokens.length} tokens',
      1,
    );
  });

  Future<void> updateDue({TaskContext? task}) async {
    await load();
    final now = DateTime.now().toUtc();
    for (final source in [..._subscriptions]) {
      task?.checkCancelled();
      if (source.enabled &&
          source.intervalHours > 0 &&
          (source.lastUpdated == null ||
              now.difference(source.lastUpdated!).inHours >=
                  source.intervalHours)) {
        await update(source.id, task: task);
      }
    }
  }

  Future<KeyCacheData> readCache(String sourceId) async {
    await load();
    if (!_source(sourceId).enabled) {
      throw StateError('This subscription is disabled');
    }
    return _readCache(sourceId);
  }

  Future<Map<int, String>> cachedDepotKeys(Iterable<int> depotIds) async {
    await load();
    final wanted = depotIds.toSet();
    final result = <int, String>{};
    for (final source in _subscriptions.where((value) => value.enabled)) {
      try {
        final cache = await _readCache(source.id);
        for (final id in wanted) {
          final key = cache.depotKeys[id];
          if (key != null) result[id] = key;
        }
        if (result.length == wanted.length) break;
      } on Object {
        // A damaged optional cache source must not block other local sources.
      }
    }
    return result;
  }

  Future<KeyCacheData> _readCache(String id) async {
    final memory = _cacheMemory[id];
    if (memory != null) return memory;
    final file = File(_cachePath(id));
    if (!await file.exists()) {
      const empty = KeyCacheData();
      _cacheMemory[id] = empty;
      return empty;
    }
    final encrypted = await file.readAsString();
    final decoded = await _decodeCacheAsync(encrypted, _unprotect);
    _cacheMemory[id] = decoded;
    return decoded;
  }

  Future<String> _download(Uri uri, TaskContext? task) async {
    _validateUrl(uri.toString());
    var current = uri;
    http.StreamedResponse? response;
    for (var redirects = 0; redirects <= 5; redirects++) {
      task?.checkCancelled();
      final request = http.Request('GET', current)
        ..headers['User-Agent'] = 'FlSteamLua/0.1.0'
        ..followRedirects = false;
      try {
        response = await _http
            .send(request)
            .timeout(const Duration(seconds: 30));
      } on http.ClientException {
        // Source query parameters can be credentials; keep them out of task logs.
        throw HttpException(
          'Cannot connect to key subscription host ${current.host}',
        );
      }
      if (![301, 302, 303, 307, 308].contains(response.statusCode)) break;
      await response.stream.timeout(const Duration(seconds: 30)).drain<void>();
      final location = response.headers['location'];
      if (redirects == 5 || location == null) {
        throw const HttpException(
          'Invalid or excessive key subscription redirects',
        );
      }
      current = current.resolve(location);
      _validateUrl(current.toString());
    }
    final received = response!;
    if (received.statusCode != 200) {
      await received.stream.timeout(const Duration(seconds: 30)).drain<void>();
      throw HttpException('Key subscription HTTP ${received.statusCode}');
    }
    const maximum = 256 * 1024 * 1024;
    if ((received.contentLength ?? 0) > maximum) {
      throw const FormatException('Key subscription exceeds 256 MiB');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in received.stream.timeout(
      const Duration(seconds: 30),
    )) {
      task?.checkCancelled();
      if (bytes.length + chunk.length > maximum) {
        throw const FormatException('Key subscription exceeds 256 MiB');
      }
      bytes.add(chunk);
    }
    task?.checkCancelled();
    return utf8.decode(bytes.takeBytes());
  }

  Future<void> refreshAppMetadata(
    int appId, {
    required String sourceId,
    Set<int>? dlcIds,
    TaskContext? task,
  }) async {
    _validateId(appId);
    final keys = await readCache(sourceId);
    task?.report('Loading app $appId metadata');
    final main = await _fetchApp(appId, keys.appTokens[appId], task);
    final values = <SteamAppInfo>[main];
    final selectedDlcIds = dlcIds ?? main.dlcAppIds.toSet();
    for (final id in main.dlcAppIds) {
      if (selectedDlcIds.contains(id)) {
        task?.checkCancelled();
        task?.report('Loading DLC $id metadata');
        values.add(await _fetchApp(id, keys.appTokens[id], task));
      }
    }
    // Each app record is independent; failed DLC requests never replace a
    // previously valid cached record or imply that the DLC has no depots.
    for (final value in values) {
      task?.checkCancelled();
      await _writeAtomic(
        File(_metadataPath(value.appId, sourceId)),
        jsonEncode(value.data),
      );
    }
  }

  Future<SteamAppInfo> _fetchApp(
    int appId,
    String? token,
    TaskContext? task,
  ) async {
    final loader = metadataLoader;
    if (loader != null) return loader(appId, token);
    final uri = Uri.https('api.steamcmd.net', '/v1/info/$appId');
    final text = await _download(uri, task);
    final info = await _parseRemoteAppAsync(appId, text);
    if (info.depots.isNotEmpty || token == null || token == '0') return info;
    task?.checkCancelled();
    task?.report('Requesting app $appId metadata with its cached access token');
    final steam = SteamProtocolService(
      paths: paths,
      settings: settings,
      httpClient: _http,
    );
    try {
      return await steam.getAppInfo(appId, accessToken: BigInt.parse(token));
    } finally {
      steam.dispose();
    }
  }

  Future<SteamAppInfo> _readApp(int appId, String sourceId) async {
    final file = File(_metadataPath(appId, sourceId));
    if (!await file.exists()) {
      throw StateError(
        'App $appId metadata is not cached. Refresh metadata online first.',
      );
    }
    final text = await file.readAsString();
    return _parseLocalAppAsync(appId, text);
  }

  Future<KeyCacheLuaPreview> generateOffline(
    int appId, {
    required String sourceId,
    Set<int> dlcIds = const {},
    bool pinManifests = false,
  }) async {
    _validateId(appId);
    final cache = await readCache(sourceId);
    if (cache.depotKeys.isEmpty && cache.appTokens.isEmpty) {
      throw StateError('Update this key cache subscription first');
    }
    final main = await _readApp(appId, sourceId);
    final dlcs = <SteamAppInfo>[];
    for (final id in main.dlcAppIds) {
      if (dlcIds.contains(id)) {
        dlcs.add(await _readApp(id, sourceId));
      }
    }
    final sourceName = _source(sourceId).name;
    return buildKeyCacheLua(
      main: main,
      dlcs: dlcs,
      cache: cache,
      sourceName: sourceName,
      dlcIds: dlcIds,
      pinManifests: pinManifests,
    );
  }

  Future<File> savePreview(
    KeyCacheLuaPreview preview,
    File target, {
    bool replace = false,
    TaskContext? task,
  }) async {
    if (p.extension(target.path).toLowerCase() != '.lua') {
      throw const FormatException('The output filename must end in .lua');
    }
    task?.checkCancelled();
    if (!replace && await target.exists()) {
      throw FileSystemException('The output file already exists', target.path);
    }
    await _writeAtomic(target, preview.lua);
    task?.report('Saved ${target.path}', 1);
    return target;
  }

  KeyCacheSubscription _source(String id) => _subscriptions.firstWhere(
    (source) => source.id == id,
    orElse: () => throw StateError('Unknown key subscription'),
  );

  static void _validateSubscription(KeyCacheSubscription source) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(source.id) ||
        source.name.trim().isEmpty ||
        source.intervalHours < 0 ||
        source.intervalHours > 8760 ||
        source.depotCount < 0 ||
        source.tokenCount < 0) {
      throw const FormatException('Invalid key subscription fields');
    }
    _validateUrl(source.depotKeysUrl);
    _validateUrl(source.tokenKeysUrl);
  }

  static void _validateUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException(
        'Key subscription URLs must be HTTPS without embedded user credentials',
      );
    }
  }

  static void _validateId(int id) {
    if (id <= 0 || id > 0xffffffff) throw ArgumentError.value(id, 'AppID');
  }

  static Future<void> _writeAtomic(File file, String content) async {
    await file.parent.create(recursive: true);
    final temp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temp.writeAsString(content, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_ownsHttp) _http.close();
    super.dispose();
  }
}

Future<KeyCacheData> _parseCacheAsync(String depots, String tokens) =>
    Isolate.run(() => parseKeyCache(depots, tokens));

Future<String> _transformAsync(
  String value,
  String Function(String) transform,
) => Isolate.run(() => transform(value));

Future<KeyCacheData> _decodeCacheAsync(
  String encrypted,
  String Function(String) unprotect,
) => Isolate.run(() {
  final raw = jsonDecode(unprotect(encrypted));
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('Invalid protected key cache');
  }
  return parseKeyCache(
    jsonEncode(raw['depotKeys']),
    jsonEncode(raw['appTokens']),
  );
});

Future<SteamAppInfo> _parseRemoteAppAsync(int appId, String text) =>
    Isolate.run(() {
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['data'] is! Map) {
        throw const FormatException('Invalid app metadata response');
      }
      return _parseApp(appId, (decoded['data'] as Map)['$appId']);
    });

Future<SteamAppInfo> _parseLocalAppAsync(int appId, String text) =>
    Isolate.run(() => _parseApp(appId, jsonDecode(text)));

KeyCacheData parseKeyCache(String depotJson, String tokenJson) {
  Map<int, String> parse(String text, {required bool token}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Invalid key cache JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Key cache must be a JSON object');
    }
    final result = <int, String>{};
    for (final entry in decoded.entries) {
      final id = int.tryParse(entry.key);
      if (id == null ||
          id < (token ? 0 : 1) ||
          id > 0xffffffff ||
          entry.value is! String) {
        throw const FormatException('Invalid key cache ID or value type');
      }
      final rawValue = entry.value as String;
      final value = token ? _normalizeToken(rawValue) : rawValue;
      if (value == null ||
          (!token && !RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(value))) {
        throw FormatException(
          'Invalid ${token ? 'app token' : 'depot key'} for $id',
        );
      }
      if (result.containsKey(id)) {
        throw const FormatException('Duplicate normalized cache ID');
      }
      result[id] = value;
    }
    return Map.unmodifiable(result);
  }

  return KeyCacheData(
    depotKeys: parse(depotJson, token: false),
    appTokens: parse(tokenJson, token: true),
  );
}

String? _normalizeToken(String value) {
  final maximum = BigInt.parse('18446744073709551615');
  BigInt? token;
  if (RegExp(r'^\d{1,20}$').hasMatch(value)) {
    token = BigInt.parse(value);
  } else if (RegExp(r'^[A-Fa-f0-9]{16}$').hasMatch(value) ||
      RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(value)) {
    token = BigInt.parse(value, radix: 16);
  }
  return token == null || token > maximum ? null : '$token';
}

SteamAppInfo _parseApp(int appId, dynamic data) {
  if (data is! Map<String, dynamic> ||
      (data['common'] != null && data['common'] is! Map) ||
      (data['depots'] != null && data['depots'] is! Map) ||
      (data['extended'] != null && data['extended'] is! Map) ||
      data.isEmpty) {
    throw FormatException('Invalid or unavailable app $appId metadata');
  }
  final normalized = Map<String, dynamic>.from(data);
  final depots = normalized['depots'];
  if (depots is Map) {
    for (final entry in depots.entries) {
      final id = int.tryParse('${entry.key}');
      if (id != null && (id <= 0 || id > 0xffffffff || entry.value is! Map)) {
        throw const FormatException('Invalid depot metadata');
      }
    }
  }
  final extended = normalized['extended'];
  if (extended is Map && extended['listofdlc'] is List) {
    normalized['extended'] = {
      ...extended,
      'listofdlc': (extended['listofdlc'] as List).join(','),
    };
  }
  return SteamAppInfo.fromData(appId, normalized);
}

KeyCacheLuaPreview buildKeyCacheLua({
  required SteamAppInfo main,
  required List<SteamAppInfo> dlcs,
  required KeyCacheData cache,
  required String sourceName,
  required Set<int> dlcIds,
  required bool pinManifests,
}) {
  final out = StringBuffer(
    '-- Generated by FlSteamLua from a local key cache.\n',
  );
  final written = <int>{};
  final tokens = <int>{};
  final missing = <int>{};
  final skipped = <int>{};
  var matched = 0;
  String comment(String value) => value.replaceAll(RegExp(r'[\r\n]'), ' ');
  void app(int id, String name, {bool requireKey = false}) {
    final key = cache.depotKeys[id];
    if (key == null && requireKey) {
      missing.add(id);
      return;
    }
    if (!written.add(id)) return;
    out.write(key == null ? 'addappid($id)' : 'addappid($id, 1, "$key")');
    if (name.isNotEmpty) out.write(' -- ${comment(name)}');
    out.writeln();
    if (key != null) matched++;
  }

  void token(int id) {
    final value = cache.appTokens[id];
    if (value != null && tokens.add(id)) {
      out.writeln('addtoken($id, "$value")');
      matched++;
    }
  }

  final allDlcIds = main.dlcAppIds.toSet();
  final selectedDlcIds = allDlcIds.intersection(dlcIds);
  final mainDepotIds = main.depots.map((depot) => depot.depotId).toSet();
  app(main.appId, main.name);
  token(main.appId);
  void depot(SteamDepotInfo value) {
    final linkedDlcId =
        value.dlcAppId ??
        (allDlcIds.contains(value.depotId) ? value.depotId : null);
    if (linkedDlcId != null && !selectedDlcIds.contains(linkedDlcId)) {
      return;
    }
    final alreadyWritten = written.contains(value.depotId);
    app(value.depotId, value.name, requireKey: true);
    if (!alreadyWritten &&
        written.contains(value.depotId) &&
        value.manifestGid != null) {
      final comment = pinManifests ? '' : '--';
      out.writeln(
        '${comment}setManifestid(${value.depotId},"${value.manifestGid}",0)',
      );
    }
  }

  for (final value in main.depots) {
    depot(value);
  }
  if (selectedDlcIds.isNotEmpty) {
    for (final dlc in dlcs) {
      final keyless =
          cache.depotKeys[dlc.appId] == null &&
          (dlc.depots.isNotEmpty || mainDepotIds.contains(dlc.appId));
      if (keyless) {
        skipped.add(dlc.appId);
        missing.add(dlc.appId);
      } else {
        app(dlc.appId, dlc.name);
      }
      token(dlc.appId);
      for (final value in dlc.depots) {
        depot(value);
      }
    }
  }
  if (matched == 0) {
    throw StateError(
      'This subscription contains no matching keys or tokens for app ${main.appId}',
    );
  }
  return KeyCacheLuaPreview(
    appId: main.appId,
    name: main.name,
    lua: out.toString(),
    sourceName: sourceName,
    missingDepotIds: missing.toList()..sort(),
    skippedDlcIds: skipped.toList()..sort(),
    dlcIds: selectedDlcIds.toList()..sort(),
  );
}
