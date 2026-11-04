import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/task_center.dart';
import 'manifest_models.dart';

class ManifestHttpHost {
  ManifestHttpHost(this.client);
  final http.Client client;

  Future<Map<String, Object?>> request(
    Map<String, dynamic> payload, {
    TaskContext? task,
  }) async {
    task?.checkCancelled();
    final method = payload['method'];
    final url = payload['url'];
    if ((method != 'GET' && method != 'POST') || url is! String) {
      throw const ManifestSourceException(
        'script_error',
        'Invalid HTTP request from manifest script',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const ManifestSourceException(
        'invalid_response',
        'Manifest scripts require an HTTP or HTTPS URL',
      );
    }
    final options = payload['options'] is Map
        ? Map<String, dynamic>.from(payload['options'] as Map)
        : <String, dynamic>{};
    final seconds = ((options['timeout'] as num?)?.toInt() ?? 60).clamp(1, 300);
    final requestedMax =
        (options['maxBytes'] as num?)?.toInt() ?? 128 * 1024 * 1024;
    final maxBytes = requestedMax.clamp(1, 128 * 1024 * 1024);
    final responseType = options['responseType'] ?? 'text';
    if (!{'text', 'json', 'base64'}.contains(responseType)) {
      throw const ManifestSourceException(
        'script_error',
        'Unknown HTTP responseType',
      );
    }
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method as String,
      uri,
      abortTrigger: abort.future,
    );
    request.headers['User-Agent'] = 'FlSteamLua/0.1';
    if (options['headers'] case final Map headers) {
      for (final entry in headers.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const ManifestSourceException(
            'script_error',
            'HTTP headers must be strings',
          );
        }
        request.headers[entry.key as String] = entry.value as String;
      }
    }
    if (method == 'POST' && options['body'] != null) {
      final body = options['body'];
      request.body = body is String ? body : jsonEncode(body);
      request.headers['Content-Type'] =
          options['contentType'] as String? ??
          (body is String ? 'text/plain; charset=utf-8' : 'application/json');
    }

    Future<Map<String, Object?>> send() async {
      final response = await client.send(request);
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        task?.checkCancelled();
        if (bytes.length + chunk.length > maxBytes) {
          throw const ManifestSourceException(
            'invalid_response',
            'Manifest response exceeds the download limit',
          );
        }
        bytes.addAll(chunk);
      }
      task?.checkCancelled();
      final status = response.statusCode;
      final ok = status >= 200 && status < 300;
      if (!ok && options['allowNonSuccess'] != true) {
        throw ManifestSourceException(
          _httpErrorKind(status),
          'Manifest server returned HTTP $status',
          statusCode: status,
        );
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final result = <String, Object?>{
        'status': status,
        'ok': ok,
        'url': response.request?.url.toString() ?? uri.toString(),
        'headers': response.headers,
        'contentType': response.headers['content-type'] ?? '',
        'text': responseType == 'base64' ? '' : text,
      };
      if (responseType == 'base64') result['base64'] = base64Encode(bytes);
      if (responseType == 'json') {
        try {
          result['data'] = jsonDecode(text);
        } on FormatException {
          throw const ManifestSourceException(
            'invalid_response',
            'Manifest server returned invalid JSON',
          );
        }
      }
      return result;
    }

    final cancellation = task == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 80), (_) {
            if (task.isCancelled && !abort.isCompleted) abort.complete();
          });
    try {
      return await send().timeout(Duration(seconds: seconds));
    } on TimeoutException {
      if (!abort.isCompleted) abort.complete();
      throw const ManifestSourceException(
        'network',
        'Manifest request timed out',
      );
    } on http.RequestAbortedException {
      task?.checkCancelled();
      throw const ManifestSourceException(
        'network',
        'Manifest request aborted',
      );
    } on http.ClientException catch (error) {
      throw ManifestSourceException('network', error.message);
    } finally {
      cancellation?.cancel();
    }
  }

  static String _httpErrorKind(int status) => switch (status) {
    401 || 403 => 'invalid_key',
    404 => 'not_found',
    429 => 'quota',
    >= 500 => 'network',
    _ => 'unknown',
  };
}
