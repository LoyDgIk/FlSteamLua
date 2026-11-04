import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/game_entry.dart';
import '../../core/task_center.dart';
import '../library/kv1.dart';
import '../steam_protocol/manifest/depot_manifest.dart';
import '../tools/tools_service.dart';

enum GameFileState { verified, missing, changed, unexpected, unverified }

class GameFileCheck {
  const GameFileCheck({
    required this.path,
    required this.state,
    this.depotId,
    this.expectedSize,
    this.actualSize,
    this.hashChecked = false,
  });

  final String path;
  final GameFileState state;
  final int? depotId;
  final int? expectedSize;
  final int? actualSize;
  final bool hashChecked;
}

class GameFileVerificationResult {
  const GameFileVerificationResult({
    required this.files,
    required this.warnings,
    required this.depotCount,
    required this.manifestCount,
  });

  final List<GameFileCheck> files;
  final List<String> warnings;
  final int depotCount;
  final int manifestCount;

  int get verifiedCount =>
      files.where((file) => file.state == GameFileState.verified).length;
  int get missingCount =>
      files.where((file) => file.state == GameFileState.missing).length;
  int get changedCount =>
      files.where((file) => file.state == GameFileState.changed).length;
  int get unexpectedCount =>
      files.where((file) => file.state == GameFileState.unexpected).length;
  int get unverifiedCount =>
      files.where((file) => file.state == GameFileState.unverified).length;
  int get issueCount => missingCount + changedCount;
}

class GameFileVerificationService {
  GameFileVerificationService({required this.tools});

  final ToolsService tools;

  Future<GameFileVerificationResult> verify(
    GameEntry game, {
    TaskContext? context,
  }) async {
    final gameDirectory = game.installPath;
    final library = game.libraryPath;
    if (gameDirectory == null || !await Directory(gameDirectory).exists()) {
      throw const FileSystemException('Game directory is not installed');
    }
    if (library == null) {
      throw const FileSystemException('Steam library path is unavailable');
    }
    final installed = await _installedManifests(game);
    if (installed.isEmpty) {
      throw const FormatException(
        'No installed depot manifests were found in appmanifest',
      );
    }
    final keys = await _depotKeys(game);
    final expected = <String, _ExpectedFile>{};
    final warnings = <String>[];
    var manifestCount = 0;
    final depotCaches = await _depotCacheDirectories(game);
    for (final entry in installed.entries) {
      context?.checkCancelled();
      final depotId = entry.key;
      final manifestId = entry.value;
      final manifestFile = await _findManifest(
        depotCaches,
        depotId,
        manifestId,
      );
      if (manifestFile == null) {
        warnings.add('Missing manifest: ${depotId}_$manifestId.manifest');
        continue;
      }
      final DepotManifest manifest;
      try {
        manifest = DepotManifest.parse(
          await manifestFile.readAsBytes(),
          depotKey: keys[depotId],
        );
      } catch (error) {
        warnings.add('${p.basename(manifestFile.path)}: $error');
        continue;
      }
      if (manifest.depotId != depotId ||
          manifest.manifestGid != BigInt.parse(manifestId)) {
        warnings.add(
          '${p.basename(manifestFile.path)} does not match the installed depot',
        );
        continue;
      }
      if (manifest.filenamesEncrypted) {
        warnings.add(
          '${p.basename(manifestFile.path)}: depot key is unavailable',
        );
        continue;
      }
      manifestCount++;
      for (final file in manifest.files) {
        context?.checkCancelled();
        final relative = _normalizeRelativePath(file.fileName);
        if (relative.isEmpty) continue;
        final key = relative.toLowerCase();
        final previous = expected[key];
        final candidate = _ExpectedFile(
          path: relative,
          depotId: depotId,
          size: file.size,
          sha: file.sha,
        );
        if (previous != null &&
            (previous.size != candidate.size ||
                !_sameBytes(previous.sha, candidate.sha))) {
          warnings.add(
            'Files overlap between depot $depotId and ${previous.depotId}: $relative',
          );
          continue;
        }
        expected[key] = candidate;
      }
      context?.report(
        'Read manifest $manifestCount/${installed.length}',
        manifestCount / installed.length,
      );
    }
    if (expected.isEmpty && warnings.isEmpty) {
      warnings.add('No files were found in installed manifests.');
    } else if (manifestCount < installed.length) {
      warnings.add(
        manifestCount == 0
            ? 'Manifest comparison is unavailable; showing a file inventory only.'
            : 'Some installed depots could not be checked; unmatched files are listed as unverified.',
      );
    }

    final checks = <GameFileCheck>[];
    final entries = expected.values.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (var index = 0; index < entries.length; index++) {
      context?.checkCancelled();
      final item = entries[index];
      final actualFile = File(p.join(gameDirectory, item.path));
      if (!await actualFile.exists()) {
        checks.add(
          GameFileCheck(
            path: item.path,
            state: GameFileState.missing,
            depotId: item.depotId,
            expectedSize: item.size,
          ),
        );
      } else {
        final actualSize = await actualFile.length();
        var matches = actualSize == item.size;
        var hashed = false;
        if (matches && item.sha.isNotEmpty) {
          final digest = await sha1.bind(actualFile.openRead()).first;
          matches = digest.toString() == _hex(item.sha);
          hashed = true;
        }
        checks.add(
          GameFileCheck(
            path: item.path,
            state: matches ? GameFileState.verified : GameFileState.changed,
            depotId: item.depotId,
            expectedSize: item.size,
            actualSize: actualSize,
            hashChecked: hashed,
          ),
        );
      }
      if (index % 40 == 0 || index == entries.length - 1) {
        context?.report(
          'Verified ${index + 1}/${entries.length}',
          (index + 1) / entries.length,
        );
      }
    }

    final unexpected = <GameFileCheck>[];
    final unverified = <GameFileCheck>[];
    await for (final entity in Directory(
      gameDirectory,
    ).list(recursive: true, followLinks: false)) {
      context?.checkCancelled();
      if (entity is! File) continue;
      final relative = _normalizeRelativePath(
        p.relative(entity.path, from: gameDirectory),
      );
      if (relative.isEmpty || expected.containsKey(relative.toLowerCase())) {
        continue;
      }
      final check = GameFileCheck(
        path: relative,
        state: manifestCount < installed.length
            ? GameFileState.unverified
            : GameFileState.unexpected,
        actualSize: await entity.length(),
      );
      if (check.state == GameFileState.unexpected) {
        unexpected.add(check);
      } else {
        unverified.add(check);
      }
    }
    unexpected.sort((a, b) => a.path.compareTo(b.path));
    unverified.sort((a, b) => a.path.compareTo(b.path));
    checks.addAll(unexpected);
    checks.addAll(unverified);
    return GameFileVerificationResult(
      files: checks,
      warnings: warnings,
      depotCount: installed.length,
      manifestCount: manifestCount,
    );
  }

