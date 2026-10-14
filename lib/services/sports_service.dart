import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sports.dart';

/// Scores and schedules from ESPN's public site API — key-less, so the
/// Sports tab works for everyone without signing up anywhere (see
/// dev-notes/sports-tab.md for why ESPN is the default layer). Unofficial
/// and undocumented: if it changes shape, this file is the only adapter to
/// fix.
///
/// One request returns every game of one league for one ESPN date, so the
/// cost is leagues x days, never per game. Results are cached in memory for
/// the whole app session with a freshness window that depends on what the
/// day holds (live games refresh every minute, finished days rarely).
class SportsService {
  SportsService._();
  static final SportsService instance = SportsService._();

  static const _base = 'https://site.api.espn.com/apis/site/v2/sports';

  final http.Client _client = http.Client();
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<List<SportsGame>>> _inFlight = {};

  /// Every game of [leagues] that starts on the local calendar day [day],
  /// plus — when [day] is today — games from the day before that are still
  /// live past midnight. ESPN buckets games by US Eastern date, so the days
  /// either side are fetched too (cached) and filtered locally; otherwise a
  /// European viewer would lose every evening NHL game, which falls on the
  /// next local day.
  ///
  /// Never throws: a league that fails keeps its last cached games (or
  /// none), and [lastError] says so.
  Future<List<SportsGame>> gamesForDay(
      List<SportsLeague> leagues, DateTime day) async {
    final local = DateTime(day.year, day.month, day.day);
    final today = _today();
    final dates = [
      local.subtract(const Duration(days: 1)),
      local,
      local.add(const Duration(days: 1)),
    ];
    final results = await Future.wait([
      for (final league in leagues)
        for (final d in dates) _fetch(league, d),
    ]);
    final seen = <String>{};
    final games = <SportsGame>[];
    for (final list in results) {
      for (final g in list) {
        if (!seen.add('${g.league.id}:${g.id}')) continue;
        final start = g.start.toLocal();
        final sameDay = start.year == local.year &&
            start.month == local.month &&
            start.day == local.day;
        final carriedOver = local == today &&
            g.state == GameState.live &&
            start.isBefore(local);
        if (sameDay || carriedOver) games.add(g);
      }
    }
    games.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.league.id.compareTo(b.league.id);
    });
    return games;
  }

  /// Set when the most recent load had at least one failed request.
  String? lastError;

  static const _standingsBase = 'https://site.api.espn.com/apis/v2/sports';
  final Map<String, (SportsStandings, DateTime)> _standingsCache = {};
  final Map<String, Future<SportsStandings?>> _standingsInFlight = {};

  /// Conference/league tables for [league]. Null when ESPN can't be reached
  /// and nothing is cached. Standings only move when a game ends, so a
  /// 15-minute cache is plenty.
  Future<SportsStandings?> standings(SportsLeague league) {
    final cached = _standingsCache[league.id];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < const Duration(minutes: 15)) {
      return Future.value(cached.$1);
    }
    return _standingsInFlight[league.id] ??=
        _downloadStandings(league).whenComplete(() {
      _standingsInFlight.remove(league.id);
    });
  }

  Future<SportsStandings?> _downloadStandings(SportsLeague league) async {
    final url = Uri.parse('$_standingsBase/${league.espnPath}/standings');
    try {
      final response =
          await _client.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final standings =
          await compute(parseEspnStandings, (response.body, league));
      _standingsCache[league.id] = (standings, DateTime.now());
      return standings;
    } catch (e) {
      debugPrint('SportsService: ${league.id} standings failed: $e');
      return _standingsCache[league.id]?.$1;
    }
  }

  DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _espnDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  Future<List<SportsGame>> _fetch(SportsLeague league, DateTime date) {
    final key = '${league.id}|${_espnDate(date)}';
    final cached = _cache[key];
    if (cached != null && !cached.isStale(date, _today())) {
      return Future.value(cached.games);
    }
    return _inFlight[key] ??= _download(league, date, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<List<SportsGame>> _download(
      SportsLeague league, DateTime date, String key) async {
    final url = Uri.parse(
        '$_base/${league.espnPath}/scoreboard?dates=${_espnDate(date)}');
    try {
      final response =
          await _client.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final body = response.body;
      // A busy NFL Sunday is a few hundred KB of JSON — decoded off the UI
      // isolate so the screen keeps responding on a weak box.
      final games = await compute(parseEspnScoreboard, (body, league));
      _cache[key] = _CacheEntry(games, DateTime.now());
      lastError = null;
      return games;
    } catch (e) {
      debugPrint('SportsService: ${league.id} ${_espnDate(date)} failed: $e');
      lastError = 'Some scores could not be loaded. Check the connection.';
      return _cache[key]?.games ?? const [];
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.games, this.fetchedAt);
  final List<SportsGame> games;
  final DateTime fetchedAt;

  bool isStale(DateTime espnDate, DateTime today) {
    final age = DateTime.now().difference(fetchedAt);
    final live = games.any((g) => g.state == GameState.live);
    final startsSoon = games.any((g) =>
        g.state == GameState.pre &&
        g.start.difference(DateTime.now().toUtc()).inMinutes < 30);
    if (live || startsSoon) return age > const Duration(seconds: 50);
    final d = DateTime(espnDate.year, espnDate.month, espnDate.day);
    if (d.isBefore(today.subtract(const Duration(days: 1)))) {
      return age > const Duration(hours: 6);
    }
    return age > const Duration(minutes: 10);
  }
}

/// Top-level so [compute] can run it on a background isolate.
@visibleForTesting
List<SportsGame> parseEspnScoreboard((String, SportsLeague) args) {
  final (body, league) = args;
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic>) return const [];
  final events = json['events'];
  if (events is! List) return const [];
  final games = <SportsGame>[];
  for (final e in events) {
    try {
      final game = _parseEvent(e as Map<String, dynamic>, league);
      if (game != null) games.add(game);
    } catch (_) {
      // One malformed event shouldn't drop the whole league.
    }
  }
  return games;
}

SportsGame? _parseEvent(Map<String, dynamic> e, SportsLeague league) {
  final competitions = e['competitions'] as List?;
  if (competitions == null || competitions.isEmpty) return null;
  final comp = competitions.first as Map<String, dynamic>;
  final competitors = (comp['competitors'] as List?) ?? const [];
  SportsTeam? home;
  SportsTeam? away;
  for (final c in competitors) {
    final m = c as Map<String, dynamic>;
    final team = _parseTeam(m);
    if (m['homeAway'] == 'home') {
      home = team;
    } else {
      away = team;
    }
  }
  if (home == null || away == null) return null;

  final status = (comp['status'] ?? e['status']) as Map<String, dynamic>?;
  final type = status?['type'] as Map<String, dynamic>?;
  final state = switch (type?['state']) {
    'in' => GameState.live,
    'post' => GameState.post,
    _ => GameState.pre,
  };

  final broadcasts = <String>{};
  for (final b in (comp['broadcasts'] as List?) ?? const []) {
    for (final n in ((b as Map)['names'] as List?) ?? const []) {
      broadcasts.add(n.toString());
    }
  }
  for (final g in (comp['geoBroadcasts'] as List?) ?? const []) {
    final name = ((g as Map)['media'] as Map?)?['shortName']?.toString();
    if (name != null && name.isNotEmpty) broadcasts.add(name);
  }

  return SportsGame(
    id: e['id'].toString(),
    league: league,
    start: DateTime.parse((comp['date'] ?? e['date']).toString()).toUtc(),
    state: state,
    statusText: (type?['shortDetail'] ?? type?['detail'] ?? '').toString(),
    home: home,
    away: away,
    broadcasts: broadcasts.toList(),
  );
}

/// Top-level so [compute] can run it on a background isolate. ESPN nests
/// groups (college conferences hold divisions); every node that carries
/// `standings.entries` becomes one table, in ESPN's order.
@visibleForTesting
SportsStandings parseEspnStandings((String, SportsLeague) args) {
  final (body, league) = args;
  final json = jsonDecode(body);
  final groups = <SportsStandingGroup>[];
  var preseason = false;
  String? season;

  void walk(Map<String, dynamic> node) {
    final standings = node['standings'];
    if (standings is Map && standings['entries'] is List) {
      // Soccer tables always say seasonType 1; only the US leagues use it
      // for exhibition games.
      if (!league.soccer && standings['seasonType'] == 1) preseason = true;
      // The table's own season ("2026" for a finished MLB year — the
      // top-level `season` already says 2027); soccer appends the league
      // name ("2026-27 English Premier League"), keep just the years.
      season ??= RegExp(r'^\d{4}(-\d{2})?')
          .firstMatch(standings['seasonDisplayName']?.toString() ?? '')
          ?.group(0);
      final rows = <SportsStandingRow>[];
      for (final e in standings['entries'] as List) {
        try {
          rows.add(_parseStandingRow(e as Map<String, dynamic>));
        } catch (_) {
          // Skip a malformed team rather than the whole table.
        }
      }
      if (rows.isNotEmpty) {
        groups.add(SportsStandingGroup(
          // "2026-27 English Premier League" → "English Premier League";
          // the season is shown on its own.
          name: (node['name'] ?? league.name)
              .toString()
              .replaceFirst(RegExp(r'^\d{4}(-\d{2})?\s+'), ''),
          rows: _sortStandings(rows, league),
        ));
      }
    }
    for (final c in (node['children'] as List?) ?? const []) {
      if (c is Map<String, dynamic>) walk(c);
    }
  }

  if (json is Map<String, dynamic>) walk(json);
  return SportsStandings(
    league: league,
    groups: groups,
    season: season,
    preseason: preseason,
  );
}

SportsStandingRow _parseStandingRow(Map<String, dynamic> e) {
  final t = (e['team'] as Map).cast<String, dynamic>();
  final logos = t['logos'] as List?;
  final name = (t['displayName'] ?? t['name'] ?? '').toString();
  final stats = <String, String>{};
  for (final s in (e['stats'] as List?) ?? const []) {
    final m = s as Map;
    final key = (m['name'] ?? m['type'])?.toString();
    if (key == null) continue;
    // College football repeats the whole set per split (overall, home,
    // away); the first one is the overall line.
    var value = (m['displayValue'] ?? m['summary'] ?? '').toString();
    // NHL's last-ten reads "6-1-1, 0" (a trailing shootout count).
    if (key == 'Last Ten Games') value = value.split(',').first.trim();
    stats.putIfAbsent(key, () => value);
  }
  final note = e['note'] as Map?;
  return SportsStandingRow(
    team: SportsTeam(
      id: (t['id'] ?? name).toString(),
      name: name,
      shortName: (t['shortDisplayName'] ?? t['name'] ?? name).toString(),
      abbreviation: (t['abbreviation'] ?? '').toString(),
      logoUrl: (logos != null && logos.isNotEmpty)
          ? (logos.first as Map)['href']?.toString()
          : null,
      color: t['color']?.toString(),
    ),
    position: 0,
    stats: stats,
    // replaceAll: ESPN has sent "##B5E7CE" (Europa League).
    noteColor: note?['color']?.toString().replaceAll('#', ''),
    note: note?['description']?.toString(),
  );
}

/// ESPN's entries are not in table order (NBA/MLB come alphabetical-ish).
/// Soccer has a `rank`; the others a `playoffSeed`, which is 0 for everyone
/// before a season starts — then wins/points decide.
List<SportsStandingRow> _sortStandings(
    List<SportsStandingRow> rows, SportsLeague league) {
  double num(SportsStandingRow r, String k) =>
      double.tryParse(r.stat(k).replaceAll('+', '')) ?? 0;
  final key = league.soccer ? 'rank' : 'playoffSeed';
  final ranked = rows.every((r) => num(r, key) > 0);
  final sorted = [...rows];
  sorted.sort((a, b) {
    if (ranked) return num(a, key).compareTo(num(b, key));
    final byPoints = num(b, 'points').compareTo(num(a, 'points'));
    if (league.espnPath.startsWith('hockey') && byPoints != 0) return byPoints;
    final byPct = num(b, 'winPercent').compareTo(num(a, 'winPercent'));
    return byPct != 0 ? byPct : num(b, 'wins').compareTo(num(a, 'wins'));
  });
  return [
    for (var i = 0; i < sorted.length; i++)
      SportsStandingRow(
        team: sorted[i].team,
        position: i + 1,
        stats: sorted[i].stats,
        noteColor: sorted[i].noteColor,
        note: sorted[i].note,
      ),
  ];
}

SportsTeam _parseTeam(Map<String, dynamic> c) {
  final t = (c['team'] as Map?)?.cast<String, dynamic>() ?? const {};
  String? record;
  final records = c['records'] as List?;
  if (records != null && records.isNotEmpty) {
    record = (records.first as Map)['summary']?.toString();
  }
  final name = (t['displayName'] ?? t['name'] ?? '').toString();
  return SportsTeam(
    id: (t['id'] ?? name).toString(),
    name: name,
    shortName: (t['shortDisplayName'] ?? t['name'] ?? name).toString(),
    abbreviation: (t['abbreviation'] ?? '').toString(),
    logoUrl: t['logo']?.toString(),
    color: t['color']?.toString(),
    record: record,
    score: c['score']?.toString(),
  );
}
