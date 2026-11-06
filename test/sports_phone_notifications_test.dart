import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/game_reminders.dart';
import 'package:nox_iptv/services/goals_alerts.dart';
import 'package:nox_iptv/services/sports_goal_background.dart';
import 'package:nox_iptv/services/sports_phone_notifications.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SportsGame fixture(DateTime start,
        {String id = 'g',
        String home = '0',
        String away = '0',
        GameState state = GameState.live}) =>
    SportsGame(
        id: id,
        league: sportsLeagueById('nhl')!,
        start: start,
        state: state,
        statusText: state == GameState.post ? 'Final' : '2nd',
        home: SportsTeam(
            id: 'h',
            name: 'Home',
            shortName: 'Home',
            abbreviation: 'H',
            score: home),
        away: SportsTeam(
            id: 'a',
            name: 'Away',
            shortName: 'Away',
            abbreviation: 'A',
            score: away));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late DateTime now;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    now = DateTime.now();
    L10n.code = 'en';
  });
  tearDown(() => L10n.code = 'en');
  Future<void> follow() async {
    await storage.setGoalsAlert(true);
    await storage.setSportsFollowedTeams(['nhl|h']);
  }

  List<Map<String, Object>> plan(GameReminders reminders,
          {Iterable<SportsGame> games = const []}) =>
      sportsNotificationPlan(storage, reminders.entries,
          GoalsAlerts(storage).matchWatches, games, now);

  test(
      'phone toggles default on, are per viewer, and do not enable subscriptions',
      () async {
    expect(storage.getPhoneGameReminders(), isTrue);
    expect(storage.getPhoneGoalAlerts(), isTrue);
    expect(storage.getGoalsAlert(), isFalse);
    await storage.setPhoneGameReminders(false);
    await storage.setPhoneGoalAlerts(false);
    await storage.setActiveViewerId('other');
    expect(storage.getPhoneGameReminders(), isTrue);
    expect(storage.getPhoneGoalAlerts(), isTrue);
    await storage.setActiveViewerId('main');
    expect(storage.getPhoneGameReminders(), isFalse);
    expect(storage.getPhoneGoalAlerts(), isFalse);
  });
  test(
      'adding, editing, rescheduling and cancelling replace native reminder ids',
      () async {
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    var game = fixture(now.add(const Duration(hours: 3)), state: GameState.pre);
    await reminders.setReminder(game, leadMinutes: 15);
    var entries = plan(reminders);
    expect(entries, hasLength(2));
    final before = entries.map((i) => i['id']).toSet();
    await reminders.setReminder(game, leadMinutes: 60);
    entries = plan(reminders);
    expect(entries.every((i) => !before.contains(i['id'])), isTrue);
    expect(entries.first['at'],
        game.start.subtract(const Duration(hours: 1)).millisecondsSinceEpoch);
    final oldStart = entries.first['startAt'];
    game =
        fixture(game.start.add(const Duration(hours: 1)), state: GameState.pre);
    reminders.reconcile([game]);
    await Future<void>.delayed(Duration.zero);
    entries = plan(reminders);
    expect(entries.first['startAt'], isNot(oldStart));
    await reminders.toggle(game);
    expect(plan(reminders), isEmpty);
  });
  test('every lead has a localized early alarm and start; zero has just start',
      () async {
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    for (final lead in GameReminder.supportedLeadMinutes) {
      await reminders.setReminder(
          fixture(now.add(const Duration(days: 10)), state: GameState.pre),
          leadMinutes: lead);
      final entries = plan(reminders);
      expect(entries, hasLength(lead == 0 ? 1 : 2));
      expect(entries.last['text'], 'Starting now');
      expect(entries.every((e) => e['at'] as int > now.millisecondsSinceEpoch),
          isTrue);
    }
  });
  test('automatic team reminders are mirrored and cancellation remains skipped',
      () async {
    final start = now.add(const Duration(hours: 4));
    final reminders = GameReminders(storage,
        now: () => now, loadSchedule: (_, team) async => null);
    addTearDown(reminders.dispose);
    await reminders.setTeam(const FollowedTeam('nhl', 'h'), true,
        games: [fixture(start, state: GameState.pre)]);
    expect(plan(reminders), hasLength(2));
    await reminders.toggle(fixture(start, state: GameState.pre));
    reminders.reconcile([fixture(start, state: GameState.pre)]);
    expect(plan(reminders), isEmpty);
  });
  test(
      'passed alarms and delivered phases are dropped on regeneration/boot snapshot',
      () async {
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    final game =
        fixture(now.add(const Duration(minutes: 20)), state: GameState.pre);
    await reminders.setReminder(game, leadMinutes: 15);
    final raw = jsonDecode(storage.getGameReminders()!) as Map;
    (raw['entries'] as List).first['early'] = true;
    await storage.setGameReminders(jsonEncode(raw));
    await reminders.refreshFromDisk();
    expect(plan(reminders).map((i) => i['phase']), ['started']);
    now = now.add(const Duration(minutes: 21));
    expect(plan(reminders), isEmpty);
    expect(reminders.poll(),
        hasLength(1)); // app still has its current start popup
  });
  test('native delivery checkpoint reload suppresses the same in-app reminder',
      () async {
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    final game =
        fixture(now.add(const Duration(minutes: 20)), state: GameState.pre);
    await reminders.setReminder(game, leadMinutes: 15);
    final raw = jsonDecode(storage.getGameReminders()!) as Map;
    (raw['entries'] as List).first['early'] = true;
    await storage.setGameReminders(jsonEncode(raw));
    await reminders.refreshFromDisk();
    now = now.add(const Duration(minutes: 5));
    expect(reminders.poll(), isEmpty);
  });
  test('only subscribed team/match games get starts, with a five-hour cap',
      () async {
    await follow();
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    final game = fixture(now.add(const Duration(hours: 1)));
    final items = plan(reminders, games: [game]);
    expect(items, hasLength(1));
    expect(items.single['kind'], 'goals');
    expect(items.single['endAt'],
        game.start.add(const Duration(hours: 5)).millisecondsSinceEpoch);
    await storage.setGoalsAlert(false);
    expect(plan(reminders, games: [game]), isEmpty);
    final alerts = GoalsAlerts(storage);
    addTearDown(alerts.dispose);
    await alerts.setGame(game, true);
    expect(plan(reminders), hasLength(1));
    now = game.start.add(const Duration(hours: 5));
    expect(plan(reminders), isEmpty);
  });
  test(
      'disabled phone preferences remove native alarms without removing follows',
      () async {
    await follow();
    final game =
        fixture(now.add(const Duration(hours: 1)), state: GameState.pre);
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    await reminders.setReminder(game, leadMinutes: 15);
    await storage.setPhoneGameReminders(false);
    await storage.setPhoneGoalAlerts(false);
    expect(plan(reminders, games: [game]), isEmpty);
    expect(reminders.isSet(game), isTrue);
    expect(storage.getSportsFollowedTeams(), ['nhl|h']);
  });
  test('goal checkpoints dedupe across service, app reopen and another service',
      () async {
    await follow();
    var game = fixture(now);
    GoalsAlerts model() => GoalsAlerts(storage,
        persistSamples: true,
        now: () => now,
        loadGames: (_, day) async => [game]);
    final service = model();
    expect(await service.poll(), isEmpty);
    service.dispose();
    game = fixture(now, home: '1');
    final app = model();
    final notice = (await app.poll()).single;
    expect(notice.previousScore, 0);
    app.reset();
    expect(await app.poll(), isEmpty);
    app.dispose();
    final again = model();
    expect(await again.poll(), isEmpty);
    again.dispose();
  });
  test('headless checkpoints retain rollback eligibility and consume it once',
      () async {
    await follow();
    var game = fixture(now);
    final posted = <GoalAlertNotice>[];
    Future<void> poll() async {
      await pollPhoneGoals([
        {'id': 'watch', 'key': 'nhl:g', 'viewer': 'main'}
      ],
          allowed: () async => true,
          save: (s, expected, data) async {
            expect(s.getGoalPhoneCheckpoint(), expected);
            await s.setGoalPhoneCheckpoint(data);
            return true;
          },
          post: (_, notice) async => posted.add(notice),
          loadGames: (_, __) async => [game]);
    }

    await poll();
    game = fixture(now, home: '1');
    await poll();
    game = fixture(now);
    await poll();
    expect(posted.map((n) => n.overturned), [false, true]);
    expect(posted.last.team.score, '0');
    await poll();
    game = fixture(now, home: '1');
    await poll();
    game = fixture(now);
    await poll();
    expect(posted, hasLength(2));
    game = fixture(now, home: '2');
    await poll();
    expect(posted, hasLength(3));
    expect(posted.last.overturned, isFalse);
  });

  test('rejected checkpoint cannot consume or deliver an overturned notice',
      () async {
    await follow();
    var game = fixture(now);
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        now: () => now,
        loadGames: (_, __) async => [game]);
    addTearDown(goals.dispose);
    await goals.poll();
    game = fixture(now, home: '1');
    await goals.poll();
    final before = storage.getGoalPhoneCheckpoint();
    goals.saveCheckpoint = (_, __) async => false;
    game = fixture(now);
    expect(await goals.poll(), isEmpty);
    expect(storage.getGoalPhoneCheckpoint(), before);
    goals.saveCheckpoint = null;
    expect((await goals.poll()).single.overturned, isTrue);
    expect(await goals.poll(), isEmpty);
  });

  test('old checkpoints baseline without inventing a prior goal notice',
      () async {
    await follow();
    var game = fixture(now, home: '1');
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        now: () => now,
        loadGames: (_, __) async => [game]);
    addTearDown(goals.dispose);
    await goals.poll();
    final data = jsonDecode(storage.getGoalPhoneCheckpoint()!) as Map;
    for (final sample in data['samples'] as List) {
      (sample as Map).remove('peak');
    }
    await storage.setGoalPhoneCheckpoint(jsonEncode(data));
    game = fixture(now);
    expect(await goals.poll(), isEmpty);
  });

  test('review phone text is localized, masked and never fetches a scorer',
      () async {
    await follow();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel,
            (call) async {
      if (call.method == 'foreground') return false;
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel, null));
    var lookups = 0;
    for (final hidden in [false, true]) {
      await storage.setSportsHideScores(hidden);
      final game = fixture(now);
      final notice = GoalAlertNotice(
          viewerId: 'main',
          game: game,
          team: game.home,
          observedAt: now,
          previousScore: 1,
          overturned: true);
      await SportsPhoneNotifications.postGoal(storage, notice,
          summaryLoader: (_) async {
        lookups++;
        return null;
      });
      final args = calls.last.arguments as Map;
      expect(args['title'], 'Goal disallowed after review');
      expect(args['hiddenText'], 'Goal disallowed after review');
      expect(args['id'], 'overturned|nhl:g|h|0');
      expect(args['text'],
          hidden ? 'Goal disallowed after review' : 'Home vs Away · 0–0');
    }
    expect(lookups, 0);
    for (final language in ['fr', 'es', 'it', 'el', 'de']) {
      await L10n.apply(language);
      final game = fixture(now);
      expect(
          GoalAlertNotice(
                  viewerId: 'main',
                  game: game,
                  team: game.home,
                  observedAt: now,
                  overturned: true)
              .overturnedText,
          isNot('Goal disallowed after review'));
      final football = SportsGame(
          id: 'f',
          league: sportsLeagueById('nfl')!,
          start: now,
          state: GameState.live,
          statusText: 'Q2',
          home: game.home,
          away: game.away);
      expect(
          GoalAlertNotice(
                  viewerId: 'main',
                  game: football,
                  team: football.home,
                  observedAt: now,
                  overturned: true)
              .overturnedText,
          isNot('Score overturned after review'));
    }
  });

  test('foreground return during fetch cannot commit or notify', () async {
    await follow();
    var allowed = true;
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        now: () => now,
        loadGames: (_, day) async {
          allowed = false;
          return [fixture(now, home: '2')];
        });
    addTearDown(goals.dispose);
    goals.canPoll = () async => allowed;
    expect(await goals.poll(), isEmpty);
    expect(storage.getGoalPhoneCheckpoint(), isNull);
  });
  test(
      'profile change at the final commit guard cannot save into another viewer',
      () async {
    await follow();
    await storage.setActiveViewerId('other');
    await follow();
    await storage.setActiveViewerId('main');
    var checks = 0;
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        now: () => now,
        loadGames: (_, day) async => [fixture(now)]);
    addTearDown(goals.dispose);
    goals.canPoll = () async {
      checks++;
      if (checks == 3) await storage.setActiveViewerId('other');
      return true;
    };
    expect(await goals.poll(), isEmpty);
    expect(storage.getGoalPhoneCheckpoint(), isNull);
    await storage.setActiveViewerId('main');
    expect(storage.getGoalPhoneCheckpoint(), isNull);
  });

  test(
      'closed-app league-only follows do not create phone polling subscriptions',
      () async {
    await storage.setLeagueGoalAlerts(['nhl']);
    final result = await pollPhoneGoals([
      {'id': 'w', 'key': 'nhl:g', 'viewer': 'main'}
    ],
        allowed: () async => true,
        save: (_, expected, data) async => throw StateError('must not save'),
        post: (_, notice) async => throw StateError('must not notify'),
        loadGames: (_, day) async => throw StateError('must not fetch'));
    expect(result.subscribed, 0);
  });

  test('rejected native compare-and-set never hands a goal to the OS',
      () async {
    await follow();
    var game = fixture(now);
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        now: () => now,
        loadGames: (_, day) async => [game]);
    addTearDown(goals.dispose);
    await goals.poll();
    final before = storage.getGoalPhoneCheckpoint();
    goals.saveCheckpoint = (_, data) async => false;
    game = fixture(now, home: '1');
    expect(await goals.poll(), isEmpty);
    expect(storage.getGoalPhoneCheckpoint(), before);
  });
  test('headless poll is limited to active games/leagues and detects finals',
      () async {
    await follow();
    await storage.setSportsFollowedTeams(['nhl|h', 'nba|h']);
    var game = fixture(now);
    final requests = <String>[];
    final posted = <GoalAlertNotice>[];
    final items = <Map>[
      {'id': 'watch', 'key': 'nhl:g', 'viewer': 'main'}
    ];
    Future<PhoneGoalPollResult> poll() => pollPhoneGoals(items,
        allowed: () async => true,
        save: (s, expected, data) async {
          await s.setGoalPhoneCheckpoint(data);
          return true;
        },
        post: (s, notice) async => posted.add(notice),
        loadGames: (leagues, day) async {
          requests.addAll(leagues.map((l) => l.id));
          return [game, fixture(now, id: 'unsubscribed', home: '9')];
        });
    await poll();
    game = fixture(now, home: '1');
    await poll();
    expect(posted, hasLength(1));
    expect(requests, everyElement('nhl'));
    game = fixture(now, home: '1', state: GameState.post);
    expect((await poll()).finished, {'watch'});
    expect(posted, hasLength(1));
  });
  test('a headless first poll after midnight still sees the start-day final',
      () async {
    await follow();
    final midnight = DateTime(2026, 11, 6, 0, 30);
    final start = DateTime(2026, 11, 5, 23);
    final requested = <DateTime>[];
    final observed = <SportsGame>[];
    final goals = GoalsAlerts(storage,
        now: () => midnight,
        restrictGames: {'nhl:g'},
        gameStarts: {'nhl:g': start},
        loadGames: (_, day) async {
          requested.add(day);
          return day.day == 5 ? [fixture(start, state: GameState.post)] : [];
        });
    addTearDown(goals.dispose);
    goals.observedGames = observed.addAll;
    await goals.poll();
    expect(requested, contains(DateTime(2026, 11, 5)));
    expect(observed.single.state, GameState.post);
  });

  test('headless Hide scores keeps polling but OS text contains no score',
      () async {
    await follow();
    await storage.setSportsHideScores(true);
    var game = fixture(now);
    await follow();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel,
            (call) async {
      if (call.method == 'foreground') return false;
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel, null));
    final goals = GoalsAlerts(storage,
        persistSamples: true,
        allowHiddenScores: true,
        now: () => now,
        loadGames: (_, day) async => [game]);
    addTearDown(goals.dispose);
    await goals.poll();
    game = fixture(now, home: '2');
    final notice = (await goals.poll()).single;
    await SportsPhoneNotifications.postGoal(storage, notice);
    expect(calls, hasLength(2));
    expect(calls.map((c) => c.arguments['text']), everyElement('Home scored!'));
    expect(calls.map((c) => c.arguments['id']).toSet(), hasLength(2));
  });
  test('several goals in one poll get distinct alerts with known scorers',
      () async {
    await follow();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel,
            (call) async {
      if (call.method == 'foreground') return false;
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel, null));
    final game = fixture(now, home: '2');
    await SportsPhoneNotifications.postGoal(
        storage,
        GoalAlertNotice(
            viewerId: 'main',
            game: game,
            team: game.home,
            observedAt: now,
            previousScore: 0),
        summaryLoader: (_) async => const SportsGameSummary(goals: [
              SportsGoal(minute: '1', scorer: 'First scorer', teamId: 'h'),
              SportsGoal(minute: '2', scorer: 'Second scorer', teamId: 'h')
            ]));
    expect(calls, hasLength(2));
    expect(calls.first.arguments['text'], contains('First scorer'));
    expect(calls.last.arguments['text'], contains('Second scorer'));
    expect(calls.map((c) => c.arguments['id']).toSet(), hasLength(2));
  });

  test('visible app skips the system goal path before fetching a scorer',
      () async {
    await follow();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel,
            (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SportsPhoneNotifications.channel, null));
    final game = fixture(now, home: '1');
    await SportsPhoneNotifications.postGoal(
        storage,
        GoalAlertNotice(
            viewerId: 'main', game: game, team: game.home, observedAt: now),
        summaryLoader: (_) async => throw StateError('must not fetch'));
    expect(calls.map((c) => c.method), ['foreground']);
  });
  test('overlapping matches share a plan while each viewer remains isolated',
      () async {
    await follow();
    final reminders = GameReminders(storage);
    addTearDown(reminders.dispose);
    var items = plan(reminders,
        games: [fixture(now, id: 'g1'), fixture(now, id: 'g2')]);
    expect(items.where((i) => i['kind'] == 'goals'), hasLength(2));
    expect(items.map((i) => i['viewer']), everyElement('main'));
    await storage.setActiveViewerId('other');
    expect(plan(reminders, games: [fixture(now)]), isEmpty);
  });
  test('phone texts use the selected language and safe target parsing',
      () async {
    await L10n.apply('fr');
    final reminders = GameReminders(storage, now: () => now);
    addTearDown(reminders.dispose);
    await reminders.setReminder(
        fixture(now.add(const Duration(hours: 2)), state: GameState.pre),
        leadMinutes: 15);
    expect(plan(reminders).singleWhere((i) => i['phase'] == 'started')['text'],
        'Commence maintenant');
    expect(
        SportsNotificationTarget.parse(
                {'key': 'nhl:g', 'startAt': now.millisecondsSinceEpoch})!
            .key,
        'nhl:g');
    expect(
        SportsNotificationTarget.parse({'key': 'nhl:', 'startAt': 1}), isNull);
    expect(SportsNotificationTarget.parse({'key': 'unknown:g', 'startAt': 1}),
        isNull);
  });
}
