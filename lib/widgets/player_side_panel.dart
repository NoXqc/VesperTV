import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../utils/constants.dart';
import '../utils/time_format.dart';
import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/sports.dart';
import '../services/epg_service.dart';
import '../services/app_preferences.dart';
import '../services/playback_service.dart';
import '../services/playlist_manager.dart';
import '../services/sports_channel_matcher.dart';
import '../services/sports_follows.dart';
import '../services/sports_service.dart';
import '../services/storage_service.dart';
import '../screens/sports_live_list_screen.dart';
import 'hold_to_activate.dart';
import 'sports_widgets.dart';

/// Left on the remote in the fullscreen live player: a see-through panel
/// over the left of the picture with three tabs — Last channels, My Teams
/// (today's games of followed teams) and Live now (games playing right now
/// in the viewer's active leagues). OK plays the channel / the game's best
/// matched channel in place; holding OK on a game "pulls" its stats over the
/// stream (see-through [SportsGameDetailsDialog], Back returns here); Back
/// closes it (handled by PlayerScreen's PopScope).
///
/// Keys are dispatched explicitly (Left/Right = tabs, Up/Down = rows) from
/// one Focus node, with the selected row only drawn highlighted — no focus
/// node per row, so default traversal never gets a say (CLAUDE.md §10).
class PlayerSidePanel extends StatefulWidget {
  const PlayerSidePanel(
      {super.key, required this.current, required this.onClose, this.onPlay});

  final Channel current;
  final VoidCallback onClose;

  /// Plays a picked channel. Null = [PlaybackService.play] (Android);
  /// Windows passes its own player's switch (DesktopPlayerScreen).
  final Future<void> Function(Channel)? onPlay;

  static const double width = 400;

  @override
  State<PlayerSidePanel> createState() => _PlayerSidePanelState();
}

class _PlayerSidePanelState extends State<PlayerSidePanel> {
  static const _tabs = ['Last channels', 'My Teams', 'Live now'];
  static const double _rowHeight = 64;

  /// Reopening lands on the tab used last (for the app session).
  static int _lastTab = 0;

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

