import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_standings_screen.dart';
import 'package:nox_iptv/services/sports_service.dart';

/// ESPN cricket scorepanel shape (checked 2026-11-19): `scores[]` = one per
/// series, each with its `leagues[0]` and `events[]`.
Map<String, dynamic> _match({
  required String id,
  required DateTime start,
  required DateTime end,
  required String classId,
  required String eventType,
  required String state,
  String description = 'Live',
  String? session,
  String? summary,
  String home = 'New Zealand',
  String away = 'India',
  String homeScore = '243/5 (82 ov)',
  String awayScore = '',
}) {
  Map<String, dynamic> side(String name, String code, String ha, String s) => {
        'id': code,
        'homeAway': ha,
        'score': s,
        // Cricket links its leaders instead of listing them.
        'leaders': {r'$ref': 'http://new.core.espnuk.org/v2/leaders'},
        'team': {
          'id': code,
          'name': name,
          'displayName': name,
          'shortDisplayName': code,
          'abbreviation': code,
          'logo': 'https://a.espncdn.com/i/teamlogos/cricket/500/$code.png',
        },
      };
  final status = {
    if (session != null) 'session': session,
    if (summary != null) 'summary': summary,
    'type': {
      'state': state,
      'description': description,
      'shortDetail': state == 'post' ? 'Final' : 'Live',
    },
  };
  return {
    'id': id,
    'date': start.toUtc().toIso8601String(),
    'endDate': end.toUtc().toIso8601String(),
    'status': status,
    'competitions': [
      {
        'date': start.toUtc().toIso8601String(),
        'endDate': end.toUtc().toIso8601String(),
        'class': {'internationalClassId': classId, 'eventType': eventType},
        'status': status,
        'competitors': [
          side(home, 'NZ', 'home', homeScore),
          side(away, 'IND', 'away', awayScore),
        ],
      }
    ],
  };
}

String _panel(DateTime day) => jsonEncode({
      'scores': [
        {
          'leagues': [
            {'id': '24469', 'name': 'India tour of New Zealand'}
          ],
          'events': [
            // Day 3 of a Test that started two days earlier.
            _match(
              id: 'test-live',
              start: day.subtract(const Duration(days: 2)),
              end: day.add(const Duration(days: 2)),
              classId: '1',
              eventType: 'Test',
              state: 'in',
              description: 'Stumps',
              session: 'Day 3',
              homeScore: '98 & 285/8 (86 ov)',
              awayScore: '325',
            ),
            // A Test that ended early: shown on its first day only.
            _match(
              id: 'test-done',
              start: day.subtract(const Duration(days: 3)),
              end: day.add(const Duration(days: 1)),
              classId: '1',
              eventType: 'Test',
              state: 'post',
              summary: 'New Zealand won by 9 wkts',
            ),
            _match(
              id: 'odi',
              start: day.add(const Duration(hours: 10)),
              end: day.add(const Duration(days: 2)),
              classId: '2',
              eventType: 'ODI',
              state: 'pre',
              homeScore: '',
            ),
          ],
        },
        {
          'leagues': [
            {'id': '1', 'name': 'ICC Women\'s Emerging Nations Trophy'}
          ],
          'events': [
            _match(
              id: 'women-t20i',
              start: day.add(const Duration(hours: 9)),
              end: day.add(const Duration(hours: 23)),
              classId: '10',
              eventType: '',
              state: 'pre',
              home: 'Ireland Women',
              away: 'Netherlands Women',
            ),
          ],
        },
        {
          'leagues': [
            {'id': '8828', 'name': 'Plunket Shield'}
          ],
          'events': [
            _match(
              id: 'domestic',
              start: day.add(const Duration(hours: 8)),
              end: day.add(const Duration(days: 3)),
              classId: '0',
              eventType: 'Test',
              state: 'in',
              home: 'Otago',
              away: 'Canterbury',
            ),
          ],
        },
      ],
    });

