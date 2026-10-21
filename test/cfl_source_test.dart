import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_standings_screen.dart';
import 'package:nox_iptv/services/cfl_source.dart';
import 'package:nox_iptv/services/sports_service.dart';

// Shapes/ids from the public CFL feeds, checked 2026-10-21. Quarter
// statuses below come from CFL's client; no game was live on that date.
const metadata = [
  {
    'ID': 19,
    'name': 'Argonauts',
    'abbreviation': 'TOR',
    'primary_color': '0C2340',
    'genius': {'id': 122345},
  },
  {
    'ID': 11,
    'name': 'Alouettes',
    'abbreviation': 'MTL',
    'primary_color': '00205B',
    'genius': {'id': 86680},
  },
];

Map<String, Object?> match(
  String status, {
  int id = 13419751,
  String date = '2026-10-23T19:00:00-04:00',
  int home = 23,
  int away = 24,
  bool hidden = false,
}) =>
    {
      'id': id,
      'date': date,
      'status': status,
      'homeSquad': {
        'id': 122345,
        'name': 'Toronto Argonauts',
        'shortName': 'TOR',
        'score': home
      },
      'awaySquad': {
        'id': 86680,
        'name': 'Montreal Alouettes',
        'shortName': 'MTL',
        'score': away
      },
      'activePeriod': null,
      'clock': '08:12',
      'possession': 'Away',
      'isHidden': hidden,
    };

String rounds(List<Map<String, Object?>> games, {String type = 'REG'}) =>
    jsonEncode([
      {'type': type, 'tournaments': games}
    ]);

CflSeason parse(List<Map<String, Object?>> games, {String type = 'REG'}) =>
    parseCflSeason((rounds(games, type: type), jsonEncode(metadata)));

Map<String, Object?> standing(String abbr, int rank) => {
      // Stats ids differ from scoreboard ids: abbreviation joins them.
      'team_id': abbr == 'TOR' ? 19 : 11,
      'abbreviation': abbr, 'place': rank == 1 ? 2 : 1, 'place_override': rank,
      'season': 2026, 'games_played': 17,
      'wins': 9, 'losses': 8, 'ties': 0, 'points': 18,
      'winning_percentage': 0.5294, 'points_for': 501, 'points_against': 495,
      'home_wins': 4, 'home_losses': 1, 'home_ties': 0,
      'away_wins': 5, 'away_losses': 7, 'away_ties': 0,
    };

String table() => jsonEncode({
      'data': {
        'divisions': {
          'east': {
            'standings': [standing('TOR', 2), standing('MTL', 1)]
          },
          'unified': {
            'standings': [standing('TOR', 2), standing('MTL', 1)]
          },
        }
      }
    });

