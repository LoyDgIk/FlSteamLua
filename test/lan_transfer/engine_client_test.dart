import 'dart:io';

import 'package:fl_steam_lua/features/lan_transfer/lan_transfer_engine_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('native engine process completes JSON-RPC handshake', () async {
    final executable = p.join(
      Directory.current.path,
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
      'lan_transfer_engine.exe',
    );
    if (!await File(executable).exists()) {
      markTestSkipped('native engine has not been built');
      return;
    }
    final directory = await Directory.systemTemp.createTemp('fl-engine-rpc-');
    final client = LanTransferEngineClient(executablePathOverride: executable);
    try {
      final events = <LanTransferEngineEvent>[];
      final subscription = client.events.listen(events.add);
      await client.start(directory.path);
      final hello = await client.request('hello', const {});
      expect(hello, isA<Map>());
      expect((hello as Map)['lanProtocol'], 'flsteamlua-lan/4');
      expect((hello)['engineProtocol'], 'flsteamlua-engine/1');
      await subscription.cancel();
    } finally {
      await client.close();
      await directory.delete(recursive: true);
    }
  });
}
