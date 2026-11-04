import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'remote_store.dart';

class S3Config {
  const S3Config({
    required this.endpoint,
    required this.bucket,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.region = 'auto',
    this.keyPrefix = '',
    this.signPayload = false,
    this.allowInsecureHttp = false,
  });
  final String endpoint;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String region;
  final String keyPrefix;
  final bool signPayload;
  final bool allowInsecureHttp;
  factory S3Config.fromJson(Map<String, dynamic> json) => S3Config(
    endpoint: json['endpoint'] as String? ?? '',
    bucket: json['bucket'] as String? ?? '',
    accessKeyId: json['access_key_id'] as String? ?? '',
    secretAccessKey: json['secret_access_key'] as String? ?? '',
    region: json['region'] as String? ?? 'auto',
    keyPrefix: json['key_prefix'] as String? ?? '',
    signPayload: json['sign_payload'] as bool? ?? false,
    allowInsecureHttp: json['allow_insecure_http'] as bool? ?? false,
  );
  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'bucket': bucket,
    'access_key_id': accessKeyId,
    'secret_access_key': secretAccessKey,
    'region': region,
    'key_prefix': keyPrefix,
    'sign_payload': signPayload,
    'allow_insecure_http': allowInsecureHttp,
  };
}

class S3RemoteStore implements RemoteStore {
  S3RemoteStore(this.client, this.config, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      endpoint = validateRemoteEndpoint(
        config.endpoint,
        allowInsecureHttp: config.allowInsecureHttp,
      ) {
    if (config.bucket.isEmpty ||
        config.bucket.contains('/') ||
        config.accessKeyId.isEmpty ||
        config.secretAccessKey.isEmpty ||
        config.region.isEmpty) {
      throw const FormatException(
        'Bucket, region and S3 credentials are required',
      );
    }
  }
  final http.Client client;
  final S3Config config;
  final DateTime Function() clock;
  final Uri endpoint;
  String get _prefix {
    final value = normalizeRemotePath(config.keyPrefix);
    return value.isEmpty ? '' : '$value/';
  }

  String _key(String path) => '$_prefix${normalizeRemotePath(path)}';
  Uri _uri(String path, [Map<String, String> query = const {}]) {
    return Uri(
      scheme: endpoint.scheme,
      host: endpoint.host,
      port: endpoint.hasPort ? endpoint.port : null,
      pathSegments: [
        ...endpoint.pathSegments.where((s) => s.isNotEmpty),
        config.bucket,
        ...normalizeRemotePath(path).split('/').where((s) => s.isNotEmpty),
      ],
      query: query.isEmpty
          ? null
          : query.entries
                .map((e) => '${_encode(e.key)}=${_encode(e.value)}')
                .join('&'),
    );
  }

  static String _encode(String input) => Uri.encodeComponent(input)
      .replaceAll('!', '%21')
      .replaceAll("'", '%27')
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll('*', '%2A');

  // Exposed for deterministic signing fixtures; signs the exact URI sent.
  Map<String, String> signedHeaders(
    String method,
    Uri uri,
    List<int> body, {
    DateTime? now,
  }) {
    final utc = (now ?? clock()).toUtc();
    final date =
        '${utc.year.toString().padLeft(4, '0')}${utc.month.toString().padLeft(2, '0')}${utc.day.toString().padLeft(2, '0')}';
    final stamp =
        '${date}T${utc.hour.toString().padLeft(2, '0')}${utc.minute.toString().padLeft(2, '0')}${utc.second.toString().padLeft(2, '0')}Z';
    final payload = config.signPayload
        ? sha256.convert(body).toString()
        : 'UNSIGNED-PAYLOAD';
    final host = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    final pairs = <String>[];
    uri.queryParametersAll.forEach((key, values) {
      for (final value in values) {
        pairs.add('${_encode(key)}=${_encode(value)}');
      }
    });
    pairs.sort();
    const headers = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalPath = '/${uri.pathSegments.map(_encode).join('/')}';
    final canonical =
        '$method\n$canonicalPath\n${pairs.join('&')}\nhost:$host\nx-amz-content-sha256:$payload\nx-amz-date:$stamp\n\n$headers\n$payload';
    final scope = '$date/${config.region}/s3/aws4_request';
    final toSign =
        'AWS4-HMAC-SHA256\n$stamp\n$scope\n${sha256.convert(utf8.encode(canonical))}';
    List<int> hmac(List<int> key, String value) =>
        Hmac(sha256, key).convert(utf8.encode(value)).bytes;
    final dateKey = hmac(utf8.encode('AWS4${config.secretAccessKey}'), date);
    final regionKey = hmac(dateKey, config.region);
    final serviceKey = hmac(regionKey, 's3');
    final signingKey = hmac(serviceKey, 'aws4_request');
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(toSign)).toString();
    return {
      'Host': host,
      'x-amz-date': stamp,
      'x-amz-content-sha256': payload,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/$scope, SignedHeaders=$headers, Signature=$signature',
    };
  }

