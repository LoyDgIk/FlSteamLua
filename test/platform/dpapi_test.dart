import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/platform/windows/dpapi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'DPAPI current-user bytes round trip with null entropy',
    () {
      final plain = Uint8List.fromList([0, 1, 2, 255, 42]);
      final encrypted = WindowsDpapi.protectBytes(plain);
      expect(encrypted, isNot(equals(plain)));
      expect(WindowsDpapi.unprotectBytes(encrypted), plain);
    },
    skip: !Platform.isWindows,
  );

  test(
    'DPAPI strings use matching entropy and reject wrong context',
    () {
      final encrypted = WindowsDpapi.protectString(
        'fixture credential',
        entropy: 'FlSteamLua:test',
      );
      expect(
        WindowsDpapi.unprotectString(encrypted, entropy: 'FlSteamLua:test'),
        'fixture credential',
      );
      expect(
        () => WindowsDpapi.unprotectString(encrypted, entropy: 'wrong'),
        throwsA(isA<FileSystemException>()),
      );
    },
    skip: !Platform.isWindows,
  );
}
