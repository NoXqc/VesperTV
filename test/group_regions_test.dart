import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/group_regions.dart';

/// Group Management > Countries (owner, 2026-11-11): the country at the
/// start of a group name, however the provider writes it.
void main() {
  String? key(String title) => GroupRegions.keyOf(title)?.key;

  test('the usual country prefixes all read as the country', () {
    for (final title in [
      'US: News',
      'US| News',
      'US | News',
      '|US| News',
      '[US] News',
      '(US) News',
      'US - News',
      'US -News',
      'USA ▎ News',
      'AM | US - News',
      'AM | US: Sports',
      'VIP | US | Sports',
      '4K | US Sports',
      'US NEWS',
      'US NEWS | CNN',
      '🇺🇸 News',
    ]) {
      expect(key(title), 'US', reason: title);
    }
    expect(key('AM | CA - Sports'), 'CA');
    expect(key('CA: CBC'), 'CA');
    expect(key('ENG | Premier League'), 'ENG');
    expect(key('FR - Films'), 'FR');
    expect(key('UK: BT Sport'), 'UK');
    expect(key('GB | BBC'), 'UK');
    expect(key('🇬🇧 BBC'), 'UK');
    expect(key('EX-YU | Filmovi'), 'EXYU');
    expect(key('LATINO: Novelas'), 'LATAM');
    expect(key('ARABIC | MBC'), 'AR');
    expect(key('CANADA | Sports'), 'CA');
  });

  test('names that only look like a prefix are left alone', () {
    expect(key('Al-Jazeera'), isNull, reason: 'a dash inside a word');
    expect(key('Sports'), isNull);
    expect(key('24/7 | Cartoons'), isNull, reason: 'no letters');
    expect(key('TV SHOWS'), isNull, reason: 'TV is not Tuvalu here');
    expect(key('IN THEATERS'), isNull);
    expect(GroupRegions.keyOf('NBA: Lakers')?.country, isFalse);
    expect(GroupRegions.keyOf('AM | Sports'),
        (key: 'AM', country: false, variant: 'AM |'),
        reason: 'AM alone is the Americas marker, not Armenia');
  });

  test('variants keep how the provider wrote it', () {
    expect(GroupRegions.keyOf('|US| News')!.variant, '|US|');
    expect(GroupRegions.keyOf('AM | US - News')!.variant, 'AM | US -');
    expect(GroupRegions.keyOf('4K | US Sports')!.variant, '4K | US');
  });

  test('detect merges spellings, orders by size, keeps the rest', () {
    final regions = GroupRegions.detect([
      'US: News',
      'US| Sports',
      'AM | US - Kids',
      'AM | CA - Sports',
      'CA: News',
      'FR - Films',
      'VIP | Events',
      'VIP | PPV',
      'NBA: Lakers',
      'Sports',
      '24/7 Cartoons',
    ]);
    expect([for (final r in regions) r.key], ['US', 'CA', 'FR', 'VIP', '']);
    final us = regions.first;
    expect(us.titles, ['US: News', 'US| Sports', 'AM | US - Kids']);
    expect(us.variants, ['US:', 'US|', 'AM | US -']);
    expect(us.flag, '🇺🇸');
    expect(regions[3].country, isFalse);
    expect(regions[3].flag, isNull);
    expect(regions.last.titles, ['NBA: Lakers', 'Sports', '24/7 Cartoons'],
        reason: 'a prefix on one group only is part of its name');
  });

  test('flags only where the code means one country', () {
    GroupRegion only(String title) => GroupRegions.detect([title]).first;
    expect(only('UK: BBC').flag, '🇬🇧');
    expect(only('AR | MBC').flag, isNull, reason: 'Arabic or Argentina');
    expect(only('ENG | BBC').flag, isNull);
  });
}
