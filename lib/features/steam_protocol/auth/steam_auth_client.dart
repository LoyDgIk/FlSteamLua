import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth_wire.dart';

// Field definitions follow SteamDatabase/Protobufs, steammessages_auth.steamclient.proto.
// Source: https://github.com/SteamDatabase/Protobufs/blob/master/steam/steammessages_auth.steamclient.proto

class SteamAuthException implements Exception {
  const SteamAuthException(this.operation, this.result, this.message);
  final String operation;
  final int result;
  final String message;

  @override
  String toString() => 'Steam $operation: $message (EResult $result)';
}

class SteamAuthResponse {
  const SteamAuthResponse(this.body, {this.result = 1, this.message = ''});
  final Uint8List body;
  final int result;
  final String message;
}

typedef SteamAuthTransport =
    Future<SteamAuthResponse> Function(String method, Uint8List payload);

class AuthConfirmation {
  const AuthConfirmation(this.type, this.message);
  final int type;
  final String message;

  bool get needsCode => type == 2 || type == 3;
  bool get needsApproval => type == 4 || type == 5;
}

class AuthChallenge {
  AuthChallenge({
    required this.clientId,
    required this.requestId,
    required this.steamId,
    required this.interval,
    required this.allowedConfirmations,
    required this.accountName,
  });

  BigInt clientId;
  final Uint8List requestId;
  final BigInt steamId;
  final Duration interval;
  final List<AuthConfirmation> allowedConfirmations;
  final String accountName;
}

class SteamAuthTokens {
  const SteamAuthTokens({
    required this.accountName,
    required this.accessToken,
    required this.refreshToken,
    this.guardData,
  });

  final String accountName;
  final String accessToken;
  final String refreshToken;
  final String? guardData;

  BigInt get steamId => jwtSteamId(refreshToken);
}

class SteamAuthClient {
  SteamAuthClient(
    this.client, {
    Uri? baseUri,
    this.timeout = const Duration(seconds: 30),
    this.transport,
    this.deviceName = 'FlSteamLua',
  }) : baseUri = baseUri ?? Uri.https('api.steampowered.com', '/');

  final http.Client client;
  final Uri baseUri;
  final Duration timeout;
  final SteamAuthTransport? transport;
  final String deviceName;

  Future<AuthChallenge> beginCredentials(
    String username,
    String password, {
    String? guardData,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('A Steam account name and password are required');
    }
    final rsa = await _call(
      'GetPasswordRSAPublicKey',
      AuthProtoWriter()..string(1, username.trim()),
    );
    final modulus = rsa.string(1);
    final exponent = rsa.string(2);
    if (modulus.isEmpty || exponent.isEmpty || rsa.integer(3) == BigInt.zero) {
      throw const FormatException('Steam returned an invalid RSA public key');
    }
    final encrypted = encryptSteamPassword(password, modulus, exponent);
    final device = AuthProtoWriter()
      ..string(1, deviceName)
      ..integer(2, 1)
      ..integer(3, 20)
      ..integer(4, 1);
    final request = AuthProtoWriter()
      ..string(1, deviceName)
      ..string(2, username.trim())
      ..string(3, encrypted)
      ..integer(4, rsa.integer(3))
      ..integer(5, 1)
      ..integer(6, 1)
      ..integer(7, 1)
      ..string(8, 'Client')
      ..bytes(9, device.toBytes());
    if (guardData != null && guardData.isNotEmpty) {
      request.string(10, guardData);
    }
    final response = await _call('BeginAuthSessionViaCredentials', request);
    final requestId = response.bytes(2);
    final clientId = response.integer(1);
    final steamId = response.integer(5);
    if (clientId == BigInt.zero ||
        steamId == BigInt.zero ||
        requestId.isEmpty) {
      throw const FormatException(
        'Steam returned an incomplete authentication challenge',
      );
    }
    final intervalSeconds = response.float32(3, fallback: 1);
    return AuthChallenge(
      clientId: clientId,
      requestId: requestId,
      steamId: steamId,
      interval: Duration(
        milliseconds: (max(0.5, intervalSeconds) * 1000).round(),
      ),
      allowedConfirmations: response
          .messages(4)
          .map(
            (field) =>
                AuthConfirmation(field.integer(1).toInt(), field.string(2)),
          )
          .toList(growable: false),
      accountName: username.trim(),
    );
  }

  Future<void> submitGuard(
    AuthChallenge challenge,
    String code,
    int type,
  ) async {
    if (type != 2 && type != 3) {
      throw ArgumentError.value(
        type,
        'type',
        'Steam Guard code must be email (2) or device (3)',
      );
    }
    if (code.trim().isEmpty) throw ArgumentError('Steam Guard code is empty');
    final request = AuthProtoWriter()
      ..integer(1, challenge.clientId)
      ..fixed64(2, challenge.steamId)
      ..string(3, code.trim())
      ..integer(4, type);
    await _call('UpdateAuthSessionWithSteamGuardCode', request);
  }

  Future<SteamAuthTokens?> poll(AuthChallenge challenge) async {
    final response = await _call(
      'PollAuthSessionStatus',
      AuthProtoWriter()
        ..integer(1, challenge.clientId)
        ..bytes(2, challenge.requestId),
    );
    final updatedClient = response.integer(1);
    if (updatedClient != BigInt.zero) challenge.clientId = updatedClient;
    final refreshToken = response.string(3);
    final accessToken = response.string(4);
    if (refreshToken.isEmpty) return null;
    if (accessToken.isEmpty) {
      throw const FormatException(
        'Steam completed authentication without an access token',
      );
    }
    final accountName = response.string(6);
    return SteamAuthTokens(
      accountName: accountName.isEmpty ? challenge.accountName : accountName,
      accessToken: accessToken,
      refreshToken: refreshToken,
      guardData: response.string(7).isEmpty ? null : response.string(7),
    );
  }

