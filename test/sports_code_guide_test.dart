import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'handoff_sports_regression_test.dart' show channel;

/// Guides that write a game only in team codes ("NBA: TOR @ BOS"; GiladG2,
/// Discord 2026-11-18).
class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  List<String> asked = const [];
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
      DateTime from, DateTime to, List<String> terms) async {
    asked = terms;
    return programmes;
  }

  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  final start = DateTime.now().toUtc().add(const Duration(hours: 2));
  final game = SportsGame(
    id: 'g1',
    league: sportsLeagueById('nba')!,
    start: start,
    state: GameState.pre,
    statusText: '',
    home: const SportsTeam(
        id: 'bos',
        name: 'Boston Celtics',
        shortName: 'Celtics',
        abbreviation: 'BOS'),
    away: const SportsTeam(
        id: 'tor',
        name: 'Toronto Raptors',
        shortName: 'Raptors',
        abbreviation: 'TOR'),
  );

  EpgProgram on(String id, String title) => EpgProgram(
      channelId: id,
      title: title,
      start: start,
      stop: start.add(const Duration(hours: 3)));

  test('a guide title in team codes finds the game', () async {
    final a = channel('a', 'US: Sports 1');
    final b = channel('b', 'US: Sports 2');
    final c = channel('c', 'US: Sports 3');
    final epg = _Guide(storage, [
      on(a.rawId, 'NBA: TOR @ BOS'),
      on(b.rawId, 'NBA Basketball: BOS vs. TOR'),
      // One code of this game only: another game.
      on(c.rawId, 'NBA: TOR @ NYK'),
    ]);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([a, b, c]);
    final out =
        await matcher.matchDay([game], SportsChannelPicks.load(storage));
    final found = out[SportsChannelPicks.eventKey(game)]!;
    expect(found.map((m) => m.channel.rawId), unorderedEquals(['a', 'b']));
    expect(found.every((m) => m.reason == MatchReason.guide), isTrue);
    // The guide is asked for the pair, never a bare code ("tor" is in
    // "Doctor").
    expect(epg.asked, contains('TOR @ BOS'));
    expect(epg.asked, isNot(contains('TOR')));
  });
}
