import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/sports.dart';
import '../services/epg_service.dart';
import '../services/playback_service.dart';
import '../services/playlist_manager.dart';
import '../services/sports_channel_matcher.dart';
import '../services/sports_follows.dart';
import '../services/sports_service.dart';
import '../services/storage_service.dart';
import 'sports_widgets.dart';

/// Left on the remote in the fullscreen live player: a see-through panel
/// over the left of the picture with three tabs — Last channels, My Teams
/// (today's games of followed teams) and Live now (games playing right now
/// in the viewer's active leagues). OK plays the channel / the game's best
/// matched channel in place; Back closes it (handled by PlayerScreen's
/// PopScope).
///
/// Keys are dispatched explicitly (Left/Right = tabs, Up/Down = rows) from
/// one Focus node, with the selected row only drawn highlighted — no focus
/// node per row, so default traversal never gets a say (CLAUDE.md §10).
class PlayerSidePanel extends StatefulWidget {
  const PlayerSidePanel(
      {super.key, required this.current, required this.onClose});

  final Channel current;
  final VoidCallback onClose;

  static const double width = 400;

  @override
  State<PlayerSidePanel> createState() => _PlayerSidePanelState();
}

class _PlayerSidePanelState extends State<PlayerSidePanel> {
  static const _tabs = ['Last channels', 'My Teams', 'Live now'];
  static const double _rowHeight = 64;

  /// Reopening lands on the tab used last (for the app session).
  static int _lastTab = 0;

  /// One matcher for the session: `prepare` skips the index rebuild while
  /// the channel list is unchanged, so reopening the panel stays cheap.
  static SportsChannelMatcher? _sharedMatcher;

  final FocusNode _focus = FocusNode(debugLabel: 'player-side-panel');
  final ScrollController _scroll = ScrollController();
  late int _tab = _lastTab;
  final List<int> _index = [0, 0, 0];

