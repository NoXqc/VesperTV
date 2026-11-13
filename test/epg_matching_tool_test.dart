import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_channel_info.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/guide_link_log.dart';
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

const _homeGuide = 'http://guide.example/home.xml?username=me&password=secret';
const _otherGuide = 'http://other.example/xmltv.php';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistManager manager;
  late VesperToolbox box;
  late _Host host;
  late EpgService epg;

  Future<String> m3u(Directory dir, String name, List<String> lines) async {
    final file = File('${dir.path}/$name.m3u');
    await file.writeAsString(['#EXTM3U', ...lines, ''].join('\n'));
    return Uri.file(file.path).toString();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_epgmatch_');
    addTearDown(() => temp.delete(recursive: true));
    final home = await m3u(temp, 'home', [
      '#EXTINF:-1 tvg-id="x1" group-title="CA| SPORTS",CA: TSN1 FHD',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="x2" group-title="CA| SPORTS",CA: TSN 2 HD',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="espn" group-title="US| SPORTS",US: ESPN HD',
      'http://x/3.ts',
      '#EXTINF:-1 tvg-id="x4" group-title="UK| SPORTS",UK: SkySports Main Event',
      'http://x/4.ts',
      '#EXTINF:-1 tvg-id="x5" group-title="US| DOCS",Discovry Channel',
      'http://x/5.ts',
      '#EXTINF:-1 tvg-id="x6" group-title="US| SPORTS",##### SPORTS #####',
      'http://x/6.ts',
      '#EXTINF:-1 tvg-id="x7" group-title="CA| SPORTS",CA: TSN 5',
      'http://x/7.ts',
    ]);
    final other = await m3u(temp, 'other', [
      '#EXTINF:-1 tvg-id="tsn5.other" group-title="SPORTS",TSN 5 HD',
      'http://y/1.ts',
    ]);
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
        m3uUrl: home,
        epgUrl: _homeGuide,
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await manager.addPlaylist(PlaylistProfile(
        id: 'o',
        name: 'Other',
        mode: 'm3u',
        m3uUrl: other,
        epgUrl: _otherGuide,
        sortOrder: 1,
        createdAt: DateTime(2026)));
    await manager.loadPlaylist('p');
    await manager.loadPlaylist('o');
    final now = DateTime.now();
    EpgProgram on(String id, String title) => EpgProgram(
        channelId: id,
        title: title,
        description: '',
        start: now.subtract(const Duration(minutes: 10)),
        stop: now.add(const Duration(minutes: 50)));
    epg = EpgService(storage)
      ..lastUpdated = now
      ..debugSetChannelsWithData({'espn', 'tsn5.other'})
      ..debugSetSourceChannels(_homeGuide, const [
        EpgChannelInfo('TSN1.ca', 'TSN 1', null),
        EpgChannelInfo('TSN2.ca', 'TSN 2', null),
        EpgChannelInfo('SkySportsMainEvent.uk', 'Sky Sports Main Event', null),
        EpgChannelInfo('DiscoveryChannel.us', 'Discovery Channel', null),
        EpgChannelInfo('espn', 'ESPN', null),
      ], now: {
        'TSN1.ca': on('TSN1.ca', 'SportsCentre'),
      })
      ..debugSetSourceChannels(_otherGuide, const [
        EpgChannelInfo('tsn5.other', 'TSN Five', null),
      ]);
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

  Future<Map<String, Object?>> run(Map<String, Object?> args) =>
      box.call('epg_matching', args, caller: VesperCaller.remoteApp);

  Map<String, String> links(String playlistId) =>
      manager.editorSession(playlistId)!.epgIdOverrides;

  test('status: guides without their login, channels without guide', () async {
    final r = await run({'action': 'status', 'playlist': 'Home'});
    final home = (r['playlists'] as List).single as Map;
    expect(home['guides'], [
      {'n': 1, 'name': 'Main guide', 'host': 'guide.example', 'channels': 5}
    ]);
    expect('$r', isNot(contains('secret')));
    // The divider row is left out; ESPN has guide data.
    expect(home['live_channels'], 6);
    expect(home['without_guide'], 5);
  });

  test('suggest, link the sure ones, undo', () async {
    final all =
        await run({'action': 'suggest', 'playlist': 'Home', 'show': 'all'});
    expect(all['without_guide'], 5, reason: '$all');
    expect(all['sure'], 4);
    expect(all['no_match'], 1, reason: 'TSN 5 is not in this guide');
    final tsn1 = (all['channels'] as List)
        .cast<Map>()
        .firstWhere((c) => c['name'] == 'CA: TSN1 FHD');
    final best = (tsn1['suggestions'] as List).first as Map;
    expect(best['guide_id'], 'TSN1.ca');
    expect(best['now'], 'SportsCentre');

    final preview = await run(
        {'action': 'link', 'playlist': 'Home', 'sure': true, 'preview': true});
    expect(preview['links'], 4);
    expect(links('p'), isEmpty);
    expect(host.questions, isEmpty);

    final done =
        await run({'action': 'link', 'playlist': 'Home', 'sure': true});
    expect(done['changed'], isTrue, reason: '$done');
    expect(
        host.questions.single,
        'An AI app wants to link 4 channels to the '
        'TV guide.');
    expect(links('p'), {
      'x1': 'TSN1.ca',
      'x2': 'TSN2.ca',
      'x4': 'SkySportsMainEvent.uk',
      'x5': 'DiscoveryChannel.us',
    });
    expect(manager.editorSession('p')!.autoPairedEpgOverrides, hasLength(4));

    // The viewer then fixes one link by hand: undo leaves it.
    await manager.editorSession('p')!.setEpgIdOverride('x5', 'docs.us');
    final undone =
        await run({'action': 'undo', 'change_id': done['change_id']});
    expect(undone['links_restored'], 3, reason: '$undone');
    expect(undone['kept'], contains('1 link'));
    expect(links('p'), {'x5': 'docs.us'});
  });

  test('explicit links: unknown guide ids are refused', () async {
    final find = await run(
        {'action': 'find_guide', 'playlist': 'Home', 'query': 'sky sports'});
    final hit = ((find['results'] as List).single as Map)['guide_id'];
    expect(hit, 'SkySportsMainEvent.uk');
    final r = await run({
      'action': 'link',
      'playlist': 'Home',
      'links': [
        {'channel_id': 'p::x4', 'guide_id': hit},
        {'channel_id': 'p::x2', 'guide_id': 'made.up'},
        {'channel_id': 'p::nope', 'guide_id': 'TSN2.ca'},
      ],
    });
    expect(r['links'], 1, reason: '$r');
    expect((r['skipped'] as List), hasLength(2));
    expect(links('p'), {'x4': 'SkySportsMainEvent.uk'});
  });

  test('another playlist\'s guide fills the gap and is added', () async {
    final s = await run({
      'action': 'suggest',
      'playlist': 'Home',
      'from_playlist': 'Other',
      'query': 'TSN 5',
      'show': 'all',
    });
    final tsn5 = (s['channels'] as List).single as Map;
    expect(
        ((tsn5['suggestions'] as List).first as Map)['guide_id'], 'tsn5.other');
    final r = await run({
      'action': 'link',
      'playlist': 'Home',
      'from_playlist': 'Other',
      'links': [
        {'channel_id': 'p::x7', 'guide_id': 'tsn5.other'}
      ],
    });
    expect(r['changed'], isTrue, reason: '$r');
    expect(r['adds_guides'], {
      'Home': ['other.example']
    });
    expect(links('p'), {'x7': 'tsn5.other'});
    expect(manager.profiles.firstWhere((p) => p.id == 'p').extraEpgUrls,
        [_otherGuide]);

    // Undo takes the borrowed guide away again.
    await run({'action': 'undo'});
    expect(links('p'), isEmpty);
    expect(
        manager.profiles.firstWhere((p) => p.id == 'p').extraEpgUrls, isEmpty);
  });

  test('add a pasted guide link, remove it, refuse bad links', () async {
    final bad = await run(
        {'action': 'add_guide', 'playlist': 'Home', 'url': 'not a link'});
    expect(bad['error'], contains('XMLTV'));
    const url = 'https://epg.example/guide.xml.gz';
    final added =
        await run({'action': 'add_guide', 'playlist': 'Home', 'url': url});
    expect(added['changed'], isTrue, reason: '$added');
    expect(host.questions.last, 'An AI app wants to add a TV guide to Home.');
    expect(manager.profiles.firstWhere((p) => p.id == 'p').extraEpgUrls, [url]);
    final again =
        await run({'action': 'add_guide', 'playlist': 'Home', 'url': url});
    expect(again['changed'], isFalse);
    final status = await run({'action': 'status', 'playlist': 'Home'});
    final guides =
        ((status['playlists'] as List).single as Map)['guides'] as List;
    expect([for (final g in guides) (g as Map)['host']],
        ['guide.example', 'epg.example']);
    final own =
        await run({'action': 'remove_guide', 'playlist': 'Home', 'guide': 1});
    expect(own['error'], contains('own guide'));
    await run({'action': 'remove_guide', 'playlist': 'Home', 'guide': 2});
    expect(
        manager.profiles.firstWhere((p) => p.id == 'p').extraEpgUrls, isEmpty);
  });

  test('unlink and a viewer saying no on the TV', () async {
    await manager.editorSession('p')!.setEpgIdOverride('x1', 'TSN1.ca');
    host.answer = false;
    final no = await run({
      'action': 'unlink',
      'channel_ids': ['p::x1']
    });
    expect(no['error'], contains('said no'));
    expect(links('p'), {'x1': 'TSN1.ca'});
    host.answer = true;
    final yes = await run({
      'action': 'unlink',
      'channel_ids': ['p::x1', 'p::x2']
    });
    expect(yes['unlinks'], 1);
    expect(links('p'), isEmpty);
  });

  test('the guide must be loaded to suggest', () async {
    epg.isLoading = true;
    final r = await run({'action': 'suggest', 'playlist': 'Home'});
    expect(r['error'], contains('updating'));
  });

  group('help manual', () {
    final tool = vesperTools.firstWhere((t) => t.name == 'epg_matching');
    final manual = vesperHelpTopics['epg_matching']!;

    test('names every action the tool offers', () {
      final actions =
          ((tool.schema['properties'] as Map)['action'] as Map)['enum'] as List;
      for (final a in actions) {
        expect(manual, contains('- $a'), reason: a as String);
      }
    });
  });

  test('the log survives a restart', () {
    final log = GuideLinkLog();
    final c = log.add('link 1', links: {
      'p': {'a': (null, 'x.us')}
    }, guides: {
      'p': (<String>[], ['http://g'])
    });
    final back = GuideLinkLog.decode(log.encode());
    expect(back.find(null)!.id, c.id);
    expect(back.find(c.id)!.links['p']!['a'], (null, 'x.us'));
    expect(back.find(c.id)!.guides['p']!.$2, ['http://g']);
    expect(GuideLinkLog.decode('{nope').changes, isEmpty);
  });
}
