import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../models/sports.dart';
import 'game_reminders.dart';
import 'goals_alerts.dart';
import 'sports_service.dart';
import 'storage_service.dart';

String phoneMatchup(String home, String away) =>
    tr('{home} vs {away}', {'home': home, 'away': away});

class SportsNotificationTarget {
  const SportsNotificationTarget(this.key, this.start);
  final String key;
  final DateTime start;
  static SportsNotificationTarget? parse(Object? raw) {
    if (raw is! Map || raw['key'] is! String || raw['startAt'] is! int) {
      return null;
    }
    final key = raw['key'] as String;
    final at = key.indexOf(':');
    if (at <= 0 ||
        key.length > 200 ||
        at == key.length - 1 ||
        sportsLeagueById(key.substring(0, at)) == null) {
      return null;
    }
    return SportsNotificationTarget(
        key, DateTime.fromMillisecondsSinceEpoch(raw['startAt'] as int));
  }
}

/// Pure plan generation: native code receives translated text and deadlines.
List<Map<String, Object>> sportsNotificationPlan(
    StorageService storage,
    Iterable<GameReminder> reminders,
    Iterable<({SportsLeague league, String id, DateTime start})> watches,
    Iterable<SportsGame> teamGames,
    DateTime now) {
  final viewer = storage.getActiveViewerId();
  final scope = jsonEncode([
    storage.getGoalsAlert(),
    storage.getSportsFollowedTeams(),
    storage.getMatchScoreAlerts()
  ]);
  final result = <Map<String, Object>>[];
  Map<String, Object> item(
          String kind, String key, DateTime start, String title) =>
      {
        'kind': kind,
        'viewer': viewer,
        'key': key,
        'startAt': start.millisecondsSinceEpoch,
        'title': title,
        'reminderChannel': tr('Game reminders'),
        'goalChannel': tr('Goal alerts'),
        'followingChannel': tr('Following games'),
        'stop': tr('Stop'),
      };
  if (storage.getPhoneGameReminders()) {
    for (final r in reminders) {
      for (final early in [true, false]) {
        if (early ? r.leadMinutes == 0 || r.earlySent : r.startSent) continue;
        final at = early ? r.early : r.start;
        if (!at.isAfter(now)) continue;
        result.add({
          ...item('reminder', r.key, r.start, phoneMatchup(r.home, r.away)),
          'id':
              '$viewer|${r.key}|${r.start.millisecondsSinceEpoch}|${r.leadMinutes}|$early',
          'at': at.millisecondsSinceEpoch,
          'endAt': (early ? at.add(const Duration(minutes: 1)) : r.expires)
              .millisecondsSinceEpoch,
          'phase': early ? 'early' : 'started',
          'lead': r.leadMinutes,
          'entryStart': r.start.toUtc().toIso8601String(),
          'text': early
              ? switch (r.leadMinutes) {
                  60 => tr('Starts in 1 hour'),
                  1440 => tr('Starts in 1 day'),
                  10080 => tr('Starts in 1 week'),
                  _ => tr('Starts in 15 minutes')
                }
              : tr('Starting now'),
        });
      }
    }
  }
  if (storage.getPhoneGoalAlerts()) {
    final games = <String,
        ({SportsLeague league, String id, DateTime start, String title})>{};
    for (final w in watches) {
      games['${w.league.id}:${w.id}'] = (
        league: w.league,
        id: w.id,
        start: w.start,
        title: w.league.shortName
      );
    }
    final followed = storage.getGoalsAlert()
        ? storage.getSportsFollowedTeams().toSet()
        : <String>{};
    for (final g in teamGames) {
      if (g.league.kind != SportsKind.team ||
          g.state == GameState.post ||
          RegExp(r'postpon|cancel|abandon|suspend', caseSensitive: false)
              .hasMatch(g.statusText)) {
        continue;
      }
      if (!games.containsKey(GoalsAlerts.gameKey(g)) &&
          ![g.home, g.away]
              .any((t) => followed.contains('${g.league.id}|${t.id}'))) {
        continue;
      }
      games[GoalsAlerts.gameKey(g)] = (
        league: g.league,
        id: g.id,
        start: g.start,
        title: phoneMatchup(g.home.shortName, g.away.shortName)
      );
    }
    for (final entry in games.entries) {
      final g = entry.value;
      if (!now.isBefore(g.start.add(const Duration(hours: 5)))) continue;
      result.add({
        ...item('goals', entry.key, g.start, g.title),
        'id': '$viewer|${entry.key}|${g.start.millisecondsSinceEpoch}|goals',
        'scope': scope,
        'at': g.start.millisecondsSinceEpoch,
        'endAt': g.start.add(const Duration(hours: 5)).millisecondsSinceEpoch,
        'ongoing': tr('Following goals: {game}', {'game': g.title}),
      });
    }
  }
  return result;
}

