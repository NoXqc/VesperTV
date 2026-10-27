import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// An AIOStreams-style add-on saved while it had no catalogs (stream-only on
// Cinemeta), whose config later gained TMDB catalogs (`tmdb:` ids).

class _Cache extends ArchiveCache {
  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;
  @override
  Future<List<ArchiveMeta>> read(
          String sourceKey, ArchiveCatalog catalog) async =>
      [];
  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

ArchiveSource _streamOnly(String host, String name) => ArchiveSource(
      manifestUrl: 'https://$host/manifest.json',
      name: name,
      catalogs: ArchiveCatalogProvider.catalogsFor(
          const [ArchiveType.movie, ArchiveType.series]),
      catalogProviderUrl: ArchiveCatalogProvider.baseUrl,
    );

final _aio = _streamOnly('aio.example', 'NoxAIO');
final _torrentio = _streamOnly('torrentio.example', 'Torrentio TB');

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

http.Response _aioManifest() => _json({
      'name': 'NoxAIO',
      'resources': [
        {
          'name': 'stream',
          'types': ['movie', 'series'],
          'idPrefixes': ['tt', 'tmdb']
        },
        {
          'name': 'catalog',
          'types': ['movie', 'series']
        },
        {
          'name': 'meta',
          'types': ['movie', 'series'],
          'idPrefixes': ['tmdb:', 'tt']
        },
      ],
      'catalogs': [
        {'type': 'movie', 'id': 'tmdb.top', 'name': 'Popular'},
        {
          'type': 'movie',
          'id': 'tmdb.search',
          'name': 'Search',
          'extra': [
            {'name': 'search', 'isRequired': true}
          ]
        },
      ],
    });

Future<StorageService> _storage(List<ArchiveSource> sources) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode([for (final s in sources) s.toJson()])
  });
  final storage = StorageService();
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final button in [true, false]) {
    test(
        'stream-only add-on gains its catalogs on '
        '${button ? 'the Refresh button' : 'a plain forced refresh: no'}',
        () async {
      final storage = await _storage([_aio]);
      final api = ArchiveApiService(client: MockClient((r) async {
        if (r.url.host == 'aio.example' && r.url.path == '/manifest.json') {
          return _aioManifest();
        }
        return _json({'metas': []});
      }));
      final service = ArchiveService(storage, api: api, cache: _Cache());
      await service.refresh(force: true, manifests: button);
      final s = service.sources.single;
      expect(s.streamOnly, !button);
      if (button) {
        expect(s.catalogs.map((c) => c.id), contains('tmdb.search'));
      }
      service.dispose();
      api.close();
    });
  }

  test('own tmdb ids fall back to the IMDb id, other add-ons asked too',
      () async {
    const own = ArchiveSource(
      manifestUrl: 'https://aio.example/manifest.json',
      name: 'NoxAIO',
      catalogs: [
        ArchiveCatalog(type: ArchiveType.movie, id: 'tmdb.top', name: 'Popular')
      ],
    );
    final storage = await _storage([own, _torrentio]);
    final asked = <String>[];
    final api = ArchiveApiService(client: MockClient((r) async {
      asked.add('${r.url.host}${r.url.path}');
      if (r.url.path == '/stream/movie/tt0145487.json') {
        return _json({
          'streams': [
            {'url': 'https://${r.url.host}/file.mkv', 'name': r.url.host}
          ]
        });
      }
      return _json({'streams': []});
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    const meta = ArchiveMeta(
        id: 'tmdb:557',
        type: ArchiveType.movie,
        name: 'Spider-Man',
        imdbId: 'tt0145487');
    final options = await service.streams(own, meta);
    expect(asked, [
      'aio.example/stream/movie/tmdb:557.json',
      'aio.example/stream/movie/tt0145487.json',
      'torrentio.example/stream/movie/tt0145487.json',
    ]);
    expect(options.map((o) => o.source.name), ['NoxAIO', 'Torrentio TB']);
    service.dispose();
    api.close();
  });

  test('IMDb-id titles keep the old lookup', () async {
    final storage = await _storage([_aio, _torrentio]);
    final asked = <String>[];
    final api = ArchiveApiService(client: MockClient((r) async {
      asked.add('${r.url.host}${r.url.path}');
      return _json({'streams': []});
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    const meta = ArchiveMeta(
        id: 'tt0145487', type: ArchiveType.movie, name: 'Spider-Man');
    await service.streams(_aio, meta);
    expect(asked, [
      'aio.example/stream/movie/tt0145487.json',
      'torrentio.example/stream/movie/tt0145487.json',
    ]);
    service.dispose();
    api.close();
  });

  test('a search row shared by stream-only add-ons names all of them',
      () async {
    final storage = await _storage([_torrentio, _aio]);
    final api = ArchiveApiService(client: MockClient((r) async {
      if (r.url.host == 'v3-cinemeta.strem.io' &&
          r.url.path.contains('search=')) {
        return _json({
          'metas': [
            {'id': 'tt0145487', 'type': 'movie', 'name': 'Spider-Man'}
          ]
        });
      }
      if (r.url.path == '/manifest.json') {
        return _json({
          'name': r.url.host,
          'resources': ['stream'],
          'types': ['movie', 'series'],
          'idPrefixes': ['tt'],
          'catalogs': [],
        });
      }
      return _json({'metas': []});
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    final rows = await service.searchRows(ArchiveType.movie, 'spider man',
        underOther: false);
    expect(rows, hasLength(1));
    expect(rows.single.labelAt(0), 'Torrentio TB · NoxAIO');
    service.dispose();
    api.close();
  });
}
