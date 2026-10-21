import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sports.dart';
import 'cfl_game_stats.dart';

/// The same public JSON used by CFL's scoreboard and stats sites. The
/// scoreboard is the whole current season, so share one request across
/// days, My Teams and next-game lookups. No background polling here.
class CflSource {
  CflSource(this._client, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static final roundsUrl =
      Uri.parse('https://cflscoreboard.cfl.ca/json/scoreboard/rounds.json');
  static final teamsUrl = Uri.parse('https://api.stats.cfl.ca/teams');
  final http.Client _client;
  final DateTime Function() _now;
  CflSeason? _cached;
  DateTime? _fetchedAt;
  Future<CflSeason>? _inFlight;
  Future<String>? _teams;

  List<SportsGame> get cachedGames => _cached?.games ?? const [];

  Future<String> _get(Uri url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final response = await _client.get(url).timeout(timeout);
    if (response.statusCode != 200) {
      throw Exception('CFL HTTP ${response.statusCode}');
    }
    return response.body;
  }

  Future<String> _teamMetadata() => _teams ??= _get(teamsUrl).catchError((e) {
        _teams = null;
        throw e;
      });

  Future<CflSeason> _season() {
    final cached = _cached;
    if (cached != null) {
      final now = _now();
      final nearGame = cached.games.any((g) =>
          g.state == GameState.live ||
          (g.state == GameState.pre &&
              g.start.difference(now).abs() < const Duration(minutes: 30)));
      final ttl =
          nearGame ? const Duration(seconds: 50) : const Duration(minutes: 10);
      if (now.difference(_fetchedAt!) < ttl) return Future.value(cached);
    }
    return _inFlight ??= _download().whenComplete(() => _inFlight = null);
  }

  Future<CflSeason> _download() async {
    final bodies = await Future.wait([_get(roundsUrl), _teamMetadata()]);
    final season = await compute(parseCflSeason, (bodies[0], bodies[1]));
    _cached = season;
    _fetchedAt = _now();
    return season;
  }

  Future<List<SportsGame>> games() async => (await _season()).games;

  Future<SportsGameSummary> gameSummary(SportsGame game) async {
    Future<String?> load(String widget) async {
      try {
        return await _get(cflGameStatsUrl(widget, game.id),
            timeout: const Duration(seconds: 6));
      } catch (e) {
        debugPrint('CFL $widget ${game.id} failed: $e');
        return null;
      }
    }

    final bodies = await Future.wait([load('teamStats'), load('playerStats')]);
    return compute(
        parseCflGameStats, (bodies[0], bodies[1], game.home.id, game.away.id));
  }

  Future<SportsStandings> standings() async {
    final season = await _season();
    // Use the scoreboard's season, including during the winter offseason.
    final body = await _get(
        Uri.parse('https://api.stats.cfl.ca/standings/${season.year}'));
    return compute(parseCflStandings, (body, season));
  }

  Future<SportsTeamSchedule?> teamSchedule(String teamId) async {
    final season = await _season();
    final team = season.teams[teamId];
    if (team == null) return null;
    return SportsTeamSchedule(
      league: sportsLeagueById('cfl')!,
      team: team,
      games: [
        for (final game in season.games)
          if (game.home.id == teamId || game.away.id == teamId) game,
      ],
    );
  }
}

class CflSeason {
  const CflSeason(this.year, this.games, this.teams);
  final int year;
  final List<SportsGame> games;