class SportsPhoneNotifications with WidgetsBindingObserver {
  SportsPhoneNotifications(this.storage, this.reminders, this.goals,
      {this.onOpen});
  static const channel = MethodChannel('vespertv/sports_notifications');
  final StorageService storage;
  final GameReminders reminders;
  final GoalsAlerts goals;
  final bool Function(SportsNotificationTarget)? onOpen;
  Timer? _refresh;
  Timer? _debounce;
  Future<void> _syncing = Future.value();
  final _games = <String, List<SportsGame>>{};
  final _scopes = <String, String>{};
  final _observedSchedules = <String, String>{};
  bool _disposed = false, _opening = false, _needsRefresh = false;
  bool _active = true;

  void start() {
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    _active = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    storage.onSportsNotificationsChanged = () => schedule();
    storage.persistGameReminders =
        (viewer, data) => saveReminders(storage, viewer, data);
    goals.canPoll =
        () async => await channel.invokeMethod<bool>('foreground') ?? false;
    goals.saveCheckpoint = (expected, data) => commit(storage, expected, data);
    goals.systemNotify = (notices) async {
      for (final notice in notices) {
        await postGoal(storage, notice);
      }
    };
    goals.observedGames = (games) {
      final viewer = storage.getActiveViewerId();
      _games[viewer] = {
        for (final g in [...?_games[viewer], ...games])
          GoalsAlerts.gameKey(g): g
      }.values.toList();
      final signature = jsonEncode(games
          .map((g) =>
              [GoalsAlerts.gameKey(g), g.start.toIso8601String(), g.state.name])
          .toList());
      if (_observedSchedules[viewer] != signature) {
        _observedSchedules[viewer] = signature;
        schedule();
      }
    };
    schedule(refresh: true);
    _refresh = Timer.periodic(const Duration(minutes: 30), (_) {
      if (_active) schedule(refresh: true);
    });
  }

