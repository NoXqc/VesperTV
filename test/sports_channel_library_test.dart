import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/sports_channel_library.dart';

void main() {
  Channel c(String id, String name, {String group = 'Unknown'}) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: group,
      url: 'https://example.com/private');
  Future<StorageService> storage() async {
    SharedPreferences.setMockInitialValues({});
    final s = StorageService();
    await s.init();
    return s;
  }

  test('manual library has no sports, EPG or 200 channel dependency', () {
    final library = SportsChannelLibrary(
        [for (var i = 0; i < 1000; i++) c('$i', 'Local $i')]);
    expect(library.search().length, 1000);
    final selected = <String>{library.search(query: 'Local 999').single.id};
    selected.add(library.search(query: 'Local 123').single.id);
    expect(selected, {'p::999', 'p::123'});
  });
  test('membership intersects visibility and never substitutes a missing id',
      () {
    final list = SportsChannelList(
        id: 'one', name: 'List', channels: ['p::hidden', 'p::1']);
    final library = SportsChannelLibrary([c('1', 'Local'), c('2', 'Local')]);
    expect(library.members(list).map((c) => c.id), ['p::1']);
    expect(list.channels, ['p::hidden', 'p::1']);
  });
  test('versions keep plus, number, country and region identities apart', () {
    final espn = c('1', 'US: ESPN HD');
    final library = SportsChannelLibrary([
      espn,
      c('2', 'US: ESPN 4K'),
      c('3', 'US: ESPN+'),
      c('4', 'CA: ESPN'),
      c('5', 'US: ESPN2'),
      c('6', 'US: ESPN East')
    ]);
    expect(library.versions(espn).map((c) => c.id), ['p::1', 'p::2']);
  });
  test('lists are many-to-many, viewer scoped, transferable and deletable',
      () async {
    final s = await storage();
    final store = SportsChannelLists(s);
    store.create('One', ['p::1']);
    store.create('Two', ['p::1']);
    await store.save();
    expect(s.getSportsChannelLists(), isNot(contains('https://')));
    await s.setActiveViewerId('kid');
    expect(SportsChannelLists(s).lists, isEmpty);
    final kid = SportsChannelLists(s);
    kid.create('Kid', []);
    await kid.save();
    final exported = s.exportForTransfer();
    final r = await storage();
    await r.importForTransfer(exported);
    expect(SportsChannelLists(r).lists.map((l) => l.name), ['One', 'Two']);
    await r.setActiveViewerId('kid');
    expect(SportsChannelLists(r).lists.single.name, 'Kid');
    await r.deleteViewerData('kid');
    expect(SportsChannelLists(r).lists, isEmpty);
  });

  test(
      'updating membership includes new matches, manual additions, and exclusions win',
      () async {
    final s = await storage();
    final store = SportsChannelLists(s);
    final list = store.create('Canada', ['p::manual']);
    list.filters = {
      'Country': ['CA']
    };
    list.excluded.add('p::excluded');
    await store.save();
    final reloaded = SportsChannelLists(s);
    final library = SportsChannelLibrary([
      c('new', 'CA: TSN 2 HD'),
      c('excluded', 'CA: TSN 1 HD'),
      c('manual', 'Unknown local'),
      c('other', 'US: ESPN')
    ], store: reloaded);
    expect(library.members(reloaded.lists.single).map((c) => c.id),
        ['p::manual', 'p::new']);
    expect(
        SportsChannelLibrary([c('other', 'US: ESPN')], store: reloaded)
            .members(reloaded.lists.single),
        isEmpty);
  });
  test('filter dimensions use AND; values use OR; unknown and manual tags work',
      () async {
    final s = await storage();
    final store = SportsChannelLists(s);
    final local = c('local', 'Unclassified');
    store.tags[local.id] = {
      'Country': ['CA'],
      'Sport': ['hockey'],
      'Network': ['Local']
    };
    final library = SportsChannelLibrary([local], store: store);
    expect(
        library.accepts(local, {
          'Country': ['US', 'CA'],
          'Sport': ['hockey']
        }),
        isTrue);
    expect(
        library.accepts(local, {
          'Country': ['US'],
          'Sport': ['hockey']
        }),
        isFalse);
    expect(
        library.accepts(c('none', 'Unknown'), {
          'Country': ['Unknown']
        }),
        isTrue);
    expect(library.tagsFor(c('plus', 'US: ESPN+'))['Network'], ['ESPN+']);
    expect(library.tagsFor(c('base', 'US: ESPN'))['Network'], ['ESPN']);
  });
  test(
      'game/team/league sources persist independently and expired events disappear',
      () async {
    final s = await storage();
    final store = SportsChannelLists(s);
    final game = SportsGame(
        id: 'one',
        league: sportsLeagueById('nhl')!,
        start: DateTime.utc(2026, 10, 23),
        state: GameState.pre,
        statusText: '',
        home: const SportsTeam(
            id: 'h', name: 'Home Team', shortName: 'Home', abbreviation: 'H'),
        away: const SportsTeam(
            id: 'a', name: 'Away Team', shortName: 'Away', abbreviation: 'A'));
    await store.setSources('event:one', ['p::event'], event: true);
    await store.setSources('team:nhl:h', ['p::team']);
    await store.setSources('league:nhl', ['p::league']);
    expect(SportsChannelLists(s).sourcesFor(game, 'one'),
        {'p::event', 'p::team', 'p::league'});
    store.sources['event:one']!['until'] = 0;
    await store.save();
    expect(SportsChannelLists(s).sourcesFor(game, 'one'),
        {'p::team', 'p::league'});
    await s.setActiveViewerId('kid');
    expect(SportsChannelLists(s).sourcesFor(game, 'one'), isEmpty);
  });
}
