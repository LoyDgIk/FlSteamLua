enum ContentSourceKind { script, subscription, local }

enum ContentCapability { lua, manifestIds, manifestFiles, manifestRequestCodes }

class ContentSourceDefinition {
  const ContentSourceDefinition({
    required this.id,
    required this.name,
    required this.kind,
    required this.capabilities,
    this.description = '',
    this.version = '',
    this.builtIn = false,
    this.enabled = true,
    this.configurationComplete = true,
    this.lastUpdated,
    this.lastTestSucceeded,
    this.lastTestMessage,
  });

  final String id;
  final String name;
  final ContentSourceKind kind;
  final Set<ContentCapability> capabilities;
  final String description;
  final String version;
  final bool builtIn;
  final bool enabled;
  final bool configurationComplete;
  final DateTime? lastUpdated;
  final bool? lastTestSucceeded;
  final String? lastTestMessage;

  bool get providesManifests =>
      capabilities.contains(ContentCapability.manifestIds) ||
      capabilities.contains(ContentCapability.manifestFiles) ||
      capabilities.contains(ContentCapability.manifestRequestCodes);
  bool get hasError => !configurationComplete || lastTestSucceeded == false;
}

class ManifestPin {
  const ManifestPin({
    required this.depotId,
    required this.manifestId,
    required this.sourceId,
  });

  final int depotId;
  final String manifestId;
  final String sourceId;
}

class ManifestRequestCode {
  const ManifestRequestCode({
    required this.depotId,
    required this.manifestId,
    required this.requestCode,
    required this.sourceId,
  });

  final int depotId;
  final String manifestId;
  final String requestCode;
  final String sourceId;
}

class ContentArtifact {
  const ContentArtifact({
    required this.filename,
    required this.bytes,
    this.capability,
    this.sourceId = '',
    this.depotId,
    this.manifestId,
  });

  final String filename;
  final List<int> bytes;
  final ContentCapability? capability;
  final String sourceId;
  final int? depotId;
  final String? manifestId;
}

class ContentSourcePayload {
  const ContentSourcePayload({
    this.artifacts = const [],
    this.pins = const [],
    this.requestCodes = const [],
    this.logs = const [],
  });

  final List<ContentArtifact> artifacts;
  final List<ManifestPin> pins;
  final List<ManifestRequestCode> requestCodes;
  final List<String> logs;
}

class ContentBundle {
  const ContentBundle({
    required this.appId,
    this.lua,
    this.manifestPins = const [],
    this.manifestFiles = const [],
    this.logs = const [],
  });

  final int appId;
  final ContentArtifact? lua;
  final List<ManifestPin> manifestPins;
  final List<ContentArtifact> manifestFiles;
  final List<String> logs;
}

class ContentPlan {
  const ContentPlan({
    required this.luaSourceId,
    this.manifestSourceId,
    this.dlcIds = const {},
  });

  final String luaSourceId;
  final String? manifestSourceId;
  final Set<int> dlcIds;
}

class ContentSourceTestResult {
  const ContentSourceTestResult({required this.success, required this.message});
  final bool success;
  final String message;
}
