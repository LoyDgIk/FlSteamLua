// Adapted from Fluent-Steam-Lua's content_log monitor and code/CDN fetcher.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/task_center.dart';

class ManifestRequest {
  const ManifestRequest(this.appId, this.depotId, this.manifestId);
  final int appId;
  final int depotId;
  final String manifestId;

  static ManifestRequest? parse(String line) {
    final match = RegExp(
      r'BYldRequestDepotManifest\(App:\s*(\d+),\s*Depot:\s*(\d+),\s*Manifest:\s*(\d+)',
    ).firstMatch(line);
    if (match == null) return null;
    final appId = int.tryParse(match[1]!);
    final depotId = int.tryParse(match[2]!);
    if (appId == null || depotId == null || appId <= 0 || depotId <= 0) {
      return null;
    }
    return ManifestRequest(appId, depotId, match[3]!);
  }
}

typedef ManifestDownloader =
    Future<void> Function(ManifestRequest request, TaskContext task);

class ManifestMonitor extends ChangeNotifier {
  ManifestMonitor({
    required this.tasks,
    required this.download,
    this.interval = const Duration(milliseconds: 500),
    this.pacing = const Duration(milliseconds: 800),
  });
  final TaskCenter tasks;
  final ManifestDownloader download;
  final Duration interval;
  final Duration pacing;
  final List<String> logs = [];
  final Set<String> _seen = {};
  final List<ManifestRequest> _queue = [];
  Timer? _timer;
  String? _path;
  int _offset = 0;
  String _partial = '';
  bool _polling = false;
  bool _working = false;
  bool _disposed = false;
  bool get isRunning => _timer != null;

  Future<void> start(String steamPath, {bool fromBeginning = false}) async {
    if (isRunning) return;
    final file = File(p.join(steamPath, 'logs', 'content_log.txt'));
    if (!await file.exists()) {
      throw FileSystemException('Steam content log not found', file.path);
    }
    _path = file.path;
    _offset = fromBeginning ? 0 : await file.length();
    _seen.clear();
    _partial = '';
    _log('Monitoring ${file.path}');
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
    notifyListeners();
  }

  Future<void> poll() async {
    if (_polling || _path == null || !isRunning) return;
    _polling = true;
    try {
      final file = File(_path!);
      final length = await file.length();
      if (length < _offset) {
        _offset = 0;
        _partial = '';
        _log('Steam rotated the content log');
      }
      if (length == _offset) return;
      final handle = await file.open();
      Uint8List bytes;
      try {
        await handle.setPosition(_offset);
        bytes = await handle.read(length - _offset);
        _offset += bytes.length;
      } finally {
        await handle.close();
      }
      final text = _partial + utf8.decode(bytes, allowMalformed: true);
      final lines = text.split('\n');
      _partial = lines.removeLast();
      for (final line in lines) {
        final request = ManifestRequest.parse(line);
        if (request == null) continue;
        final key = '${request.depotId}:${request.manifestId}';
        if (!_seen.add(key)) continue;
        if (_seen.length > 10000) _seen.clear();
        _queue.add(request);
        _log(
          'App ${request.appId}: depot ${request.depotId}, manifest ${request.manifestId}',
        );
      }
      unawaited(_drain());
    } catch (error) {
      _log(error.toString());
      stop();
    } finally {
      _polling = false;
    }
  }

  Future<void> _drain() async {
    if (_working) return;
    _working = true;
    try {
      while (_queue.isNotEmpty && isRunning) {
        final request = _queue.removeAt(0);
        try {
          await tasks.run(
            'Manifest ${request.depotId}',
            (task) => download(request, task),
            appId: request.appId,
          );
          _log('Saved ${request.depotId}_${request.manifestId}.manifest');
        } catch (error) {
          _log('Depot ${request.depotId}: $error');
        }
        if (_queue.isNotEmpty && isRunning) await Future<void>.delayed(pacing);
      }
    } finally {
      _working = false;
    }
  }

  void _log(String message) {
    if (_disposed) return;
    logs.add('${DateTime.now().toIso8601String()} $message');
    if (logs.length > 500) logs.removeAt(0);
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    super.dispose();
  }
}

