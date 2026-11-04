import 'dart:io';

import 'package:fl_steam_lua/features/steam_protocol/app_info.dart';
import 'package:fl_steam_lua/features/steam_protocol/cm_client.dart';
import 'package:fl_steam_lua/features/steam_protocol/wire/protobuf.dart';
import 'package:http/http.dart' as http;

Future<void> main(List<String> arguments) async {
  if (!arguments.contains('--live')) {
    stderr.writeln(
      'Usage: dart run bin/steam_protocol_probe.dart --live [appid]',
    );
    exitCode = 64;
    return;
  }
  final appId = arguments.where((a) => a != '--live').firstOrNull ?? '440';
  final id = int.parse(appId);
  final httpClient = http.Client();
  final cm = SteamCmClient(httpClient);
  try {
    await cm.logOn();
    stdout.writeln('Anonymous CM logon succeeded; steamId=${cm.steamId}');
    final tokens = await cm.request(
      8905,
      ProtoWriter()..varint(2, id),
      expectedType: 8906,
    );
    var token = BigInt.zero;
    for (final item in ProtoReader(tokens.single.body).messages(3)) {
      if (item.intValue(1) == id) token = item.bigInt(2);
    }
    final result = await cm.request(
      8903,
      ProtoWriter()
        ..message(
          2,
          ProtoWriter()
            ..varint(1, id)
            ..varint(2, token),
        )
        ..varint(7, 1),
      expectedType: 8904,
      done: (packet) => ProtoReader(packet.body).intValue(6) == 0,
    );
    for (final packet in result) {
      for (final item in ProtoReader(packet.body).messages(1)) {
        if (item.intValue(1) != id) continue;
        final data = item.bytesValue(5);
        if (data == null || data.isEmpty) {
          throw StateError('No appinfo buffer was returned');
        }
        final app = SteamAppInfo.fromData(id, decodeSteamKeyValues(data));
        stdout.writeln(
          'PICS app ${app.appId}: ${app.name}; depots=${app.depots.length}; DLC=${app.dlcAppIds.length}',
        );
      }
    }
  } catch (error) {
    stderr.writeln('Steam protocol probe failed: $error');
    exitCode = 1;
  } finally {
    await cm.close();
    httpClient.close();
  }
}
