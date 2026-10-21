import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ESPN lists regional games by network abbreviation or call sign ("MNMT",
/// "KJZZ-TV"); playlists use the full names. NBA user report 2026-10-21:
/// 7 of 11 games had no channel.
void main() {
  Channel ch(String id, String name) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: 'US Sports',
      url: 'http://x/$id.ts');

  SportsGame game(String id, List<String> broadcasts) => SportsGame(
        id: id,
        league: sportsLeagueById('nba')!,
        start: DateTime.now().toUtc().add(const Duration(hours: 2)),
        state: GameState.pre,
        statusText: '',
        home: SportsTeam(
            id: 'h$id',
            name: 'Home $id',
            shortName: 'Home$id',
            abbreviation: 'H$id'),
        away: SportsTeam(
            id: 'a$id',
            name: 'Away $id',
            shortName: 'Away$id',
            abbreviation: 'A$id'),
        broadcasts: broadcasts,
      );

  test("a team's own channel counts for its games", () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final matcher = SportsChannelMatcher(EpgService(storage));
    await matcher.prepare([
      ch('1', 'US - NBA TEAMS - ATLANTA HAWKS FHD'),
      ch('2', 'US - NBA TEAMS - ORLANDO MAGIC FHD'),
      ch('3', 'US - MAGIC TV'),
      ch('4', 'US - NBA TEAMS - UTAH JAZZ FHD'),
    ]);
    final g = SportsGame(
      id: 'x',
      league: sportsLeagueById('nba')!,
      start: DateTime.now().toUtc().add(const Duration(hours: 1)),
      state: GameState.pre,
      statusText: '',
      home: const SportsTeam(
          id: 'orl',
          name: 'Orlando Magic',
          shortName: 'Magic',
          abbreviation: 'ORL'),
      away: const SportsTeam(
          id: 'atl',
          name: 'Atlanta Hawks',
          shortName: 'Hawks',
          abbreviation: 'ATL'),
      broadcasts: const ['NBA League Pass'],
    );
    final out = await matcher.matchDay([g], SportsChannelPicks.load(storage));
    final ids =
        out[SportsChannelPicks.eventKey(g)]!.map((m) => m.channel.rawId);
    expect(ids, containsAll(['1', '2']));
    expect(ids, isNot(contains('3')));
    expect(ids, isNot(contains('4')));
  });

  test('regional networks and call signs find their channels', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final matcher = SportsChannelMatcher(EpgService(storage));
    await matcher.prepare([
      ch('1', 'US - MONUMENTAL SPORTS NETWORK HD'),
      ch('2', 'US - NBC SPORTS CALIFORNIA HD'),
      ch('3', 'US - KJZZ 14 SALT LAKE CITY (KJZZ) HD'),
      ch('4', 'US - KFAA 29 DALLAS HD'),
      ch('5', 'US: Bally Sports Southwest'),
      ch('6', 'US - ESPN FHD'),
      ch('7', 'RU - MONUMENTAL SPORTS'),
    ]);
    final games = [
      game('1', ['MNMT', 'NBA League Pass', 'Bucks App']),
      game('2', ['NBA League Pass', 'NBC Sports CA']),
      game('3', ['KJZZ-TV', 'Jazz+']),
      game('4', ['KFAA-TV', 'MavsTV']),
      game('5', ['FDSSW']),
      game('6', ['ESPN']),
    ];
    final out = await matcher.matchDay(games, SportsChannelPicks.load(storage));
    String? best(String id) =>
        out[SportsChannelPicks.eventKey(games[int.parse(id) - 1])]
            ?.firstOrNull
            ?.channel
            .rawId;
    expect(best('1'), '1');
    expect(best('2'), '2');
    expect(best('3'), '3');
    expect(best('4'), '4');
    expect(best('5'), '5');
    expect(best('6'), '6');
    // A foreign channel with the same name is never offered.
    final g1 = out[SportsChannelPicks.eventKey(games[0])]!;
    expect(g1.map((m) => m.channel.rawId), isNot(contains('7')));
  });
}
