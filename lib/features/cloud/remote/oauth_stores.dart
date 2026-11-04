import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'remote_store.dart';

typedef AccessTokenProvider = Future<String> Function();

abstract class _OAuthStore implements RemoteStore {
  _OAuthStore(this.client, this.accessToken);
  final http.Client client;
  final AccessTokenProvider accessToken;

  Future<http.Response> request(
    String method,
    Uri uri, {
    List<int> bytes = const [],
    Map<String, String> headers = const {},
    bool authenticated = true,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll({
        if (authenticated) 'Authorization': 'Bearer ${await accessToken()}',
        ...headers,
      })
      ..bodyBytes = bytes;
    return http.Response.fromStream(
      await client.send(request),
    ).timeout(const Duration(seconds: 60));
  }

  void check(http.Response response, String provider) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteStoreException(
        '$provider request failed',
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, dynamic> object(http.Response response, String provider) {
    check(response, provider);
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw FormatException('Invalid $provider response');
    }
    return value;
  }
}

class GoogleDriveRemoteStore extends _OAuthStore {
  GoogleDriveRemoteStore(super.client, super.accessToken);
  static const _folderMime = 'application/vnd.google-apps.folder';
  final Map<String, String> _folderIds = {};

  Uri _api(String path, [Map<String, String> query = const {}]) =>
      Uri.https('www.googleapis.com', '/drive/v3/$path', query);
  String _literal(String value) =>
      value.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  Future<List<Map<String, dynamic>>> _children(
    String parent, {
    String? name,
  }) async {
    final result = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final query =
          "'${_literal(parent)}' in parents and trashed = false"
          "${name == null ? '' : " and name = '${_literal(name)}'"}";
      final data = object(
        await request(
          'GET',
          _api('files', {
            'q': query,
            'fields':
                'nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink)',
            'pageSize': '1000',
            'pageToken': ?pageToken,
          }),
        ),
        'Google Drive',
      );
      final files = data['files'];
      if (files is! List) {
        throw const FormatException('Google Drive file list missing');
      }
      result.addAll(files.cast<Map<String, dynamic>>());
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return result;
  }

  Future<String?> _folder(String path, {bool create = false}) async {
    final normalized = normalizeRemotePath(path);
    if (_folderIds.containsKey(normalized)) return _folderIds[normalized];
    String parent = 'root';
    String accumulated = '';
    for (final name in [
      'CloudRedirect',
      ...normalized.split('/').where((s) => s.isNotEmpty),
    ]) {
      final cacheKey = accumulated;
      if (name == 'CloudRedirect' &&
          accumulated.isEmpty &&
          _folderIds.containsKey('')) {
        parent = _folderIds['']!;
        accumulated = '/';
        continue;
      }
      final matches = await _children(parent, name: name);
      final folders = matches.where((f) => f['mimeType'] == _folderMime);
      String? id = folders.firstOrNull?['id'] as String?;
      if (id == null) {
        if (!create) return null;
        final data = object(
          await request(
            'POST',
            _api('files', {'fields': 'id'}),
            headers: {'Content-Type': 'application/json'},
            bytes: utf8.encode(
              jsonEncode({
                'name': name,
                'mimeType': _folderMime,
                'parents': [parent],
              }),
            ),
          ),
          'Google Drive',
        );
        id = data['id'] as String;
      }
      parent = id;
      if (accumulated.isEmpty) {
        _folderIds[''] = id;
        accumulated = '/';
      } else {
        accumulated = '$cacheKey$name/';
        _folderIds[normalizeRemotePath(accumulated)] = id;
      }
    }
    _folderIds[normalized] = parent;
    return parent;
  }

