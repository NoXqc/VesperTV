/// Sports tab data model — provider-neutral, so a second data source (a
/// BYOK API, see dev-notes/sports-tab.md) is one more adapter producing
/// these, not a UI change. All times are UTC; convert only for display.
library;

class SportsLeague {
  const SportsLeague({
    required this.id,
    required this.espnPath,
    required this.name,
    required this.shortName,
    required this.logoUrl,
    this.soccer = false,
  });

  /// Stable id stored in prefs (`nhl`, `eng.1`, ...).
  final String id;

  /// `{sport}/{league}` segment of ESPN's site API.
  final String espnPath;
  final String name;
  final String shortName;
  final String logoUrl;

  /// Soccer reads "Home vs Away" and shows a minute clock; North American
  /// leagues read "Away at Home".
  final bool soccer;
}

/// Every league the tab knows about, in the default order.
const List<SportsLeague> kSportsLeagues = [
  SportsLeague(
      id: 'nhl',
      espnPath: 'hockey/nhl',
      name: 'NHL',
      shortName: 'NHL',
      logoUrl: 'https://a.espncdn.com/i/teamlogos/leagues/500/nhl.png'),
  SportsLeague(
      id: 'nfl',
      espnPath: 'football/nfl',
      name: 'NFL',
      shortName: 'NFL',
      logoUrl: 'https://a.espncdn.com/i/teamlogos/leagues/500/nfl.png'),
  SportsLeague(
      id: 'nba',
      espnPath: 'basketball/nba',
      name: 'NBA',
      shortName: 'NBA',
      logoUrl: 'https://a.espncdn.com/i/teamlogos/leagues/500/nba.png'),
  SportsLeague(
      id: 'mlb',
      espnPath: 'baseball/mlb',
      name: 'MLB',
      shortName: 'MLB',
      logoUrl: 'https://a.espncdn.com/i/teamlogos/leagues/500/mlb.png'),
  SportsLeague(
      id: 'college-football',
      espnPath: 'football/college-football',
      name: 'College Football',
      shortName: 'NCAAF',
      logoUrl:
          'https://a.espncdn.com/redesign/assets/img/icons/ESPN-icon-football-college.png'),
  SportsLeague(
      id: 'wnba',
      espnPath: 'basketball/wnba',
      name: 'WNBA',
      shortName: 'WNBA',
      logoUrl: 'https://a.espncdn.com/i/teamlogos/leagues/500/wnba.png'),
  SportsLeague(
      id: 'usa.1',
      espnPath: 'soccer/usa.1',
      name: 'MLS',
      shortName: 'MLS',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/19.png',
      soccer: true),
  SportsLeague(
      id: 'eng.1',
      espnPath: 'soccer/eng.1',
      name: 'Premier League',
      shortName: 'EPL',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/23.png',
      soccer: true),
  SportsLeague(
      id: 'uefa.champions',
      espnPath: 'soccer/uefa.champions',
      name: 'Champions League',
      shortName: 'UCL',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2.png',
      soccer: true),
  SportsLeague(
      id: 'esp.1',
      espnPath: 'soccer/esp.1',
      name: 'LaLiga',
      shortName: 'LaLiga',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/15.png',
      soccer: true),
  SportsLeague(
      id: 'ger.1',
      espnPath: 'soccer/ger.1',
      name: 'Bundesliga',
      shortName: 'BUN',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/10.png',
      soccer: true),
  SportsLeague(
      id: 'ita.1',
      espnPath: 'soccer/ita.1',
      name: 'Serie A',
      shortName: 'SA',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/12.png',
      soccer: true),
  SportsLeague(
      id: 'fra.1',
      espnPath: 'soccer/fra.1',
      name: 'Ligue 1',
      shortName: 'L1',
      logoUrl: 'https://a.espncdn.com/i/leaguelogos/soccer/500/9.png',
      soccer: true),
];

/// Shown until the user picks their own set in Edit leagues.
const List<String> kDefaultSportsLeagueIds = [
  'nhl',
  'nfl',
  'nba',
  'mlb',
  'eng.1',
  'uefa.champions',
];

SportsLeague? sportsLeagueById(String id) {
  for (final l in kSportsLeagues) {
    if (l.id == id) return l;
  }
  return null;
}

/// ESPN serves original logos up to 500 px (~100 KB each); its own resizer
/// returns a ~8 KB version — what a weak TV box should download and decode.
String? sportsLogoUrl(String? url, {int size = 96}) {
  if (url == null || url.isEmpty) return null;
  const host = 'https://a.espncdn.com/';
  if (!url.startsWith(host) || url.contains('/combiner/')) return url;
  final path = url.substring(host.length - 1);
  return '${host}combiner/i?img=$path&w=$size&h=$size';
}

