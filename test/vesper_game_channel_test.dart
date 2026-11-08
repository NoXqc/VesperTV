import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
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

SportsGame _game(String id, String home, String away) => SportsGame(
      id: id,
      league: sportsLeagueById('nba')!,
      start: DateTime.now().add(const Duration(hours: 2)),
      state: GameState.pre,
      statusText: '7:30 PM',
      home:
          SportsTeam(id: home, name: home, shortName: home, abbreviation: home),
      away:
          SportsTeam(id: away, name: away, shortName: away, abbreviation: away),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistManager manager;
  late StorageService storage;
  late VesperToolbox box;
  late _Host host;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_game_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="lp1" group-title="US| NBA LEAGUE PASS",NBA 01: Celtics vs. Knicks',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="lp2" group-title="US| NBA LEAGUE PASS",NBA 02: Lakers vs. Suns',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="lp3" group-title="US| NBA LEAGUE PASS",NBA 03',
      'http://x/3.ts',
      '#EXTINF:-1 tvg-id="nbatv" group-title="US| NBA LEAGUE PASS 4K",NBA TV',
      'http://x/4.ts',
      '#EXTINF:-1 tvg-id="tsn1" group-title="CA| SPORTS",CA: TSN 1',
      'http://x/5.ts',
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

  Channel named(String name) =>
      manager.channels.firstWhere((c) => c.name == name);

  test('groups channels lists one group, with the similar ones named',
      () async {
    final r = await box.call('groups',
        {'action': 'channels', 'tab': 'tv', 'group': 'nba league pass'});
    expect(r['group'], 'US| NBA LEAGUE PASS', reason: '$r');
    final names = [
      for (final c in r['channels'] as List) (c as Map)['title'],
    ];
    expect(names, [
      'NBA 01: Celtics vs. Knicks',
      'NBA 02: Lakers vs. Suns',
      'NBA 03',
    ]);
    expect(r['similar_groups'], contains('US| NBA LEAGUE PASS 4K'));
    final ref = ((r['channels'] as List).first as Map)['ref'] as String;
    expect(box.lookup(ref), isA<Channel>());
  });

  test('groups channels: an unknown group says so', () async {
    final r = await box.call(
        'groups', {'action': 'channels', 'tab': 'tv', 'group': 'cricket zone'});
    expect(r['error'], contains('No live group'));
  });

  test('game_channel saves picks the cards read, one OK for the list',
      () async {
    final celtics = _game('1', 'Knicks', 'Celtics');
    final lakers = _game('2', 'Suns', 'Lakers');
    final picks = [
      {
        'game': box.refFor(celtics),
        'channel': box.refFor(named('NBA 01: Celtics vs. Knicks')),
      },
      {
        'game': box.refFor(lakers),
        'channel': box.refFor(named('NBA 02: Lakers vs. Suns')),
      },
    ];
    final r = await box.call('game_channel', {'picks': picks},
        caller: VesperCaller.remoteApp);
    expect((r['saved'] as List).length, 2, reason: '$r');
    expect(host.questions, hasLength(1));
    expect(host.questions.single, contains('2 games'));
    final saved = SportsChannelPicks.load(storage);
    expect(saved.channelIdFor(celtics), named('NBA 01: Celtics vs. Knicks').id);
    expect(saved.channelIdFor(lakers), named('NBA 02: Lakers vs. Suns').id);
  });

  test('a game fetched again keeps its ref', () {
    final first = _game('1', 'Knicks', 'Celtics');
    final again = _game('1', 'Knicks', 'Celtics');
    final ref = box.refFor(first);
    expect(box.refFor(again), ref);
    expect(box.lookup(ref), same(again));
  });

  test('game_channel: no on the TV saves nothing', () async {
    host.answer = false;
    final g = _game('1', 'Knicks', 'Celtics');
    final r = await box.call(
        'game_channel',
        {
          'picks': [
            {'game': box.refFor(g), 'channel': box.refFor(named('NBA 03'))}
          ]
        },
        caller: VesperCaller.remoteApp);
    expect(r['error'], contains('said no'));
    expect(SportsChannelPicks.load(storage).channelIdFor(g), isNull);
  });

  test('game_channel refuses unknown refs and hidden channels', () async {
    final g = _game('1', 'Knicks', 'Celtics');
    final hidden = named('NBA 03');
    final hiddenRef = box.refFor(hidden);
    await manager.toggleChannelHidden(hidden);
    final r = await box.call('game_channel', {
      'picks': [
        {'game': 'g999', 'channel': box.refFor(named('NBA TV'))},
        {'game': box.refFor(g), 'channel': 'l999'},
        {'game': box.refFor(g), 'channel': hiddenRef},
      ]
    });
    expect(r['error'], 'Nothing saved.');
    final errors = [for (final p in r['problems'] as List) (p as Map)['error']];
    expect(errors[0], contains('Unknown game ref'));
    expect(errors[1], contains('Unknown live channel ref'));
    expect(errors[2], contains('hidden'));
    expect(SportsChannelPicks.load(storage).channelIdFor(g), isNull);
  });

  test('the sports manual names every tool it teaches', () {
    final manual = vesperHelpTopics['sports']!;
    for (final t in ['sports_today', 'play_game', 'game_channel', 'groups']) {
      expect(vesperTools.any((x) => x.name == t), isTrue, reason: t);
      expect(manual, contains(t));
    }
  });
}
