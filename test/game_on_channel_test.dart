import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';

/// The full-screen player's left drawer finds the game on the playing
/// channel to list its other sources (This game tab).
void main() {
  Channel ch(String name, {String playlist = 'p'}) => Channel(
      id: '$playlist::$name',
      rawId: name,
      playlistId: playlist,
      name: name,
      group: 'Sports',
      url: 'http://x/$name.ts');

  SportsTeam team(String id) =>
      SportsTeam(id: id, name: id, shortName: id, abbreviation: id);

  SportsGame game(String id, GameState state) => SportsGame(
        id: id,
        league: sportsLeagueById('nhl')!,
        start: DateTime(2026, 11, 10, 19),
        state: state,
        statusText: '',
        home: team('$id-h'),
        away: team('$id-a'),
      );

  String key(SportsGame g) => SportsChannelPicks.eventKey(g);

  test('the game listing the playing channel, with all its sources', () {
    final tsn = ch('CA: TSN 1 4K'), sn = ch('CA: Sportsnet ONE');
    final a = game('a', GameState.live), b = game('b', GameState.live);
    final found = gameOnChannel(sn, [
      a,
      b
    ], {
      key(a): [ChannelMatch(ch('CA: TSN 2'), MatchReason.guide, 80)],
      key(b): [
        ChannelMatch(tsn, MatchReason.guide, 90, gameEvidence: true),
        ChannelMatch(sn, MatchReason.guide, 85, gameEvidence: true),
      ],
    });
    expect(found?.game.id, 'b');
    expect([for (final m in found!.sources) m.channel.id], [tsn.id, sn.id]);
  });

  test('no game lists the channel: null', () {
    final a = game('a', GameState.live);
    expect(
        gameOnChannel(ch('US: CNN'), [
          a
        ], {
          key(a): [ChannelMatch(ch('CA: TSN 1'), MatchReason.guide, 90)],
        }),
        isNull);
  });

  test('a quality copy counts and is listed after the listed one', () {
    final hd = ch('CA: TSN 1 HD'), sd = ch('CA: TSN 1 SD', playlist: 'q');
    final other = ch('CA: RDS');
    final a = game('a', GameState.live);
    final found = gameOnChannel(sd, [
      a
    ], {
      key(a): [
        ChannelMatch(hd, MatchReason.guide, 90, gameEvidence: true),
        ChannelMatch(other, MatchReason.guide, 80, gameEvidence: true),
      ],
    });
    expect(found?.game.id, 'a');
    expect([for (final m in found!.sources) m.channel.id],
        [hd.id, sd.id, other.id]);
  });

  test('exact listing beats a copy; pick and evidence beat a bare network', () {
    final espn = ch('US: ESPN');
    final copyGame = game('copy', GameState.live);
    final exactGame = game('exact', GameState.live);
    expect(
        gameOnChannel(espn, [
          copyGame,
          exactGame
        ], {
          key(copyGame): [
            ChannelMatch(ch('US: ESPN 4K'), MatchReason.pick, 1000,
                gameEvidence: true)
          ],
          key(exactGame): [ChannelMatch(espn, MatchReason.network, 10)],
        })?.game.id,
        'exact');

    final guess = game('guess', GameState.live);
    final picked = game('picked', GameState.live);
    final guide = game('guide', GameState.live);
    expect(
        gameOnChannel(espn, [
          guess,
          guide,
          picked
        ], {
          key(guess): [ChannelMatch(espn, MatchReason.network, 70)],
          key(guide): [
            ChannelMatch(espn, MatchReason.guide, 60, gameEvidence: true)
          ],
          key(picked): [ChannelMatch(espn, MatchReason.pick, 1000)],
        })?.game.id,
        'picked');
    expect(
        gameOnChannel(espn, [
          guess,
          guide
        ], {
          key(guess): [ChannelMatch(espn, MatchReason.network, 70)],
          key(guide): [
            ChannelMatch(espn, MatchReason.guide, 60, gameEvidence: true)
          ],
        })?.game.id,
        'guide');
  });

  test('a live game beats one about to start on the same channel', () {
    final tsn = ch('CA: TSN 1');
    final soon = game('soon', GameState.pre);
    final now = game('now', GameState.live);
    expect(
        gameOnChannel(tsn, [
          soon,
          now
        ], {
          key(soon): [ChannelMatch(tsn, MatchReason.guide, 95)],
          key(now): [ChannelMatch(tsn, MatchReason.guide, 90)],
        })?.game.id,
        'now');
  });
}
