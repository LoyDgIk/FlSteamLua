import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/task_center.dart';
import '../steam_protocol/manifest/depot_manifest.dart';
import 'content_source_registry.dart';

class ContentResolver {
  ContentResolver(this.registry);
  final ContentSourceRegistry registry;
  static const maxArtifactBytes = 128 * 1024 * 1024;
  static const maxExpandedBytes = 512 * 1024 * 1024;

  Future<ContentBundle> resolve(
    int appId,
    ContentPlan plan, {
    bool pinManifests = false,
    bool refreshMetadata = true,
    TaskContext? task,
  }) async {
    final luaSource = registry.source(plan.luaSourceId);
    if (!luaSource.capabilities.contains(ContentCapability.lua)) {
      throw const FormatException(
        'The selected Lua source does not provide Lua',
      );
    }
    final requested = <String, Set<ContentCapability>>{
      plan.luaSourceId: {ContentCapability.lua},
    };
    if (plan.manifestSourceId case final String id) {
      final capabilities = registry.source(id).capabilities.intersection({
        ContentCapability.manifestIds,
        ContentCapability.manifestFiles,
      });
      if (capabilities.isEmpty) {
        throw const FormatException(
          'The selected manifest source has no manifest capability',
        );
      }
      requested.putIfAbsent(id, () => {}).addAll(capabilities);
    }
    final bundles = <ContentBundle>[];
    for (final entry in requested.entries) {
      task?.checkCancelled();
      final payload = await registry.fetch(
        entry.key,
        appId,
        requestedCapabilities: entry.value,
        dlcIds: plan.dlcIds,
        pinManifests: pinManifests,
        refreshMetadata: refreshMetadata,
        task: task,
      );
      final prepared = ContentSourcePayload(
        artifacts: await _prepareNative(payload.artifacts, task: task),
        pins: payload.pins,
        logs: payload.logs,
      );
      bundles.add(
        resolvePayload(
          appId,
          prepared,
          requestedCapabilities: entry.value,
          pinManifests: pinManifests,
        ),
      );
    }
    task?.checkCancelled();
    return _merge(appId, bundles, requireLua: true, pinManifests: pinManifests);
  }

  Future<List<int>> discoverLocalGames(
    List<String> paths, {
    TaskContext? task,
  }) async {
    final artifacts = _expandArtifacts(await _readLocal(paths, task: task));
    final ids = <int>{};
    for (final artifact in artifacts) {
      if (p.extension(artifact.filename).toLowerCase() != ".lua") continue;
      final code = _withoutComments(utf8.decode(artifact.bytes));
      final match = RegExp(r"\baddappid\s*\(\s*(\d+)").firstMatch(code);
      if (match != null) ids.add(int.parse(match[1]!));
    }
    return ids.toList()..sort();
  }

  Future<ContentBundle> resolveLocal(
    int appId,
    List<String> paths, {
    TaskContext? task,
  }) async {
    return resolvePayload(
      appId,
      ContentSourcePayload(artifacts: await _readLocal(paths, task: task)),
      requestedCapabilities: {ContentCapability.lua},
      includeManifestFiles: true,
    );
  }

