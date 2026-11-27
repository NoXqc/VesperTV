import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/tmdb_enrichment_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// cillfog (Discord, 2026-11-26): with a TMDB key, "Refresh what's new now"
/// put "The Odyssey" (2026)'s poster on "The Navigator: A Medieval Odyssey
/// (1988)", "Hexed" (2026)'s on "Hexed (1993)" and "Steps" (2026)'s on "The
/// Fantastic 4: First Steps (2025)": the first catalog search hit won.
void main() {
  bool same(String name, String title,
          {int? year,
          String id = '1',
          String? original,
          String? otherTmdb,
          DateTime? otherDate}) =>
      TmdbEnrichmentService.sameTitle(
          tmdbId: id,
          tmdbTitle: title,
          originalTitle: original,
          tmdbYear: year,
          name: name,
          otherTmdb: otherTmdb,
          otherDate: otherDate);

  group('sameTitle', () {
    test('cillfog\'s three wrong matches are refused', () {
      expect(
          same('The Navigator: A Medieval Odyssey - 1988', 'The Odyssey',
              year: 2026),
          isFalse);
      expect(same('Hexed (1993)', 'Hexed', year: 2026), isFalse);
      expect(
          same('EN - The Fantastic 4: First Steps (2025)', 'Steps', year: 2026),
          isFalse);
    });

    test('the real titles still match', () {
      expect(
          same('EN - The Fantastic 4: First Steps (2025)',
              'The Fantastic 4: First Steps',
              year: 2025),
          isTrue);
      expect(
          same('4K-EN - Wicked: For Good (2025)', 'Wicked: For Good',
              year: 2025),
          isTrue);
      expect(same('Wicked: For Good - 2025', 'Wicked: For Good', year: 2025),
          isTrue);
      expect(same('Hexed', 'Hexed', year: 2026), isTrue);
      // A provider a year off (a festival vs a cinema release).
      expect(same('Sinners (2024)', 'Sinners', year: 2025), isTrue);
    });

    test('the name\'s year beats a date an earlier match stamped', () {
      expect(
          same('Hexed (1993)', 'Hexed',
              year: 2026, otherTmdb: '1', otherDate: DateTime(2026, 2, 6)),
          isFalse);
    });

    test('a different TMDB id on the catalog side is another film', () {
      expect(same('Hexed', 'Hexed', year: 2026, otherTmdb: '99'), isFalse);
      expect(same('Hexed', 'Hexed', year: 2026, otherTmdb: '1'), isTrue);
    });

    test('the original title counts too', () {
      expect(same('KR - 기생충 (2019)', 'Parasite', original: '기생충', year: 2019),
          isTrue);
    });

    test('years in names', () {
      expect(TmdbEnrichmentService.yearInName('Hexed (1993)'), 1993);
      expect(TmdbEnrichmentService.yearInName('Title [2025]'), 2025);
      expect(
          TmdbEnrichmentService.yearInName(
              'The Navigator: A Medieval Odyssey - 1988'),
          1988);
      expect(TmdbEnrichmentService.yearInName('Blade Runner 2049'), isNull);
    });
  });

  group('clearVodTmdb', () {
    sqfliteFfiInit();
    late Directory temp;
    late CatalogDatabase catalog;
    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      temp = await Directory.systemTemp.createTemp('vesper-whatsnew-');
      catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    });
    tearDown(() async {
      await catalog.close();
      await temp.delete(recursive: true);
    });

    test('forgets the stamp, keeps the provider\'s own art', () async {
      final c = Channel(
          id: 'p::1',
          rawId: '1',
          playlistId: 'p',
          name: 'Hexed (1993)',
          group: 'Movies',
          url: 'https://example.test/1.mkv',
          logoUrl: 'https://example.test/hexed.jpg',
          onDemand: true,
          tmdbId: '1',
          releaseDate: DateTime(2026, 2, 6),
          posterUrl: 'https://image.tmdb.org/t/p/w500/hexed2026.jpg',
          backdropUrl: 'https://image.tmdb.org/t/p/w1280/hexed2026.jpg');
      await catalog.writeM3uRows(
          vod: [CatalogDatabase.vodRow('Movies', c, importMark: 1)],
          episodes: const []);
      await catalog.clearVodTmdb('p::1');
      final row = (await catalog.getVodByIds(['p::1'])).single;
      expect(row.tmdbId, isNull);
      expect(row.releaseDate, isNull);
      expect(row.posterUrl, isNull);
      expect(row.backdropUrl, isNull);
      expect(row.logoUrl, 'https://example.test/hexed.jpg');
      expect(row.name, 'Hexed (1993)');
    });
  });
}
