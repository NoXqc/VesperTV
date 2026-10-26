// Appended to an exact generated copy of sports_channel_matcher.dart.
class AuditEpg extends EpgService {
  AuditEpg(super.storage, this.db, this.mode);
  final Database db;
  final String mode;
  int queries = 0;
  int sqlMs = 0;

  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
      DateTime from, DateTime to, List<String> terms) async {
    queries++;
    final watch = Stopwatch()..start();
    final rows = <Map<String, Object?>>[];
    for (var i = 0; i < terms.length; i += 400) {
      final part = terms.sublist(i, math.min(i + 400, terms.length));
      if (mode == 'normalized') {
        final all = await db.rawQuery(
            'SELECT * FROM programme WHERE stop > ? AND start >= ? AND start < ?',
            [
              from.millisecondsSinceEpoch,
              from.millisecondsSinceEpoch,
              to.millisecondsSinceEpoch
            ]);
        rows.addAll(all.where((r) => part.any((t) =>
            sportsNormalize(r['title'] as String)
                .contains(sportsNormalize(t).trim()))));
      } else {
        final expression =
            mode == 'description' || mode == 'guarded-description'
                ? "(title || ' ' || COALESCE(descr,''))"
                : 'title';
        final likes =
            List.filled(part.length, '$expression LIKE ?').join(' OR ');
        if (part.isNotEmpty)
          rows.addAll(await db.rawQuery(
              'SELECT * FROM programme WHERE stop > ? AND start >= ? AND start < ? AND ($likes)',
              [
                from.millisecondsSinceEpoch,
                from.millisecondsSinceEpoch,
                to.millisecondsSinceEpoch,
                for (final t in part) '%$t%'
              ]));
      }
    }
    sqlMs += watch.elapsedMilliseconds;
    return [
      for (final r in rows)
        if (mode != 'app-window' ||
            ((r['stop'] as int) >
                    lastUpdated!
                        .subtract(const Duration(hours: 2))
                        .millisecondsSinceEpoch &&
                (r['start'] as int) <
                    lastUpdated!
                        .add(const Duration(hours: 36))
                        .millisecondsSinceEpoch))
          if (mode != 'guarded-description' ||
              titleAlreadyNamesGame(r) ||
              safeDescriptionListing(r))
            EpgProgram(
              channelId: r['channel_id'] as String,
              title: mode == 'description' ||
                      (mode == 'guarded-description' &&
                          !titleAlreadyNamesGame(r))
                  ? '${r['title']} ${r['descr'] ?? ''}'
                  : r['title'] as String,
              description: r['descr'] as String?,
              start: DateTime.fromMillisecondsSinceEpoch(r['start'] as int,
                  isUtc: true),
              stop: DateTime.fromMillisecondsSinceEpoch(r['stop'] as int,
                  isUtc: true),
            )
    ];
  }
}

final _nonFullGame = RegExp(
    r'\b(multiplex|final score|commentary|updates|redzone|konferenz|golazo|goal rush|highlights|replay|classic|preview|pregame|postgame|news|magazine|review)\b',
    caseSensitive: false);
List<SportsGame> auditGames = [];
bool titleAlreadyNamesGame(Map<String, Object?> row) =>
    auditGames.any((g) => namesAll(g, row['title'] as String));
bool safeDescriptionListing(Map<String, Object?> row) {
  final text = '${row['title']} ${row['descr'] ?? ''}';
  if (_nonFullGame.hasMatch(text)) return false;
  final candidates = auditGames
      .where((g) =>
          (g.start.millisecondsSinceEpoch - (row['start'] as int)).abs() <=
              3600000 &&
          namesAll(g, text))
      .toList();
  // A listing describing several simultaneous fixtures is a multiplex, not
  // proof of any full game. Also require explicit, compatible sport metadata.
  if (candidates.length != 1) return false;
  final g = candidates.single;
  if (conflict(g, text) != null) return false;
  final norm = sportsNormalize(text);
  return (g.league.soccer
          ? [' soccer ', ' football ', ' champions league ', ' premier league ']
          : switch (g.league.id) {
              'nfl' => [' nfl ', ' american football '],
              'cfl' => [' cfl ', ' canadian football '],
              'nba' => [' nba ', ' basketball ', ' baloncesto '],
              'nhl' => [' nhl ', ' hockey '],
              'mlb' => [' mlb ', ' baseball ', ' beisbol '],
              _ => <String>[],
            })
      .any(norm.contains);
}

