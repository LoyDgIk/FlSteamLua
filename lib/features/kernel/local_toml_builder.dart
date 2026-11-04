import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

enum LocalTomlBuildEventKind {
  dllLocated,
  hashComputed,
  patternScan,
  hookResolved,
  hookMissing,
  componentWritten,
  componentRejected,
  ipcWrapper,
  ipcVtable,
  completed,
}

class LocalTomlBuildEvent {
  const LocalTomlBuildEvent({
    required this.kind,
    this.component = '',
    this.name = '',
    this.value = '',
    this.size = 0,
    this.resolved = 0,
    this.total = 0,
  });

  final LocalTomlBuildEventKind kind;
  final String component;
  final String name;
  final String value;
  final int size;
  final int resolved;
  final int total;

  Map<String, Object> toMap() => {
    'kind': kind.name,
    'component': component,
    'name': name,
    'value': value,
    'size': size,
    'resolved': resolved,
    'total': total,
  };

  factory LocalTomlBuildEvent.fromMap(Map<dynamic, dynamic> map) =>
      LocalTomlBuildEvent(
        kind: LocalTomlBuildEventKind.values.byName(map['kind'] as String),
        component: map['component'] as String? ?? '',
        name: map['name'] as String? ?? '',
        value: map['value'] as String? ?? '',
        size: map['size'] as int? ?? 0,
        resolved: map['resolved'] as int? ?? 0,
        total: map['total'] as int? ?? 0,
      );
}

class LocalTomlComponentResult {
  const LocalTomlComponentResult({
    required this.component,
    required this.success,
    required this.written,
    required this.resolved,
    required this.total,
    this.error = '',
  });

  final String component;
  final bool success;
  final bool written;
  final int resolved;
  final int total;
  final String error;

  Map<String, Object> toMap() => {
    'component': component,
    'success': success,
    'written': written,
    'resolved': resolved,
    'total': total,
    'error': error,
  };

  factory LocalTomlComponentResult.fromMap(Map<dynamic, dynamic> map) =>
      LocalTomlComponentResult(
        component: map['component'] as String,
        success: map['success'] as bool,
        written: map['written'] as bool,
        resolved: map['resolved'] as int,
        total: map['total'] as int,
        error: map['error'] as String? ?? '',
      );
}

class LocalTomlBuildReport {
  const LocalTomlBuildReport({
    required this.clientSha,
    required this.uiSha,
    required this.components,
  });

  final String clientSha;
  final String uiSha;
  final List<LocalTomlComponentResult> components;

  int get writtenCount => components.where((item) => item.written).length;

  Map<String, Object> toMap() => {
    'clientSha': clientSha,
    'uiSha': uiSha,
    'components': components.map((item) => item.toMap()).toList(),
  };

  factory LocalTomlBuildReport.fromMap(Map<dynamic, dynamic> map) =>
      LocalTomlBuildReport(
        clientSha: map['clientSha'] as String,
        uiSha: map['uiSha'] as String,
        components: (map['components'] as List)
            .cast<Map>()
            .map(LocalTomlComponentResult.fromMap)
            .toList(growable: false),
      );
}

Future<LocalTomlBuildReport> buildLocalSteamTomls({
  required String steamPath,
  void Function(LocalTomlBuildEvent event)? onEvent,
}) async {
  final port = ReceivePort();
  final isolate = await Isolate.spawn(_localTomlBuildWorker, [
    port.sendPort,
    steamPath,
  ]);
  try {
    await for (final message in port) {
      if (message is! Map) continue;
      switch (message['kind']) {
        case 'event':
          onEvent?.call(LocalTomlBuildEvent.fromMap(message['event'] as Map));
          break;
        case 'done':
          return LocalTomlBuildReport.fromMap(message['report'] as Map);
        case 'error':
          throw StateError(message['message'] as String);
      }
    }
    throw StateError('Local TOML builder stopped without a result');
  } finally {
    isolate.kill(priority: Isolate.immediate);
    port.close();
  }
}

void _localTomlBuildWorker(List<Object> args) async {
  final send = args[0] as SendPort;
  final steamPath = args[1] as String;
  try {
    final report = await _LocalTomlBuilder(steamPath, (event) {
      send.send({'kind': 'event', 'event': event.toMap()});
    }).build();
    send.send({'kind': 'done', 'report': report.toMap()});
  } catch (error) {
    send.send({'kind': 'error', 'message': '$error'});
  }
}

