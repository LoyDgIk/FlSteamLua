import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/features/steam_protocol/manifest/depot_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  DepotManifest fixture() => DepotManifest(
    depotId: 123,
    manifestGid: BigInt.parse('18446744073709551614'),
    creationTime: 1730000000,
    originalSize: 100,
    compressedSize: 75,
    files: [
      DepotManifestFile(
        fileName: 'Folder/game.dat',
        size: 100,
        flags: 0,
        sha: List.filled(20, 1),
        chunks: [
          DepotManifestChunk(
            sha: List.filled(20, 2),
            crc: 0xf1234567,
            offset: 0,
            originalSize: 100,
            compressedSize: 75,
          ),
        ],
      ),
    ],
  );

  test('modern manifest preserves uint64 gid, file and chunk metadata', () {
    final result = DepotManifest.parse(fixture().toBytes());
    expect(result.depotId, 123);
    expect(result.manifestGid, BigInt.parse('18446744073709551614'));
    expect(result.creationTime, 1730000000);
    expect(result.files.single.fileName, r'Folder\game.dat');
    expect(result.files.single.size, 100);
    expect(result.files.single.chunks.single.crc, 0xf1234567);
    expect(result.files.single.chunks.single.compressedSize, 75);
    expect(result.files.single.fileNameSha.length, 20);
    expect(DepotManifest.parse(result.toBytes()).toBytes(), result.toBytes());
  });

  test('CDN ZIP unwraps exactly one manifest in memory', () {
    final bytes = fixture().toBytes();
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('manifest', bytes.length, bytes)),
    );
    expect(DepotManifest.parse(zip).depotId, 123);
    final extra = ZipEncoder().encode(
      Archive()
        ..addFile(ArchiveFile('first', bytes.length, bytes))
        ..addFile(ArchiveFile('second', bytes.length, bytes)),
    );
    expect(() => DepotManifest.parse(extra), throwsFormatException);
  });

  test('missing, truncated and unknown sections are rejected', () {
    final bytes = fixture().toBytes();
    expect(
      () => DepotManifest.parse(bytes.sublist(0, bytes.length - 1)),
      throwsFormatException,
    );
    expect(() => DepotManifest.parse([0, 0, 0, 0]), throwsFormatException);
    expect(() => DepotManifest.parse([...bytes, 0]), throwsFormatException);
    final changed = Uint8List.fromList(bytes);
    ByteData.sublistView(changed).setUint32(4, 0x7fffffff, Endian.little);
    expect(() => DepotManifest.parse(changed), throwsFormatException);
  });

  test(
    'AES encrypted filenames and link targets decrypt then serialize clear',
    () {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final encrypted = DepotManifest(
        depotId: 123,
        manifestGid: BigInt.one,
        filenamesEncrypted: true,
        files: [
          DepotManifestFile(
            fileName: encryptName(r'folder\file.txt', key),
            size: 0,
            flags: 0,
            linkTarget: encryptName('target.txt', key),
          ),
        ],
      );
      final result = DepotManifest.parse(encrypted.toBytes(), depotKey: key);
      expect(result.filenamesEncrypted, false);
      expect(result.files.single.fileName, 'folder/file.txt');
      expect(result.files.single.linkTarget, 'target.txt');
      final written = DepotManifest.parse(result.toBytes());
      expect(written.filenamesEncrypted, false);
      expect(written.files.single.fileName, r'folder\file.txt');
    },
  );

  test('failed decryption leaves the encrypted manifest untouched', () {
    final key = Uint8List(32);
    final name = encryptName('file', key);
    final manifest = DepotManifest(
      depotId: 1,
      manifestGid: BigInt.one,
      filenamesEncrypted: true,
      files: [DepotManifestFile(fileName: name, size: 0, flags: 0)],
    );
    expect(
      () => manifest.decryptFilenames(List.filled(32, 1)),
      throwsFormatException,
    );
    expect(manifest.filenamesEncrypted, true);
    expect(manifest.files.single.fileName, name);
    expect(() => manifest.decryptFilenames([1]), throwsArgumentError);
  });
}

String encryptName(String name, Uint8List key) {
  final iv = Uint8List.fromList(List.generate(16, (i) => i + 20));
  final aes = AESEngine()..init(true, KeyParameter(key));
  final encryptedIv = Uint8List(16);
  aes.processBlock(iv, 0, encryptedIv, 0);
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
  final bytes = cipher.process(Uint8List.fromList([...utf8.encode(name), 0]));
  return base64Encode([...encryptedIv, ...bytes]);
}
