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

  test('short names drop club-type words for the channel matcher', () {
    expect(sportsDbShortName('Hapoel Tel Aviv BC'), 'Hapoel Tel Aviv');
    expect(sportsDbShortName('Virtus Pallacanestro Bologna'), 'Virtus Bologna');
    expect(sportsDbShortName('Real Madrid Baloncesto'), 'Real Madrid');
    expect(sportsDbShortName('Besiktas Basketbol'), 'Besiktas');
    expect(sportsDbShortName('Hajduk Split'), 'Hajduk Split');
    // Too short once stripped: the full name.
    expect(sportsDbShortName('AEL'), 'AEL');
    expect(sportsDbShortName('FC Ae'), 'FC Ae');
  });

  test('QMJHL: TheSportsDB, nicknames for French guides, OT final', () {
    final qmjhl = sportsLeagueById('hockey.qmjhl')!;
    expect(qmjhl.sportsDbId, '5161');
    expect(qmjhl.homeTags, ['ca']);
    expect(sportsDbTeamShortName('Quebec Remparts', qmjhl), 'Remparts');
    expect(sportsDbTeamShortName('Rimouski Océanic', qmjhl), 'Océanic');
    expect(sportsDbTeamShortName('Saint John Sea Dogs', qmjhl), 'Sea Dogs');
    expect(sportsDbTeamShortName("Val-d'Or Foreurs", qmjhl), 'Foreurs');
    // Unknown team: the full name. Other leagues: unchanged.
    expect(
        sportsDbTeamShortName('Montreal Juniors', qmjhl), 'Montreal Juniors');
    expect(
        sportsDbTeamShortName('Laval Rocket', sportsLeagueById('hockey.ahl')!),
        'Laval Rocket');

    final games = parseSportsDbEvents((
      jsonEncode({
        'events': [
          {
            ...event('AOT', home: '2', away: '3'),
            'strHomeTeam': 'Rimouski Océanic',
            'strAwayTeam': 'Quebec Remparts',
          }
        ]
      }),
      qmjhl
    ));
    final g = games.single;
    expect(g.state, GameState.post);
    expect(g.statusText, 'Final/OT');
    expect(g.home.shortName, 'Océanic');
    expect(g.away.shortName, 'Remparts');
    expect(g.home.name, 'Rimouski Océanic');
  });

  test('EuroCup and the Basketball Champions League ride TheSportsDB', () {
    final eurocup = sportsLeagueById('basketball.eurocup')!;
    final bcl = sportsLeagueById('basketball.bcl')!;
    expect(eurocup.sportsDbId, '4547');
    expect(bcl.sportsDbId, '4548');
    for (final l in [eurocup, bcl]) {
      expect(l.region, 'Basketball');
      expect(l.hasStandings, isFalse);
      expect(kSportsLeagueBank.contains(l), isTrue,
          reason: 'offered in the league manager');
    }
    // A bare "champions league" would match the football competition.
    expect(bcl.seriesPhrases, isNot(contains('champions league')));
    final bank = [for (final l in kSportsLeagueBank) l.id];
    expect(bank.indexOf('basketball.eurocup'),
        bank.indexOf('basketball.euroleague') + 1);
    expect(bank.indexOf('basketball.bcl'),
        bank.indexOf('basketball.eurocup') + 1);
  });

  test('a day at the free-key cap asks for its rounds', () {
    final euroleague = sportsLeagueById('basketball.euroleague')!;
    String day(int n, {String round = '8'}) => jsonEncode({
          'events': [
            for (var i = 0; i < n; i++)
              {...event('NS'), 'intRound': round, 'strSeason': '2026-2027'}
          ]
        });
    expect(SportsDbSource.roundUrls(euroleague, day(2)), isEmpty);
    final urls = SportsDbSource.roundUrls(euroleague, day(3));
    expect(urls, hasLength(1));
    expect(urls.single.toString(),
        endsWith('eventsround.php?id=4546&r=8&s=2026-2027'));
    expect(SportsDbSource.roundUrls(euroleague, day(3, round: '0')), isEmpty);
    expect(SportsDbSource.roundUrls(euroleague, '{"events":null}'), isEmpty);
  });
}