class _LocalTomlBuilder {
  _LocalTomlBuilder(this.steamPath, this.onEvent);

  final String steamPath;
  final void Function(LocalTomlBuildEvent event) onEvent;

  Future<LocalTomlBuildReport> build() async {
    final client = File(p.join(steamPath, 'steamclient64.dll'));
    final ui = File(p.join(steamPath, 'SteamUI.dll'));
    if (!await client.exists() || !await ui.exists()) {
      throw StateError('steamclient64.dll or SteamUI.dll is missing');
    }
    final clientSize = await client.length();
    final uiSize = await ui.length();
    onEvent(
      LocalTomlBuildEvent(
        kind: LocalTomlBuildEventKind.dllLocated,
        component: 'steamclient',
        name: p.basename(client.path),
        value: client.path,
        size: clientSize,
      ),
    );
    onEvent(
      LocalTomlBuildEvent(
        kind: LocalTomlBuildEventKind.dllLocated,
        component: 'steamui',
        name: p.basename(ui.path),
        value: ui.path,
        size: uiSize,
      ),
    );

    final clientSha = (await sha256.bind(client.openRead()).first).toString();
    final uiSha = (await sha256.bind(ui.openRead()).first).toString();
    onEvent(
      LocalTomlBuildEvent(
        kind: LocalTomlBuildEventKind.hashComputed,
        component: 'steamclient',
        name: p.basename(client.path),
        value: clientSha,
      ),
    );
    onEvent(
      LocalTomlBuildEvent(
        kind: LocalTomlBuildEventKind.hashComputed,
        component: 'steamui',
        name: p.basename(ui.path),
        value: uiSha,
      ),
    );

    final clientBytes = await client.readAsBytes();
    final uiBytes = await ui.readAsBytes();
    final components = <LocalTomlComponentResult>[];
    components.add(
      await _buildPatternComponent(
        module: 'steamclient',
        sha: clientSha,
        bytes: clientBytes,
        specs: _steamclientPatterns,
      ),
    );
    components.add(
      await _buildPatternComponent(
        module: 'steamui',
        sha: uiSha,
        bytes: uiBytes,
        specs: _steamuiPatterns,
      ),
    );
    components.add(
      await _buildIpcComponent(sha: clientSha, bytes: clientBytes),
    );
    onEvent(
      LocalTomlBuildEvent(
        kind: LocalTomlBuildEventKind.completed,
        resolved: components.where((item) => item.written).length,
        total: components.length,
      ),
    );
    return LocalTomlBuildReport(
      clientSha: clientSha,
      uiSha: uiSha,
      components: List.unmodifiable(components),
    );
  }

  Future<LocalTomlComponentResult> _buildPatternComponent({
    required String module,
    required String sha,
    required Uint8List bytes,
    required List<_PatternSpec> specs,
  }) async {
    try {
      onEvent(
        LocalTomlBuildEvent(
          kind: LocalTomlBuildEventKind.patternScan,
          component: module,
        ),
      );
      final image = _PeImage.parse(bytes);
      final resolved = image.resolvePatterns(specs);
      for (final spec in specs) {
        final rva = resolved[spec.name];
        onEvent(
          LocalTomlBuildEvent(
            kind: rva == null
                ? LocalTomlBuildEventKind.hookMissing
                : LocalTomlBuildEventKind.hookResolved,
            component: module,
            name: spec.name,
            value: rva == null ? '' : _hex(rva),
            size: spec.signature.length,
          ),
        );
      }
      if (resolved.length != specs.length) {
        final error = '${specs.length - resolved.length} hooks unresolved';
        onEvent(
          LocalTomlBuildEvent(
            kind: LocalTomlBuildEventKind.componentRejected,
            component: module,
            resolved: resolved.length,
            total: specs.length,
          ),
        );
        return LocalTomlComponentResult(
          component: module,
          success: false,
          written: false,
          resolved: resolved.length,
          total: specs.length,
          error: error,
        );
      }
      final content = _patternToml(module, sha, specs, resolved);
      final target = File(
        p.join(steamPath, 'opensteamtool', 'pattern', module, '$sha.toml'),
      );
      await _writeAtomically(target, content);
      onEvent(
        LocalTomlBuildEvent(
          kind: LocalTomlBuildEventKind.componentWritten,
          component: module,
          resolved: specs.length,
          total: specs.length,
        ),
      );
      return LocalTomlComponentResult(
        component: module,
        success: true,
        written: true,
        resolved: specs.length,
        total: specs.length,
      );
    } catch (error) {
      onEvent(
        LocalTomlBuildEvent(
          kind: LocalTomlBuildEventKind.componentRejected,
          component: module,
          total: specs.length,
        ),
      );
      return LocalTomlComponentResult(
        component: module,
        success: false,
        written: false,
        resolved: 0,
        total: specs.length,
        error: '$error',
      );
    }
  }

