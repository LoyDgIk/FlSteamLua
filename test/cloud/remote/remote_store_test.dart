import 'dart:convert';

import 'package:fl_steam_lua/features/cloud/remote/cloud_remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('remote paths', () {
    test('rejects traversal at the provider boundary', () {
      expect(
        () => normalizeRemotePath('account/../secrets'),
        throwsFormatException,
      );
      expect(
        () => normalizeRemotePath('account/./save'),
        throwsFormatException,
      );
      expect(
        normalizeRemotePath('/account\\10//save.dat/'),
        'account/10/save.dat',
      );
    });
    test('rejects insecure endpoints unless explicitly enabled', () {
      expect(
        () => validateRemoteEndpoint('http://host/dav'),
        throwsFormatException,
      );
      expect(
        validateRemoteEndpoint(
          'http://host/dav',
          allowInsecureHttp: true,
        ).scheme,
        'http',
      );
    });
  });

  group('S3/R2', () {
    const config = S3Config(
      endpoint: 'https://s3.example.test',
      bucket: 'saves',
      accessKeyId: 'access',
      secretAccessKey: 'secret',
      keyPrefix: 'games',
      region: 'auto',
    );
    test('SigV4 matches an independently calculated canonical fixture', () {
      final store = S3RemoteStore(
        MockClient((_) async => http.Response('', 200)),
        const S3Config(
          endpoint: 'https://examplebucket.s3.amazonaws.com',
          bucket: 'examplebucket',
          accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
          secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
          region: 'us-east-1',
          signPayload: true,
        ),
      );
      final headers = store.signedHeaders(
        'GET',
        Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        [],
        now: DateTime.utc(2013, 5, 24),
      );
      expect(headers['x-amz-date'], '20130524T000000Z');
      expect(
        headers['Authorization'],
        endsWith(
          'Signature=df548e2ce037944d03f3e68682813b093763996d597cf890ca3d9037fd231eb4',
        ),
      );
    });
    test(
      'lists direct children with pagination and strips configured prefix',
      () async {
        final seen = <http.Request>[];
        final client = MockClient((request) async {
          seen.add(request);
          if (!request.url.queryParameters.containsKey('continuation-token')) {
            return http.Response(
              '<ListBucketResult><CommonPrefixes><Prefix>games/123/</Prefix></CommonPrefixes>'
              '<IsTruncated>true</IsTruncated><NextContinuationToken>next+token</NextContinuationToken></ListBucketResult>',
              200,
            );
          }
          return http.Response(
            '<ListBucketResult><Contents><Key>games/note.txt</Key><Size>12</Size>'
            '<LastModified>2026-11-01T01:00:00Z</LastModified></Contents><IsTruncated>false</IsTruncated></ListBucketResult>',
            200,
          );
        });
        final result = await S3RemoteStore(client, config).list('');
        expect(result.map((e) => e.path), ['123', 'note.txt']);
        expect(result.first.isDirectory, isTrue);
        expect(result.last.size, 12);
        expect(seen.first.url.queryParameters['prefix'], 'games/');
        expect(
          seen.last.url.queryParameters['continuation-token'],
          'next+token',
        );
        expect(
          seen.first.headers['Authorization'],
          startsWith('AWS4-HMAC-SHA256 '),
        );
      },
    );
    test('writes exact payload and encodes unicode/space paths once', () async {
      late http.Request seen;
      final store = S3RemoteStore(
        MockClient((request) async {
          seen = request;
          return http.Response('', 200);
        }),
        config,
      );
      await store.write('123/10/save slot.dat', [0, 2, 255]);
      expect(
        seen.url.toString(),
        'https://s3.example.test/saves/games/123/10/save%20slot.dat',
      );
      expect(seen.bodyBytes, [0, 2, 255]);
    });
    test('propagates access denied instead of an empty list', () async {
      final store = S3RemoteStore(
        MockClient((_) async => http.Response('denied', 403)),
        config,
      );
      await expectLater(
        store.list(''),
        throwsA(
          isA<RemoteStoreException>().having(
            (e) => e.statusCode,
            'status',
            403,
          ),
        ),
      );
    });
  });

  group('WebDAV', () {
    test('native credential header arrays and timeout round trip', () {
      final config = WebDavConfig.fromJson({
        'url': 'https://dav.example.test/dav',
        'auth': 'none',
        'timeout_sec': 15,
        'extra_headers': ['Translate: f', 'X-Save: value:with:colons'],
      });
      expect(config.timeoutSec, 15);
      expect(config.extraHeaders, {
        'Translate': 'f',
        'X-Save': 'value:with:colons',
      });
      expect(config.toJson()['extra_headers'], [
        'Translate: f',
        'X-Save: value:with:colons',
      ]);
    });
    const config = WebDavConfig(
      url: 'https://dav.example.test/dav',
      username: 'u',
      password: 'p',
    );
    test(
      'parses namespace independent multistatus and skips parent/outside entries',
      () async {
        final client = MockClient((request) async {
          expect(request.method, 'PROPFIND');
          expect(request.url.path, '/dav/CloudRedirect/123/');
          expect(request.headers['Authorization'], 'Basic dTpw');
          expect(request.headers['Depth'], '1');
          return http.Response('''<d:multistatus xmlns:d="DAV:">
          <d:response><d:href>/dav/CloudRedirect/123/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
          <d:response><d:href>/dav/CloudRedirect/123/10/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
          <d:response><d:href>/dav/CloudRedirect/123/save%20slot.dat</d:href><d:propstat><d:prop><d:getcontentlength>42</d:getcontentlength><d:getlastmodified>Sun, 01 Nov 2026 01:00:00 GMT</d:getlastmodified></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
          <d:response><d:href>/outside/file</d:href><d:propstat><d:prop/><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
        </d:multistatus>''', 207);
        });
        final entries = await WebDavRemoteStore(client, config).list('123');
        expect(entries.map((e) => e.path), ['123/10', '123/save slot.dat']);
        expect(entries.last.size, 42);
        expect(entries.last.modifiedAt, DateTime.utc(2026, 11, 1, 1));
      },
    );
    test('creates missing collection chain before upload', () async {
      final methods = <String>[];
      final store = WebDavRemoteStore(
        MockClient((request) async {
          methods.add('${request.method} ${request.url.path}');
          return http.Response('', request.method == 'MKCOL' ? 201 : 204);
        }),
        config,
      );
      await store.write('123/10/save.dat', [1, 2]);
      expect(methods, [
        'MKCOL /dav/CloudRedirect/',
        'MKCOL /dav/CloudRedirect/123/',
        'MKCOL /dav/CloudRedirect/123/10/',
        'PUT /dav/CloudRedirect/123/10/save.dat',
      ]);
    });
    test('auto authentication retries with digest challenge', () async {
      var attempts = 0;
      final store = WebDavRemoteStore(
        MockClient((request) async {
          if (attempts++ == 0) {
            return http.Response(
              '',
              401,
              headers: {
                'www-authenticate':
                    'Digest realm="save", nonce="abc", qop="auth", algorithm=SHA-256',
              },
            );
          }
          expect(
            request.headers['Authorization'],
            startsWith('Digest username="u"'),
          );
          expect(
            request.headers['Authorization'],
            contains('algorithm=SHA-256'),
          );
          return http.Response.bytes([3], 200);
        }),
        const WebDavConfig(
          url: 'https://dav.example.test',
          username: 'u',
          password: 'p',
          auth: 'auto',
        ),
      );
      expect(await store.read('123/10/save.dat'), [3]);
      expect(attempts, 2);
    });
  });

  group('OAuth providers', () {
    test(
      'Google Drive creates a resumable upload and sends exact bytes',
      () async {
        final calls = <String>[];
        final store = GoogleDriveRemoteStore(
          MockClient((request) async {
            calls.add('${request.method} ${request.url.path}');
            if (request.url.path.startsWith('/upload/')) {
              expect(request.method, 'POST');
              expect(jsonDecode(request.body)['name'], 'save.dat');
              return http.Response(
                '',
                200,
                headers: {
                  'location':
                      'https://www.googleapis.com/session?upload_id=xyz',
                },
              );
            }
            if (request.url.path == '/session') {
              expect(request.url.queryParameters['upload_id'], 'xyz');
              expect(request.method, 'PUT');
              expect(request.bodyBytes, [1, 2, 3]);
              return http.Response('{"id":"saved"}', 200);
            }
            final query = request.url.queryParameters['q'] ?? '';
            final name = RegExp("name = '([^']*)'").firstMatch(query)?.group(1);
            if (name == 'save.dat') return http.Response('{"files":[]}', 200);
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'folder-$name',
                    'name': name,
                    'mimeType': 'application/vnd.google-apps.folder',
                  },
                ],
              }),
              200,
            );
          }),
          () async => 'token',
        );
        await store.write('123/10/save.dat', [1, 2, 3]);
        expect(calls.last, 'PUT /session');
      },
    );
    test('OneDrive creates parent folders and uploads a small file', () async {
      final calls = <String>[];
      final store = OneDriveRemoteStore(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'GET') return http.Response('', 404);
          if (request.method == 'POST') {
            expect(jsonDecode(request.body)['folder'], isEmpty);
            return http.Response('{"id":"folder"}', 201);
          }
          expect(request.method, 'PUT');
          expect(
            request.url.path,
            '/v1.0/me/drive/root:/CloudRedirect/123/10/save.dat:/content',
          );
          expect(request.bodyBytes, [7, 8]);
          return http.Response('{"id":"file"}', 201);
        }),
        () async => 'token',
      );
      await store.write('123/10/save.dat', [7, 8]);
      expect(calls.where((value) => value.startsWith('POST')).length, 3);
    });
    test(
      'Google Drive resolves CloudRedirect hierarchy and pages children',
      () async {
        final client = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          final query = request.url.queryParameters['q'] ?? '';
          if (query.contains("name = 'CloudRedirect'")) {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'root-cloud',
                    'name': 'CloudRedirect',
                    'mimeType': 'application/vnd.google-apps.folder',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.queryParameters['pageToken'] == 'next') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'b',
                    'name': '456',
                    'mimeType': 'application/vnd.google-apps.folder',
                  },
                ],
              }),
              200,
            );
          }
          expect(query, "'root-cloud' in parents and trashed = false");
          return http.Response(
            jsonEncode({
              'nextPageToken': 'next',
              'files': [
                {
                  'id': 'a',
                  'name': '123',
                  'mimeType': 'application/vnd.google-apps.folder',
                },
              ],
            }),
            200,
          );
        });
        final store = GoogleDriveRemoteStore(client, () async => 'token');
        expect((await store.list('')).map((e) => e.path), ['123', '456']);
      },
    );
    test('OneDrive follows trusted pagination and uses logical root', () async {
      final client = MockClient((request) async {
        if (request.url.queryParameters['skip'] == '1') {
          return http.Response(
            jsonEncode({
              'value': [
                {'id': '2', 'name': 'save.dat', 'size': 7},
              ],
            }),
            200,
          );
        }
        expect(
          request.url.path,
          '/v1.0/me/drive/root:/CloudRedirect/123/10:/children',
        );
        return http.Response(
          jsonEncode({
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/next?skip=1',
            'value': [
              {'id': '1', 'name': 'nested', 'folder': {}},
            ],
          }),
          200,
        );
      });
      final entries = await OneDriveRemoteStore(
        client,
        () async => 'token',
      ).list('123/10');
      expect(entries.map((e) => e.path), ['123/10/nested', '123/10/save.dat']);
      expect(entries.last.size, 7);
    });
    test('OneDrive metadata deletion has no trailing path delimiter', () async {
      final store = OneDriveRemoteStore(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/v1.0/me/drive/root:/CloudRedirect/123/10');
          return http.Response('', 204);
        }),
        () async => 'token',
      );
      await store.delete('123/10');
    });
    test(
      'untrusted pagination URLs are rejected before token disclosure',
      () async {
        final store = OneDriveRemoteStore(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                '@odata.nextLink': 'https://untrusted.example/next',
                'value': [],
              }),
              200,
            ),
          ),
          () async => 'token',
        );
        await expectLater(store.list(''), throwsFormatException);
      },
    );
  });
}
