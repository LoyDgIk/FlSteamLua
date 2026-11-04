import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/features/cloud/cloud_credentials.dart';
import 'package:fl_steam_lua/features/cloud/cloud_oauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('PKCE uses RFC 7636 S256 challenge', () {
    expect(
      CloudOAuth.codeChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('callback rejects state mismatch and provider denial', () {
    expect(
      () => CloudOAuth.callbackCode(
        Uri.parse('/?state=other&code=code'),
        'expected',
      ),
      throwsFormatException,
    );
    expect(
      () => CloudOAuth.callbackCode(
        Uri.parse('/?state=expected&error=denied'),
        'expected',
      ),
      throwsStateError,
    );
    expect(
      CloudOAuth.callbackCode(
        Uri.parse('/?state=expected&code=code'),
        'expected',
      ),
      'code',
    );
  });

  test('expired OAuth token is refreshed and rotated token persisted', () async {
    final temp = await Directory.systemTemp.createTemp('flsteam-oauth-');
    final codec = CredentialCodec(
      protect: (value) => Uint8List.fromList(value),
      unprotect: (value) => Uint8List.fromList(value),
    );
    final credentials = CloudCredentialStore(temp.path, codec);
    final now = DateTime.utc(2026, 11, 1);
    await credentials.write('gdrive', {
      'access_token': 'expired',
      'refresh_token': 'refresh',
      'expires_at': 1,
    });
    final oauth = CloudOAuth(
      client: MockClient((request) async {
        expect(request.url.host, 'oauth2.googleapis.com');
        expect(request.bodyFields['grant_type'], 'refresh_token');
        expect(request.bodyFields['refresh_token'], 'refresh');
        return http.Response(
          '{"access_token":"new","refresh_token":"rotated","expires_in":3600}',
          200,
        );
      }),
      credentials: credentials,
      openBrowser: (_) async => true,
      clock: () => now,
    );
    expect(await oauth.accessToken('gdrive'), 'new');
    final value = (await credentials.read('gdrive'))!;
    expect(value['refresh_token'], 'rotated');
    expect(value['expires_at'], now.millisecondsSinceEpoch ~/ 1000 + 3600);
    await temp.delete(recursive: true);
  });

  test('valid token avoids network requests', () async {
    final temp = await Directory.systemTemp.createTemp('flsteam-oauth-');
    final credentials = CloudCredentialStore(
      temp.path,
      CredentialCodec(protect: (b) => b, unprotect: (b) => b),
    );
    final now = DateTime.utc(2026, 11, 1);
    await credentials.write('onedrive', {
      'access_token': 'valid',
      'refresh_token': 'refresh',
      'expires_at': now.millisecondsSinceEpoch ~/ 1000 + 3600,
    });
    final oauth = CloudOAuth(
      client: MockClient(
        (request) async => throw StateError('Unexpected network request'),
      ),
      credentials: credentials,
      openBrowser: (_) async => true,
      clock: () => now,
    );
    expect(await oauth.accessToken('onedrive'), 'valid');
    await temp.delete(recursive: true);
  });
}