  /// Abbreviations are stable across the two CFL APIs; their numeric team
  /// ids are different. The same id must work for Follow, picks and REC.
  final Map<String, SportsTeam> teams;
}

/// Parse off the UI isolate: rounds.json is about 300 KB for a season.
CflSeason parseCflSeason((String, String) bodies) {
  final rounds = jsonDecode(bodies.$1);
  final metadata = jsonDecode(bodies.$2);
  if (rounds is! List || metadata is! List) {
    throw const FormatException('Invalid CFL season');
  }
  final info = <String, Map>{
    for (final team in metadata.whereType<Map>())
      if (team['abbreviation'] != null)
        team['abbreviation'].toString().toUpperCase(): team,
  };
  final matches = <String, (Map, String)>{};
  for (final round in rounds.whereType<Map>()) {
    for (final game
        in (round['tournaments'] as List? ?? const []).whereType<Map>()) {
      if (game['id'] == null || DateTime.tryParse('${game['date']}') == null) {
        continue;
      }
      final home = game['homeSquad'];
      final away = game['awaySquad'];
      // Playoff placeholders are not games to match or auto-record yet.
      if (home is! Map ||
          away is! Map ||
          home['id'] == 0 ||
          away['id'] == 0 ||
          !info.containsKey(home['shortName']) ||
          !info.containsKey(away['shortName'])) {
        continue;
      }
      matches['${game['id']}'] = (game, '${round['type']}');
    }
  }
  if (matches.isEmpty) throw const FormatException('No CFL games');
  final records = <String, List<int>>{};
  for (final entry in matches.values) {
    final (game, type) = entry;
    if (type != 'REG' || game['status'] != 'complete') {
      continue;
    }
    final home = game['homeSquad'] as Map;
    final away = game['awaySquad'] as Map;
    final hs = num.tryParse('${home['score']}');
    final awayScore = num.tryParse('${away['score']}');
    if (hs == null || awayScore == null) continue;
    final hr = records.putIfAbsent('${home['shortName']}', () => [0, 0, 0]);
    final ar = records.putIfAbsent('${away['shortName']}', () => [0, 0, 0]);
    hr[hs > awayScore
        ? 0
        : hs < awayScore
            ? 1
            : 2]++;
    ar[awayScore > hs
        ? 0
        : awayScore < hs
            ? 1
            : 2]++;
  }
  final teams = <String, SportsTeam>{};
  SportsTeam team(Map side, {bool showScore = false}) {
    final id = '${side['shortName']}'.toUpperCase();
    final m = info[id]!;
    final rec = records[id] ?? [0, 0, 0];
    final t = SportsTeam(
      id: id,
      name: '${side['name']}',
      shortName: m['name']?.toString() ?? '${side['name']}',
      abbreviation: id,
      color: m['primary_color']?.toString(),
      logoUrl: 'https://cflscoreboard.cfl.ca/media/squads/${side['id']}.png',
      record: '${rec[0]}-${rec[1]}${rec[2] > 0 ? '-${rec[2]}' : ''}',
      score: showScore ? side['score']?.toString() : null,
    );
    teams[id] = SportsTeam(
      id: t.id,
      name: t.name,
      shortName: t.shortName,
      abbreviation: t.abbreviation,
      color: t.color,
      logoUrl: t.logoUrl,
      record: t.record,
    );
    return t;
  }

  final league = sportsLeagueById('cfl')!;
  final games = <SportsGame>[];
  for (final (game, _) in matches.values) {
    final status = '${game['status']}';
    final state = switch (status) {
      'complete' || 'canceled' || 'cancelled' => GameState.post,
      'first_quarter' ||
      'second_quarter' ||
      'third_quarter' ||
      'fourth_quarter' ||
      'half_time' ||
      'overtime' ||
      'playing' =>
        GameState.live,
      _ => GameState.pre,
    };
    final hidden = game['isHidden'] == true;
    final score = !hidden &&
        state != GameState.pre &&
        status != 'canceled' &&
        status != 'cancelled';
    final home = team(game['homeSquad'] as Map, showScore: score);
    final away = team(game['awaySquad'] as Map, showScore: score);
    final period = switch (status) {
      'first_quarter' => '1st',
      'second_quarter' => '2nd',
      'third_quarter' => '3rd',
      'fourth_quarter' => '4th',
      'half_time' => 'Halftime',
      'overtime' => 'OT',
      'complete' => 'Final',
      'canceled' || 'cancelled' => 'Canceled',
      'playing' => 'Live',
      _ => 'Scheduled',
    };
    final clock = game['clock']?.toString() ?? '';
    games.add(SportsGame(
      id: '${game['id']}',
      league: league,
      start: DateTime.parse('${game['date']}').toUtc(),
      state: state,
      statusText: hidden
          ? 'Score unavailable'
          : state == GameState.live && clock.isNotEmpty && status != 'half_time'
              ? '$clock - $period'
              : period,
      home: home,
      away: away,
      situation: state == GameState.live && !hidden
          ? SportsSituation(
              possessionTeamId: switch (game['possession']) {
              'Home' => home.id,
              'Away' => away.id,
              _ => null,
            })
          : null,
    ));
  }
  games.sort((a, b) => a.start.compareTo(b.start));
  return CflSeason(games.last.start.year, games, teams);
}

/// CFL publishes its own division membership and tiebreak ranking here.
SportsStandings parseCflStandings((String, CflSeason) args) {
  final json = jsonDecode(args.$1);
  final season = args.$2;
  final data = json is Map ? json['data'] : null;
  final divisions = data is Map ? data['divisions'] : null;
  if (divisions is! Map) throw const FormatException('Invalid CFL standings');
  final groups = <SportsStandingGroup>[];
  for (final entry in divisions.entries) {
    // CFL also supplies an all-league table; don't duplicate both divisions.
    if (entry.key == 'unified' &&
        (divisions.containsKey('east') || divisions.containsKey('west'))) {
      continue;
    }
    final division = entry.value;
    if (division is! Map) continue;
    final rows = <SportsStandingRow>[];
    for (final row
        in (division['standings'] as List? ?? const []).whereType<Map>()) {
      final team = season.teams['${row['abbreviation']}'.toUpperCase()];
      if (team == null) continue;
      String stat(String key) => row[key]?.toString() ?? '';
      String record(String prefix) =>
          '${stat('${prefix}_wins')}-${stat('${prefix}_losses')}'
          '${(row['${prefix}_ties'] as num? ?? 0) > 0 ? '-${stat('${prefix}_ties')}' : ''}';
      final diff = (row['points_for'] as num? ?? 0) -
          (row['points_against'] as num? ?? 0);
      rows.add(SportsStandingRow(
        team: team,
        position: (row['place_override'] as num? ??
                row['place'] as num? ??
                rows.length + 1)
            .toInt(),
        stats: {
          'gamesPlayed': stat('games_played'),
          'wins': stat('wins'),
          'losses': stat('losses'),
          'ties': stat('ties'),
          'points': stat('points'),
          'winPercent':
              (row['winning_percentage'] as num? ?? 0).toStringAsFixed(3),
          'pointsFor': stat('points_for'),
          'pointsAgainst': stat('points_against'),
          'pointDifferential': '${diff > 0 ? '+' : ''}$diff',
          'Home': record('home'),
          'Road': record('away'),
        },
      ));
    }
    rows.sort((a, b) => a.position.compareTo(b.position));
    if (rows.isNotEmpty) {
      groups.add(SportsStandingGroup(
        name: switch (entry.key) {
          'east' => 'East Division',
          'west' => 'West Division',
          'unified' => 'CFL',
          _ => '${division['division_name'] ?? entry.key}',
        },
        rows: rows,
      ));
    }
  }
  if (groups.isEmpty) throw const FormatException('No CFL standings');
  return SportsStandings(
      league: sportsLeagueById('cfl')!,
      groups: groups,
      season: '${season.year}');
}
