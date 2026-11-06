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
  final entries = parseAppChangelogs(markdown);
  return entries.firstOrNull;
}

List<AppChangelog> parseAppChangelogs(String markdown) {
  markdown = markdown.replaceAll('\r\n', '\n');
  final headings = RegExp(
    r'^##\s+\[([^\]]+)\][ \t]*(?:-[ \t]*([^\r\n]+))?[ \t]*$',
    multiLine: true,
  ).allMatches(markdown).toList();
  return [
    for (var index = 0; index < headings.length; index++)
      if (headings[index].group(1) != 'Unreleased')
        AppChangelog(
          version: headings[index].group(1)!,
          date: headings[index].group(2)?.trim(),
          markdown: markdown
              .substring(
                headings[index].end,
                index + 1 < headings.length
                    ? headings[index + 1].start
                    : markdown.length,
              )
              .trim(),
        ),
  ];
}
