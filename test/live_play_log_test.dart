import 'package:flutter_test/flutter_test.dart';

import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playback_service.dart';

void main() {
  Channel ch(String url) => Channel(
      id: 'p1::42',
      rawId: '42',
      name: 'TNT Sports 4',
      url: url,
      group: 'UK Sports',
      playlistId: 'p1');

  test('LivePlay names the copy without its address', () {
    const url = 'http://host.example:8080/live/user/pass/42.ts';
    final line = livePlayLogLine(ch(url), url);
    expect(line, startsWith('LivePlay: TNT Sports 4 | group UK Sports | '));
    expect(line, contains('playlist p1 | stream '));
    expect(line, endsWith(' ts'));
    expect(line, isNot(contains('host.example')));
    expect(line, isNot(contains('pass')));
  });

  test('two copies get different tags, one copy the same tag', () {
    const a = 'http://h/live/u/p/42.ts', b = 'http://h/live/u/p/43.ts';
    expect(livePlayLogLine(ch(a), a), livePlayLogLine(ch(a), a));
    expect(livePlayLogLine(ch(a), a), isNot(livePlayLogLine(ch(b), b)));
  });

  test('the recorder tap and HLS are named', () {
    const url = 'http://h/live/u/p/42.m3u8';
    final line = livePlayLogLine(ch(url), 'http://127.0.0.1:9/tap');
    expect(line, contains(' m3u8 | tap'));
  });
}
