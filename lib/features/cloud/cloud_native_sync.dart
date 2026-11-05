import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/task_center.dart';

typedef CloudNativeRunner =
    Future<Map<String, dynamic>> Function({
      required String library,
      required String provider,
      required String accountId,
      required int appId,
      required String cloudRoot,
      TaskContext? context,
    });

Future<Map<String, dynamic>> runCloudNativeSync({
  required String library,
  required String provider,
  required String accountId,
  required int appId,
  required String cloudRoot,
  TaskContext? context,
}) async {
  final executable = p.join(
    p.dirname(Platform.resolvedExecutable),
    'cloud_sync_worker.exe',
  );
  final process = await Process.start(executable, [
    library,
    provider,
    accountId,
    '$appId',
    cloudRoot,
  ]);
  final stdout = utf8.decodeStream(process.stdout);
  final stderr = utf8.decodeStream(process.stderr);
  final timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
    if (context?.isCancelled == true) process.kill();
  });
  try {
    final exit = await process.exitCode.timeout(
      const Duration(minutes: 5),
      onTimeout: () async {
        process.kill();
        await process.exitCode;
        await stdout;
        await stderr;
        throw TimeoutException('CloudRedirect sync deadline');
      },
    );
    final output = await stdout;
    await stderr;
    context?.checkCancelled();
    if (exit != 0) {
      throw ProcessException(
        executable,
        const [],
        'CloudRedirect worker failed',
        exit,
      );
    }
    final value = jsonDecode(output);
    if (value is! Map<String, dynamic> ||
        value['success'] != true ||
        value['drained'] != true ||
        value['local_cn'] is! int ||
        value['local_file_count'] is! int ||
        value['had_newer'] is! bool) {
      throw const FormatException(
        'CloudRedirect did not confirm synchronization',
      );
    }
    return value;
  } finally {
    timer.cancel();
  }
}
