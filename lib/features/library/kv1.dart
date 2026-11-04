import 'dart:convert';
import 'dart:typed_data';

/// Valve KeyValues 1 codecs used by Steam's local configuration files.
abstract final class Kv1 {
  static Map<String, dynamic> parse(String text) => _TextReader(text).read();

  static String stringify(Map<String, dynamic> values) {
    final output = StringBuffer();
    void write(Map<String, dynamic> entries, int depth) {
      final indent = '\t' * depth;
      for (final entry in entries.entries) {
        final key = _quote(entry.key);
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          output.writeln('$indent$key');
          output.writeln('$indent{');
          write(value, depth + 1);
          output.writeln('$indent}');
        } else if (value is String ||
            value is num ||
            value is BigInt ||
            value is bool) {
          final scalar = value is bool ? (value ? '1' : '0') : value.toString();
          output.writeln('$indent$key\t\t${_quote(scalar)}');
        } else {
          throw ArgumentError.value(
            value,
            entry.key,
            'Unsupported KeyValues value',
          );
        }
      }
    }

    write(values, 0);
    return output.toString();
  }

  /// Binary keys/strings are UTF-8; UInt64 values decode to [BigInt].
  static Map<String, dynamic> parseBinary(Uint8List bytes) =>
      _BinaryReader(bytes).read();

  /// Encodes nested maps, strings, ints, doubles, bools and unsigned [BigInt]s.
  static Uint8List encodeBinary(Map<String, dynamic> values) {
    final builder = BytesBuilder(copy: false);
    void string(String value) {
      if (value.contains('\u0000')) {
        throw ArgumentError.value(
          value,
          'value',
          'Binary strings cannot contain NUL',
        );
      }
      builder.add(utf8.encode(value));
      builder.addByte(0);
    }

    void integer(int value, int width) {
      final data = ByteData(width);
      if (width == 4) {
        data.setInt32(0, value, Endian.little);
      } else {
        data.setInt64(0, value, Endian.little);
      }
      builder.add(data.buffer.asUint8List());
    }

    void write(Map<String, dynamic> entries, int depth) {
      if (depth > 128) {
        throw ArgumentError('KeyValues nesting exceeds 128 levels');
      }
      for (final entry in entries.entries) {
        final value = entry.value;
        final int type;
        if (value is Map<String, dynamic>) {
          type = 0;
        } else if (value is String) {
          type = 1;
        } else if (value is bool) {
          type = 2;
        } else if (value is int) {
          type = value >= -0x80000000 && value <= 0x7fffffff ? 2 : 10;
        } else if (value is double) {
          type = 3;
        } else if (value is BigInt &&
            value >= BigInt.zero &&
            value.bitLength <= 64) {
          type = 7;
        } else {
          throw ArgumentError.value(
            value,
            entry.key,
            'Unsupported binary KeyValues value',
          );
        }
        builder.addByte(type);
        string(entry.key);
        switch (type) {
          case 0:
            write(value as Map<String, dynamic>, depth + 1);
          case 1:
            string(value as String);
          case 2:
            integer(value is bool ? (value ? 1 : 0) : value as int, 4);
          case 3:
            final data = ByteData(4)
              ..setFloat32(0, value as double, Endian.little);
            builder.add(data.buffer.asUint8List());
          case 7:
            var number = value as BigInt;
            for (var i = 0; i < 8; i++) {
              builder.addByte((number & BigInt.from(255)).toInt());
              number >>= 8;
            }
          case 10:
            integer(value as int, 8);
        }
      }
      builder.addByte(8);
    }

    write(values, 0);
    return builder.takeBytes();
  }

  static String _quote(String text) =>
      '"${text.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}

class _Token {
  const _Token(this.value, {this.quoted = false});
  final String value;
  final bool quoted;
  bool get isCondition =>
      !quoted && value.startsWith('[') && value.endsWith(']');
}

class _TextReader {
  _TextReader(this.text);
  final String text;
  int offset = 0;
  _Token? pending;

  Map<String, dynamic> read() => _block(0, false);

  Map<String, dynamic> _block(int depth, bool nested) {
    if (depth > 128) _error('KeyValues nesting exceeds 128 levels');
    final result = <String, dynamic>{};
    while (true) {
      final key = _next();
      if (key == null) {
        if (nested) _error('Missing closing brace');
        return result;
      }
      if (!key.quoted && key.value == '}') {
        if (!nested) _error('Unexpected closing brace');
        return result;
      }
      if (key.isCondition) continue;
      if (!key.quoted && key.value == '{') {
        _error('Expected a key before opening brace');
      }
      final value = _next();
      if (value == null) _error('Missing value for ${key.value}');
      if (!value.quoted && value.value == '}') {
        _error('Missing value for ${key.value}');
      }
      result[key.value] = !value.quoted && value.value == '{'
          ? _block(depth + 1, true)
          : value.value;
      final condition = _next();
      if (condition != null && !condition.isCondition) pending = condition;
    }
  }