  Future<LocalTomlComponentResult> _buildIpcComponent({
    required String sha,
    required Uint8List bytes,
  }) async {
    final total = _ipcInterfaces.fold<int>(
      0,
      (sum, interface) => sum + interface.methods.length,
    );
    try {
      final image = _PeImage.parse(bytes);
      final resolved = image.resolveIpc(_ipcInterfaces);
      for (final interface in _ipcInterfaces) {
        final result = resolved.interfaces[interface.name];
        for (final method in interface.methods) {
          final wrapper = result?.wrappers[method.name];
          if (wrapper != null) {
            onEvent(
              LocalTomlBuildEvent(
                kind: LocalTomlBuildEventKind.ipcWrapper,
                component: 'ipc/steamclient',
                name: method.name,
                value: _hex(wrapper),
              ),
            );
          }
        }
        if (result != null) {
          onEvent(
            LocalTomlBuildEvent(
              kind: LocalTomlBuildEventKind.ipcVtable,
              component: 'ipc/steamclient',
              name: interface.name,
              value: _hex(result.vtableRva),
              resolved: result.wrappers.length,
              total: interface.methods.length,
            ),
          );
        }
      }
      final count = resolved.interfaces.values.fold<int>(
        0,
        (sum, interface) => sum + interface.wrappers.length,
      );
      final content = _ipcToml(sha, resolved);
      final target = File(
        p.join(steamPath, 'opensteamtool', 'ipc', 'steamclient', '$sha.toml'),
      );
      await _writeAtomically(target, content);
      onEvent(
        LocalTomlBuildEvent(
          kind: LocalTomlBuildEventKind.componentWritten,
          component: 'ipc/steamclient',
          resolved: count,
          total: total,
        ),
      );
      return LocalTomlComponentResult(
        component: 'ipc/steamclient',
        success: true,
        written: true,
        resolved: count,
        total: total,
      );
    } catch (error) {
      onEvent(
        LocalTomlBuildEvent(
          kind: LocalTomlBuildEventKind.componentRejected,
          component: 'ipc/steamclient',
          total: total,
        ),
      );
      return LocalTomlComponentResult(
        component: 'ipc/steamclient',
        success: false,
        written: false,
        resolved: 0,
        total: total,
        error: '$error',
      );
    }
  }
}

Future<void> _writeAtomically(File target, String content) async {
  await target.parent.create(recursive: true);
  final temp = File(
    '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
  );
  await temp.writeAsString(content, flush: true);
  await temp.rename(target.path);
}

String _patternToml(
  String module,
  String sha,
  List<_PatternSpec> specs,
  Map<String, int> resolved,
) {
  final output = StringBuffer()
    ..writeln('# Generated locally by FlSteamLua')
    ..writeln('# Temporary signatures for Steam $module $sha')
    ..writeln();
  for (final spec in specs) {
    output
      ..writeln(
        '[0x${_fnv1a32(spec.name).toRadixString(16).toUpperCase().padLeft(8, '0')}]',
      )
      ..writeln('name = "${spec.name}"')
      ..writeln('rva = "${_hex(resolved[spec.name]!)}"')
      ..writeln('sig = "${spec.signature}"')
      ..writeln();
  }
  return output.toString();
}

