import 'package:flutter/foundation.dart';

import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../key_cache/key_cache_service.dart';
import '../manifests/manifest_source_service.dart';
import 'adapters/script_content_source.dart';
import 'adapters/subscription_content_source.dart';
import 'content_models.dart';

export 'content_models.dart';

class ContentImportSelection {
  const ContentImportSelection({
    this.luaSourceId,
    this.manifestSourceId,
    this.manifestExplicit = false,
  });

  final String? luaSourceId;
  final String? manifestSourceId;
  final bool manifestExplicit;
}

class ContentSourceRegistry extends ChangeNotifier {
  ContentSourceRegistry({
    required this.manifests,
    required this.keyCache,
    required this.settings,
  }) {
    manifests.addListener(notifyListeners);
    keyCache.addListener(notifyListeners);
    settings.addListener(notifyListeners);
  }

  final ManifestSourceService manifests;
  final KeyCacheService keyCache;
  final SettingsStore settings;
  final Map<String, ContentSourceTestResult> _tests = {};
  final Map<String, DateTime> _updated = {};

  Future<void> initialize() async {
    await manifests.initialize();
    await keyCache.load();
  }

  List<ContentSourceDefinition> get sources => [
    for (final value in keyCache.subscriptions)
      ContentSourceDefinition(
        id: 'subscription:${value.id}',
        name: value.name,
        kind: ContentSourceKind.subscription,
        capabilities: const {ContentCapability.lua},
        enabled: value.enabled,
        description: value.depotKeysUrl,
        lastUpdated: value.lastUpdated,
        configurationComplete:
            value.depotKeysUrl.isNotEmpty && value.tokenKeysUrl.isNotEmpty,
        lastTestSucceeded: _tests['subscription:${value.id}']?.success,
        lastTestMessage: _tests['subscription:${value.id}']?.message,
      ),
    for (final value in manifests.sources)
      ContentSourceDefinition(
        id: 'script:${value.id}',
        name: value.name,
        kind: ContentSourceKind.script,
        capabilities: value.capabilities,
        description: value.description,
        version: value.version,
        builtIn: value.builtIn,
        enabled: _scriptEnabled(value.id),
        configurationComplete: value.parameters
            .where((parameter) => parameter.required && !parameter.isAppId)
            .every(
              (parameter) =>
                  (manifests.configFor(value.id).values[parameter.key] ??
                          parameter.defaultValue)
                      .trim()
                      .isNotEmpty,
            ),
        lastUpdated: _updated['script:${value.id}'],
        lastTestSucceeded:
            _tests['script:${value.id}']?.success ??
            manifests.configFor(value.id).lastTestSucceeded,
        lastTestMessage:
            _tests['script:${value.id}']?.message ??
            manifests.configFor(value.id).lastTestMessage,
      ),
  ];

  bool _scriptEnabled(String id) {
    final disabled = settings.get<List<dynamic>>('disabledContentSources', []);
    return !disabled.contains('script:$id');
  }

  ContentSourceDefinition source(String id) => sources.firstWhere(
    (value) => value.id == id,
    orElse: () =>
        throw ArgumentError.value(id, 'sourceId', 'Unknown content source'),
  );

  List<ContentSourceDefinition> get keyCacheSources => sources
      .where((source) => source.kind == ContentSourceKind.subscription)
      .toList(growable: false);

  Future<void> loadKeyCacheSources() => keyCache.load();

