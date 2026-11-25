import 'package:flutter_test/flutter_test.dart';

import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_screen.dart';

// dajokahn (2026-11-25, LOG-5MXR4H): with All leagues, Later today listed
// tonight's NHL games first (default league order: NHL ... UCL last) and the
// nine Champions League games of the early afternoon sat far to the right.
SportsLeague _l(String id) =>
    SportsLeague(id: id, espnPath: id, name: id, shortName: id, logoUrl: '');

final _nhl = _l('nhl');
final _nba = _l('nba');
final _ucl = _l('uefa.champions');
final _leagues = [_nhl, _nba, _ucl];
final _day = DateTime(2026, 11, 25);

SportsGame _g(String id, SportsLeague league, int hour, [int minute = 0]) =>
    SportsGame(
      id: id,
      league: league,
      start: _day.add(Duration(hours: hour, minutes: minute)),
      state: GameState.pre,
      statusText: 'Scheduled',
      home: SportsTeam(
          id: 'h$id', name: 'H $id', shortName: 'H', abbreviation: 'H'),
      away: SportsTeam(
          id: 'a$id', name: 'A $id', shortName: 'A', abbreviation: 'A'),
    );

void main() {
  // Start order, as SportsService.gamesForDay returns them.
  final games = [
    _g('ucl1', _ucl, 11, 45),
    _g('ucl2', _ucl, 14),
    _g('ucl3', _ucl, 14),
    _g('nhl1', _nhl, 18),
    _g('nba1', _nba, 18, 30),
    _g('nhl2', _nhl, 19),
    _g('nba2', _nba, 21),
  ];
  List<String> ids(List<SportsGame> list) => [for (final g in list) g.id];

  test('games to come: the league starting soonest first, blocks kept', () {
    expect(ids(sportsGamesByLeague(games, _leagues, soonestFirst: true)), [
      'ucl1', 'ucl2', 'ucl3', // 11:45
      'nhl1', 'nhl2', // 18:00
      'nba1', 'nba2', // 18:30
    ]);
  });

  test('live / final rows keep the user\'s league order', () {
    expect(ids(sportsGamesByLeague(games, _leagues)),
        ['nhl1', 'nhl2', 'nba1', 'nba2', 'ucl1', 'ucl2', 'ucl3']);
  });

  test('same first start: the league order decides', () {
    final tie = [
      _g('ucl1', _ucl, 19),
      _g('nhl1', _nhl, 19),
      _g('ucl2', _ucl, 20),
    ];
    expect(ids(sportsGamesByLeague(tie, _leagues, soonestFirst: true)),
        ['nhl1', 'ucl1', 'ucl2']);
  });

  test('leagues not in the list stay in blocks', () {
    final other = _l('zzz.other');
    final mixed = [
      _g('o1', other, 10),
      _g('x1', _l('aaa.other'), 10),
      _g('o2', other, 12),
    ];
    expect(ids(sportsGamesByLeague(mixed, _leagues)), ['x1', 'o1', 'o2']);
  });
}
