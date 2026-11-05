import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

typedef CredentialTransform = Uint8List Function(Uint8List data);

class CredentialCodec {
  const CredentialCodec({required this.protect, required this.unprotect});
  final CredentialTransform protect;
  final CredentialTransform unprotect;
}

class CloudCredentialStore {
  CloudCredentialStore(this.directory, this.codec, {this.overrides = const {}});
  final String directory;
  final CredentialCodec codec;
  final Map<String, String> overrides;

  String path(String provider) =>
      overrides[provider] ??
      p.join(directory, switch (provider) {
        'gdrive' => 'google_tokens.json',
        'onedrive' => 'onedrive_tokens.json',
        'r2' => 'r2_credentials.json',
        's3' => 's3_credentials.json',
        'webdav' => 'webdav_credentials.json',
        _ => throw ArgumentError.value(provider, 'provider'),
      });

  Future<Map<String, dynamic>?> read(String provider) async {
    final file = File(path(provider));
    if (!await file.exists()) return null;
    final encrypted = await file.readAsBytes();
    if (encrypted.isEmpty) {
      throw const FormatException('Empty cloud credential file');
    }
    // The native DLL uses current-user DPAPI without additional entropy.
    final decoded = jsonDecode(utf8.decode(codec.unprotect(encrypted)));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid cloud credential file');
    }
    return decoded;
  }

  Future<void> write(String provider, Map<String, dynamic> value) async {
    final bytes = codec.protect(
      Uint8List.fromList(utf8.encode(jsonEncode(value))),
    );
    await atomicWrite(File(path(provider)), bytes);
  }

  Future<void> signOut(String provider) async {
    final file = File(path(provider));
    if (await file.exists()) await file.delete();
  }
}

Future<void> atomicWrite(File file, List<int> bytes) async {
  await file.parent.create(recursive: true);
  final temp = File(
    '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  } finally {
    if (await temp.exists()) await temp.delete();
  }
}
