// Regression coverage for Search/Expand catalog favourites and browse limits.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model the database's fresh objects and category LIMIT, without networking
// or a device database. Production PlaylistManager/PlaylistSession code runs.
class ProbeCatalog extends CatalogDatabase {
  final vodStars = <String>{};
  final seriesStars = <String>{};
  Completer<void>? readGate;
  final querySizes = <int>[];

  Channel movie(int n) => Channel(
        id: 'probe::xt_vod_$n',
        rawId: 'xt_vod_$n',
        playlistId: 'probe',
        name: 'Movie $n',
        group: 'Movies',
        url: 'https://example.com/$n.mp4',
        isFavorite: vodStars.contains('probe::xt_vod_$n'),
      );

  XtreamSeries show(int n) => XtreamSeries(
        seriesId: n,
        playlistId: 'probe',
        name: 'Show $n',
        categoryId: 'Shows',
        isFavorite: seriesStars.contains('probe::series_$n'),
      );

  @override
  Future<List<Channel>> getVodCategory(String playlistId, String categoryName,
          {int? limit}) async =>
      List.generate(limit ?? 301, (i) => movie(i + 1));

  @override
  Future<List<XtreamSeries>> getSeriesCategory(
          String playlistId, String categoryName,
          {int? limit}) async =>
      List.generate(limit ?? 301, (i) => show(i + 1));

  @override
  Future<int> getVodCategoryCount(
          String playlistId, String categoryName) async =>
      301;

  @override
  Future<int> getSeriesCategoryCount(
          String playlistId, String categoryName) async =>
      301;

  @override
  Future<void> setVodFavorite(String id, bool value) async {
    value ? vodStars.add(id) : vodStars.remove(id);
  }

  @override
  Future<void> setSeriesFavorite(String id, bool value) async {
    value ? seriesStars.add(id) : seriesStars.remove(id);
  }

  @override
  Future<List<Channel>> getVodByIds(List<String> ids) async {
    querySizes.add(ids.length);
    await readGate?.future;
    return ids.map((id) => movie(int.parse(id.split('_').last))).toList();
  }

