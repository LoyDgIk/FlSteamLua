import 'manifest_models.dart';

class ManifestScriptParser {
  static ManifestSourceDefinition parse(String script, {bool builtIn = false}) {
    final metadata = <String, String>{};
    final parameters = <ManifestParameter>[];
    final parameterKeys = <String>{};
    for (final raw in script.split('\n')) {
      final line = raw.trim();
      if (!line.startsWith('//')) continue;
      final comment = line.substring(2).trim();
      if (!comment.startsWith('@')) continue;
      final space = comment.indexOf(RegExp(r'\s'));
      final key =
          (space < 0 ? comment.substring(1) : comment.substring(1, space))
              .toLowerCase();
      final value = space < 0 ? '' : comment.substring(space).trim();
      if (key != 'param') {
        if ((key == 'provides' || key == 'manifest-types') &&
            metadata.containsKey(key)) {
          throw FormatException('Duplicate @$key declaration');
        }
        metadata.putIfAbsent(key, () => value);
        continue;
      }
      final tokens = _tokens(value);
      if (tokens.isEmpty ||
          !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(tokens.first)) {
        throw const FormatException('Invalid manifest source parameter');
      }
      final parameterKey = tokens.first;
      if (!parameterKeys.add(parameterKey)) {
        throw FormatException('Duplicate manifest parameter: $parameterKey');
      }
      final attrs = <String, String>{};
      for (final token in tokens.skip(1)) {
        final eq = token.indexOf('=');
        if (eq > 0) {
          attrs[token.substring(0, eq).toLowerCase()] = token.substring(eq + 1);
        }
      }
      final type = switch (attrs['type']) {
        'password' => ManifestParameterType.password,
        'number' || 'integer' || 'int' => ManifestParameterType.number,
        'bool' || 'boolean' => ManifestParameterType.boolean,
        _ => ManifestParameterType.text,
      };
      parameters.add(
        ManifestParameter(
          key: parameterKey,
          label: attrs['label'] ?? parameterKey,
          type: type,
          description: attrs['description'] ?? attrs['desc'] ?? '',
          required: attrs['required'] == 'true',
          defaultValue: attrs['default'] ?? '',
        ),
      );
    }
    final id = metadata['id'] ?? '';
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$').hasMatch(id)) {
      throw const FormatException('Manifest source requires a valid @id');
    }
    return ManifestSourceDefinition(
      id: id,
      name: metadata['name'] ?? id,
      script: script,
      description: metadata['description'] ?? '',
      homepage: metadata['homepage'] ?? '',
      author: metadata['author'] ?? '',
      version: metadata['version'] ?? '2.0.0',
      builtIn: builtIn,
      parameters: List.unmodifiable(parameters),
      capabilities: _capabilities(metadata),
      hasCapabilityDeclaration: metadata.containsKey('provides'),
    );
  }

  static Set<ContentCapability> _capabilities(Map<String, String> metadata) {
    if (!metadata.containsKey('provides')) {
      if (metadata.containsKey('manifest-types')) {
        throw const FormatException('@manifest-types requires @provides');
      }
      return const {ContentCapability.manifestFiles};
    }
    final provides = metadata['provides']!
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .toSet();
    if (provides.isEmpty ||
        provides.any((value) => value != 'lua' && value != 'manifest')) {
      throw const FormatException('Invalid @provides capability');
    }
    final result = <ContentCapability>{
      if (provides.contains('lua')) ContentCapability.lua,
    };
    final types = metadata['manifest-types'];
    if (provides.contains('manifest')) {
      if (types == null || types.trim().isEmpty) {
        throw const FormatException(
          'Manifest capability requires @manifest-types',
        );
      }
      for (final type
          in types.split(',').map((value) => value.trim().toLowerCase())) {
        switch (type) {
          case 'ids':
            result.add(ContentCapability.manifestIds);
          case 'files':
            result.add(ContentCapability.manifestFiles);
          case 'codes':
            result.add(ContentCapability.manifestRequestCodes);
          default:
            throw FormatException('Invalid @manifest-types value: $type');
        }
      }
    } else if (types != null) {
      throw const FormatException(
        '@manifest-types requires manifest capability',
      );
    }
    return Set.unmodifiable(result);
  }

  static List<String> _tokens(String text) {
    final result = <String>[];
    var current = StringBuffer();
    String? quote;
    for (var i = 0; i < text.length; i++) {
      final character = text[i];
      if (quote != null) {
        if (character == quote) {
          quote = null;
        } else if (character == '\\' && i + 1 < text.length) {
          current.write(text[++i]);
        } else {
          current.write(character);
        }
      } else if (character == '"' || character == "'") {
        quote = character;
      } else if (character.trim().isEmpty) {
        if (current.isNotEmpty) result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(character);
      }
    }
    if (quote != null) {
      throw const FormatException('Unclosed manifest parameter quote');
    }
    if (current.isNotEmpty) result.add(current.toString());
    return result;
  }
}
