import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';

/// The core reads only this file. Preserve unrelated keys and comments when
/// editing a setting, including multi-line arrays and quoted Windows paths.
class KernelConfig {
  KernelConfig(this.steamPath);

  final String steamPath;
  File get file => File(p.join(steamPath, 'opensteamtool.toml'));

  Map<String, dynamic> readSync() =>
      decode(file.existsSync() ? file.readAsStringSync(encoding: utf8) : '');

  static Map<String, dynamic> decode(String source) =>
      TomlDocument.parse(source.replaceFirst('\uFEFF', '')).toMap();

  Future<void> update(String section, Map<String, Object> values) async {
    if (steamPath.isEmpty || !p.isAbsolute(steamPath)) {
      throw const FormatException('Select an absolute Steam directory first');
    }
    final bytes = await file.exists() ? await file.readAsBytes() : <int>[];
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;
    final original = '${hasBom ? '\uFEFF' : ''}${utf8.decode(bytes)}';
    final updated = updateText(original, section, values);
    final temporary = File('${file.path}.$pid.tmp');
    try {
      await temporary.writeAsString(updated, encoding: utf8, flush: true);
      if (await file.exists()) await file.copy('${file.path}.bak');
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static String updateText(
    String original,
    String section,
    Map<String, Object> values,
  ) {
    final bom = original.startsWith('\uFEFF') ? '\uFEFF' : '';
    final source = original.substring(bom.length);
    decode(source);
    final newline = source.contains('\r\n') ? '\r\n' : '\n';
    final pending = {...values};
    final edits = <({int start, int end, String text})>[];
    var currentSection = <String>[];
    int? insertAt;
    var offset = 0;
    while (offset < source.length) {
      final parsed = TomlExpression.parser.parse(source.substring(offset));
      final expression = parsed.value;
      final end = offset + parsed.position;
      if (expression is TomlTable) {
        if (currentSection.length == 1 && currentSection.single == section) {
          insertAt = offset;
        }
        currentSection = expression.name.parts
            .map((part) => part.name)
            .toList();
        if (currentSection.length == 1 && currentSection.single == section) {
          insertAt = source.length;
        }
      } else if (expression is TomlKeyValuePair) {
        final key = [
          ...currentSection,
          ...expression.key.parts.map((part) => part.name),
        ];
        if (key.length == 2 &&
            key.first == section &&
            pending.containsKey(key.last)) {
          final start =
              offset + source.substring(offset, end).indexOf(RegExp(r'\S'));
          final pair = TomlKeyValuePair.parser.parse(source.substring(start));
          final encoded = TomlDocument.fromMap({
            key.last: pending.remove(key.last),
          }).toString().trim();
          final encodedValue = encoded
              .substring(encoded.indexOf('=') + 1)
              .trim();
          edits.add((
            start: start,
            end: start + pair.position,
            text: '${expression.key} = $encodedValue',
          ));
        }
      }
      offset = end;
      if (source.startsWith('\r\n', offset)) {
        offset += 2;
      } else if (source.startsWith('\n', offset)) {
        offset++;
      }
    }
    if (pending.isNotEmpty) {
      final additions = TomlDocument.fromMap(
        pending,
      ).toString().trimRight().replaceAll('\n', newline);
      final at = insertAt ?? source.length;
      final separator = at > 0 && source[at - 1] != '\n' ? newline : '';
      edits.add((
        start: at,
        end: at,
        text:
            '$separator${insertAt == null ? '[$section]$newline' : ''}$additions$newline',
      ));
    }
    var output = source;
    edits.sort((a, b) => b.start.compareTo(a.start));
    for (final edit in edits) {
      output = output.replaceRange(edit.start, edit.end, edit.text);
    }
    decode(output);
    return '$bom$output';
  }
}
