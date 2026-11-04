import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/task_center.dart';
import '../library/library_service.dart';
import 'content_models.dart';

typedef ContentFileWriter = Future<void> Function(File file, List<int> bytes);

class ContentImportEntry {
  const ContentImportEntry({
    required this.path,
    required this.artifact,
    required this.exists,
    this.originalHash,
  });
  final String path;
  final ContentArtifact artifact;
  final bool exists;
  final String? originalHash;
}

class ContentImportPreview {
  const ContentImportPreview({required this.bundle, required this.entries});
  final ContentBundle bundle;
  final List<ContentImportEntry> entries;
  bool get hasConflicts => entries.any((entry) => entry.exists);
}

class ContentImportResult {
  const ContentImportResult({
    required this.written,
    required this.skipped,
    required this.backups,
    required this.wroteLua,
    this.cleanupWarnings = const [],
  });
  final List<String> written;
  final List<String> skipped;
  final Map<String, String> backups;
  final bool wroteLua;
  final List<String> cleanupWarnings;
  bool get succeeded => written.isNotEmpty;
}

class ContentImportException implements Exception {
  const ContentImportException(
    this.cause,
    this.rollbackErrors,
    this.backups, {
    this.cleanupErrors = const {},
  });
  final Object cause;
  final Map<String, String> rollbackErrors;
  final Map<String, String> backups;
  final Map<String, String> cleanupErrors;
  @override
  String toString() =>
      (rollbackErrors.isEmpty
          ? 'Content import failed; original files were restored: $cause'
          : 'Content import failed: $cause\nFiles requiring recovery: $rollbackErrors\nBackups: $backups') +
      (cleanupErrors.isEmpty
          ? ''
          : '\nTemporary files requiring cleanup: $cleanupErrors');
}

class ContentImportService {
  ContentImportService({required this.library, ContentFileWriter? fileWriter})
    : _write = fileWriter ?? _writeAtomic;
  final LibraryService library;
  final ContentFileWriter _write;
  bool _committing = false;

  Future<ContentImportPreview> preview(ContentBundle bundle) async {
    if (bundle.lua == null) {
      throw const FormatException('Lua is required to add a game');
    }
    final roots = await library.contentDirectories();
    final existingGame = library.games
        .where((game) => game.appId == bundle.appId && game.hasLua)
        .firstOrNull;
    final entries = <ContentImportEntry>[];
    for (final artifact in [bundle.lua!, ...bundle.manifestFiles]) {
      final directory = identical(artifact, bundle.lua)
          ? roots.lua
          : p.join(roots.steam, 'depotcache');
      final name = identical(artifact, bundle.lua)
          ? '${bundle.appId}.lua'
          : artifact.filename;
      if (name != p.basename(name) ||
          name.contains('\\') ||
          name.contains('/') ||
          name.contains(':')) {
        throw const FormatException('Content target must be a filename');
      }
      final file = File(
        p.normalize(
          p.absolute(
            identical(artifact, bundle.lua) && existingGame != null
                ? existingGame.luaPath!
                : p.join(directory, name),
          ),
        ),
      );
      await _checkTarget(file);
      final exists = await file.exists();
      entries.add(
        ContentImportEntry(
          path: file.path,
          artifact: artifact,
          exists: exists,
          originalHash: exists
              ? sha256.convert(await file.readAsBytes()).toString()
              : null,
        ),
      );
    }
    return ContentImportPreview(
      bundle: bundle,
      entries: List.unmodifiable(entries),
    );
  }

  Future<ContentImportResult> commit(
    ContentImportPreview preview, {
    bool overwrite = false,
    TaskContext? task,
  }) async {
    if (_committing) throw StateError('Another content import is committing');
    _committing = true;
    final staged = <String, File>{};
    final backups = <String, String>{};
    final attempted = <String>[];
    final cleanupErrors = <String, String>{};
    final cleanupWarnings = <String>[];
    var scanAttempted = false;
    final transaction = '${DateTime.now().microsecondsSinceEpoch}';
    try {
      task?.checkCancelled();
      if (preview.hasConflicts && !overwrite) {
        return ContentImportResult(
          written: const [],
          skipped: preview.entries.map((entry) => entry.path).toList(),
          backups: const {},
          wroteLua: false,
        );
      }
      for (final entry in preview.entries) {
        task?.checkCancelled();
        final file = File(entry.path);
        await _checkTarget(file);
        final exists = await file.exists();
        final hash = exists
            ? sha256.convert(await file.readAsBytes()).toString()
            : null;
        if (exists != entry.exists || hash != entry.originalHash) {
          throw FileSystemException(
            'Content target changed after preview; prepare again',
            file.path,
          );
        }
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.$transaction.content-stage');
        staged[entry.path] = temporary;
        await temporary.writeAsBytes(entry.artifact.bytes, flush: true);
        if (exists) {
          final backup = File(
            library.paths.file(
              p.join(
                'backups',
                'content-imports',
                transaction,
                '${backups.length}-${p.basename(file.path)}',
              ),
            ),
          );
          await backup.parent.create(recursive: true);
          await file.copy(backup.path);
          backups[file.path] = backup.path;
        }
      }
      task?.checkCancelled();
      // Cancellation after this point must wait for a complete commit or rollback.
      for (final entry in preview.entries) {
        attempted.add(entry.path);
        await _write(File(entry.path), await staged[entry.path]!.readAsBytes());
      }
      scanAttempted = true;
      await library.scan();
      return ContentImportResult(
        written: List.unmodifiable(attempted),
        skipped: const [],
        backups: Map.unmodifiable(backups),
        wroteLua: true,
        cleanupWarnings: cleanupWarnings,
      );
    } catch (error) {
      final rollbackErrors = <String, String>{};
      for (final path in attempted.reversed) {
        try {
          final backup = backups[path];
          if (backup == null) {
            final created = File(path);
            if (await created.exists()) await created.delete();
          } else {
            await _writeAtomic(File(path), await File(backup).readAsBytes());
          }
        } catch (rollbackError) {
          rollbackErrors[path] = '$rollbackError';
        }
      }
      if (scanAttempted) {
        try {
          await library.scan();
        } catch (scanError) {
          rollbackErrors['library scan'] = '$scanError';
        }
      }
      if (error is TaskCancelled && attempted.isEmpty) rethrow;
      throw ContentImportException(
        error,
        rollbackErrors,
        backups,
        cleanupErrors: cleanupErrors,
      );
    } finally {
      try {
        for (final file in staged.values) {
          try {
            if (await file.exists()) await file.delete();
          } catch (error) {
            cleanupErrors[file.path] = '$error';
            cleanupWarnings.add('${file.path}: $error');
            task?.report(
              'Temporary file requires cleanup: ${file.path}: $error',
            );
          }
        }
      } finally {
        _committing = false;
      }
    }
  }

  static Future<void> _checkTarget(File file) async {
    var path = file.path;
    while (true) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw FileSystemException(
          'Content target contains a symbolic link',
          path,
        );
      }
      if (path == file.path &&
          type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw FileSystemException('Content target is not a file', path);
      }
      final parent = p.dirname(path);
      if (parent == path) break;
      path = parent;
    }
  }

  static Future<void> _writeAtomic(File file, List<int> bytes) async {
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.content-write',
    );
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
