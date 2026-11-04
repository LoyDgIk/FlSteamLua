import 'package:flutter/services.dart';

class AppChangelogSection {
  const AppChangelogSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class AppChangelog {
  const AppChangelog({
    required this.version,
    required this.sections,
    this.date,
  });

  final String version;
  final String? date;
  final List<AppChangelogSection> sections;
}

Future<AppChangelog?> loadLatestAppChangelog({AssetBundle? bundle}) async {
  final markdown = await (bundle ?? rootBundle).loadString('CHANGELOG.md');
  return parseLatestAppChangelog(markdown);
}

AppChangelog? parseLatestAppChangelog(String markdown) {
  final lines = markdown.split(RegExp(r'\r?\n'));
  final releaseHeading = RegExp(r'^##\s+\[([^\]]+)\]\s*(?:-\s*(.+))?\s*$');
  var start = -1;
  Match? selected;
  for (var index = 0; index < lines.length; index++) {
    final match = releaseHeading.firstMatch(lines[index]);
    if (match == null || match.group(1) == 'Unreleased') continue;
    start = index;
    selected = match;
    break;
  }
  if (selected == null) return null;

  var end = lines.length;
  for (var index = start + 1; index < lines.length; index++) {
    if (releaseHeading.hasMatch(lines[index])) {
      end = index;
      break;
    }
  }

  final sections = <AppChangelogSection>[];
  String? title;
  var items = <String>[];
  void finishSection() {
    if (title != null && items.isNotEmpty) {
      sections.add(
        AppChangelogSection(title: title!, items: List.unmodifiable(items)),
      );
    }
    title = null;
    items = <String>[];
  }

  for (var index = start + 1; index < end; index++) {
    final line = lines[index].trim();
    if (line.startsWith('### ')) {
      finishSection();
      title = line.substring(4).trim();
      continue;
    }
    if (line.startsWith('- ')) {
      items.add(line.substring(2).trim());
      continue;
    }
    if (line.isNotEmpty && items.isNotEmpty) {
      items[items.length - 1] = '${items.last} $line';
    }
  }
  finishSection();

  return AppChangelog(
    version: selected.group(1)!,
    date: selected.group(2)?.trim(),
    sections: List.unmodifiable(sections),
  );
}
