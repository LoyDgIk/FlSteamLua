import 'dart:convert';
import 'dart:io';

class FriendPresenceSettings {
  Future<bool> read(String steamPath) async {
    final file = await _configFile(steamPath);
    if (await FileSystemEntity.type(file.path) ==
        FileSystemEntityType.notFound) {
      return true;
    }
    final document = _Document(await file.readAsBytes());
    var inPresence = false;
    for (final line in document.lines) {
      final section = _section(line.text);
      if (section != null) {
        inPresence = section.toLowerCase() == 'presence';
      } else if (inPresence) {
        final value = _displayValue(line.text);
        if (value != null) {
          var text = line.text.substring(value.$1, value.$2);
          if (text.length >= 2 &&
              ((text.startsWith('"') && text.endsWith('"')) ||
                  (text.startsWith("'") && text.endsWith("'")))) {
            text = text.substring(1, text.length - 1);
          }
          return text.toLowerCase() != 'none';
        }
      }
    }
    return true;
  }

  Future<void> write(String steamPath, bool enabled) async {
    final file = await _configFile(steamPath);
    final existed =
        await FileSystemEntity.type(file.path) != FileSystemEntityType.notFound;
    final original = existed ? await file.readAsBytes() : <int>[];
    final document = _Document(original);
    final value = enabled ? 'spacewar' : 'none';
    final output = document.withDisplay(value);
    final temporary = File(
      '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsBytes(output, flush: true);
      if (existed) await file.copy('${file.path}.bak');
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<File> _configFile(String steamPath) async {
    if (steamPath.trim().isEmpty) {
      throw ArgumentError.value(steamPath, 'steamPath', 'Must not be empty');
    }
    final directory = Directory(steamPath).absolute;
    if (!await directory.exists()) {
      throw FileSystemException('Steam directory does not exist', steamPath);
    }
    return File.fromUri(directory.uri.resolve('opensteamtool.toml'));
  }
}

class _Document {
  _Document(List<int> bytes)
    : hasBom =
          bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf {
    source = utf8.decode(hasBom ? bytes.sublist(3) : bytes);
    var offset = 0;
    for (final match in RegExp(r'\r\n|\n|\r').allMatches(source)) {
      lines.add(
        _Line(source.substring(offset, match.start), offset, match.group(0)!),
      );
      offset = match.end;
    }
    if (offset < source.length) {
      lines.add(_Line(source.substring(offset), offset, ''));
    }
  }

  final bool hasBom;
  late final String source;
  final List<_Line> lines = [];

  List<int> withDisplay(String display) {
    var inPresence = false;
    int? sectionEnd;
    for (final line in lines) {
      final section = _section(line.text);
      if (section != null) {
        if (inPresence) {
          sectionEnd = line.offset;
          break;
        }
        inPresence = section.toLowerCase() == 'presence';
      } else if (inPresence) {
        final value = _displayValue(line.text);
        if (value != null) {
          final quote = line.text.substring(value.$1).startsWith("'")
              ? "'"
              : '"';
          return _encode(
            source.replaceRange(
              line.offset + value.$1,
              line.offset + value.$2,
              '$quote$display$quote',
            ),
          );
        }
      }
    }
    final newline =
        lines
            .map((line) => line.ending)
            .where((ending) => ending.isNotEmpty)
            .firstOrNull ??
        (Platform.isWindows ? '\r\n' : '\n');
    final assignment = 'display = "$display"';
    if (sectionEnd != null) {
      return _encode(
        source.replaceRange(sectionEnd, sectionEnd, '$assignment$newline'),
      );
    }
    final endsWithNewline = source.endsWith('\n') || source.endsWith('\r');
    final separator = source.isEmpty || endsWithNewline ? '' : newline;
    final ending = source.isEmpty || endsWithNewline ? newline : '';
    final header = inPresence ? '' : '[presence]$newline';
    return _encode('$source$separator$header$assignment$ending');
  }

  List<int> _encode(String text) => [
    if (hasBom) ...[0xef, 0xbb, 0xbf],
    ...utf8.encode(text),
  ];
}

class _Line {
  const _Line(this.text, this.offset, this.ending);
  final String text;
  final int offset;
  final String ending;
}

String? _section(String line) {
  final content = line.substring(0, _commentOffset(line)).trim();
  if (!content.startsWith('[') || !content.endsWith(']')) return null;
  return content.substring(1, content.length - 1).trim();
}

(int, int)? _displayValue(String line) {
  final end = _commentOffset(line);
  final content = line.substring(0, end);
  final assignment = RegExp(
    r'^[ \t]*display[ \t]*=[ \t]*',
    caseSensitive: false,
  ).firstMatch(content);
  if (assignment == null) return null;
  final valueEnd = content.trimRight().length;
  return (
    assignment.end,
    valueEnd < assignment.end ? assignment.end : valueEnd,
  );
}

int _commentOffset(String line) {
  var quote = 0;
  var escaped = false;
  for (var i = 0; i < line.length; i++) {
    final code = line.codeUnitAt(i);
    if (quote == 0) {
      if (code == 0x23) return i;
      if (code == 0x22 || code == 0x27) quote = code;
    } else if (quote == 0x22 && escaped) {
      escaped = false;
    } else if (quote == 0x22 && code == 0x5c) {
      escaped = true;
    } else if (code == quote) {
      quote = 0;
    }
  }
  return line.length;
}
