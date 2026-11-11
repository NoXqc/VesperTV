import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/hub_collection.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The Vesper AI `collections` tool (owner, 2026-11-11: a user asked for
/// the connector to add / remove catalogs in the Media Hub collections).
class _Host implements VesperHost {
  final questions = <String>[];
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async {
    var s = question;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    questions.add(s);
    return true;
  }

  @override
  Future<void> playChannel(Channel channel) async {}
  @override
  Future<void> openSeries(XtreamSeries series) async {}
  @override
  Future<bool> openSection(String section, {String? query}) async => true;
  @override
  void showMessage(String text) {}
}

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
        type: ArchiveType.movie, id: 'streaming.top10.nfx', name: 'Top Ten'),
    ArchiveCatalog(
        type: ArchiveType.movie, id: 'mdblist.kids', name: 'Kids Movies'),
    ArchiveCatalog(
        type: ArchiveType.series, id: 'mdblist.kidsshows', name: 'Kids Shows'),
  ],
);

/// A file in the antonangel/nuvio-template shape: "movies" types.
final _file = [
  {
    'id': 'streaming',
    'title': '🎬 Streaming',
    'folders': [
      {
        'id': 'streaming.netflix',
        'title': 'Netflix',
        'catalogSources': [
          {
            'addonId': 'aio-metadata',
            'catalogId': 'tmdb.discover.movie.streaming.netflix',
            'type': 'movies'
          },
        ]
      },
      {
        'id': 'streaming.peacock',
        'title': 'Peacock',
        'catalogSources': [
          {'addonId': 'aio-metadata', 'catalogId': 'nowhere', 'type': 'movie'}
        ]
      },
    ]
  },
  {
    'id': 'decades',
    'title': 'Decades',
    'folders': [
      {
        'id': 'decades.80s',
        'title': '80s',
        'catalogSources': [
          {'addonId': 'aio-metadata', 'catalogId': 'x.80s', 'type': 'movie'}
        ]
      }
    ]
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VesperToolbox box;
  late ArchiveService hub;
  late _Host host;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([_aio.toJson()]),
    });
    final temp = await Directory.systemTemp.createTemp('vesper_coll_');
    addTearDown(() => temp.delete(recursive: true));
    final storage = StorageService();
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    final manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    final prefs = AppPreferences(storage);
    await prefs.init();
    hub = ArchiveService(storage,
        api: ArchiveApiService(
            client: MockClient((request) async =>
                http.Response.bytes(utf8.encode(jsonEncode(_file)), 200))),
        cache: _Cache());
    await hub.importCollections('https://x.example/c.json');
    host = _Host();
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: EpgService(storage),
      storage: storage,
      prefs: prefs,
      host: host,
      archive: hub,
    );
  });

  HubFolder tile(String name) => [for (final c in hub.collections) ...c.folders]
      .firstWhere((f) => f.title == name);

  test('"movies" in a collections file reads as movie', () {
    expect(tile('Netflix').sources.single.type, 'movie');
    expect(hub.folderCatalogs(tile('Netflix')), hasLength(1),
        reason: 'the plural used to find no catalog');
  });

  test('list and catalogs', () async {
    final all = await box.call('collections', {'action': 'list'});
    final rows = all['collections'] as List;
    expect([for (final r in rows) (r as Map)['collection']],
        ['Streaming', 'Decades']);
    expect((rows.first as Map)['tiles'],
        ['Netflix', 'Peacock (no catalogs found)']);

    final one = await box
        .call('collections', {'action': 'list', 'collection': 'streaming'});
    final netflix =
        ((one['collections'] as List).single as Map)['tiles'] as List;
    expect((netflix.first as Map)['catalogs_found'], 2,
        reason: 'its page also lists Netflix Shows, named after it');

    final kids =
        await box.call('collections', {'action': 'catalogs', 'query': 'kids'});
    expect([for (final c in kids['catalogs'] as List) (c as Map)['key']],
        ['movie:mdblist.kids', 'series:mdblist.kidsshows']);
  });

  test('add and remove catalogs on a tile', () async {
    var r = await box.call('collections', {
      'action': 'add_catalogs',
      'tile': 'netflix',
      'catalogs': [
        'movie:streaming.top10.nfx',
        'movie:tmdb.discover.movie.streaming.netflix',
        'tmdb.discover.series.streaming.netflix',
      ],
    });
    expect(r['added'], [
      'movie:streaming.top10.nfx',
      'series:tmdb.discover.series.streaming.netflix'
    ]);
    expect(r['already_there'], 1);
    expect(tile('Netflix').sources.map((s) => '${s.type}:${s.catalogId}'), [
      'movie:tmdb.discover.movie.streaming.netflix',
      'movie:streaming.top10.nfx',
      'series:tmdb.discover.series.streaming.netflix',
    ]);
    expect(tile('Netflix').sources[1].addonId, 'aio-metadata');
    expect(hub.folderCatalogs(tile('Netflix')), hasLength(3));

    r = await box.call('collections', {
      'action': 'remove_catalogs',
      'tile': 'Netflix',
      'catalogs': ['movie:streaming.top10.nfx'],
    });
    expect(r['left'], 2);

    r = await box.call('collections', {
      'action': 'add_catalogs',
      'tile': 'Netflix',
      'catalogs': ['movie:made.up'],
    });
    expect(r['error'], contains('Not in the add-ons'));
  });

  test('a new tile, in a new collection or an old one', () async {
    var r = await box.call('collections', {
      'action': 'create_tile',
      'collection': 'Kids',
      'name': 'Cartoons',
      'catalogs': ['movie:mdblist.kids', 'series:mdblist.kidsshows'],
    });
    expect(r['created'], true);
    expect(hub.collections.last.label, 'Kids');
    expect(hub.folderCatalogs(tile('Cartoons')), hasLength(2));

    r = await box.call('collections', {
      'action': 'create_tile',
      'collection': 'Streaming',
      'name': 'Top 10',
      'catalogs': ['movie:streaming.top10.nfx'],
    });
    expect(r['created'], isNull);
    expect(hub.collections.first.folders.map((f) => f.title),
        ['Netflix', 'Peacock', 'Top 10']);

    r = await box.call('collections',
        {'action': 'rename_tile', 'tile': 'Top 10', 'name': 'Top Ten'});
    expect(tile('Top Ten').sources, hasLength(1));
  });

  test('remove a tile asks on the TV for an AI app', () async {
    final r = await box.call(
        'collections', {'action': 'remove_tile', 'tile': 'Peacock'},
        caller: VesperCaller.remoteApp);
    expect(r['removed'], 'Peacock');
    expect(host.questions.single, contains('Peacock'));
    expect(hub.collections.first.folders.map((f) => f.title), ['Netflix']);

    // The last tile takes its collection with it.
    await box.call('collections', {'action': 'remove_tile', 'tile': '80s'});
    expect(hub.collections.map((c) => c.label), ['Streaming']);
  });

  test('turn off, Home, move, hide rows', () async {
    await box
        .call('collections', {'action': 'turn_off', 'collection': 'Decades'});
    expect(hub.collections.last.enabled, isFalse);

    final home = await box.call(
        'collections', {'action': 'home', 'collection': 'Decades', 'on': true});
    expect(home['note'], contains('turn_on'));
    expect(hub.collections.last.onHome, isTrue);

    final moved = await box.call('collections',
        {'action': 'move', 'collection': 'Decades', 'to': 'top'});
    expect(moved['position'], 1);
    expect(hub.collections.map((c) => c.label), ['Decades', 'Streaming']);

    await box.call('collections', {'action': 'hide_rows', 'on': false});
    expect(hub.collectionsHideRows, isFalse);

    final missing = await box
        .call('collections', {'action': 'turn_on', 'collection': 'Sports'});
    expect(missing['error'], contains('No collection'));
  });
}
