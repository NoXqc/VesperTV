import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_discovery_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';

class _Cache extends ArchiveCache {
  @override
  Future<List<ArchiveMeta>> read(String source, ArchiveCatalog catalog) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('later catalog matches append instead of replacing the focused result',
      () async {
    const source = ArchiveSource(
        manifestUrl: 'https://catalog.example/manifest.json',
        name: 'Catalog',
        searchCatalogsChecked: true,
        catalogs: [
          ArchiveCatalog(
              type: ArchiveType.movie,
              id: 'first',
              name: 'First',
              searchable: true),
          ArchiveCatalog(
              type: ArchiveType.movie,
              id: 'late',
              name: 'Late',
              searchable: true)
        ]);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([source.toJson()])
    });
    final storage = StorageService();
    await storage.init();
    final late = Completer<http.Response>();
    final api = ArchiveApiService(
        client: MockClient((r) async => r.url.path.contains('/late/')
            ? await late.future
            : http.Response(
                '{"metas":[{"id":"tt1","type":"movie","name":"Spider 2"}]}',
                200)));
    final hub = ArchiveService(storage, api: api, cache: _Cache());
    final first = Completer<void>();
    hub.addListener(() {
      if (!first.isCompleted && hub.rows(ArchiveType.movie).isNotEmpty) {
        first.complete();
      }
    });
    final search = hub.search(ArchiveType.movie, 'Spider');
    await first.future;
    expect(hub.rows(ArchiveType.movie).single.items.first.id, 'tt1');
    hub.retainSearchFocus(hub.rows(ArchiveType.movie).single);
    late.complete(http.Response(
        '{"metas":[{"id":"tt2","type":"movie","name":"Spider"}]}', 200));
    await search;
    expect(hub.rows(ArchiveType.movie).single.items.map((m) => m.id),
        ['tt1', 'tt2']);
    hub.dispose();
    api.close();
  });
  test(
      'collections, recommendations and cast load on demand; identify only chosen title',
      () async {
    final requested = <String>[];
    final api = ArchiveDiscoveryService(client: MockClient((r) async {
      requested.add(r.url.path);
      final Object data = switch (r.url.path) {
        '/3/find/tt10' => {
            'movie_results': [
              {'id': 10}
            ]
          },
        '/3/movie/10' => {
            'credits': {
              'cast': [
                {'id': 99, 'name': 'Actor', 'character': 'Lead'}
              ]
            },
            'recommendations': {
              'results': [
                {'id': 20, 'title': 'Related', 'release_date': '2020-01-01'}
              ]
            },
            'belongs_to_collection': {'id': 100}
          },
        '/3/collection/100' => {
            'name': 'Franchise',
            'parts': [
              {'id': 10, 'title': 'Original'},
              {'id': 11, 'title': 'Sequel'}
            ]
          },
        '/3/movie/20/external_ids' => {'imdb_id': 'tt20'},
        '/3/person/99/combined_credits' => {
            'cast': [
              {'id': 20, 'title': 'Related', 'media_type': 'movie'},
              {'id': 30, 'name': 'A show', 'media_type': 'tv'},
              {'id': 40, 'title': 'Adult', 'media_type': 'movie', 'adult': true}
            ]
          },
        _ => {},
      };
      return http.Response(jsonEncode(data), 200);
    }));
    const meta =
        ArchiveMeta(id: 'tt10', name: 'Original', type: ArchiveType.movie);
    final result = await api.discover(meta, 'fixture-key', 'en');
    expect(result.collection.single.name, 'Sequel');
    expect(result.related.single.name, 'Related');
    expect(result.cast.single.role, 'Lead');
    expect(requested, isNot(contains('/3/movie/20/external_ids')));
    expect(
        (await api.identify(result.related.single, 'fixture-key', 'en')).imdb,
        'tt20');
    final credits = await api.credits(result.cast.single, 'fixture-key', 'en');
    expect(credits.map((m) => m.type), [ArchiveType.movie, ArchiveType.series]);
    api.dispose();
  });

  test(
      'search publishes fast catalogs while slow ones load and drops cleared results',
      () async {
    ArchiveSource source(String id) => ArchiveSource(
            manifestUrl: 'https://$id.example/manifest.json',
            name: id,
            searchCatalogsChecked: true,
            catalogs: const [
              ArchiveCatalog(
                  type: ArchiveType.movie,
                  id: 'movies',
                  name: 'Movies',
                  searchable: true)
            ]);
    final slow = source('slow'), fast = source('fast');
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([slow.toJson(), fast.toJson()])
    });
    final storage = StorageService();
    await storage.init();
    final blocked = Completer<http.Response>();
    final api = ArchiveApiService(
        client: MockClient((r) async => r.url.host == 'slow.example'
            ? await blocked.future
            : http.Response(
                '{"metas":[{"id":"tt1","type":"movie","name":"Spider"}]}',
                200)));
    final hub = ArchiveService(storage, api: api, cache: _Cache());
    final appeared = Completer<void>();
    hub.addListener(() {
      if (!appeared.isCompleted &&
          hub.rows(ArchiveType.movie).any((r) => r.isSearch)) {
        appeared.complete();
      }
    });
    final search = hub.search(ArchiveType.movie, 'Spider');
    await appeared.future;
    expect(hub.searching, true);
    expect(hub.rows(ArchiveType.movie).first.source.name, 'fast');
    hub.clearSearch(ArchiveType.movie);
    blocked.complete(http.Response(
        '{"metas":[{"id":"tt2","type":"movie","name":"Spider 2"}]}', 200));
    await search;
    expect(hub.searchQuery(ArchiveType.movie), null);
    expect(hub.rows(ArchiveType.movie), isEmpty);
    expect(hub.searching, false);
    hub.dispose();
    api.close();
  });
}
