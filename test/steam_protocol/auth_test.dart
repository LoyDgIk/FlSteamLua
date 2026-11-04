import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_steam_lua/features/steam_protocol/auth/auth_wire.dart';
import 'package:fl_steam_lua/features/steam_protocol/auth/steam_auth_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('RSA password encoding has PKCS1 v1.5 padding and fixed width', () {
    final encrypted = encryptSteamPassword(
      'test password',
      List.filled(256, 'f').join(),
      '1',
      random: Random(1),
    );
    final bytes = base64Decode(encrypted);
    expect(bytes.length, 128);
    expect(bytes.take(2), [0, 2]);
    final delimiter = bytes.indexOf(0, 2);
    expect(delimiter, greaterThanOrEqualTo(10));
    expect(utf8.decode(bytes.sublist(delimiter + 1)), 'test password');
    expect(bytes.sublist(2, delimiter).contains(0), isFalse);
  });

  test(
    'authentication request uses protobuf and processes Guard polling',
    () async {
      final sent = <String>[];
      final accountId = BigInt.parse('76561198000000000');
      final auth = SteamAuthClient(
        MockClient((_) async => http.Response('', 500)),
        transport: (method, payload) async {
          sent.add(method);
          final input = AuthProtoReader(payload);
          switch (method) {
            case 'GetPasswordRSAPublicKey':
              expect(input.string(1), 'alice');
              return SteamAuthResponse(
                (AuthProtoWriter()
                      ..string(1, List.filled(256, 'f').join())
                      ..string(2, '10001')
                      ..integer(3, 123))
                    .toBytes(),
              );
            case 'BeginAuthSessionViaCredentials':
              expect(input.string(2), 'alice');
              expect(input.string(3), isNot('password'));
              expect(input.integer(6).toInt(), 1);
              return SteamAuthResponse(
                (AuthProtoWriter()
                      ..integer(1, BigInt.parse('18446744073709550000'))
                      ..bytes(2, [1, 2, 3])
                      ..float32(3, 1.5)
                      ..bytes(4, (AuthProtoWriter()..integer(1, 3)).toBytes())
                      ..integer(5, accountId))
                    .toBytes(),
              );
            case 'UpdateAuthSessionWithSteamGuardCode':
              expect(input.integer(2), accountId);
              expect(input.string(3), 'ABCDE');
              expect(input.integer(4).toInt(), 3);
              return SteamAuthResponse(Uint8List(0));
            case 'PollAuthSessionStatus':
              expect(input.bytes(2), [1, 2, 3]);
              return SteamAuthResponse(
                (AuthProtoWriter()
                      ..string(3, 'refresh')
                      ..string(4, 'access')
                      ..string(6, 'alice')
                      ..string(7, 'guard-data'))
                    .toBytes(),
              );
            default:
              throw StateError(method);
          }
        },
      );
      final challenge = await auth.beginCredentials('alice', 'password');
      expect(challenge.interval, const Duration(milliseconds: 1500));
      expect(challenge.allowedConfirmations.single.needsCode, isTrue);
      await auth.submitGuard(challenge, 'ABCDE', 3);
      final tokens = await auth.poll(challenge);
      expect(tokens?.refreshToken, 'refresh');
      expect(tokens?.guardData, 'guard-data');
      expect(sent, [
        'GetPasswordRSAPublicKey',
        'BeginAuthSessionViaCredentials',
        'UpdateAuthSessionWithSteamGuardCode',
        'PollAuthSessionStatus',
      ]);
    },
  );

  test('poll can update client id before authentication completes', () async {
    final challenge = AuthChallenge(
      clientId: BigInt.one,
      requestId: Uint8List.fromList([4]),
      steamId: BigInt.two,
      interval: const Duration(seconds: 1),
      allowedConfirmations: [],
      accountName: 'alice',
    );
    final auth = SteamAuthClient(
      MockClient((_) async => http.Response('', 500)),
      transport: (_, _) async =>
          SteamAuthResponse((AuthProtoWriter()..integer(1, 55)).toBytes()),
    );
    expect(await auth.poll(challenge), isNull);
    expect(challenge.clientId, BigInt.from(55));
  });

  test('HTTP transport sends binary input and preserves rejection', () async {
    final auth = SteamAuthClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/IAuthenticationService/GenerateAccessTokenForApp/v1/',
        );
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data'),
        );
        return http.Response('', 200, headers: {'x-eresult': '5'});
      }),
    );
    await expectLater(
      auth.renew(BigInt.one, 'refresh'),
      throwsA(
        isA<SteamAuthException>().having((error) => error.result, 'result', 5),
      ),
    );
  });

  test(
    'renewal retains old refresh token when Steam does not rotate it',
    () async {
      final auth = SteamAuthClient(
        MockClient((_) async => http.Response('', 500)),
        transport: (_, payload) async {
          final input = AuthProtoReader(payload);
          expect(input.string(1), 'old-refresh');
          expect(input.integer(2), BigInt.from(765));
          return SteamAuthResponse(
            (AuthProtoWriter()..string(1, 'new-access')).toBytes(),
          );
        },
      );
      final tokens = await auth.renew(BigInt.from(765), 'old-refresh');
      expect(tokens.accessToken, 'new-access');
      expect(tokens.refreshToken, 'old-refresh');
    },
  );

  test('JWT SteamID decoding preserves unsigned 64 bit identifier', () {
    final payload = base64Url.encode(
      utf8.encode('{"sub":"76561198000000000"}'),
    );
    expect(
      jwtSteamId('header.$payload.signature'),
      BigInt.parse('76561198000000000'),
    );
    expect(() => jwtSteamId('invalid'), throwsFormatException);
  });

  test('malformed protobuf authentication responses are rejected', () {
    expect(() => AuthProtoReader([10, 5, 1]), throwsFormatException);
    expect(() => AuthProtoReader([0]), throwsFormatException);
  });
}