  void schedule({bool refresh = false}) {
    if (_disposed || !Platform.isAndroid) return;
    _needsRefresh |= refresh;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      final refreshNow = _needsRefresh;
      _needsRefresh = false;
      _syncing = _syncing
          .catchError((Object _) {})
          .then((_) => _sync(refreshNow))
          .catchError((Object _) {
        debugPrint('SportsNotify: sync failed');
      });
    });
  }

  Future<void> _sync(bool refresh) async {
    if (_disposed) return;
    final old = (await channel.invokeListMethod<dynamic>('plans') ?? [])
        .whereType<Map>()
        .toList();
    final plans = <Map<String, Object>>[];
    for (final viewer in storage.getViewerProfiles()) {
      final scoped = StorageService();
      await scoped.init(viewerId: viewer.id, migrate: false);
      scoped.persistGameReminders =
          (viewer, data) => saveReminders(scoped, viewer, data);
      final local = GameReminders(scoped);
      final alerts = GoalsAlerts(scoped);
      try {
        final scope = jsonEncode([
          scoped.getGoalsAlert(),
          scoped.getSportsFollowedTeams(),
          scoped.getMatchScoreAlerts()
        ]);
        if (_active && (refresh || _scopes[viewer.id] != scope)) {
          _scopes[viewer.id] = scope;
          await local.refreshSchedules(force: true);
          final games = <SportsGame>[];
          if (scoped.getGoalsAlert() && scoped.getPhoneGoalAlerts()) {
            for (final raw in scoped.getSportsFollowedTeams()) {
              final followed = FollowedTeam.parse(raw);
              final league =
                  followed == null ? null : sportsLeagueById(followed.leagueId);
              if (league == null || league.kind != SportsKind.team) continue;
              try {
                games.addAll((await SportsService.instance
                            .teamSchedule(league, followed!.teamId)
                            .timeout(const Duration(seconds: 20)))
                        ?.games ??
                    []);
              } catch (_) {}
            }
          }
          // Never replace a useful saved schedule with an empty failed fetch.
          if (games.isNotEmpty) _games[viewer.id] = games;
        }
        final current = sportsNotificationPlan(scoped, local.entries,
            alerts.matchWatches, _games[viewer.id] ?? [], DateTime.now());
        plans.addAll(current);
        if (scoped.getPhoneGoalAlerts()) {
          for (final saved in old) {
            if (saved['kind'] == 'goals' &&
                saved['viewer'] == viewer.id &&
                saved['scope'] == scope &&
                saved['endAt'] is int &&
                saved['endAt'] > DateTime.now().millisecondsSinceEpoch &&
                !current.any(
                    (p) => p['kind'] == 'goals' && p['key'] == saved['key'])) {
              plans.add(saved.map((k, v) => MapEntry('$k', v as Object)));
            }
          }
        }
      } finally {
        local.dispose();
        alerts.dispose();
      }
    }
    if (!_disposed) await channel.invokeMethod<void>('sync', {'items': plans});
  }

  static Future<void> saveReminders(
      StorageService scoped, String viewer, String data) async {
    await channel
        .invokeMethod<void>('reminders', {'viewer': viewer, 'data': data});
    await scoped.reloadPreferences();
  }

  static Future<bool> commit(
      StorageService scoped, String? expected, String data) async {
    final saved = await channel.invokeMethod<bool>('checkpoint', {
      'viewer': scoped.getActiveViewerId(),
      'expected': expected,
      'data': data,
    });
    if (saved == true) await scoped.reloadPreferences();
    return saved == true;
  }

  /// One summary fetch for each scoring update, using the existing cache/bucket.
  static Future<void> postGoal(StorageService scoped, GoalAlertNotice notice,
      {Future<SportsGameSummary?> Function(SportsGame)? summaryLoader}) async {
    if (!scoped.getPhoneGoalAlerts()) return;
    final followsTeam = scoped.getGoalsAlert() &&
        scoped
            .getSportsFollowedTeams()
            .contains('${notice.game.league.id}|${notice.team.id}');
    final subscriptions = GoalsAlerts(scoped);
    final match = subscriptions.isSet(notice.game);
    subscriptions.dispose();
    if (!followsTeam && !match) return;
    if (await channel.invokeMethod<bool>('foreground') == true) return;
    final game = notice.game;
    final current = int.tryParse(notice.team.score ?? '');
    final previous = notice.previousScore;
    final separate =
        game.league.sport == 'hockey' || game.league.sport == 'soccer';
    final scores = separate &&
            current != null &&
            previous != null &&
            current > previous
        ? [
            for (var n = previous + 1; n <= current && n <= previous + 16; n++)
              n
          ]
        : [current];
    SportsGameSummary? summary;
    if (!scoped.getSportsHideScores()) {
      try {
        summary = await (summaryLoader?.call(game) ??
            SportsService.instance.gameSummary(game, fresh: true));
      } catch (_) {}
    }
    final hidden = tr('{team} scored!', {'team': notice.team.shortName});
    for (final score in scores) {
      String? scorer;
      final mine =
          summary?.goals.where((g) => g.teamId == notice.team.id).toList();
      if (current != null &&
          mine?.length == current &&
          score != null &&
          score > 0 &&
          score <= mine!.length) {
        scorer = mine[score - 1].scorer;
      }
      if (game.league.sport == 'football') {
        for (final play in summary?.scoringPlays.reversed ?? <SportsGoal>[]) {
          if (play.teamId != notice.team.id) continue;
          final parts = play.score?.split('-');
          final after = parts?.length == 2
              ? int.tryParse(parts![game.home.id == notice.team.id ? 1 : 0])
              : null;
          if (after != null &&
              score != null &&
              after >= score &&
              after <= score + 2) {
            scorer = play.scorer;
          }
          break;
        }
      }
      final text = [
        if (scorer?.isNotEmpty ?? false) scorer!,
        phoneMatchup(game.home.shortName, game.away.shortName),
        '${game.home.score ?? ''}–${game.away.score ?? ''}'
      ].join(' · ');
      await channel.invokeMethod<void>('goal', {
        'viewer': notice.viewerId,
        'id': 'goal|${GoalsAlerts.gameKey(game)}|${notice.team.id}|$score',
        'key': GoalsAlerts.gameKey(game),
        'startAt': game.start.millisecondsSinceEpoch,
        'title': hidden,
        'text': scoped.getSportsHideScores() ? hidden : text,
        'hiddenText': hidden,
        'channel': tr('Goal alerts')
      });
    }
  }

  Future<bool> get pendingTap async {
    if (!Platform.isAndroid) return false;
    try {
      return await channel.invokeMethod<bool>('hasTap') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openPending() async {
    if (_disposed || _opening || !Platform.isAndroid) return false;
    _opening = true;
    try {
      final target =
          SportsNotificationTarget.parse(await channel.invokeMethod('target'));
      if (target == null || onOpen?.call(target) != true) return false;
      await channel.invokeMethod<void>('clearTap');
      return true;
    } catch (_) {
      return false;
    } finally {
      _opening = false;
    }
  }

  static Future<String> diagnostics() async {
    try {
      return await channel.invokeMethod<String>('diagnostics') ??
          'SportsNotify: unavailable';
    } catch (_) {
      return 'SportsNotify: unavailable';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      unawaited(reminders.refreshFromDisk().catchError((Object _) {}));
      schedule();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(openPending());
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    storage.onSportsNotificationsChanged = null;
    storage.persistGameReminders = null;
    goals.canPoll = null;
    goals.systemNotify = null;
    goals.observedGames = null;
  }
}