  Future<KeyCacheData> readKeyCache(String sourceId) {
    final value = source(sourceId);
    if (value.kind != ContentSourceKind.subscription) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'The content source does not provide depot keys',
      );
    }
    return keyCache.readCache(_nativeId(sourceId));
  }

  String _nativeId(String id) => id.substring(id.indexOf(':') + 1);

  ContentImportSelection? importSelection() {
    final value = settings.get<Object?>('contentImportSelection', null);
    if (value is! Map) return null;
    final lua = value['luaSourceId'];
    final manifest = value['manifestSourceId'];
    return ContentImportSelection(
      luaSourceId: lua is String && lua.isNotEmpty ? lua : null,
      manifestSourceId: manifest is String && manifest.isNotEmpty
          ? manifest
          : null,
      manifestExplicit: value['manifestExplicit'] == true,
    );
  }

  Future<void> rememberImportSelection(ContentImportSelection selection) =>
      settings.set('contentImportSelection', {
        'luaSourceId': selection.luaSourceId,
        'manifestSourceId': selection.manifestSourceId,
        'manifestExplicit': selection.manifestExplicit,
      });

  Future<void> setEnabled(String id, bool enabled) async {
    final value = source(id);
    final nativeId = _nativeId(id);
    if (value.kind == ContentSourceKind.subscription) {
      final subscription = keyCache.subscriptions.firstWhere(
        (item) => item.id == nativeId,
      );
      await keyCache.upsert(subscription.copyWith(enabled: enabled));
    } else {
      final disabled = settings
          .get<List<dynamic>>('disabledContentSources', [])
          .whereType<String>()
          .toSet();
      enabled ? disabled.remove(id) : disabled.add(id);
      await settings.set('disabledContentSources', disabled.toList());
    }
  }

  Future<ContentSourceTestResult> testSource(
    String id, {
    TaskContext? task,
  }) async {
    final value = source(id);
    final nativeId = _nativeId(id);
    late ContentSourceTestResult result;
    if (value.kind == ContentSourceKind.script) {
      final tested = await manifests.testSource(nativeId, task: task);
      result = ContentSourceTestResult(
        success: tested.success,
        message: tested.message,
      );
    } else {
      try {
        await keyCache.update(nativeId, task: task);
        result = const ContentSourceTestResult(
          success: true,
          message: 'Subscription updated',
        );
      } on TaskCancelled {
        rethrow;
      } catch (error) {
        result = ContentSourceTestResult(success: false, message: '$error');
      }
    }
    _tests[id] = result;
    notifyListeners();
    return result;
  }

  Future<void> update(String id, {TaskContext? task}) async {
    final value = source(id);
    if (!value.enabled) throw StateError('This content source is disabled');
    final nativeId = _nativeId(id);
    if (value.kind == ContentSourceKind.subscription) {
      await keyCache.update(nativeId, task: task);
    } else {
      await manifests.initialize();
      _updated[id] = DateTime.now();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    final value = source(id);
    final nativeId = _nativeId(id);
    if (value.kind == ContentSourceKind.subscription) {
      await keyCache.remove(nativeId);
    } else {
      await manifests.removeScript(nativeId);
    }
    _tests.remove(id);
    _updated.remove(id);
    notifyListeners();
  }

  Future<ContentSourcePayload> fetch(
    String sourceId,
    int appId, {
    required Set<ContentCapability> requestedCapabilities,
    Set<int> dlcIds = const {},
    bool pinManifests = false,
    bool refreshMetadata = true,
    TaskContext? task,
  }) async {
    final value = source(sourceId);
    if (!value.enabled) throw StateError('This content source is disabled');
    if (!value.capabilities.containsAll(requestedCapabilities)) {
      throw StateError(
        'The source does not provide the requested capabilities',
      );
    }
    final nativeId = _nativeId(sourceId);
    if (value.kind == ContentSourceKind.script) {
      return ScriptContentSourceAdapter(manifests).fetch(
        nativeId,
        appId,
        requestedCapabilities: requestedCapabilities,
        task: task,
      );
    }
    return SubscriptionContentSourceAdapter(keyCache).fetch(
      nativeId,
      appId,
      dlcIds: dlcIds,
      pinManifests: pinManifests,
      refreshMetadata: refreshMetadata,
      task: task,
    );
  }

  @override
  void dispose() {
    manifests.removeListener(notifyListeners);
    keyCache.removeListener(notifyListeners);
    settings.removeListener(notifyListeners);
    super.dispose();
  }
}
