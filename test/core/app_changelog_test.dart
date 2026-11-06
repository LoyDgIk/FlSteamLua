import 'package:fl_steam_lua/core/app_changelog.dart';
import 'package:fl_steam_lua/core/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'latest changelog preserves full Markdown and excludes older releases',
    () {
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
      expect(changelog.markdown, contains('### Added'));
      expect(
        changelog.markdown,
        contains(
          '- First user-facing change that wraps\n  onto a second line.',
        ),
      );
      expect(changelog.markdown, contains('### Fixed'));
      expect(changelog.markdown, isNot(contains('Older change.')));
    },
  );

  test('Windows line endings retain the release body', () {
    final changelog = parseLatestAppChangelog(
      '## [1.2.0] - 2026-11-06\r\n\r\n### 中文\r\n\r\n- `code`\r\n',
    );
    expect(changelog!.markdown, '### 中文\n\n- `code`');
  });

  test(
    'bundled changelog shows Chinese before English and retains inline code',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final changelog = await loadLatestAppChangelog();
      expect(changelog, isNotNull);
      expect(changelog!.version, appVersion);
      expect(
        changelog.markdown.indexOf('### 中文'),
        lessThan(changelog.markdown.indexOf('### English')),
      );
      expect(changelog.markdown, contains('#### '));
      expect(changelog.markdown, contains('- '));
    },
  );
}
