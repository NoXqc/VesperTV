import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/multiview_sports.dart';
import 'package:nox_iptv/services/sports_follows.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

SportsTeam _team(String id) =>
    SportsTeam(id: id, name: id, shortName: id, abbreviation: id);

LiveGameChannel _game(String id, String leagueId, GameState state, int hour,
        {String home = 'h', String away = 'a'}) =>
    (
      game: SportsGame(
        id: id,
        league: sportsLeagueById(leagueId)!,
        start: DateTime(2026, 10, 23, hour),
        state: state,
        statusText: '',
        home: _team(home),
        away: _team(away),
      ),
      matches: const [],
    );

/// Owner (2026-10-23): Home's Today's games puts My Teams first whenever
/// they play today, then the starred league, then everything else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('My Teams, then the starred league, then the rest', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyPlaylists: '[]'});
    final storage = StorageService();
    await storage.init();
    final follows = SportsFollows.load(storage);
    await follows.follow('nhl', 'mtl');

    final sorted = MultiviewSports.sortTodaysGames([
      _game('other-live', 'nba', GameState.live, 18),
      _game('star-later', 'eng.1', GameState.pre, 15),
      _game('star-live', 'eng.1', GameState.live, 12),
      _game('mine-later', 'nhl', GameState.pre, 19, away: 'mtl'),
      _game('other-later', 'nba', GameState.pre, 13),
    ], follows: follows, favoriteLeagueId: 'eng.1');

    expect([
      for (final g in sorted) g.game.id
    ], [
      'mine-later', // My Teams beats every live game
      'star-live',
      'star-later',
      'other-live',
      'other-later',
    ]);
  });

  test('a final leaves 60 min after it ended, overtime included', () {
    final start = DateTime(2026, 10, 23, 19);
    final hockey = _game('g', 'nhl', GameState.post, 19).game;
    final live = _game('l', 'nhl', GameState.live, 19).game;
    // Typical hockey length 2 h 45: ended ~21:45, gone after 22:45.
    expect(
        MultiviewSports.isExpired(hockey, DateTime(2026, 10, 23, 22, 40), null),
        isFalse);
    expect(
        MultiviewSports.isExpired(hockey, DateTime(2026, 10, 23, 22, 50), null),
        isTrue);
    // Overtime: still seen running at 22:30, so it stays until 23:30.
    final ot = start.add(const Duration(hours: 3, minutes: 30));
    expect(
        MultiviewSports.isExpired(hockey, DateTime(2026, 10, 23, 23, 20), ot),
        isFalse);
    expect(
        MultiviewSports.isExpired(hockey, DateTime(2026, 10, 23, 23, 40), ot),
        isTrue);
    // Never hides a live game.
    expect(MultiviewSports.isExpired(live, DateTime(2026, 10, 24, 3), null),
        isFalse);
  });

  test('no starred league and no teams: live, upcoming, final by time',
      () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyPlaylists: '[]'});
    final storage = StorageService();
    await storage.init();

    final sorted = MultiviewSports.sortTodaysGames([
      _game('final', 'nba', GameState.post, 10),
      _game('later', 'nba', GameState.pre, 20),
      _game('live', 'nhl', GameState.live, 19),
      _game('soon', 'nhl', GameState.pre, 18),
    ], follows: SportsFollows.load(storage));

    expect([for (final g in sorted) g.game.id],
        ['live', 'soon', 'later', 'final']);
  });
}
