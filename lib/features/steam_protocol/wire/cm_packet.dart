import 'dart:io';
import 'dart:typed_data';

import 'protobuf.dart';

class CmPacket {
  CmPacket(this.messageType, this.header, this.body);
  final int messageType;
  final ProtoReader header;
  final Uint8List body;

  static Uint8List encode(
    int messageType,
    ProtoWriter header,
    ProtoWriter body,
  ) {
    final headerBytes = header.toBytes();
    final bodyBytes = body.toBytes();
    final prefix = ByteData(8)
      ..setUint32(0, messageType | 0x80000000, Endian.little)
      ..setUint32(4, headerBytes.length, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(prefix.buffer.asUint8List())
          ..add(headerBytes)
          ..add(bodyBytes))
        .takeBytes();
  }

  static Iterable<CmPacket> decode(List<int> value) sync* {
    final bytes = Uint8List.fromList(value);
    if (bytes.length < 8) {
      throw const FormatException('Truncated Steam CM packet');
    }
    final data = ByteData.sublistView(bytes);
    final rawType = data.getUint32(0, Endian.little);
    if (rawType & 0x80000000 == 0) return;
    final headerLength = data.getUint32(4, Endian.little);
    if (headerLength > bytes.length - 8) {
      throw const FormatException('Invalid Steam CM header length');
    }
    final packet = CmPacket(
      rawType & 0x7fffffff,
      ProtoReader(Uint8List.sublistView(bytes, 8, 8 + headerLength)),
      Uint8List.sublistView(bytes, 8 + headerLength),
    );
    if (packet.messageType != 1) {
      yield packet;
      return;
    }
    final multi = ProtoReader(packet.body);
    var packed = multi.bytesValue(2);
    if (packed == null) {
      throw const FormatException('Steam Multi packet has no payload');
    }
    final expectedSize = multi.intValue(1);
    if (expectedSize != 0) {
      if (expectedSize > 64 * 1024 * 1024) {
        throw const FormatException('Steam Multi packet is too large');
      }
      packed = Uint8List.fromList(gzip.decode(packed));
      if (packed.length != expectedSize) {
        throw const FormatException('Steam Multi packet length mismatch');
      }
    }
    var offset = 0;
    while (offset < packed.length) {
      if (offset + 4 > packed.length) {
        throw const FormatException('Truncated Steam Multi entry');
      }
      final length = ByteData.sublistView(
        packed,
      ).getUint32(offset, Endian.little);
      offset += 4;
      if (length > packed.length - offset) {
        throw const FormatException('Invalid Steam Multi entry length');
      }
      yield* decode(Uint8List.sublistView(packed, offset, offset + length));
      offset += length;
    }
  }
}
