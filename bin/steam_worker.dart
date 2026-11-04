import 'dart:io';

import 'package:fl_steam_lua/features/achievements/native_steam.dart';
import 'package:fl_steam_lua/platform/windows/named_pipe.dart';

Future<void> main(List<String> args) async {
  WindowsNamedPipe? pipe;
  NativeSteam? steam;
  try {
    final options = <String, String>{};
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length || !args[i].startsWith('--')) {
        throw const FormatException('Invalid worker arguments');
      }
      options[args[i]] = args[i + 1];
    }
    final appId = int.tryParse(options['--app-id'] ?? '');
    final steamPath = options['--steam-path'];
    final pipeName = options['--pipe'];
    if (appId == null ||
        appId <= 0 ||
        appId > 0xffffffff ||
        steamPath == null ||
        pipeName == null) {
      throw const FormatException(
        'Worker requires app ID, Steam path and pipe name',
      );
    }
    pipe = WindowsNamedPipe.accept(pipeName);
    steam = NativeSteam(
      steamPath: steamPath,
      appId: appId,
      library: options['--bridge'],
    );
    pipe.writeJson({'ok': true, 'ready': true, 'appId': appId});
    while (true) {
      final request = pipe.readJson();
      if (request == null) break;
      try {
        switch (request['command']) {
          case 'load':
            final snapshot = await steam.load();
            pipe.writeJson({'ok': true, 'snapshot': snapshot.toJson()});
          case 'save':
            final achievements = Map<String, bool>.from(
              request['achievements'] as Map,
            );
            final stats = Map<String, num>.from(request['stats'] as Map);
            await steam.save(achievements, stats);
            pipe.writeJson({'ok': true});
          case 'tickets':
            final tickets = await steam.tickets();
            pipe.writeJson({'ok': true, 'tickets': tickets.toJson()});
          case 'exit':
            pipe.writeJson({'ok': true});
            return;
          default:
            throw const FormatException('Unknown Steam worker command');
        }
      } catch (error) {
        pipe.writeJson({'ok': false, 'error': error.toString()});
      }
    }
  } catch (error) {
    try {
      pipe?.writeJson({'ok': false, 'error': error.toString()});
    } catch (_) {
      /* The parent observes process exit if the pipe is unavailable. */
    }
    exitCode = 1;
  } finally {
    steam?.close();
    pipe?.close();
  }
}
