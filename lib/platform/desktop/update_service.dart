import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/task_center.dart';

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
    this.sha256,
  });
  final String name;
  final Uri url;
  final int size;
  final String? sha256;
}

class ApplicationRelease {
  const ApplicationRelease({
    required this.version,
    required this.url,
    required this.notes,
    required this.assets,
    this.publishedAt,
  });
  final String version;
  final Uri url;
  final String notes;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  ReleaseAsset? get windowsAsset {
    for (final asset in assets) {
      final name = asset.name.toLowerCase();
      if (name.endsWith('.exe') &&
          (name.contains('x64') || name.contains('windows')) &&
          name.contains('setup')) {
        return asset;
      }
    }
    for (final asset in assets) {
      final name = asset.name.toLowerCase();
      if (name.endsWith('.zip') &&
          (name.contains('x64') || name.contains('windows')) &&
          !name.contains('source')) {
        return asset;
      }
    }
    return null;
  }

  ReleaseAsset? checksumAssetFor(ReleaseAsset asset) =>
      assets.where((value) => value.name == '${asset.name}.sha256').firstOrNull;
}

class UpdateService {
  UpdateService({
    required this.repository,
    http.Client? client,
    bool closeClient = false,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null || closeClient;

  final String repository;
  final http.Client _client;
  final bool _ownsClient;

  bool get isConfigured =>
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository.trim());

  /// An empty repository is intentionally unconfigured, never the WPF upstream.
  Future<ApplicationRelease?> checkLatest(String currentVersion) async {
    if (!isConfigured) {
      throw StateError('Configure the FlSteamLua release repository first.');
    }
    final response = await _client
        .get(
          Uri.https(
            'api.github.com',
            '/repos/${repository.trim()}/releases/latest',
          ),
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'FlSteamLua',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw HttpException('Release check failed: HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['tag_name'] is! String ||
        decoded['html_url'] is! String ||
        decoded['assets'] is! List) {
      throw const FormatException('Invalid GitHub release response');
    }
    final version = decoded['tag_name'] as String;
    if (compareVersions(version, currentVersion) <= 0) return null;
    final assets = <ReleaseAsset>[];
    for (final value in decoded['assets'] as List) {
      if (value is! Map<String, dynamic> ||
          value['name'] is! String ||
          value['browser_download_url'] is! String ||
          value['size'] is! int) {
        throw const FormatException('Invalid GitHub release asset');
      }
      final url = Uri.parse(value['browser_download_url'] as String);
      if (url.scheme != 'https' || url.host != 'github.com') {
        throw const FormatException('Unexpected release download origin');
      }
      final digest = value['digest'];
      final sha256 = digest is String && digest.startsWith('sha256:')
          ? digest.substring('sha256:'.length).toLowerCase()
          : null;
      assets.add(
        ReleaseAsset(
          name: value['name'] as String,
          url: url,
          size: value['size'] as int,
          sha256: sha256 != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)
              ? sha256
              : null,
        ),
      );
    }
    return ApplicationRelease(
      version: version,
      url: Uri.parse(decoded['html_url'] as String),
      notes: decoded['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(decoded['published_at'] as String? ?? ''),
      assets: List.unmodifiable(assets),
    );
  }

  Future<File> download(
    ReleaseAsset asset,
    Directory directory, {
    TaskContext? task,
  }) async {
    if (p.basename(asset.name) != asset.name || asset.name.contains('\\')) {
      throw const FormatException('Invalid release asset filename');
    }
    await directory.create(recursive: true);
    final destination = File(p.join(directory.path, asset.name));
    final partial = File('${destination.path}.part');
    final response = await _client.send(http.Request('GET', asset.url));
    if (response.statusCode != 200) {
      throw HttpException('Download failed: HTTP ${response.statusCode}');
    }
    final sink = partial.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        task?.checkCancelled();
        sink.add(chunk);
        received += chunk.length;
        task?.report(asset.name, asset.size > 0 ? received / asset.size : null);
      }
      await sink.close();
      if (asset.size > 0 && received != asset.size) {
        throw HttpException(
          'Incomplete download: $received/${asset.size} bytes',
        );
      }
      return await partial.rename(destination.path);
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<File> downloadRelease(
    ApplicationRelease release,
    Directory directory, {
    TaskContext? task,
  }) async {
    final asset = release.windowsAsset;
    if (asset == null) {
      throw StateError('The release has no Windows x64 installer or ZIP');
    }
    var expected = asset.sha256;
    final checksumAsset = release.checksumAssetFor(asset);
    if (expected == null && checksumAsset != null) {
      final response = await _client
          .get(checksumAsset.url)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw HttpException(
          'Checksum download failed: HTTP ${response.statusCode}',
        );
      }
      expected = response.body
          .trim()
          .split(RegExp(r'\s+'))
          .firstOrNull
          ?.toLowerCase();
      if (expected == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(expected)) {
        throw const FormatException('Invalid release checksum');
      }
    }
    if (expected == null) {
      throw const FormatException('Release checksum is unavailable');
    }
    final file = await download(asset, directory, task: task);
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      await file.delete();
      throw const FormatException('Downloaded update SHA256 mismatch');
    }
    return file;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

int compareVersions(String left, String right) {
  ({List<int> core, List<String> pre}) parse(String value) {
    final normalized = value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first;
    final split = normalized.split('-');
    final core = split.first.split('.').map(int.tryParse).toList();
    if (core.isEmpty || core.any((part) => part == null)) {
      throw FormatException('Unsupported application version: $value');
    }
    return (
      core: core.cast<int>(),
      pre: split
          .skip(1)
          .join('-')
          .split('.')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  final a = parse(left);
  final b = parse(right);
  for (var i = 0; i < a.core.length || i < b.core.length; i++) {
    final order = (i < a.core.length ? a.core[i] : 0).compareTo(
      i < b.core.length ? b.core[i] : 0,
    );
    if (order != 0) return order;
  }
  if (a.pre.isEmpty || b.pre.isEmpty) {
    return a.pre.isEmpty == b.pre.isEmpty
        ? 0
        : a.pre.isEmpty
        ? 1
        : -1;
  }
  for (var i = 0; i < a.pre.length && i < b.pre.length; i++) {
    final ai = int.tryParse(a.pre[i]);
    final bi = int.tryParse(b.pre[i]);
    final order = ai != null && bi != null
        ? ai.compareTo(bi)
        : ai != null
        ? -1
        : bi != null
        ? 1
        : a.pre[i].compareTo(b.pre[i]);
    if (order != 0) return order;
  }
  return a.pre.length.compareTo(b.pre.length);
}
