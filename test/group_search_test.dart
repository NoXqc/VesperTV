import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/title_search.dart';

/// Group Management's search matches the start of any word in the name:
/// providers prefix groups ("US| Entertainment") and "ent" must still find
/// them, but never mid-word (Hide results acts on every match).
void main() {
  const groups = [
    'US| Entertainment',
    'UK| Entertainment HD',
    'US| Sports',
    'FR| Cinéma',
    'Documentaries',
  ];

  List<String> find(String query) {
    final search = TitleSearch(query);
    return groups.where((g) => (search.rank(g) ?? 9) <= 1).toList();
  }

  test('a word inside the name matches without its prefix', () {
    expect(find('ent'), ['US| Entertainment', 'UK| Entertainment HD']);
    expect(find('ENT'), ['US| Entertainment', 'UK| Entertainment HD']);
  });

  test('never in the middle of a word', () {
    // "Documentaries" contains "ent", but not at a word start.
    expect(find('ent'), isNot(contains('Documentaries')));
    expect(find('tainment'), isEmpty);
  });

  test('the prefix still works, with or without the separator', () {
    expect(find('us'), ['US| Entertainment', 'US| Sports']);
    expect(find('US|'), ['US| Entertainment', 'US| Sports']);
    expect(find('us ent'), ['US| Entertainment']);
  });

  test('accents are ignored', () {
    expect(find('cinema'), ['FR| Cinéma']);
  });

  test('an empty or punctuation-only query is no filter', () {
    expect(TitleSearch('').isEmpty, isTrue);
    expect(TitleSearch(' | ').isEmpty, isTrue);
  });
}
