import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/tuliprox.dart';

/// Tuliprox 2bfb3991 (uzumaki, 2026-11-23): M3U-only setups find the Player
/// API in the playlist download (`#EXTM3U x-tuliprox-player-api` or header
/// `X-Tuliprox-Player-Api-Path`); a reverse-proxy prefix stays in the
/// address; M3U streams are `/m3u-stream/...`.
Channel _channel(String url) => Channel(
    id: 'p1::1',
    rawId: '1',
    playlistId: 'p1',
    name: 'UK: CNN',
    group: 'UK| News',
    url: url);

void main() {
  tearDown(() {
    for (final host in ['tv.example.com', 'host.example', '127.0.0.1']) {
      Tuliprox.instance.noteServer('https://$host', null);
    }
  });

  group('stream addresses', () {
    const base = 'https://host.example/tuliprox/ui';
    test('M3U output streams and a reverse-proxy prefix', () {
      for (final url in [
        'https://host.example/tuliprox/m3u-stream/live/alice/pw/1042.ts',
        'https://host.example/tuliprox/m3u-stream/alice/pw/1042/live.m3u8',
        'https://host.example/tuliprox/live/alice/pw/1042.ts',
        'https://host.example/tuliprox/alice/pw/1042',
        'https://host.example/m3u-stream/live/alice/pw/1042.ts?dedicated=1',
      ]) {
        final ref = tuliproxChannelRef(base, url);
        expect(ref?.id, 1042, reason: url);
        expect(ref?.username, 'alice', reason: url);
        expect(ref?.password, 'pw', reason: url);
      }
    });

    test('movies, shows and other paths are not live channels', () {
      for (final url in [
        'https://host.example/tuliprox/movie/alice/pw/7.mkv',
        'https://host.example/tuliprox/m3u-stream/movie/alice/pw/7.mkv',
        'https://host.example/other/live/alice/pw/1042.ts',
      ]) {
        expect(tuliproxChannelRef(base, url), isNull, reason: url);
      }
    });
  });

  test('the server root of a playlist or stream address', () {
    expect(
        tuliproxServerRoot(
            'https://host.example/get.php?username=a&password=b'),
        'https://host.example');
    expect(
        tuliproxServerRoot(
            'https://host.example/tuliprox/get.php?username=a&password=b'),
        'https://host.example/tuliprox');
    expect(tuliproxServerRoot('http://host.example:8901/apiget?u=a&p=b'),
        'http://host.example:8901');
    expect(tuliproxServerRoot('https://host.example/tuliprox/m3u/a/b'),
        'https://host.example/tuliprox');
    expect(
        tuliproxServerRoot(
            'https://host.example/tuliprox/m3u-stream/live/a/b/1.ts'),
        'https://host.example/tuliprox');
    expect(tuliproxServerRoot('file:///sdcard/list.m3u'), isNull);
  });

  test('an Xtream server behind a prefix keeps it', () {
    Tuliprox.instance.login.value = null;
    Tuliprox.instance.noteServer('https://host.example/tuliprox', '/ui');
    final ref = Tuliprox.instance
        .refOf(_channel('https://host.example/tuliprox/live/alice/pw/1042.ts'));
    expect(ref?.base, 'https://host.example/tuliprox/ui');
  });

  test('an M3U list (or a file of one) gives the server', () {
    Tuliprox.instance.login.value = null;
    Tuliprox.instance.noteM3uServer(
        'https://host.example/tuliprox/get.php?username=a&password=b', '/ui');
    expect(
        Tuliprox.instance
            .refOf(_channel(
                'https://host.example/tuliprox/m3u-stream/live/a/b/5.ts'))
            ?.base,
        'https://host.example/tuliprox/ui');
    // Imported as a file: a channel's own address gives the server.
    Tuliprox.instance.noteM3uServer('file:///sdcard/list.m3u', '/',
        streamUrl: 'https://tv.example.com/m3u-stream/live/a/b/5.ts');
    expect(
        Tuliprox.instance
            .refOf(_channel('https://tv.example.com/m3u-stream/live/a/b/5.ts'))
            ?.base,
        'https://tv.example.com');
  });

  group('the download names the path', () {
    late HttpServer server;
    String? header;
    var body = '';

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        if (header != null) {
          req.response.headers.set('X-Tuliprox-Player-Api-Path', header!);
        }
        req.response
          ..write(body)
          ..close();
      });
    });
    tearDown(() => server.close(force: true));

    Future<String?> read() async {
      String? found = 'not called';
      await M3uParser.fetchAndParse(
          'http://127.0.0.1:${server.port}/tuliprox/get.php?username=a&password=b',
          playlistId: 'p1',
          onPlayerApi: (path) => found = path);
      return found;
    }

    const entry = '#EXTINF:-1 group-title="UK| News",UK: CNN\n'
        'http://127.0.0.1/tuliprox/m3u-stream/live/a/b/1.ts\n';

    test('from the #EXTM3U line', () async {
      header = null;
      body = '#EXTM3U url-tvg="http://x/epg.xml" '
              'x-tuliprox-player-api="/ui"\n' +
          entry;
      expect(await read(), '/ui');
    });

    test('from the response header', () async {
      header = '/admin';
      body = '#EXTM3U\n$entry';
      expect(await read(), '/admin');
    });

    test('none: null (the host is then forgotten)', () async {
      header = null;
      body = '#EXTM3U\n$entry';
      expect(await read(), isNull);
    });
  });
}
