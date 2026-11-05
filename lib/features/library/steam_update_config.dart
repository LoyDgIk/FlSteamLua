import 'dart:convert';

class SteamUpdateControlSettings {
  const SteamUpdateControlSettings({
    this.disableUpdateCheck = false,
    this.disableForcedUpdate = false,
  });

  final bool disableUpdateCheck;
  final bool disableForcedUpdate;

  SteamUpdateControlSettings copyWith({
    bool? disableUpdateCheck,
    bool? disableForcedUpdate,
  }) => SteamUpdateControlSettings(
    disableUpdateCheck: disableUpdateCheck ?? this.disableUpdateCheck,
    disableForcedUpdate: disableForcedUpdate ?? this.disableForcedUpdate,
  );
}

abstract final class SteamUpdateConfig {
  static SteamUpdateControlSettings parse(String source) {
    final lines = const LineSplitter().convert(source);
    final values = <String, String>{};
    for (final line in lines) {
      final text = line.trim();
      if (text.isEmpty || text.startsWith('#') || text.startsWith('//')) {
        continue;
      }
      final separator = text.indexOf('=');
      if (separator <= 0) continue;
      values[text.substring(0, separator).trim().toLowerCase()] = text
          .substring(separator + 1)
          .trim()
          .toLowerCase();
    }
    return SteamUpdateControlSettings(
      disableUpdateCheck: values['bootstrapperinhibitall'] == 'enable',
      disableForcedUpdate: values['bootstrapperforceselfupdate'] == 'disable',
    );
  }

  static String rewrite(String source, SteamUpdateControlSettings value) {
    final lines = const LineSplitter().convert(source);
    _setValue(
      lines,
      'BootStrapperInhibitAll',
      value.disableUpdateCheck ? 'enable' : null,
    );
    _setValue(
      lines,
      'BootStrapperForceSelfUpdate',
      value.disableForcedUpdate ? 'disable' : null,
    );
    return lines.isEmpty ? '' : '${lines.join('\n')}\n';
  }

  static void _setValue(List<String> lines, String key, String? value) {
    final indices = <int>[];
    for (var index = 0; index < lines.length; index++) {
      final text = lines[index].trim();
      if (text.isEmpty || text.startsWith('#') || text.startsWith('//')) {
        continue;
      }
      final separator = text.indexOf('=');
      if (separator > 0 &&
          text.substring(0, separator).trim().toLowerCase() ==
              key.toLowerCase()) {
        indices.add(index);
      }
    }
    if (value == null) {
      for (final index in indices.reversed) {
        lines.removeAt(index);
      }
      return;
    }
    if (indices.isEmpty) {
      lines.add('$key=$value');
      return;
    }
    lines[indices.first] = '$key=$value';
    for (final index in indices.skip(1).toList().reversed) {
      lines.removeAt(index);
    }
  }
}
