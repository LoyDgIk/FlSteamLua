import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/features/content_sources/content_resolver.dart';
import 'package:fl_steam_lua/features/content_sources/content_source_registry.dart';
import 'package:fl_steam_lua/features/steam_protocol/manifest/depot_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Registry implements ContentSourceRegistry {
  final definitions = <String, ContentSourceDefinition>{};
  final payloads = <String, ContentSourcePayload>{};
  final calls = <String, int>{};

  @override
  ContentSourceDefinition source(String id) => definitions[id]!;

  @override
  Future<ContentSourcePayload> fetch(
    String sourceId,
    int appId, {
    required Set<ContentCapability> requestedCapabilities,
    Set<int> dlcIds = const {},
    bool pinManifests = false,
    bool refreshMetadata = true,
    TaskContext? task,
  }) async {
    calls.update(sourceId, (count) => count + 1, ifAbsent: () => 1);
    return payloads[sourceId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Registry registry;
  late ContentResolver resolver;

  ContentArtifact lua(String text, {String source = 'script:lua'}) =>
      ContentArtifact(
        filename: '440.lua',
        bytes: utf8.encode(text),
        capability: ContentCapability.lua,
        sourceId: source,
      );

  ContentArtifact manifest({
    int depot = 441,
    String gid = '9007199254740993',
  }) => ContentArtifact(
    filename: '${depot}_$gid.manifest',
    bytes: DepotManifest(
      depotId: depot,
      manifestGid: BigInt.parse(gid),
      files: [],
    ).toBytes(),
    capability: ContentCapability.manifestFiles,
    sourceId: 'script:manifests',
  );

  Future<ContentBundle> parse(
    ContentSourcePayload payload, {
    Set<ContentCapability> requested = const {ContentCapability.lua},
    bool pinManifests = false,
  }) => Future.sync(
    () => resolver.resolvePayload(
      440,
      payload,
      requestedCapabilities: requested,
      pinManifests: pinManifests,
    ),
  );

  void source(
    String id,
    Set<ContentCapability> capabilities,
    ContentSourcePayload payload,
  ) {
    registry.definitions[id] = ContentSourceDefinition(
      id: id,
      name: id,
      kind: ContentSourceKind.script,
      capabilities: capabilities,
    );
    registry.payloads[id] = payload;
  }

  setUp(() {
    registry = _Registry();
    resolver = ContentResolver(registry);
  });

  test('Lua-only payload is valid without requesting manifests', () async {
    final bundle = await parse(
      ContentSourcePayload(
        artifacts: [lua('addappid(440)\naddtoken(440,"42")')],
      ),
    );
    expect(bundle.appId, 440);
    expect(utf8.decode(bundle.lua!.bytes), contains('addappid(440)'));
    expect(bundle.manifestFiles, isEmpty);
  });

  test('Lua-only plan ignores unrequested structured manifest pins', () async {
    final bundle = await parse(
      ContentSourcePayload(
        artifacts: [lua('addappid(440)')],
        pins: const [
          ManifestPin(depotId: 441, manifestId: '123', sourceId: 'script:both'),
        ],
      ),
    );
    expect(bundle.manifestPins, isEmpty);
    expect(utf8.decode(bundle.lua!.bytes), isNot(contains('setManifestid')));
  });

  test('ID-only request does not import extra manifest files', () async {
    final bundle = await parse(
      ContentSourcePayload(
        artifacts: [
          lua('addappid(440)'),
          manifest(gid: '123'),
        ],
        pins: const [
          ManifestPin(depotId: 441, manifestId: '123', sourceId: 'script:ids'),
        ],
      ),
      requested: {ContentCapability.lua, ContentCapability.manifestIds},
    );
    expect(bundle.manifestFiles, isEmpty);
    expect(
      utf8.decode(bundle.lua!.bytes),
      contains('--setManifestid(441,"123",0)'),
    );
  });

  test(
    'a Lua request with no Lua fails rather than importing manifests',
    () async {
      await expectLater(
        parse(ContentSourcePayload(artifacts: [manifest()])),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('explicit manifest request requires a manifest result', () async {
    await expectLater(
      parse(
        ContentSourcePayload(artifacts: [lua('addappid(440)')]),
        requested: {ContentCapability.lua, ContentCapability.manifestFiles},
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('manifest-files capability cannot be satisfied by IDs alone', () async {
    await expectLater(
      parse(
        ContentSourcePayload(
          artifacts: [lua('addappid(440)')],
          pins: const [
            ManifestPin(
              depotId: 441,
              manifestId: '123',
              sourceId: 'script:ids',
            ),
          ],
        ),
        requested: {ContentCapability.lua, ContentCapability.manifestFiles},
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('manifest magic without the complete container is rejected', () async {
    await expectLater(
      parse(
        ContentSourcePayload(
          artifacts: [
            lua('addappid(440)'),
            ContentArtifact(
              filename: '441_123.manifest',
              bytes: [0xd0, 0x17, 0xf6, 0x71, ...List.filled(32, 0)],
              capability: ContentCapability.manifestFiles,
            ),
          ],
        ),
        requested: {ContentCapability.lua, ContentCapability.manifestFiles},
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('manifest metadata is checked and its uint64 pin reaches Lua', () async {
    final bundle = await parse(
      ContentSourcePayload(artifacts: [lua('addappid(440)'), manifest()]),
      requested: {ContentCapability.lua, ContentCapability.manifestFiles},
    );
    expect(
      bundle.manifestFiles.single.filename,
      '441_9007199254740993.manifest',
    );
    expect(bundle.manifestPins.single.manifestId, '9007199254740993');
    expect(
      utf8.decode(bundle.lua!.bytes),
      matches(RegExp(r'--setManifestid\(\s*441\s*,\s*["\x27]9007199254740993')),
    );
  });

  test('checked pin option activates manifest IDs', () async {
    final bundle = await parse(
      ContentSourcePayload(
        artifacts: [lua('addappid(440)'), manifest()],
        pins: const [
          ManifestPin(
            depotId: 441,
            manifestId: '9007199254740993',
            sourceId: 'script:manifests',
          ),
        ],
      ),
      requested: {ContentCapability.lua, ContentCapability.manifestFiles},
      pinManifests: true,
    );
    expect(
      utf8.decode(bundle.lua!.bytes),
      contains('setManifestid(441,"9007199254740993",0)'),
    );
    expect(
      utf8.decode(bundle.lua!.bytes),
      isNot(contains('--setManifestid(441,"9007199254740993",0)')),
    );
  });

  test(
    'manifest filename cannot disagree with its internal depot and GID',
    () async {
      final actual = manifest();
      await expectLater(
        parse(
          ContentSourcePayload(
            artifacts: [
              lua('addappid(440)'),
              ContentArtifact(
                filename: '442_9007199254740993.manifest',
                bytes: actual.bytes,
                capability: ContentCapability.manifestFiles,
              ),
            ],
          ),
          requested: {ContentCapability.lua, ContentCapability.manifestFiles},
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('same pins deduplicate and conflicting pins fail', () async {
    final bundle = await parse(
      ContentSourcePayload(
        artifacts: [lua('addappid(440)\nsetManifestid(441,"123",0)')],
        pins: const [
          ManifestPin(
            depotId: 441,
            manifestId: '123',
            sourceId: 'script:other',
          ),
        ],
      ),
      requested: {ContentCapability.lua, ContentCapability.manifestIds},
      pinManifests: true,
    );
    expect(bundle.manifestPins, hasLength(1));
    expect(
      RegExp('setManifestid').allMatches(utf8.decode(bundle.lua!.bytes)),
      hasLength(1),
    );
    await expectLater(
      parse(
        ContentSourcePayload(
          artifacts: [lua('addappid(440)\nsetManifestid(441,"123",0)')],
          pins: const [
            ManifestPin(
              depotId: 441,
              manifestId: '124',
              sourceId: 'script:other',
            ),
          ],
        ),
        requested: {ContentCapability.lua, ContentCapability.manifestIds},
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('manifest pin mode rewrites existing Lua pins', () async {
    final unchecked = await parse(
      ContentSourcePayload(
        artifacts: [lua('addappid(440)\nsetManifestid(441,"123",0)')],
      ),
    );
    expect(
      utf8.decode(unchecked.lua!.bytes),
      contains('--setManifestid(441,"123",0)'),
    );

    final checked = await parse(
      ContentSourcePayload(
        artifacts: [lua('addappid(440)\n--setManifestid(441,"123",0)')],
      ),
      pinManifests: true,
    );
    expect(
      utf8.decode(checked.lua!.bytes),
      contains('setManifestid(441,"123",0)'),
    );
    expect(
      utf8.decode(checked.lua!.bytes),
      isNot(contains('--setManifestid(441,"123",0)')),
    );
  });

  test('archive traversal is rejected before a bundle is returned', () async {
    final content = utf8.encode('addappid(440)');
    final zip = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('../440.lua', content.length, content)),
    );
    await expectLater(
      parse(
        ContentSourcePayload(
          artifacts: [ContentArtifact(filename: '440.zip', bytes: zip)],
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('Lua belonging to another AppID is rejected', () async {
    await expectLater(
      parse(ContentSourcePayload(artifacts: [lua('addappid(999)')])),
      throwsA(isA<Exception>()),
    );
  });

  test('local Lua is parsed as text and never executed', () async {
    final directory = await Directory.systemTemp.createTemp('content-lua-');
    addTearDown(() => directory.delete(recursive: true));
    final marker = File(p.join(directory.path, 'executed.txt'));
    final input = File(p.join(directory.path, '440.lua'));
    await input.writeAsString(
      'addappid(440)\nlocal f = io.open([[${marker.path}]], "w"); '
      'if f then f:write("executed"); f:close() end',
    );
    final result = await resolver.resolveLocal(440, [input.path]);
    expect(result.lua, isNotNull);
    expect(await marker.exists(), isFalse);
  });

  test('one source serving both capabilities is fetched once', () async {
    source(
      'script:both',
      {ContentCapability.lua, ContentCapability.manifestFiles},
      ContentSourcePayload(artifacts: [lua('addappid(440)'), manifest()]),
    );
    final bundle = await resolver.resolve(
      440,
      const ContentPlan(
        luaSourceId: 'script:both',
        manifestSourceId: 'script:both',
      ),
    );
    expect(bundle.lua, isNotNull);
    expect(bundle.manifestFiles, hasLength(1));
    expect(registry.calls, {'script:both': 1});
  });

  test('a dual-capability source can be used for Lua alone', () async {
    source('script:both', {
      ContentCapability.lua,
      ContentCapability.manifestFiles,
    }, ContentSourcePayload(artifacts: [lua('addappid(440)')]));
    final bundle = await resolver.resolve(
      440,
      const ContentPlan(luaSourceId: 'script:both'),
    );
    expect(bundle.lua, isNotNull);
    expect(bundle.manifestFiles, isEmpty);
  });

  test('manifest-only definitions cannot be selected for Lua', () async {
    source('script:manifest', {
      ContentCapability.manifestFiles,
    }, ContentSourcePayload(artifacts: [manifest()]));
    await expectLater(
      resolver.resolve(440, const ContentPlan(luaSourceId: 'script:manifest')),
      throwsA(isA<Exception>()),
    );
    expect(registry.calls, isEmpty);
  });
}
