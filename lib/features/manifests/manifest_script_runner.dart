import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_qjs_next/flutter_qjs.dart';

import '../../core/task_center.dart';
import 'manifest_models.dart';

typedef ManifestRequestHandler =
    Future<Map<String, Object?>> Function(Map<String, dynamic> request);

abstract interface class ManifestScriptRunner {
  Future<Object?> invoke({
    required String script,
    required String function,
    required Map<String, Object?> params,
    required ManifestRequestHandler request,
    required void Function(String) log,
    TaskContext? task,
  });
}

class QuickJsManifestRunner implements ManifestScriptRunner {
  const QuickJsManifestRunner({this.timeout = const Duration(minutes: 5)});
  final Duration timeout;

  @override
  Future<Object?> invoke({
    required String script,
    required String function,
    required Map<String, Object?> params,
    required ManifestRequestHandler request,
    required void Function(String) log,
    TaskContext? task,
  }) async {
    final events = ReceivePort();
    final completed = Completer<Object?>();
    SendPort? control;
    final worker = await Isolate.spawn(_runManifestScript, <String, Object?>{
      'events': events.sendPort,
      'script': script,
      'function': function,
      'params': params,
    });
    final subscription = events.listen((dynamic event) async {
      if (event is! Map) return;
      switch (event['type']) {
        case 'ready':
          control = event['control'] as SendPort;
        case 'log':
          log('${event['message']}');
        case 'http':
          final reply = event['reply'] as SendPort;
          try {
            final payload = Map<String, dynamic>.from(event['payload'] as Map);
            reply.send(await request(payload));
          } catch (error) {
            reply.send({'__error': '$error'});
          }
        case 'result':
          if (!completed.isCompleted) completed.complete(event['value']);
        case 'error':
          if (!completed.isCompleted) {
            completed.completeError(
              ManifestSourceException('script_error', '${event['message']}'),
            );
          }
      }
    });
    final cancellation = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (task?.isCancelled == true) control?.send('cancel');
    });
    try {
      final result = await completed.future.timeout(timeout);
      task?.checkCancelled();
      return result;
    } on TimeoutException {
      control?.send('cancel');
      throw const ManifestSourceException(
        'script_error',
        'Manifest script exceeded its execution deadline',
      );
    } finally {
      cancellation.cancel();
      control?.send('cancel');
      await subscription.cancel();
      events.close();
      // The worker disposes its QuickJS heap on result, error or cancellation.
      unawaited(
        Future<void>.delayed(
          const Duration(seconds: 6),
          () => worker.kill(priority: Isolate.immediate),
        ),
      );
    }
  }
}

Future<void> _runManifestScript(Map<String, Object?> message) async {
  final events = message['events'] as SendPort;
  final control = ReceivePort();
  final cancelled = Completer<void>();
  final replies = <ReceivePort>[];
  final subscription = control.listen((dynamic value) {
    if (value == 'cancel' && !cancelled.isCompleted) cancelled.complete();
  });
  events.send({'type': 'ready', 'control': control.sendPort});
  JavascriptRuntime? runtime;
  try {
    runtime = getJavascriptRuntime(
      timeout: 5000,
      memoryLimit: 256 * 1024 * 1024,
    );
    runtime.onMessage('manifestLog', (dynamic args) {
      events.send({'type': 'log', 'message': '$args'});
    });
    runtime.onMessage('manifestHttp', (dynamic args) async {
      if (cancelled.isCompleted) throw const TaskCancelled();
      final reply = ReceivePort();
      replies.add(reply);
      events.send({'type': 'http', 'payload': args, 'reply': reply.sendPort});
      try {
        return await Future.any<Object?>([
          reply.first,
          cancelled.future.then<Object?>((_) => throw const TaskCancelled()),
        ]);
      } finally {
        replies.remove(reply);
        reply.close();
      }
    });
    final loaded = runtime.evaluate(message['script'] as String);
    if (loaded.isError) throw StateError(loaded.stringResult);
    final function = message['function'] as String;
    if (!{'test', 'download'}.contains(function)) {
      throw ArgumentError('Unknown manifest entry point');
    }
    final parameters = jsonEncode(message['params']);
    final pending = await runtime.evaluateAsync('''
      (async () => {
        const ctx = {
          params: $parameters,
          log: (message) => sendMessage('manifestLog', JSON.stringify(String(message))),
          http: {
            get: (url, options = {}) => request('GET', url, options),
            post: (url, options = {}) => request('POST', url, options)
          }
        };
        async function request(method, url, options) {
          const response = await sendMessage('manifestHttp', JSON.stringify({method, url, options}));
          if (response && response.__error) throw new Error(response.__error);
          return response;
        }
        if (typeof $function !== 'function') {
          throw new Error('Missing async function $function(ctx)');
        }
        return JSON.stringify(await $function(ctx));
      })();
    ''');
    if (pending.isError) throw StateError(pending.stringResult);
    final done = await Future.any<JsEvalResult>([
      runtime.handlePromise(pending),
      cancelled.future.then<JsEvalResult>((_) => throw const TaskCancelled()),
    ]);
    if (done.isError) throw StateError(done.stringResult);
    final raw = done.rawResult;
    final value = raw is String
        ? jsonDecode(raw)
        : jsonDecode(done.stringResult);
    events.send({'type': 'result', 'value': value});
  } catch (error) {
    events.send({'type': 'error', 'message': '$error'});
  } finally {
    for (final reply in replies.toList()) {
      reply.close();
    }
    runtime?.dispose();
    await subscription.cancel();
    control.close();
  }
}
