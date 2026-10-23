import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/trailer.dart';
import 'package:nox_iptv/services/trailer_service.dart';

void main() {
  const id = 'AbCdEfGhI12';
  const addons = [
    ArchiveSource(
        manifestUrl: 'https://addon.example/manifest.json',
        name: 'User trailer source',
        imdbResources: {
          'meta': ['movie', 'series']
        })
  ];
  test(
      'YouTube normalization rejects arbitrary hosts, schemes and malformed ids',
      () {
    for (final raw in [
      id,
      'https://youtu.be/$id',
      'https://www.youtube.com/watch?v=$id&t=10',
      'https://www.youtube.com/embed/$id'
    ]) {
      expect(TrailerLinks.videoId(raw), id);
    }
    for (final raw in [
      'short',
      'https://youtube.com.evil/watch?v=$id',
      'javascript:$id',
      'https://user:pass@youtube.com/watch?v=$id',
      'https://example.com/trailer.mp4'
    ]) {
      expect(TrailerLinks.videoId(raw), isNull);
    }
  });
  test('source forms deduplicate and survive ArchiveMeta cache round trips',
      () {
    final data = {
      'id': 'tt1',
      'type': 'movie',
      'name': 'Film',
      'youtube_trailer': id,
      'trailers': [
        {'source': id, 'type': 'Trailer'},
        {'source': 'OtherFilm12', 'type': 'Clip'}
      ],
      'trailerStreams': [
        {'ytId': id}
      ],
      'RemoteTrailers': [
        {'Url': 'https://youtu.be/$id'}
      ]
    };
    expect(TrailerLinks.fromMetadata(data), [id]);
    final meta = ArchiveMeta.fromJson(data)!;
    expect(ArchiveMeta.fromJson(meta.toJson())!.trailers, [id]);
    expect(
        TrailerLinks.fromMetadata(
            {'trailers': 'malformed', 'trailerStreams': null}),
        isEmpty);
  });
  test('supplied trailers never require HTTP', () async {
    final service = TrailerService(
        client: MockClient((_) async => throw StateError('Unexpected HTTP')));
    expect(
        (await service.resolve(const TrailerRequest(
                title: 'Film', series: false, supplied: [id])))!
            .queryParameters['v'],
        id);
  });
  test(
      'strict title/year lookup refuses ambiguous remakes and first-result fallback',
      () async {
    final service = TrailerService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'metas': [
                {
                  'id': 'tt1',
                  'type': 'movie',
                  'name': 'Film',
                  'releaseInfo': '2014'
                },
                {
                  'id': 'tt2',
                  'type': 'movie',
                  'name': 'Film',
                  'releaseInfo': '2014'
                },
              ]
            }),
            200)));
    expect(
        await service.resolve(
            const TrailerRequest(title: 'Film (2014)', series: false),
            addons: addons),
        isNull);
    expect(
        await service.resolve(
            const TrailerRequest(title: 'Different', series: false),
            addons: addons),
        isNull);
  });
  test(
      'known IMDb id uses the right media type and validates returned identity',
      () async {
    final service = TrailerService(client: MockClient((request) async {
      expect(request.url.host, 'addon.example');
      expect(request.url.path, '/meta/series/tt123.json');
      return http.Response(
          jsonEncode({
            'meta': {
              'id': 'tt123',
              'type': 'series',
              'trailers': [
                {'source': id, 'type': 'Trailer'}
              ]
            }
          }),
          200);
    }));
    expect(
        (await service.resolve(
                const TrailerRequest(
                    title: 'Show', series: true, imdbId: 'tt123'),
                addons: addons))!
            .queryParameters['v'],
        id);
  });
  test(
      'TMDB resolves identity but trailer playback comes only from user add-ons',
      () async {
    final hosts = <String>[];
    final service = TrailerService(client: MockClient((request) async {
      hosts.add(request.url.host);
      if (request.url.host == 'api.themoviedb.org') {
        expect(request.url.path, '/3/tv/10/external_ids');
        return http.Response(jsonEncode({'imdb_id': 'tt123'}), 200);
      }
      expect(request.url.host, 'addon.example');
      expect(request.url.queryParameters, isEmpty);
      expect(request.url.path, '/meta/series/tt123.json');
      return http.Response(
          jsonEncode({
            'meta': {
              'id': 'tt123',
              'type': 'series',
              'trailerStreams': [
                {'ytId': id}
              ]
            }
          }),
          200);
    }));
    final result = await service.resolve(
        const TrailerRequest(
            title: 'Show', series: true, tmdbId: '10', tmdbKey: 'test-key'),
        addons: addons);
    expect(result!.queryParameters['v'], id);
    expect(hosts, ['api.themoviedb.org', 'addon.example']);
  });
  test('concurrent negative lookups deduplicate, expire and tolerate failures',
      () async {
    var calls = 0;
    var now = DateTime.utc(2026, 10, 22);
    final service = TrailerService(
        now: () => now,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 503);
        }));
    const request =
        TrailerRequest(title: 'Film', series: false, imdbId: 'tt123');
    expect(
        await Future.wait([
          service.resolve(request, addons: addons),
          service.resolve(request, addons: addons)
        ]),
        [null, null]);
    // One lookup's requests (add-on, then Cinemeta), shared by both callers.
    final perLookup = calls;
    expect(perLookup, greaterThan(0));
    await service.resolve(request, addons: addons);
    expect(calls, perLookup);
    now = now.add(const Duration(minutes: 11));
    await service.resolve(request, addons: addons);
    expect(calls, 2 * perLookup);
  });
}
