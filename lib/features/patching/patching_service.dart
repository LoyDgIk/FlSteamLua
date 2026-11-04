// Dart adaptation of Fluent-Steam-Lua patch installation behavior.
// Original: Copyright (c) 2024 SteamLuaManager, zlib; modified for FlSteamLua.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';

class PatchBackup {
  const PatchBackup({
    required this.id,
    required this.directory,
    required this.gameDirectory,
    required this.createdAt,
    required this.files,
    this.restored = false,
  });
  final String id;
  final String directory;
  final String gameDirectory;
  final DateTime createdAt;
  final List<String> files;
  final bool restored;
}

typedef PatchFileWriter =
    Future<void> Function(File destination, List<int> bytes);

class PatchingService {
  PatchingService({
    required this.paths,
    required this.settings,
    PatchFileWriter? fileWriter,
  }) : _write = fileWriter ?? _writeFile;
  final AppPaths paths;
  final SettingsStore settings;
  final PatchFileWriter _write;
  final Set<String> _activeDirectories = {};

  static Future<void> _writeFile(File destination, List<int> bytes) async {
    await destination.parent.create(recursive: true);
    final temporary = File(
      '${destination.path}.flsteamlua-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<PatchBackup> installFiles(
    String gameDirectory,
    Map<String, Uint8List> files, {
    TaskContext? context,
  }) async {
    final root = p.normalize(p.absolute(gameDirectory));
    if (!await Directory(root).exists()) {
      throw FileSystemException('Game directory does not exist', root);
    }
    if (!_activeDirectories.add(root.toLowerCase())) {
      throw StateError('Another patch operation is running for this game');
    }
    String? backupRoot;
    final entries = <Map<String, Object?>>[];
    try {
      if (files.isEmpty) throw const FormatException('Patch contains no files');
      for (final relative in files.keys) {
        validateArchivePath(relative);
        await _rejectLinks(root, relative);
      }
      final id = '${DateTime.now().toUtc().microsecondsSinceEpoch}';
      backupRoot = p.join(_backupBase(root), id);
      await Directory(p.join(backupRoot, 'files')).create(recursive: true);
      final created = DateTime.now().toUtc();
      final manifest = <String, Object?>{
        'version': 1,
        'id': id,
        'gameDirectory': root,
        'createdAt': created.toIso8601String(),
        'state': 'installing',
        'entries': entries,
      };
      for (final item in files.entries) {
        context?.checkCancelled();
        final relative = validateArchivePath(item.key);
        final destination = File(p.join(root, relative));
        final existed = await destination.exists();
        final previous = existed ? await destination.readAsBytes() : null;
        if (previous != null) {
          final saved = File(p.join(backupRoot, 'files', relative));
          await saved.parent.create(recursive: true);
          await saved.writeAsBytes(previous, flush: true);
        }
        entries.add({
          'path': relative,
          'existed': existed,
          'installedSha256': sha256.convert(item.value).toString(),
        });
        // Persist the undo record before replacing the corresponding game file.
        await _saveManifest(backupRoot, manifest);
        await _write(destination, item.value);
        context?.report(
          'Installed ${entries.length}/${files.length}: $relative',
          entries.length / files.length,
        );
      }
      manifest['state'] = 'installed';
      await _saveManifest(backupRoot, manifest);
      return PatchBackup(
        id: id,
        directory: backupRoot,
        gameDirectory: root,
        createdAt: created,
        files: files.keys.toList(),
      );
    } catch (error, stack) {
      if (backupRoot != null) {
        try {
          await _undo(root, backupRoot, entries);
          final file = File(p.join(backupRoot, 'manifest.json'));
          if (await file.exists()) {
            final manifest =
                jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            manifest['state'] = 'rolledBack';
            await _saveManifest(backupRoot, manifest);
          }
        } catch (rollbackError) {
          throw FileSystemException(
            'Patch failed ($error); rollback failed ($rollbackError). Backup: $backupRoot',
          );
        }
      }
      Error.throwWithStackTrace(error, stack);
    } finally {
      _activeDirectories.remove(root.toLowerCase());
    }
  }

  String _backupBase(String root) => paths.file(
    p.join(
      'backups',
      'patches',
      sha256
          .convert(utf8.encode(root.toLowerCase()))
          .toString()
          .substring(0, 24),
    ),
  );

  static Future<void> _undo(
    String root,
    String backupRoot,
    List<Map<String, Object?>> entries,
  ) async {
    for (final entry in entries.reversed) {
      final relative = validateArchivePath(entry['path'] as String);
      await _rejectLinks(root, relative);
      final destination = File(p.join(root, relative));
      if (entry['existed'] == true) {
        final original = File(p.join(backupRoot, 'files', relative));
        if (!await original.exists()) {
          throw FileSystemException(
            'Original backup file is missing',
            original.path,
          );
        }
        await destination.parent.create(recursive: true);
        await original.copy(destination.path);
      } else if (await destination.exists()) {
        await destination.delete();
      }
    }
  }

  static Future<void> _saveManifest(
    String directory,
    Map<String, Object?> manifest,
  ) async {
    final temporary = File(p.join(directory, 'manifest.json.tmp'));
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
    await temporary.rename(p.join(directory, 'manifest.json'));
  }
}

String validateArchivePath(String raw) {
  final name = raw.replaceAll('\\', '/');
  if (name.isEmpty ||
      name.startsWith('/') ||
      name.contains(':') ||
      name.contains('\u0000') ||
      name.split('/').any((part) => part == '..') ||
      p.windows.isAbsolute(name)) {
    throw FormatException('Unsafe archive path: $raw');
  }
  for (final segment
      in name.split('/').where((part) => part.isNotEmpty && part != '.')) {
    if (RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(segment) ||
        segment.endsWith('.') ||
        segment.endsWith(' ') ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
          caseSensitive: false,
        ).hasMatch(segment)) {
      throw FormatException('Unsupported Windows archive path: $raw');
    }
  }
  final normalized = p.normalize(name);
  if (normalized == '.' || p.split(normalized).first == '..') {
    throw FormatException('Invalid archive path: $raw');
  }
  return normalized;
}

