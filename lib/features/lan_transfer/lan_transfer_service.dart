import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../library/kv1.dart';
import '../library/library_service.dart';
import 'lan_transfer_engine_client.dart';
import 'lan_transfer_models.dart';

class LanTransferService extends ChangeNotifier {
  LanTransferService({
    required this.paths,
    required this.settings,
    required this.library,
    required this.tasks,
    LanTransferEngineTransport? engine,
  }) : _engine = engine ?? LanTransferEngineClient();

  final AppPaths paths;
  final SettingsStore settings;
  final LibraryService library;
  final TaskCenter tasks;

  final LanTransferEngineTransport _engine;
  StreamSubscription<LanTransferEngineEvent>? _engineEvents;
  final List<LanPeer> _peers = [];
  final List<TransferSession> _sessions = [];
  final List<LanTransferOffer> _offers = [];
  final Map<String, TaskContext> _sessionTasks = {};
  bool _initialized = false;
  bool _discovering = false;
  bool _receiveEnabled = false;
  bool _disposed = false;
  bool _shuttingDown = false;
  String? _networkError;
  String _fingerprint = '';
  String? _configuredLuaRoot;

  bool get initialized => _initialized;
  bool get receiveEnabled => _receiveEnabled;
  bool get isDiscovering => _discovering;
  String? get networkError => _networkError;
  String get fingerprint => _fingerprint;
  List<LanPeer> get peers => List.unmodifiable(_peers);
  List<TransferSession> get sessions {
    final values = [..._sessions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(values);
  }

  List<LanTransferOffer> get offers => List.unmodifiable(_offers);
  List<TransferSession> get activeSessions => List.unmodifiable(
    _sessions.where(
      (session) => switch (session.status) {
        TransferSessionStatus.preparing ||
        TransferSessionStatus.waitingForApproval ||
        TransferSessionStatus.transferring ||
        TransferSessionStatus.paused ||
        TransferSessionStatus.verifying ||
        TransferSessionStatus.waitingForSteamExit ||
        TransferSessionStatus.committing => true,
        _ => false,
      },
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;
    await paths.initialize();
    _engineEvents ??= _engine.events.listen(_engineEvent);
    await _engine.start(paths.file(p.join('data', 'lan_transfer_engine')));
    await _configure();
    _initialized = true;
    if (settings.lanTransferEnabled) {
      await ensureStarted();
    }
    _emit();
  }

  Future<void> ensureStarted() async {
    if (!_initialized) await initialize();
    await _engine.request('discovery.start', const {});
    _discovering = true;
    _emit();
  }

  Future<void> setDisplayName(String value) async {
    if (!_initialized) await initialize();
    await settings.set('lanTransferDisplayName', value.trim());
    await _configure();
  }

  Future<void> setReceiveEnabled(bool enabled, {bool persist = true}) async {
    if (!_initialized) await initialize();
    if (persist) await settings.set('lanTransferEnabled', enabled);
    _receiveEnabled = enabled;
    await _configure();
    if (enabled) {
      await ensureStarted();
    } else {
      _discovering = false;
    }
    _emit();
  }

  Future<LanTransferPlanSummary> prepare(
    GameEntry game, {
    TaskContext? task,
  }) async {
    if (!_initialized) await initialize();
    task?.report(localizationsFor(settings.language).lanPreparing);
    final result = await _engine.request('plan.prepare', {
      'appId': game.appId,
      'name': game.name,
      'installPath': game.installPath ?? '',
      'libraryPath': game.libraryPath ?? '',
      'luaPath': game.luaPath,
      'coverUrl': game.coverUrl,
      'sizeOnDisk': game.sizeOnDisk,
    }, timeout: const Duration(minutes: 5));
    return LanTransferPlanSummary.fromJson(_map(result));
  }

  Future<void> discardPlan(String planId) async {
    await _engine.request('plan.discard', {'planId': planId});
  }

  Future<TransferSession> send(
    LanPeer peer,
    LanTransferPlanSummary plan,
    Set<String> selectedOptionalIds,
  ) async {
    if (!_initialized) await initialize();
    final result = await _engine.request('send.start', {
      'planId': plan.planId,
      'peerId': peer.fingerprint,
      'selectedOptionalIds': selectedOptionalIds.toList(),
    });
    final session = transferSessionFromEngine(_map(result));
    _upsertSession(session);
    return session;
  }

  Future<void> pause(String sessionId) async {
    final result = await _engine.request('session.pause', {
      'sessionId': sessionId,
    });
    _upsertSession(transferSessionFromEngine(_map(result)));
  }

  Future<void> resume(String sessionId) async {
    final result = await _engine.request('session.resume', {
      'sessionId': sessionId,
    });
    _upsertSession(transferSessionFromEngine(_map(result)));
  }

  Future<void> cancel(String sessionId) async {
    final result = await _engine.request('session.cancel', {
      'sessionId': sessionId,
    });
    _upsertSession(transferSessionFromEngine(_map(result)));
  }

  Future<LanPeer> addManualPeer(
    String address, {
    int port = lanTransferPort,
  }) async {
    if (!_initialized) await initialize();
    final result = await _engine.request('peer.probe', {
      'address': address,
      'port': port,
    });
    final peer = LanTransferPeerJson.fromEngineJson(_map(result));
    _upsertPeer(peer);
    return peer;
  }

  Future<void> acceptOffer(
    LanTransferOffer offer, {
    required String targetLibraryRoot,
    required bool remember,
  }) async {
    await _engine.request('offer.accept', {
      'sessionId': offer.sessionId,
      'targetLibrary': targetLibraryRoot,
      'luaRoot': _configuredLuaRoot ?? settings.steamPath,
      'remember': remember,
    });
    _offers.removeWhere((item) => item.sessionId == offer.sessionId);
    _emit();
  }

  Future<void> rejectOffer(LanTransferOffer offer, {String reason = ''}) async {
    await _engine.request('offer.reject', {
      'sessionId': offer.sessionId,
      'reason': reason,
    });
    _offers.removeWhere((item) => item.sessionId == offer.sessionId);
    _emit();
  }

  Future<void> forgetPeer(String fingerprint) async {
    await _engine.request('trust.set', {
      'remove': true,
      'fingerprint': fingerprint,
    });
    _peers.removeWhere((peer) => peer.fingerprint == fingerprint);
    _emit();
  }

  Future<({int bytes, int files})> chunkCacheStats() async {
    final result = _map(await _engine.request('cache.stats', const {}));
    return (
      bytes: (result['bytes'] as num?)?.toInt() ?? 0,
      files: (result['files'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> clearChunkCache() async {
    await _engine.request('cache.clear', const {});
    _emit();
  }

  Future<List<String>> libraryTargets() async {
    final steamRoot = settings.steamPath.trim();
    if (steamRoot.isEmpty) return const [];
    final roots = <String>[p.normalize(p.absolute(steamRoot))];
    final file = File(p.join(steamRoot, 'steamapps', 'libraryfolders.vdf'));
    if (await file.exists()) {
      try {
        final parsed = Kv1.parse(await file.readAsString());
        final listing = _mapValue(parsed, 'libraryfolders') ?? parsed;
        for (final entry in listing.entries) {
          if (int.tryParse(entry.key) == null) continue;
          final value = entry.value;
          final path = value is Map
              ? _stringValue(value, 'path')
              : value.toString();
          if (path.isNotEmpty) roots.add(p.normalize(p.absolute(path)));
        }
      } on FormatException {
        // Keep the primary Steam library available.
      }
    }
    return roots
        .where((root) => Directory(p.join(root, 'steamapps')).existsSync())
        .toSet()
        .toList(growable: false);
  }

  Future<void> shutdown() async {
    _shuttingDown = true;
    await _engine.close();
  }

  Future<void> _configure() async {
    final directories = await library.contentDirectories();
    _configuredLuaRoot = directories.lua;
    final result = _map(
      await _engine.request('configure', {
        'dataDir': paths.file(p.join('data', 'lan_transfer_engine')),
        'steamPath': settings.steamPath,
        'luaRoot': directories.lua,
        'keyCacheRoot': paths.file(p.join('cache', 'key-subscriptions')),
        'displayName': settings.get<String>(
          'lanTransferDisplayName',
          Platform.environment['USERNAME'] ?? 'FlSteamLua',
        ),
        'receiveEnabled': settings.lanTransferEnabled,
        'autoAcceptTrusted': true,
        'libraryRoots': await libraryTargets(),
      }, timeout: const Duration(seconds: 30)),
    );
    _receiveEnabled = settings.lanTransferEnabled;
    _fingerprint = '${result['fingerprint'] ?? ''}';
    _networkError = null;
    _emit();
  }

  void _engineEvent(LanTransferEngineEvent event) {
    switch (event.name) {
      case 'peers.changed':
        final values = event.data['value'];
        final list = values is List ? values : const [];
        _peers
          ..clear()
          ..addAll(
            list.whereType<Map>().map(
              (json) => LanTransferPeerJson.fromEngineJson(
                json.cast<String, dynamic>(),
              ),
            ),
          );
      case 'offer.received':
        final offer = LanTransferOffer.fromJson(event.data);
        _offers.removeWhere((item) => item.sessionId == offer.sessionId);
        _offers.insert(0, offer);
      case 'session.updated':
        _upsertSession(transferSessionFromEngine(event.data));
      case 'engine.error':
        _networkError = '${event.data['message'] ?? event.data}';
        _failActiveTasks(_networkError!);
      case 'engine.exit':
        _networkError = '${event.data['message'] ?? 'LAN engine exited'}';
        _failActiveTasks(_networkError!);
        for (final session in _sessions) {
          if (session.status != TransferSessionStatus.completed &&
              session.status != TransferSessionStatus.cancelled) {
            session
              ..status = TransferSessionStatus.failed
              ..error = _networkError;
          }
        }
        if (!_disposed && !_shuttingDown) {
          unawaited(_restartEngine());
        }
      case 'ready' || 'plan.ready' || 'task.log':
        break;
    }
    _emit();
  }

  void _upsertSession(TransferSession session) {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index < 0) {
      _sessions.add(session);
    } else {
      final previous = _sessions[index];
      session.speedSamples
        ..addAll(previous.speedSamples)
        ..add(session.speed);
      if (session.speedSamples.length > 72) {
        session.speedSamples.removeRange(0, session.speedSamples.length - 72);
      }
      _sessions[index] = session;
    }
    _syncTask(session);
    _emit();
  }

  void _syncTask(TransferSession session) {
    final active = switch (session.status) {
      TransferSessionStatus.completed ||
      TransferSessionStatus.failed ||
      TransferSessionStatus.cancelled => false,
      _ => true,
    };
    var context = _sessionTasks[session.id];
    if (context == null && active) {
      context = tasks.begin(
        localizationsFor(settings.language).lanTransferTask(session.gameName),
        appId: session.appId,
        actionId: session.id,
      );
      _sessionTasks[session.id] = context;
    }
    if (context == null) return;
    context.task
      ..progress = session.progress
      ..message = session.message.isNotEmpty
          ? session.message
          : '${session.completedChunks}/${session.totalChunks}';
    if (session.error?.toString().isNotEmpty == true) {
      tasks.fail(context, StateError(session.error.toString()));
      _sessionTasks.remove(session.id);
    } else if (session.status == TransferSessionStatus.cancelled) {
      tasks.cancelManual(context);
      _sessionTasks.remove(session.id);
    } else if (!active) {
      tasks.complete(context);
      _sessionTasks.remove(session.id);
    } else {
      context.reportProgress(context.task.message, context.task.progress);
    }
  }

  void _failActiveTasks(String message) {
    for (final context in _sessionTasks.values) {
      tasks.fail(context, StateError(message));
    }
    _sessionTasks.clear();
  }

  Future<void> _restartEngine() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_disposed || _shuttingDown) return;
    try {
      await _engine.start(paths.file(p.join('data', 'lan_transfer_engine')));
      await _configure();
      if (_receiveEnabled) await ensureStarted();
      _networkError = null;
    } catch (error) {
      _networkError = '$error';
    }
    _emit();
  }

  void _upsertPeer(LanPeer peer) {
    final index = _peers.indexWhere(
      (item) => item.fingerprint == peer.fingerprint,
    );
    if (index < 0) {
      _peers.add(peer);
    } else {
      _peers[index] = peer;
    }
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_engineEvents?.cancel());
    unawaited(_engine.close());
    super.dispose();
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  static Map<String, dynamic>? _mapValue(
    Map<dynamic, dynamic> source,
    String key,
  ) {
    for (final entry in source.entries) {
      if (entry.key.toString().toLowerCase() == key.toLowerCase() &&
          entry.value is Map) {
        return (entry.value as Map).cast<String, dynamic>();
      }
    }
    return null;
  }

  static String _stringValue(Map<dynamic, dynamic> source, String key) {
    for (final entry in source.entries) {
      if (entry.key.toString().toLowerCase() == key.toLowerCase()) {
        return entry.value?.toString() ?? '';
      }
    }
    return '';
  }
}
