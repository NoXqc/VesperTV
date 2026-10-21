import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/user_groups.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The viewer's own live groups (owner, 2026-10-21): not tied to a
/// playlist, so one group holds channels from every playlist; a moved
/// channel leaves its provider group; Remove from group / delete send it
/// back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Channel ch(String playlistId, String rawId, String group) => Channel(
        id: '$playlistId::$rawId',
        rawId: rawId,
        playlistId: playlistId,
        name: 'Channel $rawId',
        group: group,
        url: 'http://x/$rawId.ts',
      );

  Future<PlaylistSession> session(
      String id, List<Channel> channels, UserGroups mine) async {
    final storage = StorageService();
    await storage.init();
    final s = PlaylistSession(
      profile: PlaylistProfile(
          id: id,
          name: id,
          mode: 'm3u',
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: CatalogDatabase(),
      favoriteIds: () => {},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {},
      myGroupOf: (c) => mine.groupOf(c.id),
    );
    s.channels = channels;
    return s;
  }

  List<String> ids(Iterable<Channel> list) => [for (final c in list) c.id];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('one group, channels from two playlists', () async {
    final mine = UserGroups();
    final a = await session(
        'a', [ch('a', '1', 'Sports'), ch('a', '2', 'Sports')], mine);
    final b = await session('b', [ch('b', '7', 'News')], mine);

    mine.move('a::2', 'My picks');
    mine.move('b::7', 'My picks');

    // Each playlist gives its moved channels to the group…
    final all = [
      ...a.visibleChannels(groupTitle: 'My picks', category: 'tv'),
      ...b.visibleChannels(groupTitle: 'My picks', category: 'tv'),
    ];
    expect(ids(all), ['a::2', 'b::7']);
    // …and they leave their provider groups.
    expect(
        ids(a.visibleChannels(groupTitle: 'Sports', category: 'tv')), ['a::1']);
    expect(b.visibleChannels(groupTitle: 'News', category: 'tv'), isEmpty);
    // The group isn't a playlist's group (it has rows of its own).
    expect(a.tvGroups.map((g) => g.title), ['Sports']);

    // Move Up / Down across playlists.
    expect(mine.moveChannel('My picks', 'b::7', -1, all), 0);
    expect(ids(mine.ordered('My picks', all)), ['b::7', 'a::2']);

    // Remove from group.
    mine.move('a::2', null);
    expect(ids(a.visibleChannels(groupTitle: 'Sports', category: 'tv')),
        ['a::1', 'a::2']);
  });

  test('new groups go on top, names stay unique, groups move', () {
    final mine = UserGroups();
    expect(mine.create('Later'), 'Later');
    expect(mine.create('Kids'), 'Kids');
    expect(mine.groups, ['Kids', 'Later']);
    // A provider group or own group with that name: numbered.
    expect(mine.create('Sports', taken: {'Sports'}), 'Sports 2');
    expect(mine.create('Kids'), 'Kids 2');

    expect(mine.moveGroup('Later', -10), 0);
    expect(mine.groups.first, 'Later');
    expect(mine.moveGroup('Later', 1), 1);
    expect(mine.moveGroup('Nope', 1), isNull);
  });

  test('saved and loaded; delete sends channels back', () {
    final mine = UserGroups()
      ..move('a::1', 'Kids')
      ..move('b::9', 'Kids');
    final again = UserGroups()..load(mine.toJson());
    expect(again.groups, ['Kids']);
    expect(again.groupOf('b::9'), 'Kids');

    again.delete('Kids');
    expect(again.groups, isEmpty);
    expect(again.groupOf('a::1'), isNull);
    // Corrupt data reads as empty, never throws.
    expect((UserGroups()..load('{oops')).groups, isEmpty);
  });

  test('stored per viewer, not per playlist', () async {
    final storage = StorageService();
    await storage.init();
    final mine = UserGroups()..move('a::1', 'Kids');
    await storage.setMyGroups(mine.toJson());
    expect((UserGroups()..load(storage.getMyGroups())).groups, ['Kids']);
    await storage.setActiveViewerId('guest');
    expect(storage.getMyGroups(), isNull);
  });
}
