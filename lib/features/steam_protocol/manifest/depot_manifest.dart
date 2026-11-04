import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

// Steam content_manifest.proto wire format:
// https://github.com/SteamDatabase/Protobufs/blob/master/steam/content_manifest.proto
// Container markers and filename crypto interoperate with SteamKit2 DepotManifest.
// https://github.com/SteamRE/SteamKit (LGPL-2.1); this is a Dart implementation.
class DepotManifestChunk {
  const DepotManifestChunk({
    required this.sha,
    required this.crc,
    required this.offset,
    required this.originalSize,
    required this.compressedSize,
  });

  final List<int> sha;
  final int crc;
  final int offset;
  final int originalSize;
  final int compressedSize;
}

class DepotManifestFile {
  const DepotManifestFile({
    required this.fileName,
    required this.size,
    required this.flags,
    this.sha = const [],
    this.fileNameSha = const [],
    this.chunks = const [],
    this.linkTarget = '',
  });

  final String fileName;
  final int size;
  final int flags;
  final List<int> sha;
  final List<int> fileNameSha;
  final List<DepotManifestChunk> chunks;
  final String linkTarget;

  DepotManifestFile _withNames(String name, String target) => DepotManifestFile(
    fileName: name,
    size: size,
    flags: flags,
    sha: sha,
    fileNameSha: fileNameSha,
    chunks: chunks,
    linkTarget: target,
  );
}

class DepotManifest {
  DepotManifest({
    required this.depotId,
    required this.manifestGid,
    required List<DepotManifestFile> files,
    this.creationTime = 0,
    this.filenamesEncrypted = false,
    this.originalSize = 0,
    this.compressedSize = 0,
    this.encryptedCrc = 0,
  }) : _files = List.of(files);

  static const payloadMagic = 0x71f617d0;
  static const metadataMagic = 0x1f4812be;
  static const signatureMagic = 0x1b81b817;
  static const endMagic = 0x32c415ab;
  static const maxManifestBytes = 128 * 1024 * 1024;

  final int depotId;
  final BigInt manifestGid;
  final int creationTime;
  final int originalSize;
  final int compressedSize;
  final int encryptedCrc;
  bool filenamesEncrypted;
  List<DepotManifestFile> _files;
  List<DepotManifestFile> get files => List.unmodifiable(_files);