  List<SportsGame> _teamGames = const [];
  List<SportsGame> _liveGames = const [];
  Map<String, List<ChannelMatch>> _matches = const {};
  bool _sportsLoading = true;
  bool _hasFollows = false;
  bool _hideScores = false;
  String? _message;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    unawaited(_loadSports());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) unawaited(_loadSports());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Channel> get _recent {
    final seen = <String>{widget.current.id};
    final out = <Channel>[];
    for (final c in context.read<PlaybackService>().recentlyPlayed) {
      if (!Channel.isLiveId(c.rawId) || !seen.add(c.id)) continue;
      out.add(c);
      if (out.length >= 15) break;
    }
    return out;
  }

  int get _count => switch (_tab) {
        0 => _recent.length,
        1 => _teamGames.length,
        _ => _liveGames.length,
      };

  Future<void> _loadSports() async {
    final storage = context.read<StorageService>();
    final follows = SportsFollows.load(storage);
    final saved = savedSportsLeagues(storage);
    final leagues = <String, SportsLeague>{
      for (final l in saved) l.id: l,
      for (final t in follows.teams)
        if (sportsLeagueById(t.leagueId) case final l?) l.id: l,
    };
    final games = await SportsService.instance
        .gamesForDay(leagues.values.toList(), DateTime.now());
    if (!mounted) return;
    int byState(SportsGame g) => switch (g.state) {
          GameState.live => 0,
          GameState.pre => 1,
          GameState.post => 2,
        };
    final team = games.where(follows.involves).toList()
      ..sort((a, b) {
        final s = byState(a).compareTo(byState(b));
        return s != 0 ? s : a.start.compareTo(b.start);
      });
    final savedIds = {for (final l in saved) l.id};
    final live = [
      ...games.where((g) =>
          g.state == GameState.live &&
          savedIds.contains(g.league.id) &&
          follows.involves(g)),
      ...games.where((g) =>
          g.state == GameState.live &&
          savedIds.contains(g.league.id) &&
          !follows.involves(g)),
    ];
    setState(() {
      _teamGames = team;
      _liveGames = live;
      _hasFollows = !follows.isEmpty;
      _hideScores = storage.getSportsHideScores();
      _sportsLoading = false;
      for (var t = 1; t < 3; t++) {
        final n = t == 1 ? team.length : live.length;
        if (_index[t] >= n) _index[t] = n == 0 ? 0 : n - 1;
      }
    });

    final playlist = context.read<PlaylistManager>();
    final matcher =
        _sharedMatcher ??= SportsChannelMatcher(context.read<EpgService>());
    await playlist.ensureLiveChannelsLoaded();
    if (!mounted) return;
    await matcher.prepare(playlist.visibleChannels(category: 'tv'));
    if (!mounted) return;
    final matches = await matcher.matchDay(
        {...team, ...live}.toList(), SportsChannelPicks.load(storage));
    if (mounted) setState(() => _matches = matches);
  }

  void _select(int tab, int index) {
    setState(() {
      _tab = tab;
      _lastTab = tab;
      _index[tab] = index;
      _message = null;
    });
    // Keep the selected row on screen — jumpTo, never animateTo (§10).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final top = _index[_tab] * _rowHeight;
      if (top < pos.pixels) {
        _scroll.jumpTo(top);
      } else if (top + _rowHeight > pos.pixels + pos.viewportDimension) {
        _scroll.jumpTo((top + _rowHeight - pos.viewportDimension)
            .clamp(0.0, pos.maxScrollExtent));
      }
    });
  }

  void _switchTab(int tab) {
    if (tab < 0 || tab >= _tabs.length || tab == _tab) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _select(tab, 0);
  }

  Future<void> _activate() async {
    final i = _index[_tab];
    Channel? channel;
    if (_tab == 0) {
      final recent = _recent;
      if (i < recent.length) channel = recent[i];
    } else {
      final games = _tab == 1 ? _teamGames : _liveGames;
      if (i >= games.length) return;
      channel =
          _matches[SportsChannelPicks.eventKey(games[i])]?.firstOrNull?.channel;
      if (channel == null) {
        setState(() => _message = tr('No channel found for this game'));
        return;
      }
    }
    if (channel == null) return;
    widget.onClose();
    await context.read<PlaybackService>().play(channel);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_index[_tab] > 0) _select(_tab, _index[_tab] - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_index[_tab] < _count - 1) _select(_tab, _index[_tab] + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) _switchTab(_tab - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) _switchTab(_tab + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) unawaited(_activate());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    context.watch<PlaybackService>();
    final epg = context.watch<EpgService>();
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Row(
                  children: [
                    for (var t = 0; t < _tabs.length; t++)
                      Expanded(
                        child: InkWell(
                          canRequestFocus: false,
                          onTap: () => _switchTab(t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: t == _tab ? accent : Colors.white24,
                                  width: t == _tab ? 3 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              tr(_tabs[t]),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t == _tab ? accent : Colors.white70,
                                fontSize: 14,
                                fontWeight: t == _tab
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildList(accent, epg)),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(_message!,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 13)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  tr('◀ ▶ tabs  ·  OK to watch  ·  Back to close'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
      );

  Widget _buildList(Color accent, EpgService epg) {
    if (_tab == 0) {
      final recent = _recent;
      if (recent.isEmpty) {
        return _empty(tr('No other live channels watched yet this session.'));
      }
      return _list(recent.length, accent, (i) {
        final c = recent[i];
        return Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: c.logoUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.tv, color: Colors.white54))
                  : const Icon(Icons.tv, color: Colors.white54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _twoLines(
                  c.name, epg.getCurrentProgram(c.epgId)?.title ?? ''),
            ),
          ],
        );
      });
    }
    if (_sportsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final games = _tab == 1 ? _teamGames : _liveGames;
    if (games.isEmpty) {
      return _empty(_tab == 1
          ? (_hasFollows
              ? tr('None of your teams play today.')
              : tr('Follow teams from Sports > Standings to see them here.'))
          : tr('No games from your leagues are live right now.'));
    }
    return _list(games.length, accent, (i) => _gameRow(games[i]));
  }

  Widget _list(int count, Color accent, Widget Function(int i) row) =>
      ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: count,
        itemExtent: _rowHeight,
        itemBuilder: (context, i) {
          final selected = i == _index[_tab];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: InkWell(
              canRequestFocus: false,
              onTap: () {
                _select(_tab, i);
                unawaited(_activate());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Color.lerp(Colors.black, accent, 0.25)
                      : Colors.transparent,
                  border: Border.all(
                      color: selected ? accent : Colors.transparent, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: row(i),
              ),
            ),
          );
        },
      );

  Widget _twoLines(String top, String bottom) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          if (bottom.isNotEmpty)
            Text(bottom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      );

  Widget _gameRow(SportsGame g) {
    final status = switch (g.state) {
      GameState.pre => DateFormat.jm().format(g.start.toLocal()),
      _ => trSports(g.statusText),
    };
    final showScore =
        !_hideScores && g.state != GameState.pre && !g.league.isField;
    final title = g.league.isField
        ? g.title
        : showScore
            ? '${g.first.abbreviation} ${g.first.score ?? ''}  -  ${g.second.score ?? ''} ${g.second.abbreviation}'
            : '${g.first.abbreviation} ${tr(g.joiner)} ${g.second.abbreviation}';
    final channel =
        _matches[SportsChannelPicks.eventKey(g)]?.firstOrNull?.channel;
    final sub = [
      g.league.shortName,
      status,
      if (channel != null) channel.name,
    ].join('  ·  ');
    return Row(
      children: [
        if (g.league.isField)
          SportsLogo(
              url: g.league.logoUrl, size: 32, fallback: g.league.shortName)
        else ...[
          SportsLogo(
              url: g.first.logoUrl,
              size: 28,
              fallback: g.first.abbreviation,
              color: g.first.color),
          const SizedBox(width: 2),
          SportsLogo(
              url: g.second.logoUrl,
              size: 28,
              fallback: g.second.abbreviation,
              color: g.second.color),
        ],
        const SizedBox(width: 10),
        if (g.state == GameState.live) ...[
          const Icon(Icons.circle, color: Colors.redAccent, size: 8),
          const SizedBox(width: 6),
        ],
        Expanded(child: _twoLines(title, sub)),
      ],
    );
  }
}
