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
import 'package:nox_iptv/services/user_groups.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_ai.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_commands.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Hold OK on a group > Rename… (owner, 2026-11-23: groups could only be
/// renamed in the playlist editor) and Vesper's "rename the group X to Y".
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
    final temp = await Directory.systemTemp.createTemp('vesper_group_rename_');
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
  List<String> names(String group) => [
        for (final c
            in manager.visibleChannels(groupTitle: group, category: 'tv'))
          c.name
      ];

  List<String> liveTitles() => [for (final g in manager.tvGroups) g.title];

  test('a live group keeps its place, star, channel order and copies',
      () async {
    await manager.moveGroup('p', 'tv', 'NEWS', -1);
    await manager.setGroupFavorited('p', 'NEWS', true);
    await manager.moveChannel(channel('CP24'), -1);
    expect(names('NEWS'), ['CP24', 'CNN']);
    await manager.placeChannels(
        [channel('TSN 1')], const GroupRef.provider('p', 'NEWS'),
        copy: true);
    expect(liveTitles(), ['NEWS', 'SPORTS']);

    final before = manager.liveViewSignature();
    expect(await manager.renameLiveGroup('p', 'NEWS', 'Info'), 'Info');
    expect(manager.liveViewSignature(), isNot(before),
        reason: 'the TV tab redraws');
    expect(liveTitles(), ['Info', 'SPORTS']);
    expect(manager.isGroupFavorited('p', 'Info'), isTrue);
    expect(names('Info').take(2), ['CP24', 'CNN']);
    expect(names('Info'), contains('TSN 1'));
    expect(manager.isLiveGroupRenamed('p', 'Info'), isTrue);

    // Use the provider's name.
    expect(await manager.renameLiveGroup('p', 'Info', ''), 'NEWS');
    expect(liveTitles(), ['NEWS', 'SPORTS']);
    expect(manager.isGroupFavorited('p', 'NEWS'), isTrue);
    expect(names('NEWS').take(2), ['CP24', 'CNN']);
    expect(manager.isLiveGroupRenamed('p', 'NEWS'), isFalse);
  });

  test('a name the playlist already has merges; the provider\'s splits',
      () async {
    expect(await manager.renameLiveGroup('p', 'SPORTS', 'NEWS'), 'NEWS');
    expect(liveTitles(), ['NEWS']);
    expect(names('NEWS'), unorderedEquals(['TSN 1', 'RDS', 'CNN', 'CP24']));
    expect(manager.isLiveGroupRenamed('p', 'NEWS'), isTrue);
    await manager.renameLiveGroup('p', 'NEWS', '');
    expect(liveTitles(), ['SPORTS', 'NEWS']);

    // Into a hidden group: the shown one doesn't vanish with it.
    await manager.setGroupHidden('p', 'NEWS', true);
    await manager.renameLiveGroup('p', 'SPORTS', 'NEWS');
    expect([
      for (final g in manager.tvGroups)
        if (!g.isHidden) g.title
    ], ['NEWS']);
  });

  test('own groups rename; a name that is taken is refused', () async {
    await manager.createUserGroup('Picks');
    await manager.moveChannelToGroup(channel('RDS'), 'Picks');
    expect(await manager.renameUserGroup('Picks', 'Faves'), 'Faves');
    expect(manager.userGroups, ['Faves']);
    expect(names('Faves'), ['RDS']);
    expect(await manager.renameUserGroup('Faves', 'NEWS'), isNull);
    // A live group can't take an own group's name either.
    expect(await manager.renameLiveGroup('p', 'NEWS', 'Faves'), isNull);
    expect(liveTitles(), ['SPORTS', 'NEWS']);
  });

  test('the editor tool\'s rename_group keeps the star too', () async {
    await manager.setGroupFavorited('p', 'SPORTS', true);
    final r = await box.call('playlist_editor',
        {'action': 'rename_group', 'group': 'SPORTS', 'new_name': 'Sport'});
    expect(r['changed'], isTrue, reason: '$r');
    expect(manager.isGroupFavorited('p', 'Sport'), isTrue);
  });

  group('Vesper, without an AI', () {
    test('rename sentences in several languages', () {
      VesperCommand? p(String s) => parseVesperCommand(s);
      expect(p('Rename the group news to My News')?.args,
          {'action': 'rename', 'group': 'news', 'name': 'My News'});
      expect(p('vesper please rename group sports to my sports')?.args,
          {'action': 'rename', 'group': 'sports', 'name': 'My Sports'});
      expect(p('rename the sports group to Sport.')?.args,
          {'action': 'rename', 'group': 'sports', 'name': 'Sport'});
      expect(p('Renomme le groupe nouvelles en Infos')?.args['name'], 'Infos');
      expect(p('renombra el grupo deportes a Fútbol')?.args['name'], 'Fútbol');
      expect(p('rinomina il gruppo sport in Calcio')?.args['group'], 'sport');
      expect(
          p('Benenne die Gruppe sport in Fußball um')?.args['name'], 'Fußball');
      expect(p('rename group sports to my sports')?.tool, 'my_groups');
    });

    test('the sentence renames through my_groups', () async {
      final cmd = parseVesperCommand('rename the group news to Info')!;
      final r = await box.call(cmd.tool, cmd.args);
      expect(r['renamed'], 'NEWS', reason: '$r');
      expect(liveTitles(), contains('Info'));
      expect(VesperAi.describeResult(cmd, r).text, contains('Info'));

      final missing = parseVesperCommand('rename the group movies to Films')!;
      final m = await box.call(missing.tool, missing.args);
      expect(m['error'], contains('No group named'));
      expect(VesperAi.describeResult(missing, m).understood, isFalse);
    });

    test('an AI app asks on the TV first', () async {
      final r = await box.call(
          'my_groups', {'action': 'rename', 'group': 'sports', 'name': 'Sport'},
          caller: VesperCaller.remoteApp);
      expect(r['to'], 'Sport', reason: '$r');
      expect(host.questions.single, contains('rename your group SPORTS'));
    });
  });
}
