import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/sports.dart';
import 'storage_service.dart';

class GameReminder {
  GameReminder(
      {required this.key,
      required this.home,
      required this.away,
      required this.start,
      this.earlySent = false,
      this.startSent = false});

  final String key;
  final String home;
  final String away;
  final DateTime start;
  bool earlySent;
  bool startSent;

  DateTime get early => start.subtract(const Duration(minutes: 15));
  DateTime get expires => start.add(const Duration(minutes: 2));

  Map<String, Object> toJson() => {
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

/// Explicit per-game, per-viewer reminders. No network, playback or OS alarms.
/// The app-wide overlay schedules the next deadline only while foregrounded.
class GameReminders extends ChangeNotifier {
  GameReminders(this._storage, {DateTime Function()? now})
      : now = now ?? DateTime.now {
    loadViewer();
  }

  final StorageService _storage;
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
    try {
      final raw =
          jsonDecode(_storage.getGameReminders(viewerId: active) ?? '[]');
      if (raw is List) {
        for (final value in raw) {
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
    final data = jsonEncode(_entries.values.map((r) => r.toJson()).toList());
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
    if (old == null) {
      if (!canSet(game)) throw ArgumentError('Game is not upcoming');
      _entries[key] = GameReminder(
          key: key,
          home: game.home.shortName,
          away: game.away.shortName,
          start: game.start.toUtc(),
          earlySent: !now()
              .isBefore(game.start.subtract(const Duration(minutes: 15))));
    }
    try {
      await _save();
    } catch (_) {
      if (viewerId == viewer) {
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
  /// No extra polling of sports providers is introduced for reminders.
  void reconcile(Iterable<SportsGame> games) {
    loadViewer();
    var changed = false;
    for (final game in games) {
      final key = gameKey(game);
      final old = _entries[key];
      if (old == null) continue;
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
            earlySent: !now()
                .isBefore(game.start.subtract(const Duration(minutes: 15))));
        changed = true;
      }
    }
    if (changed) {
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
