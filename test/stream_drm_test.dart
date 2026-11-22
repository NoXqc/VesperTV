import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/stream_drm.dart';
import 'package:nox_iptv/services/m3u_parser.dart';

/// Two entries as m3upt.com writes them (2026-11-22): a ClearKey DASH
/// channel with its headers, and a clear HLS one with headers only.
const _playlist = '''
#EXTM3U url-tvg="https://example.com/epg.xml.xz"

#EXTINF:-1 group-title="TV" tvg-id="RTP1.pt" tvg-logo="https://example.com/RTP1.png",RTP 1
#EXTVLCOPT:http-user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"
#EXTVLCOPT:http-origin=https://www.rtp.pt
#EXTVLCOPT:http-referrer=https://www.rtp.pt/play/direto/rtp1
#KODIPROP:inputstream.adaptive.license_type=org.w3.clearkey
#KODIPROP:inputstream.adaptive.license_key=f80351a117ba3f17a26e0e8cd4dc00c4:a2226def4bc8f249de2daf36b7c12b1e
https://streaming-live.rtp.pt/liverepeater/rtpClean1HD.smil/manifest.mpd

#EXTINF:-1 group-title="TV" tvg-id="TVI.pt",TVI
#EXTVLCOPT:http-referrer=https://tviplayer.iol.pt
https://d28hnoqioi2jsa.cloudfront.net/playlist.m3u8

#EXTINF:-1 group-title="TV" tvg-id="Plain.pt",Plain
https://example.com/plain.ts
''';

