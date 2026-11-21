import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'handoff_sports_regression_test.dart' show channel;

/// UK guides list a match with its build-up: TNT Sports' "Premier League :
/// Manchester City v Fulham" ran 06:00-10:00 for a 07:30 kickoff and was
/// never suggested (owner, 2026-11-21): only programmes starting from an
/// hour before kickoff counted.
class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  DateTime? askedFrom;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
      DateTime from, DateTime to, List<String> terms) async {
    askedFrom = from;
    // Like the database: programmes starting in [from, to).
    return [
      for (final p in programmes)
        if (!p.start.isBefore(from) && p.start.isBefore(to)) p
    ];
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

  final kickoff = DateTime.now().toUtc().add(const Duration(hours: 4));
  final game = SportsGame(
    id: 'g1',
    league: sportsLeagueById('eng.1')!,
    start: kickoff,
    state: GameState.pre,
    statusText: '',
    home: const SportsTeam(
        id: 'mci',
        name: 'Manchester City',
        shortName: 'Man City',
        abbreviation: 'MNC'),
    away: const SportsTeam(
        id: 'ful', name: 'Fulham', shortName: 'Fulham', abbreviation: 'FUL'),
  );

  EpgProgram block(String id, String title, int fromMin, int toMin) =>
      EpgProgram(
          channelId: id,
          title: title,
          start: kickoff.add(Duration(minutes: fromMin)),
          stop: kickoff.add(Duration(minutes: toMin)));

  test('a block on at kickoff with its build-up finds the game', () async {
    final tnt = channel('tnt', 'UK: TNT Sports Ultimate 4K UHD');
    final pre = channel('pre', 'UK: Sports Preview');
    final old = channel('old', 'UK: Sports Classics');
    final pl = channel('pl', 'UK: Premier League TV');
    final epg = _Guide(storage, [
      // 90 min of build-up, the match, the reaction.
      block(tnt.rawId, 'Premier League : Manchester City v Fulham Live', -90,
          150),
      // A preview show that ends at kickoff: not the match.
      block(pre.rawId, 'Man City v Fulham: The Build-Up', -90, 0),
      // Started too long before kickoff.
      block(old.rawId, 'Manchester City v Fulham', -240, 60),
      // A long league block without the teams.
      block(pl.rawId, 'Premier League Live', -90, 150),
    ]);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([tnt, pre, old, pl]);
    final out =
        await matcher.matchDay([game], SportsChannelPicks.load(storage));
    final found = out[SportsChannelPicks.eventKey(game)] ?? const [];
    final guide = [
      for (final m in found)
        if (m.reason == MatchReason.guide) m.channel.rawId
    ];
    expect(guide, ['tnt']);
    // The guide is asked from far enough back to find such a block.
    expect(epg.askedFrom!.isAfter(kickoff.subtract(const Duration(hours: 3))),
        isFalse);
  });

  test('a game 45 minutes in still finds its guide block', () async {
    final now = DateTime.now().toUtc();
    final started = now.subtract(const Duration(minutes: 48));
    SportsGame epl(String id, DateTime at, GameState state, String home,
            String away) =>
        SportsGame(
          id: id,
          league: sportsLeagueById('eng.1')!,
          start: at,
          state: state,
          statusText: '',
          home: SportsTeam(
              id: home, name: home, shortName: home, abbreviation: ''),
          away: SportsTeam(
              id: away, name: away, shortName: away, abbreviation: ''),
        );
    final live =
        epl('live', started, GameState.live, 'Manchester City', 'Fulham');
    // A later game: it became the scan's anchor once the live game was
    // 30 minutes in, and the live game left the scan.
    final later = epl('later', now.add(const Duration(hours: 3)), GameState.pre,
        'Arsenal', 'Chelsea');
    final tnt = channel('tnt', 'UK: TNT Sports Ultimate 4K UHD');
    final epg = _Guide(storage, [
      EpgProgram(
          channelId: tnt.rawId,
          title: 'Premier League : Manchester City v Fulham',
          start: started.subtract(const Duration(minutes: 90)),
          stop: started.add(const Duration(minutes: 150))),
    ]);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([tnt]);
    final out =
        await matcher.matchDay([live, later], SportsChannelPicks.load(storage));
    final found = out[SportsChannelPicks.eventKey(live)] ?? const [];
    expect(found.map((m) => (m.channel.rawId, m.reason)),
        contains(('tnt', MatchReason.guide)));
  });
}
