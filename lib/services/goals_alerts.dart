import 'dart:math' as math;

import '../models/sports.dart';
import 'sports_service.dart';
import 'storage_service.dart';

class GoalAlertNotice {
  const GoalAlertNotice(
      {required this.viewerId,
      required this.game,
      required this.team,
      required this.observedAt});
  final String viewerId;
  final SportsGame game;
  final SportsTeam team;
  final DateTime observedAt;
}

class _ScoreSample {
  _ScoreSample(this.score, this.state, this.at, this.owner, this.start);
  final int score;
  final GameState state;
  final DateTime at;
  final String owner;
  final DateTime start;
}

/// Foreground, opt-in scoring changes for all My Teams. Reuses the existing
/// cached scoreboard client; no new endpoint or per-team network request.
class GoalsAlerts {
  GoalsAlerts(this.storage,
      {DateTime Function()? now,
      Future<List<SportsGame>> Function(List<SportsLeague>, DateTime)?
          loadGames})
      : now = now ?? DateTime.now,
        _loadGames = loadGames ?? SportsService.instance.gamesForDay;
  final StorageService storage;
  final DateTime Function() now;
  final Future<List<SportsGame>> Function(List<SportsLeague>, DateTime)
      _loadGames;
  final Map<String, _ScoreSample> _scores = {};
  String _viewer = '';
  int _epoch = 0;
  int? _busyEpoch;
  bool _disposed = false;
  static final _notPlaying = RegExp(
      r'postpon|cancel|abandon|suspend|forfeit|\btbd\b',
      caseSensitive: false);

  bool get enabled => storage.getGoalsAlert() && !storage.getSportsHideScores();
  Set<String> get _followed => storage.getSportsFollowedTeams().toSet();

  void reset() {
    _epoch++;
    _viewer = '';
    _scores.clear();
  }

  void dispose() {
    _disposed = true;
    reset();
  }

  bool isCurrent(GoalAlertNotice notice) =>
      !_disposed &&
      enabled &&
      _viewer == notice.viewerId &&
      storage.getActiveViewerId() == notice.viewerId &&
      _followed.contains('${notice.game.league.id}|${notice.team.id}') &&
      now().difference(notice.observedAt) <= const Duration(seconds: 90);

  Future<List<GoalAlertNotice>> poll() async {
    if (_disposed) return const [];
    final viewer = storage.getActiveViewerId();
    if (!enabled) {
      reset();
      return const [];
    }
    if (_viewer != viewer) {
      reset();
      _viewer = viewer;
    }
    final followed = _followed;
    _scores.removeWhere((_, s) =>
        !followed.contains(s.owner) ||
        now().difference(s.at) > const Duration(hours: 6));
    final leagues = <String, SportsLeague>{};
    for (final raw in followed) {
      final team = FollowedTeam.parse(raw);
      final league = team == null ? null : sportsLeagueById(team.leagueId);
      if (league != null && league.kind == SportsKind.team) {
        leagues[league.id] = league;
      }
    }
    if (leagues.isEmpty || _busyEpoch == _epoch) return const [];
    final epoch = _epoch;
    _busyEpoch = epoch;
    try {
      final all = <SportsGame>[];
      final todo = leagues.values.toList();
      var index = 0;
      Future<void> worker() async {
        while (index < todo.length) {
          final league = todo[index++];
          final current = now().toLocal();
          final today = DateTime(current.year, current.month, current.day);
          final dates = <DateTime>{today};
          // Keep an overnight live game's start day through its final update;
          // the normal day helper otherwise carries over live games only.
          for (final sample in _scores.values) {
            if (sample.state != GameState.live ||
                !sample.owner.startsWith('${league.id}|')) {
              continue;
            }
            final start = sample.start.toLocal();
            final day = DateTime(start.year, start.month, start.day);
            if (day.isBefore(today) &&
                today.difference(day) <= const Duration(days: 2)) {
              dates.add(day);
            }
          }
          for (final day in dates) {
            try {
              all.addAll(await _loadGames([league], day));
            } catch (_) {
              /* Preserve samples through a temporary feed failure. */
            }
            if (_disposed || epoch != _epoch) return;
          }
        }
      }

      await Future.wait(
          List.generate(math.min(2, todo.length), (_) => worker()));
      if (_disposed ||
          epoch != _epoch ||
          viewer != storage.getActiveViewerId() ||
          !enabled) {
        return const [];
      }
      final at = now();
      final owners = _followed;
      final seen = <String>{};
      final notices = <GoalAlertNotice>[];
      for (final game in all) {
        if (game.league.kind != SportsKind.team ||
            !seen.add('${game.league.id}:${game.id}')) {
          continue;
        }
        if (_notPlaying.hasMatch(game.statusText)) continue;
        // An incomplete scoreboard must never manufacture a goal or scoreline.
        final home = int.tryParse(game.home.score ?? '');
        final away = int.tryParse(game.away.score ?? '');
        if (home == null || away == null || home < 0 || away < 0) continue;
        for (final team in [game.home, game.away]) {
          final owner = '${game.league.id}|${team.id}';
          if (!owners.contains(owner)) continue;
          final key = '${game.league.id}:${game.id}|${team.id}';
          final score = team.id == game.home.id ? home : away;
          final previous = _scores[key];
          _scores[key] = _ScoreSample(score, game.state, at, owner, game.start);
          final eligible = game.state == GameState.live ||
              (game.state == GameState.post &&
                  previous?.state == GameState.live &&
                  at.difference(previous!.at) <= const Duration(minutes: 3));
          // First observation (including first launch, new team or resume) is
          // only a baseline. Corrections downward are also silent.
          if (previous != null &&
              eligible &&
              previous.state != GameState.post &&
              score > previous.score) {
            notices.add(GoalAlertNotice(
                viewerId: viewer, game: game, team: team, observedAt: at));
          }
        }
      }
      while (_scores.length > 512) {
        _scores.remove(_scores.keys.first);
      }
      return notices;
    } finally {
      if (_busyEpoch == epoch) _busyEpoch = null;
    }
  }
}
