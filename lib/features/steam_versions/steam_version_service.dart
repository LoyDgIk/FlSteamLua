import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../core/steam_process_actions.dart';
import '../../ui/localization.dart';
import '../library/library_service.dart';
import '../library/process_observer.dart';
import '../network/network_preferences.dart';
import 'steam_version_models.dart';
import 'steam_version_runner.dart';

export 'steam_version_models.dart';
part 'steam_version_install.dart';

class SteamVersionService extends ChangeNotifier {
  SteamVersionService({
    required this.paths,
    required this.settings,
    required this.library,
    http.Client? client,
    DateTime Function()? clock,
    Future<String> Function()? builtInCatalog,
    SteamVersionRunner? runner,
    ProcessSnapshotReader? processReader,
    Future<void> Function(File, List<int>)? writer,
  }) : client = client ?? NetworkHttpClient(settings: settings),
       _builtInCatalog =
           builtInCatalog ??
           (() => rootBundle.loadString('assets/steam_versions/catalog.json')),
       _clock = clock ?? DateTime.now,
       _runner = runner ?? runSteamVersionBootstrap,
       _processReader = processReader ?? readRunningProcesses,
       _writer = writer ?? _writeBytes;
  final AppPaths paths;
  final SettingsStore settings;
  final LibraryService library;
  final http.Client client;
  final DateTime Function() _clock;
  final Future<String> Function() _builtInCatalog;
  final SteamVersionRunner _runner;
  final ProcessSnapshotReader _processReader;
  final Future<void> Function(File, List<int>) _writer;
  final List<SteamClientVersion> _versions = [];
  final Map<String, String> _resolvedSnapshots = {};
  List<SteamClientVersion> get versions => List.unmodifiable(_versions);
  final Map<String, int> downloadedCounts = {};
  SteamClientInstallation? installed;
  bool busy = false;
  String? lastError;
  DateTime? checkedAt;
  AppLocalizations get texts => localizationsFor(settings.language);
  static const cdn = 'https://media.steampowered.com/client';
  static const defaultWaybackBase = 'https://web.archive.org';
  String get waybackBase =>
      settings.get<String>('steamVersionsWaybackBase', defaultWaybackBase);
  Uri _archiveUrl(String path, [Map<String, String>? query]) => Uri.parse(
    '${normalizeWaybackBase(waybackBase)}/$path',
  ).replace(queryParameters: query);
  Future<({String body, Uri url})> _archiveText(
    String path,
    Map<String, String>? query,
    void Function(String) validate,
    TaskContext? context,
  ) async {
    final url = _archiveUrl(path, query);
    final body = await _text(url, context);
    validate(body);
    return (body: body, url: url);
  }

