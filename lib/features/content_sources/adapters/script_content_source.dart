import '../../../core/task_center.dart';
import '../../manifests/manifest_source_service.dart';
import '../content_models.dart';

class ScriptContentSourceAdapter {
  const ScriptContentSourceAdapter(this.service);
  final ManifestSourceService service;

  Future<ContentSourcePayload> fetch(
    String id,
    int appId, {
    required Set<ContentCapability> requestedCapabilities,
    TaskContext? task,
  }) async {
    final result = await service.downloadContent(
      id,
      appId,
      requestedCapabilities: requestedCapabilities,
      task: task,
    );
    return ContentSourcePayload(
      artifacts: [
        for (final artifact in result.artifacts)
          ContentArtifact(
            filename: artifact.filename,
            bytes: artifact.bytes,
            sourceId: 'script:$id',
          ),
      ],
      pins: result.manifestPins,
      requestCodes: result.requestCodes,
      logs: result.logs,
    );
  }
}
