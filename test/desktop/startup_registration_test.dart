import 'dart:io';

import 'package:fl_steam_lua/platform/desktop/startup_registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'startup executable with spaces is passed as one quoted argument',
    () async {
      final calls = <List<String>>[];
      final registration = StartupRegistration(
        executable: r'C:\My App\fl_steam_lua.exe',
        runner: (exe, args) async {
          expect(exe, 'reg.exe');
          calls.add(args);
          return ProcessResult(1, 0, '', '');
        },
      );
      await registration.setEnabled(true);
      expect(calls.single, contains('"C:\\My App\\fl_steam_lua.exe"'));
      expect(calls.single.first, 'add');
    },
  );

  test('does not delete an unrelated startup registration', () async {
    final calls = <List<String>>[];
    final registration = StartupRegistration(
      executable: r'C:\New\app.exe',
      runner: (exe, args) async {
        calls.add(args);
        return ProcessResult(
          1,
          0,
          'FlSteamLua    REG_SZ    "C:\\Other\\app.exe"',
          '',
        );
      },
    );
    await registration.setEnabled(false);
    expect(calls.length, 1);
    expect(calls.single.first, 'query');
  });

  test('registry failure is not reported as success', () async {
    final registration = StartupRegistration(
      runner: (exe, args) async => ProcessResult(1, 5, '', 'Access denied'),
    );
    await expectLater(
      registration.setEnabled(true),
      throwsA(isA<ProcessException>()),
    );
  });
}
