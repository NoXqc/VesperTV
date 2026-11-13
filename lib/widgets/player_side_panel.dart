import '../utils/refined_finish.dart';
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
import '../services/sports_channel_library.dart';
import '../services/sports_channel_matcher.dart';
import '../services/sports_follows.dart';
import '../services/sports_service.dart';
import '../services/storage_service.dart';
import '../screens/sports_live_list_screen.dart';
import 'hold_to_activate.dart';
import 'sports_widgets.dart';

/// Left on the remote in the fullscreen live player: a see-through panel
/// over the left of the picture with up to four tabs — This game (the
/// other sources of the game on the playing channel, only while one is
/// found), Last channels, My Teams (today's games of followed teams) and
/// Live now (games playing right now in the viewer's active leagues). OK
/// plays the channel / the game's best matched channel in place; holding
/// OK on a game "pulls" its stats over the stream (see-through
/// [SportsGameDetailsDialog], Back returns here); Back closes it (handled
/// by PlayerScreen's PopScope).
///
/// Keys are dispatched explicitly (Left/Right = tabs, Up/Down = rows) from
/// one Focus node, with the selected row only drawn highlighted — no focus
/// node per row, so default traversal never gets a say (CLAUDE.md §10).
/// Its width stays [width]: the pulled stats open to its right.
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

enum _PanelTab { game, recent, teams, live }

/// The game on the playing channel and its sources (best first).
class _PlayingGame {
  _PlayingGame(this.channelId, this.game, this.sources) : at = DateTime.now();
  final String channelId;
  final SportsGame game;
  final List<ChannelMatch> sources;
  final DateTime at;
}

class _PlayerSidePanelState extends State<PlayerSidePanel> {
  static const double _rowHeight = 64;

  /// Reopening lands on the tab used last (for the app session); a found
  /// game opens This game instead, until the viewer moves.
  static _PanelTab _lastTab = _PanelTab.recent;

  /// The last open's game, shown at once when the panel reopens on the same
  /// channel (the sports load + match takes a moment), then refreshed.
  static _PlayingGame? _lastPlaying;

  final FocusNode _focus = FocusNode(debugLabel: 'player-side-panel');
  final ScrollController _scroll = ScrollController();
  late _PanelTab _tab = _lastTab;
  final Map<_PanelTab, int> _index = {for (final t in _PanelTab.values) t: 0};

  /// A key or tap in this panel: a game found later no longer moves it.
  bool _moved = false;

  List<SportsGame> _teamGames = const [];
  List<SportsGame> _liveGames = const [];
  Map<String, List<ChannelMatch>> _matches = const {};
  _PlayingGame? _playing;
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
    final cached = _lastPlaying;
    if (cached != null &&
        cached.channelId == widget.current.id &&
        DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
      _showPlaying(cached);
    }
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

  /// Tabs on screen, in order: This game only while a game is found.
  List<_PanelTab> get _tabs => [
        if (_playing != null) _PanelTab.game,
        _PanelTab.recent,
        _PanelTab.teams,
        _PanelTab.live,
      ];

  /// The tab drawn: This game falls back to Last channels without a game.
  _PanelTab get _shown =>
      _tab == _PanelTab.game && _playing == null ? _PanelTab.recent : _tab;

  static String _label(_PanelTab t) => switch (t) {
        _PanelTab.game => tr('This game'),
        _PanelTab.recent => tr('Last channels'),
        _PanelTab.teams => tr('My Teams'),
        _PanelTab.live => tr('Live now'),
      };

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

  int get _count => switch (_shown) {
        _PanelTab.game => _playing?.sources.length ?? 0,
        _PanelTab.recent => _recent.length,
        _PanelTab.teams => _teamGames.length,
        _PanelTab.live => _liveGames.length,
      };

  /// The selected row's game (null on Last channels / past the end).
  SportsGame? get _selectedGame {
    final tab = _shown;
    if (tab == _PanelTab.game) return _playing?.game;
    if (tab == _PanelTab.recent) return null;
    final games = tab == _PanelTab.teams ? _teamGames : _liveGames;
    final i = _index[tab]!;
    return i < games.length ? games[i] : null;
  }

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
    // Games the playing channel may be showing: live, or starting within
    // 30 min (the pre-game show), in any of the viewer's leagues.
    final now = DateTime.now();
    final nearby = [
      for (final g in games)
        if (g.state == GameState.live ||
            (g.state == GameState.pre &&
                g.start.difference(now) < const Duration(minutes: 30)))
          g,
    ];
    setState(() {
      _teamGames = team;
      _liveGames = live;
      _hasFollows = !follows.isEmpty;
      _hideScores = storage.getSportsHideScores();
      _sportsLoading = false;
      for (final t in [_PanelTab.teams, _PanelTab.live]) {
        final n = t == _PanelTab.teams ? team.length : live.length;
        if (_index[t]! >= n) _index[t] = n == 0 ? 0 : n - 1;
      }
    });

