import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;

import 'remote_store.dart';

/// The boundary passed to the synchronous Windows transport's worker isolate.
class WindowsWebDavRequest {
  const WindowsWebDavRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
    required this.auth,
    required this.username,
    required this.password,
    required this.timeoutSec,
    required this.allowInsecureTls,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Uint8List body;
  final String auth;
  final String username;
  final String password;
  final int timeoutSec;
  final bool allowInsecureTls;
}

typedef WindowsWebDavSender =
    Future<http.Response> Function(WindowsWebDavRequest request);

/// Reads challenge names without treating quoted auth parameters as schemes.
Set<String> webDavAuthenticationSchemes(String challenge) {
  final parts = <String>[];
  var quoted = false;
  var escaped = false;
  var start = 0;
  for (var index = 0; index < challenge.length; index++) {
    final character = challenge.codeUnitAt(index);
    if (escaped) {
      escaped = false;
    } else if (quoted && character == 0x5c) {
      escaped = true;
    } else if (character == 0x22) {
      quoted = !quoted;
    } else if (!quoted && character == 0x2c) {
      parts.add(challenge.substring(start, index).trim());
      start = index + 1;
    }
  }
  if (quoted) return {};
  parts.add(challenge.substring(start).trim());
  final name = RegExp(r"^([!#$%&'*+.^_`|~0-9A-Za-z-]+)(?:[ \t]+|$)");
  return parts
      .map(name.firstMatch)
      .whereType<RegExpMatch>()
      .map((match) => match.group(1)!.toLowerCase())
      .toSet();
}

/// WinHTTP owns the NTLM/Negotiate handshake and connection-bound credentials.
/// Blocking native calls run away from Flutter's UI isolate.
Future<http.Response> sendWindowsWebDavRequest(
  WindowsWebDavRequest request,
) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('Windows WebDAV authentication requires Windows');
  }
  if (['ntlm', 'negotiate'].contains(request.auth) &&
      !request.headers.keys.any(
        (name) => name.toLowerCase() == 'authorization',
      ) &&
      request.username.trim().isEmpty) {
    throw const FormatException('A WebDAV username is required');
  }
  return Isolate.run(() => _WinHttp().send(request));
}

class _WinHttp {
  _WinHttp();

  final _library = DynamicLibrary.open('winhttp.dll');
  final _kernel = DynamicLibrary.open('kernel32.dll');

