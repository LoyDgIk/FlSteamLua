// Network preferences adapted from Fluent-Steam-Lua (zlib license).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';

class NetworkCoverSource {
  const NetworkCoverSource(this.id, [this.template]);
  final String id;
  final String? template;

  String label(AppLocalizations l10n) => switch (id) {
    'auto' => l10n.auto,
    'direct' => l10n.originalCoverUrl,
    'store' => l10n.steamStoreApi,
    'heybox' => l10n.heyboxApi,
    'akamai-main' => l10n.akamaiMain,
    'akamai-backup' => l10n.akamaiBackup,
    'cloudflare' => l10n.cloudflareCdn,
    'akamai-large' => l10n.akamaiPortrait,
    _ => id,
  };
}

class NetworkProbeResult {
  const NetworkProbeResult({
    required this.sourceId,
    required this.label,
    this.elapsed,
    this.error,
  });
  final String sourceId;
  final String label;
  final Duration? elapsed;
  final String? error;
  bool get succeeded => error == null && elapsed != null;
}

class NetworkPreferences {
  NetworkPreferences(this.settings, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final SettingsStore settings;
  final http.Client _client;
  final bool _ownsClient;
  static const coverSources = <NetworkCoverSource>[
    NetworkCoverSource('auto'),
    NetworkCoverSource('direct'),
    NetworkCoverSource('store'),
    NetworkCoverSource('heybox'),
    NetworkCoverSource(
      'akamai-main',
      'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{id}/header.jpg',
    ),
    NetworkCoverSource(
      'akamai-backup',
      'https://cdn.akamai.steamstatic.com/steam/apps/{id}/header.jpg',
    ),
    NetworkCoverSource(
      'cloudflare',
      'https://cdn.cloudflare.steamstatic.com/steam/apps/{id}/header.jpg',
    ),
    NetworkCoverSource(
      'akamai-large',
      'https://cdn.akamai.steamstatic.com/steam/apps/{id}/library_600x900.jpg',
    ),
  ];
  static const mirrorHosts = [
    'direct',
    'gh-proxy.com',
    'ghfast.top',
    'gh-proxy.org',
  ];
  static const customMirrorId = 'custom';
  static const mirrorOptions = [...mirrorHosts, customMirrorId];
  static const _steamCoverHosts = {
    'shared.fastly.steamstatic.com',
    'shared.akamai.steamstatic.com',
    'shared.steamstatic.com',
    'cdn.akamai.steamstatic.com',
    'cdn.cloudflare.steamstatic.com',
    'steamcdn-a.akamaihd.net',
  };
  static const _mirrorProbeSource =
      'https://raw.githubusercontent.com/chen08209/FlClash/7fd417fb9a9a277c6a9339a8ac87f907df7c25f7/LICENSE';

  String get coverSourceId {
    final id = settings.get<String>('coverCdn', 'heybox');
    return coverSources.any((source) => source.id == id) ? id : 'heybox';
  }

  String get mirrorSelection {
    final value = settings.get<String>('githubMirror', 'direct');
    if (value == customMirrorId && normalizeMirror(customMirror) == null) {
      return 'direct';
    }
    return mirrorOptions.contains(value) ? value : 'direct';
  }

  String get customMirror =>
      settings.get<String>('githubMirrorCustom', '').trim();

  String get mirrorHost {
    final selection = mirrorSelection;
    if (selection == customMirrorId) {
      return normalizeMirror(customMirror) ?? 'direct';
    }
    return selection;
  }

  List<String> get mirrorTargets => [
    ...mirrorHosts,
    if (normalizeMirror(customMirror) != null) customMirrorId,
  ];

  static String? normalizeMirror(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(path: path).toString();
  }

  static String? mirrorBaseFor(SettingsStore settings) {
    final selection = settings.get<String>('githubMirror', 'direct');
    if (selection == 'direct') return null;
    if (selection == customMirrorId) {
      return normalizeMirror(settings.get<String>('githubMirrorCustom', ''));
    }
    return mirrorHosts.contains(selection) ? 'https://$selection' : null;
  }

  Future<void> setCoverSource(String id) {
    if (!coverSources.any((source) => source.id == id)) {
      throw const FormatException('Unknown cover source');
    }
    return settings.set('coverCdn', id);
  }

  Future<void> setMirror(String host, {String? custom}) async {
    if (!mirrorOptions.contains(host)) {
      throw const FormatException('Unknown GitHub mirror');
    }
    if (host == customMirrorId && normalizeMirror(custom ?? '') == null) {
      throw const FormatException('Invalid custom GitHub mirror');
    }
    await settings.set('githubMirror', host);
    if (host == customMirrorId) {
      await settings.set('githubMirrorCustom', normalizeMirror(custom!)!);
    }
  }

  static String defaultCover(int appId) =>
      'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$appId/header.jpg';

  Future<List<String>> coverUrls(int appId, {String? fallback}) async {
    final original = fallback ?? defaultCover(appId);
    try {
      return await _coverUrls(coverSourceId, appId, fallback: fallback);
    } on Exception {
      return _steamFallbacks(appId, original);
    }
  }

  Future<List<String>> _coverUrls(
    String sourceId,
    int appId, {
    String? fallback,
  }) async {
    if (appId <= 0) throw const FormatException('Invalid AppID');
    final original = fallback ?? defaultCover(appId);
    if (sourceId == 'auto') {
      final selected = await (_autoCoverSource ??= _probeAutoCoverSource());
      if (selected != 'auto') {
        try {
          return await _coverUrls(selected, appId, fallback: fallback);
        } on Exception {
          // The automatically chosen provider can go offline after probing.
        }
      }
      return _steamFallbacks(appId, original);
    }
    final source = coverSources.firstWhere((source) => source.id == sourceId);
    if (source.template != null) {
      return {
        source.template!.replaceAll('{id}', '$appId'),
        ..._steamFallbacks(appId, original),
      }.toList();
    }
    if (sourceId == 'direct') return _steamFallbacks(appId, original);
    final Uri endpoint;
    if (sourceId == 'store') {
      endpoint = Uri.https('store.steampowered.com', '/api/appdetails', {
        'appids': '$appId',
        'l': steamLanguageFor(settings.language),
        'filters': 'basic',
      });
    } else {
      endpoint = Uri.https('api.xiaoheihe.cn', '/game/web/get_game_detail/', {
        'appid': '$appId',
      });
    }
    final response = await _client
        .get(endpoint)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Cover metadata HTTP ${response.statusCode}',
        endpoint,
      );
    }
    final root = jsonDecode(response.body);
    if (root is! Map) throw const FormatException('Invalid cover metadata');
    final dynamic value = sourceId == 'store'
        ? (root['$appId'] is Map ? root['$appId']['data'] : null)
        : root['result'];
    final dynamic candidate = value is Map
        ? value[sourceId == 'store' ? 'header_image' : 'image']
        : null;
    final uri = candidate is String ? Uri.tryParse(candidate) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Cover provider returned no HTTPS image');
    }
    return {uri.toString(), ..._steamFallbacks(appId, original)}.toList();
  }

  static List<String> _steamFallbacks(int appId, String original) {
    final host = Uri.tryParse(original)?.host;
    final urls = <String>{original};
    if (host != null && _steamCoverHosts.contains(host)) {
      urls.addAll([
        'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$appId/header.jpg',
        'https://cdn.akamai.steamstatic.com/steam/apps/$appId/header.jpg',
        'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg',
        'https://steamcdn-a.akamaihd.net/steam/apps/$appId/header.jpg',
      ]);
    }
    return urls.toList();
  }

  static Future<String>? _autoCoverSource;

  @visibleForTesting
  static void resetAutoCoverSourceForTest() => _autoCoverSource = null;

  static Future<String> _probeAutoCoverSource() async {
    final client = http.Client();
    try {
      for (final sourceId in [
        'heybox',
        'akamai-main',
        'cloudflare',
        'akamai-backup',
      ]) {
        try {
          final source = coverSources.firstWhere(
            (source) => source.id == sourceId,
          );
          final Uri uri;
          if (source.template != null) {
            uri = Uri.parse(source.template!.replaceAll('{id}', '440'));
          } else {
            final endpoint = Uri.https(
              'api.xiaoheihe.cn',
              '/game/web/get_game_detail/',
              {'appid': '440'},
            );
            final response = await client
                .get(endpoint)
                .timeout(const Duration(seconds: 4));
            if (response.statusCode != 200) continue;
            final root = jsonDecode(response.body);
            final image = root is Map && root['result'] is Map
                ? root['result']['image']
                : null;
            final parsed = image is String ? Uri.tryParse(image) : null;
            if (parsed == null || parsed.scheme != 'https') continue;
            uri = parsed;
          }
          final imageResponse = await client
              .get(uri, headers: {'Range': 'bytes=0-127'})
              .timeout(const Duration(seconds: 4));
          if ((imageResponse.statusCode == 200 ||
                  imageResponse.statusCode == 206) &&
              isImage(imageResponse.bodyBytes)) {
            return sourceId;
          }
        } catch (_) {
          continue;
        }
      }
      return 'direct';
    } finally {
      client.close();
    }
  }

  Future<List<NetworkProbeResult>> testCovers({TaskContext? task}) async {
    final results = <NetworkProbeResult>[];
    for (final source in coverSources) {
      task?.checkCancelled();
      final watch = Stopwatch()..start();
      final label = source.label(localizationsFor(settings.language));
      try {
        final urls = await _coverUrls(source.id, 440);
        await _probe(Uri.parse(urls.first), image: true);
        results.add(
          NetworkProbeResult(
            sourceId: source.id,
            label: label,
            elapsed: watch.elapsed,
          ),
        );
      } catch (error) {
        results.add(
          NetworkProbeResult(
            sourceId: source.id,
            label: label,
            error: '$error',
          ),
        );
      }
      task?.report(label, results.length / coverSources.length);
    }
    return results;
  }

  Future<NetworkProbeResult> testCoverSource(
    String sourceId, {
    TaskContext? task,
  }) async {
    final source = coverSources.firstWhere((source) => source.id == sourceId);
    final label = source.label(localizationsFor(settings.language));
    final watch = Stopwatch()..start();
    task?.checkCancelled();
    try {
      final urls = await _coverUrls(sourceId, 440);
      await _probe(Uri.parse(urls.first), image: true);
      return NetworkProbeResult(
        sourceId: sourceId,
        label: label,
        elapsed: watch.elapsed,
      );
    } catch (error) {
      return NetworkProbeResult(
        sourceId: sourceId,
        label: label,
        error: '$error',
      );
    }
  }

  Future<List<NetworkProbeResult>> testMirrors({TaskContext? task}) async {
    const source =
        'https://raw.githubusercontent.com/chen08209/FlClash/7fd417fb9a9a277c6a9339a8ac87f907df7c25f7/LICENSE';
    final results = <NetworkProbeResult>[];
    final targets = mirrorTargets;
    for (final host in targets) {
      task?.checkCancelled();
      final watch = Stopwatch()..start();
      final label = _mirrorLabel(host);
      try {
        await _probe(_mirrorProbeUri(host) ?? Uri.parse(source));
        results.add(
          NetworkProbeResult(
            sourceId: host,
            label: label,
            elapsed: watch.elapsed,
          ),
        );
      } catch (error) {
        results.add(
          NetworkProbeResult(sourceId: host, label: label, error: '$error'),
        );
      }
      task?.report(label, results.length / targets.length);
    }
    return results;
  }

  Future<NetworkProbeResult> testMirror(
    String host, {
    TaskContext? task,
  }) async {
    final label = _mirrorLabel(host);
    final watch = Stopwatch()..start();
    task?.checkCancelled();
    try {
      final uri = _mirrorProbeUri(host);
      if (uri == null) {
        throw const FormatException('Configure the custom GitHub mirror first');
      }
      await _probe(uri);
      return NetworkProbeResult(
        sourceId: host,
        label: label,
        elapsed: watch.elapsed,
      );
    } catch (error) {
      return NetworkProbeResult(sourceId: host, label: label, error: '$error');
    }
  }

  String _mirrorLabel(String host) => switch (host) {
    'direct' => localizationsFor(settings.language).directGithub,
    customMirrorId => customMirror,
    _ => host,
  };

  Uri? _mirrorProbeUri(String host) {
    if (host == 'direct') return Uri.parse(_mirrorProbeSource);
    final base = _mirrorBase(host);
    return base == null ? null : Uri.parse('$base/$_mirrorProbeSource');
  }

  String? _mirrorBase(String host) {
    if (host == 'direct') return null;
    if (host == customMirrorId) return normalizeMirror(customMirror);
    return mirrorHosts.contains(host) ? 'https://$host' : null;
  }

  Future<void> _probe(Uri uri, {bool image = false}) async {
    final response = await _client
        .get(uri, headers: {'Range': 'bytes=0-127'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    if (image && !isImage(response.bodyBytes)) {
      throw const FormatException('The endpoint did not return an image');
    }
    if (!image && !response.body.contains('GNU GENERAL PUBLIC LICENSE')) {
      throw const FormatException('The mirror returned unexpected content');
    }
  }

  static bool isImage(List<int> bytes) =>
      bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff ||
      bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47 ||
      bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// Only a user's explicit mirror selection changes public download requests.
class NetworkHttpClient extends http.BaseClient {
  NetworkHttpClient({required this.settings, http.Client? inner})
    : _inner = inner ?? http.Client();
  final SettingsStore settings;
  final http.Client _inner;

  static bool canMirror(http.BaseRequest request) {
    final uri = request.url;
    if (!{'GET', 'HEAD'}.contains(request.method) ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        request.contentLength != 0) {
      return false;
    }
    const publicHeaders = {
      'accept',
      'accept-encoding',
      'user-agent',
      'range',
      'if-modified-since',
      'if-none-match',
    };
    if (request.headers.keys.any(
      (key) => !publicHeaders.contains(key.toLowerCase()),
    )) {
      return false;
    }
    final parts = uri.pathSegments;
    return uri.host == 'raw.githubusercontent.com' && parts.length >= 4 ||
        uri.host == 'github.com' &&
            parts.length >= 6 &&
            parts[2] == 'releases' &&
            (parts[3] == 'download' ||
                parts[3] == 'latest' && parts[4] == 'download');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final base = NetworkPreferences.mirrorBaseFor(settings);
    if (base == null || !canMirror(request)) {
      return _inner.send(request);
    }
    await request.finalize().drain<void>();
    final mirrored = Uri.parse('$base/${request.url}');
    http.Request copy(Uri uri) {
      final result = request is http.Abortable
          ? http.AbortableRequest(
              request.method,
              uri,
              abortTrigger: request.abortTrigger,
            )
          : http.Request(request.method, uri);
      result.headers.addAll(request.headers);
      result.followRedirects = request.followRedirects;
      result.maxRedirects = request.maxRedirects;
      result.persistentConnection = request.persistentConnection;
      return result;
    }

    try {
      final response = await _inner.send(copy(mirrored));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      await response.stream.drain<void>();
    } on http.RequestAbortedException {
      rethrow;
    } on http.ClientException {
      // The original public host remains the fallback for failed mirrors.
    }
    return _inner.send(copy(request.url));
  }

  @override
  void close() => _inner.close();
}