void main() {
  group('M3U parser', () {
    final channels = M3uParser.parse(_playlist, playlistId: 'p');

    test('reads the ClearKey pair and the VLC headers', () {
      final rtp = channels.first;
      expect(rtp.httpHeaders['User-Agent'],
          'Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0');
      expect(rtp.httpHeaders['Origin'], 'https://www.rtp.pt');
      expect(rtp.httpHeaders['Referer'], 'https://www.rtp.pt/play/direto/rtp1');
      final drm = StreamDrm.of(rtp.httpHeaders)!;
      expect(drm.system, StreamDrm.clearKey);
      expect(drm.keys, {
        'f80351a117ba3f17a26e0e8cd4dc00c4': 'a2226def4bc8f249de2daf36b7c12b1e'
      });
      expect(rtp.url, endsWith('manifest.mpd'));
    });

    test('headers without DRM, and nothing at all for a plain entry', () {
      expect(channels[1].httpHeaders, {'Referer': 'https://tviplayer.iol.pt'});
      expect(StreamDrm.of(channels[1].httpHeaders), isNull);
      expect(channels[2].httpHeaders, isEmpty);
      expect(channels[2].playlistHeaders, isEmpty);
    });

    test('KODIPROP before #EXTINF counts too, and does not leak onward', () {
      final list = M3uParser.parse('''
#EXTM3U
#KODIPROP:inputstream.adaptive.license_type=clearkey
#KODIPROP:inputstream.adaptive.license_key=f80351a117ba3f17a26e0e8cd4dc00c4:a2226def4bc8f249de2daf36b7c12b1e
#EXTINF:-1,A
https://a.example/manifest.mpd
#EXTINF:-1,B
https://b.example/manifest.mpd
''', playlistId: 'p');
      expect(StreamDrm.of(list[0].httpHeaders), isNotNull);
      expect(list[1].httpHeaders, isEmpty);
    });

    test('Kodi stream headers and #EXTHTTP', () {
      final list = M3uParser.parse('''
#EXTM3U
#EXTINF:-1,A
#KODIPROP:inputstream.adaptive.stream_headers=user-agent=My%20Box&Referer=https://r.example/
https://a.example/manifest.mpd
#EXTINF:-1,B
#EXTHTTP:{"User-Agent":"UA","cookie":"a=1"}
https://b.example/live.m3u8
''', playlistId: 'p');
      expect(list[0].httpHeaders,
          {'User-Agent': 'My Box', 'Referer': 'https://r.example/'});
      expect(list[1].httpHeaders, {'User-Agent': 'UA', 'Cookie': 'a=1'});
    });
  });

  group('StreamDrm.fromKodiProps', () {
    const kid = 'f80351a117ba3f17a26e0e8cd4dc00c4';
    const key = 'a2226def4bc8f249de2daf36b7c12b1e';

    test('several pairs, base64url ids and UUID spellings', () {
      final drm = StreamDrm.fromKodiProps({
        'license_type': 'clearkey',
        'license_key':
            'F80351A1-17BA-3F17-A26E-0E8CD4DC00C4:$key,-ANRoRe6Pxeibg6M1NwAxA:$key',
      })!;
      expect(drm.keys, {kid: key});
    });

    test('a JSON object of pairs and a JWK set', () {
      expect(
          StreamDrm.fromKodiProps({
            'license_type': 'org.w3.clearkey',
            'license_key': '{"$kid":"$key"}',
          })!
              .keys,
          {kid: key});
      expect(
          StreamDrm.fromKodiProps({
            'license_type': 'clearkey',
            'license_key':
                '{"keys":[{"kty":"oct","kid":"-ANRoRe6Pxeibg6M1NwAxA",'
                    '"k":"oiJt70vI8kneLa82t8ErHg"}],"type":"temporary"}',
          })!
              .keys,
          {kid: key});
    });

    test('Kodi 21 drm_legacy and drm JSON', () {
      expect(
          StreamDrm.fromKodiProps({'drm_legacy': 'org.w3.clearkey|$kid:$key'})!
              .keys,
          {kid: key});
      final wv = StreamDrm.fromKodiProps({
        'drm_legacy': 'com.widevine.alpha|https://lic.example/wv|X-Token=abc',
      })!;
      expect(wv.system, StreamDrm.widevine);
      expect(wv.licenseUrl, 'https://lic.example/wv');
      expect(wv.licenseHeaders, {'X-Token': 'abc'});
      expect(
          StreamDrm.fromKodiProps({
            'drm': '{"org.w3.clearkey":{"license":{"keyids":{"$kid":"$key"}}}}',
          })!
              .keys,
          {kid: key});
    });

    test('Widevine license server with headers', () {
      final drm = StreamDrm.fromKodiProps({
        'license_type': 'com.widevine.alpha',
        'license_key':
            'https://lic.example/wv?id=1|User-Agent=UA&Content-Type=application%2Foctet-stream|R{SSM}|',
      })!;
      expect(drm.system, StreamDrm.widevine);
      expect(drm.licenseUrl, 'https://lic.example/wv?id=1');
      expect(drm.licenseHeaders,
          {'User-Agent': 'UA', 'Content-Type': 'application/octet-stream'});
    });

    test('nothing usable gives null', () {
      expect(StreamDrm.fromKodiProps({}), isNull);
      expect(StreamDrm.fromKodiProps({'license_type': 'clearkey'}), isNull);
      expect(
          StreamDrm.fromKodiProps({
            'license_type': 'com.widevine.alpha',
            'license_key': '$kid:$key'
          }),
          isNull);
      expect(
          StreamDrm.fromKodiProps(
              {'license_type': 'clearkey', 'license_key': 'zz:yy'}),
          isNull);
    });

    test('the header round-trips and the license is a JWK set', () {
      final drm = StreamDrm.fromKodiProps(
          {'license_type': 'clearkey', 'license_key': '$kid:$key'})!;
      final sent = jsonDecode(drm.encode()) as Map<String, dynamic>;
      expect(sent['system'], 'clearkey');
      expect(sent['license'], {
        'keys': [
          {
            'kty': 'oct',
            'kid': '-ANRoRe6Pxeibg6M1NwAxA',
            'k': 'oiJt70vI8kneLa82t8ErHg'
          }
        ],
        'type': 'temporary',
      });
      final back = StreamDrm.of({StreamDrm.headerKey: drm.encode()})!;
      expect(back.keys, {kid: key});
    });
  });

  group('Channel', () {
    Channel drmChannel() => M3uParser.parse(_playlist, playlistId: 'p').first;

    test('playlist headers are saved, app-added ones are not', () {
      final playing = drmChannel();
      final withKey = Channel(
        id: playing.id,
        rawId: playing.rawId,
        playlistId: 'p',
        name: 'x',
        group: 'g',
        url: playing.url,
        httpHeaders: {'X-API-Key': 'secret'},
        playlistHeaders: playing.playlistHeaders,
      );
      expect(withKey.httpHeaders['X-API-Key'], 'secret');
      expect(StreamDrm.of(withKey.httpHeaders), isNotNull);
      final saved = jsonEncode(withKey.toJson());
      expect(saved, isNot(contains('secret')));
      final restored =
          Channel.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      expect(StreamDrm.of(restored.httpHeaders)!.keys, hasLength(1));
      expect(restored.httpHeaders['Origin'], 'https://www.rtp.pt');
      expect(restored.httpHeaders.containsKey('X-API-Key'), isFalse);
    });

    test('a plain channel saves no headers key', () {
      final plain = M3uParser.parse(_playlist, playlistId: 'p').last;
      expect(plain.toJson().containsKey('headers'), isFalse);
    });

    test("another copy's stream does not keep this entry's DRM", () {
      final rtp = drmChannel();
      final copy =
          rtp.copyWith(url: 'https://other.example/live.ts', httpHeaders: {});
      expect(StreamDrm.of(copy.httpHeaders), isNull);
      expect(copy.toJson().containsKey('headers'), isFalse);
      final same = rtp.copyWith(isFavorite: true);
      expect(same.httpHeaders, rtp.httpHeaders);
      expect(same.playlistHeaders, rtp.playlistHeaders);
    });

    test('withoutDrm keeps the other headers', () {
      final rtp = drmChannel();
      final plain = StreamDrm.withoutDrm(rtp.httpHeaders);
      expect(plain.containsKey(StreamDrm.headerKey), isFalse);
      expect(plain['Origin'], 'https://www.rtp.pt');
      const none = {'A': 'b'};
      expect(identical(StreamDrm.withoutDrm(none), none), isTrue);
    });
  });
}
