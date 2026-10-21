import 'dart:convert';

import '../models/sports.dart';

/// Public Genius Sports feeds embedded by CFL.ca's own gametracker. The
/// customer segment identifies CFL's public widget; no API key is used.
Uri cflGameStatsUrl(String widget, String gameId) => Uri.https(
      'gsm-widgets.betstream.betgenius.com',
      '/v1/widget/$widget/customer/democfl_light/locale/en-US/geolocale/any-',
      {'fixtureId': gameId},
    );

Map? _details(String? body) {
  if (body == null) return null;
  try {
    final json = jsonDecode(body);
    final data = json is Map ? json['data'] : null;
    final status = data is Map ? data['status'] : null;
    if (data is! Map || status is! Map || status['status'] != 'AVAILABLE') {
      return null;
    }
    return data['details'] is Map ? data['details'] as Map : null;
  } on FormatException {
    return null;
  }
}

/// Keep the home/away order from the feed: the shared dialog does the
/// final on-screen ordering. Either feed may be unavailable before kickoff.
SportsGameSummary parseCflGameStats((String?, String?, String, String) args) {
  final (teamBody, playerBody, homeId, awayId) = args;
  final teamStats = <(String, String, String)>[];
  final rawStats = _details(teamBody)?['stats'];
  final stats = <String, Map>{
    if (rawStats is List)
      for (final stat in rawStats.whereType<Map>()) '${stat['id']}': stat,
  };
  const columns = [
    ('passing_detailed', 'Passing yards'),
    ('rushing_detailed', 'Rushing yards'),
    ('net_offense_detailed', 'Net offence'),
    ('first_down_detailed', 'First downs'),
    ('sacks_for_detailed', 'Sacks'),
    ('second_down_detailed', '2nd down conversions'),
    ('giveaways_detailed', 'Turnovers'),
    ('penalties_detailed', 'Penalties (yards)'),
    ('field_goals_detailed', 'Field goals'),
    ('time_possession', 'Time of possession'),
  ];
  String display(Object? v) {
    if (v == null) return '–';
    if (v is num && v == v.roundToDouble()) return '${v.toInt()}';
    return '$v';
  }

  String value(String id, Object? raw) {
    if (raw is! List) return display(raw);
    Object? at(int i) => i < raw.length ? raw[i] : null;
    switch (id) {
      case 'first_down_detailed':
      case 'giveaways_detailed':
        final nums = [for (final v in raw) num.tryParse('$v')];
        if (nums.isEmpty || nums.any((v) => v == null)) return '–';
        return display(nums.fold<num>(0, (sum, v) => sum + v!));
      case 'second_down_detailed':
      case 'field_goals_detailed':
        return '${display(at(1))}/${display(at(0))}';
      case 'penalties_detailed':
        return '${display(at(0))}-${display(at(1))}';
      default:
        return display(at(0));
    }
  }

  for (final (id, label) in columns) {
    final stat = stats[id];
    if (stat != null && (stat['away'] != null || stat['home'] != null)) {
      teamStats.add((label, value(id, stat['away']), value(id, stat['home'])));
    }
  }

  // The first column is also the sort key: the top eight performers,
  // never an arbitrary roster prefix. Participation flags in this feed
  // sometimes say ActiveNotPlayed even for players with real game stats.
  const groups = [
    (
      'passing',
      'passing',
      [
        ('YARDS', 'YDS'),
        ('COMPLETIONS_ATTEMPTS', 'C/ATT'),
        ('TOUCHDOWNS', 'TD'),
        ('INTERCEPTIONS', 'INT'),
      ]
    ),
    (
      'rushing',
      'rushing',
      [
        ('YARDS', 'YDS'),
        ('CARRIES', 'CAR'),
        ('AVERAGE_YARDS', 'AVG'),
        ('TOUCHDOWNS', 'TD'),
      ]
    ),
    (
      'receiving',
      'receiving',
      [
        ('YARDS', 'YDS'),
        ('RECEPTIONS', 'REC'),
        ('TOUCHDOWNS', 'TD'),
        ('TARGETS', 'TGTS'),
      ]
    ),
    (
      'defence',
      'defensive',
      [
        ('DEFENCE_TACKLES', 'TOT'),
        ('DEFENCE_SOLO', 'SOLO'),
        ('DEFENCE_SK', 'SACK'),
        ('DEFENCE_INT', 'INT'),
      ]
    ),
    (
      'fieldGoals',
      'kicking',
      [
        ('FIELDGOALS_FGFGA', 'FG'),
        ('FIELDGOALS_XP', 'XP'),
        ('FIELDGOALS_LNG', 'LONG'),
        ('FIELDGOALS_SNG', 'SNG'),
      ]
    ),
    (
      'punts',
      'punting',
      [
        ('PUNTING_YDS', 'YDS'),
        ('PUNTING_NO', 'NO'),
        ('PUNTING_AVG', 'AVG'),
        ('PUNTING_LNG', 'LONG'),
      ]
    ),
    (
      'kickoffs',
      'kickoffs',
      [
        ('KICKOFFS_YDS', 'YDS'),
        ('KICKOFFS_NO', 'NO'),
        ('KICKOFFS_AVG', 'AVG'),
        ('KICKOFFS_LNG', 'LONG'),
      ]
    ),
    (
      'kickoffReturns',
      'kickoffReturns',
      [
        ('KICKRETURN_YDS', 'YDS'),
        ('KICKRETURN_NO', 'NO'),
        ('KICKRETURN_AVG', 'AVG'),
        ('KICKRETURN_LNG', 'LONG'),
      ]
    ),
    (
      'puntReturns',
      'puntReturns',
      [
        ('PUNTRETURN_YDS', 'YDS'),
        ('PUNTRETURN_NO', 'NO'),
        ('PUNTRETURN_AVG', 'AVG'),
        ('PUNTRETURN_LNG', 'LONG'),
      ]
    ),
  ];
  final players = <String, List<SportsPlayerGroup>>{};
  final details = _details(playerBody);
  for (final (side, teamId) in [('homeTeam', homeId), ('awayTeam', awayId)]) {
    final team = details?[side];
    if (team is! Map) continue;
    final parsed = <SportsPlayerGroup>[];
    for (final (source, title, fields) in groups) {
      final roster = team[source];
      if (roster is! List) continue;
      final rows = <(String, List<String>, double)>[];
      for (final player in roster.whereType<Map>()) {
        final raw = player['stats'];
        if (raw is! List) continue;
        final values = {
          for (final s in raw.whereType<Map>())
            '${s['name']}': s['statValue']?.toString(),
        };
        if (!fields.any((f) => values[f.$1]?.isNotEmpty ?? false)) continue;
        final name = (player['abbreviationName'] ?? player['name'])?.toString();
        if (name == null || name.isEmpty) continue;
        final first = values[fields.first.$1] ?? '';
        rows.add((
          name,
          [for (final (key, _) in fields) values[key] ?? '–'],
          double.tryParse(first.split('/').first) ?? 0
        ));
      }
      rows.sort((a, b) {
        final rank = b.$3.compareTo(a.$3);
        return rank != 0 ? rank : a.$1.compareTo(b.$1);
      });
      if (rows.isNotEmpty) {
        parsed.add(SportsPlayerGroup(
            title: title,
            labels: [for (final (_, label) in fields) label],
            rows: [for (final (name, vals, _) in rows.take(8)) (name, vals)]));
      }
    }
    if (parsed.isNotEmpty) players[teamId] = parsed;
  }
  return SportsGameSummary(teamStats: teamStats, players: players);
}