  Future<List<ContentArtifact>> _readLocal(
    List<String> paths, {
    TaskContext? task,
  }) async {
    final artifacts = <ContentArtifact>[];
    var total = 0;
    Future<void> add(File file, String name) async {
      task?.checkCancelled();
      if (await file.length() > maxArtifactBytes) {
        throw const FormatException('Local content file exceeds 128 MB');
      }
      final bytes = await file.readAsBytes();
      total += bytes.length;
      if (total > maxExpandedBytes || artifacts.length >= 10000) {
        throw const FormatException('Local import exceeds content size limit');
      }
      artifacts.add(
        ContentArtifact(filename: name, bytes: bytes, sourceId: 'local'),
      );
    }

    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw const FormatException(
          'Local content cannot contain symbolic links',
        );
      }
      if (type == FileSystemEntityType.directory) {
        await for (final entry in Directory(
          path,
        ).list(recursive: true, followLinks: false)) {
          if (entry is Link) {
            throw const FormatException(
              'Local content cannot contain symbolic links',
            );
          }
          if (entry is File) {
            await add(entry, p.relative(entry.path, from: path));
          }
        }
      } else if (type == FileSystemEntityType.file) {
        await add(File(path), p.basename(path));
      } else {
        throw FileSystemException('Local content does not exist', path);
      }
    }
    return _prepareNative(artifacts, task: task);
  }

  static Future<List<ContentArtifact>> _prepareNative(
    List<ContentArtifact> artifacts, {
    TaskContext? task,
  }) async {
    final result = <ContentArtifact>[];
    for (final artifact in artifacts) {
      if (!{
        '.7z',
        '.rar',
      }.contains(p.extension(artifact.filename).toLowerCase())) {
        result.add(artifact);
        continue;
      }
      _safeRelative(artifact.filename);
      if (artifact.bytes.length > maxArtifactBytes) {
        throw const FormatException('Content archive exceeds 128 MB');
      }
      final temporary = await Directory.systemTemp.createTemp(
        'fl-content-archive-',
      );
      try {
        final file = File(
          p.join(temporary.path, 'content${p.extension(artifact.filename)}'),
        );
        await file.writeAsBytes(artifact.bytes, flush: true);
        final listing = utf8.decode(await _tar(['-tf', file.path], task: task));
        final names = const LineSplitter().convert(listing);
        if (names.length > 10000) {
          throw const FormatException('Content archive has too many entries');
        }
        final details = utf8.decode(
          await _tar(['-tvf', file.path], task: task),
        );
        if (const LineSplitter()
            .convert(details)
            .any((line) => line.startsWith('l') || line.startsWith('h'))) {
          throw const FormatException('Content archive contains links');
        }
        var total = 0;
        for (final name in names) {
          _safeRelative(name);
          if (!{
            '.lua',
            '.manifest',
            '.zip',
            '.tar',
            '.tgz',
            '.gz',
          }.contains(p.extension(name).toLowerCase())) {
            continue;
          }
          final bytes = await _tar(['-xOf', file.path, '--', name], task: task);
          total += bytes.length;
          if (total > maxExpandedBytes) {
            throw const FormatException('Expanded content exceeds 512 MB');
          }
          result.add(
            ContentArtifact(
              filename: name,
              bytes: bytes,
              sourceId: artifact.sourceId,
            ),
          );
        }
      } finally {
        if (p.isWithin(
          Directory.systemTemp.absolute.path,
          temporary.absolute.path,
        )) {
          await temporary.delete(recursive: true);
        }
      }
    }
    return result;
  }

  static Future<List<int>> _tar(
    List<String> arguments, {
    TaskContext? task,
  }) async {
    task?.checkCancelled();
    final process = await Process.start(
      Platform.isWindows ? 'tar.exe' : 'tar',
      arguments,
    );
    final errors = process.stderr.transform(utf8.decoder).join();
    final bytes = <int>[];
    try {
      await process.stdout
          .forEach((chunk) {
            task?.checkCancelled();
            if (bytes.length + chunk.length > maxArtifactBytes) {
              throw const FormatException('Archive entry exceeds 128 MB');
            }
            bytes.addAll(chunk);
          })
          .timeout(const Duration(seconds: 30));
      final exit = await process.exitCode.timeout(const Duration(seconds: 5));
      if (exit != 0) {
        throw ProcessException('tar', arguments, await errors, exit);
      }
      return bytes;
    } catch (_) {
      process.kill();
      await process.exitCode;
      await errors;
      rethrow;
    }
  }

  ContentBundle resolvePayload(
    int appId,
    ContentSourcePayload payload, {
    required Set<ContentCapability> requestedCapabilities,
    bool includeManifestFiles = false,
    bool pinManifests = false,
  }) {
    if (appId <= 0) throw const FormatException('Invalid target AppID');
    final artifacts = _expandArtifacts(payload.artifacts);
    ContentArtifact? lua;
    final files = <ContentArtifact>[];
    final wantLua = requestedCapabilities.contains(ContentCapability.lua);
    final wantManifest = requestedCapabilities.any(
      (capability) => capability != ContentCapability.lua,
    );
    final pins = <ManifestPin>[if (wantManifest) ...payload.pins];
    for (final artifact in artifacts) {
      final extension = p.extension(artifact.filename).toLowerCase();
      if (extension == '.lua' && wantLua) {
        final content = utf8.decode(artifact.bytes).replaceFirst('\ufeff', '');
        final code = _withoutComments(content);
        final applications = RegExp(
          r'\baddappid\s*\(\s*(\d+)',
        ).allMatches(code).map((match) => int.parse(match[1]!));
        if (applications.firstOrNull != appId) continue;
        if (lua != null) {
          throw const FormatException(
            'Content contains more than one Lua configuration for this import',
          );
        }
        lua = ContentArtifact(
          filename: '$appId.lua',
          bytes: utf8.encode(content),
          capability: ContentCapability.lua,
          sourceId: artifact.sourceId,
        );
        pins.addAll(_luaPins(content, artifact.sourceId));
      } else if (extension == '.manifest' &&
          (requestedCapabilities.contains(ContentCapability.manifestFiles) ||
              includeManifestFiles)) {
        final manifest = DepotManifest.parse(artifact.bytes);
        final name = p.posix.basename(artifact.filename.replaceAll('\\', '/'));
        final expected = '${manifest.depotId}_${manifest.manifestGid}.manifest';
        if (name != expected) {
          throw FormatException(
            'Manifest filename does not match its depot and GID: $name',
          );
        }
        pins.add(
          ManifestPin(
            depotId: manifest.depotId,
            manifestId: '${manifest.manifestGid}',
            sourceId: artifact.sourceId,
          ),
        );
        files.add(
          ContentArtifact(
            filename: expected,
            bytes: manifest.toBytes(),
            capability: ContentCapability.manifestFiles,
            sourceId: artifact.sourceId,
            depotId: manifest.depotId,
            manifestId: '${manifest.manifestGid}',
          ),
        );
      }
    }
    if (wantLua && lua == null) {
      throw const FormatException(
        'The selected source returned no Lua configuration',
      );
    }
    if (requestedCapabilities.contains(ContentCapability.manifestFiles) &&
        files.isEmpty) {
      throw const FormatException(
        'The selected source returned no manifest files',
      );
    }
    if (requestedCapabilities.contains(ContentCapability.manifestIds) &&
        pins.isEmpty) {
      throw const FormatException(
        'The selected source returned no manifest IDs',
      );
    }
    if (wantManifest && files.isEmpty && payload.pins.isEmpty) {
      throw const FormatException(
        'The selected manifest source returned no manifest IDs or files',
      );
    }
    return _merge(
      appId,
      [
        ContentBundle(
          appId: appId,
          lua: lua,
          manifestPins: pins,
          manifestFiles: files,
          logs: payload.logs,
        ),
      ],
      requireLua: wantLua,
      pinManifests: pinManifests,
    );
  }

  static List<ContentArtifact> _expandArtifacts(List<ContentArtifact> inputs) {
    final artifacts = <ContentArtifact>[];
    var expandedBytes = 0;
    void expand(ContentArtifact artifact, int depth) {
      _safeRelative(artifact.filename);
      final extension = p.extension(artifact.filename).toLowerCase();
      if (!{
        '.lua',
        '.manifest',
        '.zip',
        '.tar',
        '.tgz',
        '.gz',
        '.7z',
        '.rar',
      }.contains(extension)) {
        return;
      }
      if (artifact.bytes.isEmpty || artifact.bytes.length > maxArtifactBytes) {
        throw FormatException(
          'Content file is empty or exceeds 128 MB: ${artifact.filename}',
        );
      }
      if (depth > 3 || artifacts.length > 10000) {
        throw const FormatException(
          'Content archive exceeds nesting or entry limit',
        );
      }
      if ({'.zip', '.tar', '.tgz', '.gz'}.contains(extension)) {
        final archive = switch (extension) {
          '.zip' => ZipDecoder().decodeBytes(artifact.bytes, verify: true),
          '.tar' => TarDecoder().decodeBytes(artifact.bytes),
          _ => TarDecoder().decodeBytes(
            GZipDecoder().decodeBytes(artifact.bytes),
          ),
        };
        if (archive.files.length > 10000) {
          throw const FormatException('Content archive has too many entries');
        }
        for (final file in archive.files) {
          _safeRelative(file.name);
          if (file.isSymbolicLink || file.isHardLink) {
            throw const FormatException('Content archive contains links');
          }
          if (!file.isFile) continue;
          expandedBytes += file.size;
          if (expandedBytes > maxExpandedBytes) {
            throw const FormatException('Expanded content exceeds 512 MB');
          }
          expand(
            ContentArtifact(
              filename: file.name,
              bytes: file.content,
              sourceId: artifact.sourceId,
            ),
            depth + 1,
          );
        }
      } else {
        if (extension == '.7z' || extension == '.rar') {
          throw const FormatException(
            'This content archive must be unpacked before importing',
          );
        }
        artifacts.add(artifact);
      }
    }

    for (final artifact in inputs) {
      expand(artifact, 0);
    }
    return artifacts;
  }

  ContentBundle _merge(
    int appId,
    List<ContentBundle> bundles, {
    required bool requireLua,
    required bool pinManifests,
  }) {
    ContentArtifact? lua;
    final pins = <int, ManifestPin>{};
    final files = <String, ContentArtifact>{};
    final logs = <String>[];
    for (final bundle in bundles) {
      lua ??= bundle.lua;
      logs.addAll(bundle.logs);
      for (final pin in bundle.manifestPins) {
        final id = BigInt.tryParse(pin.manifestId);
        if (pin.depotId <= 0 ||
            id == null ||
            id <= BigInt.zero ||
            id > (BigInt.one << 64) - BigInt.one) {
          throw const FormatException('Invalid manifest pin');
        }
        final previous = pins[pin.depotId];
        if (previous != null && previous.manifestId != pin.manifestId) {
          throw FormatException(
            'Manifest conflict for depot ${pin.depotId}: ${previous.manifestId} (${previous.sourceId}) / ${pin.manifestId} (${pin.sourceId})',
          );
        }
        pins[pin.depotId] = pin;
      }
      for (final file in bundle.manifestFiles) {
        files.putIfAbsent(file.filename, () => file);
      }
    }
    if (requireLua && lua == null) {
      throw const FormatException('Lua is required to add a game');
    }
    if (lua != null) {
      var content = utf8.decode(lua.bytes);
      final existing = _luaPins(
        content,
        lua.sourceId,
      ).map((pin) => pin.depotId).toSet();
      final extra = pins.values.where((pin) => !existing.contains(pin.depotId));
      content = _applyManifestPinMode(content, pinManifests);
      if (extra.isNotEmpty) {
        content =
            '${content.trimRight()}\n${extra.map((pin) => '${pinManifests ? '' : '--'}setManifestid(${pin.depotId},"${pin.manifestId}",0)').join('\n')}\n';
      }
      lua = ContentArtifact(
        filename: '$appId.lua',
        bytes: utf8.encode(content),
        capability: ContentCapability.lua,
        sourceId: lua.sourceId,
      );
    }
    return ContentBundle(
      appId: appId,
      lua: lua,
      manifestPins: pins.values.toList(),
      manifestFiles: files.values.toList(),
      logs: logs,
    );
  }

  static List<ManifestPin> _luaPins(String code, String sourceId) =>
      RegExp(
            r'''^\s*(?:--\s*)?setManifestid\s*\(\s*(\d+)\s*,\s*["']?(\d+)["']?\s*(?:,|\))''',
            multiLine: true,
          )
          .allMatches(code)
          .map(
            (match) => ManifestPin(
              depotId: int.parse(match[1]!),
              manifestId: match[2]!,
              sourceId: sourceId,
            ),
          )
          .toList();

  static String _applyManifestPinMode(String content, bool pinManifests) {
    final pin = RegExp(
      r'''^\s*(?:--\s*)?setManifestid\s*\(\s*(\d+)\s*,\s*["']?(\d+)["']?\s*(?:,\s*\d+\s*)?\)\s*$''',
    );
    final lines = const LineSplitter()
        .convert(content)
        .map((line) {
          final match = pin.firstMatch(line);
          if (match == null) return line;
          return '${pinManifests ? '' : '--'}setManifestid(${match[1]},"${match[2]}",0)';
        })
        .join('\n');
    return content.endsWith('\n') ? '$lines\n' : lines;
  }

  static String _withoutComments(String content) => content
      .replaceAll(RegExp(r'--\[\[[\s\S]*?\]\]'), '')
      .replaceAll(RegExp(r'--[^\r\n]*'), '');

  static void _safeRelative(String name) {
    final normalized = name.replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains(':') ||
        normalized.contains('\u0000') ||
        normalized.split('/').contains('..')) {
      throw FormatException('Unsafe content path: $name');
    }
  }
}