final _auditNormal = <String, String>{};
String auditNormalize(String text) =>
    _auditNormal.putIfAbsent(text, () => sportsNormalize(text));
final _auditGroups = <SportsGame, List<List<String>>>{};
bool namesAll(SportsGame g, String text) => _auditGroups
    .putIfAbsent(g, () => SportsChannelMatcher._nameGroups(g))
    .every((group) => group.any(auditNormalize(text).contains));

String? conflict(SportsGame g, String text) {
  final title = sportsNormalize(text);
  final markers = <String, String>{
    'nba': ' basketball ',
    'nhl': ' hockey ',
    'mlb': ' baseball ',
    'nfl': ' nfl ',
    'cfl': ' cfl ',
    'soccer': ' soccer '
  };
  final own = g.league.soccer ? 'soccer' : g.league.id;
  for (final e in markers.entries) {
    if (e.key != own && title.contains(e.value)) return e.key;
  }
  return null;
}

Map<String, Object?> matchJson(ChannelMatch m) => {
      'channel': m.channel.name,
      'channelId': m.channel.id,
      'reason': m.reason.name,
      'score': m.score,
      'detail': m.detail,
    };

const auditNetworkAliases = <String, List<String>>{
  'CBSSN': ['cbs sports network'],
  'NFL NET': ['nfl network'],
  'NHL NET': ['nhl network'],
  'NBC SPORTS PHIL': ['nbc sports philadelphia'],
  // USA Net is the US service, not USA Network Canada.
  'USA NET': ['usa network'],
};
List<ChannelMatch> withNetworkAliases(SportsChannelMatcher matcher,
    SportsGame g, List<ChannelMatch> baseline, int limit) {
  final found = {for (final m in baseline) m.channel.id: m};
  for (final network in g.broadcasts) {
    final alias = auditNetworkAliases[network.toUpperCase().trim()];
    if (alias == null ||
        (matcher._byCanonical[canonicalChannelKey(network)]?.isNotEmpty ??
            false)) continue;
    final hits = matcher._channelsNaming(alias).toList()
      ..sort((a, b) =>
          matcher._names[a].length.compareTo(matcher._names[b].length));
    var taken = 0;
    for (final i in hits) {
      if (taken >= 3) break;
      final bias = matcher._regionBias(i, g.league);
      if (bias < 0) continue;
      // A regional Plus/alternate service is a different broadcast.
      if (matcher._names[i].contains(' plus ') ||
          matcher._names[i].contains(' alternate ')) continue;
      // These schedule labels refer to US networks. Do not infer another
      // territory or a dated event channel from the network phrase alone.
      if (!matcher._names[i].contains(' us ')) continue;
      final displayName = matcher._channels[i].name
          .replaceAll(RegExp(r'\s*\(D\)\s*', caseSensitive: false), ' ');
      final identity = canonicalChannelKey(displayName);
      final identities = {
        for (final phrase in alias) canonicalChannelKey(phrase),
        if (network.toUpperCase() == 'USA NET')
          canonicalChannelKey('USA Network East'),
      };
      if (!identities.contains(identity)) continue;
      final c = matcher._channels[i];
      final score = 50 + bias;
      if ((found[c.id]?.score ?? -1) < score)
        found[c.id] =
            ChannelMatch(c, MatchReason.network, score, detail: network);
      taken++;
    }
  }
  final list = found.values.toList()
    ..sort((a, b) {
      final rank = b.score.compareTo(a.score);
      return rank != 0
          ? rank
          : a.channel.name.length.compareTo(b.channel.name.length);
    });
  return list.take(limit).toList();
}

