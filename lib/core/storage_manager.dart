import 'dart:io';

import 'package:path/path.dart' as p;

import 'task_center.dart';

class StorageUsage {
  const StorageUsage({required this.bytes, required this.files});

  final int bytes;
  final int files;
}

Future<StorageUsage> measureStorageDirectory(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) {
    return const StorageUsage(bytes: 0, files: 0);
  }
  var bytes = 0;
  var files = 0;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is Link) continue;
    if (entity is File) {
      files++;
      bytes += await entity.length();
    }
  }
  return StorageUsage(bytes: bytes, files: files);
}

Future<void> clearStorageDirectory(String path) async {
  final directory = Directory(path);
  if (await directory.exists()) await directory.delete(recursive: true);
  await directory.create(recursive: true);
}

Future<void> moveStorageDirectory(
  String sourcePath,
  String destinationPath, {
  TaskContext? task,
}) async {
  final source = Directory(p.normalize(p.absolute(sourcePath)));
  final destination = Directory(p.normalize(p.absolute(destinationPath)));
  if (p.equals(source.path, destination.path)) return;
  if (p.isWithin(source.path, destination.path) ||
      p.isWithin(destination.path, source.path)) {
    throw ArgumentError('Storage folders cannot contain one another');
  }
  await destination.create(recursive: true);
  if (!await source.exists()) return;

  final destinationEntries = await destination
      .list(followLinks: false)
      .toList();
  final sourceEntries = await source.list(followLinks: false).toList();
  if (destinationEntries.isNotEmpty && sourceEntries.isNotEmpty) {
    throw StateError('Destination storage folder must be empty');
  }

  var processed = 0;
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    task?.checkCancelled();
    if (entity is Link) {
      throw FileSystemException(
        'Linked storage entries are not supported',
        entity.path,
      );
    }
    final relative = p.relative(entity.path, from: source.path);
    final target = p.join(destination.path, relative);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
      processed++;
      if (processed == 1 || processed % 50 == 0) {
        task?.report('Copying $relative');
      }
    }
  }
  task?.checkCancelled();
  await source.delete(recursive: true);
}

String formatStorageBytes(num bytes) {
  if (bytes < 1024) return '${bytes.round()} B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
