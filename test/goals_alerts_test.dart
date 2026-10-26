import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/goals_alerts.dart';
import 'package:nox_iptv/services/storage_service.dart';

SportsGame scoreGame(DateTime time,
        {String id = 'game',
        String league = 'nhl',
        String? home = '0',
        String? away = '0',
        GameState state = GameState.live,
        String status = '2nd',
        DateTime? start}) =>
    SportsGame(
        id: id,
        league: sportsLeagueById(league)!,
        start: start ?? time.subtract(const Duration(hours: 1)),
        state: state,
        statusText: status,
        home: SportsTeam(
            id: 'mtl',
            name: 'Montreal Canadiens',
            shortName: 'Canadiens',
            abbreviation: 'MTL',
            score: home,
            logoUrl: 'https://example.com/mtl.png'),
        away: SportsTeam(
            id: 'buf',
            name: 'Buffalo Sabres',
            shortName: 'Buffalo',
            abbreviation: 'BUF',
            score: away,
            logoUrl: 'https://example.com/buf.png'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late GoalsAlerts service;
  late DateTime time;
  late List<SportsGame> games;
  late List<String> requests;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    await storage.setSportsFollowedTeams(['nhl|mtl']);
    time = DateTime(2026, 10, 26, 20);
    games = [scoreGame(time)];
    requests = [];
    service = GoalsAlerts(storage,
        now: () => time,
        loadGames: (leagues, day) async {
          requests.add(leagues.single.id);
          return games.where((g) => g.league.id == leagues.single.id).toList();
        });
  });
  tearDown(() => service.dispose());

  test('default off does no network work; preference persists per viewer',
      () async {
    expect(storage.getGoalsAlert(), isFalse);
    expect(await service.poll(), isEmpty);
    expect(requests, isEmpty);
    await storage.setGoalsAlert(true);
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getGoalsAlert(), isTrue);
    await storage.setActiveViewerId('other');
    expect(storage.getGoalsAlert(), isFalse);
    await storage.setActiveViewerId('main');
    expect(storage.getGoalsAlert(), isTrue);
  });

  test(
      'first score is baseline, selected team increases alert with exact score and logos',
      () async {
    await storage.setGoalsAlert(true);
    games = [scoreGame(time, home: '2', away: '1')];
    expect(await service.poll(), isEmpty);
    games = [scoreGame(time, home: '3', away: '1')];
    final notice = (await service.poll()).single;
    expect(notice.team.id, 'mtl');
    expect(notice.team.score, '3');
    expect(notice.team.logoUrl, 'https://example.com/mtl.png');
    expect(notice.game.league.logoUrl, isNotEmpty);
    expect(service.isCurrent(notice), isTrue);
    expect(await service.poll(), isEmpty);
    games = [scoreGame(time, home: '3', away: '2')];
    expect(await service.poll(), isEmpty);
  });

  test('newly followed team is baselined, removed team stops alerts', () async {
    await storage.setGoalsAlert(true);
    await service.poll();
    await storage.setSportsFollowedTeams(['nhl|mtl', 'nhl|buf']);
    games = [scoreGame(time, home: '1', away: '2')];
    final first = await service.poll();
    expect(first.single.team.id, 'mtl');
    games = [scoreGame(time, home: '1', away: '3')];
    final second = (await service.poll()).single;
    expect(second.team.id, 'buf');
    await storage.setSportsFollowedTeams(['nhl|mtl']);
    expect(service.isCurrent(second), isFalse);
    games = [scoreGame(time, home: '1', away: '4')];
    expect(await service.poll(), isEmpty);
  });

  test(
      'every followed team and league is included, with one request per league',
      () async {
    await storage.setGoalsAlert(true);
    await storage.setSportsFollowedTeams(['nhl|mtl', 'nhl|buf', 'nba|mtl']);
    games = [scoreGame(time), scoreGame(time, league: 'nba')];
    await service.poll();
    expect(requests.toSet(), {'nhl', 'nba'});
    expect(requests.length, 2);
    games = [
      scoreGame(time, home: '1', away: '1'),
      scoreGame(time, league: 'nba', home: '3')
    ];
    expect(
        (await service.poll())
            .map((n) => '${n.game.league.id}|${n.team.id}')
            .toSet(),
        {'nhl|mtl', 'nhl|buf', 'nba|mtl'});
  });

  test(
      'pre-game and downward corrections are silent, real subsequent increase alerts',
      () async {
    await storage.setGoalsAlert(true);
    games = [scoreGame(time, state: GameState.pre)];
    await service.poll();
    games = [scoreGame(time, home: '1')];
    expect((await service.poll()).length, 1);
    games = [scoreGame(time, home: '0')];
    expect(await service.poll(), isEmpty);
    games = [scoreGame(time, home: '1')];
    expect((await service.poll()).length, 1);
    games = [scoreGame(time, home: '2', state: GameState.pre)];
    expect(await service.poll(), isEmpty);
  });

  test(
      'final winning score is reported once, already finished games never replay',
      () async {
    await storage.setGoalsAlert(true);
    await service.poll();
    games = [
      scoreGame(time, home: '1', state: GameState.post, status: 'Final')
    ];
    expect((await service.poll()).length, 1);
    expect(await service.poll(), isEmpty);
    games = [
      scoreGame(time, home: '2', state: GameState.post, status: 'Final')
    ];
    expect(await service.poll(), isEmpty);
    service.reset();
    expect(await service.poll(), isEmpty);
  });

  test(
      'missing/invalid scores, canceled and forfeited matches cannot invent a goal',
      () async {
    await storage.setGoalsAlert(true);
    await service.poll();
    for (final game in [
      scoreGame(time, home: null),
      scoreGame(time, away: '?'),
      scoreGame(time, home: '-1'),
      scoreGame(time, home: '3', state: GameState.post, status: 'Forfeit'),
      scoreGame(time, home: '3', status: 'Canceled')
    ]) {
      games = [game];
      expect(await service.poll(), isEmpty);
    }
  });

  test('Hide scores pauses alerts and resuming establishes a fresh baseline',
      () async {
    await storage.setGoalsAlert(true);
    await service.poll();
    requests.clear();
    await storage.setSportsHideScores(true);
    games = [scoreGame(time, home: '2')];
    expect(await service.poll(), isEmpty);
    expect(requests, isEmpty);
    await storage.setSportsHideScores(false);
    expect(await service.poll(), isEmpty);
    games = [scoreGame(time, home: '3')];
    expect((await service.poll()).length, 1);
  });

  test('background/reset and opt-out never replay scores from the gap',
      () async {
    await storage.setGoalsAlert(true);
    await service.poll();
    service.reset();
    games = [scoreGame(time, home: '4')];
    expect(await service.poll(), isEmpty);
    games = [scoreGame(time, home: '5')];
    final notice = (await service.poll()).single;
    await storage.setGoalsAlert(false);
    expect(service.isCurrent(notice), isFalse);
    expect(await service.poll(), isEmpty);
    await storage.setGoalsAlert(true);
    games = [scoreGame(time, home: '6')];
    expect(await service.poll(), isEmpty);
  });

  test(
      'old viewer in-flight response cannot notify or overwrite new viewer baseline',
      () async {
    service.dispose();
    final pending = Completer<List<SportsGame>>();
    var calls = 0;
    service = GoalsAlerts(storage,
        now: () => time,
        loadGames: (_, __) async {
          calls++;
          if (calls == 1) return pending.future;
          return games;
        });
    await storage.setGoalsAlert(true);
    final old = service.poll();
    await storage.setActiveViewerId('other');
    await storage.setGoalsAlert(true);
    await storage.setSportsFollowedTeams(['nhl|mtl']);
    service.reset();
    games = [scoreGame(time, home: '4')];
    expect(await service.poll(), isEmpty);
    pending.complete([scoreGame(time, home: '9')]);
    expect(await old, isEmpty);
    games = [scoreGame(time, home: '5')];
    final notice = (await service.poll()).single;
    expect(notice.viewerId, 'other');
    expect(notice.team.score, '5');
  });

  test('temporary feed failure retains baseline and does not replay a goal',
      () async {
    service.dispose();
    var failed = false;
    service = GoalsAlerts(storage,
        now: () => time,
        loadGames: (_, __) async {
          if (failed) throw StateError('Feed unavailable');
          return games;
        });
    await storage.setGoalsAlert(true);
    games = [scoreGame(time, home: '1')];
    expect(await service.poll(), isEmpty);
    failed = true;
    expect(await service.poll(), isEmpty);
    failed = false;
    games = [scoreGame(time, home: '2')];
    expect((await service.poll()).single.team.score, '2');
    expect(await service.poll(), isEmpty);
  });

  test('concurrent checks do not duplicate requests', () async {
    await storage.setGoalsAlert(true);
    await service.poll();
    service.dispose();
    final pending = Completer<List<SportsGame>>();
    var calls = 0;
    service = GoalsAlerts(storage,
        now: () => time,
        loadGames: (_, __) async {
          calls++;
          return pending.future;
        });
    final first = service.poll();
    expect(await service.poll(), isEmpty);
    expect(calls, 1);
    pending.complete([scoreGame(time)]);
    expect(await first, isEmpty);
  });

  test('overnight final scoring update is loaded from the live game start day',
      () async {
    service.dispose();
    time = DateTime(2026, 10, 26, 23, 59, 30);
    final start = DateTime(2026, 10, 26, 23);
    var finalGame = false;
    final days = <DateTime>[];
    service = GoalsAlerts(storage,
        now: () => time,
        loadGames: (_, day) async {
          days.add(day);
          if (finalGame && day.day == 27) return [];
          return [
            scoreGame(time,
                start: start,
                home: finalGame ? '1' : '0',
                state: finalGame ? GameState.post : GameState.live,
                status: finalGame ? 'Final' : '3rd')
          ];
        });
    await storage.setGoalsAlert(true);
    await service.poll();
    time = DateTime(2026, 10, 27, 0, 0, 30);
    finalGame = true;
    final notice = (await service.poll()).single;
    expect(notice.team.score, '1');
    expect(days, contains(DateTime(2026, 10, 26)));
  });
}