  String normalizeWaybackBase(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.any((part) => part == '..' || part == '.')) {
      throw FormatException(texts.steamVersionWaybackInvalid);
    }
    return uri.toString().replaceFirst(RegExp(r'/+$'), '');
  }

  Future<void> setWaybackBase(String raw) => operation(() async {
    await settings.set('steamVersionsWaybackBase', normalizeWaybackBase(raw));
  });

  String directory(SteamClientVersion value) =>
      paths.file('downloads/steam-client/${value.id}');
  File get _catalog => File(paths.file('data/steam-client-versions.json'));
  void _notify() => notifyListeners();

  Future<T> operation<T>(Future<T> Function() action) async {
    if (busy) throw StateError(texts.steamVersionBusy);
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      lastError = '$error';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    _versions.clear();
    _resolvedSnapshots.clear();
    final seed = jsonDecode(await _builtInCatalog()) as Map<String, dynamic>;
    for (final item in seed['versions'] as List) {
      _merge(
        SteamClientVersion.fromJson(Map<String, dynamic>.from(item as Map)),
      );
    }
    if (await _catalog.exists()) {
      final json = jsonDecode(await _catalog.readAsString());
      if (json is! Map || json['versions'] is! List) {
        throw FormatException(texts.steamVersionInvalidCatalog);
      }
      for (final item in json['versions'] as List) {
        _merge(
          SteamClientVersion.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      }
      final snapshots = json['resolvedSnapshots'];
      if (snapshots is Map) {
        for (final entry in snapshots.entries) {
          if (entry.key is! String ||
              entry.value is! String ||
              !RegExp(r'^win(32|64)_\d{14}$').hasMatch(entry.key)) {
            throw FormatException(texts.steamVersionInvalidCatalog);
          }
          _resolvedSnapshots[entry.key as String] = entry.value as String;
        }
      }
      checkedAt = DateTime.tryParse(json['checkedAt'] as String? ?? '');
    }
    await refreshLocal();
  }

  Future<void> refreshLocal() async {
    installed = await inspectInstallation(settings.steamPath);
    for (final version in _versions) {
      var count = 0;
      for (final file in version.files) {
        final local = File(p.join(directory(version), file.name));
        if (await local.exists() && await local.length() == file.size) count++;
      }
      downloadedCounts[version.id] = count;
    }
    _versions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> _saveCatalog() => _writeBytes(
    _catalog,
    utf8.encode(
      jsonEncode({
        'checkedAt': checkedAt?.toIso8601String(),
        'versions': _versions.map((v) => v.toJson()).toList(),
        'resolvedSnapshots': _resolvedSnapshots,
      }),
    ),
  );
  void _merge(SteamClientVersion version) {
    if (version.snapshot != null && version.hasManifest) {
      _resolvedSnapshots['${version.arch}_${version.snapshot}'] = version.id;
    }
    _versions.removeWhere(
      (v) =>
          version.snapshot != null &&
          v.arch == version.arch &&
          v.snapshot == version.snapshot &&
          v.id != version.id,
    );
    final index = _versions.indexWhere((v) => v.id == version.id);
    if (index < 0) {
      _versions.add(version);
    } else if (version.hasManifest &&
        (!_versions[index].hasManifest ||
            version.source == 'official' ||
            _versions[index].source != 'official')) {
      _versions[index] = version;
    }
  }

  Future<void> refreshCatalog({
    bool forceRefresh = false,
    TaskContext? context,
  }) => operation(() async {
    final errors = <String>[];
    try {
      await _latest(context: context);
    } on TaskCancelled {
      rethrow;
    } catch (error) {
      errors.add('$error');
    }
    for (final arch in ['win64', 'win32']) {
      try {
        await _history(
          arch: arch,
          limit: 0,
          forceRefresh: forceRefresh,
          context: context,
        );
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        errors.add('$error');
      }
    }
    if (errors.isNotEmpty) {
      lastError = errors.join('\n');
      _notify();
      throw StateError(lastError!);
    }
  });

  Future<void> latest({TaskContext? context}) =>
      operation(() => _latest(context: context));
  Future<void> _latest({TaskContext? context}) async {
    final failures = <String>[];
    for (final arch in ['win64', 'win32']) {
      context?.checkCancelled();
      try {
        final url = '$cdn/steam_client_$arch';
        final body = await _text(Uri.parse(url), context);
        final parsed = parseSteamClientManifest(body);
        if (parsed.arch != arch) {
          throw FormatException(texts.steamVersionManifestMismatch);
        }
        _merge(
          SteamClientVersion(
            arch: arch,
            build: parsed.build,
            manifest: body,
            source: 'official',
            manifestUrl: url,
          ),
        );
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        failures.add('$arch: $error');
      }
    }
    checkedAt = _clock();
    await _saveCatalog();
    await refreshLocal();
    if (failures.isNotEmpty) throw StateError(failures.join('\n'));
  }

  Future<void> history({
    required String arch,
    String from = '',
    String to = '',
    int limit = 0,
    bool forceRefresh = false,
    TaskContext? context,
  }) => operation(
    () => _history(
      arch: arch,
      from: from,
      to: to,
      limit: limit,
      forceRefresh: forceRefresh,
      context: context,
    ),
  );
  Future<void> _history({
    required String arch,
    String from = '',
    String to = '',
    int limit = 0,
    bool forceRefresh = false,
    TaskContext? context,
  }) async {
    if (!{'win32', 'win64'}.contains(arch) ||
        limit < 0 ||
        limit > 400 ||
        !validSteamHistoryDates(from, to)) {
      throw FormatException(texts.steamVersionInvalidFilter);
    }
    final query = <String, String>{
      'url': 'media.steampowered.com/client/steam_client_$arch',
      'output': 'json',
      'fl': 'timestamp,original',
      'filter': 'statuscode:200',
      'collapse': 'digest',
      if (from.isNotEmpty) 'from': from,
      if (to.isNotEmpty) 'to': to,
    };
    final indexFile = File(
      paths.file(
        'cache/steam-client-history/index/${sha256.convert(utf8.encode('$arch|$from|$to'))}.json',
      ),
    );
    dynamic data;
    if (!forceRefresh && await indexFile.exists()) {
      final saved = jsonDecode(await indexFile.readAsString());
      if (saved is! Map ||
          saved['checkedAt'] is! String ||
          saved['rows'] is! List) {
        throw FormatException(texts.steamVersionInvalidCatalog);
      }
      final time = DateTime.tryParse(saved['checkedAt'] as String);
      if (time != null &&
          _clock().difference(time) >= Duration.zero &&
          _clock().difference(time) < const Duration(hours: 24)) {
        data = saved['rows'];
      }
    }
    final freshIndex = data == null;
    if (data == null) {
      final response = await _archiveText('cdx/search/cdx', query, (body) {
        _historyRows(jsonDecode(body), arch);
      }, context);
      data = jsonDecode(response.body);
    }
    final rows = _historyRows(data, arch);

    if (freshIndex) {
      await _writeBytes(
        indexFile,
        utf8.encode(
          jsonEncode({
            'checkedAt': _clock().toUtc().toIso8601String(),
            'rows': data,
          }),
        ),
      );
    }
    final selectedRows = limit == 0 ? rows : rows.take(limit).toList();
    for (final row in selectedRows) {
      context?.checkCancelled();
      if (_resolvedSnapshots.containsKey('${arch}_${row[0]}') ||
          _versions.any((v) => v.arch == arch && v.snapshot == row[0])) {
        continue;
      }
      _merge(
        SteamClientVersion(
          arch: arch,
          build: '',
          manifest: '',
          source: 'archive',
          snapshot: row[0],
          manifestUrl: row[1],
        ),
      );
    }
    checkedAt = _clock();
    await _saveCatalog();
    await refreshLocal();
  }

  Future<SteamClientVersion> resolveVersion(
    SteamClientVersion version, {
    bool forceRefresh = false,
    TaskContext? context,
  }) => operation(
    () =>
        _resolveVersion(version, forceRefresh: forceRefresh, context: context),
  );

  Future<SteamClientVersion> _resolveVersion(
    SteamClientVersion version, {
    bool forceRefresh = false,
    TaskContext? context,
  }) async {
    final known = _versions
        .where(
          (v) =>
              (v.id == version.id ||
                  v.id ==
                      _resolvedSnapshots['${version.arch}_${version.snapshot}']) &&
              v.hasManifest,
        )
        .firstOrNull;
    if (!forceRefresh && (version.hasManifest || known != null)) {
      return known ?? version;
    }
    final stamp = version.snapshot!;
    final arch = version.arch;
    final cache = File(
      paths.file(
        'cache/steam-client-history/manifests/${arch}_$stamp.manifest',
      ),
    );
    final replay =
        'web/${stamp}id_/http://media.steampowered.com/client/steam_client_$arch';
    final cached = !forceRefresh && await cache.exists();
    final response = cached
        ? (body: await cache.readAsString(), url: _archiveUrl(replay))
        : await _archiveText(replay, null, (body) {
            final parsed = parseSteamClientManifest(body);
            if (parsed.arch != arch ||
                version.build.isNotEmpty && parsed.build != version.build) {
              throw FormatException(texts.steamVersionManifestMismatch);
            }
          }, context);
    final parsed = parseSteamClientManifest(response.body);
    if (parsed.arch != arch ||
        version.build.isNotEmpty && parsed.build != version.build) {
      throw FormatException(texts.steamVersionManifestMismatch);
    }
    if (!cached) await _writeBytes(cache, utf8.encode(response.body));
    final resolved = SteamClientVersion(
      arch: arch,
      build: parsed.build,
      manifest: response.body,
      source: 'archive',
      manifestUrl: response.url.toString(),
      snapshot: stamp,
    );
    _merge(resolved);
    await _saveCatalog();
    await refreshLocal();
    context?.report(
      cached
          ? texts.steamVersionCacheHit(stamp)
          : texts.steamVersionCacheSaved(stamp),
    );
    return resolved;
  }

  List<List<String>> _historyRows(dynamic data, String arch) {
    if (data is! List || data.any((v) => v is! List || v.length != 2)) {
      throw FormatException(texts.steamVersionInvalidCatalog);
    }
    final rows = <List<String>>[];
    for (final row in data.skip(1)) {
      final origin = row[1] is String ? Uri.tryParse(row[1]) : null;
      if (row[0] is! String ||
          !RegExp(r'^\d{14}$').hasMatch(row[0]) ||
          !{'http', 'https'}.contains(origin?.scheme) ||
          origin?.userInfo != '' ||
          origin?.hasQuery == true ||
          origin?.hasFragment == true ||
          origin?.host != 'media.steampowered.com' ||
          origin?.path != '/client/steam_client_$arch') {
        throw FormatException(texts.steamVersionInvalidCatalog);
      }
      rows.add([row[0] as String, row[1] as String]);
    }
    rows.sort((a, b) => b[0].compareTo(a[0]));
    return rows;
  }

  Future<String> _text(Uri uri, TaskContext? context) async {
    final abort = Completer<void>();
    final timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (context?.isCancelled == true && !abort.isCompleted) abort.complete();
    });
    try {
      context?.checkCancelled();
      final response = await client
          .send(http.AbortableRequest('GET', uri, abortTrigger: abort.future))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final bytes = BytesBuilder();
      await for (final part in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        context?.checkCancelled();
        bytes.add(part);
        if (bytes.length > 4 * 1024 * 1024) {
          if (!abort.isCompleted) abort.complete();
          throw FormatException(texts.steamVersionInvalidCatalog);
        }
      }
      final raw = bytes.takeBytes();
      final decoded = raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b
          ? gzip.decode(raw)
          : raw;
      if (decoded.length > 4 * 1024 * 1024) {
        throw FormatException(texts.steamVersionInvalidCatalog);
      }
      return utf8.decode(decoded);
    } on http.RequestAbortedException {
      context?.checkCancelled();
      rethrow;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<void> download(
    SteamClientVersion version, {
    TaskContext? context,
  }) => operation(() async {
    version = await _resolveVersion(version, context: context);
    final folder = Directory(directory(version));
    await folder.create(recursive: true);
    await _writeBytes(
      File(p.join(folder.path, 'steam_client_${version.arch}.manifest')),
      utf8.encode(version.manifest),
    );
    final files = version.files;
    for (var i = 0; i < files.length; i++) {
      context?.checkCancelled();
      final file = files[i];
      context?.report(
        texts.steamVersionDownloading(file.name),
        i / files.length,
      );
      final target = File(p.join(folder.path, file.name));
      if (await _validPackage(target, file)) continue;
      final candidates = [
        Uri.parse('$cdn/${file.name}'),
        if (version.snapshot != null)
          _archiveUrl(
            'web/${version.snapshot}id_/http://media.steampowered.com/client/${file.name}',
          ),
      ];
      Object? failure;
      for (final url in candidates) {
        try {
          await _downloadFile(url, target, file, context);
          failure = null;
          break;
        } on TaskCancelled {
          rethrow;
        } catch (error) {
          failure = error;
        }
      }
      if (failure != null) throw failure;
    }
    await refreshLocal();
  });

  Future<bool> _validPackage(File file, SteamPackageFile expected) async =>
      await file.exists() &&
      await file.length() == expected.size &&
      (await sha256.bind(file.openRead()).first).toString() == expected.sha256;
  Future<void> _downloadFile(
    Uri uri,
    File target,
    SteamPackageFile expected,
    TaskContext? context,
  ) async {
    final partial = File('${target.path}.part');
    var offset = await partial.exists() ? await partial.length() : 0;
    if (offset > expected.size) {
      await partial.delete();
      offset = 0;
    }
    if (offset == expected.size && await _validPackage(partial, expected)) {
      await partial.rename(target.path);
      return;
    }
    if (offset == expected.size) {
      await partial.delete();
      offset = 0;
    }
    final abort = Completer<void>();
    final timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (context?.isCancelled == true && !abort.isCompleted) abort.complete();
    });
    RandomAccessFile? output;
    try {
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abort.future,
      );
      request.headers['Accept-Encoding'] = 'identity';
      if (offset > 0) request.headers['Range'] = 'bytes=$offset-';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.stream.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      if (response.statusCode == 206) {
        final range = RegExp(
          r'^bytes (\d+)-(\d+)/(\d+)$',
        ).firstMatch(response.headers['content-range'] ?? '');
        if (range == null ||
            int.parse(range[1]!) != offset ||
            int.parse(range[3]!) != expected.size) {
          throw FormatException(texts.steamVersionRangeInvalid);
        }
      } else {
        offset = 0;
      }
      output = await partial.open(
        mode: offset == 0 ? FileMode.write : FileMode.append,
      );
      var received = offset;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        context?.checkCancelled();
        received += chunk.length;
        if (received > expected.size) {
          throw FormatException(texts.steamVersionChecksumFailed);
        }
        await output.writeFrom(chunk);
        context?.reportProgress(
          texts.steamVersionDownloadProgress(
            expected.name,
            '$received',
            '${expected.size}',
          ),
          received / expected.size,
        );
      }
      await output.close();
      output = null;
      if (!await _validPackage(partial, expected)) {
        await partial.delete();
        throw FormatException(texts.steamVersionChecksumFailed);
      }
      await partial.rename(target.path);
    } on http.RequestAbortedException {
      context?.checkCancelled();
      rethrow;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      await output?.close();
    }
  }

  Future<void> verify(
    SteamClientVersion version, {
    TaskContext? context,
  }) async {
    if (!version.hasManifest) throw StateError(texts.steamVersionLoadManifest);
    for (final file in version.files) {
      context?.checkCancelled();
      if (!await _validPackage(
        File(p.join(directory(version), file.name)),
        file,
      )) {
        throw FormatException(texts.steamVersionPackageInvalid(file.name));
      }
    }
  }

  Future<void> importDirectory(String source, {TaskContext? context}) =>
      operation(() async {
        var imported = 0;
        for (final arch in ['win32', 'win64']) {
          final manifest = File(p.join(source, 'steam_client_$arch.manifest'));
          if (!await manifest.exists()) continue;
          final text = await manifest.readAsString();
          final parsed = parseSteamClientManifest(text);
          if (parsed.arch != arch) continue;
          final version = SteamClientVersion(
            arch: arch,
            build: parsed.build,
            manifest: text,
            source: 'local',
            manifestUrl: '',
          );
          final destination = directory(version);
          if (p.equals(p.absolute(source), p.absolute(destination))) {
            throw FormatException(texts.steamVersionSameImport);
          }
          for (final expected in version.files) {
            context?.checkCancelled();
            final file = File(p.join(source, expected.name));
            if (!await file.exists()) continue;
            if (!await _validPackage(file, expected)) {
              throw FormatException(
                texts.steamVersionPackageInvalid(expected.name),
              );
            }
            await Directory(destination).create(recursive: true);
            await file.copy(p.join(destination, expected.name));
          }
          await _writeBytes(
            File(p.join(destination, 'steam_client_$arch.manifest')),
            utf8.encode(text),
          );
          _merge(version);
          imported++;
        }
        if (imported == 0) {
          throw FormatException(texts.steamVersionInvalidCatalog);
        }
        await _saveCatalog();
        await refreshLocal();
      });
  Future<void> removeDownload(SteamClientVersion version) =>
      operation(() async {
        final folder = Directory(directory(version));
        if (await folder.exists()) await folder.delete(recursive: true);
        await refreshLocal();
      });
  Future<void> selectTarget(String directory) => operation(() async {
    final root = await _installationRoot(directory);
    await settings.set('steamPath', root);
    if (await File(p.join(root, 'steam.exe')).exists()) await library.scan();
    await refreshLocal();
  });

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}

