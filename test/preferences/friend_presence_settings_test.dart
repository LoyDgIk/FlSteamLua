import 'dart:convert';
import 'dart:io';

import 'package:fl_steam_lua/features/preferences/friend_presence_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late Directory steam;
  late File config;
  late FriendPresenceSettings settings;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('friend-presence-test-');
    steam = await Directory.fromUri(temporary.uri.resolve('Steam/')).create();
    config = File.fromUri(steam.uri.resolve('opensteamtool.toml'));
    settings = FriendPresenceSettings();
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'missing file defaults enabled without creating configuration',
    () async {
      expect(await settings.read(steam.path), isTrue);
      expect(await config.exists(), isFalse);
    },
  );

  test('missing section or key defaults enabled', () async {
    for (final source in [
      '[cloud]\ndisplay = "none"\n',
      '[presence]\n# display = "none"\nother = false\n',
    ]) {
      await config.writeAsString(source);
      expect(await settings.read(steam.path), isTrue);
    }
  });

  test('reads section, key and known values case-insensitively', () async {
    for (final fixture in [
      ('[presence]\ndisplay = "none"\n', false),
      ('[PRESENCE] # note\n  DISPLAY = \'NoNe\' # hidden\n', false),
      ('[Presence]\nDisplay = "SpAcEwAr"\n', true),
      ('[cloud]\ndisplay = "none"\n[presence]\ndisplay = "spacewar"', true),
    ]) {
      await config.writeAsString(fixture.$1);
      expect(await settings.read(steam.path), fixture.$2);
    }
  });

  test('preserves UTF-8 BOM, CRLF, comments and all other values', () async {
    const source =
        '# \u4e2d\u6587\r\n'
        '[cloud]\r\n'
        'display = "none" # untouched\r\n'
        '[presence] # broadcast\r\n'
        '\tDISPLAY  =  "SPACEWAR"  # keep "quotes"\r\n'
        'title = "a#b"\r\n'
        '[other]\r\n'
        'display="spacewar"\r\n';
    final original = [0xef, 0xbb, 0xbf, ...utf8.encode(source)];
    await config.writeAsBytes(original);
    await settings.write(steam.path, false);
    expect(await config.readAsBytes(), [
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode(source.replaceFirst('"SPACEWAR"', '"none"')),
    ]);
    expect(await File('${config.path}.bak').readAsBytes(), original);
    expect(await settings.read(steam.path), isFalse);
  });

  test(
    'preserves literal quotes, inline comment and no final newline',
    () async {
      const source = "[presence]\n display='none'\t# keep # all";
      await config.writeAsString(source);
      await settings.write(steam.path, true);
      expect(
        await config.readAsString(),
        source.replaceFirst("'none'", "'spacewar'"),
      );
    },
  );

  test('inserts missing key before following section with CRLF', () async {
    const source = '[presence]\r\n# note\r\n[cloud]\r\ndisplay="none"\r\n';
    await config.writeAsString(source);
    await settings.write(steam.path, false);
    expect(
      await config.readAsString(),
      '[presence]\r\n# note\r\ndisplay = "none"\r\n'
      '[cloud]\r\ndisplay="none"\r\n',
    );
  });

  test(
    'appends missing section without changing existing final newline',
    () async {
      for (final ending in ['', '\n', '\r\n']) {
        final source =
            '[cloud]${ending.isEmpty ? '\n' : ending}'
            'enabled = false$ending';
        await config.writeAsString(source);
        await settings.write(steam.path, true);
        final result = await config.readAsString();
        expect(result, startsWith(source));
        expect(result, contains('[presence]'));
        expect(result, contains('display = "spacewar"'));
        expect(result.endsWith('\n'), ending.isNotEmpty);
        expect(await settings.read(steam.path), isTrue);
      }
    },
  );

  test('appends key to final section without a terminal newline', () async {
    await config.writeAsString('[presence]');
    await settings.write(steam.path, false);
    final newline = Platform.isWindows ? '\r\n' : '\n';
    expect(await config.readAsString(), '[presence]${newline}display = "none"');
  });

  test('creates absent file in existing directory without a backup', () async {
    await settings.write(steam.path, false);
    expect(await settings.read(steam.path), isFalse);
    expect(await File('${config.path}.bak').exists(), isFalse);
    expect(
      (await steam.list().toList()).map((entry) => entry.uri.pathSegments.last),
      ['opensteamtool.toml'],
    );
  });

  test(
    'backup contains the immediately previous successful configuration',
    () async {
      await config.writeAsString('[presence]\ndisplay="spacewar"\n');
      await settings.write(steam.path, false);
      final previous = await config.readAsBytes();
      await settings.write(steam.path, true);
      expect(await File('${config.path}.bak').readAsBytes(), previous);
      expect(await settings.read(steam.path), isTrue);
    },
  );

  test('rejects empty, missing and non-directory Steam paths', () async {
    for (final invalid in ['', '   ']) {
      await expectLater(settings.read(invalid), throwsArgumentError);
      await expectLater(settings.write(invalid, false), throwsArgumentError);
    }
    final missing = Directory.fromUri(temporary.uri.resolve('missing/'));
    final ordinaryFile = File.fromUri(temporary.uri.resolve('file'));
    await ordinaryFile.writeAsString('unchanged');
    for (final invalid in [missing.path, ordinaryFile.path]) {
      await expectLater(
        settings.read(invalid),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        settings.write(invalid, false),
        throwsA(isA<FileSystemException>()),
      );
    }
    expect(await missing.exists(), isFalse);
    expect(await ordinaryFile.readAsString(), 'unchanged');
  });

  test('invalid UTF-8 propagates and leaves existing file untouched', () async {
    await config.writeAsBytes([0xff]);
    await expectLater(settings.read(steam.path), throwsFormatException);
    await expectLater(settings.write(steam.path, true), throwsFormatException);
    expect(await config.readAsBytes(), [0xff]);
    expect(await File('${config.path}.bak').exists(), isFalse);
  });

  test(
    'backup failure preserves configuration and removes temporary file',
    () async {
      const source = '[presence]\ndisplay = "spacewar"\n';
      await config.writeAsString(source);
      await Directory('${config.path}.bak').create();
      await expectLater(
        settings.write(steam.path, false),
        throwsA(isA<FileSystemException>()),
      );
      expect(await config.readAsString(), source);
      expect(
        (await steam.list().toList()).whereType<File>().map(
          (file) => file.path,
        ),
        [config.path],
      );
    },
  );
}
