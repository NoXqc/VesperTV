import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../models/sports.dart';
import 'goals_alerts.dart';
import 'sports_phone_notifications.dart';
import 'sports_service.dart';
import 'storage_service.dart';

class PhoneGoalPollResult {
  const PhoneGoalPollResult(this.subscribed, this.finished, this.observed);
  final int subscribed;
  final Set<String> finished;
  final List<SportsGame> observed;
}

/// Testable single pass. Shared GoalsAlerts does all score comparison/checkpoints.
Future<PhoneGoalPollResult> pollPhoneGoals(
  List<Map> items, {
  required Future<bool> Function() allowed,
  required Future<bool> Function(StorageService, String?, String) save,
  required Future<void> Function(StorageService, GoalAlertNotice) post,
  Future<List<SportsGame>> Function(List<SportsLeague>, DateTime)? loadGames,
}) async {
  final viewers = items.map((i) => i['viewer']).whereType<String>().toSet();
  final finished = <String>{};
  final observed = <SportsGame>[];
  var subscribed = 0;
  final sent = <String>{};
  for (final viewer in viewers) {
    if (!await allowed()) break;
    final storage = StorageService();
    await storage.init(viewerId: viewer, migrate: false);
    await storage.reloadPreferences();
    if (!storage.getPhoneGoalAlerts()) continue;
    final mine = items.where((i) => i['viewer'] == viewer).toList();
    final keys = mine.map((i) => i['key']).whereType<String>().toSet();
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        allowHiddenScores: true,
        includeLeagueSubscriptions: false,
        restrictGames: keys,
        gameStarts: {
          for (final item in mine)
            if (item['startAt'] is int)
              '${item['key']}':
                  DateTime.fromMillisecondsSinceEpoch(item['startAt'] as int)
        },
        loadGames: loadGames);
    goals.canPoll = allowed;
    goals.saveCheckpoint = (expected, data) => save(storage, expected, data);
    final games = <SportsGame>[];
    goals.observedGames = games.addAll;
    goals.systemNotify = (notices) async {
      for (final notice in notices) {
        final id =
            '${GoalsAlerts.gameKey(notice.game)}|${notice.team.id}|${notice.team.score}';
        if (sent.add(id)) await post(storage, notice);
      }
    };
    try {
      if (!goals.enabled) continue;
      subscribed += keys.length;
      await goals.poll();
      observed
          .addAll(games.where((g) => keys.contains(GoalsAlerts.gameKey(g))));
      for (final item in mine) {
        final game = games
            .where((g) => GoalsAlerts.gameKey(g) == item['key'])
            .firstOrNull;
        if (game != null &&
            (game.state == GameState.post ||
                RegExp(r'postpon|cancel|abandon|suspend', caseSensitive: false)
                    .hasMatch(game.statusText))) {
          finished.add('${item['id']}');
        }
      }
    } finally {
      goals.dispose();
    }
  }
  return PhoneGoalPollResult(subscribed, finished, observed);
}

@pragma('vm:entry-point')
void sportsGoalBackgroundMain() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    const bridge = SportsPhoneNotifications.channel;
    DateTime? missingSince;
    try {
      final root = StorageService();
      await root.init(migrate: false);
      await L10n.apply(root.getLanguage());
      Future<Map> state() async =>
          await bridge.invokeMapMethod<String, dynamic>('state') ?? {};
      Future<bool> allowed() async => (await state())['allowed'] == true;
      while (true) {
        final current = await state();
        final items =
            (current['items'] as List? ?? []).whereType<Map>().toList();
        if (current['allowed'] != true || items.isEmpty) {
          await bridge
              .invokeMethod<void>('finish', {'reason': 'foreground_or_empty'});
          return;
        }
        final result = await pollPhoneGoals(items,
            allowed: allowed,
            save: SportsPhoneNotifications.commit,
            post: SportsPhoneNotifications.postGoal);
        if (result.subscribed == 0) {
          await bridge
              .invokeMethod<void>('finish', {'reason': 'no_subscriptions'});
          return;
        }
        if (result.finished.length == items.length) {
          await bridge.invokeMethod<void>('finish',
              {'reason': 'final', 'finished': result.finished.toList()});
          return;
        }
        if (result.finished.isNotEmpty) {
          await bridge.invokeMethod<void>(
              'complete', {'finished': result.finished.toList()});
        }
        if (result.observed.isEmpty ||
            SportsService.instance.lastError != null) {
          missingSince ??= DateTime.now();
        } else {
          missingSince = null;
        }
        if (missingSince != null &&
            DateTime.now().difference(missingSince) >=
                const Duration(minutes: 15)) {
          await bridge
              .invokeMethod<void>('finish', {'reason': 'feed_unavailable'});
          return;
        }
        final live = {
          for (final g
              in result.observed.where((g) => g.state != GameState.post))
            GoalsAlerts.gameKey(g): g
        }.values.toList();
        await bridge.invokeMethod<void>('tick', {
          'ongoing': tr('Following goals: {game}', {
            'game': live.isEmpty
                ? items.first['title']
                : live
                    .map(
                        (g) => phoneMatchup(g.home.shortName, g.away.shortName))
                    .take(3)
                    .join(' · ')
          })
        });
        await Future<void>.delayed(const Duration(seconds: 60));
      }
    } catch (_) {
      await bridge.invokeMethod<void>('finish', {'reason': 'error'});
    }
  }, (error, stack) {},
      zoneSpecification:
          ZoneSpecification(print: (self, parent, zone, line) {}));
}
