import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:nox_iptv/services/vesper_ai/watch_list.dart';
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

const _addon = ArchiveSource(
    manifestUrl: 'https://addon.example/k3y/manifest.json', name: 'Torrentio');
const _server = ArchiveSource(
    manifestUrl: 'https://jelly.example/manifest.json', name: 'Jellyfin');

ArchiveStreamOption _stream(ArchiveSource source, String name, String title,
        {String file = 'f'}) =>
    ArchiveStreamOption(
        source: source,
        stream: ArchiveStream(
            url: 'https://debrid.example/secret-token/$file.mkv',
            name: name,
            title: title));

/// Media Hub with one movie and one show, recording what it was asked.
class _Hub implements VesperHub {
  final movie = HubTitle(
      _addon.manifestUrl,
      const ArchiveMeta(
          id: 'tt0074285',
          type: ArchiveType.movie,
          name: 'Carrie',
          year: '1976'));
  final show = HubTitle(
      _addon.manifestUrl,
      const ArchiveMeta(
          id: 'tt11280740', type: ArchiveType.series, name: 'Severance'));
  static const episodes = [
    ArchiveVideo(
        id: 'tt11280740:1:1', title: 'Good News', season: 1, episode: 1),
    ArchiveVideo(
        id: 'tt11280740:2:3', title: 'Who Is Alive?', season: 2, episode: 3),
  ];

  final options = [
    _stream(_addon, 'Torrentio\n4k DV | HDR [TB download]',
        'Carrie.1976.2160p.UHD.Remux.DV.HEVC.TrueHD.Atmos.7.1 💾 70 GB',
        file: 'a'),
    _stream(_addon, 'Torrentio\n1080p [TB+]',
        'Carrie.1976.1080p.BluRay.x264.DDP5.1 💾 9.8 GB',
        file: 'b'),
    _stream(_server, 'Jellyfin\n4K',
        'Carrie (1976) 2160p HDR10 HEVC DDP5.1 Atmos 31 GB',
        file: 'c'),
  ];
  final played = <(HubTitle, ArchiveVideo?, ArchiveStreamOption?)>[];
  HubTitle? opened;

  @override
  Future<List<HubTitle>> search(String query,
          {ArchiveType? type, int limit = 8}) async =>
      [
        if (type != ArchiveType.series &&
            'carrie'.contains(query.toLowerCase()))
          movie,
        if (type != ArchiveType.movie &&
            'severance'.contains(query.toLowerCase()))
          show,
      ];

  @override
  Future<HubTitle?> details(HubTitle title) async => title == show
      ? HubTitle(
          show.sourceUrl,
          const ArchiveMeta(
              id: 'tt11280740',
              type: ArchiveType.series,
              name: 'Severance',
              videos: episodes))
      : title;

  @override
  Future<List<ArchiveStreamOption>> streams(HubTitle title,
          {ArchiveVideo? episode}) async =>
      options;

  @override
  Future<String> play(HubTitle title,
      {ArchiveVideo? episode, ArchiveStreamOption? option}) async {
    played.add((title, episode, option));
    return 'archive::x';
  }

  @override
  Future<void> openShow(HubTitle show) async => opened = show;

  List<(HubTitle, ArchiveVideo?)> going = const [];

  @override
  List<(HubTitle, ArchiveVideo?)> continueWatching() => going;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  mediaHubStartWait = Duration.zero;