Future<Map<String, Object?>> diagnose(SportsChannelMatcher matcher, Database db,
    SportsGame g, List<ChannelMatch> matches, List<ChannelMatch> all) async {
  final (from, to) = SportsChannelMatcher._guideWindow(g);
  final rows = await db.rawQuery(
      'SELECT * FROM programme WHERE start >= ? AND start < ?',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch]);
  final both = rows.where((p) => namesAll(g, p['title'] as String)).toList();
  final described = rows
      .where((p) => namesAll(g, '${p['title']} ${p['descr'] ?? ''}'))
      .toList();
  final groups = SportsChannelMatcher._nameGroups(g);
  final one = rows
      .where((p) => groups.any(
          (group) => group.any(auditNormalize(p['title'] as String).contains)))
      .length;
  final network = <Map<String, Object?>>[];
  for (final n in g.broadcasts) {
    final upper = n.toUpperCase().trim();
    final call = _callSign.firstMatch(upper)?.group(1);
    final aliases = _networkAliases[upper] ??
        (call == null ? <String>[] : [call.toLowerCase()]);
    network.add({
      'broadcast': n,
      'streamingOnly': _streamingOnly.contains(upper),
      'canonicalChannels':
          matcher._byCanonical[canonicalChannelKey(n)]?.length ?? 0,
      'aliases': aliases,
      'aliasChannels': matcher._channelsNaming(aliases).length
    });
  }
  String cause;
  if (matches.isNotEmpty) {
    cause = matches.any((m) => m.reason == MatchReason.guide)
        ? 'guide_match'
        : matches.any((m) => m.reason == MatchReason.name && m.detail == null)
            ? 'event_name_match'
            : 'fallback_only_unverified';
  } else if (both.isNotEmpty) {
    cause = 'title_candidate_rejected_or_sql_prefilter';
  } else if (described.isNotEmpty) {
    cause = 'teams_in_description_only';
  } else if (rows.isEmpty) {
    cause = 'outside_epg_coverage';
  } else if (one > 0) {
    cause = 'only_one_team_in_title_or_alias_gap';
  } else {
    cause = 'no_identifiable_listing';
  }
  final rawNames = groups.map(matcher._channelsNaming).toList();
  var dateRejected = 0;
  if (rawNames.isNotEmpty) {
    final common = rawNames.reduce((a, b) => a.intersection(b));
    for (final i in common) {
      final d = SportsChannelMatcher._dateInName(matcher._names[i]);
      if (d != null && !SportsChannelMatcher._dateFits(d, g.start))
        dateRejected++;
    }
  }
  return {
    'gameKey': SportsChannelPicks.eventKey(g),
    'league': g.league.id,
    'game': '${g.away.name} at ${g.home.name}',
    'startUtc': g.start.toUtc().toIso8601String(),
    'cause': cause,
    'matches': matches.map(matchJson).toList(),
    'preLimitCandidates': all.length,
    'truncated': math.max(0, all.length - matches.length),
    'omittedGuideChannels': all
        .where((m) =>
            m.reason == MatchReason.guide &&
            !matches.any((shown) => shown.channel.id == m.channel.id))
        .length,
    'windowRows': rows.length,
    'bothTeamsTitle': both.length,
    'bothTeamsDescription': described.length,
    'oneTeamTitle': one,
    'dateRejected': dateRejected,
    'networks': network,
    'titleEvidence': both
        .take(4)
        .map((p) => {'title': p['title'], 'channelId': p['channel_id']})
        .toList(),
    'descriptionEvidence': described
        .take(4)
        .map((p) => {
              'title': p['title'],
              'description': p['descr'],
              'channelId': p['channel_id']
            })
        .toList(),
    'suspectMatches': [
      for (final m in matches)
        if (m.detail != null && conflict(g, m.detail!) != null)
          {
            'channel': m.channel.name,
            'detail': m.detail,
            'conflict': conflict(g, m.detail!)
          }
    ],
  };
}

