import 'dart:convert';
import 'dart:typed_data';

/// Wire subset used by Steam CM messages. Field numbers follow SteamDatabase's
/// Protobufs/steam schemas; unknown fields are retained by [ProtoReader].
class ProtoWriter {
  ProtoWriter();
  ProtoWriter.fromBytes(List<int> bytes) {
    _bytes.add(bytes);
  }
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void _unsigned(Object value) {
    var number = value is BigInt ? value : BigInt.from(value as int);
    if (number.isNegative) number = number.toUnsigned(64);
    do {
      var byte = (number & BigInt.from(127)).toInt();
      number >>= 7;
      if (number != BigInt.zero) byte |= 128;
      _bytes.addByte(byte);
    } while (number != BigInt.zero);
  }

  void varint(int field, Object value) {
    _unsigned(field << 3);
    _unsigned(value);
  }

  void fixed64(int field, BigInt value) {
    _unsigned((field << 3) | 1);
    for (var i = 0; i < 8; i++) {
      _bytes.addByte(((value >> (i * 8)) & BigInt.from(255)).toInt());
    }
  }

  void fixed32(int field, int value) {
    _unsigned((field << 3) | 5);
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    _bytes.add(data.buffer.asUint8List());
  }

  void string(int field, String value) => bytes(field, utf8.encode(value));
  void bytes(int field, List<int> value) {
    _unsigned((field << 3) | 2);
    _unsigned(value.length);
    _bytes.add(value);
  }

  void message(int field, ProtoWriter value) => bytes(field, value.toBytes());
  void packedVarints(int field, Iterable<int> values) {
    final packed = ProtoWriter();
    for (final value in values) {
      packed._unsigned(value);
    }
    bytes(field, packed.toBytes());
  }

  Uint8List toBytes() => _bytes.toBytes();
}

class ProtoField {
  const ProtoField(this.number, this.wireType, this.value);
  final int number;
  final int wireType;
  final Object value;
}

class ProtoReader {
  ProtoReader(List<int> bytes) : fields = _read(Uint8List.fromList(bytes));
  final List<ProtoField> fields;

  ProtoField? field(int number) {
    for (final value in fields) {
      if (value.number == number) return value;
    }
    return null;
  }

  int intValue(int number, {int defaultValue = 0}) {
    final value = field(number)?.value;
    return value is BigInt ? value.toInt() : defaultValue;
  }

  BigInt bigInt(int number, {BigInt? defaultValue}) {
    final value = field(number)?.value;
    return value is BigInt ? value : defaultValue ?? BigInt.zero;
  }

  Uint8List? bytesValue(int number) {
    final value = field(number)?.value;
    return value is Uint8List ? value : null;
  }

  String stringValue(int number, {String defaultValue = ''}) {
    final bytes = bytesValue(number);
    return bytes == null ? defaultValue : utf8.decode(bytes);
  }

  Iterable<ProtoReader> messages(int number) sync* {
    for (final value in fields) {
      if (value.number == number && value.value is Uint8List) {
        yield ProtoReader(value.value as Uint8List);
      }
    }
  }

  static List<ProtoField> _read(Uint8List data) {
    final result = <ProtoField>[];
    var offset = 0;
    BigInt varint() {
      var value = BigInt.zero;
      for (var shift = 0; shift < 70; shift += 7) {
        if (offset >= data.length) {
          throw const FormatException('Truncated protobuf varint');
        }
        final byte = data[offset++];
        if (shift == 63 && byte > 1) {
          throw const FormatException('Protobuf varint exceeds uint64');
        }
        value |= BigInt.from(byte & 127) << shift;
        if (byte & 128 == 0) return value;
      }
      throw const FormatException('Protobuf varint exceeds uint64');
    }

    Uint8List take(int length) {
      if (length < 0 || offset + length > data.length) {
        throw const FormatException('Truncated protobuf field');
      }
      final bytes = Uint8List.sublistView(data, offset, offset + length);
      offset += length;
      return bytes;
    }

    while (offset < data.length) {
      final tag = varint().toInt();
      final number = tag >> 3;
      final wire = tag & 7;
      if (number == 0) {
        throw const FormatException('Invalid protobuf field number');
      }
      Object value;
      switch (wire) {
        case 0:
          value = varint();
        case 1:
          final bytes = take(8);
          var number = BigInt.zero;
          for (var i = 0; i < bytes.length; i++) {
            number |= BigInt.from(bytes[i]) << (i * 8);
          }
          value = number;
        case 2:
          value = take(varint().toInt());
        case 5:
          value = BigInt.from(
            ByteData.sublistView(take(4)).getUint32(0, Endian.little),
          );
        default:
          throw FormatException('Unsupported protobuf wire type $wire');
      }
      result.add(ProtoField(number, wire, value));
    }
    return result;
  }
}
