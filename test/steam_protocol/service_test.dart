import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/steam_protocol/cm_client.dart';
import 'package:fl_steam_lua/features/steam_protocol/manifest/depot_manifest.dart';
import 'package:fl_steam_lua/features/steam_protocol/steam_protocol_service.dart';
import 'package:fl_steam_lua/features/steam_protocol/wire/cm_packet.dart';
import 'package:fl_steam_lua/features/steam_protocol/wire/protobuf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'account restore, authorized extraction and CDN token retry cross the module interface',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flsteam-protocol-',
      );
      final paths = AppPaths(directory.path);
      await paths.initialize();
      final settings = SettingsStore(paths);
      final token =
          'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '76561198000000001', 'exp': 4102444800}))).replaceAll('=', '')}.signature';
      await settings.set('steamAccountName', 'fixture');
      await settings.set(
        'steamSession',
        jsonEncode({'accountName': 'fixture', 'refreshToken': token}),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final connections = <WebSocket>[];
      var cdnRequests = 0;
      var cdnAuthRequests = 0;
      var appTokenRequests = 0;
      final appInfoTokens = <BigInt>[];
      final gid = BigInt.parse('18446744073709550001');
      final manifest = DepotManifest(
        depotId: 101,
        manifestGid: gid,
        files: const [
          DepotManifestFile(fileName: 'game/data.bin', size: 4, flags: 0),
        ],
      ).toBytes();
      final client = MockClient((request) async {
        if (request.url.path.contains('GetCMList')) {
          return http.Response(
            jsonEncode({
              'response': {
                'serverlist': [
                  {'endpoint': 'fixture.invalid:443'},
                ],
              },
            }),
            200,
          );
        }
        if (request.url.host == 'cdn.fixture.invalid') {
          cdnRequests++;
          if (!request.url.queryParameters.containsKey('token')) {
            return http.Response('denied', 403);
          }
          expect(request.url.path, '/depot/101/manifest/$gid/5/12345');
          return http.Response.bytes(manifest, 200);
        }
        throw StateError('Unexpected fixture HTTP request ${request.url}');
      });
      final listener = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        connections.add(socket);
        socket.listen((event) {
          for (final packet in CmPacket.decode(event as List<int>)) {
            final header = ProtoWriter()
              ..fixed64(1, BigInt.parse('76561198000000001'))
              ..varint(2, 7);
            if (packet.header.field(10) != null) {
              header.fixed64(11, packet.header.bigInt(10));
            }
            final body = ProtoReader(packet.body);
            switch (packet.messageType) {
              case 5514:
                expect(body.stringValue(108), token);
                socket.add(
                  CmPacket.encode(
                    751,
                    header,
                    ProtoWriter()
                      ..varint(1, 1)
                      ..varint(3, 60),
                  ),
                );
              case 8905:
                appTokenRequests++;
                final appId = body.intValue(2);
                socket.add(
                  CmPacket.encode(
                    8906,
                    header,
                    ProtoWriter()..message(
                      3,
                      ProtoWriter()
                        ..varint(1, appId)
                        ..varint(2, 1),
                    ),
                  ),
                );
              case 8903:
                appInfoTokens.add(body.messages(2).single.bigInt(2));
                final appId = body.messages(2).single.intValue(1);
                final info =
                    '"appinfo" { "common" { "name" "Fixture Game" } '
                    '"depots" { "101" { "manifests" { "public" { "gid" "$gid" } } } } }\x00';
                socket.add(
                  CmPacket.encode(
                    8904,
                    header,
                    ProtoWriter()
                      ..message(
                        1,
                        ProtoWriter()
                          ..varint(1, appId)
                          ..bytes(5, utf8.encode(info)),
                      )
                      ..varint(6, 0),
                  ),
                );
              case 5438:
                expect(body.intValue(1), 101);
                expect(body.intValue(2), 100);
                socket.add(
                  CmPacket.encode(
                    5439,
                    header,
                    ProtoWriter()
                      ..varint(1, 1)
                      ..varint(2, 101)
                      ..bytes(3, Uint8List(32)),
                  ),
                );
              case 151:
                header.varint(13, 1);
                final target = packet.header.stringValue(12);
                if (target.contains('GetManifestRequestCode')) {
                  expect(body.bigInt(3), gid);
                  socket.add(
                    CmPacket.encode(
                      147,
                      header,
                      ProtoWriter()..varint(1, 12345),
                    ),
                  );
                } else if (target.contains('GetServersForSteamPipe')) {
                  socket.add(
                    CmPacket.encode(
                      147,
                      header,
                      ProtoWriter()..message(
                        1,
                        ProtoWriter()
                          ..string(8, 'cdn.fixture.invalid')
                          ..string(9, 'cdn.fixture.invalid'),
                      ),
                    ),
                  );
                } else if (target.contains('GetCDNAuthToken')) {
                  cdnAuthRequests++;
                  expect(body.intValue(1), 101);
                  socket.add(
                    CmPacket.encode(
                      147,
                      header,
                      ProtoWriter()..string(1, '?token=fixture'),
                    ),
                  );
                } else {
                  fail('Unexpected unified method $target');
                }
            }
          }
        });
      });
      final cm = SteamCmClient(
        client,
        timeout: const Duration(seconds: 3),
        socketConnector: (_) =>
            WebSocket.connect('ws://127.0.0.1:${server.port}/cmsocket/'),
      );
      final service = SteamProtocolService(
        paths: paths,
        settings: settings,
        httpClient: client,
        accountClient: cm,
        protect: (v) => v,
        unprotect: (v) => v,
      );
      try {
        await service.restoreSession();
        expect(service.currentAccountName, 'fixture');
        await service.getAppInfo(100, accessToken: BigInt.from(987));
        expect(appTokenRequests, 0);
        expect(appInfoTokens.single, BigInt.from(987));
        final result = await service.extractApp(
          100,
          p.join(directory.path, 'exports'),
          includeDlc: false,
          pinManifests: true,
        );
        expect(result.keyCount, 1);
        expect(result.manifests.length, 1);
        expect(result.warnings, isEmpty);
        expect(appTokenRequests, 1);
        expect(appInfoTokens.last, BigInt.one);
        final lua = await File(result.luaFile).readAsString();
        expect(lua, contains('addappid(100)'));
        expect(lua, contains('addappid(101, 1, "${'00' * 32}")'));
        expect(lua, contains('setManifestid(101,"$gid",0)'));
        expect(
          DepotManifest.parse(
            await File(result.manifests.single).readAsBytes(),
          ).files.single.fileName.replaceAll('\\', '/'),
          'game/data.bin',
        );
        expect(cdnRequests, 2);
        expect(cdnAuthRequests, 1);
        await service.logOff();
        expect(service.isLoggedOn, false);
        expect(service.hasSavedSession, false);
        await expectLater(
          service.getDepotKey(101, 100),
          throwsA(isA<SteamProtocolException>()),
        );
      } finally {
        service.dispose();
        await cm.close();
        for (final socket in connections) {
          await socket.close();
        }
        await listener.cancel();
        await server.close(force: true);
        client.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