/// ESPN's dark-background variant of a team/league logo (`/500-dark/`) —
/// navy or black logos (Capitals, Nets, Raiders) vanish on the app's black
/// theme otherwise. Not every team has one (404) — callers fall back to the
/// original. Null when the URL isn't an ESPN `/500/` logo.
String? sportsDarkLogoUrl(String? url) {
  if (url == null) return null;
  for (final segment in const ['/500/scoreboard/', '/500/']) {
    if (url.contains(segment)) return url.replaceFirst(segment, '/500-dark/');
  }
  return null;
}

enum GameState { pre, live, post }

class SportsTeam {
  const SportsTeam({
    required this.id,
    required this.name,
    required this.shortName,
    required this.abbreviation,
    this.logoUrl,
    this.color,
    this.record,
    this.score,
  });

  final String id;

  /// Full name ("Detroit Red Wings").
  final String name;

  /// Nickname ("Red Wings"; soccer: "Bremen").
  final String shortName;
  final String abbreviation;
  final String? logoUrl;

  /// Hex without `#`, e.g. `e30526`.
  final String? color;

  /// "1-3-1" (W-L-OTL / W-D-L).
  final String? record;
  final String? score;
}

class SportsGame {
  const SportsGame({
    required this.id,
    required this.league,
    required this.start,
    required this.state,
    required this.statusText,
    required this.home,
    required this.away,
    this.broadcasts = const [],
  });

  final String id;
  final SportsLeague league;
  final DateTime start;
  final GameState state;

  /// Provider's short status ("End of 2nd", "73'", "Final", "7:00 PM").
  final String statusText;
  final SportsTeam home;
  final SportsTeam away;

  /// TV networks the provider lists ("ESPN", "TNT", "MSGB").
  final List<String> broadcasts;

  /// The two sides in on-screen order (see [SportsLeague.soccer]).
  SportsTeam get first => league.soccer ? home : away;
  SportsTeam get second => league.soccer ? away : home;
  String get joiner => league.soccer ? 'vs' : 'at';

  String get title => '${first.shortName} $joiner ${second.shortName}';
}

/// One team's line in a standings table. [stats] is keyed by the provider's
/// stat name (`wins`, `points`, `streak`, ...) with display-ready values, so
/// each sport can pick its own columns without the model knowing them.
class SportsStandingRow {
  const SportsStandingRow({
    required this.team,
    required this.position,
    required this.stats,
    this.noteColor,
    this.note,
  });

  final SportsTeam team;

  /// 1-based place in its group (after sorting).
  final int position;
  final Map<String, String> stats;

  /// Soccer qualification zone ("Champions League", "Relegation") and its
  /// hex colour (no `#`).
  final String? noteColor;
  final String? note;

  String stat(String name) => stats[name] ?? '';
}

/// A conference, division or league table.
class SportsStandingGroup {
  const SportsStandingGroup({required this.name, required this.rows});
  final String name;
  final List<SportsStandingRow> rows;
}

/// A team in My Teams. Team ids are only unique within a league.
class FollowedTeam {
  const FollowedTeam(this.leagueId, this.teamId);

  final String leagueId;
  final String teamId;

  /// Stored form, `leagueId|teamId`; null when malformed.
  static FollowedTeam? parse(String raw) {
    final i = raw.indexOf('|');
    if (i <= 0 || i == raw.length - 1) return null;
    return FollowedTeam(raw.substring(0, i), raw.substring(i + 1));
  }

  String get key => '$leagueId|$teamId';

  @override
  bool operator ==(Object other) =>
      other is FollowedTeam &&
      other.leagueId == leagueId &&
      other.teamId == teamId;

  @override
  int get hashCode => Object.hash(leagueId, teamId);
}

/// One team's season: who they are, where they stand, every game.
class SportsTeamSchedule {
  const SportsTeamSchedule({
    required this.league,
    required this.team,
    required this.games,
    this.standingSummary,
  });

  final SportsLeague league;

  /// [SportsTeam.record] is the season record ("1-3-2").
  final SportsTeam team;

  /// "8th in Atlantic Division".
  final String? standingSummary;

  /// Oldest first.
  final List<SportsGame> games;

  /// The game being played now, else the next one, else null.
  SportsGame? get nextGame =>
      games.where((g) => g.state == GameState.live).firstOrNull ??
      games.where((g) => g.state == GameState.pre).firstOrNull;

  SportsGame? get lastGame =>
      games.where((g) => g.state == GameState.post).lastOrNull;

  /// Live and upcoming games starting within [days] days.
  List<SportsGame> upcoming({int days = 14}) {
    final until = DateTime.now().toUtc().add(Duration(days: days));
    return [
      for (final g in games)
        if (g.state == GameState.live ||
            (g.state == GameState.pre && g.start.isBefore(until)))
          g,
    ];
  }
}

class SportsStandings {
  const SportsStandings({
    required this.league,
    required this.groups,
    this.season,
    this.preseason = false,
  });

  final SportsLeague league;
  final List<SportsStandingGroup> groups;

  /// "2026-27".
  final String? season;

  /// Exhibition-game records (the NBA publishes those before opening night).
  final bool preseason;
}
