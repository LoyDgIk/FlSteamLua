import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_engine_client.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_models.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_service.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('service maps native engine events and commands', () async {
    final root = await Directory.systemTemp.createTemp('fl-lan-service-');
    final steam = Directory(p.join(root.path, 'steam'));
    final lua = Directory(p.join(steam.path, 'config', 'stplug-in'));
    await Directory(p.join(steam.path, 'steamapps')).create(recursive: true);
    await lua.create(recursive: true);
    final paths = AppPaths(root.path);
    await paths.initialize();
    final settings = SettingsStore(paths);
    await settings.set('steamPath', steam.path);
    await settings.set('luaPath', lua.path);
    final tasks = TaskCenter();
    final engine = _FakeEngine();
    final library = LibraryService(paths: paths, settings: settings);
    final service = LanTransferService(
      paths: paths,
      settings: settings,
      library: library,
      tasks: tasks,
      engine: engine,
    );
    try {
      await service.initialize();
      expect(engine.requests.map((value) => value.$1), contains('configure'));

      engine.emit('peers.changed', {
        'value': [
          {
            'id': 'peer',
            'alias': 'Peer',
            'address': '127.0.0.1',
            'port': 47821,
            'fingerprint': 'PEER',
            'trusted': false,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          },
        ],
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.peers.single.alias, 'Peer');

      engine.emit('offer.received', {
        'sessionId': 'receive:bundle',
        'bundleId': 'bundle',
        'appId': 42,
        'gameName': 'Fixture',
        'installDir': 'Fixture',
        'totalBytes': 100,
        'selectedBytes': 100,
        'fileCount': 2,
        'chunkCount': 3,
        'luaEnabled': true,
        'manifestAvailable': true,
        'warnings': <String>[],
        'trusted': false,
        'receivedAt': DateTime.now().millisecondsSinceEpoch,
        'peer': {
          'id': 'peer',
          'alias': 'Peer',
          'address': '127.0.0.1',
          'port': 47821,
          'fingerprint': 'PEER',
          'trusted': false,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.offers.single.gameName, 'Fixture');

      engine.emit('session.updated', {
        'id': 'send:bundle',
        'bundleId': 'bundle',
        'appId': 42,
        'gameName': 'Fixture',
        'direction': 'send',
        'peerId': 'peer',
        'peerAlias': 'Peer',
        'peerAddress': '127.0.0.1',
        'peerFingerprint': 'PEER',
        'status': 'transferring',
        'totalBytes': 100,
        'transferredBytes': 50,
        'speed': 10,
        'peakSpeed': 12,
        'message': '',
        'canPause': true,
        'totalChunks': 3,
        'completedChunks': 1,
        'cachedChunks': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        service.sessions.single.status,
        TransferSessionStatus.transferring,
      );
      expect(tasks.tasks.first.actionId, 'send:bundle');
    } finally {
      service.dispose();
      tasks.dispose();
      library.dispose();
      settings.dispose();
      await root.delete(recursive: true);
    }
  });
}

class _FakeEngine implements LanTransferEngineTransport {
  final StreamController<LanTransferEngineEvent> _events =
      StreamController<LanTransferEngineEvent>.broadcast();
  final List<(String, Map<String, dynamic>)> requests = [];

  @override
  Stream<LanTransferEngineEvent> get events => _events.stream;

  @override
  bool get isRunning => true;

  @override
  Future<void> start(String dataDir) async {}

  @override
  Future<dynamic> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    requests.add((method, params));
    return switch (method) {
      'configure' => {'fingerprint': 'SELF', 'receiving': false},
      'plan.prepare' => {
        'id': 'plan',
        'appId': 42,
        'gameName': 'Fixture',
        'installDir': 'Fixture',
        'selectedBytes': 100,
        'officialBytes': 100,
        'manifestBytes': 0,
        'optionalBytes': 0,
        'officialFiles': 2,
        'manifestFiles': 0,
        'chunkCount': 3,
        'luaEnabled': false,
        'manifestAvailable': true,
        'warnings': <String>[],
        'optionalFiles': <Map<String, dynamic>>[],
      },
      'cache.stats' => {'bytes': 0, 'files': 0},
      _ => {'ok': true},
    };
  }

  void emit(String name, Map<String, dynamic> data) {
    _events.add(LanTransferEngineEvent(name, data));
  }

  @override
  Future<void> close() => _events.close();
}
