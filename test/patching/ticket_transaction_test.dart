import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/features/patching/ticket_authorization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FixtureTicketRegistry implements TicketRegistry {
  final values = <String, Uint8List?>{};
  String? steamId;
  String? failAfter;
  bool wrongReadback = false;
  final writes = <String>[];
  @override
  Map<String, Uint8List?> read(int appId) => {
    'AppTicket': values['AppTicket'],
    'ETicket': wrongReadback ? Uint8List(0) : values['ETicket'],
  };
  @override
  String? readSteamId(int appId) => steamId;
  @override
  void write(int appId, String name, Uint8List? value) {
    writes.add(name);
    if (value == null) {
      values.remove(name);
    } else {
      values[name] = Uint8List.fromList(value);
    }
    _failure(name);
  }

  @override
  void writeSteamId(int appId, String? value) {
    writes.add('SteamID');
    steamId = value;
    _failure('SteamID');
  }

  void _failure(String name) {
    if (failAfter == name) {
      failAfter = null;
      throw StateError('fixture write failed');
    }
  }
}

void main() {
  late Directory root;
  late AppPaths paths;
  late FixtureTicketRegistry registry;
  late TicketAuthorizationStore store;
  late AuthorizationTicket ticket;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ticket-transaction-');
    paths = AppPaths(root.path);
    registry = FixtureTicketRegistry();
    store = TicketAuthorizationStore(
      paths: paths,
      registry: registry,
      protect: (value) => 'encrypted:${base64Encode(utf8.encode(value))}',
      unprotect: (value) => utf8.decode(base64Decode(value.substring(10))),
    );
    final app = Uint8List(24);
    ByteData.sublistView(app)
      ..setUint32(8, 222, Endian.little)
      ..setUint32(16, 480, Endian.little);
    ticket = AuthorizationTicket(
      appId: 480,
      steamId: BigInt.from(222),
      appTicket: app,
      eTicket: Uint8List.fromList([9, 8]),
    );
  });
  tearDown(() async => root.delete(recursive: true));

  for (final previous in <String?>[null, '222', '111']) {
    test(
      'default apply preserves cached identity $previous without writing it',
      () async {
        registry.steamId = previous;
        final result = await store.apply(ticket);
        expect(registry.steamId, previous);
        expect(registry.writes, ['AppTicket', 'ETicket']);
        expect(registry.values['AppTicket'], ticket.appTicket);
        expect(result.identityMismatch, previous == '111');
        expect(await File(result.backup.path).exists(), isTrue);
        final backup =
            jsonDecode(await File(result.backup.path).readAsString()) as Map;
        expect(backup.keys, isNot(contains('SteamID')));
        expect(backup['payload'], startsWith('encrypted:'));
      },
    );
  }

  test(
    'explicit identity change and restart-safe restore recover all values including absence',
    () async {
      registry.values['AppTicket'] = Uint8List.fromList([1, 2, 3]);
      registry.steamId = null;
      final result = await store.apply(ticket, synchronizeIdentity: true);
      expect(registry.steamId, '222');
      expect(result.identityMismatch, isFalse);
      final reloaded = TicketAuthorizationStore(
        paths: paths,
        registry: registry,
        protect: (v) => 'encrypted:${base64Encode(utf8.encode(v))}',
        unprotect: (v) => utf8.decode(base64Decode(v.substring(10))),
      );
      final backups = await reloaded.credentialBackups(appId: 480);
      await reloaded.restoreCredentials(
        await reloaded.prepareRestore(backups.single),
      );
      expect(registry.values['AppTicket'], [1, 2, 3]);
      expect(registry.values.containsKey('ETicket'), isFalse);
      expect(registry.steamId, isNull);
      expect(await reloaded.credentialBackups(appId: 480), hasLength(2));
    },
  );

  for (final failedValue in ['AppTicket', 'ETicket', 'SteamID']) {
    test(
      'failure after mutating $failedValue rolls back the entire modified set',
      () async {
        registry.values['ETicket'] = Uint8List.fromList([4]);
        registry.steamId = '111';
        final before = store.credentials(480);
        registry.failAfter = failedValue;
        await expectLater(
          store.apply(ticket, synchronizeIdentity: true),
          throwsStateError,
        );
        expect(store.credentials(480).matches(before), isTrue);
        expect(await store.credentialBackups(appId: 480), hasLength(1));
      },
    );
  }

  test(
    'Lua cleanup ignores comments and quoted text and restores original bytes with credentials',
    () async {
      final file = File(p.join(root.path, '480.lua'));
      const source =
          '-- setAppTicket(480,"ignored")\r\n'
          '--[=[\r\nsetETicket(480,"ignored")\r\n]=]\r\n'
          'local note = \'setETicket(480,"text")\'\r\n'
          'addappid(480)\r\n'
          'SETAPPTICKET(480, "abcd"); -- old app\r\n'
          'setETicket(\r\n 480, "dcba"\r\n)\r\n'
          'setAppTicket(481,"keep other game")\r\n';
      final bytes = Uint8List.fromList([
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode(source),
      ]);
      await file.writeAsBytes(bytes);
      registry.steamId = '111';
      registry.values['AppTicket'] = Uint8List.fromList([7]);
      final plan = await store.prepare(ticket, luaPaths: [file.path]);
      expect(plan.lua.single.statements.map((s) => s.function), [
        'setAppTicket',
        'setETicket',
      ]);
      final applied = await store.apply(
        ticket,
        synchronizeIdentity: true,
        plan: plan,
      );
      final cleaned = await file.readAsString();
      expect(cleaned, contains('setAppTicket(481,"keep other game")'));
      expect(cleaned, contains('local note'));
      expect(cleaned, isNot(contains('SETAPPTICKET(480, "abcd")')));
      expect((await file.readAsBytes()).take(3), [0xef, 0xbb, 0xbf]);
      await store.restoreCredentials(
        await store.prepareRestore(applied.backup),
      );
      expect(await file.readAsBytes(), bytes);
      expect(registry.values['AppTicket'], [7]);
      expect(registry.values.containsKey('ETicket'), isFalse);
      expect(registry.steamId, '111');
    },
  );

  test(
    'Lua write failure after replacement restores file before any registry writes',
    () async {
      final file = File(p.join(root.path, '480.lua'));
      await file.writeAsString('addappid(480)\nsetETicket(480,"ab")\n');
      final original = await file.readAsBytes();
      final failing = TicketAuthorizationStore(
        paths: paths,
        registry: registry,
        protect: base64EncodeString,
        unprotect: base64DecodeString,
        fileWriter: (target, bytes) async {
          await target.writeAsBytes(bytes);
          throw StateError('disk fixture');
        },
      );
      final plan = await failing.prepare(ticket, luaPaths: [file.path]);
      await expectLater(failing.apply(ticket, plan: plan), throwsStateError);
      expect(await file.readAsBytes(), original);
      expect(registry.writes, isEmpty);
    },
  );

  test(
    'changed preview or edited Lua blocks mutation and backup encryption failure does too',
    () async {
      final plan = await store.prepare(ticket);
      registry.steamId = 'new cached account';
      await expectLater(
        store.apply(ticket, plan: plan),
        throwsA(isA<TicketOperationException>()),
      );
      expect(registry.writes, isEmpty);
      final failing = TicketAuthorizationStore(
        paths: paths,
        registry: registry,
        protect: (_) => throw StateError('encryption fixture'),
      );
      await expectLater(failing.apply(ticket), throwsStateError);
      expect(registry.writes, isEmpty);
      final file = File(p.join(root.path, '480.lua'));
      await file.writeAsString('setAppTicket(480,"abcd")');
      final luaPlan = await store.prepare(ticket, luaPaths: [file.path]);
      await file.writeAsString('user edited');
      await expectLater(
        store.apply(ticket, plan: luaPlan),
        throwsA(isA<TicketOperationException>()),
      );
      expect(await file.readAsString(), 'user edited');
      expect(registry.writes, isEmpty);
    },
  );
  test(
    'restore failure recovers the currently applied ticket pair and identity',
    () async {
      registry.steamId = '111';
      registry.values['ETicket'] = Uint8List.fromList([1]);
      final applied = await store.apply(ticket, synchronizeIdentity: true);
      final current = store.credentials(480);
      final restore = await store.prepareRestore(applied.backup);
      registry.failAfter = 'SteamID';
      await expectLater(store.restoreCredentials(restore), throwsStateError);
      expect(store.credentials(480).matches(current), isTrue);
    },
  );

  test(
    'native DPAPI backup survives reload and contains no plain credential payload',
    () async {
      registry.steamId = '111';
      registry.values['AppTicket'] = Uint8List.fromList(
        utf8.encode('original-ticket-secret'),
      );
      final native = TicketAuthorizationStore(paths: paths, registry: registry);
      final result = await native.apply(ticket, synchronizeIdentity: true);
      final saved = await File(result.backup.path).readAsString();
      expect(saved, isNot(contains('original-ticket-secret')));
      expect(saved, isNot(contains('SteamID')));
      final reloaded = TicketAuthorizationStore(
        paths: paths,
        registry: registry,
      );
      await reloaded.restoreCredentials(
        await reloaded.prepareRestore(result.backup),
      );
      expect(
        utf8.decode(registry.values['AppTicket']!),
        'original-ticket-secret',
      );
      expect(registry.steamId, '111');
      expect(registry.values.containsKey('ETicket'), isFalse);
    },
    skip: !Platform.isWindows,
  );
}

String base64EncodeString(String value) => base64Encode(utf8.encode(value));
String base64DecodeString(String value) => utf8.decode(base64Decode(value));
