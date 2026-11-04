import 'dart:convert';
import 'dart:typed_data';

// A restricted protobuf adapter for the Authentication service wire messages.
class AuthProtoWriter {
  final BytesBuilder _output = BytesBuilder(copy: false);

  void integer(int field, Object value) {
    _varint(BigInt.from(field << 3));
    _varint(value is BigInt ? value : BigInt.from(value as int));
  }

  void fixed64(int field, BigInt value) {
    _varint(BigInt.from((field << 3) | 1));
    var remaining = value;
    for (var i = 0; i < 8; i++) {
      _output.addByte((remaining & BigInt.from(255)).toInt());
      remaining >>= 8;
    }
  }

  void string(int field, String value) => bytes(field, utf8.encode(value));

  void bytes(int field, List<int> value) {
    _varint(BigInt.from((field << 3) | 2));
    _varint(BigInt.from(value.length));
    _output.add(value);
  }

  void float32(int field, double value) {
    _varint(BigInt.from((field << 3) | 5));
    final bytes = ByteData(4)..setFloat32(0, value, Endian.little);
    _output.add(bytes.buffer.asUint8List());
  }

  void _varint(BigInt value) {
    var remaining = value;
    if (remaining < BigInt.zero) remaining = remaining.toUnsigned(64);
    while (remaining >= BigInt.from(128)) {
      _output.addByte((remaining & BigInt.from(127)).toInt() | 128);
      remaining >>= 7;
    }
    _output.addByte(remaining.toInt());
  }

  Uint8List toBytes() => _output.toBytes();
}

class AuthProtoReader {
  AuthProtoReader(List<int> input) : _input = Uint8List.fromList(input) {
    while (_offset < _input.length) {
      final tag = _varint().toInt();
      final number = tag >> 3;
      if (number == 0) throw const FormatException('Invalid protobuf field');
      final wire = tag & 7;
      final Object value;
      switch (wire) {
        case 0:
          value = _varint();
        case 1:
          final bytes = _take(8);
          var integer = BigInt.zero;
          for (var i = 7; i >= 0; i--) {
            integer = (integer << 8) | BigInt.from(bytes[i]);
          }
          value = integer;
        case 2:
          value = _take(_varint().toInt());
        case 5:
          value = _take(4);
        default:
          throw FormatException('Unsupported protobuf wire type $wire');
      }
      _fields.putIfAbsent(number, () => []).add(value);
    }
  }

  final Uint8List _input;
  final Map<int, List<Object>> _fields = {};
  int _offset = 0;

  BigInt integer(int field) {
    final value = _fields[field]?.firstOrNull;
    return value is BigInt ? value : BigInt.zero;
  }

  Uint8List bytes(int field) {
    final value = _fields[field]?.firstOrNull;
    return value is Uint8List ? value : Uint8List(0);
  }

  String string(int field) => utf8.decode(bytes(field));

  double float32(int field, {double fallback = 0}) {
    final value = bytes(field);
    return value.length == 4
        ? ByteData.sublistView(value).getFloat32(0, Endian.little)
        : fallback;
  }

  Iterable<AuthProtoReader> messages(int field) sync* {
    for (final value in _fields[field] ?? <Object>[]) {
      if (value is Uint8List) yield AuthProtoReader(value);
    }
  }

  Uint8List _take(int length) {
    if (length < 0 || length > _input.length - _offset) {
      throw const FormatException('Truncated protobuf message');
    }
    final bytes = Uint8List.sublistView(_input, _offset, _offset + length);
    _offset += length;
    return bytes;
  }

  BigInt _varint() {
    var result = BigInt.zero;
    for (var shift = 0; shift < 70; shift += 7) {
      final byte = _take(1)[0];
      result |= BigInt.from(byte & 127) << shift;
      if (byte < 128) return result;
    }
    throw const FormatException('Protobuf varint exceeds 64 bits');
  }
}
