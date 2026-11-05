import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_release.dart';
import 'app_paths.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore(this.paths);
  final AppPaths paths;
  Map<String, dynamic> _values = {};
  Future<void> _writes = Future.value();

  String get steamPath => get<String>('steamPath', '');
  bool get quickStartDismissed => get<bool>('quickStartDismissed', false);
  String get language => get<String>('language', 'zh');
  String get theme => get<String>('theme', 'system');
  bool get pureBlack => get<bool>('themePureBlack', false);
  bool get themeFollowSystem => get<bool>('themeFollowSystem', true);
  int get themeSeed => get<int>('themeSeed', 0xff007aff);
  List<int> get themeColors {
    final value = _values['themeColors'];
    if (value is! List) return const [];
    return value.whereType<num>().map((color) => color.toInt()).toList();
  }

  String get colorStyle => get<String>('themeColorStyle', 'vivid');
  bool get sidebarFloating => get<bool>('sidebarFloating', false);
  bool get sidebarBlur => get<bool>('sidebarBlur', false);
  String get tabAnimation => get<String>('tabAnimation', 'fade');
  String get liquidGlass => get<String>('liquidGlass', 'ultra');
  String? get fontFamily {
    final value = get<String>('fontFamily', '');
    return value.isEmpty ? null : value;
  }

  bool get textScaleEnabled => get<bool>('textScaleEnabled', false);
  double get textScale => get<double>('textScale', 1);
  bool get sidebarExpanded => get<bool>('sidebarExpanded', false);
  bool get minimizeToTray => get<bool>('minimizeToTray', true);
  bool get autoCheckKernelUpdate => get<bool>('autoCheckKernelUpdate', true);
  bool get lanTransferEnabled => get<bool>('lanTransferEnabled', false);
  String get releaseRepository => appRepository;

  Map<String, String> get storageLocations {
    final value = _values['storageLocations'];
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  T get<T>(String key, T fallback) =>
      _values[key] is T ? _values[key] as T : fallback;

  Future<void> load() async {
    final file = File(paths.file('settings.json'));
    if (await file.exists()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid application settings');
      }
      _values = decoded;
    }
    notifyListeners();
  }

  Future<void> set(String key, Object? value) {
    final write = _writes.then((_) async {
      final updated = {..._values, key: value};
      await Directory(paths.root).create(recursive: true);
      final temp = File(paths.file('settings.json.tmp'));
      await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(updated),
        flush: true,
      );
      await temp.rename(paths.file('settings.json'));
      _values = updated;
      notifyListeners();
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> setStorageLocation(String name, String? path) {
    final locations = {...storageLocations};
    if (path == null || path.trim().isEmpty) {
      locations.remove(name);
    } else {
      locations[name] = path;
    }
    return set('storageLocations', locations);
  }
}
