import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/features/cloud/remote/remote_store.dart';
import 'package:fl_steam_lua/features/cloud/remote/webdav_store.dart';
import 'package:fl_steam_lua/features/cloud/remote/windows_webdav_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'authentication schemes come from challenges, not quoted parameters',
    () {
      expect(webDavAuthenticationSchemes('Negotiate, NTLM TlRMTVNTUAABAA=='), {
        'negotiate',
        'ntlm',
      });
      expect(
        webDavAuthenticationSchemes(
          r'Basic realm="fixture, NTLM, \"Negotiate\"", charset=UTF-8',
        ),
        {'basic'},
      );
      expect(
        webDavAuthenticationSchemes('Digest realm="fixture", nonce="NTLM"'),
        {'digest'},
      );
      expect(
        webDavAuthenticationSchemes('Basic realm="unterminated, NTLM'),
        isEmpty,
      );
    },
  );

  for (final mode in ['ntlm', 'negotiate']) {
    test(
      '$mode uses the native challenge transport and explicit credentials',
      () async {
        WindowsWebDavRequest? sent;
        final store = WebDavRemoteStore(
          MockClient((_) async => throw StateError('Portable transport used')),
          WebDavConfig(
            url: 'https://dav.example.test',
            auth: mode,
            username: r'DOMAIN\user',
            password: 'secret',
          ),
          windowsSender: (request) async {
            sent = request;
            return http.Response.bytes([1, 2, 3], 200);
          },
        );
        expect(await store.read('123/save.dat'), [1, 2, 3]);
        expect(sent!.auth, mode);
        expect(sent!.username, r'DOMAIN\user');
        expect(sent!.password, 'secret');
        expect(
          sent!.headers.keys.map((name) => name.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(sent!.allowInsecureTls, isFalse);
      },
    );
  }

  test('Windows modes require a username at the configuration boundary', () {
    for (final mode in ['ntlm', 'negotiate']) {
      expect(
        () => WebDavRemoteStore(
          MockClient((_) async => http.Response('', 200)),
          WebDavConfig(url: 'https://dav.example.test', auth: mode),
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'auto follows a Windows server challenge without a Basic header',
    () async {
      final store = WebDavRemoteStore(
        MockClient(
          (_) async => http.Response(
            '',
            401,
            headers: {'www-authenticate': 'Negotiate, NTLM'},
          ),
        ),
        const WebDavConfig(
          url: 'https://dav.example.test',
          auth: 'auto',
          username: 'user',
          password: 'secret',
        ),
        windowsSender: (request) async {
          expect(request.auth, 'negotiate');
          expect(
            request.headers.keys.map((name) => name.toLowerCase()),
            isNot(contains('authorization')),
          );
          return http.Response.bytes([9], 200);
        },
      );
      expect(await store.read('save'), [9]);
    },
  );

  test('rejects header injection before reaching either transport', () {
    expect(
      () => WebDavRemoteStore(
        MockClient((_) async => http.Response('', 200)),
        const WebDavConfig(
          url: 'https://dav.example.test',
          auth: 'none',
          extraHeaders: {'X-Extra': 'value\r\nAuthorization: injected'},
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'auto does not interpret a quoted realm as a Windows challenge',
    () async {
      final store = WebDavRemoteStore(
        MockClient(
          (_) async => http.Response(
            '',
            401,
            headers: {
              'www-authenticate': 'Basic realm="fixture, NTLM, Negotiate"',
            },
          ),
        ),
        const WebDavConfig(
          url: 'https://dav.example.test',
          auth: 'auto',
          username: 'fixture-user',
          password: 'fixture-secret',
        ),
        windowsSender: (_) async =>
            throw StateError('Unexpected Windows authentication'),
      );
      await expectLater(
        store.read('save'),
        throwsA(
          isA<RemoteStoreException>().having(
            (e) => e.statusCode,
            'status',
            401,
          ),
        ),
      );
    },
  );

  for (final headerName in [
    'Authorization',
    'authorization',
    'aUtHoRiZaTiOn',
  ]) {
    test(
      'explicit $headerName remains authoritative for native transport',
      () async {
        final store = WebDavRemoteStore(
          MockClient((_) async => throw StateError('Portable transport used')),
          WebDavConfig(
            url: 'https://dav.example.test',
            auth: 'negotiate',
            username: 'user',
            extraHeaders: {headerName: 'Custom explicit-token'},
          ),
          windowsSender: (request) async {
            final authorization = request.headers.entries.where(
              (entry) => entry.key.toLowerCase() == 'authorization',
            );
            expect(authorization, hasLength(1));
            expect(authorization.single.value, 'Custom explicit-token');
            return http.Response.bytes([7], 200);
          },
        );
        expect(await store.read('save'), [7]);
      },
    );
  }

  test(
    'insecure TLS is opt in and round trips the DLL credential field',
    () async {
      final config = WebDavConfig.fromJson({
        'url': 'https://dav.example.test',
        'auth': 'none',
        'allow_insecure_tls': true,
      });
      expect(config.allowInsecureTls, isTrue);
      expect(config.toJson()['allow_insecure_tls'], isTrue);
      final store = WebDavRemoteStore(
        MockClient((_) async => throw StateError('Portable transport used')),
        config,
        windowsSender: (request) async {
          expect(request.allowInsecureTls, isTrue);
          return http.Response('', 204);
        },
      );
      await store.delete('save');
    },
  );

  test(
    'native WinHTTP sends DAV methods and binary body on a local fixture',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final listener = server.listen((request) async {
        expect(request.method, 'PUT');
        expect(request.uri.path, '/dav/save.dat');
        expect(await request.expand((part) => part).toList(), [0, 1, 255]);
        expect(request.headers.value('x-test'), 'native');
        request.response.headers.set('X-Reply', 'received');
        request.response.add([3, 0, 254]);
        await request.response.close();
      });
      try {
        final response = await sendWindowsWebDavRequest(
          WindowsWebDavRequest(
            method: 'PUT',
            uri: Uri.parse('http://127.0.0.1:${server.port}/dav/save.dat'),
            headers: const {'X-Test': 'native'},
            body: Uint8List.fromList([0, 1, 255]),
            auth: 'ntlm',
            username: 'fixture-user',
            password: 'fixture-secret',
            timeoutSec: 5,
            allowInsecureTls: false,
          ),
        );
        expect(response.statusCode, 200);
        expect(response.bodyBytes, [3, 0, 254]);
        expect(response.headers['x-reply'], 'received');
      } finally {
        await listener.cancel();
        await server.close(force: true);
      }
    },
    skip: !Platform.isWindows,
  );

  for (final challenge in [
    'Basic realm="fixture"',
    'Basic realm="fixture, NTLM, Negotiate"',
    'Digest realm="fixture", nonce="NTLM"',
  ]) {
    test(
      'native transport rejects a different authentication scheme: $challenge',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var requests = 0;
        final listener = server.listen((request) async {
          requests++;
          expect(request.headers.value('authorization'), isNull);
          request.response
            ..statusCode = 401
            ..headers.set('WWW-Authenticate', challenge);
          await request.response.close();
        });
        try {
          await expectLater(
            sendWindowsWebDavRequest(
              WindowsWebDavRequest(
                method: 'PROPFIND',
                uri: Uri.parse('http://127.0.0.1:${server.port}/dav/'),
                headers: const {'Depth': '0'},
                body: Uint8List(0),
                auth: 'ntlm',
                username: 'fixture-user',
                password: 'fixture-secret',
                timeoutSec: 5,
                allowInsecureTls: false,
              ),
            ),
            throwsA(
              isA<RemoteStoreException>().having(
                (e) => e.statusCode,
                'status',
                401,
              ),
            ),
          );
          expect(requests, 1);
        } finally {
          await listener.cancel();
          await server.close(force: true);
        }
      },
      skip: !Platform.isWindows,
    );
  }

  test(
    'native probe reads an offered NTLM scheme before an explicit retry',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final authorization = <String?>[];
      final listener = server.listen((request) async {
        authorization.add(request.headers.value('authorization'));
        if (authorization.length == 1) {
          request.response
            ..statusCode = 401
            ..headers.set('WWW-Authenticate', 'NTLM');
        } else {
          request.response.add([8]);
        }
        await request.response.close();
      });
      try {
        final response = await sendWindowsWebDavRequest(
          WindowsWebDavRequest(
            method: 'GET',
            uri: Uri.parse('http://127.0.0.1:${server.port}/dav/'),
            headers: const {},
            body: Uint8List(0),
            auth: 'ntlm',
            username: 'fixture-user',
            password: 'fixture-secret',
            timeoutSec: 5,
            allowInsecureTls: false,
          ),
        );
        expect(response.statusCode, 200);
        expect(response.bodyBytes, [8]);
        expect(authorization, hasLength(2));
        expect(authorization.first, isNull);
      } finally {
        await listener.cancel();
        await server.close(force: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'native transport does not forward credentials through redirects',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final listener = server.listen((request) async {
        requests++;
        request.response
          ..statusCode = 302
          ..headers.set('Location', '/redirected');
        await request.response.close();
      });
      try {
        final response = await sendWindowsWebDavRequest(
          WindowsWebDavRequest(
            method: 'GET',
            uri: Uri.parse('http://127.0.0.1:${server.port}/dav/'),
            headers: const {'Authorization': 'Bearer fixture'},
            body: Uint8List(0),
            auth: 'none',
            username: '',
            password: '',
            timeoutSec: 5,
            allowInsecureTls: false,
          ),
        );
        expect(response.statusCode, 302);
        expect(requests, 1);
      } finally {
        await listener.cancel();
        await server.close(force: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'native authentication challenge preserves an explicit authorization header',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final listener = server.listen((request) async {
        requests++;
        expect(request.headers.value('authorization'), 'Custom explicit-token');
        request.response
          ..statusCode = 401
          ..headers.set('WWW-Authenticate', 'NTLM');
        await request.response.close();
      });
      try {
        final response = await sendWindowsWebDavRequest(
          WindowsWebDavRequest(
            method: 'GET',
            uri: Uri.parse('http://127.0.0.1:${server.port}/dav/'),
            headers: const {'aUtHoRiZaTiOn': 'Custom explicit-token'},
            body: Uint8List(0),
            auth: 'ntlm',
            username: 'fixture-user',
            password: 'fixture-secret',
            timeoutSec: 5,
            allowInsecureTls: false,
          ),
        );
        expect(response.statusCode, 401);
        expect(requests, 1);
      } finally {
        await listener.cancel();
        await server.close(force: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'native unauthenticated loopback request does not use ambient credentials',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final listener = server.listen((request) async {
        requests++;
        expect(request.headers.value('authorization'), isNull);
        request.response
          ..statusCode = 401
          ..headers.set('WWW-Authenticate', 'NTLM');
        await request.response.close();
      });
      try {
        final response = await sendWindowsWebDavRequest(
          WindowsWebDavRequest(
            method: 'GET',
            uri: Uri.parse('http://127.0.0.1:${server.port}/dav/'),
            headers: const {},
            body: Uint8List(0),
            auth: 'none',
            username: '',
            password: '',
            timeoutSec: 5,
            allowInsecureTls: false,
          ),
        );
        expect(response.statusCode, 401);
        expect(requests, 1);
      } finally {
        await listener.cancel();
        await server.close(force: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
