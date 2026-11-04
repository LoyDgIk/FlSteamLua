import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/task_center.dart';
import 'patching_service.dart';

class EmulatorRelease {
  const EmulatorRelease({
    required this.version,
    required this.url,
    required this.filename,
    required this.size,
    this.sha256Digest,
  });
  final String version, filename;
  final Uri url;
  final int size;
  final String? sha256Digest;
}

class PeInspection {
  const PeInspection(this.is64Bit, this.entryPoint, this.sections);
  final bool is64Bit;
  final int entryPoint;
  final List<String> sections;
  bool get hasSteamStubSection => sections.contains('.bind');

  static PeInspection parse(Uint8List bytes) {
    if (bytes.length < 64 || bytes[0] != 0x4d || bytes[1] != 0x5a) {
      throw const FormatException('File is not a Windows PE executable');
    }
    final data = ByteData.sublistView(bytes);
    final pe = data.getUint32(0x3c, Endian.little);
    if (pe + 24 > bytes.length || data.getUint32(pe, Endian.little) != 0x4550) {
      throw const FormatException('Invalid PE signature');
    }
    final count = data.getUint16(pe + 6, Endian.little);
    final optionalSize = data.getUint16(pe + 20, Endian.little);
    final optional = pe + 24;
    if (optionalSize < 64 ||
        optional + optionalSize + count * 40 > bytes.length) {
      throw const FormatException('Truncated PE headers');
    }
    final magic = data.getUint16(optional, Endian.little);
    if (magic != 0x10b && magic != 0x20b) {
      throw const FormatException('Unsupported PE optional header');
    }
    final sections = <String>[];
    for (var i = 0; i < count; i++) {
      final offset = optional + optionalSize + i * 40;
      sections.add(
        ascii.decode(
          bytes
              .sublist(offset, offset + 8)
              .takeWhile((byte) => byte != 0)
              .toList(),
        ),
      );
      final rawSize = data.getUint32(offset + 16, Endian.little);
      final rawPointer = data.getUint32(offset + 20, Endian.little);
      if (rawPointer > bytes.length || rawSize > bytes.length - rawPointer) {
        throw const FormatException('PE section exceeds file size');
      }
    }
    return PeInspection(
      magic == 0x20b,
      data.getUint32(optional + 16, Endian.little),
      sections,
    );
  }
}

class EmulatorService {
  EmulatorService({
    required this.paths,
    required this.patching,
    http.Client? client,
  }) : client = client ?? http.Client(),
       _ownsClient = client == null;
  final AppPaths paths;
  final PatchingService patching;
  final http.Client client;
  final bool _ownsClient;
  String get cacheDirectory => paths.file(p.join('cache', 'goldberg'));

