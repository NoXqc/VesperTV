import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sports.dart';

/// TheSportsDB (thesportsdb.com) — the second scores source, for leagues
/// ESPN doesn't cover ([SportsLeague.sportsDbId]). [SportsService] routes
/// those leagues here; the screens never know.
///
/// Uses TheSportsDB's public free key (`123`, shared by every free user —
/// not a secret, so no BYOK). The free tier is enough for the Sports tab:
/// every game of a league on one day with final scores, the next game, and
/// the top 5 of the table (that's all it returns). No live minute, box
/// score or full table — those need a paid key.
///
/// Rate limit (measured 2026-10-20): ~10 quick requests, then HTTP 429 with
/// a `Retry-After` that grows on repeat (35 s, then 120 s). So every request
/// goes through [get]'s bucket, a day is one request per league (not ESPN's
/// three), and live days refresh every 2 minutes.
class SportsDbSource {
  static const _base = 'https://www.thesportsdb.com/api/v1/json/123';

  static const _burst = 6;
  static const _refill = Duration(seconds: 4);
  static double _tokens = _burst.toDouble();
  static DateTime _tokensAt = DateTime.now();
  static DateTime? _blockedUntil;
  static Future<void> _queue = Future.value();

  /// GET through the rate-limit bucket. While TheSportsDB says to wait
  /// (`Retry-After`), fails at once so callers keep their cached data.
  static Future<http.Response> get(http.Client client, Uri url) {
    final turn = _queue.then((_) => _takeToken());
    _queue = turn.catchError((_) {});
    return turn.then((_) async {
      final response =
          await client.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 429) {
        final wait = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _blockedUntil = DateTime.now().add(Duration(seconds: wait));
        _tokens = 0;
      }
      return response;
    });
  }

  static Future<void> _takeToken() async {
    final blocked = _blockedUntil;
    if (blocked != null && DateTime.now().isBefore(blocked)) {
      throw Exception('TheSportsDB rate limit, retry after $blocked');
    }
    final now = DateTime.now();
    _tokens = (_tokens +
            now.difference(_tokensAt).inMilliseconds / _refill.inMilliseconds)
        .clamp(0, _burst.toDouble());
    _tokensAt = now;
    if (_tokens < 1) {
      final wait = _refill * (1 - _tokens);
      await Future<void>.delayed(wait);
      _tokens = 1;
      _tokensAt = DateTime.now();
    }
    _tokens -= 1;
  }

  static Uri dayUrl(SportsLeague league, DateTime utcDate) =>
      Uri.parse('$_base/eventsday.php?d=${_date(utcDate)}'
          '&l=${league.sportsDbId}');

  static Uri nextUrl(SportsLeague league) =>
      Uri.parse('$_base/eventsnextleague.php?id=${league.sportsDbId}');

  static Uri tableUrl(SportsLeague league) =>
      Uri.parse('$_base/lookuptable.php?l=${league.sportsDbId}');

  /// A team's last and next game (My Teams) — one each on the free key,
  /// from any competition the team plays in.
  static List<Uri> teamUrls(String teamId) => [
        Uri.parse('$_base/eventslast.php?id=$teamId'),
        Uri.parse('$_base/eventsnext.php?id=$teamId'),
      ];

  static String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Top-level so [compute] can run it on a background isolate. Reads the
/// `events` (day / next) or `results` (team's last) list.
List<SportsGame> parseSportsDbEvents((String, SportsLeague) args) {
  final (body, league) = args;
  final json = jsonDecode(body);
  if (json is! Map) return const [];
  final list = json['events'] ?? json['results'];
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is Map<String, dynamic>)
        if (_parseEvent(e, league) case final g?) g,
  ];
}

