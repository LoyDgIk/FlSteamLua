import 'dart:convert';
import 'dart:io';

import '../../core/app_paths.dart';
import '../../platform/windows/dpapi.dart';
import 'manifest_models.dart';

class EncryptedManifestSecretStore implements SecretValueStore {
  EncryptedManifestSecretStore(this.paths);
  final AppPaths paths;
  Future<void> _writing = Future.value();

  Future<Map<String, dynamic>> _load() async {
    final file = File(paths.file('data/manifest-secrets.json'));
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid encrypted manifest credentials');
    }
    return decoded;
  }

  @override
  Future<String?> read(String key) async {
    await _writing;
    final encoded = (await _load())[key];
    if (encoded == null) return null;
    if (encoded is! String) {
      throw const FormatException('Invalid encrypted manifest credential');
    }
    return WindowsDpapi.unprotectString(
      encoded,
      entropy: 'FlSteamLua.ManifestSources',
    );
  }

  Future<void> _change(String key, String? value) {
    final operation = _writing.then((_) async {
      final all = await _load();
      if (value == null) {
        all.remove(key);
      } else {
        all[key] = WindowsDpapi.protectString(
          value,
          entropy: 'FlSteamLua.ManifestSources',
        );
      }
      await paths.directory('data').create(recursive: true);
      final temp = File(paths.file('data/manifest-secrets.json.tmp'));
      await temp.writeAsString(jsonEncode(all), flush: true);
      await temp.rename(paths.file('data/manifest-secrets.json'));
    });
    _writing = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> write(String key, String value) => _change(key, value);

  @override
  Future<void> delete(String key) => _change(key, null);
}
