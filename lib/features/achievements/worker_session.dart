import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../platform/windows/named_pipe.dart';
import 'achievement_models.dart';

abstract interface class AchievementWorkerSession {
  Future<AchievementSnapshot> load();
  Future<void> save(Map<String, bool> achievements, Map<String, num> stats);
  Future<SteamTickets> tickets();
  Future<void> close();
}

typedef WorkerSessionFactory =
    Future<AchievementWorkerSession> Function(int appId, String steamPath);

class SteamWorkerSession implements AchievementWorkerSession {
  SteamWorkerSession._(
    this._process,
    this._isolate,
    this._responses,
    this._commands,
  );
  final Process _process;
  final Isolate _isolate;
  final StreamIterator<dynamic> _responses;
  final SendPort _commands;
  Future<void> _queue = Future.value();
  bool _closed = false;

  static Future<SteamWorkerSession> start(
    int appId,
    String steamPath, {
    String? executable,
    String? bridgeLibrary,
  }) async {
    if (appId <= 0 || appId > 0xffffffff) {
      throw ArgumentError.value(appId, 'appId');
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('Steam worker currently supports Windows x64');
    }
    final worker =
        executable ??
        p.join(p.dirname(Platform.resolvedExecutable), 'steam_worker.exe');
    if (!await File(worker).exists()) {
      throw FileSystemException(
        'Steam worker is missing. Build or install the complete Windows package.',
        worker,
      );
    }
    final pipeName =
        'flsteamlua_${pid}_${appId}_${Random.secure().nextInt(0x7fffffff)}';
    final process = await Process.start(
      worker,
      [
        '--app-id',
        '$appId',
        '--steam-path',
        steamPath,
        '--pipe',
        pipeName,
        if (bridgeLibrary != null) ...['--bridge', bridgeLibrary],
      ],
      workingDirectory: p.dirname(worker),
      environment: {'SteamAppId': '$appId', 'SteamGameId': '$appId'},
      mode: ProcessStartMode.normal,
    );
    // Steam's DLL may write or close these streams; protocol never uses them.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final responsePort = ReceivePort();
    final responses = StreamIterator<dynamic>(responsePort);
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(_pipeIsolate, [
        responsePort.sendPort,
        pipeName,
      ]);
      if (!await responses.moveNext().timeout(const Duration(seconds: 30))) {
        throw const FileSystemException('Steam pipe transport exited');
      }
      final first = responses.current;
      if (first is! SendPort) throw StateError(first.toString());
      if (!await responses.moveNext().timeout(const Duration(seconds: 35))) {
        throw const FileSystemException('Steam worker exited before ready');
      }
      _checkResponse(responses.current);
      return SteamWorkerSession._(process, isolate, responses, first);
    } catch (_) {
      process.kill();
      isolate?.kill(priority: Isolate.immediate);
      await responses.cancel();
      responsePort.close();
      rethrow;
    }
  }

  static Map<String, dynamic> _checkResponse(dynamic raw) {
    if (raw is! Map) throw StateError('Invalid Steam worker response');
    final response = Map<String, dynamic>.from(raw);
    if (response['ok'] != true) {
      throw StateError(
        response['error'] as String? ?? 'Steam worker operation failed',
      );
    }
    return response;
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> request) {
    final result = Completer<Map<String, dynamic>>();
    _queue = _queue.then((_) async {
      if (_closed) {
        result.completeError(StateError('Steam worker is closed'));
        return;
      }
      try {
        _commands.send(request);
        if (!await _responses.moveNext().timeout(const Duration(seconds: 40))) {
          throw const FileSystemException('Steam worker disconnected');
        }
        result.complete(_checkResponse(_responses.current));
      } catch (error, trace) {
        result.completeError(error, trace);
      }
    });
    return result.future;
  }

  @override
  Future<AchievementSnapshot> load() async {
    final response = await _send({'command': 'load'});
    return AchievementSnapshot.fromJson(
      Map<String, dynamic>.from(response['snapshot'] as Map),
    );
  }

  @override
  Future<void> save(
    Map<String, bool> achievements,
    Map<String, num> stats,
  ) async {
    await _send({
      'command': 'save',
      'achievements': achievements,
      'stats': stats,
    });
  }

  @override
  Future<SteamTickets> tickets() async {
    final response = await _send({'command': 'tickets'});
    return SteamTickets.fromJson(
      Map<String, dynamic>.from(response['tickets'] as Map),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    try {
      await _send({'command': 'exit'}).timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Terminate below if the worker or pipe is already unavailable. */
    }
    _closed = true;
    _commands.send(null);
    try {
      await _process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      _process.kill();
    }
    _isolate.kill(priority: Isolate.immediate);
    await _responses.cancel();
  }
}

void _pipeIsolate(List<Object> arguments) {
  final replies = arguments[0] as SendPort;
  final name = arguments[1] as String;
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  WindowsNamedPipe? pipe;
  try {
    pipe = WindowsNamedPipe.connect(name);
    replies.send(
      pipe.readJson(timeout: const Duration(seconds: 30)) ??
          {'ok': false, 'error': 'Steam worker closed before initialization'},
    );
  } catch (error) {
    replies.send({'ok': false, 'error': error.toString()});
    pipe?.close();
    commands.close();
    return;
  }
  commands.listen((dynamic message) {
    if (message == null) {
      pipe!.close();
      commands.close();
      return;
    }
    try {
      pipe!.writeJson(Map<String, dynamic>.from(message as Map));
      replies.send(
        pipe.readJson(timeout: const Duration(seconds: 35)) ??
            {'ok': false, 'error': 'Steam worker closed the connection'},
      );
    } catch (error) {
      replies.send({'ok': false, 'error': error.toString()});
      pipe!.close();
      commands.close();
    }
  });
}