  factory DepotManifest.parse(List<int> input, {List<int>? depotKey}) {
    if (input.length > maxManifestBytes) {
      throw const FormatException('Depot manifest exceeds 128 MB');
    }
    var bytes = Uint8List.fromList(input);
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final entries = archive.files.where((file) => file.isFile).toList();
      if (entries.length != 1 || entries.single.size > maxManifestBytes) {
        throw const FormatException(
          'A CDN manifest ZIP must contain one manifest',
        );
      }
      bytes = Uint8List.fromList(entries.single.content);
    }
    final data = ByteData.sublistView(bytes);
    List<int>? payload;
    List<int>? metadata;
    var hasSignature = false;
    var hasEnd = false;
    var offset = 0;
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) {
        throw const FormatException('Truncated depot manifest marker');
      }
      final magic = data.getUint32(offset, Endian.little);
      offset += 4;
      if (magic == endMagic) {
        hasEnd = true;
        break;
      }
      if (magic != payloadMagic &&
          magic != metadataMagic &&
          magic != signatureMagic) {
        throw FormatException(
          'Unsupported depot manifest marker 0x${magic.toRadixString(16)}',
        );
      }
      if (offset + 4 > bytes.length) {
        throw const FormatException('Truncated depot manifest section length');
      }
      final length = data.getUint32(offset, Endian.little);
      offset += 4;
      if (length > bytes.length - offset) {
        throw const FormatException('Truncated depot manifest section');
      }
      final section = Uint8List.sublistView(bytes, offset, offset + length);
      offset += length;
      switch (magic) {
        case payloadMagic:
          if (payload != null) {
            throw const FormatException('Duplicate manifest payload');
          }
          payload = section;
        case metadataMagic:
          if (metadata != null) {
            throw const FormatException('Duplicate manifest metadata');
          }
          metadata = section;
        case signatureMagic:
          if (hasSignature) {
            throw const FormatException('Duplicate manifest signature');
          }
          hasSignature = true;
      }
    }
    if (payload == null ||
        metadata == null ||
        !hasSignature ||
        !hasEnd ||
        offset != bytes.length) {
      throw const FormatException(
        'Missing sections or trailing data in depot manifest',
      );
    }
    final info = _Message(metadata);
    final manifest = DepotManifest(
      depotId: info.integer(1),
      manifestGid: info.bigInteger(2),
      creationTime: info.integer(3),
      filenamesEncrypted: info.integer(4) != 0,
      originalSize: info.integer(5),
      compressedSize: info.integer(6),
      encryptedCrc: info.integer(8),
      files: _Message(payload)
          .messages(1)
          .map(
            (file) => DepotManifestFile(
              fileName: file.text(1),
              size: file.integer(2),
              flags: file.integer(3),
              fileNameSha: file.bytes(4),
              sha: file.bytes(5),
              chunks: file
                  .messages(6)
                  .map(
                    (chunk) => DepotManifestChunk(
                      sha: chunk.bytes(1),
                      crc: chunk.integer(2),
                      offset: chunk.integer(3),
                      originalSize: chunk.integer(4),
                      compressedSize: chunk.integer(5),
                    ),
                  )
                  .toList(),
              linkTarget: file.text(7),
            ),
          )
          .toList(),
    );
    if (depotKey != null) manifest.decryptFilenames(depotKey);
    return manifest;
  }

  bool decryptFilenames(List<int> key) {
    if (!filenamesEncrypted) return true;
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'Expected 32 bytes');
    }
    final decrypted = _files
        .map(
          (file) => file._withNames(
            _decryptName(file.fileName, key),
            file.linkTarget.isEmpty ? '' : _decryptName(file.linkTarget, key),
          ),
        )
        .toList();
    decrypted.sort(
      (a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
    );
    _files = decrypted;
    filenamesEncrypted = false;
    return true;
  }

  Uint8List toBytes() {
    final payload = _Writer();
    final chunks = <String>{};
    for (final file in _files) {
      final name = filenamesEncrypted
          ? file.fileName
          : file.fileName.replaceAll('/', r'\');
      final mapping = _Writer()
        ..text(1, name)
        ..integer(2, file.size)
        ..integer(3, file.flags)
        ..bytes(
          4,
          filenamesEncrypted
              ? file.fileNameSha
              : sha1.convert(utf8.encode(name.toLowerCase())).bytes,
        )
        ..bytes(5, file.sha);
      for (final chunk in file.chunks) {
        chunks.add(base64Encode(chunk.sha));
        mapping.bytes(
          6,
          (_Writer()
                ..bytes(1, chunk.sha)
                ..fixed32(2, chunk.crc)
                ..integer(3, chunk.offset)
                ..integer(4, chunk.originalSize)
                ..integer(5, chunk.compressedSize))
              .result(),
        );
      }
      if (file.linkTarget.isNotEmpty) mapping.text(7, file.linkTarget);
      payload.bytes(1, mapping.result());
    }
    final payloadBytes = payload.result();
    final lengthPrefix = _uint32(payloadBytes.length);
    final crc = getCrc32([...lengthPrefix, ...payloadBytes]);
    final metadata =
        (_Writer()
              ..integer(1, depotId)
              ..bigInteger(2, manifestGid)
              ..integer(3, creationTime)
              ..integer(4, filenamesEncrypted ? 1 : 0)
              ..integer(5, originalSize)
              ..integer(6, compressedSize)
              ..integer(7, chunks.length)
              ..integer(8, filenamesEncrypted ? crc : encryptedCrc)
              ..integer(9, filenamesEncrypted ? 0 : crc))
            .result();
    return Uint8List.fromList([
      ..._uint32(payloadMagic),
      ...lengthPrefix,
      ...payloadBytes,
      ..._uint32(metadataMagic),
      ..._uint32(metadata.length),
      ...metadata,
      ..._uint32(signatureMagic),
      0,
      0,
      0,
      0,
      ..._uint32(endMagic),
    ]);
  }

  static String _decryptName(String encoded, List<int> key) {
    try {
      final cipherText = base64Decode(encoded);
      if (cipherText.length < 32 || cipherText.length % 16 != 0) {
        throw const FormatException('Invalid encrypted filename size');
      }
      final aes = AESEngine()
        ..init(false, KeyParameter(Uint8List.fromList(key)));
      final iv = Uint8List(16);
      aes.processBlock(cipherText, 0, iv, 0);
      final cipher =
          PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
            ..init(
              false,
              PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
                ParametersWithIV(KeyParameter(Uint8List.fromList(key)), iv),
                null,
              ),
            );
      final clear = cipher.process(Uint8List.sublistView(cipherText, 16));
      final end = clear.isNotEmpty && clear.last == 0
          ? clear.length - 1
          : clear.length;
      return utf8.decode(clear.sublist(0, end)).replaceAll(r'\', '/');
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Cannot decrypt manifest filename: $error');
    }
  }
}

