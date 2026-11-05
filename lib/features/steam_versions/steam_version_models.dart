import '../library/kv1.dart';

class SteamPackageFile {
  const SteamPackageFile({
    required this.name,
    required this.size,
    required this.sha256,
  });
  final String name, sha256;
  final int size;
}

class SteamClientPackage {
  const SteamClientPackage({
    required this.section,
    required this.zip,
    this.compressed,
    this.bootstrap = false,
  });
  final String section;
  final SteamPackageFile zip;
  final SteamPackageFile? compressed;
  final bool bootstrap;
  SteamPackageFile get preferred => compressed ?? zip;
}

class SteamClientVersion {
  SteamClientVersion({
    required this.arch,
    required this.build,
    required this.manifest,
    required this.source,
    required this.manifestUrl,
    this.snapshot,
  });
  final String arch, build, manifest, source, manifestUrl;
  final String? snapshot;
  bool get hasManifest => manifest.isNotEmpty;
  String get id => build.isEmpty ? '${arch}_at_$snapshot' : '${arch}_$build';
  DateTime get date => build.isNotEmpty
      ? DateTime.fromMillisecondsSinceEpoch(
          int.parse(build) * 1000,
          isUtc: true,
        )
      : DateTime.utc(
          int.parse(snapshot!.substring(0, 4)),
          int.parse(snapshot!.substring(4, 6)),
          int.parse(snapshot!.substring(6, 8)),
        );
  late final List<SteamClientPackage> packages = hasManifest
      ? parseSteamClientManifest(manifest).packages
      : const [];
  late final List<SteamPackageFile> files = _files();
  List<SteamPackageFile> _files() {
    final result = <String, SteamPackageFile>{};
    for (final package in packages) {
      result[package.preferred.name] = package.preferred;
      if (package.bootstrap && package.section == 'steam_$arch') {
        result[package.zip.name] = package.zip;
      }
    }
    return List.unmodifiable(result.values);
  }

  int get size => files.fold(0, (sum, f) => sum + f.size);
  Map<String, dynamic> toJson() => {
    'arch': arch,
    'build': build,
    'manifest': manifest,
    'source': source,
    'url': manifestUrl,
    'snapshot': snapshot,
  };
  factory SteamClientVersion.fromJson(Map<String, dynamic> value) {
    final arch = value['arch'],
        build = value['build'],
        manifest = value['manifest'];
    if (!{'win32', 'win64'}.contains(arch) ||
        build is! String ||
        build.isNotEmpty && !RegExp(r'^\d{9,10}$').hasMatch(build) ||
        manifest is! String ||
        !{
          'official',
          'archive',
          'local',
          'builtin',
        }.contains(value['source']) ||
        value['snapshot'] != null &&
            !RegExp(r'^\d{14}$').hasMatch(value['snapshot'])) {
      throw const FormatException('Invalid cached Steam version');
    }
    if (manifest.isEmpty) {
      if (value['snapshot'] == null) {
        throw const FormatException('Missing history snapshot');
      }
    } else {
      final parsed = parseSteamClientManifest(manifest);
      if (parsed.arch != arch || parsed.build != build) {
        throw const FormatException('Manifest does not match cached version');
      }
    }
    return SteamClientVersion(
      arch: arch as String,
      build: build,
      manifest: value['manifest'],
      source: value['source'],
      manifestUrl: value['url'] as String,
      snapshot: value['snapshot'] as String?,
    );
  }
}

({String arch, String build, List<SteamClientPackage> packages})
parseSteamClientManifest(String text) {
  if (text.length > 4 * 1024 * 1024) {
    throw const FormatException('Steam manifest is too large');
  }
  final document = Kv1.parse(text);
  final architectures = document.keys
      .where((k) => k == 'win32' || k == 'win64')
      .toList();
  if (architectures.length != 1) {
    throw const FormatException('Missing Steam manifest architecture');
  }
  final arch = architectures.single;
  final root = document[arch];
  if (root is! Map ||
      root['version'] is! String ||
      !RegExp(r'^\d{9,10}$').hasMatch(root['version'])) {
    throw const FormatException('Invalid Steam build number');
  }
  final result = <SteamClientPackage>[];
  SteamPackageFile file(dynamic name, dynamic size, dynamic hash) {
    final count = int.tryParse('$size');
    if (name is! String ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]+$').hasMatch(name) ||
        name.contains('..') ||
        count == null ||
        count <= 0 ||
        count > 8 * 1024 * 1024 * 1024 ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid Steam package file');
    }
    return SteamPackageFile(
      name: name,
      size: count,
      sha256: hash.toLowerCase(),
    );
  }

  void walk(Map node, String section) {
    if (node.containsKey('file')) {
      final zip = file(node['file'], node['size'], node['sha2']);
      final compressed = node['zipvz'] == null
          ? null
          : file(
              node['zipvz'],
              RegExp(r'_(\d+)$').firstMatch(node['zipvz'] as String)?.group(1),
              node['sha2vz'],
            );
      result.add(
        SteamClientPackage(
          section: section,
          zip: zip,
          compressed: compressed,
          bootstrap: node['IsBootstrapperPackage'] == '1',
        ),
      );
    }
    for (final entry in node.entries) {
      if (entry.value is Map) {
        walk(
          entry.value,
          section.isEmpty ? '${entry.key}' : '$section/${entry.key}',
        );
      }
    }
  }

  walk(root, '');
  if (result.isEmpty ||
      !result.any((v) => v.bootstrap && v.section == 'steam_$arch')) {
    throw const FormatException('Steam manifest has no bootstrap package');
  }
  return (arch: arch, build: root['version'] as String, packages: result);
}

class SteamClientInstallation {
  const SteamClientInstallation({
    required this.root,
    this.arch,
    this.build,
    this.indexPath,
  });
  final String root;
  final String? arch, build, indexPath;
}

class SteamClientBackup {
  const SteamClientBackup({
    required this.path,
    required this.target,
    required this.createdAt,
    required this.files,
    required this.build,
  });
  final String path, target, build;
  final DateTime createdAt;
  final int files;
}
