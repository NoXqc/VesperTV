import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/hub_collection.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Media Hub collections (owner, 2026-11-11): Nuvio's collections file,
/// tiles resolved against the user's own add-on catalogs.
class _Cache extends ArchiveCache {
  @override
  Future<List<ArchiveMeta>> read(
          String sourceKey, ArchiveCatalog catalog) async =>
      const [];

  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;

  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

/// The newer export (Nuvio Perfect Collections' shape).
final _perfect = [
  {
    'id': 'collections.streaming',
    'title': '🎬 Streaming',
    'showAllTab': true,
    'folders': [
      {
        'id': 'collections.streaming.netflix',
        'title': 'Netflix',
        'tileShape': 'LANDSCAPE',
        'hideTitle': false,
        'focusGifEnabled': true,
        'coverImageUrl': 'https://cdn.example/cover/netflix.webp',
        'focusGifUrl': 'https://cdn.example/focused/netflix.webp',
        'titleLogoUrl': 'https://cdn.example/title/netflix.webp',
        'heroBackdropUrl': 'https://cdn.example/backdrop/netflix.webp',
        'catalogSources': [
          {
            'addonId': 'aio-metadata',
            'catalogId': 'tmdb.discover.movie.streaming.netflix',
            'type': 'movie',
            'genre': 'None'
          },
          {
            'addonId': 'aio-metadata',
            'catalogId': 'tmdb.discover.series.streaming.netflix',
            'type': 'series',
            'genre': 'None'
          }
        ]
      },
      {
        'id': 'collections.streaming.missing',
        'title': 'Not installed',
        'tileShape': 'POSTER',
        'focusGifEnabled': false,
        'focusGifUrl': 'https://cdn.example/focused/x.webp',
        'catalogSources': [
          {'addonId': 'aio-metadata', 'catalogId': 'nowhere', 'type': 'movie'}
        ]
      },
      {'id': 'empty', 'title': 'No sources', 'catalogSources': []},
    ]
  }
];

/// The older export: `sources`, a `provider`, a genre.
final _older = {
  'collections': [
    {
      'id': 'collection-horror',
      'title': 'Horror genre',
      'folders': [
        {
          'id': 'folder-1',
          'title': 'Latest Horror shows',
          'sources': [
            {
              'type': 'movie',
              'genre': 'Horror',
              'addonId': 'aio-metadata',
              'provider': 'addon',
              'catalogId': 'mdblist.128046'
            },
            {
              'type': 'movie',
              'provider': 'tmdb',
              'catalogId': 'elsewhere',
              'addonId': ''
            }
          ]
        }
      ]
    }
  ]
};

const _aio = ArchiveSource(
  manifestUrl: 'https://aio.example/abc/manifest.json',
  name: 'AIOMetadata',
  addonId: 'aio-metadata',
  listOnly: true,
  catalogs: [
    ArchiveCatalog(
        type: ArchiveType.movie,
        id: 'tmdb.discover.movie.streaming.netflix',
        name: 'Netflix Movies'),
    ArchiveCatalog(
        type: ArchiveType.series,
        id: 'tmdb.discover.series.streaming.netflix',
        name: 'Netflix Shows'),
    ArchiveCatalog(
        type: ArchiveType.movie,
        id: 'mdblist.128046',
        name: 'Latest horror',
        genres: ['Horror', 'Comedy']),
  ],
);

Future<(ArchiveService, List<Uri>)> _service(
    {ArchiveSource source = _aio, Object? file}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([source.toJson()]),
  });
  final storage = StorageService();
  await storage.init();
  final requests = <Uri>[];
  final api = ArchiveApiService(client: MockClient((request) async {
    requests.add(request.url);
    final segs = request.url.pathSegments;
    final at = segs.indexOf('catalog');
    if (at < 0) {
      return http.Response.bytes(
          utf8.encode(jsonEncode(file ?? _perfect)), 200);
    }
    // /abc/catalog/<type>/<id>[/genre=…].json -> one title named after it.
    final type = segs[at + 1];
    final id = segs[at + 2].split('.json').first;
    return http.Response.bytes(
        utf8.encode(jsonEncode({
          'metas': [
            {'id': 'tt$id', 'type': type, 'name': 'Title of $id'}
          ]
        })),
        200);
  }));
  final service = ArchiveService(storage, api: api, cache: _Cache());
  return (service, requests);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collections file', () {
    test('reads the newer export: tiles, pictures, shapes', () {
      final list = HubCollection.parseExport(_perfect);
      expect(list, hasLength(1));
      final c = list.single;
      expect(c.title, '🎬 Streaming');
      expect(c.label, 'Streaming', reason: 'the row header drops the emoji');
      expect(c.folders.map((f) => f.title), ['Netflix', 'Not installed'],
          reason: 'a folder without catalogs is left out');
      final netflix = c.folders.first;
      expect(netflix.shape, HubTileShape.landscape);
      expect(netflix.coverUrl, 'https://cdn.example/cover/netflix.webp');
      expect(netflix.focusUrl, 'https://cdn.example/focused/netflix.webp');
      expect(netflix.sources.map((s) => s.catalogId), [
        'tmdb.discover.movie.streaming.netflix',
        'tmdb.discover.series.streaming.netflix'
      ]);
      expect(netflix.sources.first.genre, isNull, reason: '"None" = no genre');
      expect(c.folders[1].shape, HubTileShape.poster);
      expect(c.folders[1].focusUrl, isNull,
          reason: 'focusGifEnabled false: the tile stays still');
    });

    test('reads the older export and survives a save', () {
      final c = HubCollection.parseExport(_older).single;
      final f = c.folders.single;
      expect(f.sources, hasLength(1), reason: 'only add-on catalogs');
      expect(f.sources.single.genre, 'Horror');
      final again = HubCollection.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
      expect(again.folders.single.sources.single.genre, 'Horror');
      expect(again.folders.single.title, 'Latest Horror shows');
      expect(HubCollection.parseExport({'title': 'x'}), isEmpty);
      expect(HubCollection.parseExport('not json'), isEmpty);
    });

    test('links: GitHub pages as raw files, manifests are not collections', () {
      expect(
          HubCollection.rawLink(
              'https://github.com/me/setup/blob/main/templates/c.json'),
          'https://raw.githubusercontent.com/me/setup/main/templates/c.json');
      expect(HubCollection.isFileLink('https://x.example/c.json'), isTrue);
      expect(HubCollection.isFileLink('https://x.example/c.json?v=2'), isTrue);
      expect(
          HubCollection.isFileLink('https://x.example/manifest.json'), isFalse);
      expect(HubCollection.isFileLink('https://x.example/page'), isFalse);
    });
  });

  group('service', () {
    test('import, tile rows from installed catalogs, folder rows', () async {
      final (service, requests) = await _service();
      addTearDown(service.dispose);
      final n = await service
          .importCollections('https://github.com/me/setup/blob/main/c.json');
      expect(n, 1);
      expect(requests.first.host, 'raw.githubusercontent.com');
      expect(service.collections.single.link,
          'https://raw.githubusercontent.com/me/setup/main/c.json');

      final rows = service.collectionRows(ArchiveType.movie);
      expect(rows, hasLength(1));
      expect(rows.single.customTitle, 'Streaming');
      expect(rows.single.key, 'collection|collections.streaming');
      expect(rows.single.folders.map((f) => f.title), ['Netflix'],
          reason: "a tile whose catalogs aren't installed is left out");
      expect(service.collectionRows(ArchiveType.series), hasLength(1),
          reason: 'tiles show under Movies and TV Shows');

      final netflix = rows.single.folders.single;
      expect(service.folderRows(netflix), isEmpty);
      await service.loadFolder(netflix);
      final page = service.folderRows(netflix);
      expect(page.map((r) => r.title), ['Netflix Movies', 'Netflix Shows']);
      expect(page.first.items.single.name,
          'Title of tmdb.discover.movie.streaming.netflix');
      expect(service.folderLoading(netflix), isFalse);

      // The tab can leave the tiles' catalogs out of its rows.
      await service.refresh(force: true);
      final keys = service.collectionRowKeys();
      final main = service.rows(ArchiveType.movie).map((r) => r.key).toSet();
      expect(main.intersection(keys), isNotEmpty);
      expect(service.collectionsHideRows, isTrue);
      await service.setCollectionsHideRows(false);
      expect(service.collectionsHideRows, isFalse);
    });

    test('switch, order, re-import keeps the switch, remove', () async {
      final (service, _) = await _service();
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/a.json');
      await service.setCollectionEnabled('collections.streaming', false);
      expect(service.collectionRows(ArchiveType.movie), isEmpty);
      await service.importCollections('https://x.example/a.json');
      expect(service.collections, hasLength(1), reason: 'same id: updated');
      expect(service.collections.single.enabled, isFalse);

      await service.setCollectionEnabled('collections.streaming', true);
      expect(service.collectionRows(ArchiveType.movie), hasLength(1));
      await service.removeCollection('collections.streaming');
      expect(service.collections, isEmpty);
      expect(service.collectionRows(ArchiveType.movie), isEmpty);
    });

    test('adding a removed collection again brings its switches back',
        () async {
      // Owner, 2026-11-11: removing the pack and adding it again lost
      // Streaming's Show on Home.
      final (service, _) = await _service();
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/a.json');
      await service.setCollectionOnHome('collections.streaming', true);
      await service.removeCollection('collections.streaming');
      expect(service.rememberedCollectionIds, {'collections.streaming'});

      await service.importCollections('https://x.example/a.json');
      expect(service.collections.single.onHome, isTrue);
      expect(service.collections.single.enabled, isTrue);
      expect(service.rememberedCollectionIds, isEmpty,
          reason: 'used once, then forgotten');

      await service.setCollectionEnabled('collections.streaming', false);
      await service.removeCollection('collections.streaming');
      await service.importCollections('https://x.example/a.json');
      expect(service.collections.single.enabled, isFalse,
          reason: 'an off collection comes back off');
    });

    test('a genre narrows the catalog; no manifest id still matches', () async {
      final old = ArchiveSource(
          manifestUrl: _aio.manifestUrl,
          name: _aio.name,
          listOnly: true,
          catalogs: _aio.catalogs);
      final (service, _) = await _service(source: old, file: _older);
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/horror.json');
      final folder = service.collections.single.folders.single;
      final found = service.folderCatalogs(folder);
      expect(found, hasLength(1),
          reason: 'saved before its manifest id was read');
      expect(found.single.$2.extra, {'genre': 'Horror'});
      await service.loadFolder(folder);
      expect(service.folderRows(folder).single.catalog.slug,
          'mdblist.128046?genre=Horror');
    });

    test("the tab's refresh leaves the tiles' catalogs to their page",
        () async {
      final (service, requests) = await _service();
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/a.json');
      bool asked(String id) => requests.any((u) => u.path.contains(id));
      requests.clear();
      await service.refresh(force: true);
      expect(asked('streaming.netflix'), isFalse,
          reason: 'loaded when the Netflix tile opens');
      expect(asked('mdblist.128046'), isTrue, reason: 'in no collection');
      await service.setCollectionsHideRows(false);
      requests.clear();
      await service.refresh(force: true);
      expect(asked('streaming.netflix'), isTrue,
          reason: 'shown as rows again: the tab loads them');
    });

    test('catalogs kept off the home screen: tiles only, asked without genre',
        () async {
      // AIOMetadata set to "not in home": a required genre ("None" first).
      final manifest = {
        'id': 'aio-metadata',
        'name': 'AIOMetadata',
        'resources': ['catalog', 'meta'],
        'types': ['movie', 'series'],
        'idPrefixes': ['tt'],
        'catalogs': [
          {
            'id': 'tmdb.discover.movie.streaming.netflix',
            'type': 'movie',
            'name': '🎬 Netflix',
            'extra': [
              {
                'name': 'genre',
                'options': ['None', 'Action'],
                'isRequired': true
              },
              {'name': 'skip'}
            ],
            'showInHome': false
          },
          {
            'id': 'tmdb.discover.series.streaming.netflix',
            'type': 'series',
            'name': '🎬 Netflix',
            'extraRequired': ['genre'],
          },
          {
            'id': 'aiom.similar',
            'type': 'movie',
            'name': 'Similar',
            'extra': [
              {'name': 'similar', 'isRequired': true}
            ]
          },
          {'id': 'tmdb.trending', 'type': 'movie', 'name': 'Trending'},
        ],
      };
      final api = ArchiveApiService(
          client: MockClient((r) async =>
              http.Response.bytes(utf8.encode(jsonEncode(manifest)), 200)));
      final source =
          await api.fetchManifest('https://aio.example/abc/manifest.json');
      expect(source.addonId, 'aio-metadata');
      expect(
          source.catalogs.map((c) => (c.id, c.homeHidden)),
          [
            ('tmdb.discover.movie.streaming.netflix', true),
            ('tmdb.discover.series.streaming.netflix', true),
            ('tmdb.trending', false),
          ],
          reason: 'a required extra other than genre/search is still skipped');
      expect(source.catalogs.first.genres, isEmpty,
          reason: 'its required genre list is no genre filter');
      final saved = ArchiveSource.fromJson(
          jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>);
      expect(saved.catalogs.first.homeHidden, isTrue);

      final (service, requests) = await _service(source: saved);
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/a.json');
      requests.clear();
      await service.setCollectionsHideRows(false);
      await service.refresh(force: true);
      expect(service.rows(ArchiveType.movie).map((r) => r.catalog.id),
          ['tmdb.trending'],
          reason: 'never a row, even with the rows switch off');
      expect(
          requests.any((u) => u.path.contains('streaming.netflix')), isFalse);
      final tiles = service.collectionRows(ArchiveType.movie);
      expect(tiles.single.folders.map((f) => f.title), ['Netflix']);
      await service.loadFolder(tiles.single.folders.single);
      expect(
          requests
              .where((u) => u.path.contains('streaming.netflix'))
              .map((u) => u.pathSegments.last),
          containsAll([
            'tmdb.discover.movie.streaming.netflix.json',
            'tmdb.discover.series.streaming.netflix.json'
          ]));
      expect(service.folderRows(tiles.single.folders.single), hasLength(2));
    });

    test("a tile's page adds its add-on's catalogs named after it", () async {
      const aio = ArchiveSource(
        manifestUrl: 'https://aio.example/abc/manifest.json',
        name: 'AIOMetadata',
        addonId: 'aio-metadata',
        listOnly: true,
        catalogs: [
          ArchiveCatalog(
              type: ArchiveType.movie,
              id: 'tmdb.discover.movie.streaming.netflix',
              name: '🎬 Netflix',
              homeHidden: true),
          ArchiveCatalog(
              type: ArchiveType.series,
              id: 'tmdb.discover.series.streaming.netflix',
              name: '🎬 Netflix',
              homeHidden: true),
          ArchiveCatalog(
              type: ArchiveType.series, id: 'top10.nf', name: 'Netflix Top 10'),
          ArchiveCatalog(
              type: ArchiveType.movie,
              id: 'latest.nf',
              name: 'Latest on Netflix'),
          ArchiveCatalog(
              type: ArchiveType.movie, id: 'nfx', name: 'Netflixing around'),
          ArchiveCatalog(
              type: ArchiveType.movie,
              id: 'dp',
              name: 'Latest Disney+ (Movies)'),
        ],
      );
      final (service, _) = await _service(source: aio);
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/a.json');
      final netflix = service.collections.single.folders.first;
      expect(service.folderExtras(netflix).map((sc) => sc.$2.id),
          ['top10.nf', 'latest.nf'],
          reason: 'whole word only: not "Netflixing", not Disney+');
      expect(service.folderPageCatalogs(netflix), hasLength(4));
      await service.refresh(force: true);
      expect(service.rows(ArchiveType.movie).map((r) => r.catalog.id),
          unorderedEquals(['nfx', 'dp']),
          reason: 'Latest on Netflix now lives on the Netflix tile');
      final latest = ArchiveRow(
          source: aio,
          catalog: aio.catalogs.firstWhere((c) => c.id == 'latest.nf'),
          items: const []);
      expect(service.collectionRowKeys(), contains(latest.key));
      await service.loadFolder(netflix);
      expect(service.folderRows(netflix).map((r) => r.catalog.id), [
        'tmdb.discover.movie.streaming.netflix',
        'tmdb.discover.series.streaming.netflix',
        'top10.nf',
        'latest.nf'
      ]);
    });

    test('a file without collections is refused', () async {
      final (service, _) = await _service(file: {'hello': 'world'});
      addTearDown(service.dispose);
      await expectLater(service.importCollections('https://x.example/a.json'),
          throwsA(isA<ArchiveApiException>()));
      await expectLater(service.importCollections('not a link'),
          throwsA(isA<ArchiveApiException>()));
      expect(service.collections, isEmpty);
    });

    test('tiles step aside while searching', () async {
      final (service, _) = await _service();
      addTearDown(service.dispose);
      await service.importCollections('https://x.example/a.json');
      expect(service.collectionRows(ArchiveType.movie), hasLength(1));
      await service.search(ArchiveType.movie, 'Title');
      expect(service.collectionRows(ArchiveType.movie), isEmpty);
    });
  });
}
