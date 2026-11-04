import 'dart:convert';
import 'dart:typed_data';

class SteamDepotInfo {
  const SteamDepotInfo({
    required this.depotId,
    required this.appId,
    this.manifestGid,
    this.name = '',
    this.dlcAppId,
  });
  final int depotId;
  final int appId;
  final BigInt? manifestGid;
  final String name;
  final int? dlcAppId;
}

class SteamAppInfo {
  const SteamAppInfo({
    required this.appId,
    required this.name,
    required this.depots,
    required this.dlcAppIds,
    required this.data,
  });
  final int appId;
  final String name;
  final List<SteamDepotInfo> depots;
  final List<int> dlcAppIds;
  final Map<String, dynamic> data;

  factory SteamAppInfo.fromData(int appId, Map<String, dynamic> root) {
    final data = root['appinfo'] is Map<String, dynamic>
        ? root['appinfo'] as Map<String, dynamic>
        : root;
    final common = data['common'] is Map ? data['common'] as Map : const {};
    final extended = data['extended'] is Map
        ? data['extended'] as Map
        : const {};
    final depotsData = data['depots'] is Map ? data['depots'] as Map : const {};
    final dlcs = <int>{};
    for (final id in '${extended['listofdlc'] ?? ''}'.split(',')) {
      final value = int.tryParse(id.trim());
      if (value != null && value > 0) dlcs.add(value);
    }
    final depots = <SteamDepotInfo>[];
    for (final entry in depotsData.entries) {
      final depotId = int.tryParse('${entry.key}');
      if (depotId == null || entry.value is! Map) continue;
      final node = entry.value as Map;
      final sharedApp =
          int.tryParse('${node['depotfromapp'] ?? appId}') ?? appId;
      if (sharedApp != appId) continue;
      final dlc = int.tryParse('${node['dlcappid'] ?? ''}');
      if (dlc != null) dlcs.add(dlc);
      final manifests = node['manifests'];
      final public = manifests is Map ? manifests['public'] : null;
      final gid = public is Map ? public['gid'] : public;
      depots.add(
        SteamDepotInfo(
          depotId: depotId,
          appId: appId,
          name: '${node['name'] ?? ''}',
          dlcAppId: dlc,
          manifestGid: BigInt.tryParse('$gid'),
        ),
      );
    }
    return SteamAppInfo(
      appId: appId,
      name: '${common['name'] ?? 'App $appId'}',
      depots: depots,
      dlcAppIds: dlcs.toList(),
      data: data,
    );
  }
}

/// Steam PICS app buffers are text KV1; package buffers use binary KV1.
/// Supporting both also permits local protocol fixtures and inspection tools.
Map<String, dynamic> decodeSteamKeyValues(List<int> input) {
  if (input.isEmpty) throw const FormatException('Empty Steam app information');
  final bytes = Uint8List.fromList(input);
  if (bytes.first == 0 || bytes.first == 1) return _BinaryKv(bytes).read();
  final text = utf8.decode(bytes.where((byte) => byte != 0).toList());
  final tokens = <String>[];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (RegExp(r'\s').hasMatch(char)) {
      index++;
      continue;
    }
    if (char == '/' && index + 1 < text.length && text[index + 1] == '/') {
      while (index < text.length && text[index] != '\n') {
        index++;
      }
      continue;
    }
    if (char == '{' || char == '}') {
      tokens.add(char);
      index++;
      continue;
    }
    final buffer = StringBuffer();
    if (char == '"') {
      index++;
      var closed = false;
      while (index < text.length) {
        final c = text[index++];
        if (c == '"') {
          closed = true;
          break;
        }
        if (c == '\\' && index < text.length) {
          final escaped = text[index++];
          buffer.write(switch (escaped) {
            'n' => '\n',
            't' => '\t',
            _ => escaped,
          });
        } else {
          buffer.write(c);
        }
      }
      if (!closed) throw const FormatException('Unterminated Steam KV string');
    } else {
      while (index < text.length && !RegExp(r'[\s{}]').hasMatch(text[index])) {
        buffer.write(text[index++]);
      }
    }
    tokens.add(buffer.toString());
  }
  var cursor = 0;
  Map<String, dynamic> object({bool nested = false}) {
    final result = <String, dynamic>{};
    while (cursor < tokens.length) {
      final key = tokens[cursor++];
      if (key == '}') {
        if (!nested) {
          throw const FormatException('Unexpected Steam KV closing brace');
        }
        return result;
      }
      if (cursor >= tokens.length) {
        throw const FormatException('Missing Steam KV value');
      }
      final value = tokens[cursor++];
      result[key] = value == '{' ? object(nested: true) : value;
    }
    if (nested) throw const FormatException('Unclosed Steam KV object');
    return result;
  }

  return object();
}

class _BinaryKv {
  _BinaryKv(this.bytes);
  final Uint8List bytes;
  int offset = 0;
  Uint8List take(int length) {
    if (offset + length > bytes.length) {
      throw const FormatException('Truncated binary KV');
    }
    final value = Uint8List.sublistView(bytes, offset, offset + length);
    offset += length;
    return value;
  }

  String string() {
    final start = offset;
    while (offset < bytes.length && bytes[offset] != 0) {
      offset++;
    }
    if (offset == bytes.length) {
      throw const FormatException('Unterminated binary KV string');
    }
    return utf8.decode(bytes.sublist(start, offset++));
  }

  Map<String, dynamic> read() {
    final result = <String, dynamic>{};
    while (offset < bytes.length) {
      final type = take(1).first;
      if (type == 8 || type == 11) return result;
      final key = string();
      result[key] = switch (type) {
        0 => read(),
        1 => string(),
        2 => ByteData.sublistView(
          take(4),
        ).getInt32(0, Endian.little).toString(),
        3 => ByteData.sublistView(
          take(4),
        ).getFloat32(0, Endian.little).toString(),
        4 || 6 => ByteData.sublistView(
          take(4),
        ).getUint32(0, Endian.little).toString(),
        7 || 10 => _uint64(),
        _ => throw FormatException('Unsupported binary KV type $type'),
      };
    }
    throw const FormatException('Unterminated binary KV object');
  }

  String _uint64() {
    final value = take(8);
    var number = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      number |= BigInt.from(value[i]) << (8 * i);
    }
    return number.toString();
  }
}
