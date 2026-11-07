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
  Future<void> playChannel(Channel channel) async => played.add(channel.name);
  @override
  Future<void> openSeries(XtreamSeries series) async {}
  @override
  Future<bool> openSection(String section, {String? query}) async {
    opened.add('$section:$query');
    return true;
  }

  final opened = <String>[];
  final played = <String>[];
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
    final temp = await Directory.systemTemp.createTemp('vesper_voice_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="sn1" group-title="CA| SPORTS",CA: Sportsnet One',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="tsn1" group-title="CA| SPORTS",CA: TSN 1',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="ufc" group-title="PPV | EVENTS",UFC 310',
      'http://x/3.ts',
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

  test('"TSN one" plays TSN 1, not Sportsnet One', () async {
    final r = await box.call('play', {'name': 'tsn one'});
    expect(r['playing'], 'CA: TSN 1', reason: '$r');
    expect(host.played, ['CA: TSN 1']);
  });

  test('a hidden channel is never played from an old ref', () async {
    final found = await box.call('search', {'query': 'sportsnet one'});
    final ref = ((found['live'] as List).first as Map)['ref'] as String;
    final sn = manager.channels.firstWhere((c) => c.name.contains('Sportsnet'));
    await manager.toggleChannelHidden(sn);
    final r = await box.call('play', {'ref': ref});
    expect(r['error'], contains('hidden'));
    expect(host.played, isEmpty);
    final again = await box.call('search', {'query': 'sportsnet one'});
    expect(again['live'], isEmpty);
  });

  test('"pay per view" opens the PPV group; unknown words search', () async {
    final r =
        await box.call('open', {'section': 'group', 'query': 'pay per view'});
    expect(r['group'], 'PPV | EVENTS', reason: '$r');
    expect(host.opened, ['group:PPV | EVENTS']);
    final none =
        await box.call('open', {'section': 'group', 'query': 'kids zone'});
    expect(none['opened'], 'search');
    expect(host.opened.last, 'search:kids zone');
  });
}