void main() {
  final men = sportsLeagueById('cricket.international')!;
  final women = sportsLeagueById('cricket.international-women')!;
  final day = DateTime(2030, 1, 10);

  test('international cricket leagues are in the Cricket bank group', () {
    for (final l in [men, women]) {
      expect(l.region, 'Cricket');
      expect(l.hasStandings, isFalse);
      expect(l.homeFirst, isTrue);
      expect(l.sportsDbId, isNull);
    }
    expect(men.cricketInternational, CricketInternational.men);
    expect(women.cricketInternational, CricketInternational.women);
  });

  test('men keep Tests / ODIs / T20Is, women the rest, domestic neither', () {
    final body = _panel(day);
    final menIds = [
      for (final g in parseEspnScoreboard((body, men))) g.id,
    ];
    final womenIds = [
      for (final g in parseEspnScoreboard((body, women))) g.id,
    ];
    expect(menIds, ['test-live', 'test-done', 'odi']);
    expect(womenIds, ['women-t20i']);
  });

  test('scores, names, status and the last day of a Test', () {
    final games = {
      for (final g in parseEspnScoreboard((_panel(day), men))) g.id: g,
    };
    final live = games['test-live']!;
    expect(live.state, GameState.live);
    expect(live.statusText, 'Day 3 · Stumps');
    expect(live.home.score, '98 & 285/8');
    expect(live.away.score, '325');
    expect(live.home.shortName, 'New Zealand');
    expect(live.home.abbreviation, 'NZ');
    expect(live.lastDay, isNotNull);
    expect(live.end, isNull, reason: 'end makes a card read like golf');

    final done = games['test-done']!;
    expect(done.statusText, 'New Zealand won by 9 wkts');
    expect(done.lastDay, isNull);

    expect(games['odi']!.lastDay, isNull, reason: 'one-day match');
  });

  test('a Test being played shows on each of its days', () async {
    final asked = <Uri>[];
    final client = MockClient((r) async {
      asked.add(r.url);
      return http.Response(_panel(day), 200);
    });
    final service = SportsService.forTesting(client);
    final ids = [
      for (final g in await service.gamesForDay([men], day)) g.id
    ];
    expect(ids, containsAll(['test-live', 'odi']));
    expect(ids, isNot(contains('test-done')));
    expect(ids, isNot(contains('domestic')));
    expect(asked, isNotEmpty);
    expect(asked.every((u) => u.path.endsWith('/cricket/scorepanel')), isTrue);
    expect(asked.every((u) => u.queryParameters.containsKey('dates')), isTrue);
  });

  test('no stats request and no next-game request', () async {
    var requests = 0;
    final service = SportsService.forTesting(MockClient((r) async {
      requests++;
      return http.Response('{}', 404);
    }));
    final game = parseEspnScoreboard((_panel(day), men)).first;
    final summary = await service.gameSummary(game);
    expect(summary, isNotNull);
    expect(await service.nextGameStart(men, day), isNull);
    expect(await service.teamSchedule(men, 'NZ'), isNull);
    expect(requests, 0);
  });

  test('the T20 leagues are ESPN leagues with tables, no team schedules', () {
    const ids = {
      'cricket.ipl': 'cricket/8048',
      'cricket.bbl': 'cricket/8044',
      'cricket.psl': 'cricket/8679',
      'cricket.sa20': 'cricket/21275',
      'cricket.cpl': 'cricket/8623',
      'cricket.t20-blast': 'cricket/8053',
    };
    ids.forEach((id, path) {
      final l = sportsLeagueById(id)!;
      expect(l.espnPath, path, reason: id);
      expect(l.sportsDbId, isNull, reason: id);
      expect(l.hasStandings, isTrue, reason: id);
      expect(l.hasTeamSchedules, isFalse, reason: id);
      expect(l.cricketInternational, isNull, reason: id);
    });
    expect(sportsLeagueById('nhl')!.hasTeamSchedules, isTrue);
  });

  test('a league scoreboard reads like the scorepanel', () {
    final ipl = sportsLeagueById('cricket.ipl')!;
    final body = jsonEncode({
      'events': [
        _match(
          id: '1',
          start: day.add(const Duration(hours: 14)),
          end: day.add(const Duration(days: 1)),
          classId: '0',
          eventType: 'T20',
          state: 'post',
          summary: 'Royal Challengers won by 5 wkts',
          home: 'Gujarat Titans',
          away: 'Royal Challengers Bengaluru',
          homeScore: '156',
          awayScore: '161/5 (19.2/20 ov, target 157)',
        ),
        // An off-season scoreboard lists an empty event.
        <String, dynamic>{},
      ],
    });
    final game = parseEspnScoreboard((body, ipl)).single;
    expect(game.state, GameState.post);
    expect(game.first.name, 'Gujarat Titans');
    expect(game.first.score, '156');
    expect(game.second.score, '161/5');
    expect(game.statusText, 'Royal Challengers won by 5 wkts');
    expect(game.lastDay, isNull);
  });

  test('cricket tables: ESPN rank order, no Cross Pool, cricket columns', () {
    final bbl = sportsLeagueById('cricket.bbl')!;
    Map<String, dynamic> row(String name, int rank, int pts) => {
          'team': {'id': name, 'displayName': name, 'abbreviation': name},
          'stats': [
            {'name': 'rank', 'displayValue': '$rank'},
            {'name': 'matchesPlayed', 'displayValue': '3'},
            {'name': 'matchesWon', 'displayValue': '2'},
            {'name': 'matchPoints', 'displayValue': '$pts'},
          ],
        };
    final body = jsonEncode({
      'name': 'Big Bash League',
      'children': [
        {
          'name': '',
          'standings': {
            'entries': [row('Heat', 2, 4), row('Strikers', 1, 6)],
          },
        },
        {
          'name': 'Cross Pool',
          'standings': {
            'entries': [row('Heat', 1, 4)],
          },
        },
      ],
    });
    final table = parseEspnStandings((body, bbl));
    expect(table.groups.length, 1);
    expect(table.groups.single.name, 'Big Bash League');
    expect([for (final r in table.groups.single.rows) r.team.name],
        ['Strikers', 'Heat']);
    expect([for (final c in sportsStandingColumns(bbl)) c.stat],
        containsAll(['matchesPlayed', 'matchesWon', 'matchPoints']));
  });
}
