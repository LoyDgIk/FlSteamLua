import 'dart:io';

import 'package:path/path.dart' as p;

const appStorageDirectories = ['cache', 'backups', 'downloads', 'logs', 'data'];

class AppPaths {
  AppPaths(this.root);

  factory AppPaths.platform() {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return AppPaths(p.join(base, 'FlSteamLua'));
  }

  final String root;
  final Map<String, String> _storageLocations = {};

  Map<String, String> get storageLocations =>
      Map.unmodifiable(_storageLocations);

  String storageLocation(String name) =>
      _storageLocations[name] ?? p.normalize(p.join(root, name));

  void configureStorageLocations(Map<String, String> locations) {
    _storageLocations.clear();
    for (final name in appStorageDirectories) {
      final value = locations[name]?.trim();
      if (value == null || value.isEmpty || !p.isAbsolute(value)) continue;
      _storageLocations[name] = p.normalize(p.absolute(value));
    }
  }

  String file(String relative) {
    final normalized = p.normalize(relative);
    final parts = p.split(normalized);
    if (parts.length == 1) {
      return _storageLocations[parts.first] ?? p.join(root, normalized);
    }
    final base = _storageLocations[parts.first];
    return base == null
        ? p.join(root, normalized)
        : p.joinAll([base, ...parts.skip(1)]);
  }

  Directory directory(String relative) => Directory(file(relative));

  Future<void> initialize() async {
    await Directory(root).create(recursive: true);
    for (final name in appStorageDirectories) {
      await Directory(storageLocation(name)).create(recursive: true);
    }
  }
}
