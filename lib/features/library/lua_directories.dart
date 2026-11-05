import 'dart:io';

import 'package:path/path.dart' as p;

import '../kernel/kernel_config.dart';

/// Ordered core paths. Index zero is the client's default write destination;
/// the core also always loads config/lua after its configured paths.
class LuaDirectories {
  LuaDirectories(this.steamPath);

  final String steamPath;
  String get coreDefault => p.join(steamPath, 'config', 'lua');

  /// User-configured paths from the core TOML. The fixed core directory is
  /// displayed separately and is never a reorderable custom entry.
  List<String> customPaths() {
    final lua = KernelConfig(steamPath).readSync()['lua'];
    final raw = lua is Map ? lua['paths'] : null;
    if (raw == null || raw is List && raw.isEmpty) return const [];
    if (raw is! List ||
        raw.any((value) => value is! String || value.trim().isEmpty)) {
      throw const FormatException(
        'lua.paths must be an array of non-empty paths',
      );
    }
    return _normalize(
      raw.cast<String>(),
    ).where((path) => !samePath(path, coreDefault)).toList(growable: false);
  }

  List<String> read() {
    final custom = customPaths();
    return custom.isEmpty ? [coreDefault] : custom;
  }

  List<String> get loadOrder {
    final paths = customPaths();
    return [...paths, coreDefault];
  }

  List<String> _normalize(List<String> paths) {
    final result = <String>[];
    for (final path in paths) {
      final full = p.normalize(
        p.isAbsolute(path) ? path : p.join(steamPath, path),
      );
      if (!result.any((other) => samePath(other, full))) result.add(full);
    }
    return result;
  }

  Future<void> save(List<String> paths) async {
    if (paths.any((path) => path.trim().isEmpty)) {
      throw const FormatException('Lua directories cannot be empty');
    }
    final normalized = _normalize(
      paths.map((path) => path.trim()).toList(),
    ).where((path) => !samePath(path, coreDefault)).toList(growable: false);
    for (final path in normalized) {
      await Directory(path).create(recursive: true);
    }
    await KernelConfig(steamPath).update('lua', {'paths': normalized});
  }

  static bool samePath(String a, String b) => p.equals(
    Platform.isWindows ? a.toLowerCase() : a,
    Platform.isWindows ? b.toLowerCase() : b,
  );
}
