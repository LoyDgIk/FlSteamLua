import 'dart:io';

typedef DesktopProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Registration is changed only by the explicit preference action.
class StartupRegistration {
  StartupRegistration({DesktopProcessRunner? runner, String? executable})
    : _runner = runner ?? ((exe, args) => Process.run(exe, args)),
      executable = executable ?? Platform.resolvedExecutable;

  final DesktopProcessRunner _runner;
  final String executable;
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  Future<bool> isEnabled() async {
    final result = await _runner('reg.exe', [
      'query',
      _key,
      '/v',
      'FlSteamLua',
    ]);
    if (result.exitCode == 1) return false;
    if (result.exitCode != 0) {
      throw ProcessException(
        'reg.exe',
        [],
        '${result.stderr}',
        result.exitCode,
      );
    }
    final match = RegExp(
      r'REG_SZ\s+(.+)$',
      multiLine: true,
    ).firstMatch(result.stdout.toString());
    return match?.group(1)?.trim() == '"$executable"';
  }

  Future<void> setEnabled(bool enabled) async {
    if (!enabled && !await isEnabled()) return;
    final args = enabled
        ? [
            'add',
            _key,
            '/v',
            'FlSteamLua',
            '/t',
            'REG_SZ',
            '/d',
            '"$executable"',
            '/f',
          ]
        : ['delete', _key, '/v', 'FlSteamLua', '/f'];
    final result = await _runner('reg.exe', args);
    if (result.exitCode != 0) {
      throw ProcessException(
        'reg.exe',
        args,
        '${result.stderr}',
        result.exitCode,
      );
    }
  }
}
