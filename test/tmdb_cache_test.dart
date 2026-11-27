import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/tmdb_enrichment_service.dart';
import 'package:nox_iptv/services/watch_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Channel _movie(String id, String name, {String? tmdb}) => Channel(
    id: 'p::xt_vod_$id',
    rawId: 'xt_vod_$id',
    playlistId: 'p',
    name: name,
    group: 'Movies',
    url: 'https://provider.test/movie/$id.mkv',
    onDemand: true,
    tmdbId: tmdb);

/// Owner, 2026-11-26: Expand catalog's TMDB sort ("Fetching TMDB release
/// dates... x/y") took forever and started over at every open. A content
/// update rewrote each category's rows (losing every answer), titles TMDB
/// doesn't have were searched again each time, and a search hit cost a
/// second request.
void main() {
  sqfliteFfiInit();
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late CatalogDatabase catalog;
  late StorageService storage;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-tmdb-');
    catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    await storage.setTmdbApiKey('KEY');
  });
  tearDown(() async {
    await catalog.close();
    await temp.delete(recursive: true);
  });

  group('a content update keeps what TMDB gave', () {
    test('movies: date, posters, when asked; the provider id is fresh',
        () async {
      await catalog.upsertVodCategory(
          'p', 'Movies', [_movie('1', 'Heat'), _movie('2', 'Nowhere')]);
      await catalog.setVodTmdb('p::xt_vod_1',
          releaseDate: DateTime(1995, 12, 15),
          posterUrl: 'https://image.tmdb.org/t/p/w500/h.jpg',
          backdropUrl: 'https://image.tmdb.org/t/p/w1280/hb.jpg',
          checkedMs: 1000);
      await catalog.setVodTmdb('p::xt_vod_2', checkedMs: 2000);
      await catalog.setVodProviderImages('p::xt_vod_1',
          posterUrl: 'https://provider.test/big.jpg');

      // Update Content: the provider's list again, now with an id for Heat.
      await catalog.upsertVodCategory('p', 'Movies', [
        _movie('1', 'Heat', tmdb: '949'),
        _movie('2', 'Nowhere'),
        _movie('3', 'New one'),
      ]);
      final rows = {
        for (final c in await catalog.getVodCategory('p', 'Movies')) c.rawId: c
      };
      final heat = rows['xt_vod_1']!;
      expect(heat.releaseDate, DateTime(1995, 12, 15));
      expect(heat.posterUrl, 'https://image.tmdb.org/t/p/w500/h.jpg');
      expect(heat.backdropUrl, 'https://image.tmdb.org/t/p/w1280/hb.jpg');
      expect(heat.providerPosterUrl, 'https://provider.test/big.jpg');
      expect(heat.tmdbCheckedMs, 1000);
      expect(heat.tmdbId, '949');
      expect(rows['xt_vod_2']!.tmdbCheckedMs, 2000);
      expect(rows['xt_vod_3']!.tmdbCheckedMs, isNull);
    });

    test('shows too', () async {
      XtreamSeries show() => XtreamSeries(
          seriesId: 7, playlistId: 'p', name: 'Andor', categoryId: 'Shows');
      await catalog.upsertSeriesCategory('p', 'Shows', [show()]);
      await catalog.setSeriesTmdb('p::series_7',
          releaseDate: DateTime(2022, 9, 21),
          posterUrl: 'https://image.tmdb.org/t/p/w500/a.jpg',
          checkedMs: 3000);
      await catalog.upsertSeriesCategory('p', 'Shows', [show()]);
      final andor = (await catalog.getSeriesCategory('p', 'Shows')).single;
      expect(andor.releaseDate, DateTime(2022, 9, 21));
      expect(andor.posterUrl, 'https://image.tmdb.org/t/p/w500/a.jpg');
      expect(andor.tmdbCheckedMs, 3000);
    });

    test('an M3U import too', () async {
      final heat = _movie('1', 'Heat');
      await catalog.writeM3uRows(
          vod: [CatalogDatabase.vodRow('Movies', heat, importMark: 1)]);
      await catalog.finishM3uImport('p', 1);
      await catalog.setVodTmdb(heat.id,
          releaseDate: DateTime(1995, 12, 15), checkedMs: 1000);
      await catalog.writeM3uRows(vod: [
        CatalogDatabase.vodRow('Movies', _movie('1', 'Heat'), importMark: 2)
      ]);
      await catalog.finishM3uImport('p', 2);
      final row = (await catalog.getVodCategory('p', 'Movies')).single;
      expect(row.releaseDate, DateTime(1995, 12, 15));
      expect(row.tmdbCheckedMs, 1000);
    });
  });

  group('lookups', () {
    late List<String> asked;
    var now = DateTime(2026, 11, 26);

    TmdbEnrichmentService service() => TmdbEnrichmentService(storage, catalog,
        now: () => now,
        client: MockClient((req) async {
          final path = req.url.path.replaceFirst('/3/', '');
          final query = req.url.queryParameters['query'];
          asked.add(query == null ? path : '$path?$query');
          Object? body;
          switch ((path, query)) {
            case ('search/movie', 'Heat'):
              body = {
                'results': [
                  {
                    'id': 949,
                    'release_date': '1995-12-15',
                    'poster_path': '/h.jpg',
                    'backdrop_path': '/hb.jpg'
                  }
                ]
              };
            case ('search/movie', 'Nowhere'):
              body = {'results': []};
            case ('movie/603', null):
              body = {'release_date': '1999-03-31', 'poster_path': '/m.jpg'};
            case ('search/movie', 'The Matrix Reloaded'):
              body = {
                'results': [
                  {'release_date': '2003-05-15', 'poster_path': '/r.jpg'}
                ]
              };
            case ('movie/99999999', null):
              return http.Response('{}', 404);
            case ('search/movie', 'Broken'):
              return http.Response('oops', 500);
          }
          if (body == null) return http.Response('{}', 404);
          return http.Response(jsonEncode(body), 200);
        }));

    Future<List<Channel>> saved() => catalog.getVodCategory('p', 'Movies');

    Future<void> settle() async {
      // The answers are saved without holding up the next lookup.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    setUp(() async {
      asked = [];
      now = DateTime(2026, 11, 26);
      await catalog.upsertVodCategory('p', 'Movies', [
        _movie('1', 'FR - Heat'),
        _movie('2', 'Nowhere'),
        _movie('3', 'The Matrix', tmdb: '603'),
        _movie('4', 'The Matrix Reloaded', tmdb: '99999999'),
        _movie('5', 'Broken'),
      ]);
    });

    test('one request per title, answers kept, misses remembered', () async {
      final items = await saved();
      final progress = <int>[];
      await service().enrichVod(items, onProgress: (d, _) => progress.add(d));
      expect(progress.last, 5);
      expect(asked..sort(), [
        'movie/603',
        'movie/99999999', // not TMDB's id: then the title
        'search/movie?Broken',
        'search/movie?Heat', // no details request after a search hit
        'search/movie?Nowhere',
        'search/movie?The Matrix Reloaded',
      ]);
      final heat = items.firstWhere((c) => c.rawId == 'xt_vod_1');
      expect(heat.releaseDate, DateTime(1995, 12, 15));
      expect(heat.posterUrl, 'https://image.tmdb.org/t/p/w500/h.jpg');
      expect(heat.backdropUrl, 'https://image.tmdb.org/t/p/w1280/hb.jpg');
      expect(heat.tmdbId, isNull,
          reason: 'a searched id never becomes the provider id Trakt trusts');
      await settle();

      // The next open (fresh rows from the database): only Broken again.
      asked.clear();
      await service().enrichVod(await saved());
      expect(asked, ['search/movie?Broken']);

      // A month later the titles TMDB had nothing for are asked again.
      now = now.add(const Duration(days: 31));
      asked.clear();
      await service().enrichVod(await saved());
      expect(asked..sort(), ['search/movie?Broken', 'search/movie?Nowhere']);
    });

    test('the rule', () {
      final now = DateTime(2026, 11, 26);
      final day = const Duration(days: 1).inMilliseconds;
      final ms = now.millisecondsSinceEpoch;
      bool needs(DateTime? d, String? p, int? at) =>
          TmdbEnrichmentService.needsLookup(d, p, at, now);
      expect(needs(null, null, null), isTrue);
      expect(needs(DateTime(2020), 'p', null), isFalse);
      expect(needs(null, null, ms - day), isFalse);
      expect(needs(null, null, ms - 31 * day), isTrue);
      expect(needs(DateTime(2020), null, ms - day), isFalse);
    });
  });

  group('Trakt / Simkl without the movie page', () {
    test("a provider movie's own TMDB id", () {
      expect(WatchTracker.providerMovieTmdb(_movie('1', 'Heat', tmdb: '949')),
          '949');
      expect(WatchTracker.providerMovieTmdb(_movie('1', 'Heat')), isNull);
      expect(WatchTracker.providerMovieTmdb(_movie('1', 'Heat', tmdb: '0')),
          isNull);
      final episode = Channel(
          id: 'p::xt_ep_5',
          rawId: 'xt_ep_5',
          playlistId: 'p',
          name: 'S01E01',
          group: 'Andor',
          url: 'https://provider.test/series/5.mkv',
          onDemand: true,
          tmdbId: '83867');
      expect(WatchTracker.providerMovieTmdb(episode), isNull);
    });

    test('a play started elsewhere is registered', () async {
      final heat = _movie('42', 'Heat', tmdb: '949');
      expect(WatchTracker.instance.isTracked(heat.id), isFalse);
      await WatchTracker.instance.startedChannel(heat);
      expect(WatchTracker.instance.isTracked(heat.id), isTrue);
      expect(WatchTracker.instance.itemFor(heat.id)!.tmdb, '949');
      final live = Channel(
          id: 'p::espn',
          rawId: 'espn',
          playlistId: 'p',
          name: 'ESPN',
          group: 'Sports',
          url: 'https://provider.test/live/1.ts');
      await WatchTracker.instance.startedChannel(live);
      expect(WatchTracker.instance.isTracked(live.id), isFalse);
    });
  });
}
