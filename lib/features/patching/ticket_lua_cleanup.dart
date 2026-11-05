import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TicketLuaCleanupException implements Exception {
  const TicketLuaCleanupException();
}

class LuaTicketStatement {
  const LuaTicketStatement(this.function, this.line, this.start, this.end);
  final String function;
  final int line, start, end;
}

class TicketLuaCleanup {
  const TicketLuaCleanup({
    required this.path,
    required this.original,
    required this.updated,
    required this.statements,
  });
  final String path;
  final Uint8List original, updated;
  final List<LuaTicketStatement> statements;

  static Future<TicketLuaCleanup> read(String path, int appId) async {
    final original = await File(path).readAsBytes();
    final bom =
        original.length >= 3 &&
        original[0] == 0xef &&
        original[1] == 0xbb &&
        original[2] == 0xbf;
    final source = utf8.decode(original);
    final tokens = _tokens(source);
    final statements = <LuaTicketStatement>[];
    for (var i = 0; i + 5 < tokens.length; i++) {
      final token = tokens[i];
      final name = token.text.toLowerCase();
      if (token.string || !{'setappticket', 'seteticket'}.contains(name)) {
        continue;
      }
      if (i > 0 && {'.', ':'}.contains(tokens[i - 1].text)) continue;
      if (tokens[i + 1].text != '(' ||
          tokens[i + 2].text != '$appId' ||
          tokens[i + 3].text != ',') {
        continue;
      }
      if (!tokens[i + 4].string || tokens[i + 5].text != ')') {
        throw const TicketLuaCleanupException();
      }
      // Only stand-alone calls can be removed without changing Lua expressions.
      final lineStart = source.lastIndexOf('\n', token.start) + 1;
      final prefix = source.substring(lineStart, token.start).trim();
      if (prefix.isNotEmpty && !prefix.endsWith(';')) {
        throw const TicketLuaCleanupException();
      }
      var end = tokens[i + 5].end;
      if (i + 6 < tokens.length && tokens[i + 6].text == ';') {
        end = tokens[i + 6].end;
      }
      statements.add(
        LuaTicketStatement(
          name == 'setappticket' ? 'setAppTicket' : 'setETicket',
          '\n'.allMatches(source.substring(0, token.start)).length + 1,
          token.start,
          end,
        ),
      );
      i += 5;
    }
    var updated = source;
    for (final statement in statements.reversed) {
      updated = updated.replaceRange(statement.start, statement.end, '');
    }
    return TicketLuaCleanup(
      path: path,
      original: original,
      updated: Uint8List.fromList([
        if (bom) ...[0xef, 0xbb, 0xbf],
        ...utf8.encode(updated),
      ]),
      statements: List.unmodifiable(statements),
    );
  }
}

typedef _Token = ({String text, int start, int end, bool string});

List<_Token> _tokens(String source) {
  final result = <_Token>[];
  var i = 0;
  final longOpen = RegExp(r'\[(=*)\[');
  while (i < source.length) {
    if (RegExp(r'\s').hasMatch(source[i])) {
      i++;
      continue;
    }
    final start = i;
    final comment = source.startsWith('--', i);
    if (comment) i += 2;
    final bracket = longOpen.matchAsPrefix(source, i);
    if (bracket != null) {
      final closing = ']${bracket[1]}]';
      final end = source.indexOf(closing, bracket.end);
      if (end < 0) {
        throw const FormatException('Unterminated Lua string or comment');
      }
      i = end + closing.length;
      if (!comment) {
        result.add((
          text: source.substring(start, i),
          start: start,
          end: i,
          string: true,
        ));
      }
      continue;
    }
    if (comment) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    final quote = source[i];
    if (quote == '"' || quote == "'") {
      i++;
      while (i < source.length && source[i] != quote) {
        i += source[i] == r'\' ? 2 : 1;
      }
      if (i >= source.length) {
        throw const FormatException('Unterminated Lua string');
      }
      i++;
      result.add((
        text: source.substring(start, i),
        start: start,
        end: i,
        string: true,
      ));
      continue;
    }
    final word = RegExp(r'[A-Za-z_][A-Za-z0-9_]*|\d+').matchAsPrefix(source, i);
    i = word?.end ?? i + 1;
    result.add((
      text: source.substring(start, i),
      start: start,
      end: i,
      string: false,
    ));
  }
  return result;
}
