import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_session.dart';
import 'package:nox_iptv/services/media_server_api.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';

const _plex = ArchiveSource(
  manifestUrl: 'https://plex.example#fixture-machine',
  name: 'My Plex',
  server: MediaServerLogin(
      kind: MediaServerKind.plex,
      userId: 'fixture-machine',
      token: 'fixture-token',
      deviceId: 'fixture-device'),
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: '1', name: 'Movies'),
    ArchiveCatalog(type: ArchiveType.series, id: '2', name: 'Shows'),
  ],
);
const _simkl = ArchiveSource(
    manifestUrl: 'tracker:simkl',
    name: 'Simkl',
    tracker: TrackerLogin(kind: TrackerKind.simkl, accessToken: 'fixture'));
const _movie = ArchiveMeta(
    id: 'tt1838722',
    type: ArchiveType.movie,
    name: 'Truth or Dare',
    year: '2012');

http.Response _container(Map<String, Object?> values) =>
    http.Response(jsonEncode({'MediaContainer': values}), 200);
Map<String, Object?> _item(
        {String id = '301',
        String? imdb = 'tt1838722',
        String year = '2012'}) =>
    {
      'ratingKey': id,
      'type': 'movie',
      'title': 'Truth or Dare',
      'year': int.parse(year),
      if (imdb != null)
        'Guid': [
          {'id': 'imdb://$imdb'}
        ],
    };
http.Response _streams() => _container({
      'Metadata': [
        {
          'Media': [
            {
              'Part': [
                {'key': '/library/parts/55/file.mkv', 'size': 123456789}
              ]
            }
          ]
        }
      ]
    });