Future<void> _rejectLinks(String root, String relative) async {
  var current = root;
  if (await FileSystemEntity.type(root, followLinks: false) ==
      FileSystemEntityType.link) {
    throw FileSystemException(
      'Game directory must not be a symbolic link',
      root,
    );
  }
  for (final segment in p.split(relative)) {
    current = p.join(current, segment);
    if (await FileSystemEntity.type(current, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FileSystemException(
        'Patch destination contains a symbolic link',
        current,
      );
    }
  }
}

Future<Map<String, Uint8List>> readArchiveFiles(String archivePath) async {
  final file = File(archivePath);
  if (!await file.exists()) {
    throw FileSystemException('Archive does not exist', archivePath);
  }
  if (await file.length() > 1024 * 1024 * 1024) {
    throw const FormatException('Archive exceeds 1 GiB limit');
  }
  final extension = p.extension(archivePath).toLowerCase();
  if (extension == '.7z' || extension == '.rar') {
    return _readWithSystemTar(archivePath);
  }
  final bytes = await file.readAsBytes();
  return Isolate.run(() => _decodeArchive(archivePath, bytes));
}

Map<String, Uint8List> _decodeArchive(String path, Uint8List bytes) {
  final lower = path.toLowerCase();
  final Archive archive;
  if (lower.endsWith('.zip')) {
    archive = ZipDecoder().decodeBytes(bytes, verify: true);
  } else if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
    archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  } else if (lower.endsWith('.tar')) {
    archive = TarDecoder().decodeBytes(bytes);
  } else {
    throw const FormatException(
      'Supported patch archives: zip, 7z, rar, tar, tar.gz',
    );
  }
  final files = <String, Uint8List>{};
  final names = <String>{};
  var total = 0;
  for (final entry in archive) {
    if (entry.isSymbolicLink) {
      throw const FormatException('Archive links are not supported');
    }
    if (!entry.isFile) continue;
    final name = validateArchivePath(entry.name);
    if (!names.add(name.toLowerCase())) {
      throw FormatException('Duplicate archive path: $name');
    }
    total += entry.size;
    if (total > 2 * 1024 * 1024 * 1024 || files.length >= 20000) {
      throw const FormatException('Archive extraction limit exceeded');
    }
    files[name] = entry.content;
  }
  return _stripSingleRoot(files);
}