    final playlist = context.read<PlaylistManager>();
    final matcher = SportsChannelMatcher.shared(context.read<EpgService>());
    await playlist.ensureLiveChannelsLoaded();
    if (!mounted) return;
    final channels = playlist.visibleChannels(category: 'tv');
    await matcher.prepare(channels, hidden: playlist.hiddenLiveChannels());
    if (!mounted) return;
    final picks = SportsChannelPicks.load(storage);
    final wanted = {...team, ...live, ...nearby}.toList();
    final matches = await matcher.matchDay(wanted, picks);
    if (!mounted) return;
    // The same sources, in the same order, as Sports Trak's cards.
    SportsChannelLists(storage)
        .mergeAddedSources(wanted, matches, channels, picks);
    final found = gameOnChannel(widget.current, nearby, matches);
    setState(() {
      _matches = matches;
      if (found == null) {
        _playing = null;
        _lastPlaying = null;
      } else {
        _showPlaying(
            _PlayingGame(widget.current.id, found.game, found.sources));
      }
    });
  }

  /// Shows [p] under This game; opens that tab (on the playing source)
  /// unless the viewer already moved in the panel.
  void _showPlaying(_PlayingGame p) {
    _playing = p;
    _lastPlaying = p;
    final n = p.sources.length;
    if (!_moved) {
      final at = p.sources.indexWhere((m) => m.channel.id == p.channelId);
      _tab = _PanelTab.game;
      _index[_PanelTab.game] = at < 0 ? 0 : at;
      _reveal();
    } else if (_index[_PanelTab.game]! >= n) {
      _index[_PanelTab.game] = n == 0 ? 0 : n - 1;
    }
  }

  void _select(_PanelTab tab, int index) {
    setState(() {
      _moved = true;
      _tab = tab;
      _lastTab = tab;
      _index[tab] = index;
      _message = null;
    });
    _reveal();
  }

  /// Keeps the selected row on screen — jumpTo, never animateTo (§10).
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final pos = _scroll.position;
      final top = _index[_shown]! * _rowHeight;
      if (top < pos.pixels) {
        _scroll.jumpTo(top);
      } else if (top + _rowHeight > pos.pixels + pos.viewportDimension) {
        _scroll.jumpTo((top + _rowHeight - pos.viewportDimension)
            .clamp(0.0, pos.maxScrollExtent));
      }
    });
  }

  void _switchTab(_PanelTab tab) {
    if (tab == _shown) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    // This game keeps its row (the playing source at first).
    _select(tab, tab == _PanelTab.game ? _index[tab]! : 0);
  }

  void _stepTab(int delta) {
    final tabs = _tabs;
    final next = tabs.indexOf(_shown) + delta;
    if (next >= 0 && next < tabs.length) _switchTab(tabs[next]);
  }

  Future<void> _activate() async {
    final tab = _shown;
    final i = _index[tab]!;
    Channel? channel;
    if (tab == _PanelTab.game) {
      final p = _playing;
      if (p == null || i >= p.sources.length) return;
      channel = p.sources[i].channel;
      if (channel.id == widget.current.id) {
        widget.onClose();
        return;
      }
      // Like Sports Trak: watching another listed source makes it this
      // game's pick (the card shows it next time).
      if (channel.id != p.sources.first.channel.id) {
        unawaited(SportsChannelPicks.load(context.read<StorageService>())
            .pickForGame(p.game, channel.id));
      }
    } else if (tab == _PanelTab.recent) {
      final recent = _recent;
      if (i < recent.length) channel = recent[i];
    } else {
      final game = _selectedGame;
      if (game == null) return;
      channel =
          _matches[SportsChannelPicks.eventKey(game)]?.firstOrNull?.channel;
      if (channel == null) {
        final why = SportsChannelMatcher.sharedWhyNoMatch(game);
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
    final g = _selectedGame;
    if (g == null) return;
    final onGame = _shown == _PanelTab.game;
    final sources = onGame
        ? _playing!.sources
        : _matches[SportsChannelPicks.eventKey(g)] ?? const <ChannelMatch>[];
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
          matches: sources,
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
    // Another source of the playing game becomes its pick, like OK.
    if (onGame &&
        channel.id != widget.current.id &&
        channel.id != sources.first.channel.id) {
      unawaited(SportsChannelPicks.load(context.read<StorageService>())
          .pickForGame(g, channel.id));
    }
    widget.onClose();
    if (channel.id != widget.current.id) await _play(channel);
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
    _moved = true;
    if (_shown == _PanelTab.recent) {
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
    final tab = _shown;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_index[tab]! > 0) _select(tab, _index[tab]! - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_index[tab]! < _count - 1) _select(tab, _index[tab]! + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) _stepTab(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) _stepTab(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    context.watch<PlaybackService>();
    final epg = context.watch<EpgService>();
    final shown = _shown;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Material(
        color: RefinedFinish.surface(
            context, Colors.black.withValues(alpha: 0.62)),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Row(
                  children: [
                    for (final t in _tabs)
                      Expanded(
                        child: InkWell(
                          canRequestFocus: false,
                          onTap: () => _switchTab(t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 2),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: t == shown ? accent : Colors.white24,
                                  width: t == shown ? 3 : 1,
                                ),
                              ),
                            ),
                            // Four tabs share the same width as three did
                            // (the stats open to the panel's right): a long
                            // label shrinks instead of being cut.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _label(t),
                                maxLines: 1,
                                style: TextStyle(
                                  color: t == shown ? accent : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: t == shown
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
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
                  shown == _PanelTab.recent
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

  Widget _channelLogo(Channel c) => SizedBox(
        width: 36,
        height: 36,
        child: (c.logoUrl != null && c.logoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: c.logoUrl!,
                fit: BoxFit.contain,
                // A small logo: decoded small, not at the file's size (CLAUDE.md §10 (6)).
                memCacheWidth: 160,
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.tv, color: Colors.white54))
            : const Icon(Icons.tv, color: Colors.white54),
      );

  Widget _buildList(Color accent, EpgService epg) {
    final tab = _shown;
    if (tab == _PanelTab.game) return _buildGame(_playing!, accent, epg);
    if (tab == _PanelTab.recent) {
      final recent = _recent;
      if (recent.isEmpty) {
        return _empty(tr('No other live channels watched yet this session.'));
      }
      return _list(recent.length, accent, (i) {
        final c = recent[i];
        return Row(
          children: [
            _channelLogo(c),
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
    final games = tab == _PanelTab.teams ? _teamGames : _liveGames;
    if (games.isEmpty) {
      return _empty(tab == _PanelTab.teams
          ? (_hasFollows
              ? tr('None of your teams play today.')
              : tr('Follow teams from {tab} > Standings to see them here.',
                  {'tab': AppConstants.sportsTabName}))
          : tr('No games from your leagues are live right now.'));
    }
    return _list(games.length, accent, (i) => _gameRow(games[i]));
  }

  /// This game: the game (not a row) above its sources, the playing one
  /// tagged. Same width as the other tabs.
  Widget _buildGame(_PlayingGame p, Color accent, EpgService epg) {
    final playlists = context.read<PlaylistManager>();
    // Two providers' TSN 1 look alike: name the playlist when they differ.
    final mixed = p.sources.map((m) => m.channel.playlistId).toSet().length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _rowHeight,
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: _gameRow(p.game, withChannel: false),
        ),
        Expanded(
          child: _list(p.sources.length, accent, (i) {
            final m = p.sources[i];
            final c = m.channel;
            final program = epg.getCurrentProgram(c.epgId)?.title ?? '';
            final why = m.detail == null || m.reason == MatchReason.name
                ? m.reason.label
                : '${m.reason.label} · ${m.detail}';
            final sub = [
              if (mixed) playlists.playlistNameFor(c.playlistId).trim(),
              program.isNotEmpty ? program : why,
            ].where((s) => s.isNotEmpty).join('  ·  ');
            return Row(
              children: [
                _channelLogo(c),
                const SizedBox(width: 12),
                Expanded(child: _twoLines(c.name, sub)),
                if (c.id == widget.current.id) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: accent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tr('Watching').toUpperCase(),
                        style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            );
          }),
        ),
        if (p.sources.length == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(tr('No other source found for this game.'),
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _list(int count, Color accent, Widget Function(int i) row) =>
      ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: count,
        itemExtent: _rowHeight,
        itemBuilder: (context, i) {
          final tab = _shown;
          final selected = i == _index[tab];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: InkWell(
              canRequestFocus: false,
              onTap: () {
                _select(tab, i);
                unawaited(_activate());
              },
              onLongPress: tab == _PanelTab.recent
                  ? null
                  : () {
                      _select(tab, i);
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

  /// [withChannel]: the second line names the game's best channel (not in
  /// This game's header, its sources are listed under it).
  Widget _gameRow(SportsGame g, {bool withChannel = true}) {
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
    final channel = withChannel
        ? _matches[SportsChannelPicks.eventKey(g)]?.firstOrNull?.channel
        : null;
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
          decoration: RefinedFinish.decorate(
              context,
              BoxDecoration(
                color: RefinedFinish.surface(
                    context, Colors.black.withValues(alpha: 0.62)),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(24)),
                border: Border.all(color: Colors.white24),
              )),
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
