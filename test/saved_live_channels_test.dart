import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/saved_live_channels.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/user_groups.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A live channel's id comes from the provider (EPG id, stream id, M3U line
/// position), so it changes when the provider changes those; saved
/// channels (Favourites, own groups) then fell out after an update
/// (Discord, Kal-el23, 2026-11-16). They now follow their channel.
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

Channel _ch(String rawId, String name,
        {String group = 'SPORTS', String? stream, String? url}) =>
    Channel(
      id: 'p::$rawId',
      rawId: rawId,
      playlistId: 'p',
      name: name,
      group: group,
      url: url ?? 'http://h/live/u/pw/${stream ?? '0'}.ts',
      streamId: stream,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SavedLiveKey.streamKeyOf', () {
    test('Xtream stream id, else the link\'s numbered file name', () {
      expect(
          SavedLiveKey.streamKeyOf(_ch('a', 'A', stream: '325318')), '325318');
      expect(
          SavedLiveKey.streamKeyOf(
              _ch('a', 'A', url: 'http://h/u/pw/4471.m3u8?token=x')),
          '4471');
      expect(SavedLiveKey.streamKeyOf(_ch('a', 'A', url: 'http://h/u/pw/88')),
          '88');
    });

    test('a file name every channel may share is no stream', () {
      for (final url in [
        'http://h/tsn/index.m3u8',
        'http://h/play.php?id=5',
        'http://h/',
        '',
      ]) {
        expect(SavedLiveKey.streamKeyOf(_ch('a', 'A', url: url)), '',
            reason: url);
      }
    });
  });

  group('SavedLiveChannels.rescue', () {
    Map<String, Channel> rescue(
            Map<String, SavedLiveKey> missing, List<Channel> live) =>
        SavedLiveChannels.rescue(missing, live);

    test('the provider gave the channel an EPG id: same stream', () {
      final found = rescue({
        'p::xt_live_101': const SavedLiveKey('101', 'TSN 1', 'SPORTS'),
      }, [
        _ch('tsn1.ca', 'TSN 1', stream: '101'),
        _ch('rds.ca', 'RDS', stream: '102'),
      ]);
      expect(found['p::xt_live_101']?.id, 'p::tsn1.ca');
    });

    test('a copy appeared with the same EPG id: id gets #stream', () {
      final live = Channel.withUniqueIds([
        _ch('espn.us', 'ESPN HD', stream: '7'),
        _ch('espn.us', 'ESPN 4K', stream: '8'),
      ]);
      final found = rescue(
          {'p::espn.us': const SavedLiveKey('7', 'ESPN HD', 'SPORTS')}, live);
      expect(found['p::espn.us']?.id, 'p::espn.us#7');
    });

    test('renumbered streams: found by name in its group', () {
      final found = rescue({
        'p::xt_live_101': const SavedLiveKey('101', 'TSN 1', 'SPORTS'),
      }, [
        _ch('xt_live_901', 'TSN 1', stream: '901'),
        _ch('xt_live_101', 'Some Movie Channel',
            group: 'MOVIES', stream: '101'),
        _ch('xt_live_902', 'TSN 1', group: 'BACKUP', stream: '902'),
      ]);
      expect(found['p::xt_live_101']?.id, 'p::xt_live_901',
          reason: 'stream 101 is now another channel (other name and group)');
    });

    test('the group was renamed: the name alone, when it is the only one', () {
      final found = rescue({
        'p::cp24': const SavedLiveKey('', 'CP24', 'CA NEWS'),
      }, [
        _ch('cp24.ca', 'CP24', group: 'CA | NEWS'),
      ]);
      expect(found['p::cp24']?.id, 'p::cp24.ca');
    });

    test('never guesses', () {
      // Two of that name in its group.
      expect(
          rescue({
            'p::old': const SavedLiveKey('', 'ESPN', 'SPORTS'),
          }, [
            _ch('a', 'ESPN'),
            _ch('b', 'ESPN'),
          ]),
          isEmpty);
      // Its group is still there without it: gone, not renamed.
      expect(
          rescue({
            'p::old': const SavedLiveKey('', 'ESPN', 'SPORTS'),
          }, [
            _ch('a', 'TSN 1'),
            _ch('b', 'ESPN', group: 'BACKUP'),
          ]),
          isEmpty);
      // Two saved ids would land on the same channel.
      expect(
          rescue({
            'p::old1': const SavedLiveKey('', 'ESPN', 'SPORTS'),
            'p::old2': const SavedLiveKey('', 'espn ', 'SPORTS'),
          }, [
            _ch('a', 'ESPN'),
          ]),
          isEmpty);
    });

    test('keys round-trip, junk is dropped', () {
      final keys = {
        'p::a': const SavedLiveKey('1', 'A', 'G'),
        'p::b': const SavedLiveKey('', 'B "x"', 'G|H'),
      };
      expect(SavedLiveChannels.decode(SavedLiveChannels.encode(keys)), keys);
      expect(SavedLiveChannels.decode('{"p::a":[1,2]}'), isEmpty);
      expect(SavedLiveChannels.decode('nope'), isEmpty);
      expect(SavedLiveChannels.decode(null), isEmpty);
    });
  });

  test('UserGroups.renameId moves placements and order entries', () {
    final g = UserGroups()
      ..move('p::old', 'Picks')
      ..addCopy('p::old2', const GroupRef.own('Picks'))
      ..moveToProvider('p::old3', const GroupRef.provider('q', 'UK'));
    g.order['Picks'] = ['p::x', 'p::old', 'p::y'];
    g.porder[const GroupRef.provider('q', 'UK').encode()] = ['p::old3'];
    g
      ..renameId('p::old', 'p::new')
      ..renameId('p::old2', 'p::new2')
      ..renameId('p::old3', 'p::new3');
    expect(g.groupOf('p::new'), 'Picks');
    expect(g.groupOf('p::old'), isNull);
    expect(g.copiesOf('p::new2'), [const GroupRef.own('Picks')]);
    expect(g.providerMoveOf('p::new3'), const GroupRef.provider('q', 'UK'));
    expect(g.order['Picks'], ['p::x', 'p::new', 'p::y']);
    expect(g.porder.values.single, ['p::new3']);
    expect(g.channelIds, {'p::new', 'p::new2', 'p::new3'});
  });

  group('PlaylistManager', () {
    late PlaylistManager manager;
    late _DirStorage storage;
    late File list;

    Future<void> write(List<String> rows) =>
        list.writeAsString(['#EXTM3U', ...rows, ''].join('\n'));

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('vesper_saved_');
      addTearDown(() => temp.delete(recursive: true));
      storage = _DirStorage(temp);
      await storage.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
      addTearDown(catalog.close);
      manager = PlaylistManager(storage, catalog);
      addTearDown(manager.dispose);
      list = File('${temp.path}/p.m3u');
      await write([
        '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
        'http://x/live/u/pw/101.ts',
        '#EXTINF:-1 tvg-id="rds" group-title="SPORTS",RDS',
        'http://x/live/u/pw/102.ts',
        '#EXTINF:-1 group-title="NEWS",CNN',
        'http://x/live/u/pw/103.ts',
        '#EXTINF:-1 tvg-id="cp24" group-title="NEWS",CP24',
        'http://x/live/u/pw/104.ts',
      ]);
      await manager.addPlaylist(PlaylistProfile(
          id: 'p',
          name: 'Home',
          mode: 'm3u',
          m3uUrl: Uri.file(list.path).toString(),
          sortOrder: 0,
          createdAt: DateTime(2026)));
      await manager.loadPlaylist('p');
    });

    Channel channel(String name) => manager
        .visibleChannels(category: 'tv')
        .firstWhere((c) => c.name == name);
    List<String> favourites() =>
        [for (final c in manager.orderedFavoriteLiveChannels()) c.name];

    test('Favourites, their order and own groups follow new ids', () async {
      await manager.toggleFavorite(channel('CNN'));
      await manager.toggleFavorite(channel('TSN 1'));
      await manager.moveFavoriteLiveChannel(channel('CNN'), -1);
      expect(favourites(), ['CNN', 'TSN 1'], reason: 'not playlist order');
      final picks = await manager.createUserGroup('Picks');
      await manager.moveChannelToGroup(channel('RDS'), picks);
      final oldCnn = channel('CNN').id;

      // The provider's update: TSN 1 and RDS get new EPG ids, a channel is
      // added on top (every line without a tvg-id moves down one).
      await write([
        '#EXTINF:-1 tvg-id="new" group-title="NEWS",CTV News',
        'http://x/live/u/pw/100.ts',
        '#EXTINF:-1 tvg-id="tsn1.ca" group-title="SPORTS",TSN 1',
        'http://x/live/u/pw/101.ts',
        '#EXTINF:-1 tvg-id="rds.ca" group-title="SPORTS",RDS',
        'http://x/live/u/pw/102.ts',
        '#EXTINF:-1 group-title="NEWS",CNN',
        'http://x/live/u/pw/103.ts',
        '#EXTINF:-1 tvg-id="cp24" group-title="NEWS",CP24',
        'http://x/live/u/pw/104.ts',
      ]);
      await manager.loadPlaylist('p');
      await settle();

      expect(channel('CNN').id, isNot(oldCnn), reason: 'the id did change');
      expect(favourites(), ['CNN', 'TSN 1'], reason: 'same channels, order');
      expect(channel('TSN 1').isFavorite, isTrue);
      expect(manager.liveGroupOf(channel('RDS')), picks);
      expect(storage.getFavorites(), {channel('TSN 1').id, channel('CNN').id});
      expect(
          SavedLiveChannels.decode(
                  storage.getSavedLiveKeys(AppConstants.mainViewerId))
              .keys,
          unorderedEquals(
              [channel('TSN 1').id, channel('CNN').id, channel('RDS').id]));
    });

    test('a channel the provider dropped stays saved for when it is back',
        () async {
      await manager.toggleFavorite(channel('CP24'));
      final id = channel('CP24').id;
      await write([
        '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
        'http://x/live/u/pw/101.ts',
        '#EXTINF:-1 tvg-id="weather" group-title="NEWS",Weather',
        'http://x/live/u/pw/555.ts',
      ]);
      await manager.loadPlaylist('p');
      await settle();
      expect(favourites(), isEmpty, reason: 'nothing guessed in its place');
      expect(storage.getFavorites(), {id});
      expect(
          SavedLiveChannels.decode(
              storage.getSavedLiveKeys(AppConstants.mainViewerId)),
          contains(id));
    });

    test('unstarring forgets the channel\'s identity at the next load',
        () async {
      await manager.toggleFavorite(channel('RDS'));
      expect(
          SavedLiveChannels.decode(
              storage.getSavedLiveKeys(AppConstants.mainViewerId)),
          contains(channel('RDS').id));
      await manager.toggleFavorite(channel('RDS'));
      await manager.loadPlaylist('p');
      await settle();
      expect(
          SavedLiveChannels.decode(
              storage.getSavedLiveKeys(AppConstants.mainViewerId)),
          isEmpty);
    });
  });
}
