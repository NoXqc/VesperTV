import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Event channels named in team codes, with no guide ("B01: 7pm CHA @ DET",
/// "FB01 : 8:15 DAL @ PHI"; user report 2026-10-28). Times are Eastern.
void main() {
  Channel ch(String id, String name) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: 'Events',
      url: 'http://x/$id.ts');

  SportsTeam team(String abbr) => SportsTeam(
      id: abbr, name: 'Team $abbr', shortName: abbr, abbreviation: abbr);

  SportsGame game(String league, String away, String home, DateTime start) =>
      SportsGame(
        id: '$away$home',
        league: sportsLeagueById(league)!,
        start: start,
        state: GameState.pre,
        statusText: '',
        home: team(home),
        away: team(away),
        broadcasts: const [],
      );

  Future<Map<String, List<String>>> match(
      List<Channel> channels, List<SportsGame> games) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final matcher = SportsChannelMatcher(EpgService(storage));
    await matcher.prepare(channels);
    final out = await matcher.matchDay(games, SportsChannelPicks.load(storage));
    return {
      for (final g in games)
        '${g.league.id}:${g.away.abbreviation}@${g.home.abbreviation}': [
          for (final m in out[SportsChannelPicks.eventKey(g)] ?? const [])
            m.channel.rawId
        ]
    };
  }

  final channels = [
    ch('b01', 'B01: 7pm CHA @ DET'),
    ch('b02', 'B02: 7pm WAS @ CLE'),
    ch('b05', 'B05: 7:30pm ORL @ TOR'),
    ch('fb01', 'FB01 : 8:15 DAL @ PHI'),
    ch('h01', 'H01: 7pm DET @ TOR'),
  ];

  // 2026-10-28 is daylight time: 7pm EDT = 23:00 UTC.
  test('codes + Eastern time find the event channel', () async {
    final out = await match(channels, [
      game('nba', 'CHA', 'DET', DateTime.utc(2026, 10, 28, 23)),
      game('nba', 'WSH', 'CLE', DateTime.utc(2026, 10, 28, 23)),
      game('nba', 'ORL', 'TOR', DateTime.utc(2026, 10, 28, 23, 30)),
    ]);
    expect(out['nba:CHA@DET'], ['b01']);
    expect(out['nba:WSH@CLE'], ['b02']); // ESPN's WSH = provider's WAS
    expect(out['nba:ORL@TOR'], ['b05']);
  });

  test('standard time in winter', () async {
    // 8:15pm EST = 01:15 UTC the next day.
    final out = await match(channels,
        [game('nfl', 'DAL', 'PHI', DateTime.utc(2026, 12, 7, 1, 15))]);
    expect(out['nfl:DAL@PHI'], ['fb01']);
  });

  test('wrong time, reversed teams or another sport are not matched', () async {
    final out = await match(channels, [
      // Same codes, other time (another sport's DET @ TOR is 7pm).
      game('nba', 'DET', 'TOR', DateTime.utc(2026, 10, 28, 23, 30)),
      // Home and away swapped on an "@" channel.
      game('nba', 'DET', 'CHA', DateTime.utc(2026, 10, 28, 23)),
    ]);
    expect(out['nba:DET@TOR'], isEmpty);
    expect(out['nba:DET@CHA'], isEmpty);
  });

  test("a sport-named group must be the game's sport", () async {
    Channel inGroup(String id, String name, String group) => Channel(
        id: 'p::$id',
        rawId: id,
        playlistId: 'p',
        name: name,
        group: group,
        url: 'http://x/$id.ts');
    final start = DateTime.utc(2026, 10, 28, 23);
    final out = await match([
      inGroup('hockey', 'H01: 7pm DET @ TOR', 'Hockey'),
      inGroup('hoops', 'B09: 7pm DET @ TOR', 'NBA Basketball'),
      inGroup('mlb', 'BB01: 7pm DET @ TOR', 'Baseball Playoffs'),
    ], [
      game('nba', 'DET', 'TOR', start),
      game('nhl', 'DET', 'TOR', start),
    ]);
    expect(out['nba:DET@TOR'], ['hoops']);
    expect(out['nhl:DET@TOR'], ['hockey']);
  });
}