SportsGame? _parseEvent(Map<String, dynamic> e, SportsLeague league) {
  final id = e['idEvent']?.toString();
  final start = _start(e);
  if (id == null || start == null) return null;
  final status = (e['strStatus'] ?? '').toString().trim().toUpperCase();
  final postponed = e['strPostponed']?.toString() == 'yes';
  final (state, text) = switch (status) {
    _ when postponed => (GameState.post, 'Postponed'),
    'FT' || 'AET' || 'PEN' || 'AP' || 'AWD' || 'WO' => (GameState.post, status),
    'MATCH FINISHED' => (GameState.post, 'FT'),
    'PST' || 'POSTPONED' => (GameState.post, 'Postponed'),
    'CANC' || 'ABD' => (GameState.post, 'Canceled'),
    '1H' => (GameState.live, '1st Half'),
    '2H' => (GameState.live, '2nd Half'),
    'HT' => (GameState.live, 'HT'),
    'ET' || 'BT' => (GameState.live, 'Extra Time'),
    'P' => (GameState.live, 'Penalties'),
    'LIVE' || 'INT' => (GameState.live, ''),
    _ => (GameState.pre, ''),
  };
  String? score(String key) {
    final s = e[key]?.toString();
    return state == GameState.pre || s == null || s.isEmpty ? null : s;
  }

  SportsTeam team(String side) {
    final name = (e['str${side}Team'] ?? '').toString();
    return SportsTeam(
      id: (e['id${side}Team'] ?? name).toString(),
      name: name,
      shortName: name,
      abbreviation: '',
      logoUrl: e['str${side}TeamBadge']?.toString(),
      score: score('int${side}Score'),
    );
  }

  return SportsGame(
    id: id,
    league: league,
    start: start,
    state: state,
    statusText: text,
    home: team('Home'),
    away: team('Away'),
  );
}

/// `strTimestamp` is UTC without a zone ("2026-10-18T13:00:00"); older
/// rows only have `dateEvent` + `strTime` (also UTC).
DateTime? _start(Map<String, dynamic> e) {
  var raw = e['strTimestamp']?.toString();
  if (raw == null || raw.isEmpty) {
    final date = e['dateEvent']?.toString();
    if (date == null || date.isEmpty) return null;
    final time = e['strTime']?.toString();
    raw = '${date}T${time == null || time.isEmpty ? '00:00:00' : time}';
  }
  raw = raw.replaceFirst(RegExp(r'(Z|[+-]\d\d:?\d\d)$'), '');
  return DateTime.tryParse('${raw}Z')?.toUtc();
}

/// Top-level so [compute] can run it on a background isolate. Rows carry
/// the same stat names as ESPN's soccer tables, so the Standings screen's
/// soccer columns read them unchanged.
SportsStandings parseSportsDbTable((String, SportsLeague) args) {
  final (body, league) = args;
  final json = jsonDecode(body);
  final list = json is Map ? json['table'] : null;
  final byGroup = <String, List<SportsStandingRow>>{};
  String? season;
  for (final r in list is List ? list : const []) {
    if (r is! Map) continue;
    final name = (r['strTeam'] ?? '').toString();
    if (name.isEmpty) continue;
    season ??= r['strSeason']?.toString().replaceFirstMapped(
        RegExp(r'^(\d{4})-\d\d(\d\d)$'), (m) => '${m[1]}-${m[2]}');
    // "/tiny" is already on the table's badges; [sportsLogoUrl] adds it.
    final badge = r['strBadge']?.toString().replaceFirst(RegExp(r'/tiny$'), '');
    final gd = int.tryParse(r['intGoalDifference']?.toString() ?? '');
    final note = r['strDescription']?.toString();
    byGroup.putIfAbsent((r['strGroup'] ?? '').toString(), () => []).add(
          SportsStandingRow(
            team: SportsTeam(
              id: (r['idTeam'] ?? name).toString(),
              name: name,
              shortName: name,
              abbreviation: '',
              logoUrl: badge,
            ),
            position: int.tryParse(r['intRank']?.toString() ?? '') ?? 0,
            stats: {
              'rank': (r['intRank'] ?? '').toString(),
              'gamesPlayed': (r['intPlayed'] ?? '').toString(),
              'wins': (r['intWin'] ?? '').toString(),
              'ties': (r['intDraw'] ?? '').toString(),
              'losses': (r['intLoss'] ?? '').toString(),
              'pointDifferential': gd == null ? '' : (gd > 0 ? '+$gd' : '$gd'),
              'points': (r['intPoints'] ?? '').toString(),
            },
            note: note == null || note.isEmpty ? null : note,
          ),
        );
  }
  final single = byGroup.length == 1;
  return SportsStandings(
    league: league,
    season: season,
    groups: [
      for (final MapEntry(:key, :value) in byGroup.entries)
        SportsStandingGroup(
          // One table: the league's own name, not TheSportsDB's "HNL".
          name: single || key.isEmpty ? league.name : key,
          rows: value..sort((a, b) => a.position.compareTo(b.position)),
        ),
    ],
  );
}
