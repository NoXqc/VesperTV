import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/real_4k_channels.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'handoff_sports_regression_test.dart' show channel, game;

class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
          DateTime from, DateTime to, List<String> terms) async =>
      programmes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test(
      'matched 4K from another broadcaster is offered first without changing settings',
      () async {
    expect(storage.getSportsPreferQuality(), isTrue);
    final start = DateTime.now().toUtc();
    final g = game('g', start);
    final hd = channel('hd', 'US: ESPN HD');
    final uhd = channel('uhd', 'CA: Sportsnet ONE 4K');
    final epg = _Guide(storage, [
      for (final c in [hd, uhd])
        EpgProgram(
            channelId: c.rawId,
            title: 'Buffalo Bills vs Las Vegas Raiders',
            start: start,
            stop: start.add(const Duration(hours: 3)))
    ]);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([hd, uhd]);
    final picks = SportsChannelPicks.load(storage);
    final key = SportsChannelPicks.eventKey(g);
    expect((await matcher.matchDay([g], picks))[key]!.first.channel.id, uhd.id);
    // Saved picks override the automatic 4K default on every rematch.
    await picks.pickForGame(g, hd.id);
    expect((await matcher.matchDay([g], picks))[key]!.first.channel.id, hd.id);
    await picks.clearFor(g);
    await storage.setSportsPreferQuality(false);
    expect((await matcher.matchDay([g], picks))[key]!.first.channel.id, hd.id);
  });

  test('confirmed 4K and saved choices stay first even when names differ', () {
    final before = Real4kChannels.ids.value;
    addTearDown(() => Real4kChannels.ids.value = before);
    final hd =
        ChannelMatch(channel('hd', 'US: ESPN HD'), MatchReason.guide, 100);
    final named = ChannelMatch(
        channel('named', 'CA: Sportsnet 4K'), MatchReason.guide, 90);
    final measured =
        ChannelMatch(channel('measured', 'CA: TSN'), MatchReason.guide, 80);
    Real4kChannels.ids.value = {measured.channel.id};
    expect(preferSportsSources([hd, named, measured]), [measured, named, hd]);
    final pick = ChannelMatch(hd.channel, MatchReason.pick, 1000);
    expect(preferSportsSources([named, measured, pick]).first, same(pick));
  });

  test(
      'a manually added source list defaults to 4K until a specific source is picked',
      () {
    final hd =
        ChannelMatch(channel('hd', 'US: ESPN HD'), MatchReason.pick, 950);
    final uhd =
        ChannelMatch(channel('uhd', 'CA: Sportsnet 4K'), MatchReason.pick, 950);
    expect(preferSportsSources([hd, uhd]).first, same(uhd));
    final saved = ChannelMatch(hd.channel, MatchReason.pick, 1000);
    expect(preferSportsSources([uhd, saved]).first, same(saved));
  });
}
