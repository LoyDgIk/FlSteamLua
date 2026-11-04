import 'dart:typed_data';

import 'package:fl_steam_lua/features/library/kv1.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KV1 text', () {
    test(
      'parses nested library folders, comments, BOM and conditional values',
      () {
        final parsed = Kv1.parse(
          '\ufeff'
          '''
// Steam library folders
"libraryfolders"
{
  "0" { "path" "C:\\\\Program Files (x86)\\\\Steam" }
  "1" { "path" "D:/Games/Steam" "apps" { "570" "123" } }
  platform windows [WIN32]
  duplicate old
  duplicate new // retain the last declaration
}
''',
        );
        final folders = parsed['libraryfolders'] as Map<String, dynamic>;
        expect((folders['0'] as Map)['path'], r'C:\Program Files (x86)\Steam');
        expect((folders['1'] as Map)['apps'], {'570': '123'});
        expect(folders['platform'], 'windows');
        expect(folders['duplicate'], 'new');
      },
    );

    test(
      'preserves unescaped Windows paths and handles quote/backslash escapes',
      () {
        final parsed = Kv1.parse(
          r'path "C:\temp\newgame" quoted "say \"hello\""',
        );
        expect(parsed['path'], r'C:\temp\newgame');
        expect(parsed['quoted'], 'say "hello"');
      },
    );

    test(
      'writer roundtrips text without losing non-ASCII or string contents',
      () {
        final expected = <String, dynamic>{
          'users': <String, dynamic>{
            '76561198000000000': <String, dynamic>{
              'AccountName': 'player',
              'PersonaName': '\u6e38\u620f\u73a9\u5bb6',
              'path': r'E:\Steam\"quoted"',
              'MostRecent': '1',
            },
          },
        };
        expect(Kv1.parse(Kv1.stringify(expected)), expected);
      },
    );

    for (final input in [
      '"missing"',
      '{ "key" "value" }',
      'a { b c',
      'a "unterminated',
      'a b }',
    ]) {
      test('rejects malformed text: $input', () {
        expect(() => Kv1.parse(input), throwsFormatException);
      });
    }
  });

  group('KV1 binary', () {
    test('roundtrips nested strings and numeric types', () {
      final expected = <String, dynamic>{
        'entry': <String, dynamic>{
          'name': '\u6d4b\u8bd5',
          'int32': -123,
          'int64': -0x100000000,
          'float': 1.25,
          'uint64': BigInt.parse('18446744073709551615'),
        },
      };
      expect(Kv1.parseBinary(Kv1.encodeBinary(expected)), expected);
    });

    test('decodes pointers, colors and length-prefixed UTF-16 strings', () {
      final bytes = Uint8List.fromList([
        4,
        112,
        0,
        0x78,
        0x56,
        0x34,
        0x12,
        6,
        99,
        0,
        0x01,
        0x02,
        0x03,
        0xff,
        5,
        119,
        0,
        3,
        0,
        0x60,
        0x4f,
        0x7d,
        0x59,
        0,
        0,
        11,
      ]);
      expect(Kv1.parseBinary(bytes), {
        'p': 0x12345678,
        'c': 0xff030201,
        'w': '\u4f60\u597d',
      });
    });

    test('duplicate binary keys use the last value', () {
      expect(
        Kv1.parseBinary(
          Uint8List.fromList([1, 97, 0, 111, 0, 1, 97, 0, 110, 0, 8]),
        ),
        {'a': 'n'},
      );
    });

    for (final bytes in <List<int>>[
      [],
      [1, 97],
      [1, 97, 0, 98],
      [2, 97, 0, 1, 2, 3],
      [0, 97, 0, 8],
      [8, 1],
      [99, 97, 0, 8],
    ]) {
      test('rejects malformed binary $bytes', () {
        expect(
          () => Kv1.parseBinary(Uint8List.fromList(bytes)),
          throwsFormatException,
        );
      });
    }

    test('rejects values that cannot be represented', () {
      expect(() => Kv1.encodeBinary({'bad': null}), throwsArgumentError);
      expect(
        () => Kv1.encodeBinary({'bad': BigInt.one << 64}),
        throwsArgumentError,
      );
      expect(
        () => Kv1.encodeBinary({'bad': 'nul\u0000value'}),
        throwsArgumentError,
      );
    });
  });
}
