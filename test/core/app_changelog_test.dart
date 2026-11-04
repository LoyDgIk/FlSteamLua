import 'package:fl_steam_lua/core/app_changelog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest changelog keeps sections and wrapped bullets', () {
    final changelog = parseLatestAppChangelog('''
# Changelog

## [Unreleased]

## [1.2.0] - 2026-11-04

### Added

- First user-facing change that wraps
  onto a second line.

### Fixed

- A release fix.

## [1.1.0] - 2026-10-01

### Added

- Older change.
''');

    expect(changelog, isNotNull);
    expect(changelog!.version, '1.2.0');
    expect(changelog.date, '2026-11-04');
    expect(changelog.sections.map((section) => section.title), [
      'Added',
      'Fixed',
    ]);
    expect(
      changelog.sections.first.items.single,
      'First user-facing change that wraps onto a second line.',
    );
  });
}
