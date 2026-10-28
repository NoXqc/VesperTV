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

// The Media Hub "Newest" filter: release-year catalogs only, narrowed by the
// picked genre on the items (a year catalog takes no second server filter).

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

final _year = '${DateTime.now().year}';

// Stream-only add-on on Cinemeta: Popular / New / Featured.
final _torrentio = ArchiveSource(
  manifestUrl: 'https://torrentio.example/manifest.json',
  name: 'Torrentio',
  catalogs: ArchiveCatalogProvider.catalogsFor(const [ArchiveType.movie]),
  catalogProviderUrl: ArchiveCatalogProvider.baseUrl,
);

// An add-on with its own catalogs, like AIOStreams + TMDB.
final _aio = ArchiveSource(
  manifestUrl: 'https://aio.example/manifest.json',
  name: 'NoxAIO',
  catalogs: [
    const ArchiveCatalog(
        type: ArchiveType.movie, id: 'tmdb.top', name: 'Popular'),
    ArchiveCatalog(
        type: ArchiveType.movie,
        id: 'tmdb.year',
        name: 'Year',
        years: [_year, '${DateTime.now().year - 1}']),
  ],
);

http.Response _json(Object o) => http.Response(jsonEncode(o), 200);

Map<String, dynamic> _m(String id, String name, [List<String>? genres]) => {
      'id': id,
      'type': 'movie',
      'name': name,
      if (genres != null) 'genres': genres,
    };

Future<ArchiveService> _service(List<String> asked) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode([_torrentio.toJson(), _aio.toJson()]),
  });
  final storage = StorageService();
  await storage.init();
  final api = ArchiveApiService(client: MockClient((r) async {
    asked.add('${r.url.host}${r.url.path}');
    if (r.url.host == 'v3-cinemeta.strem.io' &&
        r.url.path.contains('/year/genre=$_year')) {
      return _json({
        'metas': [
          _m('tt1', 'New Action', ['Action', 'Thriller']),
          _m('tt2', 'New Comedy', ['Comedy']),
        ]
      });
    }
    if (r.url.host == 'aio.example' && r.url.path.contains('tmdb.year')) {
      // TMDB's catalog lists carry no genres.
      return _json({
        'metas': [_m('tmdb:1', 'Tmdb New')]
      });
    }
    return _json({
      'metas': [
        _m('tt9', 'Old Popular', ['Action'])
      ]
    });
  }));
  return ArchiveService(storage, api: api, cache: _Cache());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Newest lists only the release-year rows; off restores the rest',
      () async {
    final asked = <String>[];
    final service = await _service(asked);
    await service.refresh();
    expect(service.canNewest(ArchiveType.movie), isTrue);
    expect(service.rows(ArchiveType.movie).map((r) => r.title),
        containsAll(['Popular', 'New', 'Featured']));

    await service.setNewest(ArchiveType.movie, true);
    final rows = service.rows(ArchiveType.movie);
    expect(rows.map((r) => r.title), ['New', 'New']);
    expect(rows.map((r) => r.source.name), ['Torrentio', 'NoxAIO']);
    // The source's own Year catalog is asked for this year.
    expect(asked.any((a) => a.contains('aio.example/catalog/movie/tmdb.year')),
        isTrue);

    await service.setNewest(ArchiveType.movie, false);
    expect(service.rows(ArchiveType.movie).map((r) => r.title),
        contains('Popular'));
    service.dispose();
  });

  test('Newest with a genre keeps matching items; rows without genres drop',
      () async {
    final service = await _service([]);
    await service.setNewest(ArchiveType.movie, true);
    await service.setGenre(ArchiveType.movie, 'Action');
    final rows = service.rows(ArchiveType.movie);
    expect(rows, hasLength(1));
    expect(rows.single.source.name, 'Torrentio');
    expect(rows.single.items.map((m) => m.name), ['New Action']);
    // Back to all genres: both new releases, and NoxAIO's row returns.
    await service.setGenre(ArchiveType.movie, null);
    expect(service.rows(ArchiveType.movie).expand((r) => r.items).length, 3);
    service.dispose();
  });

  test('no release-year catalog, no Newest', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([
        const ArchiveSource(
          manifestUrl: 'https://plain.example/manifest.json',
          name: 'Plain',
          catalogs: [
            ArchiveCatalog(type: ArchiveType.movie, id: 'top', name: 'Popular'),
          ],
        ).toJson(),
      ]),
    });
    final storage = StorageService();
    await storage.init();
    final service = ArchiveService(storage, cache: _Cache());
    expect(service.canNewest(ArchiveType.movie), isFalse);
    service.dispose();
  });
}