class ManifestCdnDownloader {
  ManifestCdnDownloader({
    http.Client? client,
    this.sources,
    this.cdnHost = 'steampipe.akamaized.net',
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;
  final http.Client _client;
  final bool _ownsClient;
  final List<Uri Function(int, String)>? sources;
  final String cdnHost;

  List<Uri Function(int, String)> get _sources =>
      sources ??
      [
        (depot, gid) => Uri.https('20770407.xyz', '/manifest/$depot/$gid'),
        (depot, gid) =>
            Uri.https('steamapi.993499094.xyz', '/manifest/$depot/$gid'),
        (depot, gid) => Uri.https('manifest.manifestdex.com', '/$depot'),
        (depot, gid) => Uri.http('gmrc.wudrm.com', '/manifest/$depot'),
        (depot, gid) => Uri.https('manifest.steam.run', '/api/manifest/$depot'),
      ];

  Future<File> download(
    String steamPath,
    ManifestRequest request,
    TaskContext task,
  ) async {
    if (request.appId <= 0 ||
        request.depotId <= 0 ||
        !RegExp(r'^[1-9]\d*$').hasMatch(request.manifestId)) {
      throw const FormatException('Invalid manifest request');
    }
    final errors = <String>[];
    for (final source in _sources) {
      task.checkCancelled();
      final uri = source(request.depotId, request.manifestId);
      try {
        task.report('Requesting code from ${uri.host}');
        final codeResponse = await _client
            .get(
              uri,
              headers: {
                'User-Agent': uri.host.contains('manifestdex')
                    ? 'ManifestDeX/1.0'
                    : 'FlSteamLua/0.1',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (codeResponse.statusCode != 200) {
          throw HttpException('HTTP ${codeResponse.statusCode}');
        }
        var code = codeResponse.body.trim();
        if (code.startsWith('{')) {
          final decoded = jsonDecode(code) as Map<String, dynamic>;
          code = '${decoded['content'] ?? ''}';
        }
        if (!RegExp(r'^[1-9]\d*$').hasMatch(code)) {
          throw const FormatException('Invalid request code');
        }
        task.checkCancelled();
        final cdn = Uri.https(
          cdnHost,
          '/depot/${request.depotId}/manifest/${request.manifestId}/5/$code',
        );
        task.report('Downloading manifest from $cdnHost');
        final response = await _client
            .get(cdn)
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200) {
          throw HttpException('CDN HTTP ${response.statusCode}');
        }
        final bytes = unwrapManifest(response.bodyBytes);
        task.checkCancelled();
        final directory = Directory(p.join(steamPath, 'depotcache'));
        await directory.create(recursive: true);
        final output = File(
          p.join(
            directory.path,
            '${request.depotId}_${request.manifestId}.manifest',
          ),
        );
        final temporary = File('${output.path}.flsteamlua.tmp');
        await temporary.writeAsBytes(bytes, flush: true);
        await temporary.rename(output.path);
        task.report(output.path, 1);
        return output;
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        errors.add('${uri.host}: $error');
      }
    }
    throw HttpException(errors.join('\n'));
  }

  static List<int> unwrapManifest(List<int> input) {
    if (input.length > 128 * 1024 * 1024) {
      throw const FormatException('Manifest is too large');
    }
    var bytes = input;
    if (input.length >= 4 && input[0] == 0x50 && input[1] == 0x4b) {
      final archive = ZipDecoder().decodeBytes(input);
      final files = archive.files.where((file) => file.isFile).toList();
      final z = files.where((file) => file.name == 'z').firstOrNull;
      final entry = z ?? (files.length == 1 ? files.single : null);
      if (entry == null || entry.size > 128 * 1024 * 1024) {
        throw const FormatException('Invalid manifest archive');
      }
      bytes = entry.content;
    }
    const magic = [0xd0, 0x17, 0xf6, 0x71];
    if (bytes.length < 32 || !listEquals(bytes.take(4).toList(), magic)) {
      throw const FormatException('Invalid manifest magic');
    }
    return bytes;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