  Future<SteamAuthTokens> waitForTokens(
    AuthChallenge challenge, {
    Duration deadline = const Duration(minutes: 3),
    bool Function()? isCancelled,
  }) async {
    final until = DateTime.now().add(deadline);
    while (DateTime.now().isBefore(until)) {
      if (isCancelled?.call() ?? false) {
        throw const SteamAuthException(
          'authentication',
          52,
          'Authentication cancelled',
        );
      }
      final tokens = await poll(challenge);
      if (tokens != null) return tokens;
      await Future<void>.delayed(challenge.interval);
    }
    throw TimeoutException('Steam Guard approval timed out', deadline);
  }

  Future<SteamAuthTokens> renew(BigInt steamId, String refreshToken) async {
    final response = await _call(
      'GenerateAccessTokenForApp',
      AuthProtoWriter()
        ..string(1, refreshToken)
        ..fixed64(2, steamId)
        ..integer(3, 1),
    );
    final accessToken = response.string(1);
    if (accessToken.isEmpty) {
      throw const FormatException(
        'Steam token renewal returned no access token',
      );
    }
    final renewed = response.string(2);
    return SteamAuthTokens(
      accountName: '',
      accessToken: accessToken,
      refreshToken: renewed.isEmpty ? refreshToken : renewed,
    );
  }

  Future<AuthProtoReader> _call(String method, AuthProtoWriter payload) async {
    final response =
        await (transport?.call(method, payload.toBytes()) ??
                _requestHttp(method, payload.toBytes()))
            .timeout(timeout);
    if (response.result != 1) {
      throw SteamAuthException(
        method,
        response.result,
        response.message.isNotEmpty
            ? response.message
            : _resultDescription(response.result),
      );
    }
    return AuthProtoReader(response.body);
  }

  Future<SteamAuthResponse> _requestHttp(
    String method,
    Uint8List payload,
  ) async {
    final endpoint = baseUri.resolve('IAuthenticationService/$method/v1/');
    final encoded = base64Encode(payload);
    final http.BaseRequest request;
    if (method == 'GetPasswordRSAPublicKey') {
      request = http.Request(
        'GET',
        endpoint.replace(queryParameters: {'input_protobuf_encoded': encoded}),
      );
    } else {
      request = http.MultipartRequest('POST', endpoint)
        ..fields['input_protobuf_encoded'] = encoded;
    }
    request.headers.addAll({
      'accept': 'application/octet-stream',
      'user-agent': 'FlSteamLua/0.1',
      'origin': 'https://steamloopback.host',
      'referer': 'https://steamloopback.host/',
    });
    final result = await http.Response.fromStream(await client.send(request));
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw SteamAuthException(
        method,
        result.statusCode,
        'HTTP ${result.statusCode}',
      );
    }
    final resultCode = int.tryParse(result.headers['x-eresult'] ?? '');
    if (resultCode == null) {
      throw const FormatException(
        'Steam authentication response omitted x-eresult',
      );
    }
    return SteamAuthResponse(
      result.bodyBytes,
      result: resultCode,
      message: result.headers['x-error_message'] ?? '',
    );
  }
}

String encryptSteamPassword(
  String password,
  String modulusHex,
  String exponentHex, {
  Random? random,
}) {
  final modulus = BigInt.parse(modulusHex, radix: 16);
  final exponent = BigInt.parse(exponentHex, radix: 16);
  final size = (modulus.bitLength + 7) ~/ 8;
  final passwordBytes = utf8.encode(password);
  if (size < 64 ||
      exponent <= BigInt.zero ||
      passwordBytes.length > size - 11) {
    throw const FormatException('Password or RSA key is invalid');
  }
  final entropy = random ?? Random.secure();
  // RSAES-PKCS1-v1_5, required by Steam's password authentication endpoint.
  final block = Uint8List(size)..[1] = 2;
  final delimiter = size - passwordBytes.length - 1;
  for (var i = 2; i < delimiter; i++) {
    block[i] = entropy.nextInt(255) + 1;
  }
  block.setRange(delimiter + 1, size, passwordBytes);
  var message = BigInt.zero;
  for (final byte in block) {
    message = (message << 8) | BigInt.from(byte);
  }
  var encrypted = message.modPow(exponent, modulus);
  final output = Uint8List(size);
  for (var i = size - 1; i >= 0; i--) {
    output[i] = (encrypted & BigInt.from(255)).toInt();
    encrypted >>= 8;
  }
  return base64Encode(output);
}

BigInt jwtSteamId(String token) {
  final parts = token.split('.');
  if (parts.length != 3) throw const FormatException('Invalid Steam token');
  final payload = jsonDecode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  );
  if (payload is! Map<String, dynamic> || payload['sub'] == null) {
    throw const FormatException('Steam token has no subject');
  }
  return BigInt.parse(payload['sub'].toString());
}

String _resultDescription(int result) => switch (result) {
  5 => 'Incorrect account name or password',
  15 => 'Account access denied',
  20 => 'Steam service unavailable',
  29 => 'Authentication token expired',
  63 => 'Steam Guard code is incorrect',
  65 => 'Steam Guard code has expired',
  84 => 'Too many login attempts; try again later',
  85 => 'Steam Guard code is incorrect',
  _ => 'Steam rejected the authentication request',
};
