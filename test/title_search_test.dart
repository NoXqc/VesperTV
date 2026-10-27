import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/title_search.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';

void main() {
  test(
      'joined, spaced and hyphenated franchise names match in either direction',
      () {
    for (final query in [
      'spiderman',
      'Spider Man',
      'Spider-Man',
      'spider—man'
    ]) {
      for (final title in [
        'Spider-Man: Homecoming',
        'The Amazing Spider Man',
        'SPIDERMAN 2'
      ]) {
        expect(TitleSearch(query).matches(title), isTrue,
            reason: '$query / $title');
      }
    }
    expect(TitleSearch('starwars').matches('Star Wars: A New Hope'), isTrue);
    expect(TitleSearch('iron man').matches('Ironman'), isTrue);
  });

  test('accents, combining accents, ligatures and non-Latin titles survive',
      () {
    for (final title in ['ÉLITE', 'E\u0301lite']) {
      expect(TitleSearch('elite').matches(title), isTrue);
    }
    expect(TitleSearch('oeuvre').matches('Une œuvre'), isTrue);
    expect(TitleSearch('αθηνα').matches('Αθήνα'), isTrue);
    expect(TitleSearch('東京').matches('東京物語'), isTrue);
    expect(TitleSearch('东京').matches('東京物語'), isFalse);
  });

  test(
      'all words match in any order; empty punctuation cannot match everything',
      () {
    expect(TitleSearch('homecoming spider').matches('Spider-Man: Homecoming'),
        isTrue);
    expect(TitleSearch('spider batman').matches('Spider-Man: Homecoming'),
        isFalse);
    for (final query in ['', '  ', '%_--']) {
      expect(TitleSearch(query).matches('Anything'), isFalse);
      expect(TitleSearch(query).remoteQueries(query), isEmpty);
    }
  });

  test(
      'remote variants are bounded and broad discovery is marked for filtering',
      () {
    final compound = TitleSearch('spiderman').remoteQueries('spiderman');
    expect(compound,
        [(text: 'spiderman', broad: false), (text: 'spid', broad: true)]);
    expect(TitleSearch('Spider-Man').remoteQueries('Spider-Man').length,
        lessThanOrEqualTo(3));
    expect(TitleSearch('li').remoteQueries('li'), [(text: 'li', broad: false)]);
  });

  test('ranking preserves relevance within tiers and deduplicates matching IDs',
      () {
    ArchiveMeta m(String id, String title) =>
        ArchiveMeta(id: id, type: ArchiveType.movie, name: title);
    final items = [
      m('1', 'The Amazing Spider Man'),
      m('2', 'Spider-Man 2'),
      m('3', 'Homecoming: a Spider story'),
      m('2', 'Spider-Man 2'),
      m('4', 'Unrelated'),
      m('4', 'Spider-Man')
    ];
    expect(ArchiveService.rankSearch('spiderman', items).map((m) => m.id),
        ['2', '4', '1']);
    expect(
        ArchiveService.rankSearch('spider homecoming', items).map((m) => m.id),
        ['3']);
  });
}