  /// Hold OK on a game row (see [_onKey]): like [HoldToActivate], a hold
  /// needs the remote's own key repeats, not just time — a late key-up
  /// after a click on a busy box has none — so it fires from a repeat.
  bool _selectDown = false;
  bool _holdFired = false;
  final Stopwatch _held = Stopwatch();
  static const _holdDuration = Duration(milliseconds: 550);

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
      if (!c.isLive || !seen.add(c.id)) continue;
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
    // The favourite league's games first, then My Teams' games, each
    // keeping the start order.
    final favoriteId = favoriteSportsLeague(storage)?.id;
    int rank(SportsGame g) =>
        (g.league.id == favoriteId ? 0 : 2) + (follows.involves(g) ? 0 : 1);
    final live = [
      for (var r = 0; r < 4; r++)
        ...games.where((g) =>
            g.state == GameState.live &&
            savedIds.contains(g.league.id) &&
            rank(g) == r),
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
    final matcher = SportsChannelMatcher.shared(context.read<EpgService>());
    await playlist.ensureLiveChannelsLoaded();
    if (!mounted) return;
    await matcher.prepare(playlist.visibleChannels(category: 'tv'),
        hidden: playlist.hiddenLiveChannels());
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
        final why = SportsChannelMatcher.sharedWhyNoMatch(games[i]);
        setState(() =>
            _message = why?.reason ?? tr('No channel found for this game'));
        return;
      }
    }
    if (channel == null) return;
    widget.onClose();
    await _play(channel);
  }

  /// Hold OK on a game: its box score / stats over the stream, see-through.
  /// Watch on a channel there plays it like OK does.
  Future<void> _openStats() async {
    if (_tab == 0) return;
    final games = _tab == 1 ? _teamGames : _liveGames;
    final i = _index[_tab];
    if (i >= games.length) return;
    final g = games[i];
    final size = MediaQuery.sizeOf(context);
    final channel = await showDialog<Channel>(
      context: context,
      barrierColor: Colors.transparent,
      // Landscape phone: the dialog places itself around the notch (see
      // SportsGameDetailsDialog.build); the default SafeArea pushed it off
      // the panel's edge.
      useSafeArea: context.read<AppPreferences>().isTelevision ||
          size.width <= size.height,
      // Opened by a hold: drop the held OK's repeats.
      builder: (_) => SwallowHeldActivate(
        child: SportsGameDetailsDialog(
          game: g,
          matches: _matches[SportsChannelPicks.eventKey(g)] ?? const [],
          hideScores: _hideScores,
          overStream: true,
        ),
      ),
    );
    if (!mounted) return;
    if (channel == null) {
      _focus.requestFocus();
      return;
    }
    widget.onClose();
    await _play(channel);
  }

  Future<void> _play(Channel channel) {
    final play = widget.onPlay;
    return play != null
        ? play(channel)
        : context.read<PlaybackService>().play(channel);
  }

  static bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  /// OK on a game tab: tap = watch (on key-up), hold = stats. Last
  /// channels has no hold, so it plays on key-down as before.
  KeyEventResult _onSelectKey(KeyEvent event) {
    if (_tab == 0) {
      if (event is KeyDownEvent) unawaited(_activate());
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      _selectDown = true;
      _holdFired = false;
      _held
        ..reset()
        ..start();
    } else if (event is KeyRepeatEvent) {
      if (_selectDown && !_holdFired && _held.elapsed >= _holdDuration) {
        _holdFired = true;
        unawaited(_openStats());
      }
    } else if (event is KeyUpEvent) {
      // Only a press that started here (an orphaned key-up is ignored).
      final tap = _selectDown && !_holdFired;
      _selectDown = false;
      _held.stop();
      if (tap) unawaited(_activate());
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_isSelect(event.logicalKey)) return _onSelectKey(event);
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Windows keyboard: Esc closes, like Back on a remote.
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
      return KeyEventResult.handled;
    }
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
                  _tab == 0
                      ? tr('◀ ▶ tabs  ·  OK to watch  ·  Back to close')
                      : tr(
                          '◀ ▶ tabs  ·  OK to watch  ·  Hold OK for stats  ·  Back to close'),
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
              : tr('Follow teams from {tab} > Standings to see them here.',
                  {'tab': AppConstants.sportsTabName}))
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
              onLongPress: _tab == 0
                  ? null
                  : () {
                      _select(_tab, i);
                      unawaited(_openStats());
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

  /// [topSpans]: styled pieces of the first line (a game's coloured
  /// scores) in place of plain [top].
  Widget _twoLines(String top, String bottom, {List<InlineSpan>? topSpans}) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
              TextSpan(text: topSpans == null ? top : null, children: topSpans),
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
      GameState.pre => TimeFormat.hm.format(g.start.toLocal()),
      _ => trSports(g.statusText),
    };
    final showScore =
        !_hideScores && g.state != GameState.pre && !g.isEventOnly;
    final title = g.isEventOnly
        ? g.title
        : showScore
            ? '${g.first.abbreviation} ${g.first.score ?? ''}  -  ${g.second.score ?? ''} ${g.second.abbreviation}'
            : '${g.first.abbreviation} ${tr(g.joiner)} ${g.second.abbreviation}';
    // Scores in the palette accent so they stand out (owner, 2026-10-18).
    final scoreStyle = TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800);
    final channel =
        _matches[SportsChannelPicks.eventKey(g)]?.firstOrNull?.channel;
    final sub = [
      g.league.shortName,
      status,
      if (channel != null) channel.name,
    ].join('  ·  ');
    // Each team's score small under its logo (owner, 2026-10-18).
    Widget team(SportsTeam t) => SizedBox(
          width: 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SportsLogo(
                  url: t.logoUrl,
                  size: 28,
                  fallback: t.abbreviation,
                  color: t.color),
              if (showScore)
                Text(t.score ?? '',
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
            ],
          ),
        );
    return Row(
      children: [
        if (g.isEventOnly)
          SportsLogo(
              url: g.league.logoUrl, size: 32, fallback: g.league.shortName)
        else ...[
          team(g.first),
          const SizedBox(width: 2),
          team(g.second),
        ],
        const SizedBox(width: 10),
        if (g.state == GameState.live) ...[
          const Icon(Icons.circle, color: Colors.redAccent, size: 8),
          const SizedBox(width: 6),
        ],
        Expanded(
            child: _twoLines(title, sub,
                topSpans: showScore
                    ? [
                        TextSpan(text: '${g.first.abbreviation} '),
                        TextSpan(text: g.first.score ?? '', style: scoreStyle),
                        const TextSpan(text: '  -  '),
                        TextSpan(text: g.second.score ?? '', style: scoreStyle),
                        TextSpan(text: ' ${g.second.abbreviation}'),
                      ]
                    : null)),
      ],
    );
  }
}

/// Touch and mouse: the floating tab on the left edge of a fullscreen
/// player that opens [PlayerSidePanel] (a remote uses Left), shown with
/// the player bars. Phone (PlayerScreen) and Windows (DesktopPlayerScreen).
class PlayerSidePanelTab extends StatelessWidget {
  const PlayerSidePanelTab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 18, 10, 18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(24)),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_list_rounded, color: scheme.primary, size: 24),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