String _ipcToml(String sha, _IpcResolution resolution) {
  final output = StringBuffer()
    ..writeln('# Generated locally by FlSteamLua')
    ..writeln('# Temporary signatures for Steam steamclient $sha')
    ..writeln();
  for (final interface in _ipcInterfaces) {
    final result = resolution.interfaces[interface.name]!;
    output
      ..writeln('[${interface.name}]')
      ..writeln('interface_id = ${interface.id}')
      ..writeln('vtable_rva = "${_hex(result.vtableRva)}"')
      ..writeln();
    for (final method in interface.methods) {
      output
        ..writeln('[${interface.name}.${method.name}]')
        ..writeln('method_index = ${method.index}')
        ..writeln('funcHash = "${_hex32(method.funcHash)}"')
        ..writeln('wrapper_rva = "${_hex(result.wrappers[method.name]!)}"')
        ..writeln('fencepost = "${_hex32(method.fencepost)}"')
        ..writeln('argc = ${method.argc}')
        ..writeln();
    }
  }
  return output.toString();
}

class _PeImage {
  _PeImage._({
    required this.bytes,
    required this.imageBase,
    required this.sections,
    required this.functions,
  });

  factory _PeImage.parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 0x40 || data.getUint16(0, Endian.little) != 0x5a4d) {
      throw const FormatException('Not a PE image');
    }
    final peOffset = data.getUint32(0x3c, Endian.little);
    if (data.getUint32(peOffset, Endian.little) != 0x4550) {
      throw const FormatException('Invalid PE signature');
    }
    final sectionCount = data.getUint16(peOffset + 6, Endian.little);
    final optionalSize = data.getUint16(peOffset + 20, Endian.little);
    final optionalOffset = peOffset + 24;
    if (data.getUint16(optionalOffset, Endian.little) != 0x20b) {
      throw const FormatException('Expected a PE32+ image');
    }
    final imageBase = data.getUint64(optionalOffset + 24, Endian.little);
    final directoryCount = data.getUint32(optionalOffset + 108, Endian.little);
    if (directoryCount <= 3) {
      throw const FormatException('PE exception directory is unavailable');
    }
    final exceptionRva = data.getUint32(
      optionalOffset + 112 + 3 * 8,
      Endian.little,
    );
    final exceptionSize = data.getUint32(
      optionalOffset + 112 + 3 * 8 + 4,
      Endian.little,
    );
    final sections = <_PeSection>[];
    final sectionOffset = optionalOffset + optionalSize;
    for (var index = 0; index < sectionCount; index++) {
      final offset = sectionOffset + index * 40;
      final nameBytes = bytes.sublist(offset, offset + 8);
      final nameEnd = nameBytes.indexOf(0);
      final name = String.fromCharCodes(
        nameEnd < 0 ? nameBytes : nameBytes.sublist(0, nameEnd),
      );
      sections.add(
        _PeSection(
          name: name,
          virtualAddress: data.getUint32(offset + 12, Endian.little),
          virtualSize: data.getUint32(offset + 8, Endian.little),
          rawOffset: data.getUint32(offset + 20, Endian.little),
          rawSize: data.getUint32(offset + 16, Endian.little),
        ),
      );
    }
    final image = _PeImage._(
      bytes: bytes,
      imageBase: imageBase,
      sections: sections,
      functions: const [],
    );
    final exceptionOffset = image.rvaToOffset(exceptionRva);
    if (exceptionOffset == null) {
      throw const FormatException('PE exception directory is unreadable');
    }
    final functions = <_PeFunction>[];
    for (var offset = 0; offset + 12 <= exceptionSize; offset += 12) {
      final begin = data.getUint32(exceptionOffset + offset, Endian.little);
      final end = data.getUint32(exceptionOffset + offset + 4, Endian.little);
      if (begin != 0 && end > begin) {
        functions.add(_PeFunction(begin, end));
      }
    }
    functions.sort((left, right) => left.begin.compareTo(right.begin));
    return _PeImage._(
      bytes: bytes,
      imageBase: imageBase,
      sections: sections,
      functions: List.unmodifiable(functions),
    );
  }

  final Uint8List bytes;
  final int imageBase;
  final List<_PeSection> sections;
  final List<_PeFunction> functions;

  int? rvaToOffset(int rva) {
    for (final section in sections) {
      final size = section.virtualSize > section.rawSize
          ? section.virtualSize
          : section.rawSize;
      if (rva >= section.virtualAddress &&
          rva < section.virtualAddress + size) {
        return section.rawOffset + rva - section.virtualAddress;
      }
    }
    return null;
  }

  Map<String, int> resolvePatterns(List<_PatternSpec> specs) {
    final text = sections.where((section) => section.name == '.text').first;
    final offset = text.rawOffset;
    final end = offset + text.rawSize;
    final byPrefix = <int, List<_PatternSpec>>{};
    for (final spec in specs) {
      final bytes = _signatureBytes(spec.signature);
      byPrefix.putIfAbsent(_uint64At(bytes, 0), () => []).add(spec);
    }
    final matches = <String, Set<int>>{
      for (final spec in specs) spec.name: <int>{},
    };
    for (var position = offset; position + 8 <= end; position++) {
      final candidates = byPrefix[_uint64At(bytes, position)];
      if (candidates == null) continue;
      for (final spec in candidates) {
        final signature = _signatureBytes(spec.signature);
        if (_matchesAt(bytes, position, signature)) {
          matches[spec.name]!.add(text.virtualAddress + position - offset);
        }
      }
    }
    return {
      for (final spec in specs)
        if (matches[spec.name]!.length == 1)
          spec.name: matches[spec.name]!.single,
    };
  }

  _IpcResolution resolveIpc(List<_IpcInterfaceSpec> interfaces) {
    final text = sections.where((section) => section.name == '.text').first;
    final data = ByteData.sublistView(bytes);
    final interfaceResults = <String, _IpcInterfaceResolution>{};
    for (final interface in interfaces) {
      final candidatesByMethod = <String, List<int>>{};
      for (final method in interface.methods) {
        final candidates = _markerFunctions(text, method);
        if (candidates.isEmpty) {
          throw FormatException(
            'IPC wrapper ${method.name} has no matching function',
          );
        }
        candidatesByMethod[method.name] = candidates;
      }
      int? vtable;
      Map<String, int>? wrappers;
      for (final method in interface.methods) {
        for (final wrapper in candidatesByMethod[method.name]!) {
          final pointer = imageBase + wrapper;
          for (final section in sections) {
            if (section.name != '.rdata' && section.name != '.data') continue;
            final start = section.rawOffset;
            final end = start + section.rawSize;
            for (var position = start; position + 8 <= end; position += 8) {
              if (data.getUint64(position, Endian.little) != pointer) continue;
              final candidate =
                  section.virtualAddress + position - start - method.index * 8;
              if (candidate < 0) continue;
              final resolved = <String, int>{};
              for (final check in interface.methods) {
                final slot = rvaToOffset(candidate + check.index * 8);
                if (slot == null || slot + 8 > bytes.length) continue;
                final value = data.getUint64(slot, Endian.little) - imageBase;
                if (candidatesByMethod[check.name]!.contains(value)) {
                  resolved[check.name] = value;
                }
              }
              if (resolved.length == interface.methods.length) {
                if (vtable != null && vtable != candidate) {
                  throw FormatException(
                    'IPC vtable ${interface.name} is ambiguous',
                  );
                }
                vtable = candidate;
                wrappers = resolved;
              }
            }
          }
        }
      }
      if (vtable == null || wrappers == null) {
        throw FormatException('IPC vtable ${interface.name} was not found');
      }
      interfaceResults[interface.name] = _IpcInterfaceResolution(
        vtableRva: vtable,
        wrappers: wrappers,
      );
    }
    return _IpcResolution(interfaceResults);
  }

  List<int> _markerFunctions(_PeSection text, _IpcMethodSpec method) {
    final result = <int>{};
    final hashBytes = _u32Bytes(method.funcHash);
    final fencepostBytes = _u32Bytes(method.fencepost);
    final start = text.rawOffset;
    final end = start + text.rawSize;
    for (var position = start; position + 4 <= end; position++) {
      if (!_matchesAt(bytes, position, hashBytes)) continue;
      final rva = text.virtualAddress + position - start;
      final function = _functionAt(rva);
      if (function == null) continue;
      final functionStart = rvaToOffset(function.begin);
      final functionEnd = rvaToOffset(function.end);
      if (functionStart == null || functionEnd == null) continue;
      if (!_contains(bytes, functionStart, functionEnd, fencepostBytes)) {
        continue;
      }
      result.add(function.begin);
      var chainedStart = function.begin;
      for (var index = _functionIndexAt(rva) - 1; index >= 0; index--) {
        final previous = functions[index];
        if (previous.end != chainedStart ||
            chainedStart - previous.begin > 64) {
          break;
        }
        chainedStart = previous.begin;
        result.add(chainedStart);
      }
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  _PeFunction? _functionAt(int rva) {
    final index = _functionIndexAt(rva);
    return index < 0 ? null : functions[index];
  }

  int _functionIndexAt(int rva) {
    var low = 0;
    var high = functions.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final function = functions[middle];
      if (rva < function.begin) {
        high = middle - 1;
      } else if (rva >= function.end) {
        low = middle + 1;
      } else {
        return middle;
      }
    }
    return -1;
  }
}

