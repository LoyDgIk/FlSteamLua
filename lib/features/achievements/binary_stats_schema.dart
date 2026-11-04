import 'dart:convert';
import 'dart:typed_data';

/// Valve binary KV1 reader for the locally cached user stats schema.
class BinaryStatsSchema {
  BinaryStatsSchema(this.root);
  final Map<String, dynamic> root;

  factory BinaryStatsSchema.decode(Uint8List bytes) =>
      BinaryStatsSchema(_BinaryKvReader(bytes).readObject());

  Map<String, dynamic> stats(int appId) {
    final app = root['$appId'];
    if (app is! Map<String, dynamic>) return const {};
    final value = app['stats'];
    return value is Map<String, dynamic> ? value : const {};
  }

  Map<String, Map<String, dynamic>> achievementDefinitions(int appId) {
    final result = <String, Map<String, dynamic>>{};
    for (final stat in stats(appId).values.whereType<Map<String, dynamic>>()) {
      final type = stat['type_int'] ?? stat['type'];
      if (![
        4,
        5,
        '4',
        '5',
        'achievements',
        'groupachievements',
      ].contains(type is String ? type.toLowerCase() : type)) {
        continue;
      }
      final bits = stat['bits'];
      if (bits is! Map<String, dynamic>) continue;
      for (final bit in bits.values.whereType<Map<String, dynamic>>()) {
        final id = bit['name'];
        if (id is String && id.isNotEmpty) result[id] = bit;
      }
    }
    return result;
  }

  static String localized(dynamic value, String language, String fallback) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      final text = value[language] ?? value['english'];
      if (text is String && text.isNotEmpty) return text;
    }
    return fallback;
  }
}

class _BinaryKvReader {
  _BinaryKvReader(this.bytes) : data = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData data;
  int offset = 0;

  void require(int length) {
    if (offset + length > bytes.length) {
      throw const FormatException('Truncated Steam stats schema');
    }
  }

  String string() {
    final start = offset;
    while (offset < bytes.length && bytes[offset] != 0) {
      offset++;
    }
    require(1);
    final value = utf8.decode(
      bytes.sublist(start, offset),
      allowMalformed: true,
    );
    offset++;
    return value;
  }

  Map<String, dynamic> readObject([int depth = 0]) {
    if (depth > 64) {
      throw const FormatException('Steam stats schema is too deeply nested');
    }
    final result = <String, dynamic>{};
    while (offset < bytes.length) {
      final type = bytes[offset++];
      if (type == 8 || type == 11) return result;
      final key = string();
      dynamic value;
      switch (type) {
        case 0:
          value = readObject(depth + 1);
        case 1:
          value = string();
        case 2:
          require(4);
          value = data.getInt32(offset, Endian.little);
          offset += 4;
        case 3:
          require(4);
          value = data.getFloat32(offset, Endian.little);
          offset += 4;
        case 4 || 6:
          require(4);
          value = data.getUint32(offset, Endian.little);
          offset += 4;
        case 5:
          require(2);
          final length = data.getUint16(offset, Endian.little);
          offset += 2;
          require(length * 2);
          final codes = List.generate(
            length,
            (i) => data.getUint16(offset + i * 2, Endian.little),
          );
          offset += length * 2;
          value = String.fromCharCodes(codes.where((c) => c != 0));
        case 7:
          require(8);
          value = data.getUint64(offset, Endian.little);
          offset += 8;
        case 10:
          require(8);
          value = data.getInt64(offset, Endian.little);
          offset += 8;
        default:
          throw FormatException('Unsupported binary KV1 type $type');
      }
      result[key] = value;
    }
    if (depth != 0) {
      throw const FormatException('Unterminated Steam stats schema');
    }
    return result;
  }
}
