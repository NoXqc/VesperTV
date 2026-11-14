import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/utils/hub_title_order.dart';

/// Media Hub release tags, sort and filters (hub_title_order.dart): read
/// from what the add-on sends (`released`, `releaseInfo`, `imdbRating`,
/// `genres`, `popularity`), as Cinemeta's catalogs do.
ArchiveMeta _m(String name,
        {String? released,
        String? year,
        String? rating,
        double? popularity,
        List<String> genres = const []}) =>
    ArchiveMeta.fromJson({
      'id': 'tt$name',
      'type': 'movie',
      'name': name,
      if (released != null) 'released': released,
      if (year != null) 'releaseInfo': year,
      if (rating != null) 'imdbRating': rating,
      if (popularity != null) 'popularity': popularity,
      'genres': genres,
    })!;

void main() {
  final today = DateTime(2026, 11, 13);

  test('released and popularity are read and kept by the cache', () {
    final m = ArchiveMeta.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Verity',
      'releaseInfo': '2026',
      'released': '2026-10-02T00:00:00.000Z',
      'popularity': 41.5,
    })!;
    expect(m.releaseDate, DateTime(2026, 10, 2));
    expect(m.popularity, 41.5);
    final again = ArchiveMeta.fromJson(m.toJson())!;
    expect(again.released, m.released);
    expect(again.popularity, 41.5);
    // A string score reads too; anything else is none.
    expect(
        ArchiveMeta.fromJson(
                {'id': 'a', 'type': 'movie', 'name': 'a', 'popularity': '3.5'})!
            .popularity,
        3.5);
  });

  test('Coming soon after today, NEW for 30 days, nothing after', () {
    expect(hubReleaseTag(_m('a', released: '2026-11-20T00:00:00.000Z'), today),
        HubReleaseTag.comingSoon);
    expect(hubReleaseTag(_m('b', released: '2026-11-13T00:00:00.000Z'), today),
        HubReleaseTag.isNew,
        reason: 'out today');
    expect(hubReleaseTag(_m('c', released: '2026-10-20T00:00:00.000Z'), today),
        HubReleaseTag.isNew);
    expect(hubReleaseTag(_m('d', released: '2026-09-01T00:00:00.000Z'), today),
        isNull);
    expect(
        hubReleaseTag(_m('e', year: '2027'), today), HubReleaseTag.comingSoon,
        reason: 'a later year alone says Coming soon');
    expect(hubReleaseTag(_m('f', year: '2026'), today), isNull,
        reason: 'a year alone can not say how new');
    expect(hubReleaseTag(_m('g', year: '2019-2024'), today), isNull);
    expect(hubReleaseTag(_m('h'), today), isNull);
  });

  test('sorts: missing values last, ties in the sent order', () {
    final items = [
      _m('Bravo', released: '2024-05-01', rating: '7.1', popularity: 10),
      _m('alpha', year: '2026', rating: '8.0'),
      _m('Charlie', released: '2026-12-01', popularity: 50),
      _m('Delta'),
      _m('Echo', released: '2024-05-01', rating: '7.1', popularity: 10),
    ];
    List<String> names(HubSort s) =>
        [for (final i in hubSortOrder(items, s)) items[i].name];
    expect(
        names(HubSort.source), ['Bravo', 'alpha', 'Charlie', 'Delta', 'Echo']);
    expect(
        names(HubSort.newest), ['Charlie', 'alpha', 'Bravo', 'Echo', 'Delta']);
    expect(
        names(HubSort.oldest), ['Bravo', 'Echo', 'alpha', 'Charlie', 'Delta']);
    expect(
        names(HubSort.popular), ['Charlie', 'Bravo', 'Echo', 'alpha', 'Delta']);
    expect(
        names(HubSort.rating), ['alpha', 'Bravo', 'Echo', 'Charlie', 'Delta']);
    expect(names(HubSort.aToZ), ['alpha', 'Bravo', 'Charlie', 'Delta', 'Echo']);
    expect(hubHasPopularity(items), isTrue);
    expect(hubHasPopularity([_m('x')]), isFalse);
  });

  test('genres by how common, decades newest first', () {
    final items = [
      _m('a', year: '1999', genres: ['Drama', 'Crime']),
      _m('b', released: '2024-01-01', genres: ['Drama']),
      _m('c', year: '2010-2015', genres: ['Comedy', 'Drama']),
      _m('d', genres: ['Crime']),
    ];
    expect(hubGenres(items), ['Drama', 'Crime', 'Comedy']);
    expect(hubDecades(items), [2020, 2010, 1990]);
    expect(hubDecade(items[2]), 2010, reason: 'a series span: its start');
    expect(hubDecade(items[3]), isNull);
  });
}
