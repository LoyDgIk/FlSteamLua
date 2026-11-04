import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerAppLicenses() {
  const licenses = {
    'FlClash UI': 'assets/licenses/FlClash-GPL-3.0.txt',
    'Fluent-Steam-Lua': 'assets/licenses/Fluent-Steam-Lua-zlib.txt',
    'SteamAchievementManager':
        'assets/licenses/SteamAchievementManager-zlib.txt',
    'SteamKit2': 'assets/licenses/SteamKit2-LGPL-2.1.txt',
    'CloudRedirect': 'assets/licenses/CloudRedirect-MIT.txt',
    'JetBrains Mono': 'assets/fonts/JetBrainsMono-OFL.txt',
    'Twemoji Mozilla': 'assets/fonts/Twemoji-Mozilla-LICENSE.md',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in licenses.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}