Map<String, Uint8List> _stripSingleRoot(Map<String, Uint8List> files) {
  var result = files;
  while (result.isNotEmpty &&
      result.keys.every((name) => p.split(name).length > 1)) {
    final first = p.split(result.keys.first).first;
    if (!result.keys.every((name) => p.split(name).first == first)) break;
    result = {
      for (final entry in result.entries)
        p.joinAll(p.split(entry.key).skip(1)): entry.value,
    };
  }
  return result;
}

Future<Map<String, Uint8List>> _readWithSystemTar(String archivePath) async {
  final executable = Platform.isWindows
      ? p.join(
          Platform.environment['SystemRoot'] ?? r'C:\Windows',
          'System32',
          'tar.exe',
        )
      : 'bsdtar';
  final listing = await _runTar(executable, [
    '-tf',
    p.absolute(archivePath),
  ], const Duration(seconds: 30));
  if (listing.$1 != 0) {
    throw FormatException(
      'System libarchive could not read archive: ${listing.$3}',
    );
  }
  final names = const LineSplitter()
      .convert(listing.$2)
      .where((line) => line.isNotEmpty)
      .toList();
  if (names.length > 20000) {
    throw const FormatException('Archive contains too many entries');
  }
  final normalizedNames = <String>{};
  for (final name in names) {
    final normalized = validateArchivePath(name);
    if (!name.endsWith('/') && !normalizedNames.add(normalized.toLowerCase())) {
      throw FormatException('Duplicate archive path: $name');
    }
  }
  final details = await _runTar(executable, [
    '-tvf',
    p.absolute(archivePath),
  ], const Duration(seconds: 30));
  if (details.$1 != 0 ||
      const LineSplitter()
          .convert(details.$2)
          .any(
            (line) =>
                line.isNotEmpty &&
                !line.startsWith('-') &&
                !line.startsWith('d'),
          )) {
    throw const FormatException(
      'Archive contains unsupported symbolic links or special files',
    );
  }
  var declaredBytes = 0;
  for (final line in const LineSplitter().convert(details.$2)) {
    if (!line.startsWith('-')) continue;
    final metadata = RegExp(
      r'^\S+\s+\d+\s+\S+\s+\S+\s+(\d+)\s',
    ).firstMatch(line);
    if (metadata == null) {
      throw const FormatException('Cannot determine archive entry sizes');
    }
    declaredBytes += int.parse(metadata[1]!);
    if (declaredBytes > 2 * 1024 * 1024 * 1024) {
      throw const FormatException('Archive extraction limit exceeded');
    }
  }
  final temp = await Directory.systemTemp.createTemp('flsteamlua-patch-');
  try {
    final extraction = await _runTar(executable, [
      '-xf',
      p.absolute(archivePath),
      '-C',
      temp.path,
      '--no-same-owner',
    ], const Duration(minutes: 3));
    if (extraction.$1 != 0) {
      throw FormatException('Archive extraction failed: ${extraction.$3}');
    }
    final result = <String, Uint8List>{};
    var total = 0;
    await for (final entity in temp.list(recursive: true, followLinks: false)) {
      if (entity is Link) throw const FormatException('Archive contains links');
      if (entity is! File) continue;
      total += await entity.length();
      if (total > 2 * 1024 * 1024 * 1024 || result.length >= 20000) {
        throw const FormatException('Archive extraction limit exceeded');
      }
      result[validateArchivePath(p.relative(entity.path, from: temp.path))] =
          await entity.readAsBytes();
    }
    return _stripSingleRoot(result);
  } finally {
    await temp.delete(recursive: true);
  }
}

Future<(int, String, String)> _runTar(
  String executable,
  List<String> arguments,
  Duration timeout,
) async {
  final process = await Process.start(executable, arguments);
  final output = process.stdout.transform(systemEncoding.decoder).join();
  final error = process.stderr.transform(systemEncoding.decoder).join();
  try {
    final exit = await process.exitCode.timeout(timeout);
    return (exit, await output, await error);
  } catch (_) {
    process.kill();
    await process.exitCode;
    await output;
    await error;
    rethrow;
  }
}
