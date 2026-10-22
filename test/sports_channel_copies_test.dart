import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/utils/channel_name_matching.dart';

/// Audit item 5: quality copies of one channel no longer fill a game's
/// slots ahead of other matches.
void main() {
  ChannelMatch m(String name, int score) => ChannelMatch(
      Channel(
          id: 'p::$name',
          rawId: name,
          playlistId: 'p',
          name: name,
          group: 'Sports',
          url: 'http://x/$name.ts'),
      MatchReason.guide,
      score);

  test('quality copies share a key; region, number and + stay apart', () {
    expect(channelCopyKey('CA: TSN 1 4K'), channelCopyKey('CA: TSN 1 FHD'));
    expect(channelCopyKey('CA: TSN 1 HD'), channelCopyKey('CA| TSN 1'));
    expect(channelCopyKey('CA: TSN 1'), isNot(channelCopyKey('CA: TSN 2')));
    expect(channelCopyKey('US: ESPN'), isNot(channelCopyKey('CA: ESPN')));
    expect(channelCopyKey('US: ESPN'), isNot(channelCopyKey('US: ESPN+')));
    expect(channelCopyKey('US: NBC East'), isNot(channelCopyKey('US: NBC')));
    expect(channelCopyKey('4K'), '');
  });

  test('distinct channels first, their copies after', () {
    final sorted = [
      m('CA: TSN 1 4K', 90),
      m('CA: TSN 1 FHD', 89),
      m('CA: TSN 1 HD', 88),
      m('CA: Sportsnet ONE', 80),
      m('US: ESPN', 70),
      m('CA: Sportsnet ONE HD', 60),
      m('US: ESPN2', 50),
    ];
    final names =
        distinctCopiesFirst(sorted, 3).map((e) => e.channel.name).toList();
    expect(names, [
      'CA: TSN 1 4K',
      'CA: Sportsnet ONE',
      'US: ESPN',
      'CA: TSN 1 FHD',
      'CA: TSN 1 HD',
      'CA: Sportsnet ONE HD',
    ]);
  });

  test('a short list comes back unchanged', () {
    final sorted = [m('US: ESPN', 70), m('US: FS1', 60)];
    expect(distinctCopiesFirst(sorted, 8), sorted);
  });
}
