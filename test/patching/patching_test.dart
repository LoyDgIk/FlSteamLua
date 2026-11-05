import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/patching/emulator_service.dart';
import 'package:fl_steam_lua/features/patching/goldberg_config.dart';
import 'package:fl_steam_lua/features/patching/patching_service.dart';
import 'package:fl_steam_lua/features/patching/ticket_authorization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

Uint8List bytes(String value) => Uint8List.fromList(utf8.encode(value));

void main() {
  late Directory temporary;
  late Directory game;
  late AppPaths paths;
  late SettingsStore settings;
  late PatchingService patching;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('flsteam-patch-test-');
    game = await Directory(p.join(temporary.path, 'game')).create();
    paths = AppPaths(p.join(temporary.path, 'app'));
    settings = SettingsStore(paths);
    patching = PatchingService(paths: paths, settings: settings);
  });
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'partial write failure rolls back previous files and additions',
    () async {
      await File(p.join(game.path, 'api.dll')).writeAsString('original');
      var writes = 0;
      final failing = PatchingService(
        paths: paths,
        settings: settings,
        fileWriter: (file, data) async {
          if (++writes == 3) {
            throw const FileSystemException('injected disk failure');
          }
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data);
        },
      );
      await expectLater(
        failing.installFiles(game.path, {
          'api.dll': bytes('patched'),
          'new.ini': bytes('new'),
          'last.dll': bytes('last'),
        }),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File(p.join(game.path, 'api.dll')).readAsString(),
        'original',
      );
      expect(await File(p.join(game.path, 'new.ini')).exists(), isFalse);
      expect(await File(p.join(game.path, 'last.dll')).exists(), isFalse);
    },
  );

  test(
    'archive reader rejects unsafe paths and case duplicates before writes',
    () async {
      for (final name in [
        '../escape.dll',
        '/root.dll',
        r'C:\escape.dll',
        r'..\escape.dll',
      ]) {
        final archive = Archive()..addFile(ArchiveFile(name, 1, [1]));
        final file = File(p.join(temporary.path, 'bad.zip'));
        await file.writeAsBytes(ZipEncoder().encode(archive));
        await expectLater(
          readArchiveFiles(file.path),
          throwsA(isA<FormatException>()),
        );
      }
      final duplicate = Archive()
        ..addFile(ArchiveFile('a.dll', 1, [1]))
        ..addFile(ArchiveFile('A.dll', 1, [2]));
      final file = File(p.join(temporary.path, 'duplicate.zip'));
      await file.writeAsBytes(ZipEncoder().encode(duplicate));
      await expectLater(
        readArchiveFiles(file.path),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('Windows system libarchive decodes 7z packages', () async {
    final original = File(p.join(game.path, 'fixture.dll'));
    await original.writeAsString('fixture bytes');
    final archive = p.join(temporary.path, 'fixture.7z');
    final process = await Process.run('tar', [
      '--format=7zip',
      '-cf',
      archive,
      '-C',
      game.path,
      'fixture.dll',
    ]);
    expect(process.exitCode, 0, reason: '${process.stderr}');
    final files = await readArchiveFiles(archive);
    expect(utf8.decode(files['fixture.dll']!), 'fixture bytes');
  }, skip: !Platform.isWindows);

  test(
    'Goldberg settings preserve comments unknown INI and extra JSON fields',
    () async {
      final folder = await Directory(
        p.join(game.path, 'steam_settings'),
      ).create();
      await File(p.join(folder.path, 'configs.user.ini')).writeAsString(
        '# user comment\n[user::general]\nfuture_key=keep\naccount_name=Old\n',
      );
      await File(
        p.join(folder.path, 'achievements.json'),
      ).writeAsString('[{"name":"A","future":42}]');
      final service = GoldbergConfigService(patching);
      final loaded = await service.load(game.path);
      loaded.config.accountName = 'New';
      loaded.config.appId = '123';
      loaded.config.dlcIds = [22, 23, 22];
      await service.save(game.path, loaded.config);
      final text = await File(
        p.join(folder.path, 'configs.user.ini'),
      ).readAsString();
      expect(text, contains('# user comment'));
      expect(text, contains('future_key=keep'));
      expect(text, contains('account_name=New'));
      final reloaded = await service.load(game.path);
      expect(reloaded.config.achievements.single['future'], 42);
      expect(reloaded.config.dlcIds, [22, 23]);
      final zip = p.join(temporary.path, 'config.zip');
      await service.exportZip(game.path, zip);
      expect((await readArchiveFiles(zip)).keys, contains('configs.user.ini'));
    },
  );

  test(
    'Goldberg rejects INI injection and invalid port without writing',
    () async {
      final service = GoldbergConfigService(patching);
      final config = GoldbergConfig(accountName: 'bad\nkey=value');
      await expectLater(
        service.save(game.path, config),
        throwsA(isA<FormatException>()),
      );
      config.accountName = 'okay';
      config.listenPort = 99999;
      await expectLater(
        service.save(game.path, config),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'ticket parser validates lengths, embedded AppID and does not echo secrets',
    () {
      final app = Uint8List(24);
      ByteData.sublistView(app)
        ..setUint32(8, 1234, Endian.little)
        ..setUint32(16, 480, Endian.little);
      final ticket = AuthorizationTicket(
        appId: 480,
        steamId: BigInt.from(1234),
        appTicket: app,
        eTicket: Uint8List.fromList([2, 3]),
      );
      final parsed = AuthorizationTicket.parse(ticket.exportText());
      expect(parsed.appId, 480);
      expect(parsed.steamId, BigInt.from(1234));
      expect(ticket.exportText(), startsWith('appid: 480\n'));
      expect(
        AuthorizationTicket.parse(
          '\uFEFF${ticket.exportText()}# Game name: fixture\n'
          '// other metadata\n',
        ).appId,
        480,
      );
      expect(
        AuthorizationTicket.parse(
          'Extracted by FlSteamLua. Use the ticket before it expires.\n'
          '${ticket.exportText()}',
        ).appId,
        480,
      );
      expect(
        () => AuthorizationTicket.parse(
          ticket.exportText().replaceFirst('24 bytes', '23 bytes'),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AuthorizationTicket.parse(
          ticket.exportText().replaceFirst('appid: 480', 'appid: 999'),
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('ticket registry write failure restores both prior values', () async {
    final registry = _FakeRegistry();
    final store = TicketAuthorizationStore(
      paths: paths,
      registry: registry,
      protect: (text) => text,
      unprotect: (text) => text,
    );
    final before = registry.values.map(
      (key, value) => MapEntry(key, Uint8List.fromList(value!)),
    );
    registry.failNextEncryptedWrite = true;
    await expectLater(
      store.apply(
        AuthorizationTicket(
          appId: 480,
          steamId: BigInt.one,
          appTicket: Uint8List.fromList([9]),
          eTicket: Uint8List.fromList([8]),
        ),
      ),
      throwsStateError,
    );
    expect(registry.values, before);
    expect(registry.steamId, '123');
  });

  test('ticket replacement preserves the cached identity by default', () async {
    final registry = _FakeRegistry();
    final store = TicketAuthorizationStore(paths: paths, registry: registry);
    await store.apply(
      AuthorizationTicket(
        appId: 480,
        steamId: BigInt.from(456),
        appTicket: Uint8List.fromList([9]),
        eTicket: Uint8List.fromList([8]),
      ),
    );
    expect(registry.steamId, '123');
  });

  test('saved ticket backup roundtrips through injected codec', () async {
    final app = Uint8List(24);
    ByteData.sublistView(app)
      ..setUint32(8, 1234, Endian.little)
      ..setUint32(16, 480, Endian.little);
    final store = TicketAuthorizationStore(
      paths: paths,
      registry: _FakeRegistry(),
      protect: (text) => base64Encode(utf8.encode(text)),
      unprotect: (text) => utf8.decode(base64Decode(text)),
    );
    await store.save(
      AuthorizationTicket(
        appId: 480,
        steamId: BigInt.from(1234),
        appTicket: app,
        eTicket: Uint8List.fromList([1]),
      ),
    );
    expect(await store.list(), [480]);
    expect((await store.load(480)).appId, 480);
    await store.delete(480);
    expect(await store.list(), isEmpty);
  });

  test('release selection excludes draft/debug and preserves digest', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {'tag_name': 'test', 'draft': true, 'assets': []},
          {
            'tag_name': 'v1',
            'draft': false,
            'assets': [
              {
                'name': 'emu-win-debug.7z',
                'size': 12,
                'browser_download_url': 'https://example.test/debug',
              },
              {
                'name': 'emu-win-release.7z',
                'size': 12,
                'browser_download_url': 'https://example.test/emu',
                'digest': 'sha256:abcd',
              },
            ],
          },
        ]),
        200,
      ),
    );
    final emulator = EmulatorService(
      paths: paths,
      patching: patching,
      client: client,
    );
    final release = await emulator.latestRelease();
    expect(release.version, 'v1');
    expect(release.sha256Digest, 'abcd');
    expect(release.url.path, '/emu');
    client.close();
  });

  test('PE inspection rejects truncated or malformed input', () {
    expect(
      () => PeInspection.parse(Uint8List(64)),
      throwsA(isA<FormatException>()),
    );
    final fake = Uint8List(64)
      ..[0] = 0x4d
      ..[1] = 0x5a;
    ByteData.sublistView(fake).setUint32(0x3c, 1000, Endian.little);
    expect(() => PeInspection.parse(fake), throwsA(isA<FormatException>()));
  });
}

class _FakeRegistry implements TicketRegistry {
  String? steamId = '123';
  @override
  String? readSteamId(int appId) => steamId;
  @override
  void writeSteamId(int appId, String? value) {
    steamId = value;
  }

  final values = <String, Uint8List?>{
    'AppTicket': Uint8List.fromList([1]),
    'ETicket': Uint8List.fromList([2]),
  };
  bool failNextEncryptedWrite = false;
  @override
  Map<String, Uint8List?> read(int appId) => Map.of(values);
  @override
  void write(int appId, String name, Uint8List? bytes) {
    if (name == 'ETicket' && failNextEncryptedWrite) {
      failNextEncryptedWrite = false;
      throw StateError('injected write failure');
    }
    values[name] = bytes;
  }
}
