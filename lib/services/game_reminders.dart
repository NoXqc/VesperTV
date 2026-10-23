import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/sports.dart';
import 'storage_service.dart';
import 'sports_service.dart';

class GameReminder {
  GameReminder(
      {required this.key,
      required this.home,
      required this.away,
      required this.start,
      this.logoUrl,
      this.manual = true,
      Set<String>? teams,
      this.earlySent = false,
      this.startSent = false})
      : teams = teams ?? {};

  final String key;
  final String home;
  final String away;
  final DateTime start;
  String? logoUrl;
  final bool manual;
  final Set<String> teams;
  bool earlySent;
  bool startSent;

  DateTime get early => start.subtract(const Duration(minutes: 15));
  DateTime get expires => start.add(const Duration(minutes: 2));

  Map<String, Object> toJson() => {
        'logo': logoUrl ?? '',
        'manual': manual,
        'teams': teams.toList(),
        'key': key,
        'home': home,
        'away': away,
        'start': start.toUtc().toIso8601String(),
        'early': earlySent,
        'started': startSent
      };

  static GameReminder? parse(Object? raw) {
    if (raw is! Map ||
        raw['key'] is! String ||
        raw['home'] is! String ||
        raw['away'] is! String ||
        raw['start'] is! String) {
      return null;
    }
    final start = DateTime.tryParse(raw['start'] as String)?.toUtc();
    if (start == null) return null;
    return GameReminder(
        key: raw['key'] as String,
        home: raw['home'] as String,
        away: raw['away'] as String,
        start: start,
        logoUrl: raw['logo'] is String ? raw['logo'] as String : null,
        manual: raw['manual'] != false,
        teams: (raw['teams'] is List ? raw['teams'] as List : [])
            .whereType<String>()
            .toSet(),
        earlySent: raw['early'] == true,
        startSent: raw['started'] == true);
  }
}

class GameReminderNotice {
  const GameReminderNotice(this.reminder, {required this.atStart});
  final GameReminder reminder;
  final bool atStart;

  bool validAt(DateTime now) => atStart
      ? !now.isAfter(reminder.expires)
      : now.isBefore(reminder.start) &&
          now.difference(reminder.early) <= const Duration(minutes: 1);
}

/// Per-game and automatic team reminders, scoped to the viewer and device.
/// The app-wide overlay schedules the next deadline only while foregrounded.
class GameReminders extends ChangeNotifier {
  GameReminders(this._storage,
      {DateTime Function()? now,
      Future<SportsTeamSchedule?> Function(SportsLeague, String)? loadSchedule})
      : now = now ?? DateTime.now,
        _loadSchedule = loadSchedule ?? SportsService.instance.teamSchedule {
    loadViewer();
  }

  final StorageService _storage;
  final Future<SportsTeamSchedule?> Function(SportsLeague, String)
      _loadSchedule;
  final Set<String> _teams = {};
  final Set<String> _skipped = {};
  DateTime? _lastSync;
  int _generation = 0;
  bool _disposed = false;
  bool get hasTeamReminders => _teams.isNotEmpty;
  DateTime get nextScheduleRefresh =>
      (_lastSync ?? now()).add(const Duration(minutes: 30));
  bool teamEnabled(FollowedTeam team) => _teams.contains(team.key);
  List<FollowedTeam> get followedTeams => [
        for (final raw in _storage.getSportsFollowedTeams())
          if (FollowedTeam.parse(raw) case final t?) t
      ];

  Set<String> _owners(SportsGame game) => {
        for (final id in [game.home.id, game.away.id])
          if (_teams.contains('${game.league.id}|$id')) '${game.league.id}|$id'
      };
  String? _logo(SportsGame game) {
    for (final side in [game.home, game.away]) {
      if (teamEnabled(FollowedTeam(game.league.id, side.id))) {
        return side.logoUrl;
      }
    }
    for (final side in [game.home, game.away]) {
      if (followedTeams.contains(FollowedTeam(game.league.id, side.id))) {
        return side.logoUrl;
      }
    }
    return game.home.logoUrl;
  }

