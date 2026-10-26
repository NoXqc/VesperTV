import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/sports_db_source.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SportsGame parse(String league, String title,
        {String status = '', Map<String, Object?> extra = const {}}) =>
    parseSportsDbEvents((
      jsonEncode({
        'events': [
          {
            'idEvent': '2599791',
            'strTimestamp': '2026-10-27T00:00:00',
            'strEvent': title,
            'strHomeTeam': null,
            'strAwayTeam': null,
            'strStatus': status,
            'strVenue': 'Arena',
            'strCity': 'City',
            ...extra,
          }
        ]
      }),
      sportsLeagueById(league)!
    )).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Boxing/WWE/AEW use verified SportsDB leagues and UFC event behavior',
      () {
    for (final (id, db) in [
      ('boxing', '4445'),
      ('wrestling.wwe', '4444'),
      ('wrestling.aew', '4563')
    ]) {
      final league = sportsLeagueById(id)!;
      expect(league.sportsDbId, db);
      expect(league.kind, SportsKind.fight);
      expect(league.hasStandings, false);
      expect(league.region, 'Fighting');
    }
  });

  test('named boxing fight uses UFC-style two fighters, no fabricated scores',
      () {
    final g = parse('boxing', 'Canelo Álvarez vs Christian Mbilli');
    expect(g.isEventOnly, false);
    expect(g.first.name, 'Canelo Álvarez');
    expect(g.second.name, 'Christian Mbilli');
    expect(g.title, 'Canelo Álvarez vs Christian Mbilli');
    expect(g.event!.title, g.title);
    expect(g.event!.venue, 'Arena, City');
    expect(g.state, GameState.pre);
    expect(g.first.score, null);
    expect(g.second.score, null);
    final finished =
        parse('boxing', 'First Fighter vs. Second Fighter', status: 'FT');
    expect(finished.state, GameState.post);
    expect(finished.first.score, null);
    expect(finished.second.score, null);
  });

  test('WWE/AEW retain show titles, UTC time and event-only layout', () {
    for (final (id, title) in [
      ('wrestling.wwe', 'RAW #1744'),
      ('wrestling.aew', 'Dynamite #369 Fright Night Dynamite'),
    ]) {
      final g = parse(id, title);
      expect(g.title, title);
      expect(g.isEventOnly, true);
      expect(g.start, DateTime.utc(2026, 10, 27));
      expect(g.first.name, isEmpty);
      expect(g.second.name, isEmpty);
      expect(g.first.logoUrl, g.league.logoUrl);
      expect(g.state, GameState.pre);
    }
    expect(parse('boxing', 'Zuffa Boxing 11 Fisher vs Pirotton').isEventOnly,
        true);
  });

  test(
      'empty titles and missing times are omitted instead of inventing a midnight event',
      () {
    final league = sportsLeagueById('wrestling.wwe')!;
    final games = parseSportsDbEvents((
      jsonEncode({
        'events': [
          {
            'idEvent': '1',
            'strTimestamp': '2026-10-27T00:00:00',
            'strEvent': ''
          },
          {
            'idEvent': '2',
            'dateEvent': '2026-10-27',
            'strEvent': 'Unknown time'
          },
        ]
      }),
      league
    ));
    expect(games, isEmpty);
    expect(parse('wrestling.wwe', 'Canceled Show', status: 'CANC').state,
        GameState.post);
  });

  test(
      'wrestling event aliases match ordinary channel titles without episode numbers',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final epg = EpgService(storage);
    final matcher = SportsChannelMatcher(epg);
    final picks = SportsChannelPicks.load(storage);
    Channel ch(String id, String title) => Channel(
        id: 'p::$id',
        rawId: id,
        playlistId: 'p',
        name: title,
        group: 'Sports',
        url: 'https://example.com/$id');
    await matcher.prepare([
      ch('raw', 'WWE Raw 4K'),
      ch('aew', 'AEW Dynamite HD'),
      ch('wrong', 'NFL Football'),
    ]);
    final raw = parse('wrestling.wwe', 'RAW #1744');
    final aew = parse('wrestling.aew', 'Dynamite #369 Fright Night Dynamite');
    final out = await matcher.matchDay([raw, aew], picks);
    expect(out[SportsChannelPicks.eventKey(raw)]!.first.channel.rawId, 'raw');
    expect(out[SportsChannelPicks.eventKey(aew)]!.first.channel.rawId, 'aew');
    expect(out.values.expand((m) => m).any((m) => m.channel.rawId == 'wrong'),
        false);
    epg.dispose();
  });
}