  Future<Map<String, dynamic>?> _file(String path) async {
    final parent = await _folder(parentRemotePath(path));
    if (parent == null) return null;
    return (await _children(parent, name: remoteName(path))).firstOrNull;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final folder = await _folder(path);
    if (folder == null) return [];
    return (await _children(folder))
        .map(
          (item) => RemoteEntry(
            path: joinRemotePath(path, item['name'] as String),
            isDirectory: item['mimeType'] == _folderMime,
            size: int.tryParse(item['size']?.toString() ?? '') ?? 0,
            modifiedAt: DateTime.tryParse(
              item['modifiedTime'] as String? ?? '',
            ),
            remoteId: item['id'] as String?,
            webUrl: item['webViewLink'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<Uint8List> read(String path) async {
    final item = await _file(path);
    if (item == null) {
      throw const RemoteStoreException(
        'Google Drive save not found',
        statusCode: 404,
      );
    }
    final response = await request(
      'GET',
      _api('files/${item['id']}', {'alt': 'media'}),
    );
    check(response, 'Google Drive');
    return response.bodyBytes;
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    final normalized = normalizeRemotePath(path);
    if (normalized.isEmpty) {
      throw const FormatException('A save file path is required');
    }
    final parent = await _folder(parentRemotePath(normalized), create: true);
    final existing = await _file(normalized);
    final metadata = <String, Object>{
      'name': remoteName(normalized),
      if (existing == null) 'parents': [parent!],
    };
    final uri = Uri.https(
      'www.googleapis.com',
      '/upload/drive/v3/files${existing == null ? '' : '/${existing['id']}'}',
      {'uploadType': 'resumable', 'fields': 'id'},
    );
    final start = await request(
      existing == null ? 'POST' : 'PATCH',
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': bytes.length.toString(),
      },
      bytes: utf8.encode(jsonEncode(metadata)),
    );
    check(start, 'Google Drive');
    final location = start.headers['location'];
    if (location == null) {
      throw const FormatException('Google Drive upload session missing');
    }
    final uploadUri = validateRemoteEndpoint(location);
    if (uploadUri.host != 'www.googleapis.com' &&
        !uploadUri.host.endsWith('.googleapis.com')) {
      throw const FormatException('Unexpected Google Drive upload endpoint');
    }
    // Upload URLs include a session query and must be retained after validation.
    final response = await request(
      'PUT',
      uploadUri.replace(query: Uri.parse(location).query),
      bytes: bytes,
      headers: {'Content-Type': 'application/octet-stream'},
    );
    check(response, 'Google Drive');
  }

  @override
  Future<void> delete(String path) async {
    if (normalizeRemotePath(path).isEmpty) {
      throw const FormatException('Cannot delete cloud root');
    }
    final item = await _file(path);
    if (item == null) return;
    final response = await request('DELETE', _api('files/${item['id']}'));
    if (response.statusCode != 404) check(response, 'Google Drive');
    final normalized = normalizeRemotePath(path);
    _folderIds.removeWhere(
      (key, _) => key == normalized || key.startsWith('$normalized/'),
    );
  }

  @override
  Future<void> testConnection() async {
    object(
      await request('GET', _api('about', {'fields': 'user(displayName)'})),
      'Google Drive',
    );
  }
}

class OneDriveRemoteStore extends _OAuthStore {
  OneDriveRemoteStore(super.client, super.accessToken);
  Uri _api(String suffix) =>
      Uri.parse('https://graph.microsoft.com/v1.0$suffix');
  String _path(String path) =>
      encodedRemotePath(joinRemotePath('CloudRedirect', path));
  Uri _item(String path, [String suffix = '']) =>
      _api('/me/drive/root:/${_path(path)}${suffix.isEmpty ? '' : ':$suffix'}');
  Future<List<Map<String, dynamic>>> _children(String path) async {
    Uri? next = _item(path, '/children');
    final results = <Map<String, dynamic>>[];
    while (next != null) {
      final response = await request('GET', next);
      if (response.statusCode == 404) return [];
      final data = object(response, 'OneDrive');
      final items = data['value'];
      if (items is! List) {
        throw const FormatException('OneDrive file list missing');
      }
      results.addAll(items.cast<Map<String, dynamic>>());
      final link = data['@odata.nextLink'] as String?;
      next = link == null ? null : Uri.parse(link);
      if (next != null &&
          (next.scheme != 'https' || next.host != 'graph.microsoft.com')) {
        throw const FormatException('Unexpected OneDrive pagination endpoint');
      }
    }
    return results;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async => (await _children(path))
      .map(
        (item) => RemoteEntry(
          path: joinRemotePath(path, item['name'] as String),
          isDirectory: item['folder'] is Map,
          size: (item['size'] as num?)?.toInt() ?? 0,
          modifiedAt: DateTime.tryParse(
            item['lastModifiedDateTime'] as String? ?? '',
          ),
          remoteId: item['id'] as String?,
          webUrl: item['webUrl'] as String?,
        ),
      )
      .toList();
  @override
  Future<Uint8List> read(String path) async {
    final response = await request('GET', _item(path, '/content'));
    check(response, 'OneDrive');
    return response.bodyBytes;
  }

  Future<void> _ensureParents(String path) async {
    final segments = [
      'CloudRedirect',
      ...parentRemotePath(path).split('/').where((s) => s.isNotEmpty),
    ];
    var parent = '';
    for (final segment in segments) {
      final encoded = encodedRemotePath(joinRemotePath(parent, segment));
      final probe = await request('GET', _api('/me/drive/root:/$encoded'));
      if (probe.statusCode == 404) {
        final parentUri = parent.isEmpty
            ? _api('/me/drive/root/children')
            : _api('/me/drive/root:/${encodedRemotePath(parent)}:/children');
        final response = await request(
          'POST',
          parentUri,
          headers: {'Content-Type': 'application/json'},
          bytes: utf8.encode(
            jsonEncode({
              'name': segment,
              'folder': <String, dynamic>{},
              '@microsoft.graph.conflictBehavior': 'fail',
            }),
          ),
        );
        if (response.statusCode != 409) check(response, 'OneDrive');
      } else {
        check(probe, 'OneDrive');
      }
      parent = joinRemotePath(parent, segment);
    }
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    final normalized = normalizeRemotePath(path);
    if (normalized.isEmpty) {
      throw const FormatException('A save file path is required');
    }
    await _ensureParents(normalized);
    if (bytes.length <= 4 * 1024 * 1024) {
      final response = await request(
        'PUT',
        _item(normalized, '/content'),
        bytes: bytes,
        headers: {'Content-Type': 'application/octet-stream'},
      );
      check(response, 'OneDrive');
      return;
    }
    final session = object(
      await request(
        'POST',
        _item(normalized, '/createUploadSession'),
        headers: {'Content-Type': 'application/json'},
        bytes: utf8.encode(
          jsonEncode({
            'item': {
              '@microsoft.graph.conflictBehavior': 'replace',
              'name': remoteName(normalized),
            },
          }),
        ),
      ),
      'OneDrive',
    );
    final location = session['uploadUrl'] as String?;
    if (location == null) {
      throw const FormatException('OneDrive upload session missing');
    }
    validateRemoteEndpoint(location);
    final uri = Uri.parse(location);
    const chunkSize = 10 * 1024 * 1024;
    for (var start = 0; start < bytes.length; start += chunkSize) {
      final end = math.min(start + chunkSize, bytes.length);
      final response = await request(
        'PUT',
        uri,
        authenticated: false,
        bytes: bytes.sublist(start, end),
        headers: {
          'Content-Length': (end - start).toString(),
          'Content-Range': 'bytes $start-${end - 1}/${bytes.length}',
        },
      );
      check(response, 'OneDrive');
    }
  }

  @override
  Future<void> delete(String path) async {
    if (normalizeRemotePath(path).isEmpty) {
      throw const FormatException('Cannot delete cloud root');
    }
    final response = await request('DELETE', _item(path));
    if (response.statusCode != 404) check(response, 'OneDrive');
  }

  @override
  Future<void> testConnection() async {
    object(
      await request('GET', _api('/me/drive?\$select=id,driveType')),
      'OneDrive',
    );
  }
}
