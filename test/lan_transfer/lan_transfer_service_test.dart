import 'dart:async';
import 'dart:io';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_engine_client.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_models.dart';
import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_service.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'startup does not start the engine when receiving is disabled',
    () async {
      await _withService((service, settings, engine) async {
        await service.initializeIfReceiving();
        expect(service.initialized, isFalse);
        expect(engine.startCount, 0);
        expect(engine.requests, isEmpty);
        await service.shutdown();
        expect(engine.startCount, 0);
      });
    },
  );

  test('startup starts the engine when receiving is enabled', () async {
    await _withService((service, settings, engine) async {
      await settings.set('lanTransferEnabled', true);
      await service.initializeIfReceiving();
      expect(service.initialized, isTrue);
      expect(service.receiveEnabled, isTrue);
      expect(service.isDiscovering, isTrue);
      expect(engine.startCount, 1);
      expect(
        engine.requests.where((value) => value.$1 == 'configure'),
        hasLength(1),
      );
      expect(
        engine.requests.where((value) => value.$1 == 'discovery.start'),
        hasLength(1),
      );
    });
  });

  for (final clear in [false, true]) {
    test(
      'first cache ${clear ? 'clear' : 'stats'} request starts the engine',
      () async {
        await _withService((service, settings, engine) async {
          if (clear) {
            await service.clearChunkCache();
          } else {
            expect(await service.chunkCacheStats(), (bytes: 0, files: 0));
          }
          expect(engine.startCount, 1);
          expect(engine.requests.map((value) => value.$1), [
            'configure',
            'session.list',
            clear ? 'cache.clear' : 'cache.stats',
          ]);
        });
      },
    );
  }

  test('concurrent first use shares one initialization', () async {
    await _withService((service, settings, engine) async {
      final first = service.initialize();
      final second = service.initialize();
      expect(identical(first, second), isTrue);
      await Future.wait([first, second]);
      expect(engine.startCount, 1);
      expect(engine.requests.map((value) => value.$1), [
        'configure',
        'session.list',
      ]);
      await service.ensureStarted();
      expect(engine.startCount, 1);
      expect(engine.requests.last.$1, 'discovery.start');
    });
  });

  test('service maps native engine events and commands', () async {
    final root = await Directory.systemTemp.createTemp('fl-lan-service-');
    final steam = Directory(p.join(root.path, 'steam'));
    final lua = Directory(p.join(steam.path, 'config', 'lua'));
    await Directory(p.join(steam.path, 'steamapps')).create(recursive: true);
    await lua.create(recursive: true);
    final paths = AppPaths(root.path);
    await paths.initialize();
    final settings = SettingsStore(paths);
    await settings.set('steamPath', steam.path);
    final tasks = TaskCenter();
    final engine = _FakeEngine();
    engine.restoredSessions = [_sessionJson('send:initial')];
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
      expect(
        engine.requests.map((value) => value.$1),
        contains('session.list'),
      );
      expect(service.sessions.single.id, 'send:initial');

      final summary = await service.prepare(
        const GameEntry(
          appId: 42,
          name: 'Fixture',
          luaPath: 'disabled/42.lua',
          luaEnabled: false,
        ),
      );
      expect(summary.luaAvailable, isTrue);
      expect(summary.luaEnabled, isFalse);
      final prepare = engine.requests.lastWhere(
        (value) => value.$1 == 'plan.prepare',
      );
      expect(prepare.$2['luaEnabled'], isFalse);

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

      final offerJson = {
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
      };
      engine.emit('offer.received', offerJson);
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
        'networkBytes': 30,
        'diskBytes': 30,
        'diskSpeed': 6,
        'installedBytes': 20,
        'installedFiles': 1,
        'totalFiles': 2,
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
        service.sessions
            .firstWhere((session) => session.id == 'send:bundle')
            .status,
        TransferSessionStatus.transferring,
      );
      expect(tasks.tasks.first.actionId, 'send:bundle');
      final transfer = service.sessions.firstWhere(
        (session) => session.id == 'send:bundle',
      );
      expect(transfer.networkBytes, 30);
      expect(transfer.diskBytes, 30);
      expect(transfer.diskSpeed, 6);
      expect(transfer.installProgress, .5);
      expect(transfer.diskSpeedSamples, [6]);

      engine.emit('session.updated', {
        ..._sessionJson('receive:bundle'),
        'direction': 'receive',
        'status': 'transferring',
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.offers, isEmpty);

      engine.emit('offer.received', offerJson);
      await Future<void>.delayed(Duration.zero);
      expect(service.offers, hasLength(1));
      engine.emit('session.updated', {
        ..._sessionJson('receive:bundle'),
        'direction': 'receive',
        'status': 'cancelled',
      });
      await Future<void>.delayed(Duration.zero);
      expect(service.offers, isEmpty);

      engine.restoredSessions = [_sessionJson('send:restored')];
      engine.emit('engine.exit', {'message': 'fixture exit'});
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(engine.startCount, 2);
      expect(
        service.sessions.any((session) => session.id == 'send:restored'),
        isTrue,
      );
    } finally {
      service.dispose();
      tasks.dispose();
      library.dispose();
      settings.dispose();
      await root.delete(recursive: true);
    }
  });
}

Future<void> _withService(
  Future<void> Function(
    LanTransferService service,
    SettingsStore settings,
    _FakeEngine engine,
  )
  action,
) async {
  final root = await Directory.systemTemp.createTemp('fl-lan-startup-');
  final steam = Directory(p.join(root.path, 'steam'));
  await Directory(p.join(steam.path, 'steamapps')).create(recursive: true);
  final paths = AppPaths(root.path);
  await paths.initialize();
  final settings = SettingsStore(paths);
  await settings.set('steamPath', steam.path);
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
    await action(service, settings, engine);
  } finally {
    service.dispose();
    tasks.dispose();
    library.dispose();
    settings.dispose();
    await root.delete(recursive: true);
  }
}

class _FakeEngine implements LanTransferEngineTransport {
  final StreamController<LanTransferEngineEvent> _events =
      StreamController<LanTransferEngineEvent>.broadcast();
  final List<(String, Map<String, dynamic>)> requests = [];
  List<Map<String, dynamic>> restoredSessions = [];
  int startCount = 0;

  @override
  Stream<LanTransferEngineEvent> get events => _events.stream;

  @override
  bool get isRunning => true;

  @override
  Future<void> start(String dataDir) async {
    startCount++;
  }

  @override
  Future<dynamic> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    requests.add((method, params));
    return switch (method) {
      'configure' => {'fingerprint': 'SELF', 'receiving': false},
      'session.list' => {'sessions': restoredSessions},
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
        'luaAvailable': true,
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

Map<String, dynamic> _sessionJson(String id) => {
  'id': id,
  'bundleId': id.split(':').last,
  'appId': 42,
  'gameName': 'Fixture',
  'direction': 'send',
  'peerId': 'peer',
  'peerAlias': 'Peer',
  'peerAddress': '127.0.0.1',
  'peerFingerprint': 'PEER',
  'status': 'failed',
  'totalBytes': 100,
  'transferredBytes': 50,
  'speed': 0,
  'peakSpeed': 12,
  'message': '',
  'canPause': true,
  'totalChunks': 3,
  'completedChunks': 1,
  'cachedChunks': 0,
  'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
};
