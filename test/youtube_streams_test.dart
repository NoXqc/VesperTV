import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/youtube_streams.dart';

/// Owner, 2026-11-26: trailers play YouTube's own files in our player
/// (ARVIO's way) instead of YouTube's web player.
void main() {
  const id = 'AbCdEfGhI12';
  const visitor = 'CgtWaXNpdG9yMTIz';
  const hls = 'https://manifest.googlevideo.com/api/manifest/hls_variant/'
      'id/1/file/index.m3u8';
  const mp4 = 'https://rr1.googlevideo.com/videoplayback?itag=18&id=1';

  // sw.js_data: `)]}'` then [[_, _, [[[... 13: visitor]], key]]].
  final serviceWorker = ")]}'\n${jsonEncode([
        [
          'a',
          null,
          [
            [
              [for (var i = 0; i < 13; i++) i, visitor]
            ],
            'not-used'
          ]
        ]
      ])}";

  http.Response player(Map<String, Object?> data) =>
      http.Response(jsonEncode(data), 200);

  ({YouTubeStreams service, List<http.Request> asked}) make(
      {bool refuse = false}) {
    final asked = <http.Request>[];
    final service = YouTubeStreams(client: MockClient((req) async {
      asked.add(req);
      if (req.url.path == '/sw.js_data') {
        return http.Response(serviceWorker, 200);
      }
      if (refuse) {
        return player({
          'playabilityStatus': {'status': 'LOGIN_REQUIRED'}
        });
      }
      return switch (req.headers['x-youtube-client-name']) {
        '101' => player({
            'playabilityStatus': {'status': 'OK'},
            'streamingData': {'hlsManifestUrl': hls}
          }),
        '3' => player({
            'playabilityStatus': {'status': 'OK'},
            'streamingData': {
              'formats': [
                {
                  'itag': 18,
                  'url': mp4,
                  'mimeType': 'video/mp4; codecs="avc1.42001E, mp4a.40.2"',
                  'height': 360
                },
                // Ciphered: needs YouTube's player code, skipped.
                {
                  'itag': 22,
                  'signatureCipher': 's=abc&url=https%3A%2F%2Fx',
                  'mimeType': 'video/mp4',
                  'height': 720
                },
              ]
            }
          }),
        _ => player({
            'playabilityStatus': {'status': 'LOGIN_REQUIRED'}
          }),
      };
    }));
    return (service: service, asked: asked);
  }

  test('HD playlist for title pages, the single file for cards', () async {
    final (:service, :asked) = make();
    final stream = (await service.resolve(id))!;
    expect(stream.large.toString(), hls);
    expect(stream.small.toString(), mp4);
    expect(stream.muxedHeight, 360);
    // The visitor id goes with every client; no API key anywhere.
    final posts = asked.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(3));
    for (final post in posts) {
      expect(post.headers['x-goog-visitor-id'], visitor);
      final client = (jsonDecode(post.body) as Map)['context']['client'] as Map;
      expect(client['visitorData'], visitor);
      expect((jsonDecode(post.body) as Map)['videoId'], id);
    }
    expect(asked.any((r) => r.url.queryParameters.containsKey('key')), isFalse);
  });

  test('kept: the next ask for the same trailer needs no request', () async {
    final (:service, :asked) = make();
    await service.resolve(id);
    final before = asked.length;
    expect((await service.resolve(id))!.large.toString(), hls);
    expect(asked, hasLength(before));
    // A link that failed to play is asked for again.
    service.forget(id);
    await service.resolve(id);
    expect(asked.length, greaterThan(before));
  });

  test('YouTube refusing every client: null (the web player stays)', () async {
    final (:service, asked: _) = make(refuse: true);
    expect(await service.resolve(id), isNull);
  });

  test('not a YouTube id: nothing asked', () async {
    final (:service, :asked) = make();
    expect(await service.resolve('../etc'), isNull);
    expect(asked, isEmpty);
  });

  test("a card's single file doesn't wait for the HD playlist", () async {
    final slowPlaylist = Completer<http.Response>();
    final service = YouTubeStreams(client: MockClient((req) {
      if (req.url.path == '/sw.js_data') {
        return Future.value(http.Response(serviceWorker, 200));
      }
      return switch (req.headers['x-youtube-client-name']) {
        '101' => slowPlaylist.future,
        '3' => Future.value(player({
            'streamingData': {
              'formats': [
                {'url': mp4, 'mimeType': 'video/mp4', 'height': 360}
              ]
            }
          })),
        _ => Future.value(player({
            'playabilityStatus': {'status': 'LOGIN_REQUIRED'}
          })),
      };
    }));
    expect((await service.resolveSmall(id)).toString(), mp4);
    expect(slowPlaylist.isCompleted, isFalse);
    slowPlaylist.complete(player({
      'streamingData': {'hlsManifestUrl': hls}
    }));
    // The title page still gets the HD playlist.
    expect((await service.resolve(id))!.large.toString(), hls);
  });

  test('visitor id from sw.js_data', () {
    expect(YouTubeStreams.visitorFromServiceWorkerData(serviceWorker), visitor);
    expect(YouTubeStreams.visitorFromServiceWorkerData('nope'), isNull);
  });
}
