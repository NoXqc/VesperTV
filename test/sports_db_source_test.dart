import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/sports_db_source.dart';

void main() {
  final league = sportsLeagueById('cro.1')!;

  Map<String, Object?> event(String status,
          {String home = '1', String away = '0', String postponed = 'no'}) =>
      {
        'idEvent': '2482565',
        'strTimestamp': '2026-10-18T13:00:00',
        'dateEvent': '2026-10-18',
        'strTime': '13:00:00',
        'strHomeTeam': 'Hajduk Split',
        'strAwayTeam': 'Varaždin',
        'idHomeTeam': '134019',
        'idAwayTeam': '137798',
        'strHomeTeamBadge':
            'https://r2.thesportsdb.com/images/media/team/badge/23mvtk1579955412.png',
        'intHomeScore': home,
        'intAwayScore': away,
        'strStatus': status,
        'strPostponed': postponed,
      };

  test('the five leagues route to TheSportsDB', () {
    for (final id in ['rou.1', 'rou.2', 'cro.1', 'srb.1', 'bul.1']) {
      expect(sportsLeagueById(id)?.sportsDbId, isNotNull, reason: id);
    }
    expect(sportsLeagueById('eng.1')!.sportsDbId, isNull);
  });

  test('a finished game: UTC start, scores, home first', () {
    final games = parseSportsDbEvents((
      jsonEncode({
        'events': [event('FT')]
      }),
      league
    ));
    expect(games, hasLength(1));
    final g = games.single;
    expect(g.start, DateTime.utc(2026, 10, 18, 13));
    expect(g.state, GameState.post);
    expect(g.statusText, 'FT');
    expect(g.title, 'Hajduk Split vs Varaždin');
    expect(g.home.score, '1');
    expect(g.away.score, '0');
    expect(sportsLogoUrl(g.home.logoUrl), endsWith('.png/tiny'));
  });

  test('statuses: not started, live, postponed', () {
    GameState stateOf(Map<String, Object?> e) => parseSportsDbEvents((
          jsonEncode({
            'events': [e]
          }),
          league
        )).single.state;
    final pre = event('NS', home: '', away: '');
    expect(stateOf(pre), GameState.pre);
    expect(stateOf(event('2H')), GameState.live);
    expect(stateOf(event('NS', postponed: 'yes')), GameState.post);
  });

  test('a team\'s last game comes under "results"', () {
    final games = parseSportsDbEvents((
      jsonEncode({
        'results': [event('FT')]
      }),
      league
    ));
    expect(games, hasLength(1));
  });

  test('table rows use the soccer stat names', () {
    final table = parseSportsDbTable((
      jsonEncode({
        'table': [
          {
            'intRank': '1',
            'idTeam': '134019',
            'strTeam': 'Hajduk Split',
            'strBadge':
                'https://r2.thesportsdb.com/images/media/team/badge/23mvtk1579955412.png/tiny',
            'strSeason': '2026-2027',
            'strGroup': 'HNL',
            'strDescription': 'Promotion - Champions League (Qualification)',
            'intPlayed': '10',
            'intWin': '7',
            'intLoss': '2',
            'intDraw': '1',
            'intGoalDifference': '10',
            'intPoints': '22',
          }
        ]
      }),
      league
    ));
    expect(table.season, '2026-27');
    final group = table.groups.single;
    expect(group.name, league.name);
    final row = group.rows.single;
    expect(row.position, 1);
    expect(row.stat('points'), '22');
    expect(row.stat('ties'), '1');
    expect(row.stat('pointDifferential'), '+10');
    expect(sportsLogoUrl(row.team.logoUrl), endsWith('.png/tiny'));
  });

  test('null lists parse to nothing', () {
    expect(parseSportsDbEvents(('{"events":null}', league)), isEmpty);
    expect(parseSportsDbTable(('{"table":null}', league)).groups, isEmpty);
  });
}