  Future<EmulatorRelease> latestRelease() async {
    final response = await client
        .get(
          Uri.parse('https://api.github.com/repos/Detanup01/gbe_fork/releases'),
          headers: {
            'User-Agent': 'FlSteamLua',
            'Accept': 'application/vnd.github+json',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException(
        'Goldberg release lookup returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Invalid GitHub releases response');
    }
    for (final release in decoded) {
      if (release is! Map ||
          release['draft'] == true ||
          release['assets'] is! List) {
        continue;
      }
      for (final asset in release['assets'] as List) {
        if (asset is! Map || asset['name'] is! String) continue;
        final name = asset['name'] as String;
        if (!name.toLowerCase().startsWith('emu-win-release') ||
            !name.endsWith('.7z')) {
          continue;
        }
        final url = Uri.tryParse(
          asset['browser_download_url'] as String? ?? '',
        );
        if (url == null || url.scheme != 'https') {
          throw const FormatException('Invalid emulator download URL');
        }
        final digest = asset['digest'] as String?;
        return EmulatorRelease(
          version: release['tag_name'] as String,
          url: url,
          filename: name,
          size: asset['size'] as int,
          sha256Digest: digest?.startsWith('sha256:') == true
              ? digest!.substring(7)
              : null,
        );
      }
    }
    throw StateError('No Windows release emulator package found');
  }

  Future<void> download(EmulatorRelease release, {TaskContext? context}) async {
    if (release.size > 512 * 1024 * 1024) {
      throw const FormatException('Emulator package exceeds 512 MiB');
    }
    final request = http.Request('GET', release.url)
      ..headers['User-Agent'] = 'FlSteamLua';
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException(
        'Emulator download returned HTTP ${response.statusCode}',
      );
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 60),
    )) {
      context?.checkCancelled();
      bytes.add(chunk);
      if (bytes.length > 512 * 1024 * 1024) {
        throw const FormatException('Emulator package exceeds 512 MiB');
      }
      context?.report(
        'Downloading Goldberg',
        release.size == 0 ? null : bytes.length / release.size,
      );
    }
    if (release.size != 0 && bytes.length != release.size) {
      throw const FormatException('Emulator download size mismatch');
    }
    final content = bytes.takeBytes();
    if (release.sha256Digest != null &&
        sha256.convert(content).toString() !=
            release.sha256Digest!.toLowerCase()) {
      throw const FormatException('Emulator SHA256 verification failed');
    }
    final archive = File(
      paths.file(
        p.join(
          'downloads',
          'goldberg-${DateTime.now().microsecondsSinceEpoch}.7z',
        ),
      ),
    );
    await archive.parent.create(recursive: true);
    await archive.writeAsBytes(content);
    try {
      final files = await readArchiveFiles(archive.path);
      final x86 = _locateDll(files, false);
      final x64 = _locateDll(files, true);
      await Directory(cacheDirectory).create(recursive: true);
      await File(
        p.join(cacheDirectory, 'steam_api.dll'),
      ).writeAsBytes(x86, flush: true);
      await File(
        p.join(cacheDirectory, 'steam_api64.dll'),
      ).writeAsBytes(x64, flush: true);
      await File(
        p.join(cacheDirectory, 'version.txt'),
      ).writeAsString(release.version, flush: true);
    } finally {
      await archive.delete();
    }
  }

  Future<String?> installedVersion() async {
    final file = File(p.join(cacheDirectory, 'version.txt'));
    return await file.exists() ? (await file.readAsString()).trim() : null;
  }

  Future<PatchBackup> deploy(
    String gameDirectory, {
    TaskContext? context,
  }) async {
    final root = Directory(gameDirectory);
    if (!await root.exists()) {
      throw FileSystemException('Game directory does not exist', gameDirectory);
    }
    final targets = <String, Uint8List>{};
    final cached = <String, Uint8List>{};
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      context?.checkCancelled();
      if (entity is! File) continue;
      final name = p.basename(entity.path).toLowerCase();
      if (name != 'steam_api.dll' && name != 'steam_api64.dll') continue;
      final inspection = PeInspection.parse(await entity.readAsBytes());
      if (inspection.is64Bit != (name == 'steam_api64.dll')) {
        throw FormatException(
          'Steam API architecture/name mismatch: ${entity.path}',
        );
      }
      cached[name] ??= await File(p.join(cacheDirectory, name)).readAsBytes();
      final replacement = PeInspection.parse(cached[name]!);
      if (replacement.is64Bit != inspection.is64Bit) {
        throw const FormatException('Cached emulator architecture mismatch');
      }
      targets[p.relative(entity.path, from: gameDirectory)] = cached[name]!;
    }
    if (targets.isEmpty) {
      throw StateError(
        'No steam_api.dll or steam_api64.dll found in game directory',
      );
    }
    return patching.installFiles(gameDirectory, targets, context: context);
  }

  Uint8List _locateDll(Map<String, Uint8List> files, bool x64) {
    final name = x64 ? 'steam_api64.dll' : 'steam_api.dll';
    final candidates =
        files.entries
            .where(
              (entry) =>
                  p.basename(entry.key).toLowerCase() == name &&
                  !entry.key.toLowerCase().contains('experimental') &&
                  !entry.key.toLowerCase().contains('debug'),
            )
            .toList()
          ..sort((a, b) => a.key.length.compareTo(b.key.length));
    for (final candidate in candidates) {
      if (PeInspection.parse(candidate.value).is64Bit == x64) {
        return candidate.value;
      }
    }
    throw FormatException('Emulator package is missing $name');
  }

  void close() {
    if (_ownsClient) client.close();
  }
}