  late VesperToolbox box;
  late _Hub hub;
  late _Host host;
  late StorageService storage;
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_hub_');
    addTearDown(() => temp.delete(recursive: true));
    storage = StorageService();
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    final manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    prefs = AppPreferences(storage);
    await prefs.init();
    hub = _Hub();
    host = _Host();
    box = VesperToolbox(
      playlist: manager,
      playback: PlaybackService(storage, manager),
      epg: EpgService(storage),
      storage: storage,
      prefs: prefs,
      host: host,
      hub: hub,
    );
  });

  test('search hands out title refs', () async {
    final r =
        await box.call('media_hub', {'action': 'search', 'query': 'carrie'});
    final titles = r['titles'] as List;
    expect(titles.single, containsPair('title', 'Carrie'));
    expect(titles.single, containsPair('kind', 'movie'));
    expect(titles.single, containsPair('year', '1976'));
    expect((titles.single as Map)['ref'], startsWith('h'));
  });

  test('sources: quality, audio, size, ready and best; never a link', () async {
    final ref = ((await box.call(
                'media_hub', {'action': 'search', 'query': 'carrie'}))['titles']
            as List)
        .single['ref'];
    final r = await box.call('media_hub', {'action': 'sources', 'ref': ref});
    final list = (r['sources'] as List).cast<Map>();
    expect(list, hasLength(3));
    expect(list[0]['video'], '4K Dolby Vision HDR HEVC');
    expect(list[0]['audio'], 'TrueHD 7.1 Atmos');
    expect(list[0]['ready'], isFalse, reason: 'still downloading');
    expect(list[0]['size_gb'], 70.0);
    expect(list[1]['audio'], 'E-AC-3 5.1');
    expect(list[1]['ready'], isTrue);
    expect(list[2]['audio'], 'E-AC-3 5.1 Atmos');
    expect(list[2]['source'], 'Jellyfin');
    // Best: the highest quality that can play now (the 4K download can't).
    expect(r['best'], list[2]['ref']);
    final json = jsonEncode(r);
    expect(json, isNot(contains('http')));
    expect(json, isNot(contains('secret-token')));
  });

  test('play best starts the best stream; a stream ref plays that one',
      () async {
    final ref = ((await box.call(
                'media_hub', {'action': 'search', 'query': 'carrie'}))['titles']
            as List)
        .single['ref'];
    var r = await box
        .call('media_hub', {'action': 'play', 'ref': ref, 'best': true});
    expect(r['playing'], 'Carrie', reason: '$r');
    expect(hub.played.single.$3, same(hub.options[2]));

    final sources =
        await box.call('media_hub', {'action': 'sources', 'ref': ref});
    final second = ((sources['sources'] as List)[1] as Map)['ref'];
    r = await box.call('media_hub', {'action': 'play', 'ref': second});
    expect(hub.played.last.$3, same(hub.options[1]));

    // Without best, the app picks as usual (saved pick, Auto-play, list).
    await box.call('media_hub', {'action': 'play', 'query': 'carrie'});
    expect(hub.played.last.$3, isNull);
  });

  test('a show opens its page, or plays the episode asked for', () async {
    var r =
        await box.call('media_hub', {'action': 'play', 'query': 'severance'});
    expect(r['opened'], 'Severance');
    expect(hub.opened, same(hub.show));

    r = await box.call('media_hub',
        {'action': 'play', 'query': 'severance', 'season': 2, 'episode': 3});
    expect(r['playing'], 'Severance S02E03 - Who Is Alive?', reason: '$r');
    expect(hub.played.last.$2?.id, 'tt11280740:2:3');

    r = await box.call('media_hub',
        {'action': 'play', 'query': 'severance', 'season': 9, 'episode': 1});
    expect(r['error'], contains('no season 9 episode 1'));

    r = await box
        .call('media_hub', {'action': 'episodes', 'query': 'severance'});
    expect(r['seasons'], [1, 2]);
    expect((r['episodes'] as List).single, containsPair('episode', 3));
  });

  test('continue plays the title in Continue watching, a show at its episode',
      () async {
    hub.going = [(hub.movie, null), (hub.show, _Hub.episodes[1])];
    var r = await box
        .call('media_hub', {'action': 'continue', 'query': 'severance'});
    expect(r['playing'], contains('Severance'));
    expect(hub.played.last.$1, hub.show);
    expect(hub.played.last.$2, _Hub.episodes[1]);
    expect(hub.played.last.$3, isNull, reason: 'the stream picked last time');
    r = await box.call('media_hub', {'action': 'continue', 'query': 'Carrie'});
    expect(r['playing'], 'Carrie');
    expect(hub.played.last.$2, isNull);
  });

  test('continue on a title not started plays it like play', () async {
    final r =
        await box.call('media_hub', {'action': 'continue', 'query': 'carrie'});
    expect(r['playing'], 'Carrie');
    expect(hub.played.single.$1, hub.movie);
    expect(
        (await box.call('media_hub', {'action': 'continue', 'query': 'zzz'}))
            .containsKey('error'),
        isTrue);
  });

  test('an AI app asks on the TV before playing', () async {
    await storage.setAiConfirmRemotePlay(true);
    await box.call('media_hub', {'action': 'play', 'query': 'carrie'},
        caller: VesperCaller.remoteApp);
    expect(host.questions.single, 'An AI app wants to play Carrie.');
  });

  test('switch needs a Media Hub title playing; hidden Media Hub refuses',
      () async {
    final r = await box.call('media_hub', {'action': 'switch', 'ref': 'next'});
    expect(r['error'], isNotNull);
    prefs.setHideArchive(true);
    final hidden =
        await box.call('media_hub', {'action': 'search', 'query': 'carrie'});
    expect(hidden['error'], contains('Media Hub is hidden'));
  });

  test('next stream skips downloads and wraps around', () {
    final o = _Hub().options;
    expect(hubNextStream(o, 1), same(o[2]));
    expect(hubNextStream(o, 2), same(o[1]), reason: 'o[0] is downloading');
    expect(hubNextStream([o[1]], 0), isNull);
  });

  test('best is listed even past the first 25, with how it was picked',
      () async {
    // The Batman (owner, 2026-11-09): best was the 57th stream, and the
    // largest one with English beside other languages lost to English-only.
    await storage.setArchiveAutoLargest(true);
    await storage.setPreferredAudioLanguage('en');
    hub.options
      ..clear()
      ..addAll([
        for (var i = 0; i < 30; i++)
          _stream(_addon, 'Torrentio\n4k', 'Movie 2160p 🇷🇺 💾 ${90 + i} GB',
              file: 'dub$i'),
        _stream(_addon, 'Torrentio\n4k',
            'Movie 2160p 🗣 English | Russian 💾 77.3 GB',
            file: 'multi'),
        _stream(_addon, 'Torrentio\n4k', 'Movie 2160p 💾 76.5 GB', file: 'en'),
      ]);
    final ref = ((await box.call(
                'media_hub', {'action': 'search', 'query': 'carrie'}))['titles']
            as List)
        .single['ref'];
    final r = await box.call('media_hub', {'action': 'sources', 'ref': ref});
    final list = (r['sources'] as List).cast<Map>();
    expect(list, hasLength(26));
    expect(list.last['ref'], r['best']);
    expect(list.last['size_gb'], 77.3);
    expect(r['best_rule'], contains('largest file'));
    expect(r['best_rule'], contains('en audio'));
    expect(r['note'], contains('then best'));
  });

  test('best follows the viewer\'s Media Hub playback limit', () async {
    await storage.setArchiveOptionsJson(
        'playback', jsonEncode({'maxHeight': 1080}));
    expect(
        hubBestStream(storage, _Hub().options)?.stream.name, contains('1080p'));
  });
}
