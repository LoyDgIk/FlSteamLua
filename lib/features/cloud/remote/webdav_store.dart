import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'remote_store.dart';
import 'windows_webdav_transport.dart';

class WebDavConfig {
  const WebDavConfig({
    required this.url,
    this.username = '',
    this.password = '',
    this.auth = 'basic',
    this.bearerToken = '',
    this.keyPrefix = '',
    this.allowInsecureHttp = false,
    this.allowInsecureTls = false,
    this.timeoutSec = 30,
    this.extraHeaders = const {},
  });
  final String url;
  final String username;
  final String password;
  final String auth;
  final String bearerToken;
  final String keyPrefix;
  final bool allowInsecureHttp;
  final bool allowInsecureTls;
  final int timeoutSec;
  final Map<String, String> extraHeaders;
  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['extra_headers'];
    final headers = <String, String>{};
    if (raw is String || raw is List) {
      final lines = raw is String
          ? const LineSplitter().convert(raw)
          : raw.cast<String>();
      for (final line in lines) {
        final index = line.indexOf(':');
        if (index > 0) {
          headers[line.substring(0, index).trim()] = line
              .substring(index + 1)
              .trim();
        }
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    return WebDavConfig(
      url: json['url'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      auth: json['auth'] as String? ?? 'basic',
      bearerToken: json['bearer_token'] as String? ?? '',
      keyPrefix: json['key_prefix'] as String? ?? '',
      allowInsecureHttp: json['allow_insecure_http'] as bool? ?? false,
      allowInsecureTls: json['allow_insecure_tls'] as bool? ?? false,
      timeoutSec: (json['timeout_sec'] as num?)?.toInt() ?? 30,
      extraHeaders: headers,
    );
  }
  Map<String, dynamic> toJson() => {
    'url': url,
    'username': username,
    'password': password,
    'auth': auth,
    'bearer_token': bearerToken,
    'key_prefix': keyPrefix,
    'allow_insecure_http': allowInsecureHttp,
    'allow_insecure_tls': allowInsecureTls,
    'timeout_sec': timeoutSec,
    'extra_headers': extraHeaders.entries
        .map((e) => '${e.key}: ${e.value}')
        .toList(),
  };
}

class WebDavRemoteStore implements RemoteStore {
  WebDavRemoteStore(
    this.client,
    this.config, {
    WindowsWebDavSender? windowsSender,
  }) : endpoint = validateRemoteEndpoint(
         config.url,
         allowInsecureHttp: config.allowInsecureHttp,
       ),
       _windowsSender = windowsSender ?? sendWindowsWebDavRequest {
    if (![
      'basic',
      'auto',
      'digest',
      'ntlm',
      'negotiate',
      'bearer',
      'none',
    ].contains(config.auth)) {
      throw const FormatException('Unsupported WebDAV authentication mode');
    }
    if (['ntlm', 'negotiate'].contains(config.auth) &&
        config.username.trim().isEmpty) {
      throw const FormatException('A WebDAV username is required');
    }
    if ([
      config.username,
      config.password,
      config.bearerToken,
    ].any((value) => value.contains('\u0000'))) {
      throw const FormatException('Invalid WebDAV credential');
    }
    final headerName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
    final invalidHeaderValue = RegExp(r'[\x00-\x08\x0A-\x1F\x7F]');
    if (config.extraHeaders.entries.any(
      (entry) =>
          !headerName.hasMatch(entry.key) ||
          invalidHeaderValue.hasMatch(entry.value),
    )) {
      throw const FormatException('Invalid WebDAV header');
    }
    if (config.timeoutSec < 0 || config.timeoutSec > 300) {
      throw const FormatException(
        'WebDAV timeout must be between 0 and 300 seconds',
      );
    }
  }
  final http.Client client;
  final WebDavConfig config;
  final Uri endpoint;
  final WindowsWebDavSender _windowsSender;
  String? _digestChallenge;
  int _nonceCount = 0;
  List<String> get _rootSegments {
    final segments = endpoint.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.last.toLowerCase() != 'cloudredirect') {
      segments.add('CloudRedirect');
    }
    return [
      ...segments,
      ...normalizeRemotePath(
        config.keyPrefix,
      ).split('/').where((s) => s.isNotEmpty),
    ];
  }

  Uri _uri(String path, {bool collection = false}) => endpoint.replace(
    pathSegments: [
      ..._rootSegments,
      ...normalizeRemotePath(path).split('/').where((s) => s.isNotEmpty),
      if (collection) '',
    ],
  );

  String _digestAuthorization(String method, Uri uri, String challenge) {
    final values = <String, String>{};
    for (final match in RegExp(
      r'(\w+)=(?:"([^"]*)"|([^,\s]+))',
    ).allMatches(challenge)) {
      values[match.group(1)!] = match.group(2) ?? match.group(3)!;
    }
    final realm = values['realm'];
    final nonce = values['nonce'];
    if (realm == null || nonce == null) {
      throw const FormatException('Invalid WebDAV digest challenge');
    }
    final algorithm = (values['algorithm'] ?? 'MD5').toUpperCase();
    if (!['MD5', 'SHA-256'].contains(algorithm)) {
      throw FormatException('Unsupported digest algorithm: $algorithm');
    }
    String digest(String text) => (algorithm == 'MD5' ? md5 : sha256)
        .convert(utf8.encode(text))
        .toString();
    final qops = values['qop']?.split(',').map((s) => s.trim()).toList();
    if (qops != null && !qops.contains('auth')) {
      throw const FormatException('WebDAV digest requires auth QOP');
    }
    final target = uri.hasQuery && uri.query.isNotEmpty
        ? '${uri.path}?${uri.query}'
        : uri.path;
    final nc = (++_nonceCount).toRadixString(16).padLeft(8, '0');
    final cnonce = sha256
        .convert(utf8.encode('${DateTime.now().microsecondsSinceEpoch}:$nc'))
        .toString()
        .substring(0, 24);
    final ha1 = digest('${config.username}:$realm:${config.password}');
    final ha2 = digest('$method:$target');
    final response = digest(
      qops == null ? '$ha1:$nonce:$ha2' : '$ha1:$nonce:$nc:$cnonce:auth:$ha2',
    );
    String quote(String text) =>
        text.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return 'Digest username="${quote(config.username)}", realm="${quote(realm)}", nonce="${quote(nonce)}", '
        'uri="${quote(target)}", response="$response", algorithm=$algorithm'
        '${qops == null ? '' : ', qop=auth, nc=$nc, cnonce="$cnonce"'}'
        '${values['opaque'] == null ? '' : ', opaque="${quote(values['opaque']!)}"'}';
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    List<int> body = const [],
    Map<String, String> headers = const {},
  }) async {
    Future<http.Response> attempt() async {
      final auth = <String, String>{...config.extraHeaders, ...headers};
      final hasAuth = auth.keys.any(
        (key) => key.toLowerCase() == 'authorization',
      );
      if (!hasAuth) {
        if (_digestChallenge != null) {
          auth['Authorization'] = _digestAuthorization(
            method,
            uri,
            _digestChallenge!,
          );
        } else if (config.auth == 'basic' || config.auth == 'auto') {
          auth['Authorization'] =
              'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
        } else if (config.auth == 'bearer') {
          auth['Authorization'] = 'Bearer ${config.bearerToken}';
        }
      }
      final request = http.Request(method, uri)
        ..headers.addAll(auth)
        ..bodyBytes = body;
      if (['ntlm', 'negotiate'].contains(config.auth) ||
          config.allowInsecureTls) {
        return _windowsSender(
          WindowsWebDavRequest(
            method: method,
            uri: uri,
            headers: Map.of(request.headers),
            body: request.bodyBytes,
            auth: config.auth,
            username: config.username,
            password: config.password,
            timeoutSec: config.timeoutSec,
            allowInsecureTls: config.allowInsecureTls,
          ),
        );
      }
      return http.Response.fromStream(await client.send(request)).timeout(
        Duration(seconds: config.timeoutSec > 0 ? config.timeoutSec : 30),
      );
    }

    var response = await attempt();
    final challenge = response.headers['www-authenticate'];
    final offered = webDavAuthenticationSchemes(challenge ?? '');
    if (response.statusCode == 401 &&
        config.auth == 'auto' &&
        (offered.contains('negotiate') || offered.contains('ntlm'))) {
      final request = http.Request(method, uri)
        ..headers.addAll({...config.extraHeaders, ...headers})
        ..bodyBytes = body;
      return _windowsSender(
        WindowsWebDavRequest(
          method: method,
          uri: uri,
          headers: Map.of(request.headers),
          body: request.bodyBytes,
          auth: offered.contains('negotiate') ? 'negotiate' : 'ntlm',
          username: config.username,
          password: config.password,
          timeoutSec: config.timeoutSec,
          allowInsecureTls: config.allowInsecureTls,
        ),
      );
    }
    if (response.statusCode == 401 &&
        ['auto', 'digest'].contains(config.auth) &&
        challenge != null &&
        challenge.toLowerCase().startsWith('digest ')) {
      _digestChallenge = challenge;
      response = await attempt();
    }
    return response;
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteStoreException(
        'WebDAV request failed',
        statusCode: response.statusCode,
      );
    }
  }

  static const _propfind =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/>'
      '<d:getlastmodified/></d:prop></d:propfind>';
  @override
  Future<List<RemoteEntry>> list(String path) async {
    final requested = normalizeRemotePath(path);
    final response = await _send(
      'PROPFIND',
      _uri(path, collection: true),
      body: utf8.encode(_propfind),
      headers: {'Depth': '1', 'Content-Type': 'application/xml; charset=utf-8'},
    );
    if (response.statusCode == 404) return [];
    _check(response);
    final document = XmlDocument.parse(response.body);
    final entries = <RemoteEntry>[];
    final root = _uri('', collection: true);
    for (final item in document.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'response',
    )) {
      String value(String name) =>
          item.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == name)
              .map((e) => e.innerText)
              .firstOrNull ??
          '';
      final href = value('href');
      final uri = _uri(requested, collection: true).resolve(href);
      if (uri.origin != root.origin) continue;
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final base = root.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.length < base.length ||
          List.generate(
            base.length,
            (i) => segments[i] == base[i],
          ).contains(false)) {
        continue;
      }
      final relative = normalizeRemotePath(
        segments.skip(base.length).join('/'),
      );
      if (relative == requested || parentRemotePath(relative) != requested) {
        continue;
      }
      final propstats = item.childElements.where(
        (e) => e.name.local == 'propstat',
      );
      final succeeded = propstats.any(
        (e) => e.childElements
            .where((v) => v.name.local == 'status')
            .any((v) => v.innerText.contains(' 200 ')),
      );
      if (propstats.isNotEmpty && !succeeded) continue;
      final date = value('getlastmodified');
      DateTime? modified;
      if (date.isNotEmpty) {
        modified = DateTime.tryParse(date);
        if (modified == null) {
          try {
            modified = HttpDate.parse(date);
          } on FormatException {
            /* Optional server metadata. */
          }
        }
      }
      entries.add(
        RemoteEntry(
          path: relative,
          isDirectory: item.descendants.whereType<XmlElement>().any(
            (e) => e.name.local == 'collection',
          ),
          size: int.tryParse(value('getcontentlength')) ?? 0,
          modifiedAt: modified,
        ),
      );
    }
    return entries;
  }

  @override
  Future<Uint8List> read(String path) async {
    final response = await _send('GET', _uri(path));
    _check(response);
    return response.bodyBytes;
  }

  Future<void> _ensureParents(String path) async {
    final segments = [
      ..._rootSegments,
      ...parentRemotePath(path).split('/').where((s) => s.isNotEmpty),
    ];
    final original = endpoint.pathSegments.where((s) => s.isNotEmpty).length;
    for (var count = original + 1; count <= segments.length; count++) {
      final uri = endpoint.replace(pathSegments: [...segments.take(count), '']);
      final response = await _send('MKCOL', uri);
      if (response.statusCode != 405) _check(response);
    }
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    await _ensureParents(path);
    _check(await _send('PUT', _uri(path), body: bytes));
  }

  @override
  Future<void> delete(String path) async {
    final response = await _send('DELETE', _uri(path));
    if (response.statusCode != 404) _check(response);
  }

  @override
  Future<void> testConnection() async {
    final response = await _send(
      'PROPFIND',
      endpoint,
      body: utf8.encode(_propfind),
      headers: {'Depth': '0', 'Content-Type': 'application/xml; charset=utf-8'},
    );
    _check(response);
  }
}
