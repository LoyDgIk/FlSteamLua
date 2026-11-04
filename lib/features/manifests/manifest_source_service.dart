import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../network/network_preferences.dart';
import '../content_sources/content_models.dart';
import 'encrypted_secret_store.dart';
import 'manifest_http_host.dart';
import 'manifest_models.dart';
import 'manifest_script_parser.dart';
import 'manifest_script_runner.dart';

export 'manifest_models.dart';

class ManifestSourceService extends ChangeNotifier {
  ManifestSourceService({
    required this.paths,
    this.settings,
    http.Client? client,
    SecretValueStore? secrets,
    ManifestScriptRunner? runner,
    Future<String> Function(String)? assetLoader,
  }) : _client =
           client ??
           (settings == null
               ? http.Client()
               : NetworkHttpClient(settings: settings)),
       _ownsClient = client == null,
       _secrets = secrets ?? EncryptedManifestSecretStore(paths),
       _runner = runner ?? const QuickJsManifestRunner(),
       _loadAsset = assetLoader ?? rootBundle.loadString;

  final AppPaths paths;
  final SettingsStore? settings;
  final http.Client _client;
  final bool _ownsClient;
  final SecretValueStore _secrets;
  final ManifestScriptRunner _runner;
  final Future<String> Function(String) _loadAsset;
  final Map<String, ManifestSourceDefinition> _sources = {};
  final Map<String, ManifestSourceConfig> _configs = {};
  List<ManifestSourceDefinition> get sources =>
      List.unmodifiable(_sources.values);
  Directory get scriptDirectory => paths.directory('data/manifest-scripts');