  Future<void> setTeam(FollowedTeam team, bool enabled,
      {Iterable<SportsGame> games = const []}) async {
    loadViewer();
    final viewer = viewerId;
    final wasEnabled = _teams.contains(team.key);
    final previous = {
      for (final entry in _entries.values)
        entry.key: GameReminder.parse(entry.toJson())!
    };
    if (enabled) {
      _teams.add(team.key);
    } else {
      _teams.remove(team.key);
      _entries.removeWhere((_, entry) {
        entry.teams.remove(team.key);
        return !entry.manual && entry.teams.isEmpty;
      });
    }
    reconcile(games, persist: false);
    try {
      await _save();
    } catch (_) {
      if (viewerId == viewer) {
        if (wasEnabled) {
          _teams.add(team.key);
        } else {
          _teams.remove(team.key);
        }
        _entries
          ..clear()
          ..addAll(previous);
      }
      rethrow;
    }
    if (_disposed || viewerId != viewer) return;
    notifyListeners();
    if (enabled) await refreshSchedules(force: true);
  }

  Future<void> refreshSchedules({bool force = false}) async {
    loadViewer();
    if (!hasTeamReminders ||
        (!force &&
            _lastSync != null &&
            now().difference(_lastSync!) < const Duration(minutes: 30))) {
      return;
    }
    _lastSync = now();
    final generation = _generation;
    for (final key in _teams.toList()) {
      final team = FollowedTeam.parse(key);
      final league = team == null ? null : sportsLeagueById(team.leagueId);
      if (league == null) continue;
      try {
        final schedule = await _loadSchedule(league, team!.teamId);
        if (_disposed ||
            generation != _generation ||
            _storage.getActiveViewerId() != viewerId) {
          return;
        }
        if (schedule != null) reconcile(schedule.games);
      } catch (_) {
        /* Keep saved schedule through a temporary network failure. */
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  final DateTime Function() now;
  String viewerId = '';
  final Map<String, GameReminder> _entries = {};
  Future<void> _write = Future.value();

  static String gameKey(SportsGame game) => '${game.league.id}:${game.id}';
  bool containsKey(String key) => _entries.containsKey(key);
  bool isCurrent(GameReminder entry) =>
      _entries[entry.key]?.start == entry.start;
  bool isSet(SportsGame game) => containsKey(gameKey(game));
  bool canSet(SportsGame game) =>
      game.state == GameState.pre &&
      game.start.isAfter(now()) &&
      !RegExp(r'postpon|cancel|suspend|\btbd\b', caseSensitive: false)
          .hasMatch(game.statusText);

  void loadViewer() {
    final active = _storage.getActiveViewerId();
    if (viewerId == active) return;
    viewerId = active;
    _entries.clear();
    _teams.clear();
    _skipped.clear();
    _lastSync = null;
    _generation++;
    try {
      final raw =
          jsonDecode(_storage.getGameReminders(viewerId: active) ?? '[]');
      if (raw is Map) {
        _teams.addAll((raw['teams'] as List? ?? []).whereType<String>());
        _skipped.addAll((raw['skipped'] as List? ?? []).whereType<String>());
      }
      final entries = raw is List
          ? raw
          : raw is Map
              ? raw['entries']
              : null;
      if (entries is List) {
        for (final value in entries) {
          final entry = GameReminder.parse(value);
          if (entry != null && entry.expires.isAfter(now())) {
            _entries[entry.key] = entry;
          }
        }
      }
    } catch (_) {
      // A corrupt/older preference must not prevent startup.
    }
  }

  Future<void> _save() {
    final viewer = viewerId;
    final data = jsonEncode({
      'entries': _entries.values.map((r) => r.toJson()).toList(),
      'teams': _teams.toList(),
      'skipped': _skipped.toList()
    });
    _write = _write
        .catchError((Object _) {})
        .then((_) => _storage.setGameReminders(data, viewerId: viewer));
    return _write;
  }

  void _saveLater() => unawaited(_save().catchError((Object _) {
        debugPrint('Game reminders: could not save delivery state');
      }));

  Future<bool> toggle(SportsGame game) async {
    loadViewer();
    final viewer = viewerId;
    final key = gameKey(game);
    final old = _entries.remove(key);
    final wasSkipped = _skipped.contains(key);
    if (old != null && old.teams.isNotEmpty) {
      _skipped.add(key);
    } else {
      _skipped.remove(key);
    }
    if (old == null) {
      if (!canSet(game)) throw ArgumentError('Game is not upcoming');
      _entries[key] = GameReminder(
          key: key,
          home: game.home.shortName,
          away: game.away.shortName,
          start: game.start.toUtc(),
          logoUrl: _logo(game),
          earlySent: !now()
              .isBefore(game.start.subtract(const Duration(minutes: 15))));
    }
    try {
      await _save();
    } catch (_) {
      if (viewerId == viewer) {
        if (wasSkipped) {
          _skipped.add(key);
        } else {
          _skipped.remove(key);
        }
        if (old == null) {
          _entries.remove(key);
        } else {
          _entries[key] = old;
        }
      }
      rethrow;
    }
    if (viewerId == viewer) notifyListeners();
    return old == null;
  }

  /// Fresh schedules already obtained by My Teams update known reminders.
  /// Automatic team schedules also refresh while the app is foregrounded.
  void reconcile(Iterable<SportsGame> games, {bool persist = true}) {
    loadViewer();
    var changed = false;
    for (final game in games) {
      final key = gameKey(game);
      final old = _entries[key];
      if (old == null) {
        final owners = _owners(game);
        if (owners.isNotEmpty && !_skipped.contains(key) && canSet(game)) {
          _entries[key] = GameReminder(
              key: key,
              home: game.home.shortName,
              away: game.away.shortName,
              start: game.start.toUtc(),
              logoUrl: _logo(game),
              manual: false,
              teams: owners,
              earlySent: !now()
                  .isBefore(game.start.subtract(const Duration(minutes: 15))));
          changed = true;
        }
        continue;
      }
      final owners = _owners(game);
      if (!old.teams.containsAll(owners)) {
        old.teams.addAll(owners);
        changed = true;
      }
      final logo = _logo(game);
      if (old.logoUrl != logo) {
        old.logoUrl = logo;
        changed = true;
      }
      if (game.state == GameState.post ||
          RegExp(r'postpon|cancel|suspend', caseSensitive: false)
              .hasMatch(game.statusText)) {
        _entries.remove(key);
        changed = true;
      } else if (game.state == GameState.pre &&
          game.start.toUtc() != old.start) {
        _entries[key] = GameReminder(
            key: key,
            home: game.home.shortName,
            away: game.away.shortName,
            start: game.start.toUtc(),
            logoUrl: _logo(game),
            manual: old.manual,
            teams: old.teams,
            earlySent: !now()
                .isBefore(game.start.subtract(const Duration(minutes: 15))));
        changed = true;
      }
    }
    if (changed && persist) {
      _saveLater();
      notifyListeners();
    }
  }

  List<GameReminderNotice> poll() {
    loadViewer();
    final time = now().toUtc();
    final notices = <GameReminderNotice>[];
    var changed = false;
    for (final entry in _entries.values.toList()) {
      if (!time.isBefore(entry.expires)) {
        _entries.remove(entry.key);
        changed = true;
        continue;
      }
      if (!entry.earlySent && !time.isBefore(entry.early)) {
        entry.earlySent = true;
        changed = true;
        final notice = GameReminderNotice(entry, atStart: false);
        if (notice.validAt(time)) notices.add(notice);
      }
      if (!entry.startSent && !time.isBefore(entry.start)) {
        entry.startSent = true;
        changed = true;
        notices.add(GameReminderNotice(entry, atStart: true));
      }
    }
    if (changed) _saveLater();
    return notices;
  }

  DateTime? get nextDeadline {
    DateTime? next;
    for (final entry in _entries.values) {
      final date = !entry.earlySent
          ? entry.early
          : !entry.startSent
              ? entry.start
              : entry.expires;
      if (next == null || date.isBefore(next)) next = date;
    }
    return next;
  }
}
