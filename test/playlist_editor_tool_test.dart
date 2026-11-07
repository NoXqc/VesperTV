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

/// The TV side of an AI-app request: answers the confirm, records it.
class _Host implements VesperHost {
  bool answer = true;
  final questions = <String>[];
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async {
    var s = question;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    questions.add(s);
    return answer;
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

/// Cache files in a temp folder instead of path_provider's.
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
    final temp = await Directory.systemTemp.createTemp('vesper_editor_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="tsn1" group-title="CA| SPORTS",CA: TSN 1',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="tsn2" group-title="CA| SPORTS",CA: TSN 2',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="canal" group-title="FR| SPORTS",CANAL+ SPORT',
      'http://x/3.ts',
      '#EXTINF:-1 tvg-id="ng1" group-title="CA| SPORTS",NOGUIDE ONE',
      'http://x/4.ts',
      '#EXTINF:-1 tvg-id="ng2" group-title="CA| SPORTS",NOGUIDE TWO',
      'http://x/5.ts',
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
    final epg = EpgService(storage)
      ..lastUpdated = DateTime.now()
      ..debugSetChannelsWithData({'tsn1', 'tsn2', 'canal'});
    final prefs = AppPreferences(storage);
    await prefs.init();
    host = _Host();
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: epg,
      storage: storage,
      prefs: prefs,
      host: host,
    );
  });

  Future<Map<String, Object?>> edit(Map<String, Object?> args) =>
      box.call('playlist_editor', args, caller: VesperCaller.remoteApp);

  Future<String> idOf(String name) async {
    final r = await edit({'action': 'find_channels', 'query': name});
    final list = r['channels'] as List;
    return (list.firstWhere((c) => (c as Map)['name'] == name) as Map)['id']
        as String;
  }

  List<String> visible() =>
      [for (final c in manager.visibleChannels(category: 'tv')) c.name];

  test('hide channels without guide data: preview, confirm, undo', () async {
    final preview = await edit({'action': 'hide_no_guide', 'preview': true});
    expect(preview['preview'], isTrue);
    expect(((preview['playlists'] as List).single as Map)['hidden'], 2);
    expect(visible(), hasLength(5), reason: 'a preview changes nothing');
    expect(host.questions, isEmpty);

    final done = await edit({'action': 'hide_no_guide'});
    expect(done['changed'], isTrue, reason: '$done');
    expect(host.questions.single, contains('2 channels hidden'));
    expect(visible(), ['CA: TSN 1', 'CA: TSN 2', 'CANAL+ SPORT']);
    final hidden = await edit({'action': 'find_channels', 'only': 'hidden'});
    expect(
        [for (final c in hidden['channels'] as List) (c as Map)['hidden_by']],
        ['editor', 'editor']);

    final undone = await edit({'action': 'undo'});
    expect(undone['undid'], contains(done['change_id'] as String));
    expect(visible(), hasLength(5));
    final again = await edit({'action': 'undo'});
    expect(again['error'], contains('no AI playlist change'));
  });

  test('strip CA affixes with a rule, then undo it', () async {
    final r = await edit({
      'action': 'add_rule',
      'rule_type': 'replace',
      'regex': true,
      'find': r'^\s*CA\s*[:|\-]+\s*',
      'replace': '',
    });
    expect(((r['playlists'] as List).single as Map)['renamed'], 2);
    expect(visible(),
        ['TSN 1', 'TSN 2', 'CANAL+ SPORT', 'NOGUIDE ONE', 'NOGUIDE TWO']);
    final list = await edit({'action': 'list'});
    final rules = ((list['playlists'] as List).single as Map)['rules'] as List;
    expect((rules.single as Map)['n'], 1);
    expect((list['ai_changes'] as List), hasLength(1));
    await edit({'action': 'undo', 'change_id': r['change_id']});
    expect(visible().first, 'CA: TSN 1');
  });

  test('fallback channel is tried first when the channel fails', () async {
    final tsn1 = await idOf('CA: TSN 1');
    final canal = await idOf('CANAL+ SPORT');
    final r = await edit(
        {'action': 'add_fallback', 'channel_id': tsn1, 'fallback_id': canal});
    expect(r['changed'], isTrue, reason: '$r');
    final channel = manager.channels.firstWhere((c) => c.id == tsn1);
    expect(manager.failoverCandidatesFor(channel).first.id, canal);
    await edit({'action': 'undo'});
    expect(manager.failoverCandidatesFor(channel).map((c) => c.id),
        isNot(contains(canal)));
  });

  test('no on the TV changes nothing', () async {
    host.answer = false;
    final r = await edit({'action': 'hide_no_guide'});
    expect(r['error'], contains('said no'));
    expect(visible(), hasLength(5));
    expect((await edit({'action': 'list'}))['ai_changes'], isEmpty);
  });

  test('undo keeps a rename the viewer made by hand since', () async {
    final tsn1 = await idOf('CA: TSN 1');
    final tsn2 = await idOf('CA: TSN 2');
    final r = await edit({
      'action': 'rename',
      'renames': [
        {'channel_id': tsn1, 'new_name': 'AI One'},
        {'channel_id': tsn2, 'new_name': 'AI Two'},
      ],
    });
    expect(((r['playlists'] as List).single as Map)['renamed'], 2);
    // The viewer renames TSN 1 again in the editor page.
    final s = manager.editorSession('p')!;
    final rawTsn1 = tsn1.split('::').last;
    await s.saveEdits(s.edits..names[rawTsn1] = 'Viewer One');
    final undone = await edit({'action': 'undo'});
    expect(undone['kept'], contains('1 part'));
    expect(visible().take(2), ['Viewer One', 'CA: TSN 2']);
  });

  test('a hide rule matching every channel is refused', () async {
    final r = await edit({
      'action': 'add_rule',
      'rule_type': 'hide',
      'find': '.',
      'regex': true
    });
    expect(r['error'], contains('every channel'));
    expect(visible(), hasLength(5));
  });

  test('the help tool serves the manual', () async {
    final r = await box.call('vesper_help', {'topic': 'playlist_editor'});
    expect(r['manual'], contains('undo [change_id]'));
    expect((await box.call('vesper_help', {'topic': 'nope'}))['error'],
        contains('Topics'));
  });
}
