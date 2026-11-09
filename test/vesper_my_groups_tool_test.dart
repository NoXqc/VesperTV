import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Host implements VesperHost {
  final questions = <String>[];
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async {
    var s = question;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    questions.add(s);
    return true;
  }

  @override
  Future<void> playChannel(Channel channel) async {}
  @override
  Future<void> openSeries(XtreamSeries series) async {}
  @override
  Future<bool> openSection(String section, {String? query}) async => true;
  @override
  void showMessage(String text) {}
}

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

  late PlaylistManager manager;
  late VesperToolbox box;
  late _Host host;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_groups_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="rds" group-title="SPORTS",RDS',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="cnn" group-title="NEWS",CNN',
      'http://x/3.ts',
      '#EXTINF:-1 tvg-id="cp24" group-title="NEWS",CP24',
      'http://x/4.ts',
      '',
    ].join('\n'));
    final storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    await manager.addPlaylist(PlaylistProfile(
        id: 'p',
        name: 'Home',
        mode: 'm3u',
        m3uUrl: Uri.file(file.path).toString(),
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await manager.loadPlaylist('p');
    final prefs = AppPreferences(storage);
    await prefs.init();
    host = _Host();
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: EpgService(storage),
      storage: storage,
      prefs: prefs,
      host: host,
    );
  });

  Channel channel(String name) =>
      manager.visibleChannels(category: 'tv').firstWhere((c) => c.name == name);
  String ref(String name) => box.refFor(channel(name));
  List<String> names(String group) => [
        for (final c
            in manager.visibleChannels(groupTitle: group, category: 'tv'))
          c.name
      ];

  test('a Sports group of picked channels, ordered and moved', () async {
    final empty = await box.call('my_groups', {'action': 'list'});
    expect(empty['note'], contains('No own groups'));
    final added = await box.call('my_groups', {
      'action': 'add',
      'group': 'Sports',
      'refs': [ref('TSN 1'), ref('RDS'), ref('CP24'), 'nope'],
    });
    expect(added['error'], isNull, reason: '$added');
    expect(added['group'], 'Sports');
    expect(added['not_live_channels'], ['nope']);
    expect(manager.userGroups, ['Sports']);
    expect(names('Sports'), ['TSN 1', 'RDS', 'CP24']);
    // They left their provider groups.
    expect(names('SPORTS'), isEmpty);
    expect(names('NEWS'), ['CNN']);

    final ordered = await box.call('my_groups', {
      'action': 'order',
      'group': 'sports',
      'refs': [ref('CP24')],
    });
    expect(ordered['order'], ['1. CP24', '2. TSN 1', '3. RDS']);
    final moved = await box
        .call('my_groups', {'action': 'move', 'ref': ref('RDS'), 'to': 'top'});
    expect(moved['position'], 1);
    expect(names('Sports'), ['RDS', 'CP24', 'TSN 1']);

    final back = await box.call('my_groups', {
      'action': 'remove',
      'refs': [ref('CP24')],
    });
    expect(back['back_to_their_groups'], ['CP24 (NEWS)']);
    expect(names('NEWS'), ['CNN', 'CP24']);

    final again =
        await box.call('my_groups', {'action': 'create', 'group': 'Sports'});
    expect(again['note'], contains('already'));
    await box.call('my_groups', {'action': 'create', 'group': 'News'});
    expect(manager.userGroups, ['News', 'Sports']);
    final group = await box
        .call('my_groups', {'action': 'move', 'group': 'Sports', 'to': 'top'});
    expect(group['position'], 1);
    expect(manager.userGroups, ['Sports', 'News']);
  });

  test('a channel moves inside its provider group too', () async {
    final r = await box
        .call('my_groups', {'action': 'move', 'ref': ref('CP24'), 'to': 'up'});
    expect(r['group'], 'NEWS');
    expect(names('NEWS'), ['CP24', 'CNN']);
  });

  test('an AI app asks on the TV before deleting a group', () async {
    await box.call('my_groups', {
      'action': 'add',
      'group': 'Sports',
      'refs': [ref('TSN 1')],
    });
    final r = await box.call(
        'my_groups', {'action': 'delete', 'group': 'Sports'},
        caller: VesperCaller.remoteApp);
    expect(r['deleted'], 'Sports');
    expect(host.questions.single, contains('delete your group Sports'));
    expect(manager.userGroups, isEmpty);
    expect(names('SPORTS'), ['TSN 1', 'RDS']);
  });
}
