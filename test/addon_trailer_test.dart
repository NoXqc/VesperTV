import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/trailer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrailerStorage extends StorageService {
  int writes = 0;
  @override
  Future<void> writeCacheFile(String name, String data) async {
    writes++;
  }
}

void main() {
  const id = 'AbCdEfGhI12';
  const request = TrailerRequest(title: 'Film', series: false, imdbId: 'tt123');
  const source = ArchiveSource(
      manifestUrl: 'https://user-addon.example/manifest.json',
      name: 'User add-on',
      imdbResources: {
        'meta': ['movie'],
        'stream': ['movie']
      });

  test('no configured add-ons means no built-in YouTube provider or lookup',
      () async {
    final service = TrailerService(
        client: MockClient((_) async => throw StateError('No HTTP allowed')));
    expect(await service.resolve(request), isNull);
  });

  test(
      'built-in catalog metadata never becomes an implicitly supplied trailer source',
      () {
    const builtinMetadata = ArchiveSource(
        manifestUrl: 'https://user-stream.example/manifest.json',
        name: 'Stream add-on',
        catalogProviderUrl: ArchiveCatalogProvider.baseUrl);
    expect(builtinMetadata.suppliesOwnMetadata, isFalse);
    expect(source.suppliesOwnMetadata, isTrue);
  });

  test('IPTV supplied id and source-supplied direct trailers bypass discovery',
      () async {
    final service = TrailerService(
        client: MockClient((_) async => throw StateError('No HTTP allowed')));
    expect(
        (await service.resolve(const TrailerRequest(
                title: 'Film', series: false, supplied: [id])))!
            .queryParameters['v'],
        id);
    expect(
        (await service.resolve(const TrailerRequest(
                title: 'Show',
                series: true,
                suppliedStreams: [
              ArchiveStream(url: 'https://cdn.example/trailer.mp4')
            ])))!
            .path,
        '/trailer.mp4');
  });

  test(
      'wrong meta identity cannot become a trailer; stream fallback stays on the exact id',
      () async {
    final paths = <String>[];
    final service = TrailerService(client: MockClient((req) async {
      paths.add(req.url.path);
      if (req.url.path.contains('/meta/')) {
        return http.Response(
            jsonEncode({
              'meta': {
                'id': 'tt999',
                'trailerStreams': [
                  {'ytId': 'OtherFilm12'}
                ]
              }
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'streams': [
              {'ytId': id}
            ]
          }),
          200);
    }));
    expect(
        (await service.resolve(request, addons: [source]))!
            .queryParameters['v'],
        id);
    expect(paths, ['/meta/movie/tt123.json', '/stream/movie/tt123.json']);
  });

  test('disabled and non-IMDb sources are never queried', () async {
    final service = TrailerService(
        client: MockClient((_) async => throw StateError('No HTTP allowed')));
    expect(
        await service.resolve(request, addons: [
          source.copyWith(enabled: false),
          const ArchiveSource(
              manifestUrl: 'https://own.example/manifest.json',
              name: 'Own IDs',
              imdbResources: {'meta': []})
        ]),
        isNull);
  });

  test('manifest resource/type restrictions survive storage and copies',
      () async {
    final api = ArchiveApiService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'name': 'Trailer source',
              'types': ['movie', 'series'],
              'idPrefixes': ['tt'],
              'resources': [
                {
                  'name': 'meta',
                  'types': ['movie'],
                  'idPrefixes': ['tt']
                },
                {
                  'name': 'stream',
                  'types': ['series'],
                  'idPrefixes': ['other_']
                }
              ],
              'catalogs': [
                {'type': 'movie', 'id': 'movies', 'name': 'Movies'}
              ],
            }),
            200)));
    final parsed =
        await api.fetchManifest('https://user.example/manifest.json');
    final restored =
        ArchiveSource.fromJson(parsed.toJson()).copyWith(enabled: true);
    expect(restored.supportsImdb('meta', 'movie'), isTrue);
    expect(restored.supportsImdb('meta', 'series'), isFalse);
    expect(restored.supportsImdb('stream', 'series'), isFalse);
  });

  test(
      'metadata-only IMDb trailer add-on can be added without invented streams',
      () async {
    final api = ArchiveApiService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'name': 'Meta trailers',
              'types': ['movie'],
              'idPrefixes': ['tt'],
              'resources': ['meta'],
              'catalogs': [],
            }),
            200)));
    final parsed =
        await api.fetchManifest('https://user.example/manifest.json');
    expect(parsed.supportsImdb('meta', 'movie'), isTrue);
    expect(parsed.supportsImdb('stream', 'movie'), isFalse);
    expect(parsed.catalogs, isEmpty);
  });

  test('Media Hub keeps different YouTube ids and direct URLs in source order',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final api = ArchiveApiService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'streams': [
                {'ytId': id, 'name': 'First'},
                {'ytId': 'OtherFilm12', 'name': 'Second'},
                {'ytId': id},
                {'url': 'https://cdn.example/video.mp4'},
              ]
            }),
            200)));
    final service = ArchiveService(storage, api: api);
    final streams = await service.streams(source,
        const ArchiveMeta(id: 'tt123', type: ArchiveType.movie, name: 'Film'));
    expect(streams.map((s) => s.stream.identity),
        ['yt:$id', 'yt:OtherFilm12', 'https://cdn.example/video.mp4']);
    service.dispose();
  });

  test('old own-catalog source rereads its manifest without rewriting settings',
      () async {
    final paths = <String>[];
    const old = ArchiveSource(
        manifestUrl: 'https://old.example/manifest.json', name: 'Saved source');
    final service = TrailerService(client: MockClient((req) async {
      paths.add(req.url.path);
      if (req.url.path == '/manifest.json') {
        return http.Response(
            jsonEncode({
              'name': 'Saved source',
              'types': ['movie'],
              'idPrefixes': ['tt'],
              'resources': ['meta'],
              'catalogs': []
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'meta': {
              'id': 'tt123',
              'trailerStreams': [
                {'ytId': id}
              ]
            }
          }),
          200);
    }));
    expect(
        (await service.resolve(request, addons: [old]))!.queryParameters['v'],
        id);
    expect(paths, ['/manifest.json', '/meta/movie/tt123.json']);
    expect(old.imdbResources, isEmpty);
  });

  test('direct trailer records neither recently-played entry nor cache file',
      () async {
    final storage = TrailerStorage();
    final playback =
        PlaybackService(storage, PlaylistManager(storage, CatalogDatabase()));
    await playback.recordWatched(Channel.trailer(
        title: 'Film trailer', url: 'https://cdn.example/trailer.mp4'));
    expect(playback.recentlyPlayed, isEmpty);
    expect(storage.writes, 0);
  });

  test(
      'direct trailer metadata survives cache without losing supplied YouTube ids',
      () {
    final meta = ArchiveMeta.fromJson({
      'id': 'tt123',
      'type': 'movie',
      'name': 'Film',
      'youtube_trailer': id,
      'trailerStreams': [
        {'url': 'https://cdn.example/trailer.mp4'}
      ]
    })!;
    final restored = ArchiveMeta.fromJson(meta.toJson())!;
    expect(restored.trailers, [id]);
    expect(
        restored.trailerStreams
            .any((s) => s.url == 'https://cdn.example/trailer.mp4'),
        isTrue);
  });
}
