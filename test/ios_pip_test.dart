import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/ios_pip.dart';

void main() {
  group('IosPip.linkFor (what Apple\'s player gets)', () {
    test('Xtream live .ts becomes its HLS twin', () {
      expect(
          IosPip.linkFor('http://host:8080/live/user/pass/123.ts', live: true),
          'http://host:8080/live/user/pass/123.m3u8');
    });

    test('Xtream short live link gets /live/ and .m3u8', () {
      expect(IosPip.linkFor('http://host:8080/user/pass/123', live: true),
          'http://host:8080/live/user/pass/123.m3u8');
    });

    test('live HLS stays as it is', () {
      const url = 'https://cdn.example/stream/index.m3u8?token=a';
      expect(IosPip.linkFor(url, live: true), url);
    });

    test('raw TS from another server has no HLS twin', () {
      expect(IosPip.linkFor('http://host/channels/tsn.ts', live: true), isNull);
    });

    test('MKV, AVI and TS files are refused, MP4 and unknown are tried', () {
      expect(
          IosPip.linkFor('https://cdn/x/Movie.2160p.mkv', live: false), isNull);
      expect(IosPip.linkFor('https://cdn/x/movie.AVI', live: false), isNull);
      expect(IosPip.linkFor('http://host/movie/u/p/9.ts', live: false), isNull);
      expect(IosPip.linkFor('http://host/movie/u/p/9.mp4', live: false),
          'http://host/movie/u/p/9.mp4');
      expect(
          IosPip.linkFor('https://store.example/dl/abc?token=1', live: false),
          'https://store.example/dl/abc?token=1');
    });

    test('a link without a scheme is refused', () {
      expect(IosPip.linkFor('not a link', live: false), isNull);
    });
  });
}
