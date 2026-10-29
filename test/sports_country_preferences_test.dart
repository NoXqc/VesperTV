import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/profile_copy.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_countries.dart';
import 'package:nox_iptv/services/sports_channel_library.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'handoff_sports_regression_test.dart' show channel, game;

class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  int calls = 0;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
      DateTime from, DateTime to, List<String> terms) async {
    calls++;
    return programmes;
  }

  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

EpgProgram programme(Channel channel, SportsGame game, [String? title]) =>
    EpgProgram(
        channelId: channel.rawId,
        title: title ?? '${game.home.name} vs ${game.away.name}',
        start: game.start,
        stop: game.start.add(const Duration(hours: 3)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test(
      'Canadian brands, explicit tags and ambiguous European brands are conservative',
      () {
    for (final name in [
      'TSN 1',
      'TSN+ 04',
      'Sportsnet ONE',
      'RDS 2',
      'TVA Sports 2'
    ]) {
      expect(SportsChannelCountries.infer(channel(name, name)), 'CA');
    }
    for (final name in [
      'SportsNet LA',
      'SportsNet Pittsburgh',
      'Spectrum SportsNet'
    ]) {
      expect(SportsChannelCountries.infer(channel(name, name)), 'US');
    }
    for (final name in [
      'Sky Sports Football',
      'DAZN 1',
      'beIN Sports',
      'Eurosport 1',
      'ITV 4'
    ]) {
      expect(SportsChannelCountries.infer(channel(name, name)), null);
    }
    expect(SportsChannelCountries.infer(channel('a', 'CAFR | RDS')), 'CA');
    expect(SportsChannelCountries.infer(channel('b', '[GB] Sky Sports')), 'UK');
    expect(
        SportsChannelCountries.infer(channel('c', 'FR - beIN Sports')), 'FR');
    expect(SportsChannelCountries.infer(channel('d', 'RO - RDS')), 'RO');
    final grouped = Channel(
        id: 'p::grouped',
        rawId: 'grouped',
        playlistId: 'p',
        name: 'beIN Sports 1',
        group: 'France | Sports',
        url: '');
    expect(SportsChannelCountries.infer(grouped), 'FR');
    expect(
        SportsChannelCountries.infer(channel('flag', '🇫🇷 FR | beIN Sports')),
        'FR');
    expect(
        SportsChannelCountries.infer(Channel(
            id: 'p::romanian',
            rawId: 'romanian',
            playlistId: 'p',
            name: 'RDS',
            group: 'Romania | Sports',
            url: '')),
        'RO');
  });

  test(
      'country preferences reorder existing EPG matches without changing scores or queries',
      () async {
    final g = game('one', DateTime.now().toUtc());
    final live = [
      channel('us', 'US - ESPN 4K'),
      channel('tsn', 'TSN 1 FHD'),
      channel('sn', 'Sportsnet ONE HD'),
      channel('rds', 'RDS 2 HD'),
      channel('tva', 'TVA Sports HD'),
      channel('unknown', 'Mystery Sports HD')
    ];
    final guide = _Guide(storage, [for (final c in live) programme(c, g)]);
    final matcher = SportsChannelMatcher(guide);
    await matcher.prepare(live);
    final picks = SportsChannelPicks.load(storage);
    final key = SportsChannelPicks.eventKey(g);
    final before = (await matcher.matchDay([g], picks, limit: 100))[key]!;
    expect(before.first.channel.id, 'p::us');
    final calls = guide.calls;
    await storage.setSportsPreferredCountries(['CA']);
    final after = (await matcher.matchDay([g], picks, limit: 100))[key]!;
    expect(after.take(4).map((m) => m.channel.id).toSet(),
        {'p::tsn', 'p::sn', 'p::rds', 'p::tva'});
    expect(after.map((m) => m.channel.id).toSet(),
        before.map((m) => m.channel.id).toSet());
    expect({for (final m in after) m.channel.id: (m.reason, m.score, m.detail)},
        {for (final m in before) m.channel.id: (m.reason, m.score, m.detail)});
    expect(guide.calls, calls); // same guide cache; preference needs no query
    await storage.setSportsPreferredCountries([]);
    expect(
        (await matcher.matchDay([g], picks, limit: 100))[key]!
            .map((m) => m.channel.id),
        before.map((m) => m.channel.id));
    guide.dispose();
  });

  test(
      'French football guide matches can precede UK 4K without adding a wrong-game French feed',
      () async {
    final g = SportsGame(
        id: 'football',
        league: sportsLeagueById('eng.1')!,
        start: DateTime.now().toUtc(),
        state: GameState.pre,
        statusText: '',
        home: const SportsTeam(
            id: 'ars',
            name: 'Arsenal',
            shortName: 'Arsenal',
            abbreviation: 'ARS'),
        away: const SportsTeam(
            id: 'che',
            name: 'Chelsea',
            shortName: 'Chelsea',
            abbreviation: 'CHE'));
    final uk = channel('uk', 'UK - Sky Sports 4K'),
        fr = channel('fr', 'FR - Canal+ Sport HD'),
        wrong = channel('wrong', 'FR - beIN Sports 2 HD');
    final guide = _Guide(storage, [
      programme(uk, g),
      programme(fr, g),
      programme(wrong, g, 'Liverpool vs Everton')
    ]);
    final matcher = SportsChannelMatcher(guide);
    await matcher.prepare([uk, fr, wrong]);
    await storage.setSportsPreferredCountries(['FR']);
    final result =
        (await matcher.matchDay([g], SportsChannelPicks.load(storage)))
            .values
            .single;
    expect(result.first.channel.id, fr.id);
    expect(result.map((m) => m.channel.id), isNot(contains(wrong.id)));
    expect(result.map((m) => m.channel.id), contains(uk.id));
    guide.dispose();
  });

  test(
      'a Canadian broadcaster suggestion cannot precede an EPG-confirmed US game',
      () async {
    final base = game('one', DateTime.now().toUtc());
    final g = SportsGame(
        id: base.id,
        league: base.league,
        start: base.start,
        state: base.state,
        statusText: '',
        home: base.home,
        away: base.away,
        broadcasts: ['TSN']);
    final us = channel('us', 'US - ESPN HD'), ca = channel('ca', 'TSN');
    final guide = _Guide(storage, [programme(us, g)]);
    final matcher = SportsChannelMatcher(guide);
    await matcher.prepare([us, ca]);
    await storage.setSportsPreferredCountries(['CA']);
    final result =
        (await matcher.matchDay([g], SportsChannelPicks.load(storage)))
            .values
            .single;
    expect(result.first.channel.id, us.id);
    expect(result.last.reason, MatchReason.network);
    expect(result.last.channel.id, ca.id);
    guide.dispose();
  });

  test(
      'explicit game/team picks win; quality sorts within country; absent preferences preserve fallback order',
      () async {
    await storage.setSportsPreferredCountries(['CA']);
    final picks = SportsChannelPicks.load(storage);
    final live = [
      channel('us', 'US - ESPN 4K'),
      channel('hd', 'TSN 1 HD'),
      channel('4k', 'TSN 2 4K')
    ];
    final confirmed = [
      for (final c in live)
        ChannelMatch(c, MatchReason.guide, 80, gameEvidence: true)
    ];
    expect(picks.orderMatches(confirmed).map((m) => m.channel.id),
        ['p::4k', 'p::hd', 'p::us']);
    expect(
        picks
            .orderMatches([
              ChannelMatch(live.first, MatchReason.pick, 1000),
              ...confirmed.skip(1)
            ])
            .first
            .channel
            .id,
        'p::us');
    await storage.setSportsPreferredCountries(['FR']);
    expect(picks.orderMatches(confirmed), preferSportsSources(confirmed));
    await storage.setSportsPreferredCountries([]);
    await storage.setSportsPreferQuality(false);
    expect(identical(picks.orderMatches(confirmed), confirmed), true);
  });

  test(
      'manual country corrections win over inferred brands and keep unknown explicit',
      () async {
    final tsn = channel('tsn', 'TSN 1');
    final unknown = channel('unknown', 'CA - Event TV');
    await storage.setSportsPreferredCountries(['FR']);
    final store = SportsChannelLists(storage);
    store.tags[tsn.id] = {
      'Country': ['fr']
    };
    store.tags[unknown.id] = {
      'Country': ['Unknown']
    };
    await store.save();
    expect(SportsCountryPreferences.load(storage).prefers(tsn), true);
    await storage.setSportsPreferredCountries(['CA']);
    expect(SportsCountryPreferences.load(storage).prefers(tsn), false);
    expect(SportsCountryPreferences.load(storage).prefers(unknown), false);
    await storage.setSportsChannelLists('{bad data');
    expect(SportsCountryPreferences.load(storage).prefers(tsn), true);
  });

  test(
      'preferences are viewer-scoped, copyable with Sports and travel in backup/transfer',
      () async {
    await storage.setSportsPreferredCountries(['CA', 'FR']);
    final payload = storage.exportForTransfer();
    expect(payload.keys.any((k) => k.contains('sports_preferred_countries')),
        true);
    expect(
        storage
            .exportForBackup()
            .keys
            .any((k) => k.contains('sports_preferred_countries')),
        true);
    await storage.copyMainToViewer('new', {ProfileCopy.sports},
        restricted: false);
    await storage.setActiveViewerId('other');
    expect(storage.getSportsPreferredCountries(), isEmpty);
    await storage.setSportsPreferredCountries(['GR']);
    await storage.setActiveViewerId('new');
    expect(storage.getSportsPreferredCountries(), ['CA', 'FR']);
    await storage.setActiveViewerId('main');
    expect(storage.getSportsPreferredCountries(), ['CA', 'FR']);
    await storage.setSportsPreferredCountries([]);
    await storage.importForTransfer(payload);
    expect(storage.getSportsPreferredCountries(), ['CA', 'FR']);
  });
}