  _Token? _next() {
    if (pending != null) {
      final token = pending;
      pending = null;
      return token;
    }
    _space();
    if (offset == text.length) return null;
    final char = text[offset++];
    if (char == '{' || char == '}') return _Token(char);
    if (char == '"') {
      final value = StringBuffer();
      while (offset < text.length) {
        final current = text[offset++];
        if (current == '"') return _Token(value.toString(), quoted: true);
        if (current == '\\' && offset < text.length) {
          final next = text[offset];
          // Steam paths commonly contain unescaped backslashes such as C:\temp.
          if (next == '"' || next == '\\') {
            value.write(next);
            offset++;
            continue;
          }
        }
        value.write(current);
      }
      _error('Unterminated quoted string');
    }
    final start = offset - 1;
    while (offset < text.length) {
      final c = text[offset];
      if (_isSpace(c) || c == '{' || c == '}') break;
      if (c == '/' && offset + 1 < text.length && text[offset + 1] == '/') {
        break;
      }
      offset++;
    }
    return _Token(text.substring(start, offset));
  }

  void _space() {
    while (offset < text.length) {
      if (_isSpace(text[offset]) ||
          (offset == 0 && text.codeUnitAt(offset) == 0xfeff)) {
        offset++;
      } else if (text[offset] == '/' &&
          offset + 1 < text.length &&
          text[offset + 1] == '/') {
        offset += 2;
        while (offset < text.length && text[offset] != '\n') {
          offset++;
        }
      } else {
        return;
      }
    }
  }

  bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\r' || c == '\n';
  Never _error(String message) => throw FormatException(message, text, offset);
}

class _BinaryReader {
  _BinaryReader(this.bytes) : data = ByteData.sublistView(bytes);
  final Uint8List bytes;
  final ByteData data;
  int offset = 0;

  Map<String, dynamic> read() {
    final result = _block(0);
    if (offset != bytes.length) {
      _error('Unexpected bytes after root end marker');
    }
    return result;
  }

  Map<String, dynamic> _block(int depth) {
    if (depth > 128) _error('KeyValues nesting exceeds 128 levels');
    final values = <String, dynamic>{};
    while (true) {
      _require(1);
      final type = bytes[offset++];
      if (type == 8 || type == 11) return values;
      final key = _string();
      final dynamic value;
      switch (type) {
        case 0:
          value = _block(depth + 1);
        case 1:
          value = _string();
        case 2:
          _require(4);
          value = data.getInt32(offset, Endian.little);
          offset += 4;
        case 3:
          _require(4);
          value = data.getFloat32(offset, Endian.little);
          offset += 4;
        case 4:
        case 6:
          _require(4);
          value = data.getUint32(offset, Endian.little);
          offset += 4;
        case 5:
          value = _wideString();
        case 7:
          _require(8);
          var number = BigInt.zero;
          for (var i = 7; i >= 0; i--) {
            number = (number << 8) | BigInt.from(bytes[offset + i]);
          }
          offset += 8;
          value = number;
        case 10:
          _require(8);
          value = data.getInt64(offset, Endian.little);
          offset += 8;
        default:
          _error('Unsupported binary KeyValues type $type');
      }
      values[key] = value;
    }
  }

  String _string() {
    final start = offset;
    while (offset < bytes.length && bytes[offset] != 0) {
      offset++;
    }
    if (offset == bytes.length) _error('Unterminated binary string');
    final result = utf8.decode(bytes.sublist(start, offset));
    offset++;
    return result;
  }

  String _wideString() {
    _require(2);
    final length = data.getUint16(offset, Endian.little);
    offset += 2;
    _require(length * 2);
    final units = List<int>.generate(
      length,
      (index) => data.getUint16(offset + index * 2, Endian.little),
    );
    offset += length * 2;
    if (units.isNotEmpty && units.last == 0) units.removeLast();
    return String.fromCharCodes(units);
  }

  void _require(int count) {
    if (offset + count > bytes.length) {
      _error('Truncated binary KeyValues value');
    }
  }

  Never _error(String message) => throw FormatException(message, bytes, offset);
}
