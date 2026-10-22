import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

void main() {
  const error = 'PlatformException(VideoError, Video player had error wn: '
      'Source error [ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED] cause: mv0: '
      'None of the available extractors could read the stream.)';
  const malformed = 'PlatformException(VideoError, Video player had error bo: '
      'Source error [ERROR_CODE_PARSING_MANIFEST_MALFORMED] cause: oa0: '
      'Input does not start with the #EXTM3U header)';

  // /dead/ answers with an error page, everything else with a playlist.
  final client = MockClient((req) async => req.url.path.contains('/dead/')
      ? http.Response('<html><title>Stream offline</title>', 200,
          headers: {'content-type': 'text/html'})
      : http.Response('#EXTM3U\n#EXT-X-VERSION:3\n', 200));

  test('a live .ts that was HLS is learned once, then opened as HLS', () async {
    const live = 'https://hls-host.example/live/u/p/316436843.ts';
    expect(streamController(live).formatHint, isNull);
    expect(await learnHlsHost(live, 'HTTP 404', client: client), isFalse);
    expect(await learnHlsHost(live, error, client: client), isTrue);
    expect(await learnHlsHost(live, error, client: client), isFalse,
        reason: 'retry only once');
    expect(streamController(live).formatHint, VideoFormat.hls);
    // VOD on the same host keeps the normal detection.
    expect(
        streamController('https://hls-host.example/movie/u/p/1.mkv').formatHint,
        isNull);
  });

  test('a dead channel answering with a page does not mark its server',
      () async {
    const dead = 'https://mixed.example/dead/u/p/1.ts';
    expect(await learnHlsHost(dead, error, client: client), isFalse);
    expect(streamController('https://mixed.example/live/u/p/2.ts').formatHint,
        isNull);
  });

  test('a plain TS channel on an HLS server is opened as TS again', () async {
    const hls = 'https://split.example/live/u/p/1.ts';
    const ts = 'https://split.example/live/u/p/2.ts';
    expect(await learnHlsHost(hls, error, client: client), isTrue);
    expect(streamController(ts).formatHint, VideoFormat.hls);
    expect(unlearnHlsUrl(ts, 'HTTP 404'), isFalse);
    expect(unlearnHlsUrl(ts, malformed), isTrue);
    expect(unlearnHlsUrl(ts, malformed), isFalse, reason: 'retry only once');
    expect(streamController(ts).formatHint, isNull);
    expect(streamController(hls).formatHint, VideoFormat.hls);
  });

  test('non-.ts URLs are never retried as HLS', () async {
    expect(
        await learnHlsHost('https://other.example/a/1.m3u8', error,
            client: client),
        isFalse);
    expect(
        await learnHlsHost('https://other.example/movie/1.mp4', error,
            client: client),
        isFalse);
    expect(unlearnHlsUrl('https://other.example/a/1.m3u8', malformed), isFalse);
  });
}
