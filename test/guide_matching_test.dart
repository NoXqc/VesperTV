import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/guide_matching.dart';

GuideEntry e(String id, String name, {bool live = false}) =>
    GuideEntry(id, name, live: live);

void main() {
  final guide = [
    e('ESPN.us', 'ESPN'),
    e('ESPN2.us', 'ESPN 2'),
    e('ESPNPlus.us', 'ESPN+'),
    e('TSN1.ca', 'TSN 1'),
    e('TSN2.ca', 'TSN 2'),
    e('BBCOne.uk', 'BBC One'),
    e('SkySportsMainEvent.uk', 'Sky Sports Main Event'),
    e('DiscoveryChannel.us', 'Discovery Channel'),
    e('CNN.us', 'CNN'),
    e('CNN.ca', 'CNN'),
    e('I10035.json.schedulesdirect.org', 'Fox News Channel'),
  ];
  final matcher = GuideMatcher(guide);

  String? best(String name) {
    final s = matcher.suggest(name);
    return s.isEmpty ? null : s.first.entry.id;
  }

  bool sure(String name) => isSure(matcher.suggest(name));

  test('region tags and quality words do not matter', () {
    for (final name in [
      'US: ESPN HD',
      '|US| ESPN FHD',
      '[US] ESPN 4K',
      'ESPN'
    ]) {
      expect(best(name), 'ESPN.us', reason: name);
      expect(sure(name), isTrue, reason: name);
    }
  });

  test('numbers must agree', () {
    expect(best('CA: TSN1'), 'TSN1.ca');
    expect(best('CA | TSN 2 HD'), 'TSN2.ca');
    expect(sure('CA: TSN 2'), isTrue);
    expect(best('ESPN 2'), 'ESPN2.us');
    // ESPN 2 is never offered as plain ESPN with any confidence.
    final espn = matcher.suggest('ESPN');
    expect(
        espn.where((s) => s.entry.id == 'ESPN2.us' && s.score >= 0.9), isEmpty);
  });

  test('ESPN and ESPN+ stay apart', () {
    expect(best('US: ESPN+'), 'ESPNPlus.us');
    expect(sure('ESPN+'), isTrue);
  });

  test('spacing, camel case ids and number words', () {
    expect(best('UK: SkySports Main Event'), 'SkySportsMainEvent.uk');
    expect(sure('UK: SkySports Main Event'), isTrue);
    expect(best('UK: BBC 1 HD'), 'BBCOne.uk');
    expect(sure('UK: BBC 1 HD'), isTrue);
  });

  test('a typo still finds the channel', () {
    expect(best('Discovry Channel'), 'DiscoveryChannel.us');
  });

  test('another region is a guess, not sure', () {
    final s = matcher.suggest('CA: ESPN');
    expect(s.first.entry.id, 'ESPN.us');
    expect(s.first.score, lessThan(0.9));
    expect(isSure(s), isFalse);
  });

  test('the region picks between same-name ids', () {
    expect(best('CA: CNN'), 'CNN.ca');
    expect(best('US: CNN'), 'CNN.us');
    // No region: two equal ids, so not sure.
    expect(sure('CNN'), isFalse);
  });

  test('of two equal ids, the one airing something now is sure', () {
    final m = GuideMatcher([
      e('foo.us', 'Foo Network'),
      e('foohd.us', 'Foo Network', live: true),
    ]);
    final s = m.suggest('Foo Network HD');
    expect(s.first.entry.id, 'foohd.us');
    expect(isSure(s), isTrue);
  });

  test('a name from another playlist (alias) matches too', () {
    final m = GuideMatcher([
      GuideEntry('fnc.us', 'FNC', aliases: ['US: FOX NEWS']),
    ]);
    expect(m.suggest('USA | Fox News HD').first.entry.id, 'fnc.us');
  });

  test('a long tag-like word before a dash is kept', () {
    expect(GuideName.parse('ESPN 2 - Live').tokens, ['espn', '2', 'live']);
    expect(GuideName.parse('AM | US: ESPN').tokens, ['espn']);
    expect(GuideName.parse('AM | US: ESPN').region, 'us');
    expect(GuideName.parse('BBC One (UK)').region, 'gb');
  });

  test('nothing for unrelated names', () {
    expect(matcher.suggest('Cartoon Network'), isEmpty);
    expect(matcher.suggest('#####'), isEmpty);
  });

  test('suggestGuides runs off the UI thread', () async {
    final all = await suggestGuides(guide, ['US: ESPN', 'CA: TSN 1']);
    expect([for (final s in all) s.first.entry.id], ['ESPN.us', 'TSN1.ca']);
  });
}
