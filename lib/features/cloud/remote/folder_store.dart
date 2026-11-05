import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../cloud_credentials.dart';
import 'remote_store.dart';

class FolderRemoteStore implements RemoteStore {
  FolderRemoteStore(this.root);
  final String root;
  String _path(String value) {
    final relative = normalizeRemotePath(value);
    if (relative.contains(':')) {
      throw const FormatException('Invalid relative path');
    }
    return p.join(root, p.fromUri(Uri(path: relative)));
  }

  @override
  Future<List<RemoteEntry>> list(String path) async {
    final directory = Directory(_path(path));
    if (!await directory.exists()) return [];
    final entries = <RemoteEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Link) {
        throw const FileSystemException('Linked repository entry');
      }
      final stat = await entity.stat();
      entries.add(
        RemoteEntry(
          path: joinRemotePath(path, p.basename(entity.path)),
          isDirectory: entity is Directory,
          size: entity is File ? stat.size : 0,
          modifiedAt: stat.modified,
        ),
      );
    }
    return entries;
  }

  @override
  Future<Uint8List> read(String path) => File(_path(path)).readAsBytes();
  @override
  Future<void> write(String path, List<int> bytes) =>
      atomicWrite(File(_path(path)), bytes);
  @override
  Future<void> delete(String path) async {
    final target = _path(path);
    if (p.equals(p.normalize(target), p.normalize(root))) {
      throw const FormatException('Cannot delete repository root');
    }
    if (await File(target).exists()) {
      await File(target).delete();
    } else if (await Directory(target).exists()) {
      await Directory(target).delete(recursive: true);
    }
  }

  @override
  Future<void> testConnection() async {
    await Directory(root).list().isEmpty;
  }
}