  Future<Map<int, String>> _installedManifests(GameEntry game) async {
    try {
      return await tools.installedManifests(game);
    } catch (error) {
      throw FormatException('Could not read appmanifest: $error');
    }
  }

  Future<Map<int, Uint8List>> _depotKeys(GameEntry game) async {
    final result = <int, Uint8List>{};
    if (!game.hasLua) return result;
    try {
      for (final depot in await tools.depots(game)) {
        final raw = depot.key;
        if (raw == null || raw.isEmpty) continue;
        final bytes = _decodeKey(raw);
        if (bytes != null) result[depot.id] = bytes;
      }
    } catch (_) {
      // A missing or malformed Lua file only limits encrypted manifests.
    }
    return result;
  }

  Future<Set<String>> _depotCacheDirectories(GameEntry game) async {
    final roots = <String>{};
    if (game.libraryPath case final library?) {
      roots.add(p.normalize(p.absolute(library)));
    }
    final steam = tools.settings.steamPath.trim();
    if (steam.isNotEmpty) roots.add(p.normalize(p.absolute(steam)));
    if (steam.isNotEmpty) {
      final vdf = File(p.join(steam, 'steamapps', 'libraryfolders.vdf'));
      if (await vdf.exists()) {
        final parsed = Kv1.parse(await vdf.readAsString());
        final listing = parsed['libraryfolders'] as Map? ?? parsed;
        for (final value in listing.values) {
          final path = value is Map
              ? '${value['path'] ?? ''}'.trim()
              : '$value'.trim();
          if (path.isNotEmpty) roots.add(p.normalize(p.absolute(path)));
        }
      }
    }
    return {for (final root in roots) p.join(root, 'steamapps', 'depotcache')};
  }

  Future<File?> _findManifest(
    Set<String> depotCaches,
    int depotId,
    String manifestId,
  ) async {
    for (final directory in depotCaches) {
      final file = File(p.join(directory, '${depotId}_$manifestId.manifest'));
      if (await file.exists()) return file;
    }
    return null;
  }

  static Uint8List? _decodeKey(String value) {
    final clean = value.trim();
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(clean)) {
      return Uint8List.fromList([
        for (var index = 0; index < clean.length; index += 2)
          int.parse(clean.substring(index, index + 2), radix: 16),
      ]);
    }
    try {
      final bytes = base64Decode(clean);
      return bytes.length == 32 ? Uint8List.fromList(bytes) : null;
    } on FormatException {
      return null;
    }
  }

  static String _normalizeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    final parts = p.posix
        .normalize(normalized)
        .split('/')
        .where((part) => part.isNotEmpty && part != '.');
    final result = parts.join('/');
    return result == '..' || result.startsWith('../') ? '' : result;
  }

  static bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

class _ExpectedFile {
  const _ExpectedFile({
    required this.path,
    required this.depotId,
    required this.size,
    required this.sha,
  });

  final String path;
  final int depotId;
  final int size;
  final List<int> sha;
}
