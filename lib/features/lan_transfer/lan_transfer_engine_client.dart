import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class LanTransferEngineEvent {
  const LanTransferEngineEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

abstract interface class LanTransferEngineTransport {
  Stream<LanTransferEngineEvent> get events;
  bool get isRunning;

  Future<void> start(String dataDir);

  Future<dynamic> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 45),
  });

  Future<void> close();
}

class LanTransferEngineClient implements LanTransferEngineTransport {
  LanTransferEngineClient({this.executablePathOverride});

  final String? executablePathOverride;
  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final Map<String, Completer<dynamic>> _pending = {};
  final StreamController<LanTransferEngineEvent> _events =
      StreamController<LanTransferEngineEvent>.broadcast();
  int _sequence = 0;
  Future<void>? _startFuture;
  bool _closed = false;
  Future<void> _writes = Future.value();
  String? _lastError;

  @override
  Stream<LanTransferEngineEvent> get events => _events.stream;
  @override
  bool get isRunning => _process != null;
  String? get lastError => _lastError;

  String get executablePath {
    final configured = executablePathOverride;
    if (configured != null && configured.isNotEmpty) return configured;
    final adjacent = p.join(
      p.dirname(Platform.resolvedExecutable),
      'lan_transfer_engine.exe',
    );
    if (File(adjacent).existsSync()) return adjacent;
    return p.join(
      Directory.current.path,
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
      'lan_transfer_engine.exe',
    );
  }

  @override
  Future<void> start(String dataDir) {
    if (_closed) throw StateError('LAN transfer engine client is closed');
    final starting = _startFuture;
    if (starting != null) return starting;
    if (_process != null) return Future.value();
    return _startFuture = _start(dataDir).whenComplete(() {
      _startFuture = null;
    });
  }

  Future<void> _start(String dataDir) async {
    await Directory(dataDir).create(recursive: true);
    final executable = executablePath;
    if (!await File(executable).exists()) {
      throw StateError('LAN transfer engine is missing: $executable');
    }
    final process = await Process.start(
      executable,
      ['--data-dir', dataDir],
      workingDirectory: p.dirname(executable),
      mode: ProcessStartMode.normal,
    );
    _process = process;
    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleStreamError);
    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.trim().isNotEmpty) debugPrint('LAN engine: $line');
        }, onError: _handleStreamError);
    unawaited(
      process.exitCode.then((code) {
        if (!identical(_process, process)) return;
        _process = null;
        final error = StateError('LAN transfer engine exited ($code)');
        _lastError = '$error';
        for (final pending in _pending.values) {
          if (!pending.isCompleted) pending.completeError(error);
        }
        _pending.clear();
        if (!_events.isClosed) {
          _events.add(
            LanTransferEngineEvent('engine.exit', {
              'code': code,
              'message': '$error',
            }),
          );
        }
      }),
    );
    try {
      await request('hello', const {}, timeout: const Duration(seconds: 20));
      _lastError = null;
    } catch (_) {
      if (identical(_process, process)) _process = null;
      process.kill();
      await process.stdin.close().catchError((_) {});
      rethrow;
    }
  }

  @override
  Future<dynamic> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final process = _process;
    if (process == null) throw StateError('LAN transfer engine is not running');
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    final write = _writes.then((_) async {
      process.stdin.writeln(
        jsonEncode({'id': id, 'method': method, 'params': params}),
      );
      await process.stdin.flush();
    });
    _writes = write.catchError((Object _) {});
    await write;
    try {
      return await completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
    }
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(line);
    } catch (error) {
      _lastError = 'Invalid engine response: $error';
      debugPrint(_lastError);
      return;
    }
    if (decoded is! Map) return;
    final value = Map<String, dynamic>.from(decoded);
    if (value['event'] case final String name) {
      final data = value['data'];
      if (!_events.isClosed) {
        _events.add(
          LanTransferEngineEvent(
            name,
            data is Map ? Map<String, dynamic>.from(data) : {'value': data},
          ),
        );
      }
      return;
    }
    final id = value['id']?.toString();
    if (id == null) return;
    final pending = _pending.remove(id);
    if (pending == null || pending.isCompleted) return;
    final error = value['error'];
    if (error is Map) {
      pending.completeError(
        StateError('${error['message'] ?? error['code'] ?? 'Engine error'}'),
      );
    } else {
      pending.complete(value['result']);
    }
  }

  void _handleStreamError(Object error, StackTrace stack) {
    _lastError = '$error';
    debugPrint('LAN engine stream: $error');
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _startFuture?.catchError((Object _) {});
    try {
      if (_process != null) {
        await request(
          'shutdown',
          const {},
          timeout: const Duration(seconds: 2),
        );
      }
    } catch (_) {
      // The process may already be gone.
    }
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    final process = _process;
    _process = null;
    if (process != null) {
      process.kill();
      await process.stdin.close().catchError((_) {});
    }
    await _events.close();
  }
}
