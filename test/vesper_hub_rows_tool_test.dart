import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
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

/// The Vesper AI `hub_rows` tool: Customize Media Hub's switches for an AI
/// (owner, 2026-11-11: "tell my Claude MCP to hide anything I don't want").
class _Host implements VesperHost {
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async =>
      true;
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

ArchiveSource _addon(String name, String host) => ArchiveSource(
      manifestUrl: 'https://$host/abc/manifest.json',
      name: name,
      addonId: host,
      listOnly: true,
      catalogs: const [
        ArchiveCatalog(
            type: ArchiveType.movie, id: 'tmdb.top', name: 'TMDB Popular'),
        ArchiveCatalog(
            type: ArchiveType.movie, id: 'tmdb.trending', name: 'Trending'),
        ArchiveCatalog(
            type: ArchiveType.series, id: 'tmdb.top', name: 'TMDB Popular'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VesperToolbox box;
  late ArchiveService hub;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([
        _addon('AIOMetadata', 'aio.one').toJson(),
        _addon('Second AIO', 'aio.two').toJson(),
      ]),
    });
    final temp = await Directory.systemTemp.createTemp('vesper_rows_');
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
        api: ArchiveApiService(client: MockClient((request) async {
      final segs = request.url.pathSegments;
      final at = segs.indexOf('catalog');
      final id = segs[at + 2].split('.json').first;
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'metas': [
              {
                'id': 'tt${request.url.host}$id',
                'type': segs[at + 1],
                'name': 'Title of $id'
              }
            ]
          })),
          200);
    })), cache: _Cache());
    await hub.refresh(force: true);
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: EpgService(storage),
      storage: storage,
      prefs: prefs,
      host: _Host(),
      archive: hub,
    );
  });

  List<String> shown(ArchiveType type) => [
        for (final r in hub.rows(type)) '${r.title}|${r.source.name}',
      ];

  test('list, hide one add-on\'s row, show it again', () async {
    final list =
        await box.call('hub_rows', {'action': 'list', 'type': 'movies'});
    expect([for (final r in list['rows'] as List) (r as Map)['row']],
        ['TMDB Popular', 'Trending', 'TMDB Popular', 'Trending']);

    var r = await box.call('hub_rows', {
      'action': 'hide',
      'rows': ['tmdb popular'],
      'source': 'second',
    });
    expect(r['done'], [
      'TMDB Popular (movies, Second AIO)',
      'TMDB Popular (shows, Second AIO)'
    ]);
    expect(shown(ArchiveType.movie), [
      'TMDB Popular|AIOMetadata',
      'Trending|AIOMetadata',
      'Trending|Second AIO'
    ]);

    r = await box.call('hub_rows', {
      'action': 'show',
      'rows': ['TMDB Popular'],
      'type': 'shows',
    });
    expect(r['done'], hasLength(2),
        reason: 'no source: every row of that name');
    expect(shown(ArchiveType.series), hasLength(2));
    expect(shown(ArchiveType.movie), hasLength(3), reason: 'movies untouched');
  });

  test('pin, move, rename; several matches need a source', () async {
    var r = await box.call('hub_rows', {
      'action': 'move',
      'rows': ['Trending'],
      'type': 'movies',
    });
    expect(r['error'], contains('Several rows match'));

    r = await box.call('hub_rows', {
      'action': 'move',
      'rows': ['Trending'],
      'type': 'movies',
      'source': 'second',
      'to': 'top',
    });
    expect(shown(ArchiveType.movie).first, 'Trending|Second AIO');

    await box.call('hub_rows', {
      'action': 'pin',
      'rows': ['TMDB Popular'],
      'type': 'movies',
      'source': 'AIOMetadata',
    });
    expect(shown(ArchiveType.movie).first, 'TMDB Popular|AIOMetadata');

    await box.call('hub_rows', {
      'action': 'rename',
      'rows': ['TMDB Popular'],
      'type': 'movies',
      'source': 'AIOMetadata',
      'name': 'Popular now',
    });
    expect(shown(ArchiveType.movie).first, 'Popular now|AIOMetadata');

    r = await box.call('hub_rows', {
      'action': 'hide',
      'rows': ['Nope']
    });
    expect(r['error'], contains('No row named Nope'));
  });
}
