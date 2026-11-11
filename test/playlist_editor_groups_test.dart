import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_editor_server.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The editor server's Move / Copy to group routes (2026-11-11), against
/// real playlists: groupdest lists destinations, place moves or copies
/// (applied at once), unplace puts channels back.
class _RealHttp extends HttpOverrides {}

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
  late PlaybackService playback;
  late PlaylistEditorServer server;
  late HttpClient client;
  late Uri base;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_editor_grp_');
    addTearDown(() => temp.delete(recursive: true));
    final storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    manager = PlaylistManager(storage, catalog);
    for (final (id, name, rows) in [
      (
        'p',
        'Home',
        [
          '#EXTINF:-1 tvg-id="cnn" group-title="NEWS",CNN',
          'http://x/1.ts',
          '#EXTINF:-1 tvg-id="rds" group-title="SPORTS",RDS',
          'http://x/2.ts',
        ]
      ),
      (
        'q',
        'Other',
        [
          '#EXTINF:-1 tvg-id="bbc" group-title="UK",BBC One',
          'http://y/1.ts',
          '#EXTINF:-1 tvg-id="itv" group-title="UK",ITV',
          'http://y/2.ts',
          '#EXTINF:-1 tvg-id="espn" group-title="SPORTS",ESPN',
          'http://y/3.ts',
        ]
      ),
    ]) {
      final file = File('${temp.path}/$id.m3u');
      await file.writeAsString(['#EXTM3U', ...rows, ''].join('\n'));
      await manager.addPlaylist(PlaylistProfile(
          id: id,
          name: name,
          mode: 'm3u',
          m3uUrl: Uri.file(file.path).toString(),
          sortOrder: id == 'p' ? 0 : 1,
          createdAt: DateTime(2026)));
      await manager.loadPlaylist(id);
    }
    playback = PlaybackService(storage, manager);
    server = PlaylistEditorServer(manager, playback, storage);
    await server.start();
    base = Uri.parse(server.address!);
    client =
        HttpOverrides.runWithHttpOverrides(() => HttpClient(), _RealHttp());
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    server.dispose();
    playback.dispose();
    manager.dispose();
  });

  Future<({int status, Map data})> request(String path, {Object? body}) async {
    final req =
        await client.openUrl(body == null ? 'GET' : 'POST', base.resolve(path));
    req.headers.set('x-editor-code', server.code);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    final data = await utf8.decoder.bind(res).join();
    return (
      status: res.statusCode,
      data: data.isEmpty ? {} : jsonDecode(data) as Map
    );
  }

  String raw(String name) => manager
      .visibleChannels(category: 'tv')
      .firstWhere((c) => c.name == name)
      .rawId;
  List<String> names(String playlist, String group) => [
        for (final c in manager.visibleChannels(
            playlistId: playlist, groupTitle: group, category: 'tv'))
          c.name
      ];

  test('groupdest lists own groups, playlists and a playlist\'s groups',
      () async {
    await manager.createUserGroup('Picks');
    final top = await request('/api/groupdest?pl=p');
    expect(top.status, 200);
    expect(top.data['restricted'], false);
    expect(top.data['own'], [
      {'t': 'Picks', 'n': 0}
    ]);
    expect([for (final p in top.data['playlists'] as List) p['name']],
        ['Home', 'Other']);
    final groups = await request('/api/groupdest?pl=p&to=q');
    expect({
      for (final g in groups.data['groups'] as List) g['t']: g['n'],
    }, {
      'UK': 2,
      'SPORTS': 1
    });
    expect((await request('/api/groupdest?pl=p&to=nope')).status, 404);
  });

  test('copy into another playlist\'s group shows at once, on the rows too',
      () async {
    final r = await request('/api/place?pl=p', body: {
      'ids': [raw('CNN')],
      'mode': 'copy',
      'to': {'playlist': 'q', 'group': 'UK'},
    });
    expect(r.status, 200);
    expect(r.data['changed'], 1);
    expect(r.data['group'], 'Other › UK');
    expect(r.data['placements'][raw('CNN')]['cp'], ['Other › UK']);
    expect(names('q', 'UK'), ['BBC One', 'ITV', 'CNN']);
    expect(names('p', 'NEWS'), ['CNN'], reason: 'a copy stays');
    final channels = await request('/api/channels?pl=p');
    final row = (channels.data['channels'] as List)
        .firstWhere((c) => c['r'] == raw('CNN'));
    expect(row['cp'], ['Other › UK']);
    expect(row.containsKey('mv'), isFalse);
  });

  test('move into a new custom group, then put it back', () async {
    final moved = await request('/api/place?pl=p', body: {
      'ids': [raw('RDS')],
      'mode': 'move',
      'to': {'newOwn': 'Weekend'},
    });
    expect(moved.data['changed'], 1);
    expect(moved.data['group'], 'Weekend (my group)');
    expect(manager.userGroups, ['Weekend']);
    expect(names('p', 'SPORTS'), isEmpty);
    expect([
      for (final c
          in manager.visibleChannels(groupTitle: 'Weekend', category: 'tv'))
        c.name
    ], [
      'RDS'
    ]);
    final again = await request('/api/place?pl=p', body: {
      'ids': [raw('RDS')],
      'mode': 'move',
      'to': {'own': 'Weekend'},
    });
    expect(again.data['changed'], 0);
    expect(again.data['skipped'], 1);
    final back = await request('/api/unplace?pl=p', body: {
      'ids': [raw('RDS'), raw('CNN')],
    });
    expect(back.data['changed'], 1);
    expect(back.data['placements'], isEmpty);
    expect(names('p', 'SPORTS'), ['RDS']);
  });

  test('a missing group, a missing selection and a blank name are refused',
      () async {
    Future<String?> error(Map<String, Object?> body) async =>
        (await request('/api/place?pl=p', body: body)).data['error'] as String?;
    expect(
        await error({
          'ids': [raw('CNN')],
          'mode': 'copy',
          'to': {'playlist': 'q', 'group': 'Gone'},
        }),
        'That group no longer exists.');
    expect(
        await error({
          'ids': [raw('CNN')],
          'mode': 'move',
          'to': {'own': 'Nope'},
        }),
        'That group no longer exists.');
    expect(
        await error({
          'ids': <String>[],
          'mode': 'move',
          'to': {'own': 'x'},
        }),
        'Select channels first.');
    expect(
        await error({
          'ids': [raw('CNN')],
          'mode': 'move',
          'to': {'newOwn': '   '},
        }),
        'Type a name for the new group.');
    expect(manager.userGroups, isEmpty, reason: 'nothing was created');
    expect(names('p', 'NEWS'), ['CNN']);
  });
}
