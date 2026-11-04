import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/tools/manifest_monitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'parses real content log request while preserving 64-bit manifest IDs',
    () {
      final request = ManifestRequest.parse(
        'BYldRequestDepotManifest(App: 50, Depot: 71, Manifest: 99900011122233344, token: 0)',
      );
      expect(request?.appId, 50);
      expect(request?.depotId, 71);
      expect(request?.manifestId, '99900011122233344');
      expect(ManifestRequest.parse('ordinary log message'), isNull);
    },
  );

  test('rejects HTML and accepts zipped manifest magic', () {
    expect(
      () => ManifestCdnDownloader.unwrapManifest('<html>oops</html>'.codeUnits),
      throwsFormatException,
    );
    final manifest = [0xd0, 0x17, 0xf6, 0x71, ...List.filled(40, 0)];
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('z', manifest.length, manifest)),
    );
    expect(ManifestCdnDownloader.unwrapManifest(zip), manifest);
  });

  test(
    'CDN repair writes only verified manifests to fixture Steam directory',
    () async {
      final temp = await Directory.systemTemp.createTemp('flsteam-monitor-');
      addTearDown(() => temp.delete(recursive: true));
      final bytes = [0xd0, 0x17, 0xf6, 0x71, ...List.filled(40, 0)];
      final downloader = ManifestCdnDownloader(
        sources: [(depot, gid) => Uri.https('codes.test', '/$depot/$gid')],
        cdnHost: 'cdn.test',
        client: MockClient((request) async {
          if (request.url.host == 'codes.test') {
            return http.Response('123456', 200);
          }
          expect(
            request.url.path,
            '/depot/71/manifest/99900011122233344/5/123456',
          );
          return http.Response.bytes(bytes, 200);
        }),
      );
      addTearDown(downloader.dispose);
      final tasks = TaskCenter();
      final file = await tasks.run(
        'fixture',
        (task) => downloader.download(
          temp.path,
          const ManifestRequest(50, 71, '99900011122233344'),
          task,
        ),
      );
      expect(await file.readAsBytes(), bytes);
      expect(p.basename(file.path), '71_99900011122233344.manifest');
      expect(tasks.tasks.single.status, TaskStatus.succeeded);
    },
  );

  test(
    'monitor ignores old and duplicate requests and handles appended lines',
    () async {
      final temp = await Directory.systemTemp.createTemp('flsteam-tail-');
      addTearDown(() => temp.delete(recursive: true));
      final log = File(p.join(temp.path, 'logs', 'content_log.txt'));
      await log.parent.create();
      await log.writeAsString(
        'BYldRequestDepotManifest(App: 50, Depot: 70, Manifest: 100)\n',
      );
      final requests = <ManifestRequest>[];
      final monitor = ManifestMonitor(
        tasks: TaskCenter(),
        interval: const Duration(days: 1),
        pacing: Duration.zero,
        download: (request, task) async {
          requests.add(request);
        },
      );
      addTearDown(monitor.dispose);
      await monitor.start(temp.path);
      await log.writeAsString(
        'BYldRequestDepotManifest(App: 50, Depot: 71, Manifest: 200)\n'
        'BYldRequestDepotManifest(App: 50, Depot: 71, Manifest: 200)\n',
        mode: FileMode.append,
      );
      await monitor.poll();
      await Future<void>.delayed(Duration.zero);
      expect(requests.map((r) => r.depotId), [71]);
      monitor.stop();
      expect(monitor.isRunning, false);
    },
  );
}