  Future<http.Response> _request(
    String method,
    String key, {
    Map<String, String> query = const {},
    List<int> bytes = const [],
  }) async {
    final uri = _uri(key, query);
    final request = http.Request(method, uri)
      ..headers.addAll(signedHeaders(method, uri, bytes))
      ..bodyBytes = bytes;
    final response = await http.Response.fromStream(
      await client.send(request),
    ).timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteStoreException(
        'S3 request failed',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final normalized = normalizeRemotePath(path);
    final prefix = _key(normalized.isEmpty ? '' : '$normalized/');
    final objectPrefix = prefix.isEmpty || prefix.endsWith('/')
        ? prefix
        : '$prefix/';
    final entries = <RemoteEntry>[];
    String? token;
    do {
      final response = await _request(
        'GET',
        '',
        query: {
          'list-type': '2',
          'prefix': objectPrefix,
          'delimiter': '/',
          'continuation-token': ?token,
        },
      );
      final document = XmlDocument.parse(response.body);
      String text(XmlElement element, String name) =>
          element.childElements
              .where((e) => e.name.local == name)
              .map((e) => e.innerText)
              .firstOrNull ??
          '';
      for (final item in document.rootElement.childElements) {
        if (item.name.local == 'CommonPrefixes') {
          final key = text(item, 'Prefix');
          if (key.startsWith(_prefix)) {
            entries.add(
              RemoteEntry(
                path: normalizeRemotePath(key.substring(_prefix.length)),
                isDirectory: true,
              ),
            );
          }
        } else if (item.name.local == 'Contents') {
          final key = text(item, 'Key');
          if (key == objectPrefix || !key.startsWith(_prefix)) continue;
          entries.add(
            RemoteEntry(
              path: normalizeRemotePath(key.substring(_prefix.length)),
              isDirectory: false,
              size: int.tryParse(text(item, 'Size')) ?? 0,
              modifiedAt: DateTime.tryParse(text(item, 'LastModified')),
            ),
          );
        }
      }
      final truncated = text(document.rootElement, 'IsTruncated') == 'true';
      token = truncated
          ? text(document.rootElement, 'NextContinuationToken')
          : null;
      if (truncated && (token == null || token.isEmpty)) {
        throw const FormatException('S3 pagination token missing');
      }
    } while (token != null);
    return entries;
  }

  @override
  Future<Uint8List> read(String path) async =>
      (await _request('GET', _key(path))).bodyBytes;
  @override
  Future<void> write(String path, List<int> bytes) async {
    await _request('PUT', _key(path), bytes: bytes);
  }

  @override
  Future<void> delete(String path) async {
    await _request('DELETE', _key(path));
  }

  @override
  Future<void> testConnection() async {
    await list('');
  }
}
