import 'dart:typed_data';

class RemoteEntry {
  const RemoteEntry({
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modifiedAt,
    this.remoteId,
    this.webUrl,
  });
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modifiedAt;
  final String? remoteId;
  final String? webUrl;
}

abstract class RemoteStore {
  Future<List<RemoteEntry>> list(String path);
  Future<Uint8List> read(String path);
  Future<void> write(String path, List<int> bytes);
  Future<void> delete(String path);
  Future<void> testConnection();
}

class RemoteStoreException implements Exception {
  const RemoteStoreException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

// Remote paths are untrusted names returned by providers and user imports.
String normalizeRemotePath(String path) {
  final segments = path
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.any((s) => s == '.' || s == '..' || s.contains('\u0000'))) {
    throw const FormatException('Invalid remote save path');
  }
  return segments.join('/');
}

String joinRemotePath(String parent, String child) =>
    normalizeRemotePath('$parent/$child');

String parentRemotePath(String path) {
  final normalized = normalizeRemotePath(path);
  final index = normalized.lastIndexOf('/');
  return index < 0 ? '' : normalized.substring(0, index);
}

String remoteName(String path) => normalizeRemotePath(path).split('/').last;

String encodedRemotePath(String path) =>
    normalizeRemotePath(path).split('/').map(Uri.encodeComponent).join('/');

Uri validateRemoteEndpoint(String value, {bool allowInsecureHttp = false}) {
  final uri = Uri.parse(value);
  if (!uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      !(uri.scheme == 'https' || (allowInsecureHttp && uri.scheme == 'http'))) {
    throw const FormatException('A valid HTTPS endpoint is required');
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: uri.pathSegments,
  );
}