class _PeSection {
  const _PeSection({
    required this.name,
    required this.virtualAddress,
    required this.virtualSize,
    required this.rawOffset,
    required this.rawSize,
  });

  final String name;
  final int virtualAddress;
  final int virtualSize;
  final int rawOffset;
  final int rawSize;
}

class _PeFunction {
  const _PeFunction(this.begin, this.end);

  final int begin;
  final int end;
}

class _PatternSpec {
  const _PatternSpec(this.name, this.signature);

  final String name;
  final String signature;
}

class _IpcInterfaceSpec {
  const _IpcInterfaceSpec(this.name, this.id, this.methods);

  final String name;
  final int id;
  final List<_IpcMethodSpec> methods;
}

class _IpcMethodSpec {
  const _IpcMethodSpec(
    this.name,
    this.index,
    this.funcHash,
    this.fencepost,
    this.argc,
  );

  final String name;
  final int index;
  final int funcHash;
  final int fencepost;
  final int argc;
}

class _IpcResolution {
  const _IpcResolution(this.interfaces);

  final Map<String, _IpcInterfaceResolution> interfaces;
}

class _IpcInterfaceResolution {
  const _IpcInterfaceResolution({
    required this.vtableRva,
    required this.wrappers,
  });

  final int vtableRva;
  final Map<String, int> wrappers;
}