  late final _open = _library
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Utf16>,
          Uint32,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Uint32,
        ),
        Pointer<Void> Function(
          Pointer<Utf16>,
          int,
          Pointer<Utf16>,
          Pointer<Utf16>,
          int,
        )
      >('WinHttpOpen');
  late final _connect = _library
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>, Uint16, Uint32),
        Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>, int, int)
      >('WinHttpConnect');
  late final _openRequest = _library
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Pointer<Utf16>>,
          Uint32,
        ),
        Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Pointer<Utf16>>,
          int,
        )
      >('WinHttpOpenRequest');
  late final _close = _library
      .lookupFunction<
        Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('WinHttpCloseHandle');
  late final _timeouts = _library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Int32, Int32, Int32, Int32),
        int Function(Pointer<Void>, int, int, int, int)
      >('WinHttpSetTimeouts');
  late final _setOption = _library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Uint32, Pointer<Void>, Uint32),
        int Function(Pointer<Void>, int, Pointer<Void>, int)
      >('WinHttpSetOption');
  late final _send = _library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Uint32,
          Pointer<Void>,
          Uint32,
          Uint32,
          UintPtr,
        ),
        int Function(
          Pointer<Void>,
          Pointer<Utf16>,
          int,
          Pointer<Void>,
          int,
          int,
          int,
        )
      >('WinHttpSendRequest');
  late final _addHeaders = _library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Utf16>, Uint32, Uint32),
        int Function(Pointer<Void>, Pointer<Utf16>, int, int)
      >('WinHttpAddRequestHeaders');
  late final _receive = _library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('WinHttpReceiveResponse');
  late final _queryHeaders = _library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Uint32,
          Pointer<Utf16>,
          Pointer<Void>,
          Pointer<Uint32>,
          Pointer<Uint32>,
        ),
        int Function(
          Pointer<Void>,
          int,
          Pointer<Utf16>,
          Pointer<Void>,
          Pointer<Uint32>,
          Pointer<Uint32>,
        )
      >('WinHttpQueryHeaders');
  late final _credentials = _library
      .lookupFunction<
        Int32 Function(
          Pointer<Void>,
          Uint32,
          Uint32,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Void>,
        ),
        int Function(
          Pointer<Void>,
          int,
          int,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Pointer<Void>,
        )
      >('WinHttpSetCredentials');
  late final _read = _library
      .lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Void>, Uint32, Pointer<Uint32>),
        int Function(Pointer<Void>, Pointer<Void>, int, Pointer<Uint32>)
      >('WinHttpReadData');
  late final _lastError = _kernel
      .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

  Never _failed(String operation, [int? code]) => throw WindowsWebDavException(
    'WebDAV Windows transport: $operation failed',
    code ?? _lastError(),
  );

  void _check(int result, String operation) {
    if (result == 0) _failed(operation);
  }

  void _option(Pointer<Void> handle, int option, int value, Arena arena) {
    final data = arena<Uint32>()..value = value;
    _check(_setOption(handle, option, data.cast(), 4), 'SetOption');
  }

  http.Response send(WindowsWebDavRequest input) => using((arena) {
    final session = _open(
      'FlSteamLua/0.1'.toNativeUtf16(allocator: arena),
      4, // WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY (Windows 8.1 and newer).
      nullptr,
      nullptr,
      0,
    );
    if (session == nullptr) _failed('Open');
    Pointer<Void> connection = nullptr;
    Pointer<Void> request = nullptr;
    try {
      final timeout = (input.timeoutSec > 0 ? input.timeoutSec : 30) * 1000;
      _check(
        _timeouts(session, timeout, timeout, timeout, timeout),
        'SetTimeouts',
      );
      connection = _connect(
        session,
        input.uri.host.toNativeUtf16(allocator: arena),
        input.uri.port,
        0,
      );
      if (connection == nullptr) _failed('Connect');
      final target = input.uri.hasQuery
          ? '${input.uri.path}?${input.uri.query}'
          : input.uri.path;
      final headerText = input.headers.entries
          .map((entry) => '${entry.key}: ${entry.value}\r\n')
          .join();
      final headerPointer = headerText.toNativeUtf16(allocator: arena);
      final bytes = arena<Uint8>(input.body.isEmpty ? 1 : input.body.length);
      bytes.asTypedList(input.body.length).setAll(0, input.body);
      final length = arena<Uint32>()..value = 4;
      final status = arena<Uint32>();
      final hasExplicitAuth = input.headers.keys.any(
        (name) => name.toLowerCase() == 'authorization',
      );
      final scheme = switch (input.auth) {
        'ntlm' => 0x2,
        'negotiate' => 0x10,
        _ => 0,
      };

      void openRequest({required bool authenticate}) {
        request = _openRequest(
          connection,
          input.method.toNativeUtf16(allocator: arena),
          (target.isEmpty ? '/' : target).toNativeUtf16(allocator: arena),
          nullptr,
          nullptr,
          nullptr,
          input.uri.scheme == 'https' ? 0x00800000 : 0,
        );
        if (request == nullptr) _failed('OpenRequest');
        _option(request, 88, 0, arena); // REDIRECT_POLICY_NEVER.
        _option(request, 77, 2, arena); // AUTOLOGON_SECURITY_LEVEL_HIGH.
        if (!authenticate) {
          // HIGH alone does not block ambient credentials for localhost/IPs.
          // It also cannot preserve a manually supplied Authorization header.
          _option(request, 63, 4, arena); // DISABLE_AUTHENTICATION.
        } else {
          // Automatic authentication is enabled only with explicit, non-null
          // credentials, and only after checking the offered server scheme.
          _check(
            _credentials(
              request,
              0,
              scheme,
              input.username.toNativeUtf16(allocator: arena),
              input.password.toNativeUtf16(allocator: arena),
              nullptr,
            ),
            'SetCredentials',
          );
        }
        if (input.allowInsecureTls) {
          _option(request, 31, 0x00003300, arena);
        }
        if (headerText.isNotEmpty) {
          _check(
            _addHeaders(request, headerPointer, headerText.length, 0x20000000),
            'AddRequestHeaders',
          );
        }
      }

      openRequest(authenticate: false);
      var credentialsSet = false;
      var received = false;
      for (var attempt = 0; attempt < 4; attempt++) {
        if (_send(
              request,
              nullptr,
              0,
              bytes.cast(),
              input.body.length,
              input.body.length,
              0,
            ) ==
            0) {
          final error = _lastError();
          if (error == 12032 && attempt < 3) continue;
          _failed('SendRequest', error);
        }
        if (_receive(request, nullptr) == 0) {
          final error = _lastError();
          if (error == 12032 && attempt < 3) continue;
          _failed('ReceiveResponse', error);
        }
        length.value = 4;
        _check(
          _queryHeaders(
            request,
            19 | 0x20000000,
            nullptr,
            status.cast(),
            length,
            nullptr,
          ),
          'QueryStatus',
        );
        if (status.value != 401 ||
            scheme == 0 ||
            hasExplicitAuth ||
            credentialsSet) {
          received = true;
          break;
        }
        // Automatic authentication is disabled for the probe, so WinHTTP does
        // not populate QueryAuthSchemes. Read the actual response header.
        final offered = webDavAuthenticationSchemes(
          _headers(request, arena)['www-authenticate'] ?? '',
        );
        if (!offered.contains(input.auth)) {
          throw RemoteStoreException(
            'WebDAV server does not offer ${input.auth} authentication',
            statusCode: 401,
          );
        }
        _close(request);
        request = nullptr;
        openRequest(authenticate: true);
        credentialsSet = true;
      }
      if (!received) _failed('Authentication retry', 12032);
      final responseHeaders = _headers(request, arena);
      final output = BytesBuilder(copy: false);
      final buffer = arena<Uint8>(64 * 1024);
      final read = arena<Uint32>();
      while (true) {
        _check(_read(request, buffer.cast(), 64 * 1024, read), 'ReadData');
        if (read.value == 0) break;
        output.add(Uint8List.fromList(buffer.asTypedList(read.value)));
      }
      return http.Response.bytes(
        output.takeBytes(),
        status.value,
        headers: responseHeaders,
      );
    } finally {
      if (request != nullptr) _close(request);
      if (connection != nullptr) _close(connection);
      _close(session);
    }
  });

  Map<String, String> _headers(Pointer<Void> request, Arena arena) {
    final length = arena<Uint32>();
    _queryHeaders(request, 22, nullptr, nullptr, length, nullptr);
    if (length.value == 0) return {};
    final buffer = arena<Uint8>(length.value);
    _check(
      _queryHeaders(request, 22, nullptr, buffer.cast(), length, nullptr),
      'QueryHeaders',
    );
    final result = <String, String>{};
    for (final line
        in buffer.cast<Utf16>().toDartString().split('\r\n').skip(1)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final name = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      result.update(
        name,
        (previous) => '$previous, $value',
        ifAbsent: () => value,
      );
    }
    return result;
  }
}

class WindowsWebDavException implements Exception {
  const WindowsWebDavException(this.message, this.code);
  final String message;
  final int code;
  @override
  String toString() => '$message (Win32 $code)';
}
