import 'dart:io';
import 'dart:isolate';

import 'package:fl_steam_lua/platform/windows/named_pipe.dart';
import 'package:flutter_test/flutter_test.dart';

void _echoServer(List<Object> args) {
  final name = args[0] as String;
  final result = args[1] as SendPort;
  WindowsNamedPipe? pipe;
  try {
    pipe = WindowsNamedPipe.accept(name);
    final request = pipe.readJson();
    pipe.writeJson({'ok': true, 'payload': request!['payload']});
    result.send('closed');
  } catch (error) {
    result.send(error.toString());
  } finally {
    pipe?.close();
  }
}

void main() {
  test(
    'named pipe round trips multiline unicode without stdout framing',
    () async {
      final name =
          'flsteamlua_test_${pid}_${DateTime.now().microsecondsSinceEpoch}';
      final result = ReceivePort();
      final isolate = await Isolate.spawn(_echoServer, [name, result.sendPort]);
      WindowsNamedPipe? pipe;
      try {
        pipe = WindowsNamedPipe.connect(name);
        pipe.writeJson({'payload': '成就\nfixture'});
        final response = pipe.readJson(timeout: const Duration(seconds: 3));
        expect(response, {'ok': true, 'payload': '成就\nfixture'});
        expect(
          await result.first.timeout(const Duration(seconds: 3)),
          'closed',
        );
      } finally {
        pipe?.close();
        result.close();
        isolate.kill();
      }
    },
    skip: !Platform.isWindows,
  );
}
