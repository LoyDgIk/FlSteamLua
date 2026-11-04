import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_steam_lua/features/achievements/binary_stats_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<int> string(String value) => [...utf8.encode(value), 0];
  List<int> field(String key, String value) => [
    1,
    ...string(key),
    ...string(value),
  ];
  List<int> object(String key, List<int> children) => [
    0,
    ...string(key),
    ...children,
    8,
  ];

  test('parses binary achievement schema and localized fields', () {
    final bytes = Uint8List.fromList([
      ...object(
        '10',
        object(
          'stats',
          object('0', [
            ...field('type', 'achievements'),
            ...object(
              'bits',
              object('0', [
                ...field('name', 'first'),
                ...object(
                  'display',
                  object('name', [
                    ...field('english', 'First'),
                    ...field('schinese', '第一步'),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
      8,
    ]);
    final schema = BinaryStatsSchema.decode(bytes);
    final achievement = schema.achievementDefinitions(10)['first']!;
    final display = achievement['display'] as Map;
    expect(BinaryStatsSchema.localized(display['name'], 'schinese', ''), '第一步');
    expect(BinaryStatsSchema.localized(display['name'], 'german', ''), 'First');
    expect(schema.stats(20), isEmpty);
  });

  test('rejects truncated and unknown binary schema types', () {
    expect(
      () => BinaryStatsSchema.decode(Uint8List.fromList([0, 97, 0, 1, 98])),
      throwsFormatException,
    );
    expect(
      () => BinaryStatsSchema.decode(Uint8List.fromList([99, 97, 0])),
      throwsFormatException,
    );
  });
}
