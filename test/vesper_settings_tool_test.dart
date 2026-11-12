import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/de.dart';
import 'package:nox_iptv/l10n/el.dart';
import 'package:nox_iptv/l10n/es.dart';
import 'package:nox_iptv/l10n/fr.dart';
import 'package:nox_iptv/l10n/it.dart';
import 'package:nox_iptv/l10n/pl.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_playback_preferences.dart';
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

  late _DirStorage storage;
  late PlaylistManager manager;
  late AppPreferences prefs;
  late VesperToolbox box;
  late _Host host;
  var hubCleared = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_settings_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
      'http://x/1.ts',
      '',
    ].join('\n'));
    storage = _DirStorage(temp);
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
    prefs = AppPreferences(storage);
    await prefs.init();
    host = _Host();
    hubCleared = 0;
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: EpgService(storage),
      storage: storage,
      prefs: prefs,
      host: host,
      clearHubHistory: () async {
        hubCleared++;
        return 3;
      },
    );
  });

  Map<String, Object?> setting(Map<String, Object?> list, String key) =>
      (list['settings'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((s) => s['key'] == key);

  test('list shows keys, current values and choices', () async {
    final list = await box.call('settings', {'action': 'list'});
    expect(setting(list, 'skip_intro')['value'], true);
    expect(setting(list, 'up_next')['choices'], ['early', 'end', 'off']);
    expect(setting(list, 'guide_transparency')['type'], 'number');
    expect(setting(list, 'fast_startup')['applies'], 'at the next app start');
    expect((list['clear'] as Map).keys, contains('all_history'));
    final sports = await box.call('settings', {
      'action': 'list',
      'section': 'sports',
    });
    expect(
        (sports['settings'] as List)
            .every((s) => (s as Map)['section'] == 'sports'),
        isTrue);
  });

  test('the viewer\'s own requests change settings without a confirm',
      () async {
    final r = await box.call('settings', {
      'action': 'set',
      'changes': [
        {'key': 'subtitle_size', 'value': 'Large'},
        {'key': 'guide_layout', 'value': 'timeline'},
        {'key': 'skip_intro', 'value': 'off'},
        {'key': 'guide_transparency', 'value': '140'},
      ],
    });
    expect(r['error'], isNull, reason: '$r');
    expect(prefs.subtitleScale, 1.25);
    expect(prefs.guideViewMode, 'timeline');
    expect(storage.getSkipSegments(), isFalse);
    expect(prefs.guideTransparency, 100, reason: 'clamped to its maximum');
    expect(host.questions, isEmpty);
    final again = await box.call(
        'settings', {'action': 'set', 'key': 'skip_intro', 'value': 'false'});
    expect(again['note'], contains('Already'));
  });

  test('an AI app waits for OK on the TV; No leaves the settings alone',
      () async {
    host.answer = false;
    final r = await box.call(
        'settings', {'action': 'set', 'key': 'hide_movies', 'value': 'true'},
        caller: VesperCaller.remoteApp);
    expect(r['error'], contains('said no'));
    expect(prefs.hideMovies, isFalse);
    expect(host.questions.single, contains('Hide Movies: turn on'));
    host.answer = true;
    await box.call(
        'settings', {'action': 'set', 'key': 'hide_movies', 'value': 'true'},
        caller: VesperCaller.remoteApp);
    expect(prefs.hideMovies, isTrue);
  });

  test('Media Hub playback settings: one changes, the others stay', () async {
    await storage.setArchiveOptionsJson(
        'playback', '{"source":"https://a.example/manifest.json"}');
    final r = await box.call('settings', {
      'action': 'set',
      'changes': [
        {'key': 'media_hub_largest_file', 'value': 'true'},
        {'key': 'media_hub_max_quality', 'value': '4K'},
        {'key': 'media_hub_language', 'value': 'English'},
        {'key': 'media_hub_prefer_sdr', 'value': 'on'},
      ],
    });
    expect(r['error'], isNull, reason: '$r');
    expect(storage.getArchiveAutoLargest(), isTrue);
    final saved = ArchivePlaybackPreferences.read(storage);
    expect(saved.maxHeight, 2160);
    expect(saved.language, 'en');
    expect(saved.avoidHdr, isTrue);
    expect(saved.autoPlay, isFalse);
    expect(saved.sourceKey, 'https://a.example/manifest.json',
        reason: 'not an AI setting, never lost');
    final list = await box.call('settings', {'action': 'list'});
    expect(setting(list, 'media_hub_language')['value'], 'en');
    expect(setting(list, 'media_hub_max_quality')['value'], '4k');
    await box.call('settings',
        {'action': 'set', 'key': 'media_hub_language', 'value': 'any'});
    expect(ArchivePlaybackPreferences.read(storage).language, isEmpty);
    expect(ArchivePlaybackPreferences.read(storage).maxHeight, 2160);
  });

  test('only listed settings and values are accepted', () async {
    final unknown = await box.call('settings',
        {'action': 'set', 'key': 'ask_on_the_tv_first', 'value': 'false'});
    expect(unknown['error'], contains('Unknown setting'));
    expect(storage.getAiConfirmRemotePlay(), isTrue);
    final bad = await box.call(
        'settings', {'action': 'set', 'key': 'up_next', 'value': 'sometimes'});
    expect(bad['error'], contains('early, end, off'));
  });

  test('resume at start: full screen and in the guide exclude each other',
      () async {
    await box.call('settings',
        {'action': 'set', 'key': 'resume_in_guide', 'value': 'true'});
    expect(storage.getResumeLastChannelInGuide(), isTrue);
    expect(storage.getResumeLastChannelAtStartup(), isFalse);
    final r = await box.call('settings',
        {'action': 'set', 'key': 'resume_full_screen', 'value': 'true'});
    expect(r['note'], contains('next app start'));
    expect(storage.getResumeLastChannelAtStartup(), isTrue);
    expect(storage.getResumeLastChannelInGuide(), isFalse);
  });

  test('clear empties the histories it names', () async {
    await storage.addRecentSearch('dune');
    final r = await box.call(
        'settings', {'action': 'clear', 'what': 'searches_and_channels'},
        caller: VesperCaller.remoteApp);
    expect(r['cleared'], ['searches_and_channels'], reason: '$r');
    expect(storage.getRecentSearches(), isEmpty);
    expect(host.questions.single, contains('Clear search & channel history'));
    expect(hubCleared, 0);

    final all =
        await box.call('settings', {'action': 'clear', 'what': 'all_history'});
    expect(all['cleared'],
        ['searches_and_channels', 'movies_and_shows', 'media_hub']);
    expect(all['media_hub_titles'], 3);
    expect(hubCleared, 1);
  });

  test('a kids profile can read settings but not change them', () async {
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
    manager.applyActiveViewer();
    final list = await box.call('settings', {'action': 'list'});
    expect(list['note'], contains('kids profile'));
    final set = await box.call(
        'settings', {'action': 'set', 'key': 'hide_movies', 'value': 'true'});
    expect(set['error'], contains('cannot change'));
    final clear =
        await box.call('settings', {'action': 'clear', 'what': 'all_history'});
    expect(clear['error'], contains('cannot clear'));
  });

  test('every text the TV shows is translated', () {
    for (final (name, dictionary) in [
      ('fr', kFr),
      ('de', kDe),
      ('es', kEs),
      ('it', kIt),
      ('el', kEl),
      ('pl', kPl),
    ]) {
      final missing = [
        for (final text in vesperSettingTexts)
          if (!dictionary.containsKey(text)) text,
        for (final text in const [
          'An AI app wants to change settings: {what}.',
          'An AI app wants to: {what}.',
        ])
          if (!dictionary.containsKey(text)) text,
      ];
      expect(missing, isEmpty, reason: name);
    }
  });
}