int _fnv1a32(String value) {
  var hash = 0x811c9dc5;
  for (final byte in value.codeUnits) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

String _hex(int value) => '0x${value.toRadixString(16).toUpperCase()}';

String _hex32(int value) =>
    '0x${value.toRadixString(16).toUpperCase().padLeft(8, '0')}';

Uint8List _signatureBytes(String value) => Uint8List.fromList(
  value
      .trim()
      .split(RegExp(r'\s+'))
      .map((part) => int.parse(part, radix: 16))
      .toList(),
);

Uint8List _u32Bytes(int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return data.buffer.asUint8List();
}

int _uint64At(Uint8List value, int offset) =>
    value[offset] |
    value[offset + 1] << 8 |
    value[offset + 2] << 16 |
    value[offset + 3] << 24 |
    value[offset + 4] << 32 |
    value[offset + 5] << 40 |
    value[offset + 6] << 48 |
    value[offset + 7] << 56;

bool _matchesAt(Uint8List source, int offset, Uint8List pattern) {
  if (offset + pattern.length > source.length) return false;
  for (var index = 0; index < pattern.length; index++) {
    if (source[offset + index] != pattern[index]) return false;
  }
  return true;
}

bool _contains(Uint8List source, int start, int end, Uint8List pattern) {
  for (var position = start; position + pattern.length <= end; position++) {
    if (_matchesAt(source, position, pattern)) return true;
  }
  return false;
}

const _steamclientPatterns = <_PatternSpec>[
  _PatternSpec(
    'BBuildAndAsyncSendFrame',
    '48 8B C4 55 48 8D 68 A1 48 81 EC C0 00 00 00 48 89 70 18 49 8B F0 48 89',
  ),
  _PatternSpec(
    'BuildDepotDependency',
    '48 8B C4 4C 89 48 20 89 50 10 48 89 48 08 55 48 8D A8 78 FE FF FF 48 81',
  ),
  _PatternSpec(
    'BuildSpawnEnvBlock',
    '4C 89 4C 24 20 4C 89 44 24 18 48 89 54 24 10 48 89 4C 24 08 55 53 56 57 41 54 41 55 41 56 41 57 48 8D AC 24 B8',
  ),
  _PatternSpec(
    'CUser_BuildSessionTicket',
    '48 89 5C 24 20 44 89 44 24 18 48 89 54 24 10 55 56 57 41 54 41 55 41 56 41 57 48 8D',
  ),
  _PatternSpec(
    'CUtlBufferEnsureCapacity',
    '48 89 5C 24 08 57 48 83 EC 30 48 8B D9 8D 7A 01 0F B6 49 1F F6 C1 01 8B',
  ),
  _PatternSpec(
    'CUtlMemoryGrow',
    '48 89 5C 24 10 57 48 83 EC 30 8B FA 48 8B D9 8B 51 08 8B 49 10 8D 04 39 3B C2 0F 8E EE 00 00 00 2B CA 48 89 74 24 40 8D 34 39 85 F6 7F 28 4C 8D 05 03 F6',
  ),
  _PatternSpec(
    'CheckAppOwnership',
    '48 8B C4 89 50 10 48 89 48 08 55 53 48 8D 68 D8 48 81 EC 18 01 00 00 48',
  ),
  _PatternSpec(
    'CloseAppCloud',
    '48 89 5C 24 10 57 48 83 EC 30 8B FA 48 8B D9 85 D2 75 33 48 8B 0D 1E CA',
  ),
  _PatternSpec(
    'ConfigStoreGetBinary',
    '40 53 55 56 57 48 83 EC 38 48 63 FA 49 8B E9 8B D7 49 8B D8 48 8B F1 E8',
  ),
  _PatternSpec(
    'FindOrCreateKey',
    '48 8B C4 4C 89 48 20 57 48 81 EC 60 04 00 00 48 89 70 E8 48 8B FA 4C 89',
  ),
  _PatternSpec(
    'GetAppDataFromAppInfo',
    '40 53 55 56 57 41 56 41 57 48 81 EC 78 01 00 00 41 C6 01 00 49 8B F1 49',
  ),
  _PatternSpec(
    'GetAppIDForCurrentPipe',
    '8B 81 D0 10 00 00 83 F8 FF 74 49 44 8B 89 D8 00 00 00 4C 8D 91 B8 10 00',
  ),
  _PatternSpec(
    'GetOrAddAppData',
    '48 83 EC 58 48 8B 05 E5 42 CC 00 48 89 5C 24 68 48 89 6C 24 70 41 0F B6',
  ),
  _PatternSpec(
    'GetPackageInfo',
    '48 89 5C 24 18 89 54 24 10 55 56 57 48 83 EC 20 44 8B 49 20 49 8B F0 8B',
  ),
  _PatternSpec(
    'GetPipeClient',
    '85 D2 74 30 44 0F B7 CA 44 3B 49 60 73 26 48 8B 41 40 45 8B C1 4D 03 C0',
  ),
  _PatternSpec(
    'IPCProcessMessage',
    '48 89 5C 24 18 48 89 6C 24 20 57 41 54 41 55 41 56 41 57 48 83 EC 30 49',
  ),
  _PatternSpec(
    'KeyValues_FindOrCreateKey',
    '48 8B C4 4C 89 48 20 57 48 81 EC 60 04 00 00 48 89 70 E8 48 8B FA 4C 89',
  ),
  _PatternSpec(
    'KeyValues_ReadAsBinary',
    '48 8B C4 44 88 48 20 55 48 8D 68 A9 48 81 EC C0 00 00 00 48 89 70 F0 48',
  ),
  _PatternSpec(
    'LoadDepotDecryptionKey',
    '40 53 55 56 57 48 83 EC 38 48 63 FA 49 8B E9 8B D7 49 8B D8 48 8B F1 E8',
  ),
  _PatternSpec(
    'LoadPackage',
    '44 89 44 24 18 53 55 56 57 41 55 41 56 41 57 48 81 EC 20 01 00 00 49 63',
  ),
  _PatternSpec(
    'MarkLicenseAsChanged',
    '48 89 5C 24 20 89 54 24 10 55 56 57 48 83 EC 20 83 B9 EC 22 00 00 00 44',
  ),
  _PatternSpec(
    'OptedInMask',
    '89 54 24 10 55 53 56 57 41 55 41 56 48 8D AC 24 38 FF FF FF 48 81 EC C8',
  ),
  _PatternSpec(
    'PchMsgNameFromEMsg',
    '48 89 5C 24 08 57 48 83 EC 20 8B D9 E8 AF F7 FF FF 48 8B 15 28 8E 46 00',
  ),
  _PatternSpec(
    'ProcessPendingLicenseUpdates',
    '41 56 41 57 48 83 EC 38 83 B9 C8 24 00 00 00 B8 E0 23 00 00 48 89 5C 24',
  ),
  _PatternSpec(
    'ReadAsBinary',
    '48 8B C4 44 88 48 20 55 48 8D 68 A9 48 81 EC C0 00 00 00 48 89 70 F0 48',
  ),
  _PatternSpec(
    'RecvPkt',
    '48 8B C4 55 48 8D A8 E8 FB FF FF 48 81 EC 10 05 00 00 48 89 58 08 48 8B',
  ),
  _PatternSpec(
    'SendCallbackToPipe',
    '48 89 5C 24 08 57 48 83 EC 30 41 8B D9 41 8B F8 E8 0B D1 F0 FF 48 8B C8',
  ),
  _PatternSpec(
    'SpawnProcess',
    '48 89 5C 24 18 4C 89 4C 24 20 48 89 54 24 10 55 56 57 41 54 41 55 41 56 41 57 48 8D',
  ),
];

const _steamuiPatterns = <_PatternSpec>[
  _PatternSpec(
    'AddProtobufAsBinary',
    '40 53 55 56 57 48 83 EC 28 48 8B 05 30 64 23 00 48 8B F2 48 8B D9 44 8B',
  ),
  _PatternSpec(
    'BuildCompleteAppOverviewChange',
    '4C 89 44 24 18 48 89 54 24 10 48 89 4C 24 08 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 E1',
  ),
  _PatternSpec(
    'CSteamUIAppControllerRunFrame',
    '48 89 5C 24 10 48 89 6C 24 18 56 57 41 54 41 56 41 57 48 83 EC 40 0F 29',
  ),
  _PatternSpec(
    'FillInAppOverview',
    '48 89 54 24 10 48 89 4C 24 08 55 53 56 57 41 54 41 55 41 56 41 57 48 8D 6C 24 E1 48 81 EC B8',
  ),
  _PatternSpec(
    'GetAppByID',
    '89 54 24 10 53 48 83 EC 40 48 8B 05 E0 01 63 00 41 0F B6 D8 48 89 7C 24',
  ),
  _PatternSpec(
    'GetTopManager',
    '48 8B 05 C9 CA B5 00 C3 CC CC CC CC CC CC CC CC 40 55 53 56 57 41 56 41',
  ),
  _PatternSpec(
    'LoadModuleWithPath',
    '48 89 5C 24 18 55 56 41 57 48 83 EC 40 48 8B E9 4C 89 74 24 68 B9 FC FF',
  ),
  _PatternSpec(
    'MarkAppChange',
    '48 83 EC 78 48 8B 05 75 18 5A 00 48 89 74 24 70 8B F2 4C 89 6C 24 60 4C',
  ),
  _PatternSpec(
    'RepeatedFieldUint32_Add',
    '48 89 74 24 10 48 89 7C 24 18 41 56 48 83 EC 20 8B 31 48 8B F9 8B 49 04 4C 8D 34 B5',
  ),
  _PatternSpec(
    'ShouldShowAppInLibrary',
    '40 53 48 83 EC 20 48 8B 01 48 8B D9 FF 10 3D D6 0C 09 00 0F 84 A7 00 00',
  ),
];

const _ipcInterfaces = <_IpcInterfaceSpec>[
  _IpcInterfaceSpec('IClientUser', 1, [
    _IpcMethodSpec('GetSteamID', 10, 0xD6FC3200, 0xD7058CA5, 0),
    _IpcMethodSpec(
      'GetAppOwnershipTicketExtendedData',
      105,
      0xC7E71245,
      0xC8449840,
      2,
    ),
    _IpcMethodSpec('RequestEncryptedAppTicket', 120, 0x25D6BB1D, 0x2646B663, 2),
    _IpcMethodSpec('GetEncryptedAppTicket', 121, 0xE0468CB4, 0xE0B80200, 1),
  ]),
  _IpcInterfaceSpec('IClientUtils', 4, [
    _IpcMethodSpec('GetAppID', 19, 0x09607EC4, 0x0AFE7552, 0),
    _IpcMethodSpec('GetAPICallResult', 24, 0x2D3D3947, 0x2EDF5EE6, 3),
  ]),
];
