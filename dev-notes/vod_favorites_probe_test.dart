// Diagnostic probe for the 2026-10-22 VOD favourites report, not a desired-
// behaviour regression suite. These assertions capture the current defects.
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model the database's fresh objects and category LIMIT, without networking
// or a device database. Production PlaylistManager/PlaylistSession code runs.
class ProbeCatalog extends CatalogDatabase {
  final vodStars = <String>{};
  final seriesStars = <String>{};

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
        categoryId: 'shows',
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late ProbeCatalog db;
  late PlaylistManager manager;

  setUp(() async {
    // This executable diagnostic test lives outside test/ intentionally.
    // ignore: invalid_use_of_visible_for_testing_member
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

  test('Search/Expand copies save but leave browse favourites empty', () async {
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
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
    // Stale cached flags also make the next toggle fail to remove it:
    // the user sees the cached item unstarred, but its id is already saved.
    await manager.toggleFavorite(manager.allCachedVod.first);
    await manager.toggleSeriesFavorite(manager.allCachedSeries.first);
    expect(storage.getFavorites(), contains(movie.id));
    expect(storage.getFavoriteSeries(), contains(show.id));
  });

  test('item 301 saves but is absent even after restamping cached objects',
      () async {
    final movie = db.movie(301);
    final show = db.show(301);
    await manager.toggleFavorite(movie);
    await manager.toggleSeriesFavorite(show);
    manager.applyActiveViewer();
    expect(storage.getFavorites(), contains(movie.id));
    expect(storage.getFavoriteSeries(), contains(show.id));
    expect(manager.favoriteMovies, isEmpty);
    expect(manager.favoriteSeries, isEmpty);
  });
}
