import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'handoff_sports_regression_test.dart' show channel;

class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
          DateTime from, DateTime to, List<String> terms) async =>
      programmes;

  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

SportsGame _game(String id, DateTime start, SportsTeam home, SportsTeam away) =>
    SportsGame(
        id: id,
        league: sportsLeagueById('nfl')!,
        start: start,
        state: GameState.pre,
        statusText: '',
        home: home,
        away: away,
        broadcasts: const ['ESPN']);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  // User report 2026-11-05: games on at the same time all pointed to one
  // 4K station.
  test('a station the guide shows on one game is not guessed for another',
      () async {
    final start = DateTime.now().toUtc().add(const Duration(hours: 1));
    final bills = _game(
        'a',
        start,
        const SportsTeam(
            id: 'buf',
            name: 'Buffalo Bills',
            shortName: 'Bills',
            abbreviation: 'BUF'),
        const SportsTeam(
            id: 'lv',
            name: 'Las Vegas Raiders',
            shortName: 'Raiders',
            abbreviation: 'LV'));
    final jets = _game(
        'b',
        start,
        const SportsTeam(
            id: 'nyj',
            name: 'New York Jets',
            shortName: 'Jets',
            abbreviation: 'NYJ'),
        const SportsTeam(
            id: 'mia',
            name: 'Miami Dolphins',
            shortName: 'Dolphins',
            abbreviation: 'MIA'));
    final uhd = channel('uhd', 'US: ESPN 4K');
    final hd = channel('hd', 'US: ESPN2 HD');
    EpgProgram on(String id, String title) => EpgProgram(
        channelId: id,
        title: title,
        start: start,
        stop: start.add(const Duration(hours: 3)));
    final epg = _Guide(storage, [
      on(uhd.rawId, 'Buffalo Bills vs Las Vegas Raiders'),
      on(hd.rawId, 'New York Jets vs Miami Dolphins'),
    ]);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([uhd, hd]);
    final picks = SportsChannelPicks.load(storage);
    final out = await matcher.matchDay([bills, jets], picks);
    final billsIds = out[SportsChannelPicks.eventKey(bills)]!
        .map((m) => m.channel.id)
        .toList();
    final jetsIds = out[SportsChannelPicks.eventKey(jets)]!
        .map((m) => m.channel.id)
        .toList();
    expect(billsIds.first, uhd.id);
    expect(jetsIds, [hd.id]);
  });

  test('the guide-confirmed source outranks a 4K guess', () {
    final guess =
        ChannelMatch(channel('uhd', 'US: ESPN 4K'), MatchReason.network, 50);
    final shown = ChannelMatch(
        channel('hd', 'US: ESPN2 HD'), MatchReason.guide, 80,
        gameEvidence: true);
    // Matches arrive best score first; the 4K guess used to jump ahead.
    expect(preferSportsSources([shown, guess]).first, same(shown));
  });

  test('confirmed sources go best quality first; guesses keep their place', () {
    final hd = ChannelMatch(channel('hd', 'US: FS1 HD'), MatchReason.guide, 80,
        gameEvidence: true);
    final guess = ChannelMatch(
        channel('net', 'US: NFL Network'), MatchReason.network, 75);
    final fhd = ChannelMatch(
        channel('fhd', 'US: Fox FHD'), MatchReason.guide, 70,
        gameEvidence: true);
    expect(preferSportsSources([hd, guess, fhd]), [fhd, guess, hd]);
  });
}
