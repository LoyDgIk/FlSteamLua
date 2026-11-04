import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/features/steam_protocol/app_info.dart';
import 'package:fl_steam_lua/features/steam_protocol/cm_client.dart';
import 'package:fl_steam_lua/features/steam_protocol/wire/cm_packet.dart';
import 'package:fl_steam_lua/features/steam_protocol/wire/protobuf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'protobuf preserves uint64, nested fields and malformed-input errors',
    () {
      final max = BigInt.parse('18446744073709551615');
      final writer = ProtoWriter()
        ..varint(1, max)
        ..fixed64(2, max)
        ..message(3, ProtoWriter()..string(1, '测试'))
        ..fixed32(4, 0xffffffff);
      final reader = ProtoReader(writer.toBytes());
      expect(reader.bigInt(1), max);
      expect(reader.bigInt(2), max);
      expect(reader.messages(3).single.stringValue(1), '测试');
      expect(reader.intValue(4), 0xffffffff);
      expect(() => ProtoReader([0x0a, 3, 1]), throwsFormatException);
      expect(() => ProtoReader([0]), throwsFormatException);
      expect(
        () => ProtoReader([8, ...List.filled(10, 255)]),
        throwsFormatException,
      );
    },
  );

  test('Steam Multi decompresses packets and rejects truncated framing', () {
    final single = CmPacket.encode(
      751,
      ProtoWriter()..varint(2, 42),
      ProtoWriter()..varint(1, 1),
    );
    final length = ByteData(4)..setUint32(0, single.length, Endian.little);
    final combined = [...length.buffer.asUint8List(), ...single];
    final multi = CmPacket.encode(
      1,
      ProtoWriter(),
      ProtoWriter()
        ..varint(1, combined.length)
        ..bytes(2, gzip.encode(combined)),
    );
    final packet = CmPacket.decode(multi).single;
    expect(packet.messageType, 751);
    expect(packet.header.intValue(2), 42);
    expect(ProtoReader(packet.body).intValue(1), 1);
    expect(() => CmPacket.decode([1, 2]).toList(), throwsFormatException);
    final bad = CmPacket.encode(
      1,
      ProtoWriter(),
      ProtoWriter()..bytes(2, [1, 2]),
    );
    expect(() => CmPacket.decode(bad).toList(), throwsFormatException);
  });

  test('app information merges DLC depot IDs and skips shared depots', () {
    const text =
        '"appinfo" { "common" { "name" "测试游戏" } '
        '"extended" { "listofdlc" "20,21" } "depots" {'
        '"100" { "name" "base" "manifests" { "public" { "gid" "18446744073709551615" } } } '
        '"101" { "dlcappid" "22" } "102" { "depotfromapp" "999" } } }\x00';
    final app = SteamAppInfo.fromData(
      10,
      decodeSteamKeyValues(utf8.encode(text)),
    );
    expect(app.name, '测试游戏');
    expect(app.depots.map((d) => d.depotId), [100, 101]);
    expect(app.depots.first.manifestGid, BigInt.parse('18446744073709551615'));
    expect(app.dlcAppIds, [20, 21, 22]);
    expect(
      () => decodeSteamKeyValues(utf8.encode('"key" {')),
      throwsFormatException,
    );
  });

  test(
    'CM websocket logs on and correlates split PICS responses by uint64 job ID',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final serverSub = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((event) {
          for (final packet in CmPacket.decode(event as List<int>)) {
            if (packet.messageType == 5514) {
              final request = ProtoReader(packet.body);
              expect(request.intValue(1), 65581);
              socket.add(
                CmPacket.encode(
                  751,
                  ProtoWriter()
                    ..fixed64(1, BigInt.parse('117093590311632900'))
                    ..varint(2, 123),
                  ProtoWriter()
                    ..varint(1, 1)
                    ..varint(3, 60),
                ),
              );
            } else if (packet.messageType == 8903) {
              final sourceJob = packet.header.bigInt(10);
              expect(sourceJob, greaterThan(BigInt.zero));
              for (final pending in [true, false]) {
                socket.add(
                  CmPacket.encode(
                    8904,
                    ProtoWriter()..fixed64(11, sourceJob),
                    ProtoWriter()..varint(6, pending ? 1 : 0),
                  ),
                );
              }
            }
          }
        });
      });
      final httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'response': {
              'serverlist': [
                {'endpoint': 'fixture.invalid:443'},
              ],
            },
          }),
          200,
        ),
      );
      final cm = SteamCmClient(
        httpClient,
        timeout: const Duration(seconds: 3),
        socketConnector: (_) =>
            WebSocket.connect('ws://127.0.0.1:${server.port}/cmsocket/'),
      );
      try {
        await Future.wait([cm.logOn(), cm.logOn()]);
        expect(cm.isLoggedOn, true);
        expect(cm.sessionId, 123);
        final replies = await cm.request(
          8903,
          ProtoWriter(),
          expectedType: 8904,
          done: (packet) => ProtoReader(packet.body).intValue(6) == 0,
        );
        expect(replies.length, 2);
      } finally {
        await cm.close();
        httpClient.close();
        for (final socket in sockets) {
          await socket.close();
        }
        await serverSub.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'CM rejects refused logon and fails active jobs on socket close',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      WebSocket? connection;
      final serverSub = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        connection = socket;
        socket.listen((event) {
          for (final packet in CmPacket.decode(event as List<int>)) {
            if (packet.messageType == 5514) {
              socket.add(
                CmPacket.encode(
                  751,
                  ProtoWriter(),
                  ProtoWriter()..varint(1, 5),
                ),
              );
            } else if (packet.messageType == 5438) {
              unawaited(socket.close());
            }
          }
        });
      });
      final httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'response': {
              'serverlist': [
                {'endpoint': 'fixture.invalid:443'},
              ],
            },
          }),
          200,
        ),
      );
      final cm = SteamCmClient(
        httpClient,
        timeout: const Duration(seconds: 3),
        socketConnector: (_) =>
            WebSocket.connect('ws://127.0.0.1:${server.port}/cmsocket/'),
      );
      try {
        await expectLater(cm.logOn(), throwsA(isA<SteamProtocolException>()));
        expect(cm.isLoggedOn, false);
        await expectLater(
          cm.request(5438, ProtoWriter(), expectedType: 5439),
          throwsA(isA<SteamProtocolException>()),
        );
      } finally {
        await cm.close();
        httpClient.close();
        await connection?.close();
        await serverSub.cancel();
        await server.close(force: true);
      }
    },
  );
}