  @override
  Future<List<XtreamSeries>> getSeriesByIds(List<String> ids) async {
    querySizes.add(ids.length);
    await readGate?.future;
    return ids.map((id) => show(int.parse(id.split('_').last))).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late ProbeCatalog db;
  late PlaylistManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    db = ProbeCatalog();
    manager = PlaylistManager(storage, db);
    await manager.addPlaylist(PlaylistProfile(
      id: 'probe',
      name: 'Probe',
      mode: 'xtream',
      sortOrder: 0,
      createdAt: DateTime(2026),
    ));
    await manager.ensureCategoryLoaded('probe', 'Movies', 'vod');
    await manager.ensureCategoryLoaded('probe', 'Shows', 'series');
    expect(manager.allCachedVod, hasLength(300));
    expect(manager.allCachedSeries, hasLength(300));
  });

  tearDown(() => manager.dispose());

  test('control: normal browse objects appear in favourites', () async {
    await manager.toggleFavorite(manager.allCachedVod.first);
    await manager.toggleSeriesFavorite(manager.allCachedSeries.first);
    expect(manager.favoriteMovies.map((c) => c.id), ['probe::xt_vod_1']);
    expect(manager.favoriteSeries.map((s) => s.id), ['probe::series_1']);
  });

  test('Search/Expand copies synchronize; stale copies can remove favourites',
      () async {
    final movie = db.movie(1);
    final show = db.show(1);
    expect(identical(movie, manager.allCachedVod.first), isFalse);
    await manager.toggleFavorite(movie);
    await manager.toggleSeriesFavorite(show);
    expect(movie.isFavorite, isTrue);
    expect(show.isFavorite, isTrue);
    expect(storage.getFavorites(), contains(movie.id));
    expect(storage.getFavoriteSeries(), contains(show.id));
    expect(db.vodStars, contains(movie.id));
    expect(db.seriesStars, contains(show.id));
    expect(manager.favoriteMovies.map((c) => c.id), [movie.id]);
    expect(manager.favoriteSeries.map((s) => s.id), [show.id]);
    expect(manager.allCachedVod.first.isFavorite, isTrue);
    expect(manager.allCachedSeries.first.isFavorite, isTrue);
    await manager.toggleFavorite(db.movie(1)..isFavorite = false);
    await manager.toggleSeriesFavorite(db.show(1)..isFavorite = false);
    expect(storage.getFavorites(), isNot(contains(movie.id)));
    expect(storage.getFavoriteSeries(), isNot(contains(show.id)));
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
    expect(manager.allCachedVod.first.isFavorite, isFalse);
    expect(manager.allCachedSeries.first.isFavorite, isFalse);
  });

  test('item 301 stays visible without increasing browse caches', () async {
    final movie = db.movie(301);
    final show = db.show(301);
    await manager.toggleFavorite(movie);
    await manager.toggleSeriesFavorite(show);
    manager.applyActiveViewer();
    await manager.ensureFavoriteCatalogLoaded();
    expect(storage.getFavorites(), contains(movie.id));
    expect(storage.getFavoriteSeries(), contains(show.id));
    expect(manager.favoriteMovies.map((c) => c.id), [movie.id]);
    expect(manager.favoriteSeries.map((s) => s.id), [show.id]);
    expect(manager.allCachedVod, hasLength(300));
    expect(manager.allCachedSeries, hasLength(300));
  });

  test('restart resolves saved ids without loading categories or legacy bits',
      () async {
    await storage.setFavorites({'probe::xt_vod_301'});
    await storage.setFavoriteSeries({'probe::series_301'});
    final freshStorage = StorageService();
    await freshStorage.init();
    final fresh = PlaylistManager(freshStorage, db);
    await fresh.addPlaylist(manager.profiles.first);
    fresh.applyActiveViewer();
    await fresh.ensureFavoriteCatalogLoaded();
    expect(fresh.allCachedVod, isEmpty);
    expect(fresh.allCachedSeries, isEmpty);
    expect(fresh.favoriteMovies.single.id, 'probe::xt_vod_301');
    expect(fresh.favoriteSeries.single.id, 'probe::series_301');
    expect(fresh.favoriteMovies.single.isFavorite, isTrue);
    expect(fresh.favoriteSeries.single.isFavorite, isTrue);
    expect(db.vodStars, isEmpty);
    expect(db.seriesStars, isEmpty);
    fresh.dispose();
  });

  test('non-Main favourites survive switches without legacy DB writes',
      () async {
    await storage.setActiveViewerId('other');
    manager.applyActiveViewer();
    await manager.toggleFavorite(db.movie(301));
    await manager.toggleSeriesFavorite(db.show(301));
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies.single.id, 'probe::xt_vod_301');
    expect(manager.favoriteSeries.single.id, 'probe::series_301');
    expect(db.vodStars, isEmpty);
    expect(db.seriesStars, isEmpty);
    await storage.setActiveViewerId('main');
    manager.applyActiveViewer();
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
    await manager.ensureFavoriteCatalogLoaded();
    await storage.setActiveViewerId('other');
    manager.applyActiveViewer();
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, hasLength(1));
    expect(manager.favoriteSeries, hasLength(1));
  });

  test('hidden groups and disabled playlists exclude resolved favourites',
      () async {
    await manager.toggleFavorite(db.movie(301));
    await manager.toggleSeriesFavorite(db.show(301));
    await manager.ensureFavoriteCatalogLoaded();
    await manager.setGroupHidden('probe', 'Movies', true);
    await manager.setGroupHidden('probe', 'Shows', true);
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
    await manager.setGroupHidden('probe', 'Movies', false,
        loadImmediately: false);
    await manager.setGroupHidden('probe', 'Shows', false,
        loadImmediately: false);
    expect(manager.favoriteMovies, hasLength(1));
    expect(manager.favoriteSeries, hasLength(1));
    await manager
        .updatePlaylist(manager.profiles.first.copyWith(enabled: false));
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
    await manager
        .updatePlaylist(manager.profiles.first.copyWith(enabled: true));
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, hasLength(1));
    expect(manager.favoriteSeries, hasLength(1));
  });

  test('old viewer query cannot repopulate the next viewer', () async {
    await storage.setFavorites({'probe::xt_vod_301'});
    await storage.setFavoriteSeries({'probe::series_301'});
    db.readGate = Completer<void>();
    manager.applyActiveViewer();
    final oldLoad = manager.ensureFavoriteCatalogLoaded();
    await storage.setActiveViewerId('other');
    manager.applyActiveViewer();
    db.readGate!.complete();
    await oldLoad;
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
  });

  test(
      'restricted viewers cannot see saved titles in unloaded disallowed groups',
      () async {
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'kid',
          name: 'Kid',
          colorIndex: 1,
          isRestricted: true,
          createdAt: DateTime(2026)),
    ]);
    await storage.setActiveViewerId('kid');
    await storage.setFavorites({'probe::xt_vod_301'});
    await storage.setFavoriteSeries({'probe::series_301'});
    manager.applyActiveViewer();
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
    await storage.setShownGroups('probe', {'Movies', 'Shows'});
    manager.applyActiveViewer();
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, hasLength(1));
    expect(manager.favoriteSeries, hasLength(1));
  });

  test('clear favourites prevents an in-flight query restoring items',
      () async {
    await manager.toggleFavorite(db.movie(301));
    await manager.toggleSeriesFavorite(db.show(301));
    db.readGate = Completer<void>();
    final pending = manager.ensureFavoriteCatalogLoaded();
    await manager.clearFavorites('Movies', const []);
    await manager.clearFavorites('TV Shows', const []);
    db.readGate!.complete();
    await pending;
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
  });

  test('large favourite lists are queried in bounded batches and deduplicated',
      () async {
    await storage
        .setFavorites({for (var i = 1; i <= 1001; i++) 'probe::xt_vod_$i'});
    await storage.setFavoriteSeries(
        {for (var i = 1; i <= 1001; i++) 'probe::series_$i'});
    manager.applyActiveViewer();
    await manager.ensureFavoriteCatalogLoaded();
    expect(manager.favoriteMovies, hasLength(1001));
    expect(manager.favoriteSeries, hasLength(1001));
    expect(db.querySizes.every((size) => size <= 400), isTrue);
    final count = db.querySizes.length;
    await manager.ensureFavoriteCatalogLoaded();
    expect(db.querySizes, hasLength(count));
  });
}