void main() {
  test('CFL is a main/default league with Canadian channel preference', () {
    final league = sportsLeagueById('cfl')!;
    expect(kSportsLeagues, contains(league));
    expect(kDefaultSportsLeagueIds, contains('cfl'));
    expect(kSportsLeagueBank, isNot(contains(league)));
    expect(league.isCfl, isTrue);
    expect(league.homeTags, ['ca']);
    expect(
        sportsStandingColumns(league).map((c) => c.stat), contains('points'));
  });

  test('UTC start, full names, nickname, identity and unstarted scores', () {
    final game = parse([match('scheduled', home: 0, away: 0)]).games.single;
    expect(game.start, DateTime.utc(2026, 10, 23, 23));
    expect(game.state, GameState.pre);
    expect(game.home.id, 'TOR');
    expect(game.home.name, 'Toronto Argonauts');
    expect(game.home.shortName, 'Argonauts');
    expect(game.away.id, 'MTL');
    expect(game.title, 'Alouettes at Argonauts');
    expect(game.home.score, isNull);
    expect(game.home.logoUrl, endsWith('/media/squads/122345.png'));
    expect(game.home.color, '0C2340');
  });

  test('every CFL quarter, halftime and overtime is live', () {
    final statuses = {
      'first_quarter': '08:12 - 1st',
      'second_quarter': '08:12 - 2nd',
      'third_quarter': '08:12 - 3rd',
      'fourth_quarter': '08:12 - 4th',
      'half_time': 'Halftime',
      'overtime': '08:12 - OT',
    };
    for (final entry in statuses.entries) {
      final game = parse([match(entry.key)]).games.single;
      expect(game.state, GameState.live, reason: entry.key);
      expect(game.statusText, entry.value);
      expect(game.home.score, '23');
      expect(game.away.score, '24');
      expect(game.situation?.possessionTeamId, 'MTL');
    }
    expect(parse([match('pre_match')]).games.single.state, GameState.pre);
  });

  test('final/zero/tied scores and REG-only records (no pre/postseason)', () {
    final body = jsonEncode([
      {
        'type': 'PRE',
        'tournaments': [match('complete', id: 1, home: 55)]
      },
      {
        'type': 'REG',
        'tournaments': [
          match('complete', id: 2, home: 0),
          match('complete', id: 3, home: 24),
          match('complete', id: 4, home: 25),
        ]
      },
      {
        'type': 'POST',
        'tournaments': [match('complete', id: 5, home: 55)]
      },
    ]);
    final season = parseCflSeason((body, jsonEncode(metadata)));
    expect(season.teams['TOR']!.record, '1-1-1');
    expect(season.teams['TOR']!.score, isNull);
    final shutout = season.games.firstWhere((g) => g.id == '2');
    expect(shutout.state, GameState.post);
    expect(shutout.statusText, 'Final');
    expect(shutout.home.score, '0');
  });

  test('hidden scores, cancellations, placeholders and malformed games', () {
    final placeholder = match('scheduled', id: 2)
      ..['awaySquad'] = {'id': 0, 'name': 'TBD', 'shortName': 'TBD'};
    final game = parse([
      match('second_quarter', hidden: true),
      placeholder,
      {...match('scheduled', id: 3), 'date': 'bad-date'},
    ]).games.single;
    expect(game.state, GameState.live);
    expect(game.home.score, isNull);
    expect(game.situation, isNull);
    expect(game.statusText, 'Score unavailable');
    final cancelled = parse([match('canceled')]).games.single;
    expect(cancelled.state, GameState.post);
    expect(cancelled.home.score, isNull);
    expect(cancelled.statusText, 'Canceled');
  });

  test('official ranking and cross-source team identity survive standings', () {
    final season = parse([match('scheduled')]);
    final standings = parseCflStandings((table(), season));
    expect(standings.season, '2026');
    final division = standings.groups.single;
    expect(division.name, 'East Division');
    expect(division.rows.map((r) => r.team.id), ['MTL', 'TOR']);
    final tor = division.rows.last;
    expect(tor.team.id, season.games.single.home.id);
    expect(tor.stat('points'), '18');
    expect(tor.stat('pointDifferential'), '+6');
    expect(tor.stat('winPercent'), '0.529');
    expect(tor.stat('Home'), '4-1');
  });

  test('invalid shapes throw rather than replace cached season with empty data',
      () {
    expect(() => parseCflSeason(('{}', '[]')), throwsFormatException);
    expect(() => parseCflSeason(('[]', '[]')), throwsFormatException);
    expect(() => parseCflStandings(('{}', parse([match('complete')]))),
        throwsFormatException);
    expect(
        () => parseCflStandings(
            ('{"data":{"divisions":{}}}', parse([match('complete')]))),
        throwsFormatException);
  });

  test('shared requests, live freshness, failed refresh and offseason season',
      () async {
    var now = DateTime.utc(2027, 1, 1);
    var roundCalls = 0;
    var teamCalls = 0;
    var fail = false;
    final client = MockClient((request) async {
      if (request.url == CflSource.roundsUrl) {
        roundCalls++;
        if (fail) return http.Response('failed', 503);
        return http.Response(rounds([match('second_quarter')]), 200);
      }
      if (request.url == CflSource.teamsUrl) {
        teamCalls++;
        return http.Response(jsonEncode(metadata), 200);
      }
      expect(request.url.toString(), 'https://api.stats.cfl.ca/standings/2026');
      return http.Response(table(), 200);
    });
    addTearDown(client.close);
    final source = CflSource(client, now: () => now);
    await Future.wait([source.games(), source.games()]);
    final schedule = await source.teamSchedule('TOR');
    expect(schedule!.games.single.home.id, schedule.team.id);
    expect(await source.teamSchedule('unknown'), isNull);
    expect(roundCalls, 1);
    expect(teamCalls, 1);
    now = now.add(const Duration(seconds: 51));
    await source.games();
    expect(roundCalls, 2);
    expect(teamCalls, 1);
    await source.standings();
    now = now.add(const Duration(seconds: 51));
    fail = true;
    await expectLater(source.games(), throwsException);
    expect(source.cachedGames.single.state, GameState.live);
  });

  test('new feed messages have every supported translation', () async {
    final previous = L10n.setting;
    addTearDown(() => L10n.apply(previous));
    for (final language in ['fr', 'es', 'it', 'el']) {
      await L10n.apply(language);
      for (final label in [
        'East Division',
        'West Division',
        'Score unavailable'
      ]) {
        expect(tr(label), isNot(label), reason: '$language: $label');
      }
      expect(trSports('Score unavailable'), tr('Score unavailable'));
    }
  });

  test('SportsService routes every CFL feature without an ESPN request',
      () async {
    final day = DateTime(2026, 10, 23);
    final first = DateTime(2026, 10, 23, 19).toUtc();
    final second = DateTime(2026, 10, 24, 19).toUtc();
    var roundCalls = 0;
    var statsCalls = 0;
    final statsUrls = <Uri>[];
    final client = MockClient((request) async {
      if (request.url.host == 'gsm-widgets.betstream.betgenius.com') {
        statsCalls++;
        statsUrls.add(request.url);
        if (request.url.path.contains('/teamStats/')) {
          return http.Response(
              jsonEncode({
                'data': {
                  'status': {'status': 'AVAILABLE'},
                  'details': {
                    'stats': [
                      {
                        'id': 'passing_detailed',
                        'away': [262],
                        'home': [324]
                      }
                    ]
                  }
                }
              }),
              200);
        }
        return http.Response('failed', 503); // Optional player feed failure.
      }
      if (request.url == CflSource.roundsUrl) {
        roundCalls++;
        return http.Response(
            rounds([
              match('scheduled', date: first.toIso8601String()),
              match('scheduled', id: 2, date: second.toIso8601String()),
            ]),
            200);
      }
      if (request.url == CflSource.teamsUrl) {
        return http.Response(jsonEncode(metadata), 200);
      }
      expect(request.url.toString(), 'https://api.stats.cfl.ca/standings/2026');
      return http.Response(table(), 200);
    });
    addTearDown(client.close);
    final service = SportsService.forTesting(client);
    final league = sportsLeagueById('cfl')!;
    final dayGames = await service.gamesForDay([league], day);
    expect(dayGames, hasLength(1));
    expect(dayGames.single.start, first);
    expect(await service.nextGameStart(league, day), first.toLocal());
    expect((await service.standings(league))!.groups.single.rows, hasLength(2));
    expect((await service.teamSchedule(league, 'TOR'))!.games, hasLength(2));
    final summary = await service.gameSummary(dayGames.single);
    expect(summary!.tables.single.labels, ['GP', 'W', 'L', 'T', 'PTS']);
    expect(summary.tables.single.rows.map((r) => r.$1), ['MTL', 'TOR']);
    expect(summary.teamStats.single, ('Passing yards', '262', '324'));
    await service.gameSummary(dayGames.single);
    expect(statsCalls, 2); // Two optional feeds, shared/cached per game.
    expect(statsUrls.map((u) => u.queryParameters['fixtureId']),
        everyElement(dayGames.single.id));
    expect(
        statsUrls.map((u) => u.path),
        containsAll([
          '/v1/widget/teamStats/customer/democfl_light/locale/en-US/geolocale/any-',
          '/v1/widget/playerStats/customer/democfl_light/locale/en-US/geolocale/any-',
        ]));
    final game = dayGames.single;
    final hidden = SportsGame(
        id: game.id,
        league: game.league,
        start: game.start,
        state: game.state,
        statusText: 'Score unavailable',
        home: game.home,
        away: game.away);
    expect((await service.gameSummary(hidden))!.teamStats, isEmpty);
    expect(statsCalls, 2); // Hidden stats cannot leak from the populated cache.
    expect(roundCalls, 1);
    expect(service.lastError, isNull);
  });

  test('a scheduled season switches to frequent refresh near kickoff',
      () async {
    var now = DateTime.utc(2026, 10, 23, 21);
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url == CflSource.teamsUrl) {
        return http.Response(jsonEncode(metadata), 200);
      }
      calls++;
      return http.Response(rounds([match('scheduled')]), 200);
    });
    addTearDown(client.close);
    final source = CflSource(client, now: () => now);
    await source.games();
    now = now.add(const Duration(minutes: 5));
    await source.games();
    expect(calls, 1);
    now = DateTime.utc(2026, 10, 23, 22, 45);
    await source.games();
    expect(calls, 2);
    now = now.add(const Duration(seconds: 20));
    await source.games();
    expect(calls, 2);
    now = now.add(const Duration(seconds: 31));
    await source.games();
    expect(calls, 3);
  });
}
