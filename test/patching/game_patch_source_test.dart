import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/features/patching/game_patch_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  test('VM table parses typed patches and keeps VBS global', () {
    final table = GamePatchSourceService.parseVmText('''
123-2626638: https://example.test/vm.zip
123-V38: https://example.test/v38.zip
123-fix: https://example.test/fix.zip
123-crack: https://example.test/crack.zip
VBS: https://example.test/vbs.zip
456-fix: https://example.test/other.zip
not a patch line
''');
    expect(table.forApp(123).map((option) => option.kind), [
      GamePatchKind.vm,
      GamePatchKind.v38,
      GamePatchKind.fix,
      GamePatchKind.crack,
      GamePatchKind.vbs,
    ]);
    expect(table.forApp(123).first.buildId, '2626638');
    expect(table.forApp(456).map((option) => option.kind), [
      GamePatchKind.fix,
      GamePatchKind.vbs,
    ]);
  });

  test('download extracts into the application folder only', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'flsteam-patch-source-',
    );
    final paths = AppPaths(temporary.path);
    final archive = Archive()
      ..addFile(ArchiveFile('readme.txt', 8, utf8.encode('fixture!')));
    final client = MockClient(
      (request) async => http.Response.bytes(
        ZipEncoder().encode(archive),
        200,
        headers: const {'content-type': 'application/zip'},
      ),
    );
    final service = GamePatchSourceService(paths: paths, client: client);
    try {
      final result = await service.downloadAndExtract(
        123,
        GamePatchOption(
          kind: GamePatchKind.vm,
          buildId: '2626638',
          url: Uri.parse('https://example.test/patch.zip'),
        ),
      );
      expect(result.files, 1);
      final extracted = File(
        '${result.directory}${Platform.pathSeparator}readme.txt',
      );
      expect(await extracted.readAsString(), 'fixture!');
      expect(
        p.isWithin(
          p.join(paths.root, 'downloads', 'patches'),
          Directory(result.directory).path,
        ),
        isTrue,
      );
    } finally {
      service.close();
      await temporary.delete(recursive: true);
    }
  });
}
