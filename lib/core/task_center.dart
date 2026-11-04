import 'dart:async';

import 'package:flutter/foundation.dart';

enum TaskStatus { running, succeeded, failed, cancelled }

class TaskCancelled implements Exception {
  const TaskCancelled();
  @override
  String toString() => 'Task cancelled';
}

class TaskProgress {
  TaskProgress(this.id, this.title, {this.appId, this.actionId});
  final String id;
  final String title;
  final int? appId;
  final String? actionId;
  final DateTime startedAt = DateTime.now();
  TaskStatus status = TaskStatus.running;
  double? progress;
  String message = '';
  Object? error;
  bool cancellationRequested = false;
  final List<String> logs = [];
}

class TaskContext {
  TaskContext(this.task, this._notify);
  final TaskProgress task;
  final VoidCallback _notify;

  bool get isCancelled => task.cancellationRequested;
  void checkCancelled() {
    if (isCancelled) throw const TaskCancelled();
  }

  void report(String message, [double? progress]) {
    task.message = message;
    task.progress = progress;
    task.logs.add(message);
    _notify();
  }

  void reportProgress(String message, [double? progress]) {
    task.message = message;
    task.progress = progress;
    _notify();
  }
}

class TaskCenter extends ChangeNotifier {
  final List<TaskProgress> _tasks = [];
  int _sequence = 0;
  Completer<void>? _idle;
  List<TaskProgress> get tasks => List.unmodifiable(_tasks);
  int get runningCount =>
      _tasks.where((t) => t.status == TaskStatus.running).length;

  Future<T> run<T>(
    String title,
    Future<T> Function(TaskContext) action, {
    int? appId,
  }) async {
    final task = TaskProgress(
      '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      title,
      appId: appId,
    );
    _tasks.insert(0, task);
    if (_idle == null || _idle!.isCompleted) {
      _idle = Completer<void>();
    }
    notifyListeners();
    try {
      final result = await action(TaskContext(task, notifyListeners));
      task.status = TaskStatus.succeeded;
      task.progress = 1;
      return result;
    } on TaskCancelled {
      task.status = TaskStatus.cancelled;
      rethrow;
    } catch (error) {
      task.status = TaskStatus.failed;
      task.error = error;
      rethrow;
    } finally {
      notifyListeners();
      if (runningCount == 0) _idle?.complete();
    }
  }

  TaskContext begin(String title, {int? appId, String? actionId}) {
    final task = TaskProgress(
      '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      title,
      appId: appId,
      actionId: actionId,
    );
    _tasks.insert(0, task);
    if (_idle == null || _idle!.isCompleted) {
      _idle = Completer<void>();
    }
    notifyListeners();
    return TaskContext(task, notifyListeners);
  }

  void complete(TaskContext context, {String? message}) {
    if (context.task.status != TaskStatus.running) return;
    context.task
      ..status = TaskStatus.succeeded
      ..progress = 1;
    if (message != null) context.task.message = message;
    notifyListeners();
    if (runningCount == 0) _idle?.complete();
  }

  void fail(TaskContext context, Object error) {
    if (context.task.status != TaskStatus.running) return;
    context.task
      ..status = TaskStatus.failed
      ..error = error;
    notifyListeners();
    if (runningCount == 0) _idle?.complete();
  }

  void cancelManual(TaskContext context) {
    if (context.task.status != TaskStatus.running) return;
    context.task.status = TaskStatus.cancelled;
    notifyListeners();
    if (runningCount == 0) _idle?.complete();
  }

  void cancel(String id) {
    final task = _tasks.firstWhere((task) => task.id == id);
    if (task.status == TaskStatus.running) {
      task.cancellationRequested = true;
      notifyListeners();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((task) => task.status != TaskStatus.running);
    notifyListeners();
  }

  void requestCancellation() {
    for (final task in _tasks.where(
      (task) => task.status == TaskStatus.running,
    )) {
      task.cancellationRequested = true;
    }
    notifyListeners();
  }

  Future<void> cancelAndWait() async {
    requestCancellation();
    await _idle?.future;
  }
}
