import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

void main() {
  const error = 'PlatformException(VideoError, Video player had error wn: '
      'Source error [ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED] cause: mv0: '
      'None of the available extractors could read the stream.)';
  const live = 'https://hls-host.example/live/u/p/316436843.ts';

  test('a live .ts that was HLS is learned once, then opened as HLS', () {
    expect(streamController(live).formatHint, isNull);
    expect(learnHlsHost(live, 'HTTP 404'), isFalse);
    expect(learnHlsHost(live, error), isTrue);
    expect(learnHlsHost(live, error), isFalse, reason: 'retry only once');
    expect(streamController(live).formatHint, VideoFormat.hls);
    // VOD on the same host keeps the normal detection.
    expect(
        streamController('https://hls-host.example/movie/u/p/1.mkv').formatHint,
        isNull);
  });

  test('non-.ts URLs are never retried as HLS', () {
    expect(learnHlsHost('https://other.example/a/1.m3u8', error), isFalse);
    expect(learnHlsHost('https://other.example/movie/1.mp4', error), isFalse);
  });
}
