import 'package:flutter/foundation.dart';

import '../../core/game_entry.dart';
import 'achievement_models.dart';
import 'worker_session.dart';

class AchievementService extends ChangeNotifier {
  AchievementService({
    String? workerExecutable,
    String? bridgeLibrary,
    WorkerSessionFactory? sessionFactory,
  }) : _factory =
           sessionFactory ??
           ((appId, steamPath) => SteamWorkerSession.start(
             appId,
             steamPath,
             executable: workerExecutable,
             bridgeLibrary: bridgeLibrary,
           ));

  final WorkerSessionFactory _factory;
  AchievementWorkerSession? _session;
  GameEntry? _game;
  AchievementSnapshot? _data;
  final Map<String, bool> _pending = {};
  final Map<String, num> _pendingStats = {};
  String _steamPath = '';
  Object? _error;
  bool _loading = false;
  bool _saving = false;

  GameEntry? get game => _game;
  AchievementSnapshot? get data => _data;
  Map<String, bool> get pending => Map.unmodifiable(_pending);
  Map<String, num> get pendingStats => Map.unmodifiable(_pendingStats);
  Object? get error => _error;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get hasChanges => _pending.isNotEmpty || _pendingStats.isNotEmpty;

  Future<void> load(GameEntry game, {required String steamPath}) async {
    if (_loading || _saving) {
      throw StateError('An achievement operation is already running');
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_game?.appId != game.appId ||
          _steamPath != steamPath ||
          _session == null) {
        await _session?.close();
        _session = null;
        _data = null;
        _pending.clear();
        _pendingStats.clear();
        _game = game;
        _steamPath = steamPath;
        _session = await _factory(game.appId, steamPath);
      }
      final snapshot = await _session!.load();
      if (snapshot.appId != game.appId) {
        throw StateError('Steam returned data for a different game');
      }
      _data = snapshot;
      _pending.clear();
      _pendingStats.clear();
    } catch (error) {
      _error = error;
      final failedSession = _session;
      _session = null;
      await failedSession?.close();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reload() {
    final selected = _game;
    if (selected == null) throw StateError('Select a game first');
    return load(selected, steamPath: _steamPath);
  }

  void setAchievement(String id, bool achieved) {
    if (_loading || _saving) throw StateError('Wait for the current operation');
    final achievement = _data?.achievements
        .where((a) => a.id == id)
        .firstOrNull;
    if (achievement == null) {
      throw ArgumentError.value(id, 'id', 'Unknown achievement');
    }
    if (achieved == achievement.achieved) {
      _pending.remove(id);
    } else {
      _pending[id] = achieved;
    }
    notifyListeners();
  }

  void setStat(String id, num value) {
    if (_loading || _saving) throw StateError('Wait for the current operation');
    final stat = _data?.stats.where((s) => s.id == id).firstOrNull;
    if (stat == null) throw ArgumentError.value(id, 'id', 'Unknown statistic');
    if (!value.isFinite ||
        (stat.type == StatType.floating &&
            value.abs() > 3.4028234663852886e38) ||
        (stat.type == StatType.integer &&
            (value != value.round() ||
                value < -2147483648 ||
                value > 2147483647)) ||
        (stat.minimum != null && value < stat.minimum!) ||
        (stat.maximum != null && value > stat.maximum!)) {
      throw ArgumentError.value(value, 'value', 'Outside the statistic range');
    }
    if (value == stat.value) {
      _pendingStats.remove(id);
    } else {
      _pendingStats[id] = value;
    }
    notifyListeners();
  }

  void discardChanges() {
    if (_saving) return;
    _pending.clear();
    _pendingStats.clear();
    notifyListeners();
  }

  Future<void> save() async {
    if (_session == null || _game == null) {
      throw StateError('Select a game first');
    }
    if (_loading || _saving) {
      throw StateError('An achievement operation is already running');
    }
    if (!hasChanges) return;
    _saving = true;
    _error = null;
    notifyListeners();
    final desiredAchievements = Map<String, bool>.from(_pending);
    final desiredStats = Map<String, num>.from(_pendingStats);
    try {
      await _session!.save(desiredAchievements, desiredStats);
      final confirmed = await _session!.load();
      for (final change in desiredAchievements.entries) {
        final actual = confirmed.achievements
            .where((a) => a.id == change.key)
            .firstOrNull;
        if (actual == null || actual.achieved != change.value) {
          throw StateError('Steam did not confirm achievement ${change.key}');
        }
      }
      for (final change in desiredStats.entries) {
        final actual = confirmed.stats
            .where((s) => s.id == change.key)
            .firstOrNull;
        final expected = actual?.type == StatType.floating
            ? (ByteData(
                4,
              )..setFloat32(0, change.value.toDouble())).getFloat32(0)
            : change.value;
        if (actual == null || actual.value != expected) {
          throw StateError('Steam did not confirm statistic ${change.key}');
        }
      }
      _data = confirmed;
      _pending.clear();
      _pendingStats.clear();
    } catch (error) {
      _error = error;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<SteamTickets> extractTickets({
    required int appId,
    required String steamPath,
  }) async {
    final session = await _factory(appId, steamPath);
    try {
      return await session.tickets();
    } finally {
      await session.close();
    }
  }

  Future<void> close() async {
    await _session?.close();
    _session = null;
  }

  @override
  void dispose() {
    final session = _session;
    _session = null;
    session?.close();
    super.dispose();
  }
}
