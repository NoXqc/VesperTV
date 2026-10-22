import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/utils/catalog_sort.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The Movies / TV Shows rows follow the Expand catalog sort (user: "Date
/// added/updated" in Expand, rows still in the provider's order). The rows
/// keep a category's first 300, so the database must hand them over in
/// that order — CatalogSort.orderBy, on the real column names.
void main() {
  sqfliteFfiInit();

  Channel movie(String name, {String? rating, int? added, int? released}) =>
      Channel(
        id: 'p::$name',
        rawId: name,
        playlistId: 'p',
        name: name,
        group: 'Movies',
        url: 'http://x/$name.mkv',
        rating: rating,
        addedAt:
            added == null ? null : DateTime.fromMillisecondsSinceEpoch(added),
        releaseDate: released == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(released),
      );

  final movies = [
    movie('beta', rating: '6.1', added: 2000, released: 10),
    movie('Alpha', rating: '', added: null, released: 30),
    movie('gamma', rating: '8.4', added: 3000, released: null),
    movie('Delta', rating: null, added: 1000, released: 20),
  ];

  Future<List<String>> sqlOrder(CatalogSort sort) async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE vod_channels (name TEXT NOT NULL, '
        'rating TEXT, added_at INTEGER, release_date INTEGER)');
    for (final m in movies) {
      await db.insert('vod_channels', {
        'name': m.name,
        'rating': m.rating,
        'added_at': m.addedAt?.millisecondsSinceEpoch,
        'release_date': m.releaseDate?.millisecondsSinceEpoch,
      });
    }
    final rows = await db.query('vod_channels', orderBy: sort.orderBy);
    await db.close();
    return rows.map((r) => r['name'] as String).toList();
  }

  List<String> dartOrder(CatalogSort sort) =>
      sortCatalogChannels(movies, sort).map((c) => c.name).toList();

  test('newest added first, unknown dates last', () async {
    expect(
        dartOrder(CatalogSort.addedDate), ['gamma', 'beta', 'Delta', 'Alpha']);
    expect(await sqlOrder(CatalogSort.addedDate),
        dartOrder(CatalogSort.addedDate));
  });

  test('the database agrees with the Expand grid for every sort', () async {
    for (final sort in CatalogSort.values.where((s) => s != CatalogSort.none)) {
      expect(await sqlOrder(sort), dartOrder(sort), reason: sort.name);
    }
  });

  test('default keeps the provider order; unknown saved value = default', () {
    expect(CatalogSort.none.orderBy, isNull);
    expect(dartOrder(CatalogSort.none), movies.map((m) => m.name).toList());
    expect(catalogSortFrom('addedDate'), CatalogSort.addedDate);
    expect(catalogSortFrom('bogus'), CatalogSort.none);
    expect(catalogSortFrom(null), CatalogSort.none);
  });
}