Future<void> _writeBytes(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  final temporary = File(
    '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

Future<SteamClientInstallation> inspectInstallation(String root) async {
  if (root.isEmpty) return SteamClientInstallation(root: root);
  final package = Directory(p.join(root, 'package'));
  if (!await package.exists()) return SteamClientInstallation(root: root);
  final files = await package
      .list(followLinks: false)
      .where(
        (v) =>
            v is File &&
            RegExp(
              r'^steam_client_(?:publicbeta_)?win(?:32|64)\.(installed|manifest)$',
            ).hasMatch(p.basename(v.path)),
      )
      .cast<File>()
      .toList();
  final candidates = files.where((v) => v.path.endsWith('.installed')).toList();
  final ordered = (candidates.isEmpty ? files : candidates)
      .map((file) async => (file: file, modified: await file.lastModified()))
      .toList();
  final stamped = <({File file, DateTime modified})>[];
  for (final future in ordered) {
    stamped.add(await future);
  }
  stamped.sort((a, b) => b.modified.compareTo(a.modified));
  for (final item in stamped) {
    final base = p.basename(item.file.path);
    final match = RegExp(r'win(32|64)').firstMatch(base);
    if (match == null) continue;
    final arch = 'win${match[1]}';
    final manifest = File(
      p.join(
        package.path,
        base.replaceFirst(RegExp(r'\.(installed|manifest)$'), '.manifest'),
      ),
    );
    if (!await manifest.exists()) continue;
    final text = await manifest.readAsString();
    final value = RegExp(
      r'"version"\s+"(\d{9,10})"',
    ).firstMatch(text)?.group(1);
    if (value != null) {
      return SteamClientInstallation(
        root: root,
        arch:
            RegExp(r'^\s*"?(win32|win64)"?\s*\{').firstMatch(text)?.group(1) ??
            arch,
        build: value,
        indexPath: item.file.path.endsWith('.installed')
            ? item.file.path
            : null,
      );
    }
  }
  return SteamClientInstallation(root: root);
}

bool validSteamHistoryDates(String from, String to) {
  for (final value in [from, to]) {
    if (value.isEmpty) continue;
    if (!RegExp(r'^\d{8}$').hasMatch(value)) return false;
    final year = int.parse(value.substring(0, 4)),
        month = int.parse(value.substring(4, 6)),
        day = int.parse(value.substring(6));
    final date = DateTime.utc(year, month, day);
    if (year < 2003 ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      return false;
    }
  }
  return from.isEmpty || to.isEmpty || from.compareTo(to) <= 0;
}