void main() {
  test('real snapshots: production baseline and isolated experiments',
      () async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final root = Directory('.dart_tool/matcher-audit');
    final scheduleDir = Directory('${root.path}/schedule')
      ..createSync(recursive: true);
    final errors = <String>[];
    final real = http.Client();
    final service = SportsService.forTesting(MockClient((request) async {
      final file = File(
          '${scheduleDir.path}/${base64Url.encode(utf8.encode(request.url.toString()))}.json');
      if (file.existsSync())
        return http.Response.bytes(file.readAsBytesSync(), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      try {
        final response =
            await real.get(request.url).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200)
          file.writeAsStringSync(response.body);
        else
          errors.add('${request.url.host} HTTP ${response.statusCode}');
        return response;
      } catch (_) {
        errors.add('${request.url.host} unavailable');
        return http.Response('{}', 503);
      }
    }));
    final leagues = [
      for (final id in [
        'nfl',
        'nba',
        'nhl',
        'mlb',
        'eng.1',
        'uefa.champions',
        'cfl'
      ])
        sportsLeagueById(id)!
    ];
    final byDay = <DateTime, List<SportsGame>>{};
    for (var day = 19; day <= 25; day++) {
      byDay[DateTime(2026, 10, day)] =
          await service.gamesForDay(leagues, DateTime(2026, 10, day));
    }
    real.close();
    auditGames = byDay.values.expand((games) => games).toList();
    File('${root.path}/schedule-errors.json')
        .writeAsStringSync(jsonEncode(errors));
    final output = File('${root.path}/results.ndjson').openWrite();
    final timings = <Map<String, Object?>>[];
    for (final directory in root.listSync().whereType<Directory>()) {
      final file = File('${directory.path}/channels.json');
      final guide = File('${directory.path}/guide.sqlite');
      final status = File('${directory.path}/status.json');
      if (!file.existsSync() || !guide.existsSync() || !status.existsSync())
        continue;
      final state = jsonDecode(status.readAsStringSync()) as Map;
      if (state['result'] != 'ok') continue;
      final raw = jsonDecode(file.readAsStringSync()) as List;
      final channels = [
        for (final c in raw)
          Channel(
              id: c['id'],
              rawId: c['rawId'],
              playlistId: c['playlistId'],
              name: c['name'],
              group: c['group'],
              url: '',
              epgKey: c['epgId'])
      ];
      final db = await databaseFactoryFfi.openDatabase(guide.absolute.path,
          options: OpenDatabaseOptions(readOnly: true));
      final baselineRows = <String, Map<String, Object?>>{};
      for (final mode in [
        'baseline',
        'normalized',
        'description',
        'guarded-description',
        'network-aliases',
        'app-window'
      ]) {
        final epg = AuditEpg(storage, db, mode)
          ..lastUpdated = DateTime.parse(state['capturedUtc']);
        final matcher = SportsChannelMatcher(epg);
        final prepareWatch = Stopwatch()..start();
        await matcher.prepare(channels);
        final prepareMs = prepareWatch.elapsedMilliseconds;
        final watch = Stopwatch()..start();
        for (final entry in byDay.entries) {
          final picks = SportsChannelPicks.load(storage);
          final matches = await matcher.matchDay(entry.value, picks);
          final all = await matcher.matchDay(entry.value, picks, limit: 100000);
          for (final g in entry.value) {
            final key = SportsChannelPicks.eventKey(g);
            if (mode == 'network-aliases') {
              final supplemented =
                  withNetworkAliases(matcher, g, all[key] ?? [], 100000);
              all[key] = supplemented;
              matches[key] = supplemented.take(8).toList();
            }
            final row = mode == 'baseline'
                ? await diagnose(
                    matcher, db, g, matches[key] ?? [], all[key] ?? [])
                : <String, Object?>{
                    ...baselineRows[key]!,
                    'matches': (matches[key] ?? []).map(matchJson).toList(),
                    'preLimitCandidates': all[key]?.length ?? 0,
                    'suspectMatches': [
                      for (final m in matches[key] ?? <ChannelMatch>[])
                        if (m.detail != null && conflict(g, m.detail!) != null)
                          matchJson(m)
                    ]
                  };
            if (mode == 'baseline') baselineRows[key] = row;
            output.writeln(
                jsonEncode({'source': state['label'], 'mode': mode, ...row}));
          }
        }
        timings.add({
          'source': state['label'],
          'mode': mode,
          'prepareMs': prepareMs,
          'totalMs': watch.elapsedMilliseconds,
          'sqlMs': epg.sqlMs,
          'queries': epg.queries,
          'games': byDay.values.fold<int>(0, (n, g) => n + g.length)
        });
        expect(
            epg.queries, byDay.values.where((games) => games.isNotEmpty).length,
            reason: 'Warm unlimited reruns must reuse the same guide scan');
        epg.dispose();
        print(
            '${state['label']} $mode done: ${watch.elapsedMilliseconds} ms, ${epg.queries} guide scans');
      }
      _auditNormal.clear();
      await db.close();
    }
    await output.close();
    File('${root.path}/timings.json').writeAsStringSync(jsonEncode(timings));
    print(jsonEncode(timings));
  }, timeout: const Timeout(Duration(minutes: 20)));

  test(
      'negative controls: descriptions, wrong sport, replays, SQL accents and stale index',
      () async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE programme(channel_id TEXT,start INTEGER,stop INTEGER,title TEXT,descr TEXT)');
    final start = DateTime.utc(2026, 10, 22, 20);
    final game = SportsGame(
        id: 'audit-control',
        league: sportsLeagueById('nfl')!,
        start: start,
        state: GameState.pre,
        statusText: 'Scheduled',
        home: const SportsTeam(
            id: '1',
            name: 'Miami Dolphins',
            shortName: 'Dolphins',
            abbreviation: 'MIA'),
        away: const SportsTeam(
            id: '2',
            name: 'Buffalo Bills',
            shortName: 'Bills',
            abbreviation: 'BUF'));
    auditGames = [game];
    Channel channel(String id, String name) => Channel(
        id: id,
        rawId: id,
        playlistId: 'control',
        name: name,
        group: 'Sports',
        url: '');
    final channels = [
      channel('a', 'Control A'),
      channel('b', 'Control B'),
      channel('c', 'Control C')
    ];
    Future<int> count(String mode) async {
      final epg = AuditEpg(storage, db, mode);
      final matcher = SportsChannelMatcher(epg);
      await matcher.prepare(channels);
      final result =
          await matcher.matchDay([game], SportsChannelPicks.load(storage));
      return result[SportsChannelPicks.eventKey(game)]!.length;
    }

    await db.insert('programme', {
      'channel_id': 'a',
      'start': start.millisecondsSinceEpoch,
      'stop': start.add(const Duration(hours: 3)).millisecondsSinceEpoch,
      'title': 'NFL Football',
      'descr': 'Buffalo Bills at Miami Dolphins'
    });
    expect(await count('baseline'), 0);
    expect(await count('description'), 1);
    expect(await count('guarded-description'), 1);
    await db.update('programme', {'title': 'NFL Highlights'});
    expect(await count('description'),
        1); // Naive proposal creates a wrong full-game match.
    expect(await count('guarded-description'), 0);
    await db.update('programme', {'title': 'NHL Hockey'});
    expect(await count('description'), 1);
    expect(await count('guarded-description'), 0);
    await db.update('programme', {
      'title': 'NFL Multiplex',
      'descr': 'Buffalo Bills at Miami Dolphins and other games'
    });
    expect(await count('guarded-description'), 0);

    final epg = AuditEpg(storage, db, 'baseline');
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare(channels);
    await matcher
        .prepare([channels.first, channel('b', 'Renamed B'), channels.last]);
    expect(matcher.channels[1].name,
        'Control B'); // Existing signature misses middle renames.
    final fetched = await epg.findProgrammesByTitle(
        start, start.add(const Duration(hours: 1)), ['fenerbahce']);
    expect(fetched, isEmpty);
    await db.update('programme', {'title': 'Fenerbahçe / Slavia Prague'});
    expect(
        await epg.findProgrammesByTitle(
            start, start.add(const Duration(hours: 1)), ['fenerbahce']),
        isEmpty);
    final normalized = AuditEpg(storage, db, 'normalized');
    expect(
        await normalized.findProgrammesByTitle(
            start, start.add(const Duration(hours: 1)), ['fenerbahce']),
        hasLength(1));
    final aliasMatcher = SportsChannelMatcher(epg);
    await aliasMatcher.prepare([
      channel('us', 'US - CBS SPORTS NETWORK HD'),
      channel('ru', 'RU - CBS SPORTS NETWORK HD'),
      channel('ca', 'CA - USA NETWORK CANADA HD'),
      channel('usa', 'US - USA NETWORK EAST HD'),
      channel('west', 'US - USA NETWORK WEST HD'),
      channel('nfl', 'US - NFL NETWORK HD'),
      channel('dated', 'US - NFL Network: Bills vs Raiders 2026-10-23'),
      channel('phil', 'US - NBC SPORTS PHILADELPHIA HD'),
      channel('plus', 'US - NBC SPORTS PHILADELPHIA PLUS HD'),
    ]);
    final broadcastGame = SportsGame(
        id: game.id,
        league: game.league,
        start: game.start,
        state: game.state,
        statusText: game.statusText,
        home: game.home,
        away: game.away,
        broadcasts: ['CBSSN', 'USA Net', 'NBC Sports Phil', 'NFL Net']);
    expect(
        withNetworkAliases(aliasMatcher, broadcastGame, [], 8)
            .map((m) => m.channel.id)
            .toSet(),
        {
          'us',
          'usa',
          'nfl',
          'phil'
        }); // No foreign/West/Plus service or stale event named after a network.
    await db.close();
  });
}
