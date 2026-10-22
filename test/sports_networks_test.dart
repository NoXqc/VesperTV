import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/sports_channel_library.dart';
import 'package:nox_iptv/services/sports_networks.dart';

/// Sports Trak › Channels (owner, 2026-10-22): one card per network, and
/// the hockey filter must bring TSN, ESPN, Sportsnet, TVA Sports and RDS.
void main() {
  Channel ch(String name) => Channel(
      id: 'p::$name',
      rawId: name,
      playlistId: 'p',
      name: name,
      group: name.contains('CNN') ? 'News' : 'CA Sports',
      url: 'http://x/${name.hashCode}.ts');

  final channels = [
    for (final n in [
      'CA: TSN 2 FHD',
      'CA: TSN 1 4K',
      'CA: TSN 1 FHD',
      'CA: Sportsnet ONE',
      'CA: Sportsnet Ontario',
      'CA: RDS 2',
      'CA: TVA Sports',
      'US: ESPN',
      'US: ESPN2',
      'US: ESPN+ 12',
      'US: NBA TV',
      'US: NHL Network',
      'US: SportsNet LA',
      'US: FanDuel Sports Detroit',
      'US: CNN',
    ])
      ch(n)
  ];

  test('multi-sport networks count for hockey; league networks only for theirs',
      () {
    final library = SportsChannelLibrary(channels);
    final hockey = channels
        .where((c) => library.accepts(c, {
              'Sport': ['hockey']
            }))
        .map((c) => c.name)
        .toSet();
    for (final n in [
      'CA: TSN 1 FHD',
      'CA: Sportsnet ONE',
      'CA: RDS 2',
      'CA: TVA Sports',
      'US: ESPN',
      'US: NHL Network',
    ]) {
      expect(hockey, contains(n));
    }
    expect(hockey, isNot(contains('US: NBA TV')));
    expect(hockey, isNot(contains('US: CNN')));
  });

  test('one card per network, feeds in order, best copy first', () {
    final cards = SportsChannelLibrary.groups(channels, row: 'Sports networks');
    final tsn = cards.firstWhere((g) => g.name == 'TSN');
    expect(tsn.channels.map((c) => c.name),
        ['CA: TSN 1 FHD', 'CA: TSN 1 4K', 'CA: TSN 2 FHD']);
    final names = cards.map((g) => g.name).toSet();
    expect(names, containsAll(['TSN', 'Sportsnet', 'RDS', 'TVA Sports']));
    expect(cards.firstWhere((g) => g.name == 'ESPN').channels.length, 2);
    expect(cards.firstWhere((g) => g.name == 'ESPN+').channels.length, 1);
  });

  test('rows: league, regional (US SportsNet is not Canada\'s), sports', () {
    String row(String name) => SportsChannelLibrary.category(ch(name));
    expect(row('US: NBA TV'), 'League networks');
    expect(row('US: NHL Network'), 'League networks');
    expect(row('US: SportsNet LA'), 'Regional channels');
    expect(row('US: FanDuel Sports Detroit'), 'Regional channels');
    expect(row('CA: Sportsnet Ontario'), 'Sports networks');
    expect(sportsNetworkOf(ch('CA: Sportsnet Ontario'))?.id, 'sportsnet');
    expect(row('US: CNN'), '');
    expect(
        SportsChannelLibrary.category(Channel(
            id: 'p::x',
            rawId: 'x',
            playlistId: 'p',
            name: 'US: Big Event 3',
            group: 'Sports',
            url: 'http://x/1.ts')),
        'Other sports channels');
  });
}
