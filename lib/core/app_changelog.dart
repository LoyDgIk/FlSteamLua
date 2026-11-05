import 'package:flutter/services.dart';

class AppChangelog {
  const AppChangelog({
    required this.version,
    required this.markdown,
    this.date,
  });

  final String version;
  final String? date;
  final String markdown;
}

Future<AppChangelog?> loadLatestAppChangelog({AssetBundle? bundle}) async {
  final markdown = await (bundle ?? rootBundle).loadString('CHANGELOG.md');
  return parseLatestAppChangelog(markdown);
}

AppChangelog? parseLatestAppChangelog(String markdown) {
  markdown = markdown.replaceAll('\r\n', '\n');
  final headings = RegExp(
    r'^##\s+\[([^\]]+)\][ \t]*(?:-[ \t]*([^\r\n]+))?[ \t]*$',
    multiLine: true,
  ).allMatches(markdown).toList();
  for (var index = 0; index < headings.length; index++) {
    final heading = headings[index];
    if (heading.group(1) == 'Unreleased') continue;
    final end = index + 1 < headings.length
        ? headings[index + 1].start
        : markdown.length;
    return AppChangelog(
      version: heading.group(1)!,
      date: heading.group(2)?.trim(),
      markdown: markdown.substring(heading.end, end).trim(),
    );
  }
  return null;
}
