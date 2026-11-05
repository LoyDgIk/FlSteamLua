import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_paths.dart';
import '../core/settings_store.dart';
import '../core/task_center.dart';
import '../features/achievements/achievement_service.dart';
import '../features/cloud/cloud_service.dart';
import '../features/content_sources/content_import_service.dart';
import '../features/content_sources/content_resolver.dart';
import '../features/content_sources/content_source_registry.dart';
import '../features/kernel/kernel_service.dart';
import '../features/key_cache/key_cache_service.dart';
import '../features/lan_transfer/lan_transfer_service.dart';
import '../features/library/library_service.dart';
import '../features/manifests/manifest_source_service.dart';
import '../features/preferences/preferences_controller.dart';
import '../features/steam_protocol/steam_protocol_service.dart';
import '../features/store/store_service.dart';
import '../features/tools/tools_page.dart';
import 'trainer_lifecycle.dart';
import '../ui/localization.dart';

final appServicesProvider = Provider<AppServices>((ref) {
  throw StateError('AppServices must be installed at the application root');
});

class AppServices extends ChangeNotifier {
  AppServices(this.paths) {
    settings = SettingsStore(paths);
    store = StoreService(settings: settings);
    library = LibraryService(paths: paths, settings: settings);
    manifests = ManifestSourceService(paths: paths, settings: settings);
    keyCache = KeyCacheService(paths: paths, settings: settings);
    contentSources = ContentSourceRegistry(
      manifests: manifests,
      keyCache: keyCache,
      settings: settings,
    );
    kernel = KernelService(
      paths: paths,
      settings: settings,
      manifestCodeSources: () => contentSources.sources
          .where(
            (source) =>
                source.enabled &&
                source.capabilities.contains(
                  ContentCapability.manifestRequestCodes,
                ),
          )
          .toList(),
      resolveManifestRequestCode:
          ({
            required sourceId,
            required appId,
            required depotId,
            required gid,
          }) async {
            final payload = await contentSources.fetch(
              sourceId,
              appId,
              requestedCapabilities: {ContentCapability.manifestRequestCodes},
              manifestRequest: (depotId: depotId, manifestId: gid),
            );
            return payload.requestCodes
                .where(
                  (value) =>
                      value.depotId == depotId && value.manifestId == gid,
                )
                .firstOrNull
                ?.requestCode;
          },
    );
    contentResolver = ContentResolver(contentSources);
    contentImporter = ContentImportService(library: library);
    cloud = CloudService(paths: paths, settings: settings);
    steam = SteamProtocolService(paths: paths, settings: settings);
    lanTransfer = LanTransferService(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
    );
    tools = ToolsController(
      library: library,
      appPaths: paths,
      settings: settings,
      tasks: tasks,
      kernel: kernel,
    );
    preferences = PreferencesController(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
      keyCacheUpdateDue: () => tasks.run(
        localizationsFor(settings.language).updateKeySubscriptions,
        (task) => keyCache.updateDue(task: task),
      ),
    );
    settings.addListener(_settingsChanged);
    _trainerLifecycle = TrainerLifecycle(
      library: library,
      trainers: tools.trainers,
      tasks: tasks,
      settings: settings,
    );
  }

  final AppPaths paths;
  late final SettingsStore settings;
  late final LibraryService library;
  late final ManifestSourceService manifests;
  late final KernelService kernel;
  late final KeyCacheService keyCache;
  late final ContentSourceRegistry contentSources;
  late final ContentResolver contentResolver;
  late final ContentImportService contentImporter;
  late final CloudService cloud;
  late final SteamProtocolService steam;
  late final LanTransferService lanTransfer;
  late final ToolsController tools;
  late final TrainerLifecycle _trainerLifecycle;
  late final PreferencesController preferences;
  final TaskCenter tasks = TaskCenter();
  late final StoreService store;
  final AchievementService achievements = AchievementService();
  bool initialized = false;
  final List<String> startupErrors = [];

  void _settingsChanged() {
    paths.configureStorageLocations(settings.storageLocations);
    store.language = steamLanguageFor(settings.language);
    final region = settings
        .get<String>('storeCountryCode', 'CN')
        .trim()
        .toUpperCase();
    if (RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
      store.countryCode = region;
    }
  }

  Future<void> initialize() async {
    await paths.initialize();
    try {
      await settings.load();
    } catch (error) {
      startupErrors.add('Settings: $error');
    }
    paths.configureStorageLocations(settings.storageLocations);
    await paths.initialize();
    try {
      await kernel.syncManifestConfiguration();
    } catch (error) {
      startupErrors.add('Kernel manifest proxy: $error');
    }
    try {
      await library.scan();
      if (settings.steamPath.isEmpty && library.steamPath != null) {
        await settings.set('steamPath', library.steamPath!);
      }
    } catch (error) {
      startupErrors.add('Steam: $error');
    }
    try {
      await manifests.initialize();
    } catch (error) {
      startupErrors.add('Manifest sources: $error');
    }
    try {
      await tools.initialize();
    } catch (error) {
      startupErrors.add('Tools: $error');
    }
    try {
      await keyCache.load();
    } catch (error) {
      startupErrors.add('Key subscriptions: $error');
    }
    try {
      await lanTransfer.initializeIfReceiving();
    } catch (error) {
      startupErrors.add('LAN transfer: $error');
    }
    await library.startProcessMonitoring();
    try {
      await preferences.initialize();
    } catch (error) {
      startupErrors.add('Preferences: $error');
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> setStorageLocation(String name, String? path) async {
    final previous = settings.storageLocations[name];
    await settings.setStorageLocation(name, path);
    try {
      paths.configureStorageLocations(settings.storageLocations);
      await paths.initialize();
    } catch (_) {
      await settings.setStorageLocation(name, previous);
      paths.configureStorageLocations(settings.storageLocations);
      rethrow;
    }
  }

  Future<void> shutdown() async {
    tasks.requestCancellation();
    await preferences.shutdown();
    await library.stopProcessMonitoring();
    await _trainerLifecycle.stop();
    await tools.shutdown();
    await lanTransfer.shutdown();
    await tasks.cancelAndWait();
    await achievements.close();
  }

  @override
  void dispose() {
    preferences.dispose();
    _trainerLifecycle.detach();
    settings.removeListener(_settingsChanged);
    tools.dispose();
    lanTransfer.dispose();
    library.dispose();
    achievements.dispose();
    contentSources.dispose();
    manifests.dispose();
    kernel.dispose();
    keyCache.dispose();
    cloud.dispose();
    steam.dispose();
    store.dispose();
    tasks.dispose();
    settings.dispose();
    super.dispose();
  }
}
