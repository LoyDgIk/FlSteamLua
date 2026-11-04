import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/features/achievements/achievement_models.dart';
import 'package:fl_steam_lua/features/achievements/achievement_service.dart';
import 'package:fl_steam_lua/features/achievements/worker_session.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWorker implements AchievementWorkerSession {
  FakeWorker(this.appId);
  final int appId;
  bool achieved = false;
  int score = 10;
  bool failSave = false;
  bool ignoreSave = false;
  bool closed = false;
  int saves = 0;

  @override
  Future<AchievementSnapshot> load() async => AchievementSnapshot(
    appId: appId,
    achievements: [Achievement(id: 'first', name: 'First', achieved: achieved)],
    stats: [
      GameStat(
        id: 'score',
        name: 'Score',
        type: StatType.integer,
        value: score,
        minimum: 0,
        maximum: 100,
      ),
    ],
  );
  @override
  Future<void> save(
    Map<String, bool> achievements,
    Map<String, num> stats,
  ) async {
    saves++;
    if (failSave) throw StateError('Steam rejected the update');
    if (ignoreSave) return;
    achieved = achievements['first'] ?? achieved;
    score = stats['score']?.toInt() ?? score;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<SteamTickets> tickets() async => SteamTickets(
    appId: appId,
    steamId: '42',
    appTicketBase64: 'YQ==',
    encryptedTicketBase64: 'Yg==',
  );
}

void main() {
  const firstGame = GameEntry(appId: 10, name: 'One');
  const secondGame = GameEntry(appId: 20, name: 'Two');
  late List<FakeWorker> workers;
  late AchievementService service;
  setUp(() {
    workers = [];
    service = AchievementService(
      sessionFactory: (appId, path) async {
        final worker = FakeWorker(appId);
        workers.add(worker);
        return worker;
      },
    );
  });
  tearDown(() async {
    await service.close();
    service.dispose();
  });

  test('changes remain pending until saved and confirmed', () async {
    await service.load(firstGame, steamPath: 'test');
    service.setAchievement('first', true);
    service.setStat('score', 22);
    expect(service.data!.achievements.single.achieved, false);
    expect(workers.single.saves, 0);
    await service.save();
    expect(service.hasChanges, false);
    expect(service.data!.achievements.single.achieved, true);
    expect(service.data!.stats.single.value, 22);
  });

  test('toggling back removes pending state', () async {
    await service.load(firstGame, steamPath: 'test');
    service.setAchievement('first', true);
    service.setAchievement('first', false);
    service.setStat('score', 20);
    service.setStat('score', 10);
    expect(service.hasChanges, false);
    await service.save();
    expect(workers.single.saves, 0);
  });

  test('failed save preserves pending changes and exposes failure', () async {
    await service.load(firstGame, steamPath: 'test');
    service.setAchievement('first', true);
    workers.single.failSave = true;
    await expectLater(service.save(), throwsStateError);
    expect(service.pending, {'first': true});
    expect(service.error, isA<StateError>());
    expect(service.isSaving, false);
  });

  test('a successful enqueue without confirmed data is not success', () async {
    await service.load(firstGame, steamPath: 'test');
    service.setAchievement('first', true);
    workers.single.ignoreSave = true;
    await expectLater(service.save(), throwsStateError);
    expect(service.pending, {'first': true});
  });

  test('switching app closes old worker and scopes data by app ID', () async {
    await service.load(firstGame, steamPath: 'test');
    await service.load(secondGame, steamPath: 'test');
    expect(workers.first.closed, true);
    expect(service.data!.appId, 20);
    expect(workers.length, 2);
  });

  test('rejects invalid stat values before worker mutation', () async {
    await service.load(firstGame, steamPath: 'test');
    for (final value in [double.nan, double.infinity, -1, 101, 12.5]) {
      expect(() => service.setStat('score', value), throwsArgumentError);
    }
    expect(() => service.setAchievement('unknown', true), throwsArgumentError);
    expect(workers.single.saves, 0);
  });

  test(
    'ticket extraction uses isolated session and always closes it',
    () async {
      final tickets = await service.extractTickets(
        appId: 20,
        steamPath: 'test',
      );
      expect(tickets.appId, 20);
      expect(workers.single.closed, true);
      expect(service.game, isNull);
    },
  );
}
