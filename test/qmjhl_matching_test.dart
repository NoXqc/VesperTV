import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/sports_db_source.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QMJHL event channels name games by city ("QMJHL 11: Cape Breton @
/// Quebec - #519 | Fri 7th 12:00AM", owner's provider, 2026-11-09), while
/// the feed names teams ("Quebec Remparts"). Real names from that group.
void main() {
  Channel ch(String id, String name) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: 'Live | QMJHL',
      url: 'http://x/$id.ts');

  SportsTeam team(String id, String name, SportsLeague league) => SportsTeam(
      id: id,
      name: name,
      shortName: sportsDbTeamShortName(name, league),
      abbreviation: '');

  SportsGame game(String league, String home, String away, DateTime start,
      {String id = 'g1'}) {
    final l = sportsLeagueById(league)!;
    return SportsGame(
      id: id,
      league: l,
      start: start,
      state: GameState.pre,
      statusText: '',
      home: team('h', home, l),
      away: team('a', away, l),
    );
  }

  Future<(SportsChannelMatcher, SportsChannelPicks)> setUp() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    return (
      SportsChannelMatcher(EpgService(storage)),
      SportsChannelPicks.load(storage)
    );
  }

  test('QMJHL channels named by city match; other games and days do not',
      () async {
    final (matcher, picks) = await setUp();
    await matcher.prepare([
      ch('dated', 'QMJHL 11: Cape Breton @ Quebec - #519 | Fri 7th 12:00AM'),
      ch('undated', 'QMJHL 05: Cape Breton @ Quebec - #519'),
      ch('stale', 'QMJHL 30: Cape Breton @ Quebec - #600 | Fri 21st 12:00AM'),
      ch('other', 'QMJHL 00: Halifax @ Baie-Comeau - #402'),
      ch('half', 'QMJHL 19: Cape Breton @ Baie-Comeau - #525 | Sat 8th 9:00PM'),
      ch('french', 'LHJMQ: Eagles de Cape Breton c. Remparts de Québec'),
      ch('draft', 'QMJHL 07: RepÃªchage LHJMQ 2025 QMJHL Draft - 06/06/2025'),
    ]);
    final g = game('hockey.qmjhl', 'Quebec Remparts', 'Cape Breton Eagles',
        DateTime.utc(2026, 11, 7));
    final out = await matcher.matchDay([g], picks);
    final found = out[SportsChannelPicks.eventKey(g)]!;
    expect(found.map((m) => m.channel.rawId),
        unorderedEquals(['dated', 'undated', 'french']));
    expect(found.every((m) => m.reason == MatchReason.name), isTrue);
  });

  test('hyphenated and two-word cities and nicknames', () async {
    final (matcher, picks) = await setUp();
    await matcher.prepare([
      ch('a', "QMJHL 15: Gatineau @ Val-d'Or - #524 | Sat 8th 12:00AM"),
      ch('b', 'QMJHL 13: Halifax @ Saint John - #520 | Fri 7th 11:00PM'),
    ]);
    final g1 = game('hockey.qmjhl', "Val-d'Or Foreurs", 'Gatineau Olympiques',
        DateTime.utc(2026, 11, 8));
    final g2 = game('hockey.qmjhl', 'Saint John Sea Dogs', 'Halifax Mooseheads',
        DateTime.utc(2026, 11, 7, 23),
        id: 'g3');
    final out = await matcher.matchDay([g1, g2], picks);
    expect(out[SportsChannelPicks.eventKey(g1)]!.map((m) => m.channel.rawId),
        ['a']);
    expect(out[SportsChannelPicks.eventKey(g2)]!.map((m) => m.channel.rawId),
        ['b']);
  });

  test('city names stay off for leagues without cityNames', () async {
    final (matcher, picks) = await setUp();
    await matcher.prepare([ch('ahl', 'AHL 03: Belleville @ Laval')]);
    final g = game('hockey.ahl', 'Laval Rocket', 'Belleville Senators',
        DateTime.utc(2026, 11, 7));
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)] ?? const [], isEmpty);
  });

  test('"Sat 8th Nov 3:00 PM" is Nov 8, not Nov 3', () async {
    final (matcher, picks) = await setUp();
    await matcher.prepare([
      ch('cfl',
          'CA | CFL 00: Montreal Alouettes vs Hamilton Tiger-Cats | Sat 8th Nov 3:00 PM ET'),
    ]);
    final l = sportsLeagueById('cfl')!;
    final g = SportsGame(
      id: 'g2',
      league: l,
      start: DateTime.utc(2026, 11, 8, 20),
      state: GameState.pre,
      statusText: '',
      home: const SportsTeam(
          id: 'h',
          name: 'Hamilton Tiger-Cats',
          shortName: 'Tiger-Cats',
          abbreviation: 'HAM'),
      away: const SportsTeam(
          id: 'a',
          name: 'Montreal Alouettes',
          shortName: 'Alouettes',
          abbreviation: 'MTL'),
    );
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)]!.map((m) => m.channel.rawId),
        ['cfl']);
  });
}
