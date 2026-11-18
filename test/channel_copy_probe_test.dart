import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/channel_copy_fallback.dart';
import 'package:nox_iptv/utils/channel_name_matching.dart';

Channel _c(int i, String name) => Channel(
    id: 'p::$i',
    rawId: '$i',
    playlistId: 'p',
    name: name,
    group: 'G',
    url: 'https://x/$i');

void main() {
  const names = [
    'CA: TSN 1 4K',
    'CA: TSN 1 FHD',
    'CA: TSN1 HD',
    'CA: TSN 2',
    'US: TSN 1',
    'TSN 1',
    'ESPN',
    'ESPN+',
    'US| ESPN HD',
    'US| ESPN 4K',
    'DE: Sport1 Großbritannien',
    'DE: SPORT 1 GROSSBRITANNIEN HD',
    'UK - BBC One HD',
    'UK - BBC ONE',
    'UK - BBC One East',
    '4K',
    'HD',
    'FOX 5 NY',
    'FOX5 NY HEVC',
    'Sky Sports F1 UHD',
    'SKY SPORTS F1',
  ];

  // The probe word only skips names that can't have the key: the result is
  // the same as comparing every channel's key (the Sources drawer, owner
  // 2026-11-16: seconds on a box).
  test('copiesOf finds exactly the channels with the same copy key', () {
    final pool = [for (final (i, n) in names.indexed) _c(i, n)];
    for (final channel in pool) {
      final key = channelCopyKey(channel.name);
      final expected = {
        if (key.isNotEmpty)
          for (final c in pool)
            if (c.id != channel.id && channelCopyKey(c.name) == key) c.name
      };
      expect(
          ChannelCopyFallback.copiesOf(channel, pool)
              .map((c) => c.name)
              .toSet(),
          expected,
          reason: channel.name);
    }
    expect(channelCopyProbe(channelCopyKey('CA: TSN1 HD')), 'TSN');
    expect(channelCopyProbe(''), '');
  });

  test('300k channels', () {
    final pool = [
      for (var i = 0; i < 300000; i++)
        _c(i, 'XX: Channel ${i % 5000} ${const ['HD', 'FHD', '4K'][i % 3]}'),
      _c(300001, 'CA: TSN 1 FHD'),
      _c(300002, 'CA: TSN1 HD'),
    ];
    final watch = Stopwatch()..start();
    final copies = ChannelCopyFallback.copiesOf(_c(-1, 'CA: TSN 1 4K'), pool);
    // ignore: avoid_print
    print('copiesOf over ${pool.length}: ${watch.elapsedMilliseconds} ms');
    expect(copies.map((c) => c.name), ['CA: TSN 1 FHD', 'CA: TSN1 HD']);
  });
}
