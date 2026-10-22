import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/channel.dart';
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
}
