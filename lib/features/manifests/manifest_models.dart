import 'dart:typed_data';

import '../content_sources/content_models.dart';

export '../content_sources/content_models.dart' show ContentCapability;

enum ManifestParameterType { text, password, number, boolean }

class ManifestParameter {
  const ManifestParameter({
    required this.key,
    required this.label,
    this.type = ManifestParameterType.text,
    this.description = '',
    this.required = false,
    this.defaultValue = '',
  });

  final String key;
  final String label;
  final ManifestParameterType type;
  final String description;
  final bool required;
  final String defaultValue;
  bool get isSecret => type == ManifestParameterType.password;
  bool get isAppId => key.toLowerCase() == 'appid';
}

class ManifestSourceDefinition {
  const ManifestSourceDefinition({
    required this.id,
    required this.name,
    required this.script,
    this.description = '',
    this.homepage = '',
    this.author = '',
    this.version = '2.0.0',
    this.builtIn = false,
    this.parameters = const [],
    this.capabilities = const {ContentCapability.manifestFiles},
    this.hasCapabilityDeclaration = false,
  });

  final String id;
  final String name;
  final String script;
  final String description;
  final String homepage;
  final String author;
  final String version;
  final bool builtIn;
  final List<ManifestParameter> parameters;
  final Set<ContentCapability> capabilities;
  final bool hasCapabilityDeclaration;
}

class ManifestSourceConfig {
  const ManifestSourceConfig({
    this.values = const {},
    this.lastTestedAt,
    this.lastTestSucceeded,
    this.lastTestMessage,
  });
  final Map<String, String> values;
  final DateTime? lastTestedAt;
  final bool? lastTestSucceeded;
  final String? lastTestMessage;
}

class ManifestArtifact {
  const ManifestArtifact({
    required this.filename,
    required this.bytes,
    this.contentType = 'application/octet-stream',
    this.logs = const [],
  });
  final String filename;
  final Uint8List bytes;
  final String contentType;
  final List<String> logs;
}

class ManifestDownloadResult {
  const ManifestDownloadResult({
    this.artifacts = const [],
    this.manifestPins = const [],
    this.requestCodes = const [],
    this.logs = const [],
  });

  final List<ManifestArtifact> artifacts;
  final List<ManifestPin> manifestPins;
  final List<ManifestRequestCode> requestCodes;
  final List<String> logs;
}

class ManifestTestResult {
  const ManifestTestResult({
    required this.success,
    required this.message,
    this.errorKind,
    this.statusCode,
    this.logs = const [],
  });
  final bool success;
  final String message;
  final String? errorKind;
  final int? statusCode;
  final List<String> logs;
}

class ManifestSourceException implements Exception {
  const ManifestSourceException(this.kind, this.message, {this.statusCode});
  final String kind;
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

abstract interface class SecretValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
