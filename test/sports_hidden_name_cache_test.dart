import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Only on a hidden channel" is found once per channel list (2026-11-25):
/// the scan read every hidden name for each game without a channel on
/// every match. A changed list scans again.
void main() {
  Channel ch(String id, String name) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: 'UK | NHL',
      url: 'http://x/$id.ts');

  test(
      'a game only on a hidden channel says so, every match, until the '
      'list changes', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final matcher = SportsChannelMatcher(EpgService(storage));
    final picks = SportsChannelPicks.load(storage);
    final nhl = sportsLeagueById('nhl')!;
    final g = SportsGame(
      id: 'g1',
      league: nhl,
      start: DateTime.utc(2026, 11, 26, 0, 30),
      state: GameState.pre,
      statusText: '',
      home: const SportsTeam(
          id: 'h',
          name: 'Boston Bruins',
          shortName: 'Bruins',
          abbreviation: 'BOS'),
      away: const SportsTeam(
          id: 'a',
          name: 'Detroit Red Wings',
          shortName: 'Red Wings',
          abbreviation: 'DET'),
    );
    final shown = [ch('cnn', 'US: CNN HD')];
    final hidden = [
      ch('x', 'UK: Sky Sports Main Event'),
      ch('bru', 'UK: NHL 04: Boston Bruins vs Detroit Red Wings'),
    ];

    await matcher.prepare(shown, hidden: hidden);
    for (var pass = 0; pass < 2; pass++) {
      final out = await matcher.matchDay([g], picks);
      expect(out[SportsChannelPicks.eventKey(g)] ?? const [], isEmpty);
      final why = matcher.whyNoMatch(g)!;
      expect(why.cause, NoMatchCause.hiddenChannel, reason: 'pass $pass');
      expect(why.channelName, 'UK: NHL 04: Boston Bruins vs Detroit Red Wings');
    }

    // The channel is no longer hidden anywhere: the answer is found again.
    await matcher.prepare(shown, hidden: [hidden.first]);
    await matcher.matchDay([g], picks);
    expect(matcher.whyNoMatch(g)?.cause, isNot(NoMatchCause.hiddenChannel));
  });
}
