import 'dart:convert';

import '../../../core/task_center.dart';
import '../../key_cache/key_cache_service.dart';
import '../content_models.dart';

class SubscriptionContentSourceAdapter {
  const SubscriptionContentSourceAdapter(this.service);
  final KeyCacheService service;

  Future<ContentSourcePayload> fetch(
    String id,
    int appId, {
    Set<int> dlcIds = const {},
    bool pinManifests = false,
    bool refreshMetadata = true,
    TaskContext? task,
  }) async {
    if (refreshMetadata) {
      final cached = await service.readCache(id);
      if (cached.depotKeys.isEmpty && cached.appTokens.isEmpty) {
        await service.update(id, task: task);
      }
      await service.refreshAppMetadata(
        appId,
        sourceId: id,
        dlcIds: dlcIds,
        task: task,
      );
    }
    task?.checkCancelled();
    final preview = await service.generateOffline(
      appId,
      sourceId: id,
      dlcIds: dlcIds,
      pinManifests: pinManifests,
    );
    return ContentSourcePayload(
      artifacts: [
        ContentArtifact(
          filename: '$appId.lua',
          bytes: utf8.encode(preview.lua),
          capability: ContentCapability.lua,
          sourceId: 'subscription:$id',
        ),
      ],
      logs: [
        if (preview.missingDepotIds.isNotEmpty)
          'Missing depot keys: ${preview.missingDepotIds.join(', ')}',
        if (preview.skippedDlcIds.isNotEmpty)
          'Skipped DLC: ${preview.skippedDlcIds.join(', ')}',
      ],
    );
  }
}
