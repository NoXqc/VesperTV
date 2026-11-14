import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/media_server_api.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This unit test exercises server routing; a background refresh must not call
// the real device-only path_provider/sqflite cache after the assertions finish.
class _MemoryCache extends ArchiveCache {
  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;
  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

/// A fake Jellyfin (API at the root) or Emby (API under `/emby`, legacy
/// headers) server. Records each request with the auth it carried.
MockClient fakeServer(MediaServerKind kind, List<String> log) {
  final emby = kind == MediaServerKind.emby;
  final prefix = emby ? '/emby' : '';
  return MockClient((req) async {
    final path = req.url.path;
    final auth = emby
        ? req.headers['x-emby-authorization']
        : req.headers['authorization'];
    final token = emby ? req.headers['x-emby-token'] : null;
    log.add('${req.method} $path');
    Object? body;
    if (!path.startsWith(prefix) || (emby && !path.startsWith('/emby/'))) {
      return http.Response('not found', 404);
    }
    final p = path.substring(prefix.length);
    if (p == '/System/Info/Public') {
      body = emby
          ? {'ServerName': 'Den', 'Version': '4.8.10.0', 'Id': 'e1'}
          : {
              'ServerName': 'Attic',
              'Version': '10.10.7',
              'ProductName': 'Jellyfin Server',
              'Id': 'j1'
            };
    } else if (auth == null || !auth.contains('Client="VesperTV"')) {
      return http.Response('no auth', 401);
    } else if (p == '/Users/AuthenticateByName') {
      final b = jsonDecode(req.body) as Map;
      if (b['Username'] != 'ann' || b['Pw'] != 'pw') {
        return http.Response('bad', 401);
      }
      body = {
        'User': {'Id': 'u1', 'Name': 'ann'},
        'AccessToken': 'tok',
      };
    } else if (!(auth.contains('Token="tok"') || token == 'tok')) {
      return http.Response('no token', 401);
    } else if (p == '/Users/u1/Views') {
      body = {
        'Items': [
          {'Id': 'lm', 'Name': 'Films', 'CollectionType': 'movies'},
          {'Id': 'lt', 'Name': 'Shows', 'CollectionType': 'tvshows'},
          {'Id': 'lx', 'Name': 'Music', 'CollectionType': 'music'},
        ]
      };
    } else if (p == '/Users/u1/Items' &&
        req.url.queryParameters['ParentId'] == 'lm') {
      body = {
        'Items': [
          {
            'Id': 'm1',
            'Name': 'Home Movie',
            'Type': 'Movie',
            'ProductionYear': 2024,
            'ImageTags': {'Primary': 'pt'},
            'BackdropImageTags': ['bt'],
            'RunTimeTicks': 54000000000,
            'CommunityRating': 7.25,
          }
        ]
      };
    } else if (p == '/Users/u1/Items/s1') {
      body = {'Id': 's1', 'Name': 'A Show', 'Type': 'Series'};
    } else if (p == '/Shows/s1/Episodes') {
      body = {
        'Items': [
          {'Id': 'e2', 'Name': 'Two', 'ParentIndexNumber': 1, 'IndexNumber': 2},
          {'Id': 'e1', 'Name': 'One', 'ParentIndexNumber': 1, 'IndexNumber': 1},
          {
            'Id': 'e3',
            'Name': 'Missing',
            'ParentIndexNumber': 1,
            'IndexNumber': 3,
            'LocationType': 'Virtual'
          },
        ]
      };
    } else if (p.endsWith('/PlaybackInfo') &&
        req.method == 'POST' &&
        req.url.queryParameters['UserId'] == 'u1' &&
        (jsonDecode(req.body) as Map)['UserId'] == 'u1') {
      body = switch (p) {
        // A title kept in two files.
        '/Items/v2/PlaybackInfo' => {
            'MediaSources': [
              {
                'Id': 'v2a',
                'Type': 'Default',
                'Name': '1080p',
                'Container': 'mkv',
                'Path': '/media/Film/Film - 1080p.mkv',
                'Size': 4000000000,
              },
              {
                'Id': 'v2b',
                'Type': 'Default',
                'Name': '2160p',
                'Container': 'mkv',
                'Path': '/media/Film/Film - 2160p.mkv',
                'Size': 20000000000,
              },
            ]
          },
        '/Items/one/PlaybackInfo' => {
            'MediaSources': [
              {'Id': 'one', 'Type': 'Default', 'Name': 'One', 'Size': 9},
            ]
          },
        // AIOStreams' Jellyfin API: one version per add-on stream.
        '/Items/aio/PlaybackInfo' => {
            'MediaSources': [
              {
                'Id': 'aio',
                'Type': 'Default',
                'Name': '4K REMUX',
                'Path': 'https://cdn.example/play/1.mkv',
                'IsRemote': true,
                'Size': 58000000000,
                'aiostreams': {
                  'name': '[RD+] AIO 4K',
                  'description': 'Movie.2160p.REMUX.mkv\n58 GB',
                  'filename': 'Movie.2160p.REMUX.mkv',
                  'size': 58000000000,
                  'bingeGroup': 'g1',
                },
              },
              {
                'Id': 'b2',
                'Type': 'Default',
                'Name': '1080p',
                'Path': 'https://cdn.example/play/2.mkv',
                'RequiredHttpHeaders': {'X-Key': 'k'},
                'aiostreams': {
                  'name': '[RD+] AIO 1080p',
                  'description': 'Movie.1080p.mkv',
                },
              },
              {
                'Id': 'c3',
                'Type': 'Default',
                'Path': '',
                'aiostreams': {'ytId': 'abc'},
              },
            ]
          },
        '/Items/none/PlaybackInfo' => {
            'MediaSources': [
              {
                'Id': 'none',
                'Type': 'Placeholder',
                'Name': 'No streams found',
                'Path': 'https://aio.example/nothing.mp4',
                'aiostreams': {},
              },
            ]
          },
        _ => null,
      };
    }
    if (body == null) return http.Response('not found', 404);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('address clean-up', () {
    expect(MediaServerApi.normalizeUrl(' 192.168.1.10:8096/ '),
        'http://192.168.1.10:8096');
    expect(
        MediaServerApi.normalizeUrl(
            'https://jf.example.org/web/index.html#!/home.html'),
        'https://jf.example.org');
  });

  for (final kind in [MediaServerKind.jellyfin, MediaServerKind.emby]) {
    group(kind.label, () {
      final log = <String>[];
      final api = MediaServerApi(client: fakeServer(kind, log));
      final apiBase = kind == MediaServerKind.emby
          ? 'http://nas:8096/emby'
          : 'http://nas:8096';

      test('detects the server, signs in, libraries become catalogs', () async {
        final s = await api.connect('nas:8096', 'ann', 'pw');
        expect(s.server!.kind, kind);
        expect(s.baseUrl, apiBase);
        expect(s.name, kind == MediaServerKind.emby ? 'Den' : 'Attic');
        expect(s.catalogs.map((c) => '${c.type.wire}/${c.id}/${c.name}'),
            ['movie/lm/Films', 'series/lt/Shows']); // music left out
        // Survives storage (and Transfer).
        final back = ArchiveSource.fromJson(s.toJson());
        expect(back.server!.token, 'tok');
        expect(back.baseUrl, apiBase);
      });

      test('wrong password', () async {
        expect(() => api.connect('nas:8096', 'ann', 'nope'),
            throwsA(isA<MediaServerLoginException>()));
      });

      test('rows, episodes and the direct stream', () async {
        final s = await api.connect('nas:8096', 'ann', 'pw');
        final m = (await api.fetchCatalog(s, s.catalogs.first)).single;
        expect(m.type, ArchiveType.movie);
        expect(m.year, '2024');
        expect(m.runtime, '90 min');
        expect(m.rating, '7.3');
        expect(m.posterUrl,
            '$apiBase/Items/m1/Images/Primary?maxHeight=600&tag=pt');
        expect(m.backgroundUrl,
            '$apiBase/Items/m1/Images/Backdrop/0?maxWidth=1280&tag=bt');

        const show =
            ArchiveMeta(id: 's1', type: ArchiveType.series, name: 'A Show');
        final full = await api.fetchMeta(s, show);
        expect(full!.videos.map((v) => '${v.season}x${v.episode} ${v.id}'),
            ['1x1 e1', '1x2 e2']); // sorted, missing episode dropped

        final key = kind == MediaServerKind.jellyfin ? 'ApiKey' : 'api_key';
        expect((await api.streams(s, 'e1')).single.url,
            '$apiBase/Videos/e1/stream?static=true&$key=tok');
      });

      test('every version of a title is a stream', () async {
        final s = await api.connect('nas:8096', 'ann', 'pw');
        final key = kind == MediaServerKind.jellyfin ? 'ApiKey' : 'api_key';
        final v = await api.streams(s, 'v2');
        expect(v.map((x) => x.url), [
          '$apiBase/Videos/v2/stream?static=true&MediaSourceId=v2a&$key=tok',
          '$apiBase/Videos/v2/stream?static=true&MediaSourceId=v2b&$key=tok',
        ]);
        expect(v.map((x) => x.title),
            ['${kind.label} · 1080p · MKV', '${kind.label} · 2160p · MKV']);
        expect(v.map((x) => x.sizeBytes), [4000000000, 20000000000]);
        expect(v.first.fileName, 'Film - 1080p.mkv');
        // One file: the same link as before (a remembered pick still matches).
        expect((await api.streams(s, 'one')).single.url,
            '$apiBase/Videos/one/stream?static=true&$key=tok');
      });
    });
  }

  test('AIOStreams: each add-on stream is a version, named like the add-on',
      () async {
    final api =
        MediaServerApi(client: fakeServer(MediaServerKind.jellyfin, []));
    final s = await api.connect('nas:8096', 'ann', 'pw');
    final v = await api.streams(s, 'aio');
    // The add-on links themselves; the YouTube one is left out.
    expect(v.map((x) => x.url),
        ['https://cdn.example/play/1.mkv', 'https://cdn.example/play/2.mkv']);
    expect(v.map((x) => x.name), ['[RD+] AIO 4K', '[RD+] AIO 1080p']);
    expect(v.first.title, 'Movie.2160p.REMUX.mkv\n58 GB');
    expect(v.first.fileName, 'Movie.2160p.REMUX.mkv');
    expect(v.first.sizeBytes, 58000000000);
    expect(v.first.bingeGroup, 'g1');
    expect(v.last.requestHeaders, {'X-Key': 'k'});
    // Nothing found: no stream, not the "No streams found" notice clip.
    expect(await api.streams(s, 'none'), isEmpty);
  });

  test('AIOStreams libraries name their add-on catalogs', () async {
    final asked = <Uri>[];
    final api = MediaServerApi(client: MockClient((req) async {
      final p = req.url.path;
      asked.add(req.url);
      final Object? body = switch (p) {
        '/jellyfin/System/Info/Public' => {
            'ServerName': 'AIOStreams',
            'Version': '12.0.0',
            'ProductName': 'Jellyfin Server',
            'Id': 'a1',
          },
        '/jellyfin/Users/AuthenticateByName' => {
            'User': {'Id': 'u1', 'Name': 'me'},
            'AccessToken': 'tok',
          },
        '/jellyfin/Users/u1/Views' => {
            'Items': [
              {
                'Id': 'pop',
                'Name': 'Popular',
                'CollectionType': 'movies',
                'Path': '/aiostreams/movie/949e3b0.tmdb.top',
              },
              {
                // AIOMetadata's plural type, a genre-only catalog.
                'Id': 'nf',
                'Name': 'Netflix - New',
                'Path': '/aiostreams/movies/'
                    '1a2b3c4.tmdb.discover.movie.netflix-new.981dc1aa',
                'aiostreams': {'genreRequired': true},
              },
              {
                'Id': 'shows',
                'Name': 'Trending',
                'CollectionType': 'tvshows',
                'Path': '/aiostreams/series/949e3b0.tmdb.trending',
              },
            ]
          },
        '/jellyfin/Users/u1/Items' => {'Items': []},
        _ => null,
      };
      if (body == null) return http.Response('not found', 404);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    }));
    final s = await api.connect('https://aio.example/jellyfin', 'id', 'pw');
    expect(
        s.catalogs.map((c) =>
            '${c.type.wire}/${c.id}/${c.addonCatalogId}/${c.homeHidden}'),
        [
          'movie/pop/tmdb.top/false',
          'movie/nf/tmdb.discover.movie.netflix-new.981dc1aa/true',
          'series/shows/tmdb.trending/false',
        ]);
    // The add-on's own order (no newest-first sort); a tile's genre is sent.
    await api.fetchCatalog(s, s.catalogs.first);
    expect(asked.last.queryParameters.containsKey('SortBy'), isFalse);
    await api.fetchCatalog(
        s,
        ArchiveCatalog(
            type: ArchiveType.movie,
            id: 'nf',
            name: 'Netflix - New',
            extra: const {'genre': 'Comedy'},
            addonCatalogId: s.catalogs[1].addonCatalogId));
    expect(asked.last.queryParameters['Genres'], 'Comedy');
    expect(asked.last.queryParameters['ParentId'], 'nf');
    // A genre-only catalog lists nothing without one: AIOMetadata's "None".
    await api.fetchCatalog(s, s.catalogs[1]);
    expect(asked.last.queryParameters['Genres'], 'None');
    await api.fetchCatalog(s, s.catalogs.first);
    expect(asked.last.queryParameters.containsKey('Genres'), isFalse);
  });

  test('not a server', () async {
    final api = MediaServerApi(
        client: MockClient((_) async => http.Response('nope', 404)));
    expect(() => api.connect('nowhere', 'a', 'b'),
        throwsA(isA<ArchiveApiException>()));
  });

  test('ArchiveService: add, rows refresh and Play go to the server', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: '[]',
    });
    final storage = StorageService();
    await storage.init();
    final log = <String>[];
    final service = ArchiveService(storage,
        cache: _MemoryCache(),
        servers:
            MediaServerApi(client: fakeServer(MediaServerKind.jellyfin, log)));
    final s = await service.addMediaServer('nas:8096', 'ann', 'pw');
    // Signing in again as the same user replaces, doesn't duplicate.
    await service.addMediaServer('nas:8096', 'ann', 'pw');
    expect(service.sources.length, 1);
    const movie =
        ArchiveMeta(id: 'm1', type: ArchiveType.movie, name: 'Home Movie');
    final options = await service.streams(s, movie);
    expect(options.single.stream.url,
        'http://nas:8096/Videos/m1/stream?static=true&ApiKey=tok');
    final ch = service.channelFor(s, movie, options.single.stream);
    expect(ch.url, options.single.stream.url);
    expect(ch.playlistId, ArchiveService.playlistId);
  });
}