Uint8List _uint32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

class _Field {
  const _Field(this.number, this.value);
  final int number;
  final Object value;
}

class _Message {
  _Message(List<int> input) {
    final bytes = Uint8List.fromList(input);
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    BigInt varint() {
      var value = BigInt.zero;
      for (var shift = 0; shift < 70; shift += 7) {
        if (offset >= bytes.length) {
          throw const FormatException('Truncated protobuf varint');
        }
        final byte = bytes[offset++];
        value |= BigInt.from(byte & 0x7f) << shift;
        if ((byte & 0x80) == 0) return value;
      }
      throw const FormatException('Invalid protobuf varint');
    }

    while (offset < bytes.length) {
      final tag = varint().toInt();
      final number = tag >> 3;
      if (number == 0) {
        throw const FormatException('Invalid protobuf field number');
      }
      switch (tag & 7) {
        case 0:
          _fields.add(_Field(number, varint()));
        case 1:
          if (offset + 8 > bytes.length) {
            throw const FormatException('Truncated fixed64');
          }
          final value =
              BigInt.from(data.getUint32(offset, Endian.little)) |
              (BigInt.from(data.getUint32(offset + 4, Endian.little)) << 32);
          offset += 8;
          _fields.add(_Field(number, value));
        case 2:
          final size = varint().toInt();
          if (size < 0 || size > bytes.length - offset) {
            throw const FormatException('Truncated protobuf bytes');
          }
          _fields.add(
            _Field(number, Uint8List.sublistView(bytes, offset, offset + size)),
          );
          offset += size;
        case 5:
          if (offset + 4 > bytes.length) {
            throw const FormatException('Truncated fixed32');
          }
          _fields.add(
            _Field(number, BigInt.from(data.getUint32(offset, Endian.little))),
          );
          offset += 4;
        default:
          throw const FormatException('Unsupported protobuf wire type');
      }
    }
  }

  final List<_Field> _fields = [];
  Object? _value(int field) {
    for (final entry in _fields.reversed) {
      if (entry.number == field) return entry.value;
    }
    return null;
  }

  BigInt bigInteger(int field) => _value(field) as BigInt? ?? BigInt.zero;
  int integer(int field) => bigInteger(field).toInt();
  List<int> bytes(int field) => _value(field) as List<int>? ?? const [];
  String text(int field) => utf8.decode(bytes(field));
  Iterable<_Message> messages(int field) => _fields
      .where((entry) => entry.number == field)
      .map((entry) => _Message(entry.value as List<int>));
}

class _Writer {
  final BytesBuilder _builder = BytesBuilder(copy: false);
  void _varint(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError.value(value, 'value', 'Unsigned integer required');
    }
    while (value > BigInt.from(0x7f)) {
      _builder.addByte((value & BigInt.from(0x7f)).toInt() | 0x80);
      value >>= 7;
    }
    _builder.addByte(value.toInt());
  }

  void integer(int field, int value) => bigInteger(field, BigInt.from(value));
  void bigInteger(int field, BigInt value) {
    _varint(BigInt.from(field << 3));
    _varint(value);
  }

  void fixed32(int field, int value) {
    _varint(BigInt.from((field << 3) | 5));
    _builder.add(_uint32(value));
  }

  void bytes(int field, List<int> value) {
    _varint(BigInt.from((field << 3) | 2));
    _varint(BigInt.from(value.length));
    _builder.add(value);
  }

  void text(int field, String value) => bytes(field, utf8.encode(value));
  Uint8List result() => _builder.toBytes();
}
