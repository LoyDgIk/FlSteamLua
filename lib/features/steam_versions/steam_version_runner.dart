import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../core/task_center.dart';
import '../library/process_observer.dart';

typedef SteamVersionRunner =
    Future<void> Function({
      required String executable,
      required String workingDirectory,
      required String packagesUrl,
      TaskContext? context,
    });

Future<void> runSteamVersionBootstrap({
  required String executable,
  required String workingDirectory,
  required String packagesUrl,
  TaskContext? context,
}) async {
  final process = await Process.start(executable, [
    '-forcesteamupdate',
    '-forcepackagedownload',
    '-overridepackageurl',
    packagesUrl,
    '-exitsteam',
  ], workingDirectory: workingDirectory);
  final output = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .listen((line) => context?.report(line));
  final errors = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .listen((line) => context?.report(line));
  int? code;
  final exit = process.exitCode.then((v) => code = v);
  final deadline = DateTime.now().add(const Duration(minutes: 10));
  try {
    while (true) {
      context?.checkCancelled();
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Steam bootstrap deadline exceeded');
      }
      if (code != null) {
        if (code != 0) {
          throw ProcessException(
            executable,
            const [],
            'Steam bootstrap failed',
            code!,
          );
        }
        final children = (await readRunningProcesses()).where(
          (v) => p.isWithin(workingDirectory, v.executablePath),
        );
        if (children.isEmpty) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await exit;
  } finally {
    process.kill();
    for (final child in await readRunningProcesses()) {
      if (p.isWithin(workingDirectory, child.executablePath)) {
        await stopObservedProcess(child);
      }
    }
    await exit;
    await output.cancel();
    await errors.cancel();
  }
}

/// Serves only the verified package inventory to the loopback Steam updater.
class SteamPackageServer {
  SteamPackageServer({
    required this.directory,
    required this.arch,
    required this.files,
  });
  final String directory, arch;
  final Set<String> files;
  HttpServer? _server;
  final Set<String> missing = {};
  String get url => 'http://127.0.0.1:${_server!.port}';
  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      try {
        if (!{'GET', 'HEAD'}.contains(request.method) ||
            request.uri.pathSegments.length != 1) {
          request.response.statusCode = 404;
          return;
        }
        final name = request.uri.pathSegments.single;
        final manifest = {
          'steam_client_win32',
          'steam_client_win64',
        }.contains(name);
        if (!manifest && !files.contains(name)) {
          request.response.statusCode = 404;
          return;
        }
        final file = File(
          p.join(directory, manifest ? 'steam_client_$arch.manifest' : name),
        );
        if (!await file.exists()) {
          missing.add(name);
          request.response.statusCode = 404;
          return;
        }
        final size = await file.length();
        var start = 0, end = size - 1;
        final requested = request.headers.value(HttpHeaders.rangeHeader);
        if (requested != null) {
          final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(requested);
          if (match == null) {
            request.response.statusCode = 416;
            return;
          }
          start = int.parse(match[1]!);
          end = match[2]!.isEmpty ? end : int.parse(match[2]!);
          if (start > end || end >= size) {
            request.response.statusCode = 416;
            return;
          }
          request.response.statusCode = 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/$size',
          );
        }
        request.response.headers.contentType = ContentType.binary;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.contentLength = end - start + 1;
        if (request.method != 'HEAD') {
          await request.response.addStream(file.openRead(start, end + 1));
        }
      } on HttpException {
        /* the updater closed this connection */
      } finally {
        await request.response.close();
      }
    });
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }
}
