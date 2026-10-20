import '../models/channel.dart';
import '../models/sports.dart';
import 'epg_service.dart';
import 'playlist_manager.dart';
import 'sports_channel_matcher.dart';
import 'sports_follows.dart';
import 'sports_service.dart';
import 'storage_service.dart';

/// A game being played right now and the channel that best shows it.
typedef LiveGameChannel = ({SportsGame game, Channel channel});

/// The Multiview channel picker's two sports shortcuts (most Multiview
/// viewers watch sports — owner, 2026-10-19):
/// - "Live now": games playing right now in the viewer's Sports Trak
///   leagues (+ followed teams' leagues), each with its best matched
///   channel — the same matching as Sports Trak and the player side panel;
/// - "Sports": every channel whose group or name looks like sports.
class MultiviewSports {
  MultiviewSports._();

  /// Whole-word sports terms in a group or channel name ("NHL | Events",
  /// "USA | SPORTS", "ESPN 2", "TSN 1", "DAZN 1"…). Words only: "f1" must
  /// not match "HDF1".
  static final _sportsWords = RegExp(
      r'\b(sports?|deportes?|esportes?|espn\w*|tsn\d*|sportsnet|dazn|bein|'
      r'eurosport|supersport|nfl|nba|nhl|mlb|mls|ncaa|ufc|wwe|pfl|ppv|f1|'
      r'formula 1|nascar|indycar|motogp|golf|tennis|boxing|hockey|soccer|'
      r'football|futbol|basketball|baseball|cricket|rugby|racing|redzone)\b',
      caseSensitive: false);

  static bool isSports(Channel c) =>
      _sportsWords.hasMatch(c.group) || _sportsWords.hasMatch(c.name);

  /// Live games with a matched channel, earliest start first. Games with no
  /// channel in the viewer's playlists are left out.
  static Future<List<LiveGameChannel>> liveGames({
    required StorageService storage,
    required PlaylistManager playlist,
    required EpgService epg,
  }) async {
    final follows = SportsFollows.load(storage);
    final leagues = <String, SportsLeague>{
      for (final l in savedSportsLeagues(storage)) l.id: l,
      for (final t in follows.teams)
        if (sportsLeagueById(t.leagueId) case final l?) l.id: l,
    };
    if (leagues.isEmpty) return const [];
    final games = (await SportsService.instance
            .gamesForDay(leagues.values.toList(), DateTime.now()))
        .where((g) => g.state == GameState.live)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (games.isEmpty) return const [];
    final matcher = SportsChannelMatcher.shared(epg);
    await playlist.ensureLiveChannelsLoaded();
    await matcher.prepare(playlist.visibleChannels(category: 'tv'));
    final matches = await matcher
        .matchDay(games, SportsChannelPicks.load(storage), limit: 1);
    return [
      for (final g in games)
        if (matches[SportsChannelPicks.eventKey(g)]?.firstOrNull?.channel
            case final c?)
          (game: g, channel: c),
    ];
  }

  /// "Avalanche at Flyers · 2nd 12:10" (golf/racing: the event's title) —
  /// no score, so Sports Trak's hide-scores setting is never crossed.
  static String label(SportsGame g) {
    final status = g.statusText.trim();
    return status.isEmpty ? g.title : '${g.title} · $status';
  }
}
