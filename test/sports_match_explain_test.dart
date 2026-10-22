import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Matching audit (dev-notes/sports-matcher-audit, 2026-10-21): strict US
/// network names, an index that notices a renamed channel, and a reason for
/// every game left without a channel.
void main() {
  Channel ch(String id, String name) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: 'US Sports',
      url: 'http://x/$id.ts');

  SportsGame game(
          {List<String> broadcasts = const [],
          String home = 'Buffalo Bills',
          String away = 'Las Vegas Raiders',
          String league = 'nfl',
          DateTime? start}) =>
      SportsGame(
        id: 'g1',
        league: sportsLeagueById(league)!,
        start: start ?? DateTime.now().toUtc().add(const Duration(hours: 2)),
        state: GameState.pre,
        statusText: '',
        home: SportsTeam(
            id: 'h',
            name: home,
            shortName: home.split(' ').last,
            abbreviation: 'H'),
        away: SportsTeam(
            id: 'a',
            name: away,
            shortName: away.split(' ').last,
            abbreviation: 'A'),
        broadcasts: broadcasts,
      );

  Future<(SportsChannelMatcher, SportsChannelPicks)> setUp() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    return (
      SportsChannelMatcher(EpgService(storage)),
      SportsChannelPicks.load(storage)
    );
  }

  test('schedule labels find only the exact US network', () async {
    final (matcher, picks) = await setUp();
    await matcher.prepare([
      ch('us', 'US - CBS SPORTS NETWORK HD'),
      ch('ru', 'RU - CBS SPORTS NETWORK HD'),
      ch('ca', 'CA - USA NETWORK CANADA HD'),
      ch('usa', 'US - USA NETWORK EAST HD'),
      ch('west', 'US - USA NETWORK WEST HD'),
      ch('nfl', 'US - NFL NETWORK HD'),
      ch('dated', 'US - NFL Network: Bulls vs Knicks 2026-10-23'),
      ch('phil', 'US - NBC SPORTS PHILADELPHIA HD'),
      ch('plus', 'US - NBC SPORTS PHILADELPHIA PLUS HD'),
    ]);
    final g = game(
        broadcasts: const ['CBSSN', 'USA Net', 'NBC Sports Phil', 'NFL Net']);
    final out = await matcher.matchDay([g], picks);
    final found = out[SportsChannelPicks.eventKey(g)]!;
    expect(found.map((m) => m.channel.rawId).toSet(),
        {'us', 'usa', 'nfl', 'phil'});
    expect(found.every((m) => m.reason == MatchReason.network), isTrue);
  });

  test('a channel renamed in the middle of the list is re-indexed', () async {
    final (matcher, picks) = await setUp();
    final g = game();
    await matcher.prepare([
      ch('1', 'US - ESPN'),
      ch('2', 'NFL 01 - Something else'),
      ch('3', 'US - TNT'),
    ]);
    expect((await matcher.matchDay([g], picks))[SportsChannelPicks.eventKey(g)],
        isEmpty);
    await matcher.prepare([
      ch('1', 'US - ESPN'),
      ch('2', 'NFL 01 - Raiders @ Bills'),
      ch('3', 'US - TNT'),
    ]);
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)]!.map((m) => m.channel.rawId),
        ['2']);
    expect(matcher.whyNoMatch(g), isNull);
  });

  test('a game only on a hidden channel says so', () async {
    final (matcher, picks) = await setUp();
    final g = game();
    await matcher.prepare([ch('1', 'US - ESPN')],
        hidden: [ch('2', 'NFL 01 - Raiders @ Bills')]);
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)], isEmpty);
    final why = matcher.whyNoMatch(g)!;
    expect(why.cause, NoMatchCause.hiddenChannel);
    expect(why.channelName, 'NFL 01 - Raiders @ Bills');
  });

  test('a game nothing names gets the plain reason', () async {
    final (matcher, picks) = await setUp();
    final g = game();
    await matcher.prepare([ch('1', 'US - ESPN')],
        hidden: [ch('2', 'NFL 02 - Chiefs @ Broncos')]);
    await matcher.matchDay([g], picks);
    expect(matcher.whyNoMatch(g)!.cause, NoMatchCause.notFound);
  });

  test("team channels say they aren't from the guide", () async {
    final (matcher, picks) = await setUp();
    final g = game();
    await matcher.prepare([ch('1', 'US - NFL TEAMS - BUFFALO BILLS FHD')]);
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)]!.single.reason,
        MatchReason.teamChannel);
  });

  test('old one-team event feeds cannot bypass the event date guard', () async {
    final (matcher, picks) = await setUp();
    final g = game(start: DateTime.utc(2026, 10, 23, 23));
    await matcher.prepare([
      ch('old', 'US - NFL - Buffalo Bills vs Miami Dolphins Oct 18'),
      ch('iso', 'US - NFL - Buffalo Bills vs Miami Dolphins 2026-10-18'),
      ch('team', 'US - NFL TEAMS - BUFFALO BILLS FHD'),
      ch('current', 'US - NFL - Buffalo Bills Oct 23rd'),
    ]);
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)]!.map((m) => m.channel.rawId),
        unorderedEquals(['team', 'current']));
  });

  test('CFL November ordinal event names are not October team feeds', () async {
    final (matcher, picks) = await setUp();
    final g = game(
        league: 'cfl',
        home: 'Toronto Argonauts',
        away: 'Montreal Alouettes',
        start: DateTime.utc(2026, 10, 23, 23));
    await matcher.prepare([
      ch('old',
          'CA | CFL 00: Montreal Alouettes vs Hamilton Tiger-Cats | Sat 8th Nov 3:00 PM ET'),
      ch('oldBoth', 'CA | CFL Montreal Alouettes vs Toronto Argonauts Nov 8th'),
      ch('current',
          'CA | CFL Montreal Alouettes vs Toronto Argonauts 23rd Oct'),
    ]);
    final out = await matcher.matchDay([g], picks);
    expect(out[SportsChannelPicks.eventKey(g)]!.map((m) => m.channel.rawId),
        ['current']);
    expect(
        out[SportsChannelPicks.eventKey(g)]!.single.reason, MatchReason.name);
  });
}