  Future<void> initialize() async {
    final definitions = <String, ManifestSourceDefinition>{};
    for (final name in ['luatools', 'ryuu', 'hubcap', 'manifesthub2']) {
      final script = await _loadAsset('assets/manifest_sources/$name.js');
      final definition = ManifestScriptParser.parse(script, builtIn: true);
      definitions[definition.id] = definition;
    }
    await scriptDirectory.create(recursive: true);
    await for (final file in scriptDirectory.list()) {
      if (file is! File || p.extension(file.path).toLowerCase() != '.js') {
        continue;
      }
      final definition = ManifestScriptParser.parse(await file.readAsString());
      final existing = definitions[definition.id];
      if (existing != null && !existing.builtIn) {
        throw FormatException('Duplicate manifest source ID: ${definition.id}');
      }
      definitions[definition.id] = existing?.builtIn == true
          ? ManifestSourceDefinition(
              id: definition.id,
              name: definition.name,
              script: definition.script,
              description: definition.description,
              homepage: definition.homepage,
              author: definition.author,
              version: definition.version,
              builtIn: true,
              parameters: definition.parameters,
              capabilities: definition.capabilities,
              hasCapabilityDeclaration: definition.hasCapabilityDeclaration,
            )
          : definition;
    }
    final file = File(paths.file('data/manifest-sources.json'));
    final configs = <String, ManifestSourceConfig>{};
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> ||
          json['version'] != 2 ||
          json['sources'] is! Map) {
        throw const FormatException('Invalid manifest source settings');
      }
      for (final entry in (json['sources'] as Map).entries) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        final values = Map<String, String>.from(value['values'] as Map? ?? {});
        final source = definitions[entry.key];
        if (source != null) {
          for (final parameter in source.parameters.where(
            (parameter) => parameter.isSecret,
          )) {
            final secret = await _secrets.read('${entry.key}.${parameter.key}');
            if (secret != null) values[parameter.key] = secret;
          }
        }
        configs['${entry.key}'] = ManifestSourceConfig(
          values: values,
          lastTestedAt: DateTime.tryParse(
            value['lastTestedAt'] as String? ?? '',
          ),
          lastTestSucceeded: value['lastTestSucceeded'] as bool?,
          lastTestMessage: value['lastTestMessage'] as String?,
        );
      }
    }
    _sources
      ..clear()
      ..addAll(definitions);
    _configs
      ..clear()
      ..addAll(configs);
    notifyListeners();
  }

  ManifestSourceConfig configFor(String sourceId) =>
      _configs[sourceId] ?? const ManifestSourceConfig();

  Future<void> saveConfig(String sourceId, Map<String, String> values) async {
    final source = _source(sourceId);
    final persisted = <String, String>{};
    for (final parameter in source.parameters.where(
      (parameter) => !parameter.isAppId,
    )) {
      final value = values[parameter.key] ?? parameter.defaultValue;
      if (parameter.isSecret) {
        if (value.isEmpty) {
          await _secrets.delete('$sourceId.${parameter.key}');
        } else {
          await _secrets.write('$sourceId.${parameter.key}', value);
        }
      }
      persisted[parameter.key] = value;
    }
    _configs[sourceId] = ManifestSourceConfig(
      values: Map.unmodifiable(persisted),
    );
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final data = <String, Object?>{};
    for (final entry in _configs.entries) {
      final source = _sources[entry.key];
      if (source == null) continue;
      final secretKeys = source.parameters
          .where((parameter) => parameter.isSecret)
          .map((parameter) => parameter.key)
          .toSet();
      data[entry.key] = {
        'values': {
          for (final value in entry.value.values.entries)
            if (!secretKeys.contains(value.key)) value.key: value.value,
        },
        'lastTestedAt': entry.value.lastTestedAt?.toIso8601String(),
        'lastTestSucceeded': entry.value.lastTestSucceeded,
        'lastTestMessage': entry.value.lastTestMessage,
      };
    }
    await paths.directory('data').create(recursive: true);
    final temp = File(paths.file('data/manifest-sources.json.tmp'));
    await temp.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'version': 2, 'sources': data}),
      flush: true,
    );
    await temp.rename(paths.file('data/manifest-sources.json'));
  }

  Future<ManifestTestResult> testSource(
    String sourceId, {
    Map<String, String>? values,
    TaskContext? task,
  }) async {
    final source = _source(sourceId);
    final selected = values ?? configFor(sourceId).values;
    final logs = <String>[];
    late ManifestTestResult result;
    try {
      final params = _parameters(source, selected);
      if (!RegExp(r'\bfunction\s+test\s*\(').hasMatch(source.script)) {
        result = const ManifestTestResult(
          success: false,
          message: 'This source does not provide a connection test',
          errorKind: 'not_configured',
        );
      } else {
        final output = await _invoke(
          source,
          'test',
          params,
          selected,
          logs,
          task,
        );
        if (output is! Map) {
          throw const ManifestSourceException(
            'invalid_response',
            'Source test must return an object',
          );
        }
        final ok = output['ok'] == true || output['success'] == true;
        result = ManifestTestResult(
          success: ok,
          message: _redact(
            '${output['message'] ?? output['error'] ?? (ok ? 'Connection succeeded' : 'Connection failed')}',
            selected,
            source,
          ),
          errorKind: output['errorKind'] as String?,
          statusCode: (output['statusCode'] as num?)?.toInt(),
          logs: List.unmodifiable(logs),
        );
      }
    } on TaskCancelled {
      rethrow;
    } catch (error) {
      task?.checkCancelled();
      result = ManifestTestResult(
        success: false,
        message: _redact('$error', selected, source),
        errorKind: error is ManifestSourceException
            ? error.kind
            : 'script_error',
        statusCode: error is ManifestSourceException ? error.statusCode : null,
        logs: List.unmodifiable(logs),
      );
    }
    if (values == null) {
      _configs[sourceId] = ManifestSourceConfig(
        values: selected,
        lastTestedAt: DateTime.now(),
        lastTestSucceeded: result.success,
        lastTestMessage: result.message,
      );
      await _save();
      notifyListeners();
    }
    return result;
  }

  Future<ManifestDownloadResult> downloadContent(
    String sourceId,
    int appId, {
    TaskContext? task,
    Map<String, String>? values,
    Set<ContentCapability>? requestedCapabilities,
  }) async {
    if (appId <= 0) throw ArgumentError.value(appId, 'appId');
    final source = _source(sourceId);
    final selected = values ?? configFor(sourceId).values;
    final params = _parameters(source, selected)
      ..['appid'] = appId
      ..['requestedCapabilities'] = requestedCapabilities
          ?.map((value) => value.name)
          .toList();
    final logs = <String>[];
    task?.report('Connecting to ${source.name}');
    try {
      final output = await _invoke(
        source,
        'download',
        params,
        selected,
        logs,
        task,
      );
      task?.checkCancelled();
      if (output is! Map) {
        throw const ManifestSourceException(
          'invalid_response',
          'Source download must return an object',
        );
      }
      if (output['error'] != null) {
        throw ManifestSourceException(
          output['errorKind'] as String? ?? 'unknown',
          _redact('${output['error']}', selected, source),
          statusCode: (output['statusCode'] as num?)?.toInt(),
        );
      }
      final artifacts = <ManifestArtifact>[];
      if (output['filename'] != null || output['content'] != null) {
        artifacts.add(_decodeArtifact(output, logs));
      }
      if (output['artifacts'] != null) {
        if (output['artifacts'] is! List) {
          throw const FormatException('Source artifacts must be a list');
        }
        for (final value in output['artifacts'] as List) {
          if (value is! Map) {
            throw const FormatException('Invalid source artifact');
          }
          artifacts.add(_decodeArtifact(value, logs));
        }
      }
      final pins = <ManifestPin>[];
      if (output['manifestPins'] != null) {
        if (output['manifestPins'] is! List) {
          throw const FormatException('Source manifestPins must be a list');
        }
        for (final value in output['manifestPins'] as List) {
          if (value is! Map ||
              value['depotId'] is! int ||
              (value['depotId'] as int) <= 0 ||
              value['manifestId'] is! String) {
            throw const FormatException('Invalid manifest pin');
          }
          final id = value['manifestId'] as String;
          if (!RegExp(r'^[1-9]\d*$').hasMatch(id) ||
              BigInt.parse(id) > (BigInt.one << 64) - BigInt.one) {
            throw const FormatException('Invalid manifest ID');
          }
          pins.add(
            ManifestPin(
              depotId: value['depotId'] as int,
              manifestId: id,
              sourceId: 'script:$sourceId',
            ),
          );
        }
      }
      final requestCodes = <ManifestRequestCode>[];
      if (output['manifestRequestCodes'] != null) {
        if (output['manifestRequestCodes'] is! List) {
          throw const FormatException(
            'Source manifestRequestCodes must be a list',
          );
        }
        for (final value in output['manifestRequestCodes'] as List) {
          if (value is! Map ||
              value['depotId'] is! int ||
              (value['depotId'] as int) <= 0 ||
              value['manifestId'] is! String ||
              value['requestCode'] is! String) {
            throw const FormatException('Invalid manifest request code');
          }
          final manifestId = value['manifestId'] as String;
          final requestCode = value['requestCode'] as String;
          if (!_isUint64(manifestId) || !_isUint64(requestCode)) {
            throw const FormatException('Invalid manifest request code');
          }
          requestCodes.add(
            ManifestRequestCode(
              depotId: value['depotId'] as int,
              manifestId: manifestId,
              requestCode: requestCode,
              sourceId: 'script:$sourceId',
            ),
          );
        }
      }
      if (artifacts.isEmpty && pins.isEmpty && requestCodes.isEmpty) {
        throw const FormatException('Source returned no content');
      }
      return ManifestDownloadResult(
        artifacts: List.unmodifiable(artifacts),
        manifestPins: List.unmodifiable(pins),
        requestCodes: List.unmodifiable(requestCodes),
        logs: List.unmodifiable(logs),
      );
    } on TaskCancelled {
      rethrow;
    } catch (error) {
      task?.checkCancelled();
      if (error is ManifestSourceException) {
        throw ManifestSourceException(
          error.kind,
          _redact(error.message, selected, source),
          statusCode: error.statusCode,
        );
      }
      throw ManifestSourceException(
        'script_error',
        _redact('$error', selected, source),
      );
    }
  }

  ManifestArtifact _decodeArtifact(Map output, List<String> logs) {
    final filename = output['filename'];
    final content = output['content'];
    if (filename is! String ||
        content is! String ||
        content.isEmpty ||
        filename != p.basename(filename) ||
        filename.contains('\\') ||
        filename.contains('/') ||
        RegExp(r'[<>:"|?*\x00-\x1f]').hasMatch(filename) ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
          caseSensitive: false,
        ).hasMatch(filename) ||
        !{
          '.lua',
          '.bin',
          '.manifest',
          '.zip',
          '.7z',
          '.rar',
        }.contains(p.extension(filename).toLowerCase())) {
      throw const ManifestSourceException(
        'invalid_response',
        'Source returned an invalid artifact',
      );
    }
    final encoding = output['encoding'] ?? 'text';
    if (encoding != 'text' && encoding != 'base64') {
      throw const FormatException(
        'Source returned an unknown content encoding',
      );
    }
    final bytes = encoding == 'base64'
        ? base64Decode(content)
        : Uint8List.fromList(utf8.encode(content));
    if (bytes.isEmpty || bytes.length > 128 * 1024 * 1024) {
      throw const FormatException('Source artifact is empty or too large');
    }
    return ManifestArtifact(
      filename: filename,
      bytes: bytes,
      contentType:
          output['contentType'] as String? ?? 'application/octet-stream',
      logs: List.unmodifiable(logs),
    );
  }

  Future<ManifestArtifact> download(
    String sourceId,
    int appId, {
    TaskContext? task,
    Map<String, String>? values,
  }) async {
    final result = await downloadContent(
      sourceId,
      appId,
      task: task,
      values: values,
    );
    if (result.artifacts.length != 1) {
      throw const FormatException(
        'This operation requires one downloadable file',
      );
    }
    return result.artifacts.single;
  }

  Future<void> removeScript(String sourceId) async {
    final source = _source(sourceId);
    if (source.builtIn) throw StateError('Built-in sources cannot be deleted');
    final file = File(p.join(scriptDirectory.path, '$sourceId.js'));
    await file.delete();
    for (final parameter in source.parameters.where(
      (value) => value.isSecret,
    )) {
      await _secrets.delete('$sourceId.${parameter.key}');
    }
    _sources.remove(sourceId);
    _configs.remove(sourceId);
    await _save();
    notifyListeners();
  }

  Future<File> downloadToFile(
    String sourceId,
    int appId, {
    TaskContext? task,
    Map<String, String>? values,
  }) async {
    final artifact = await download(
      sourceId,
      appId,
      task: task,
      values: values,
    );
    final directory = paths.directory(
      'downloads/manifests/${DateTime.now().microsecondsSinceEpoch}-$appId',
    );
    await directory.create(recursive: true);
    task?.checkCancelled();
    return File(
      p.join(directory.path, artifact.filename),
    ).writeAsBytes(artifact.bytes, flush: true);
  }

  Future<int> clearDownloadedManifests(int appId) async {
    if (appId <= 0) throw const FormatException('Invalid AppID');
    final root = paths.directory('downloads/manifests');
    if (!await root.exists()) return 0;
    final suffix = '-$appId';
    var removed = 0;
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory && p.basename(entity.path).endsWith(suffix)) {
        await entity.delete(recursive: true);
        removed++;
      }
    }
    return removed;
  }

  Future<void> importScript(File file) async {
    final script = await file.readAsString();
    final definition = ManifestScriptParser.parse(script);
    if (_sources.containsKey(definition.id)) {
      throw const FormatException('A source with this ID already exists');
    }
    await scriptDirectory.create(recursive: true);
    await File(
      p.join(scriptDirectory.path, '${definition.id}.js'),
    ).writeAsString(script, flush: true);
    _sources[definition.id] = definition;
    notifyListeners();
  }

  String scriptFor(String sourceId) => _source(sourceId).script;

  File scriptFileFor(String sourceId) =>
      File(p.join(scriptDirectory.path, '$sourceId.js'));

  Future<void> saveScript(String sourceId, String script) async {
    final existing = _source(sourceId);
    final definition = ManifestScriptParser.parse(script);
    if (definition.id != sourceId) {
      throw FormatException(
        'Script ID changed from $sourceId to ${definition.id}',
      );
    }
    await scriptDirectory.create(recursive: true);
    await scriptFileFor(sourceId).writeAsString(script, flush: true);
    _sources[sourceId] = ManifestSourceDefinition(
      id: definition.id,
      name: definition.name,
      script: definition.script,
      description: definition.description,
      homepage: definition.homepage,
      author: definition.author,
      version: definition.version,
      builtIn: existing.builtIn,
      parameters: definition.parameters,
      capabilities: definition.capabilities,
      hasCapabilityDeclaration: definition.hasCapabilityDeclaration,
    );
    notifyListeners();
  }

  Future<void> restoreBuiltInScript(String sourceId) async {
    final source = _source(sourceId);
    if (!source.builtIn) {
      throw StateError('Only built-in sources can be restored');
    }
    final file = scriptFileFor(sourceId);
    if (await file.exists()) await file.delete();
    await initialize();
  }

  Future<Object?> _invoke(
    ManifestSourceDefinition source,
    String function,
    Map<String, Object?> params,
    Map<String, String> values,
    List<String> logs,
    TaskContext? task,
  ) {
    final host = ManifestHttpHost(_client);
    return _runner.invoke(
      script: source.script,
      function: function,
      params: params,
      task: task,
      request: (request) => host.request(request, task: task),
      log: (message) {
        final safe = _redact(message, values, source);
        logs.add(safe);
        task?.report(safe);
      },
    );
  }

  Map<String, Object?> _parameters(
    ManifestSourceDefinition source,
    Map<String, String> values,
  ) {
    final result = <String, Object?>{};
    for (final parameter in source.parameters.where(
      (parameter) => !parameter.isAppId,
    )) {
      final value = values[parameter.key] ?? parameter.defaultValue;
      if (parameter.required && value.trim().isEmpty) {
        throw ManifestSourceException(
          parameter.isSecret ? 'missing_key' : 'not_configured',
          'Missing ${parameter.label}',
        );
      }
      result[parameter.key] = switch (parameter.type) {
        ManifestParameterType.number =>
          value.isEmpty
              ? null
              : num.tryParse(value) ??
                    (throw FormatException(
                      'Invalid number: ${parameter.label}',
                    )),
        ManifestParameterType.boolean =>
          value.toLowerCase() == 'true' || value == '1',
        _ => value,
      };
    }
    return result;
  }

  ManifestSourceDefinition _source(String sourceId) =>
      _sources[sourceId] ??
      (throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Unknown manifest source',
      ));

  String _redact(
    String message,
    Map<String, String> values,
    ManifestSourceDefinition source,
  ) {
    for (final parameter in source.parameters.where(
      (parameter) => parameter.isSecret,
    )) {
      final value = values[parameter.key];
      if (value != null && value.isNotEmpty) {
        message = message
            .replaceAll(value, '[redacted]')
            .replaceAll(Uri.encodeComponent(value), '[redacted]');
      }
    }
    return message;
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
    super.dispose();
  }
}

bool _isUint64(String value) {
  if (!RegExp(r'^[1-9]\d*$').hasMatch(value)) return false;
  return BigInt.tryParse(value) != null &&
      BigInt.parse(value) <= (BigInt.one << 64) - BigInt.one;
}
