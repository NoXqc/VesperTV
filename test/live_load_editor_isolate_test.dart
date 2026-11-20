import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_edits.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/channel_name_matching.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A saved Xtream live list is read on an isolate at launch, and since
/// 2026-11-19 the playlist editor layer is applied there too (LOG-PJTTML: a
/// 57k-channel list froze a Homatics for 5.5 s on the main thread, and a
/// key press then had Android close the app). The result must be the one
/// the main thread would have worked out.
class _DirStorage extends StorageService {
  _DirStorage(this.dir);
  final Directory dir;
  @override
  Future<String?> cacheFilePath(String name) async {
    final f = File('${dir.path}/$name.json');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> writeCacheFile(String name, String content) =>
      File('${dir.path}/$name.json').writeAsString(content);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Channel ch(int i, String name, String group) => Channel(
      id: 'x::$i',
      rawId: '$i',
      playlistId: 'x',
      name: name,
      group: group,
      url: 'http://h/live/u/p/$i.ts');

  final source = [
    ch(1, 'UK| SKY SPORTS MAIN EVENT FHD', 'UK| SPORT'),
    ch(2, 'UK| SKY SPORTS MAIN EVENT HD', 'UK| SPORT'),
    ch(3, 'UK| SKY SPORTS MAIN EVENT SD', 'UK| SPORT'),
    ch(4, 'UK| BBC ONE ᵛᶦᵖ', 'UK| GENERAL'),
    ch(5, '##### SPORTS #####', 'UK| SPORT'),
    ch(6, 'UK| ADULT 1', 'UK| OTHER'),
    ch(7, 'UK| ITV 1 HD', 'UK| GENERAL'),
  ];
  final edits = PlaylistEdits(
    names: {'7': 'ITV One'},
    hidden: {'4'},
    hideLowerCopies: true,
    hideSeparators: true,
    rules: [
      EditRule(type: 'replace', find: 'UK| '),
      EditRule(type: 'hide', find: 'ADULT'),
    ],
  );

  test('the launch isolate applies the editor layer as the main thread would',
      () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_liveiso_');
    addTearDown(() => temp.delete(recursive: true));
    final storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    await storage.writeCacheFile('xtream_live_channels_x',
        jsonEncode([for (final c in source) c.toJson()]));
    final session = PlaylistSession(
      profile: PlaylistProfile(
          id: 'x',
          name: 'X',
          mode: 'xtream',
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: catalog,
      favoriteIds: () => {},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {},
    )..edits = PlaylistEdits.decode(edits.encode());

    await session.ensureLiveChannelsLoaded();

    // The same edits on the main thread, on fresh copies.
    final expected = [
      for (final c in source) Channel.fromJson(c.toJson()),
    ];
    final expectedHidden = edits.apply(expected);
    expect(session.editHidden, expectedHidden);
    expect(session.editHidden, {'2', '3', '4', '5', '6'});
    expect([for (final c in session.liveChannels) c.name],
        [for (final c in expected) c.name]);
    expect(session.liveChannels.last.name, 'ITV One');
    expect(session.liveChannels.first.name, 'SKY SPORTS MAIN EVENT FHD');
    // Its copy keys came along: Combine playlists finds them remembered.
    expect(channelCopyKey('SKY SPORTS MAIN EVENT FHD'),
        channelCopyKey('SKY SPORTS MAIN EVENT HD'));
  });
}
