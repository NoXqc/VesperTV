import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/user_groups.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The playlist editor's Move / Copy to group (2026-11-11): a channel is
/// moved (leaves its group) or copied (stays and is also shown) into one of
/// the viewer's own groups or into a provider group of any playlist.
class _DirStorage extends StorageService {
  _DirStorage(this.dir);
  final Directory dir;
  @override
  Future<String> rawCachePath(String name, String ext) async =>
      '${dir.path}/$name.$ext';
  @override
  Future<String?> cacheFilePath(String name) async {
    final f = File('${dir.path}/$name.json');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> writeCacheFile(String name, String content) =>
      File('${dir.path}/$name.json').writeAsString(content);

  @override
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserGroups', () {
    test('GroupRef round-trips and rejects junk', () {
      const own = GroupRef.own('My picks');
      const pro = GroupRef.provider('p1', 'US | Sports');
      expect(GroupRef.decode(own.encode()), own);
      expect(GroupRef.decode(pro.encode()), pro);
      expect(own, isNot(pro));
      expect(GroupRef.decode('x'), isNull);
      expect(GroupRef.decode('p:nopelist'), isNull);
      expect(GroupRef.decode(42), isNull);
    });

    test('provider moves and copies are stored and read back', () {
      final g = UserGroups()
        ..moveToProvider('a::1', const GroupRef.provider('b', 'Sports'))
        ..addCopy('a::2', const GroupRef.provider('b', 'Sports'))
        ..addCopy('a::2', const GroupRef.own('Picks'))
        ..addCopy('a::2', const GroupRef.own('Picks'));
      expect(g.copiesOf('a::2').length, 2, reason: 'no duplicate copy');
      expect(
          g.idsInto(const GroupRef.provider('b', 'Sports')), ['a::1', 'a::2']);
      final back = UserGroups()..load(g.toJson());
      expect(
          back.providerMoveOf('a::1'), const GroupRef.provider('b', 'Sports'));
      expect(back.copiesOf('a::2'), g.copiesOf('a::2'));
    });

    test('an old save without the new maps still loads, and stays small', () {
      final g = UserGroups()
        ..load('{"groups":["A"],"moves":{"p::1":"A"},"order":{}}');
      expect(g.groupOf('p::1'), 'A');
      expect(g.hasPlacements, isFalse);
      expect(g.toJson(), isNot(contains('pmoves')));
      expect(g.toJson(), isNot(contains('copies')));
    });

    test('moving replaces earlier placements; deleting a group drops copies',
        () {
      final g = UserGroups()
        ..moveToProvider('a::1', const GroupRef.provider('b', 'Sports'))
        ..addCopy('a::1', const GroupRef.own('Picks'))
        ..create('Picks');
      g.move('a::1', 'Picks');
      expect(g.providerMoveOf('a::1'), isNull, reason: 'one primary place');
      expect(g.copiesOf('a::1'), isEmpty, reason: 'now lives in Picks');
      g
        ..addCopy('a::2', const GroupRef.own('Picks'))
        ..delete('Picks');
      expect(g.copies, isEmpty);
      expect(g.groupOf('a::1'), isNull);
    });

    test('clearPlacement puts a channel fully back', () {
      final g = UserGroups()
        ..moveToProvider('a::1', const GroupRef.provider('b', 'Sports'))
        ..addCopy('a::1', const GroupRef.own('Picks'))
        ..clearPlacement('a::1');
      expect(g.hasPlacements, isFalse);
    });
  });

  group('PlaylistManager', () {
    late PlaylistManager manager;
    late _DirStorage storage;

    Future<void> addList(Directory temp, String id, List<String> rows) async {
      final file = File('${temp.path}/$id.m3u');
      await file.writeAsString(['#EXTM3U', ...rows, ''].join('\n'));
      await manager.addPlaylist(PlaylistProfile(
          id: id,
          name: id == 'p' ? 'Home' : 'Other',
          mode: 'm3u',
          m3uUrl: Uri.file(file.path).toString(),
          sortOrder: id == 'p' ? 0 : 1,
          createdAt: DateTime(2026)));
      await manager.loadPlaylist(id);
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('vesper_place_');
      addTearDown(() => temp.delete(recursive: true));
      storage = _DirStorage(temp);
      await storage.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
      addTearDown(catalog.close);
      manager = PlaylistManager(storage, catalog);
      addTearDown(manager.dispose);
      await addList(temp, 'p', [
        '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
        'http://x/1.ts',
        '#EXTINF:-1 tvg-id="rds" group-title="SPORTS",RDS',
        'http://x/2.ts',
        '#EXTINF:-1 tvg-id="cnn" group-title="NEWS",CNN',
        'http://x/3.ts',
        '#EXTINF:-1 tvg-id="cp24" group-title="NEWS",CP24',
        'http://x/4.ts',
      ]);
      await addList(temp, 'q', [
        '#EXTINF:-1 tvg-id="espn" group-title="SPORTS",ESPN',
        'http://y/1.ts',
        '#EXTINF:-1 tvg-id="bbc" group-title="UK",BBC One',
        'http://y/2.ts',
      ]);
    });

    Channel channel(String name) => manager
        .visibleChannels(category: 'tv')
        .firstWhere((c) => c.name == name);
    List<String> names(String playlist, String group) => [
          for (final c in manager.visibleChannels(
              playlistId: playlist, groupTitle: group, category: 'tv'))
            c.name
        ];
    List<String> own(String group) => [
          for (final c
              in manager.visibleChannels(groupTitle: group, category: 'tv'))
            c.name
        ];

    test('move to a group of the same playlist', () async {
      final r = await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('p', 'SPORTS'),
          copy: false);
      expect(r.changed, 1);
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS', 'CNN']);
      expect(names('p', 'NEWS'), ['CP24']);
      expect(manager.liveGroupCount('p', 'SPORTS'), 3);
      expect(manager.liveGroupOf(channel('CNN')), 'SPORTS');
    });

    test('move into another playlist\'s group, no bleed into a same-named one',
        () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      expect(names('q', 'SPORTS'), ['ESPN', 'CNN']);
      expect(names('p', 'NEWS'), ['CP24'], reason: 'it left its group');
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS'],
          reason: 'same title in its own playlist must not pick it up');
      expect(manager.liveGroupCount('q', 'SPORTS'), 2);
      expect(manager.liveGroupCount('p', 'NEWS'), 1);
    });

    test('copy keeps the channel where it is and lists it in the new group',
        () async {
      await manager.placeChannels(
          [channel('TSN 1')], const GroupRef.provider('q', 'UK'),
          copy: true);
      expect(names('q', 'UK'), ['BBC One', 'TSN 1']);
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS']);
      expect(manager.liveGroupCount('q', 'UK'), 2);
      expect(manager.liveGroupCount('p', 'SPORTS'), 2);
      // Copying again changes nothing.
      final again = await manager.placeChannels(
          [channel('TSN 1')], const GroupRef.provider('q', 'UK'),
          copy: true);
      expect(again.changed, 0);
      expect(again.skipped, 1);
    });

    test('own groups: move and copy, order and counts', () async {
      final title = await manager.createUserGroup('Picks');
      final dest = GroupRef.own(title);
      await manager.placeChannels([channel('CNN')], dest, copy: false);
      await manager
          .placeChannels([channel('ESPN'), channel('RDS')], dest, copy: true);
      expect(own('Picks'), unorderedEquals(['CNN', 'ESPN', 'RDS']));
      expect(names('p', 'NEWS'), ['CP24'], reason: 'CNN moved out');
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS'], reason: 'RDS copied');
      expect(manager.liveGroupCount(null, 'Picks'), 3);
      final placed = manager.placementOf(channel('RDS'))!;
      expect(placed.moved, isNull);
      expect(placed.copies, ['Picks (my group)']);
      expect(manager.placementOf(channel('CNN'))!.moved, 'Picks (my group)');
      expect(manager.isCopyIn(channel('RDS'), 'Picks'), isTrue);
      await manager.removeCopyFrom(channel('RDS'), 'Picks');
      expect(own('Picks'), unorderedEquals(['CNN', 'ESPN']));
    });

    test('moving a channel back to its provider group puts it back', () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      expect(names('p', 'NEWS'), ['CP24']);
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('p', 'NEWS'),
          copy: false);
      expect(names('p', 'NEWS'), ['CNN', 'CP24']);
      expect(names('q', 'SPORTS'), ['ESPN']);
      expect(manager.placementOf(channel('CNN')), isNull);
    });

    test('unplace puts channels back and removes their copies', () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      await manager.placeChannels(
          [channel('RDS')], const GroupRef.provider('q', 'UK'),
          copy: true);
      expect(manager.placementOf(channel('CNN'))!.moved, 'Other › SPORTS');
      final n = await manager.unplaceChannels([
        channel('CNN'),
        channel('RDS'),
        channel('CP24'),
      ]);
      expect(n, 2, reason: 'CP24 was never placed');
      expect(names('q', 'SPORTS'), ['ESPN']);
      expect(names('q', 'UK'), ['BBC One']);
      expect(names('p', 'NEWS'), ['CNN', 'CP24']);
    });

    test('a channel hidden on the TV is not listed in its new group', () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'UK'),
          copy: true);
      await manager.toggleChannelHidden(channel('CNN'));
      expect(names('q', 'UK'), ['BBC One']);
    });

    test('the placements are saved with the viewer\'s own groups', () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      await manager.placeChannels(
          [channel('RDS')], const GroupRef.provider('q', 'UK'),
          copy: true);
      final saved = UserGroups()..load(storage.getMyGroups());
      expect(saved.providerMoveOf(channel('CNN').id),
          const GroupRef.provider('q', 'SPORTS'));
      expect(saved.copiesOf(channel('RDS').id),
          [const GroupRef.provider('q', 'UK')]);
    });

    // Limits revisited (2026-11-11): Move Up / Down where placed channels
    // are listed, flat lists following hidden groups, kids profiles.
    test('Move Up / Down in a group that received a channel', () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      expect(names('q', 'SPORTS'), ['ESPN', 'CNN']);
      // The TV picks groups by title; SPORTS is also a group of p.
      expect(
          await manager.moveChannel(channel('CNN'), -1, inGroup: 'SPORTS'), 0);
      expect(names('q', 'SPORTS'), ['CNN', 'ESPN']);
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS']);
      // The group's own channels follow the same order.
      await manager.moveChannel(channel('ESPN'), -1, inGroup: 'SPORTS');
      expect(names('q', 'SPORTS'), ['ESPN', 'CNN']);
      final saved = UserGroups()..load(storage.getMyGroups());
      expect(
          saved.porder.keys, [const GroupRef.provider('q', 'SPORTS').encode()]);
    });

    test('Move Up / Down after a move inside one playlist; the order stays',
        () async {
      await manager.placeChannels(
          [channel('CP24')], const GroupRef.provider('p', 'SPORTS'),
          copy: false);
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS', 'CP24']);
      await manager.moveChannel(channel('CP24'), -1, inGroup: 'SPORTS');
      expect(names('p', 'SPORTS'), ['TSN 1', 'CP24', 'RDS']);
      await manager.moveChannel(channel('RDS'), -2, inGroup: 'SPORTS');
      expect(names('p', 'SPORTS'), ['RDS', 'TSN 1', 'CP24']);
      await manager.unplaceChannels([channel('CP24')]);
      expect(names('p', 'SPORTS'), ['RDS', 'TSN 1'],
          reason: 'the order outlives the channel that was placed');
    });

    test('a copy moves in the group it is copied into, not its own', () async {
      await manager.placeChannels(
          [channel('TSN 1')], const GroupRef.provider('q', 'UK'),
          copy: true);
      expect(manager.isCopyIn(channel('TSN 1'), 'UK'), isTrue);
      await manager.moveChannel(channel('TSN 1'), -1, inGroup: 'UK');
      expect(names('q', 'UK'), ['TSN 1', 'BBC One']);
      expect(names('p', 'SPORTS'), ['TSN 1', 'RDS']);
      await manager.moveChannel(channel('TSN 1'), 1, inGroup: 'SPORTS');
      expect(names('p', 'SPORTS'), ['RDS', 'TSN 1']);
      expect(names('q', 'UK'), ['TSN 1', 'BBC One']);
      // Hold OK > Remove from a provider group's copy too.
      await manager.removeCopyFrom(channel('TSN 1'), 'UK');
      expect(names('q', 'UK'), ['BBC One']);
      expect(names('p', 'SPORTS'), ['RDS', 'TSN 1']);

      final title = await manager.createUserGroup('Picks');
      await manager.placeChannels([channel('BBC One')], GroupRef.own(title),
          copy: false);
      await manager
          .placeChannels([channel('CNN')], GroupRef.own(title), copy: true);
      expect(own('Picks'), ['BBC One', 'CNN']);
      await manager.moveChannel(channel('CNN'), -1, inGroup: 'Picks');
      expect(own('Picks'), ['CNN', 'BBC One']);
      expect(names('p', 'NEWS'), ['CNN', 'CP24']);
    });

    List<String> flat() =>
        [for (final c in manager.visibleChannels(category: 'tv')) c.name];

    test('Search and Multiview leave out a channel moved into a hidden group',
        () async {
      await manager.placeChannels(
          [channel('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      expect(flat(), contains('CNN'));
      await manager.setGroupHidden('q', 'SPORTS', true);
      expect(flat(), isNot(contains('CNN')));
      expect(flat(), isNot(contains('ESPN')));
      expect(manager.visibleChannels(playlistId: 'p', category: 'tv'),
          isNot(contains(predicate<Channel>((c) => c.name == 'CNN'))));
      await manager.setGroupHidden('q', 'SPORTS', false);
      expect(flat(), contains('CNN'));
    });

    test('a channel copied out of a hidden group into a shown one is listed',
        () async {
      await manager.setGroupHidden('p', 'NEWS', true);
      expect(flat(), isNot(contains('CNN')));
      final cnn = manager
          .editorSession('p')!
          .allLiveChannels
          .firstWhere((c) => c.name == 'CNN');
      await manager
          .placeChannels([cnn], const GroupRef.provider('q', 'UK'), copy: true);
      expect(flat(), contains('CNN'));
      expect(flat(), isNot(contains('CP24')));
      expect(names('q', 'UK'), ['BBC One', 'CNN']);
      expect(manager.liveGroupCount('q', 'UK'), 2);
    });

    test('kids profile: placing never shows a group its allowlist hides',
        () async {
      await storage.setViewerProfiles([
        ViewerProfile.main(),
        ViewerProfile(
            id: 'kid',
            name: 'Kid',
            colorIndex: 1,
            isRestricted: true,
            createdAt: DateTime(2026)),
      ]);
      await storage.setActiveViewerId('kid');
      await storage.setShownGroups('p', {'SPORTS'});
      await storage.setShownGroups('q', {'SPORTS', 'UK'});
      manager.applyActiveViewer();
      expect(flat(), ['TSN 1', 'RDS', 'ESPN', 'BBC One']);
      Channel any(String name) => [
            ...manager.editorSession('p')!.allLiveChannels,
            ...manager.editorSession('q')!.allLiveChannels,
          ].firstWhere((c) => c.name == name);

      await manager.placeChannels(
          [any('CNN')], const GroupRef.provider('q', 'UK'),
          copy: true);
      final title = await manager.createUserGroup('Picks');
      await manager
          .placeChannels([any('CP24')], GroupRef.own(title), copy: false);
      await manager.placeChannels(
          [any('CNN')], const GroupRef.provider('q', 'SPORTS'),
          copy: false);
      await manager.placeChannels(
          [any('RDS')], const GroupRef.provider('q', 'UK'),
          copy: true);
      expect(names('q', 'UK'), ['BBC One', 'RDS'], reason: 'NEWS not allowed');
      expect(names('q', 'SPORTS'), ['ESPN']);
      expect(own('Picks'), isEmpty);
      expect(flat(), isNot(contains('CNN')));
      expect(flat(), isNot(contains('CP24')));

      // The parent allows NEWS: the placements apply.
      await storage.setShownGroups('p', {'SPORTS', 'NEWS'});
      manager.applyActiveViewer();
      expect(names('q', 'SPORTS'), ['ESPN', 'CNN']);
      expect(names('q', 'UK'), ['BBC One', 'CNN', 'RDS']);
      expect(own('Picks'), ['CP24']);
    });

    test('an unavailable destination is refused', () async {
      expect(
          () => manager.placeChannels(
              [channel('CNN')], const GroupRef.own('Nope'),
              copy: false),
          throwsStateError);
      expect(
          () => manager.placeChannels(
              [channel('CNN')], const GroupRef.provider('gone', 'X'),
              copy: true),
          throwsStateError);
    });
  });
}
