# Subscription content adapter

Subscriptions are one content-source implementation. They provide Lua and do not claim standalone manifest-file capability.

`KeyCacheService.readCache(sourceId)`, `refreshAppMetadata(appId, sourceId: ...)` and `generateOffline(appId, sourceId: ...)` use an explicit subscription ID. Cache and application metadata are isolated per subscription. There is no global current or activated subscription.

The unified content-source page owns editing, testing, updating, enabling and deleting subscriptions. Import plans choose sources per operation. Offline generation uses previously prepared metadata and does not silently fetch it.
