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

class _Cache extends ArchiveCache {
  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;

  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hide default rows and search, preserve own catalogs and streams',
      () async {
    final stream = ArchiveSource(
      manifestUrl: 'https://streams.example/manifest.json',
      name: 'Streams',
      catalogProviderUrl: ArchiveCatalogProvider.baseUrl,
      catalogs: ArchiveCatalogProvider.catalogsFor(ArchiveType.values),
    );
    const own = ArchiveSource(
      manifestUrl: 'https://catalog.example/manifest.json',
      name: 'My catalog',
      listOnly: true,
      catalogs: [
        ArchiveCatalog(
            type: ArchiveType.movie,
            id: 'mine',
            name: 'Mine',
            searchable: true,
            genres: ['Custom'])
      ],
    );
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources:
          jsonEncode([stream.toJson(), own.toJson()]),
    });
    final storage = StorageService();
    await storage.init();
    final requests = <Uri>[];
    final api = ArchiveApiService(client: MockClient((request) async {
      requests.add(request.url);
      return http.Response(
          jsonEncode(request.url.path.startsWith('/stream/')
              ? {
                  'streams': [
                    {'url': 'https://video.example/movie.mp4'}
                  ]
                }
              : request.url.path.startsWith('/meta/')
                  ? {
                      'meta': {
                        'id': 'tt1',
                        'type': 'movie',
                        'name': 'Test movie'
                      }
                    }
                  : {
                      'metas': [
                        {'id': 'tt1', 'type': 'movie', 'name': 'Test movie'}
                      ]
                    }),
          200);
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    addTearDown(service.dispose);
    expect(service.showCinemetaCatalog, isTrue);
    await service.refresh(force: true);
    expect(service.rows(ArchiveType.movie).length, 4);
    await service.search(ArchiveType.movie, 'Test');
    expect(service.rows(ArchiveType.movie).where((r) => r.isSearch).length, 2);

    await service.setShowCinemetaCatalog(false);
    expect(service.searchQuery(ArchiveType.movie), isNull);
    expect(service.rows(ArchiveType.movie).map((r) => r.title), ['Mine']);
    expect(service.rows(ArchiveType.series), isEmpty);
    expect(service.hasAny(ArchiveType.series), isFalse);
    expect(service.genres(ArchiveType.movie), ['Custom']);
    requests.clear();
    await service.refresh(force: true);
    final results = await service.searchRows(ArchiveType.movie, 'Test');
    expect(results.map((r) => r.source.name), ['My catalog']);
    expect(requests.every((u) => u.host == 'catalog.example'), isTrue);
    final preview = results.single.items.single;
    expect((await service.meta(own, preview))!.name, 'Test movie');
    expect((await service.streams(own, preview)).single.source.name, 'Streams');
    expect(service.enabledSources.length, 2);
    final reopened = ArchiveService(storage);
    expect(reopened.showCinemetaCatalog, isFalse);
    reopened.dispose();
    expect(storage.exportForTransfer(),
        contains(AppConstants.keyArchiveCinemetaCatalog));
    expect(storage.exportForTransfer(includeArchive: false),
        isNot(contains(AppConstants.keyArchiveCinemetaCatalog)));

    await service.setShowCinemetaCatalog(true);
    expect(service.rows(ArchiveType.movie).length, 4);
    expect(service.hasAny(ArchiveType.series), isTrue);
  });
}