Future<StorageService> _storage(List<ArchiveSource> sources) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode([for (final source in sources) source.toJson()])
  });
  final storage = StorageService();
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final origin in [
    _simkl,
    const ArchiveSource(
        manifestUrl: 'tracker:trakt',
        name: 'Trakt',
        tracker: TrackerLogin(kind: TrackerKind.trakt, accessToken: 'fixture')),
    const ArchiveSource(
        manifestUrl: 'https://lists.example/manifest.json',
        name: 'List only',
        listOnly: true),
    const ArchiveSource(
        manifestUrl: 'https://addon.example/manifest.json',
        name: 'Cinemeta',
        catalogProviderUrl: ArchiveCatalogProvider.baseUrl),
  ]) {
    test('${origin.name} movie maps to Plex without loading browse pages',
        () async {
      final storage = await _storage([origin, _plex]);
      final paths = <String>[];
      final client = MockClient((r) async {
        paths.add(r.url.path);
        expect(r.headers['x-plex-token'], 'fixture-token');
        if (r.url.path == '/library/sections/1/all') {
          expect(r.url.queryParameters['title'], 'Truth or Dare');
          expect(r.url.queryParameters['includeGuids'], '1');
          return _container({
            'Metadata': [_item()]
          });
        }
        expect(r.url.path, '/library/metadata/301');
        return _streams();
      });
      final api = ArchiveApiService(
          client:
              MockClient((_) async => http.Response('{"streams":[]}', 200)));
      final hub = ArchiveService(storage,
          servers: MediaServerApi(client: client), api: api);
      final options = await hub.streams(origin, _movie);
      expect(options, hasLength(1));
      expect(options.single.source.key, _plex.key);
      expect(Uri.parse(options.single.stream.url).path,
          '/library/parts/55/file.mkv');
      expect(paths, ['/library/sections/1/all', '/library/metadata/301']);
      hub.dispose();
      api.close();
      client.close();
    });
  }

  for (final items in [
    [_item(imdb: 'tt9999999')], // Same title/year, different known film.
    [_item(imdb: null, year: '2018')], // Remake.
    [_item(id: '301', imdb: null), _item(id: '302', imdb: null)], // Ambiguous.
  ]) {
    test(
        'conflicting, remade or ambiguous titles produce no Plex stream: $items',
        () async {
      final storage = await _storage([_simkl, _plex]);
      final client = MockClient((r) async {
        expect(r.url.path, '/library/sections/1/all');
        return _container({'Metadata': items});
      });
      final hub =
          ArchiveService(storage, servers: MediaServerApi(client: client));
      expect(await hub.streams(_simkl, _movie), isEmpty);
      hub.dispose();
      client.close();
    });
  }

  test('a unique title and year can match legacy Plex metadata without a GUID',
      () async {
    final storage = await _storage([_simkl, _plex]);
    final client = MockClient((r) async => r.url.path.endsWith('/all')
        ? _container({
            'Metadata': [_item(imdb: null)]
          })
        : _streams());
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    expect(await hub.streams(_simkl, _movie), hasLength(1));
    hub.dispose();
    client.close();
  });

  test(
      'targeted lookup follows search pages instead of requiring browse loading',
      () async {
    final storage = await _storage([_simkl, _plex]);
    final offsets = <String?>[];
    final client = MockClient((r) async {
      if (!r.url.path.endsWith('/all')) return _streams();
      offsets.add(r.url.queryParameters['X-Plex-Container-Start']);
      expect(r.url.queryParameters['title'], 'Truth or Dare');
      return _container({
        'Metadata': offsets.length == 1
            ? List.generate(
                100, (i) => _item(id: '$i', imdb: 'tt${9000000 + i}'))
            : [_item()],
      });
    });
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    expect(await hub.streams(_simkl, _movie), hasLength(1));
    expect(offsets, ['0', '100']);
    hub.dispose();
    client.close();
  });

  test('a later exact IMDb match outranks an earlier legacy title/year match',
      () async {
    final plex = _plex.copyWith(catalogs: [
      ..._plex.catalogs,
      const ArchiveCatalog(
          type: ArchiveType.movie, id: '3', name: 'More movies'),
    ]);
    final storage = await _storage([_simkl, plex]);
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/all')) {
        return _container({
          'Metadata': [
            r.url.path.contains('/1/') ? _item(id: '200', imdb: null) : _item(),
          ]
        });
      }
      expect(r.url.path, '/library/metadata/301');
      return _streams();
    });
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    expect(await hub.streams(_simkl, _movie), hasLength(1));
    hub.dispose();
    client.close();
  });

  test(
      'no title/year guessing when an IMDb-less title is ambiguous across libraries',
      () async {
    final plex = _plex.copyWith(catalogs: [
      ..._plex.catalogs,
      const ArchiveCatalog(
          type: ArchiveType.movie, id: '3', name: 'More movies'),
    ]);
    final storage = await _storage([_simkl, plex]);
    final client = MockClient((r) async {
      expect(r.url.path.endsWith('/all'), true);
      return _container({
        'Metadata': [
          _item(id: r.url.path.contains('/1/') ? '200' : '301', imdb: null),
        ]
      });
    });
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    expect(await hub.streams(_simkl, _movie), isEmpty);
    hub.dispose();
    client.close();
  });

  test('a tracker episode uses the matched Plex season/episode rating key',
      () async {
    final storage = await _storage([_simkl, _plex]);
    final paths = <String>[];
    final client = MockClient((r) async {
      paths.add(r.url.path);
      if (r.url.path == '/library/sections/2/all' ||
          r.url.path == '/library/metadata/400') {
        return _container({
          'Metadata': [
            {
              'ratingKey': '400',
              'type': 'show',
              'title': 'A show',
              'Guid': [
                {'id': 'imdb://tt1234567'}
              ]
            }
          ]
        });
      }
      if (r.url.path == '/library/metadata/400/allLeaves') {
        return _container({
          'totalSize': 2,
          'Metadata': [
            {
              'ratingKey': '411',
              'type': 'episode',
              'parentIndex': 1,
              'index': 2
            },
            {
              'ratingKey': '422',
              'type': 'episode',
              'parentIndex': 2,
              'index': 2
            },
          ]
        });
      }
      expect(r.url.path, '/library/metadata/422');
      return _streams();
    });
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    final options = await hub.streams(
        _simkl,
        const ArchiveMeta(
            id: 'tt1234567', name: 'A show', type: ArchiveType.series),
        episode: const ArchiveVideo(
            id: 'tt1234567:2:2', title: 'Two', season: 2, episode: 2));
    expect(options, hasLength(1));
    expect(paths.last, '/library/metadata/422');
    expect(paths.any((p) => p.contains('tt1234567')), isFalse);
    hub.dispose();
    client.close();
  });

  test('disabled and Other servers are not searched for tracker streams',
      () async {
    for (final source in [
      _plex.copyWith(enabled: false),
      _plex.copyWith(otherChoice: true),
    ]) {
      final storage = await _storage([_simkl, source]);
      final client =
          MockClient((_) async => throw StateError('Must not search'));
      final hub =
          ArchiveService(storage, servers: MediaServerApi(client: client));
      final session = hub.searchStreams(_simkl, _movie);
      await session.done;
      expect(session.statuses, isEmpty);
      expect(session.options, isEmpty);
      hub.dispose();
      client.close();
    }
  });

  test(
      'direct Plex title keeps its native id and never performs another search',
      () async {
    final storage = await _storage([_plex]);
    final client = MockClient((r) async {
      expect(r.url.path, '/library/metadata/301');
      return _streams();
    });
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    expect(
        await hub.streams(
            _plex,
            const ArchiveMeta(
                id: '301',
                imdbId: 'tt1838722',
                name: 'Truth or Dare',
                type: ArchiveType.movie)),
        hasLength(1));
    hub.dispose();
    client.close();
  });

  test('viewer change drops a delayed Plex match before requesting its file',
      () async {
    final storage = await _storage([_simkl, _plex]);
    final entered = Completer<void>(), response = Completer<http.Response>();
    final client = MockClient((r) async {
      expect(r.url.path, '/library/sections/1/all');
      entered.complete();
      return response.future;
    });
    final hub =
        ArchiveService(storage, servers: MediaServerApi(client: client));
    final session = hub.searchStreams(_simkl, _movie);
    await entered.future;
    await storage.setActiveViewerId('another');
    response.complete(_container({
      'Metadata': [_item()]
    }));
    await session.done;
    expect(session.active, isFalse);
    expect(session.options, isEmpty);
    hub.dispose();
    client.close();
  });

  test('Plex starts alongside slow addons and joins the existing retry queue',
      () async {
    final addons = List.generate(
        3,
        (i) => ArchiveSource(
            manifestUrl: 'https://addon$i.example/manifest.json',
            name: 'Addon $i',
            catalogProviderUrl: ArchiveCatalogProvider.baseUrl));
    final storage = await _storage([_simkl, ...addons, _plex]);
    final slow = Completer<void>(), usable = Completer<void>();
    var attempts = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/all')) {
        if (attempts++ == 0) return http.Response('', 503);
        return _container({
          'Metadata': [_item()]
        });
      }
      return _streams();
    });
    final api = ArchiveApiService(client: MockClient((_) async {
      await slow.future;
      return http.Response('{"streams":[]}', 200);
    }));
    final hub = ArchiveService(storage,
        servers: MediaServerApi(client: client), api: api);
    final session = hub.searchStreams(_simkl, _movie);
    session.addListener(() {
      if (session.statuses[_plex.key] == ArchiveSourceStatus.failed &&
          !usable.isCompleted) {
        usable.complete();
      }
    });
    await usable.future;
    expect(session.loading, isTrue);
    slow.complete();
    await session.done;
    await session.retrySource!(_plex.key);
    expect(session.options, hasLength(1));
    expect(session.options.single.source.key, _plex.key);
    hub.dispose();
    api.close();
    client.close();
  });
}
