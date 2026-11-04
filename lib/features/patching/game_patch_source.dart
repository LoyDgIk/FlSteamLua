import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/task_center.dart';
import 'patching_service.dart';

enum GamePatchKind { vm, v38, fix, crack, vbs }

class GamePatchOption {
  const GamePatchOption({required this.kind, required this.url, this.buildId});

  final GamePatchKind kind;
  final Uri url;
  final String? buildId;

  String get suffix => switch (kind) {
    GamePatchKind.vm => buildId ?? 'vm',
    GamePatchKind.v38 => 'V38',
    GamePatchKind.fix => 'fix',
    GamePatchKind.crack => 'crack',
    GamePatchKind.vbs => 'VBS',
  };
}

class GamePatchTable {
  const GamePatchTable({this.patches = const {}, this.vbs});

  final Map<int, List<GamePatchOption>> patches;
  final GamePatchOption? vbs;

  List<GamePatchOption> forApp(int appId) => [...?patches[appId], ?vbs];
}

class GamePatchDownloadResult {
  const GamePatchDownloadResult({
    required this.directory,
    required this.files,
    required this.bytes,
  });

  final String directory;
  final int files;
  final int bytes;
}

class GamePatchSourceService {
  GamePatchSourceService({required this.paths, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const defaultUrls = [
    'https://pan.qzyun.net/f/d/6oE4UD/VM.txt',
    'https://gitee.com/biaogeNB/SteamToolbox/raw/master/VM.txt',
  ];
  static const _maxDownloadBytes = 1024 * 1024 * 1024;

  final AppPaths paths;
  final http.Client _client;
  final bool _ownsClient;

  Future<List<GamePatchOption>> loadPatches(
    int appId, {
    TaskContext? context,
  }) async {
    Object? lastError;
    var sourceLoaded = false;
    for (final raw in defaultUrls) {
      context?.checkCancelled();
      try {
        context?.report('Loading patch source');
        final response = await _client
            .get(Uri.parse(raw), headers: const {'User-Agent': 'FlSteamLua'})
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          throw HttpException('Patch source HTTP ${response.statusCode}');
        }
        sourceLoaded = true;
        final table = parseVmText(response.body);
        final patches = table.forApp(appId);
        if (patches.isNotEmpty) return patches;
      } catch (error) {
        lastError = error;
      }
    }
    if (sourceLoaded) return const [];
    if (lastError != null) {
      throw FormatException('Patch source unavailable: $lastError');
    }
    return const [];
  }

  static GamePatchTable parseVmText(String text) {
    final patches = <int, List<GamePatchOption>>{};
    GamePatchOption? vbs;
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      var separator = line.indexOf('：');
      if (separator < 0) separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final urlText = line.substring(separator + 1).trim();
      final url = Uri.tryParse(urlText);
      if (url == null ||
          (url.scheme != 'https' && url.scheme != 'http') ||
          url.host.isEmpty) {
        continue;
      }
      if (key.toUpperCase() == 'VBS') {
        vbs = GamePatchOption(kind: GamePatchKind.vbs, url: url);
        continue;
      }
      final dash = key.indexOf('-');
      if (dash <= 0) continue;
      final appId = int.tryParse(key.substring(0, dash));
      if (appId == null || appId <= 0) continue;
      var suffix = key.substring(dash + 1).trim();
      if (suffix.startsWith('-')) suffix = suffix.substring(1);
      final option = _optionForSuffix(suffix, url);
      if (option == null) continue;
      (patches[appId] ??= []).add(option);
    }
    return GamePatchTable(patches: patches, vbs: vbs);
  }

  Future<GamePatchDownloadResult> downloadAndExtract(
    int appId,
    GamePatchOption option, {
    TaskContext? context,
  }) async {
    final extension = _archiveExtension(option.url);
    final archive = File(
      paths.file(
        p.join(
          'cache',
          'patches',
          '$appId-${_safeSuffix(option.suffix)}.$extension',
        ),
      ),
    );
    final target = paths.directory(
      p.join('downloads', 'patches', '$appId-${_safeSuffix(option.suffix)}'),
    );
    final staging = Directory(
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await archive.parent.create(recursive: true);
    try {
      context?.checkCancelled();
      final request = http.Request('GET', option.url)
        ..headers['User-Agent'] = 'FlSteamLua';
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException(
          'Patch download returned HTTP ${response.statusCode}',
        );
      }
      final declared = response.contentLength ?? 0;
      if (declared > _maxDownloadBytes) {
        throw const FormatException('Patch archive exceeds 1 GiB');
      }
      final partial = File('${archive.path}.part');
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          context?.checkCancelled();
          received += chunk.length;
          if (received > _maxDownloadBytes) {
            throw const FormatException('Patch archive exceeds 1 GiB');
          }
          sink.add(chunk);
          context?.report(
            'Downloading patch',
            declared == 0 ? null : received / declared,
          );
        }
      } finally {
        await sink.close();
      }
      if (declared > 0 && received != declared) {
        throw const FormatException('Patch download size mismatch');
      }
      if (await archive.exists()) await archive.delete();
      await partial.rename(archive.path);
      context?.checkCancelled();
      final files = await readArchiveFiles(archive.path);
      if (files.isEmpty) {
        throw const FormatException('Patch archive contains no files');
      }
      await staging.create(recursive: true);
      var totalBytes = 0;
      for (final entry in files.entries) {
        context?.checkCancelled();
        final relative = validateArchivePath(entry.key);
        final destination = File(p.join(staging.path, relative));
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(entry.value, flush: true);
        totalBytes += entry.value.length;
      }
      if (await target.exists()) await target.delete(recursive: true);
      await staging.rename(target.path);
      return GamePatchDownloadResult(
        directory: target.path,
        files: files.length,
        bytes: totalBytes,
      );
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await archive.exists()) await archive.delete();
      final partial = File('${archive.path}.part');
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> openDirectory(String path) async {
    if (!await Directory(path).exists()) {
      throw FileSystemException('Directory does not exist', path);
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Opening extracted patches requires Windows');
    }
    await Process.start('explorer.exe', [
      path,
    ], mode: ProcessStartMode.detached);
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  static GamePatchOption? _optionForSuffix(String suffix, Uri url) {
    final normalized = suffix.toLowerCase();
    if (normalized.startsWith('v38')) {
      return GamePatchOption(kind: GamePatchKind.v38, url: url);
    }
    if (normalized.startsWith('fix')) {
      return GamePatchOption(kind: GamePatchKind.fix, url: url);
    }
    if (normalized.startsWith('crack')) {
      return GamePatchOption(kind: GamePatchKind.crack, url: url);
    }
    if (RegExp(r'^\d+$').hasMatch(suffix)) {
      return GamePatchOption(kind: GamePatchKind.vm, url: url, buildId: suffix);
    }
    return null;
  }

  static String _archiveExtension(Uri url) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.tar.gz')) return 'tar.gz';
    for (final extension in ['.zip', '.7z', '.rar', '.tar']) {
      if (path.endsWith(extension)) return extension.substring(1);
    }
    return 'zip';
  }

  static String _safeSuffix(String suffix) =>
      suffix.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
