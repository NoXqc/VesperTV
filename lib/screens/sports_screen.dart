import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/channel.dart';
import '../models/sports.dart';
import '../services/desktop_mini_player.dart';
import '../services/epg_service.dart';
import '../services/playback_service.dart';
import '../services/playlist_manager.dart';
import '../services/sports_channel_matcher.dart';
import '../services/sports_follows.dart';
import '../services/sports_service.dart';
import '../services/storage_service.dart';
import '../utils/route_observer.dart';
import '../utils/tv_theme.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/live_resume_hint.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/sports_widgets.dart';
import '../widgets/tv_menu_tile.dart';
import 'desktop_player_screen.dart';
import 'player_screen.dart';
import 'sports_my_teams_screen.dart';
import 'sports_standings_screen.dart';

/// Sports: today's games across the user's leagues with logos, records,
/// live scores and the IPTV channel each game is on (see
/// [SportsChannelMatcher] for how channels are found). Select a game for its
/// channels; when none was found — or the wrong one — the user picks it once
/// and can have it remembered for that team.
///
/// D-pad layout, top to bottom: league chips, day strip, then one horizontal
/// row per section (Live now / Later / Final). Up/Down move between those
/// zones explicitly (CLAUDE.md §10: default traversal across differently
/// shaped rows is unreliable); Left/Right is plain traversal inside a row.
class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _Section {
  _Section(this.id, this.label, this.games);
  final String id;
  final String label;
  final List<SportsGame> games;
}

class _SportsScreenState extends State<SportsScreen> with RouteAware {
  late final StorageService _storage;
  late final SportsChannelMatcher _matcher;
  late SportsChannelPicks _picks;
  late SportsFollows _follows;

  late List<SportsLeague> _leagues;
  String? _leagueFilter;
  int _dayOffset = 0;
  bool _hideScores = false;

  List<SportsGame> _games = const [];
  Map<String, List<ChannelMatch>> _matches = const {};
  bool _loading = true;
  bool _matching = false;
  String? _error;
  int _loadToken = 0;

  SportsGame? _heroGame;
  Timer? _pollTimer;
  bool _covered = false;

  /// The "Hold > to resume" pill covered the cards and Standings' table;
  /// hidden for as long as Sports (and anything pushed over it) is open.
  late final VoidCallback _showResumeHint;

  // Focus bookkeeping — see the class doc for the zone model.
  // Zones: 0 league chips, 1 day chips, 2 Standings button, 3+ game rows.
  static const _firstRowZone = 3;
  int _zone = _firstRowZone;
  final Map<String, FocusNode> _chipNodes = {};
  final Map<String, FocusNode> _cardNodes = {};
  final Map<String, String> _lastCardInRow = {};
  final Map<String, GlobalKey> _rowKeys = {};
  bool _initialFocusDone = false;

  @override
  void initState() {
    super.initState();
    _showResumeHint = LiveResumeHint.hideWhileMounted();
    _storage = context.read<StorageService>();
    _matcher = SportsChannelMatcher(context.read<EpgService>());
    _picks = SportsChannelPicks.load(_storage);
    _follows = SportsFollows.load(_storage);
    final saved = _storage.getSportsLeagues();
    _leagues = [
      for (final id in saved ?? kDefaultSportsLeagueIds)
        if (sportsLeagueById(id) != null) sportsLeagueById(id)!,
    ];
    if (_leagues.isEmpty) {
      _leagues = [
        for (final id in kDefaultSportsLeagueIds) sportsLeagueById(id)!
      ];
    }
    _hideScores = _storage.getSportsHideScores();
    unawaited(_load());
    // Live scores tick while the screen is visible; SportsService's own
    // freshness window decides whether a tick actually hits the network.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_covered && mounted) unawaited(_load(silent: true));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _covered = true;

  @override
  void didPopNext() {
    _covered = false;
    unawaited(_load(silent: true));
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _showResumeHint();
    _pollTimer?.cancel();
    for (final n in _chipNodes.values) {
      n.dispose();
    }
    for (final n in _cardNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  DateTime get _day {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(Duration(days: _dayOffset));
  }

  List<SportsLeague> get _shownLeagues => _leagueFilter == null
      ? _leagues
      : _leagues.where((l) => l.id == _leagueFilter).toList();

  Future<void> _load({bool silent = false}) async {
    final token = ++_loadToken;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final games = await SportsService.instance.gamesForDay(_shownLeagues, _day);
    if (!mounted || token != _loadToken) return;
    setState(() {
      _games = games;
      _loading = false;
      _error = games.isEmpty ? SportsService.instance.lastError : null;
      final heroKey = _heroGame == null ? null : _gameKey(_heroGame!);
      _heroGame = games.where((g) => _gameKey(g) == heroKey).firstOrNull ??
          _defaultHero(games);
    });
    _ensureInitialFocus();
    await _rematch(token);
  }

  Future<void> _rematch([int? token]) async {
    final myToken = token ?? _loadToken;
    setState(() => _matching = true);
    final playlist = context.read<PlaylistManager>();
    await playlist.ensureLiveChannelsLoaded();
    if (!mounted) return;
    await _matcher.prepare(playlist.visibleChannels(category: 'tv'));
    final matches = await _matcher.matchDay(_games, _picks);
    if (!mounted || myToken != _loadToken) return;
    setState(() {
      _matches = matches;
      _matching = false;
    });
  }

  static String _gameKey(SportsGame g) => SportsChannelPicks.eventKey(g);

  SportsGame? _defaultHero(List<SportsGame> games) {
    if (games.isEmpty) return null;
    return games.where((g) => g.state == GameState.live).firstOrNull ??
        games.where((g) => g.state == GameState.pre).firstOrNull ??
        games.first;
  }

  List<_Section> get _sections {
    // My Teams' games first (stable: start order kept within each half).
    List<SportsGame> followedFirst(Iterable<SportsGame> games) => [
          ...games.where(_follows.involves),
          ...games.where((g) => !_follows.involves(g)),
        ];
    final live = followedFirst(_games.where((g) => g.state == GameState.live));
    final pre = followedFirst(_games.where((g) => g.state == GameState.pre));
    final post = _games.where((g) => g.state == GameState.post).toList();
    final laterLabel = switch (_dayOffset) {
      0 => 'Later today',
      1 => 'Tomorrow',
      _ when _dayOffset < 0 => 'Not played',
      _ => 'Scheduled',
    };
    return [
      if (live.isNotEmpty) _Section('live', 'Live now', live),
      if (pre.isNotEmpty) _Section('pre', laterLabel, pre),
      if (post.isNotEmpty) _Section('post', 'Final', post),
    ];
  }

  // ---------------------------------------------------------------- focus

  FocusNode _chipNode(String id) =>
      _chipNodes[id] ??= FocusNode(debugLabel: 'sports-chip-$id');

  FocusNode _cardNode(String key) =>
      _cardNodes[key] ??= FocusNode(debugLabel: 'sports-card-$key');

  String get _leagueChipId => 'league:${_leagueFilter ?? 'all'}';
  String get _dayChipId => 'day:$_dayOffset';

  void _ensureInitialFocus() {
    if (_initialFocusDone) return;
    _initialFocusDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sections = _sections;
      if (sections.isNotEmpty) {
        _focusZone(_firstRowZone, sections);
      } else {
        _chipNode(_dayChipId).requestFocus();
      }
    });
  }

  void _focusZone(int zone, List<_Section> sections) {
    if (zone == 0) {
      _chipNode(_leagueChipId).requestFocus();
    } else if (zone == 1) {
      _chipNode(_dayChipId).requestFocus();
    } else if (zone == 2) {
      _chipNode('standings').requestFocus();
    } else {
      final s = sections[zone - _firstRowZone];
      final remembered = _lastCardInRow[s.id];
      final key = s.games.any((g) => _gameKey(g) == remembered)
          ? remembered!
          : _gameKey(s.games.first);
      _cardNode(key).requestFocus();
    }
    _zone = zone;
  }

  void _moveZone(int delta) {
    final sections = _sections;
    final target = _zone + delta;
    if (target < 0 || target >= _firstRowZone + sections.length) return;
    _focusZone(target, sections);
  }

  void _ensureRowVisible(String sectionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[sectionId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: 0.05);
      }
    });
  }

  // -------------------------------------------------------------- actions

  void _setLeagueFilter(String? id) {
    if (_leagueFilter == id) return;
    setState(() => _leagueFilter = id);
    unawaited(_load());
  }

  void _setDay(int offset) {
    if (_dayOffset == offset) return;
    setState(() {
      _dayOffset = offset;
      _heroGame = null;
    });
    unawaited(_load());
  }

  Future<void> _toggleScores() async {
    setState(() => _hideScores = !_hideScores);
    await _storage.setSportsHideScores(_hideScores);
  }

  Future<void> _editLeagues() async {
    final chosen = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          _EditLeaguesDialog(selected: [for (final l in _leagues) l.id]),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    await _storage.setSportsLeagues(chosen);
    setState(() {
      _leagues = [for (final id in chosen) sportsLeagueById(id)!];
      if (_leagueFilter != null && !chosen.contains(_leagueFilter)) {
        _leagueFilter = null;
      }
    });
    unawaited(_load());
  }

  // ------------------------------------------------------- league reorder

  /// League chip in "move" mode (hold OK on it), or null. Same model as the
  /// TV groups column's `_movingGroupKey`: focus stays on the chip,
  /// Left/Right move it, OK or Back is "done". Saved on every step.
  String? _movingLeague;

  void _tapLeague(String id) {
    if (_movingLeague != null) {
      _endLeagueMove();
    } else {
      _setLeagueFilter(id);
    }
  }

  void _startLeagueMove(String id) => setState(() => _movingLeague = id);

  void _endLeagueMove() {
    if (_movingLeague == null) return;
    setState(() => _movingLeague = null);
  }

  void _moveLeague(int delta) {
    final id = _movingLeague;
    if (id == null) return;
    final from = _leagues.indexWhere((l) => l.id == id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= _leagues.length) return;
    setState(() {
      final l = _leagues.removeAt(from);
      _leagues.insert(to, l);
    });
    unawaited(_storage.setSportsLeagues([for (final l in _leagues) l.id]));
    // The chip keeps its node (keyed by league id) and focus; just keep it on
    // screen. Zero duration = jump (CLAUDE.md §10).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chipNode('league:$id').context;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx);
    });
  }

  Future<void> _openStandings() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SportsStandingsScreen(
        leagues: _leagues,
        initialLeague: sportsLeagueById(_leagueFilter ?? '') ?? _leagues.first,
        follows: _follows,
      ),
    ));
  }

  Future<void> _openMyTeams() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SportsMyTeamsScreen(
        leagues: _leagues,
        follows: _follows,
        hideScores: _hideScores,
        matchGames: _matchGames,
        onActivate: _activateGame,
        onMenu: _openGame,
      ),
    ));
  }

  /// Channel matches for games outside the day being shown (My Teams).
  Future<Map<String, List<ChannelMatch>>> _matchGames(
      List<SportsGame> games) async {
    final playlist = context.read<PlaylistManager>();
    await playlist.ensureLiveChannelsLoaded();
    await _matcher.prepare(playlist.visibleChannels(category: 'tv'));
    return _matcher.matchDay(games, _picks);
  }

  /// OK on a card: straight to the stream when a channel is matched (your
  /// pick ranks first), otherwise the menu so one can be picked. Holding OK
  /// always opens the menu (other channels / pick / forget) — owner: OK
  /// popping the menu even with a channel assigned was one press too many.
  /// [matches] = My Teams' own (its games aren't all on the shown day).
  Future<void> _activateGame(SportsGame game,
      [List<ChannelMatch>? matches]) async {
    final best = (matches ?? _matches[_gameKey(game)])?.firstOrNull;
    if (best == null) return _openGame(game, matches);
    await _play(best.channel);
  }

  Future<void> _openGame(SportsGame game,
      [List<ChannelMatch>? gameMatches]) async {
    final matches =
        gameMatches ?? _matches[_gameKey(game)] ?? const <ChannelMatch>[];
    final result = await showDialog<_GameAction>(
      context: context,
      // Opened by a hold too: drop the held OK's repeats (see the widget).
      builder: (_) => SwallowHeldActivate(
          child: _GameDialog(
        game: game,
        matches: matches,
        matching: gameMatches == null && _matching,
        hideScores: _hideScores,
        hasPick: _picks.channelIdFor(game) != null,
      )),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case _WatchAction(:final channel):
        await _play(channel);
      case _PickAction():
        await _pickChannel(game);
      case _ForgetPickAction():
        await _picks.clearFor(game);
        await _rematch();
    }
  }

  Future<void> _pickChannel(SportsGame game) async {
    final channel = await Navigator.of(context).push<Channel>(
      MaterialPageRoute(
        builder: (_) => _ChannelPickerScreen(game: game, matcher: _matcher),
      ),
    );
    if (channel == null || !mounted) return;
    final scope = await showDialog<_PickScope>(
      context: context,
      builder: (_) => _PickScopeDialog(game: game, channel: channel),
    );
    if (scope == null || !mounted) return;
    switch (scope) {
      case _PickScope.game:
        await _picks.pickForGame(game, channel.id);
      case _PickScope.first:
        await _picks.pickForTeam(game, game.first, channel.id);
      case _PickScope.second:
        await _picks.pickForTeam(game, game.second, channel.id);
    }
    await _rematch();
    if (!mounted) return;
    await _play(channel);
  }

  Future<void> _play(Channel channel) async {
    // Same split as SearchScreen._openChannel: Windows has its own player.
    if (Platform.isWindows) {
      DesktopMiniPlayer.instance.clear();
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DesktopPlayerScreen(channel: channel)));
      return;
    }
    await context.read<PlaybackService>().play(channel);
    if (!mounted) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final hero = _heroGame;
    // Back while moving a league chip = "done", not leave Sports.
    return PopScope(
      canPop: _movingLeague == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endLeagueMove();
      },
      child: withTvThemeIfNeeded(
        context,
        (context) => Stack(
          children: [
            const Positioned.fill(child: SettingsGradientBackground()),
            Positioned.fill(child: _TeamGlow(game: hero)),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: CallbackShortcuts(
                  bindings: _movingLeague != null
                      ? {
                          const SingleActivator(LogicalKeyboardKey.arrowLeft):
                              () => _moveLeague(-1),
                          const SingleActivator(LogicalKeyboardKey.arrowRight):
                              () => _moveLeague(1),
                          // Stay on the chip until OK/Back says "done".
                          const SingleActivator(LogicalKeyboardKey.arrowUp):
                              () {},
                          const SingleActivator(LogicalKeyboardKey.arrowDown):
                              () {},
                        }
                      : {
                          const SingleActivator(LogicalKeyboardKey.arrowUp):
                              () => _moveZone(-1),
                          const SingleActivator(LogicalKeyboardKey.arrowDown):
                              () => _moveZone(1),
                        },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeagueBar(),
                        const SizedBox(height: 8),
                        _buildDayBar(),
                        const SizedBox(height: 6),
                        _buildStandingsButton(),
                        const SizedBox(height: 4),
                        if (hero != null)
                          _Hero(
                            game: hero,
                            matches: _matches[_gameKey(hero)],
                            matching: _matching,
                            hideScores: _hideScores,
                          ),
                        Expanded(child: _buildBody(sections)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueBar() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Text('Sports',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 16),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SportsChip(
                  key: const ValueKey('league:all'),
                  focusNode: _chipNode('league:all'),
                  enabled: _movingLeague == null,
                  label: 'All',
                  selected: _leagueFilter == null,
                  onFocus: () => _zone = 0,
                  onTap: () => _setLeagueFilter(null),
                ),
                for (final l in _leagues)
                  HoldToActivate(
                    // Keyed: the list reorders in move mode, and unkeyed chips
                    // swapped focus nodes — focus dropped and stale "focused"
                    // outlines stuck on other chips (owner: three focuses).
                    key: ValueKey('league:${l.id}'),
                    onTap: () => _tapLeague(l.id),
                    onHold: () => _startLeagueMove(l.id),
                    child: SportsChip(
                      focusNode: _chipNode('league:${l.id}'),
                      enabled: _movingLeague == null || _movingLeague == l.id,
                      label: l.name,
                      logoUrl: l.logoUrl,
                      selected: _leagueFilter == l.id,
                      moving: _movingLeague == l.id,
                      onFocus: () => _zone = 0,
                      onTap: () => _tapLeague(l.id),
                    ),
                  ),
                SportsChip(
                  key: const ValueKey('league:edit'),
                  focusNode: _chipNode('league:edit'),
                  enabled: _movingLeague == null,
                  label: 'Edit leagues',
                  icon: Icons.tune,
                  selected: false,
                  onFocus: () => _zone = 0,
                  onTap: _editLeagues,
                ),
                SportsChip(
                  key: const ValueKey('league:scores'),
                  focusNode: _chipNode('league:scores'),
                  enabled: _movingLeague == null,
                  label: _hideScores ? 'Scores hidden' : 'Scores shown',
                  icon: _hideScores ? Icons.visibility_off : Icons.visibility,
                  selected: false,
                  onFocus: () => _zone = 0,
                  onTap: _toggleScores,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar() {
    String label(int offset) {
      if (offset == -1) return 'Yesterday';
      if (offset == 0) return 'Today';
      if (offset == 1) return 'Tomorrow';
      final n = DateTime.now();
      return DateFormat('EEE d')
          .format(DateTime(n.year, n.month, n.day + offset));
    }

    final live = _games.where((g) => g.state == GameState.live).length;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (_dayOffset == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _LiveCount(count: live),
            ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var o = -1; o <= 6; o++)
                  SportsChip(
                    focusNode: _chipNode('day:$o'),
                    label: label(o),
                    selected: _dayOffset == o,
                    compact: true,
                    onFocus: () => _zone = 1,
                    onTap: () => _setDay(o),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Its own centered spot under the day row (was the last chip of the
  /// league bar — owner: hard to find there). Names the filtered league so
  /// it's clear which table opens.
  Widget _buildStandingsButton() {
    final league = sportsLeagueById(_leagueFilter ?? '');
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SportsChip(
            focusNode: _chipNode('standings'),
            label: league == null ? 'Standings' : '${league.name} standings',
            icon: Icons.leaderboard,
            selected: false,
            compact: true,
            onFocus: () => _zone = 2,
            onTap: _openStandings,
          ),
          SportsChip(
            focusNode: _chipNode('myteams'),
            label: 'My Teams',
            icon: Icons.star,
            selected: false,
            compact: true,
            onFocus: () => _zone = 2,
            onTap: _openMyTeams,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<_Section> sections) {
    if (_loading && _games.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_error != null ? Icons.cloud_off : Icons.event_busy,
                size: 44, color: Colors.white38),
            const SizedBox(height: 10),
            Text(_error ?? 'No games on this day for your leagues',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            if (_error == null) ...[
              const SizedBox(height: 4),
              const Text('Try another day, or add leagues with Edit leagues.',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        for (final s in sections) _buildSection(s),
      ],
    );
  }

  Widget _buildSection(_Section s) {
    final rowKey = _rowKeys[s.id] ??= GlobalKey();
    final zoneIndex = _firstRowZone + _sections.indexWhere((x) => x.id == s.id);
    return Padding(
      key: rowKey,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.label,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 8),
              Text('${s.games.length}',
                  style: const TextStyle(fontSize: 15, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _GameCard.height + 18 + _HoldHint.height,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final g in s.games)
                  _GameCard(
                    key: ValueKey('card-${_gameKey(g)}'),
                    focusNode: _cardNode(_gameKey(g)),
                    game: g,
                    match: _matches[_gameKey(g)]?.firstOrNull,
                    matching: _matching,
                    hideScores: _hideScores,
                    starred: _follows.involves(g),
                    onFocus: () {
                      _zone = zoneIndex;
                      _lastCardInRow[s.id] = _gameKey(g);
                      _ensureRowVisible(s.id);
                      if (_heroGame != g) setState(() => _heroGame = g);
                    },
                    onTap: () => _activateGame(g),
                    onHold: () => _openGame(g),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== widgets

String _timeLabel(DateTime utc) => DateFormat.jm().format(utc.toLocal());

/// Soft glow of the focused game's two team colours behind everything —
/// the screen takes on the matchup's identity instead of a flat panel.
class _TeamGlow extends StatelessWidget {
  const _TeamGlow({required this.game});
  final SportsGame? game;

  @override
  Widget build(BuildContext context) {
    final a = sportsTeamColor(game?.first.color) ?? Colors.transparent;
    final b = sportsTeamColor(game?.second.color) ?? Colors.transparent;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        // SizedBox.expand: AnimatedSwitcher lays children out loosely, so
        // a bare DecoratedBox would collapse to zero size.
        child: SizedBox.expand(
          key: ValueKey('${game?.id}'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.topRight,
                colors: [
                  a.withValues(alpha: 0.32),
                  Colors.transparent,
                  b.withValues(alpha: 0.32),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.3, 0.85],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveCount extends StatelessWidget {
  const _LiveCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? Colors.redAccent : Colors.white24,
          ),
        ),
        const SizedBox(width: 6),
        Text('Live now  $count',
            style: TextStyle(
                color: on ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Big summary of the focused game above the rows.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.game,
    required this.matches,
    required this.matching,
    required this.hideScores,
  });

  final SportsGame game;
  final List<ChannelMatch>? matches;
  final bool matching;
  final bool hideScores;

  @override
  Widget build(BuildContext context) {
    final showScore = game.state != GameState.pre && !hideScores;
    return SizedBox(
      height: 168,
      child: Row(
        children: [
          Expanded(child: _side(context, game.first, alignEnd: false)),
          SizedBox(width: 230, child: _center(context, showScore)),
          Expanded(child: _side(context, game.second, alignEnd: true)),
        ],
      ),
    );
  }

  Widget _side(BuildContext context, SportsTeam t, {required bool alignEnd}) {
    final logo = SportsLogo(
        url: t.logoUrl, size: 92, fallback: t.abbreviation, color: t.color);
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(t.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        if (t.record != null)
          Text(t.record!,
              style: const TextStyle(fontSize: 15, color: Colors.white60)),
      ],
    );
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: text), const SizedBox(width: 14), logo]
          : [logo, const SizedBox(width: 14), Flexible(child: text)],
    );
  }

  Widget _center(BuildContext context, bool showScore) {
    final scheme = Theme.of(context).colorScheme;
    final best = matches?.firstOrNull;
    String status;
    Color statusColor = Colors.white70;
    switch (game.state) {
      case GameState.live:
        status = game.statusText.isEmpty ? 'Live' : game.statusText;
        statusColor = Colors.redAccent;
      case GameState.post:
        status = game.statusText.isEmpty ? 'Final' : game.statusText;
      case GameState.pre:
        final until = game.start.difference(DateTime.now().toUtc());
        status = until.inMinutes > 0 && until.inHours < 24
            ? 'Starts in ${until.inHours > 0 ? '${until.inHours}h ' : ''}${until.inMinutes % 60}m'
            : DateFormat('EEE, MMM d').format(game.start.toLocal());
        statusColor = scheme.primary;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(game.league.name.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, letterSpacing: 1.2, color: Colors.white54)),
        const SizedBox(height: 4),
        if (showScore)
          Text('${game.first.score ?? '-'}  -  ${game.second.score ?? '-'}',
              style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white))
        else
          Text(
              game.state == GameState.pre
                  ? _timeLabel(game.start)
                  : game.joiner,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        Text(status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
        const SizedBox(height: 8),
        if (best != null)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.live_tv, size: 15, color: scheme.primary),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(best.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          )
        else
          Text(
              matching
                  ? 'Looking for the channel…'
                  : 'No channel found — OK to pick one',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}

/// Small hint under the focused game card (owner: the floating pill was too
/// big). Only the hold is spelled out — OK-to-watch is obvious. Its height is
/// always reserved in the row so focus moves don't shift the layout.
class _HoldHint extends StatelessWidget {
  const _HoldHint({required this.visible});
  final bool visible;

  static const double height = 22;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, size: 11, color: scheme.primary),
                const SizedBox(width: 4),
                const Text('Hold OK to pick or swap the channel',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({
    super.key,
    required this.focusNode,
    required this.game,
    required this.match,
    required this.matching,
    required this.hideScores,
    required this.starred,
    required this.onFocus,
    required this.onTap,
    required this.onHold,
  });

  static const double width = 268;
  static const double height = 132;

  final FocusNode focusNode;
  final SportsGame game;
  final ChannelMatch? match;
  final bool matching;
  final bool hideScores;

  /// One of My Teams plays.
  final bool starred;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final VoidCallback onHold;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = widget.game;
    final live = g.state == GameState.live;
    final showScore = g.state != GameState.pre && !widget.hideScores;
    final status = switch (g.state) {
      GameState.pre => _timeLabel(g.start),
      GameState.live => g.statusText.isEmpty ? 'LIVE' : g.statusText,
      GameState.post => g.statusText.isEmpty ? 'Final' : g.statusText,
    };

    Widget teamLine(SportsTeam t, {required bool leading}) {
      final firstScore = int.tryParse(g.first.score ?? '');
      final secondScore = int.tryParse(g.second.score ?? '');
      final mine = int.tryParse(t.score ?? '');
      final other = identical(t, g.first) ? secondScore : firstScore;
      final winning = g.state == GameState.post &&
          mine != null &&
          other != null &&
          mine > other;
      return Row(
        children: [
          SizedBox(
            width: 22,
            child: leading
                ? const SizedBox()
                : Text(g.joiner,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white54)),
          ),
          SportsLogo(
              url: t.logoUrl,
              size: 30,
              fallback: t.abbreviation,
              color: t.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: g.state == GameState.post && !winning
                        ? Colors.white70
                        : Colors.white)),
          ),
          if (showScore)
            Text(t.score ?? '',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: winning || live ? Colors.white : Colors.white70))
          else if (t.record != null)
            Text(t.record!,
                style: const TextStyle(fontSize: 13, color: Colors.white54)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Remote OK: short = watch, hold = channel menu (key path). Mouse/touch
          // long-press opens the menu too; a plain click keeps InkWell's onTap.
          HoldToActivate(
            onTap: widget.onTap,
            onHold: widget.onHold,
            child: InkWell(
              focusNode: widget.focusNode,
              borderRadius: BorderRadius.circular(16),
              // Same mouse convention as PosterCard: first click focuses (fills
              // the hero), a click on the focused card opens it.
              onTap: () {
                if (Platform.isWindows && !widget.focusNode.hasFocus) {
                  widget.focusNode.requestFocus();
                } else {
                  widget.onTap();
                }
              },
              onFocusChange: (f) {
                setState(() => _focused = f);
                if (f) widget.onFocus();
              },
              child: AnimatedScale(
                scale: _focused ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: Container(
                  width: _GameCard.width,
                  height: _GameCard.height,
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                  decoration: BoxDecoration(
                    color:
                        _focused ? null : Colors.white.withValues(alpha: 0.07),
                    gradient: _focused ? sportsFocusSheen(scheme) : null,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _focused ? scheme.primary : Colors.white10,
                        width: _focused ? 2.5 : 1),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.35),
                                blurRadius: 16)
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.starred)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.star,
                                  size: 13, color: scheme.primary),
                            ),
                          Text(g.league.shortName.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1,
                                  color: Colors.white54)),
                          const Spacer(),
                          if (live)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent),
                            ),
                          Text(status,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      live ? Colors.redAccent : Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      teamLine(g.first, leading: true),
                      const SizedBox(height: 4),
                      teamLine(g.second, leading: false),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                              widget.match != null
                                  ? Icons.live_tv
                                  : Icons.add_circle_outline,
                              size: 13,
                              color: widget.match != null
                                  ? scheme.primary
                                  : Colors.white38),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.match?.channel.name ??
                                  (widget.matching
                                      ? 'Looking…'
                                      : 'Pick a channel'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: widget.match != null
                                      ? scheme.primary
                                      : Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _HoldHint(visible: _focused),
        ],
      ),
    );
  }
}

// =================================================================== dialogs

sealed class _GameAction {}

class _WatchAction extends _GameAction {
  _WatchAction(this.channel);
  final Channel channel;
}

class _PickAction extends _GameAction {}

class _ForgetPickAction extends _GameAction {}

class _GameDialog extends StatelessWidget {
  const _GameDialog({
    required this.game,
    required this.matches,
    required this.matching,
    required this.hideScores,
    required this.hasPick,
  });

  final SportsGame game;
  final List<ChannelMatch> matches;
  final bool matching;
  final bool hideScores;
  final bool hasPick;

  @override
  Widget build(BuildContext context) {
    final showScore = game.state != GameState.pre && !hideScores;
    return Dialog(
      backgroundColor: const Color(0xFF15151A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SportsLogo(
                      url: game.first.logoUrl,
                      size: 44,
                      fallback: game.first.abbreviation,
                      color: game.first.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            showScore
                                ? '${game.first.shortName} ${game.first.score ?? ''}  ${game.joiner}  ${game.second.shortName} ${game.second.score ?? ''}'
                                : game.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text(
                            '${game.league.name} · ${game.state == GameState.pre ? '${DateFormat('EEE').format(game.start.toLocal())} ${_timeLabel(game.start)}' : game.statusText}'
                            '${game.broadcasts.isEmpty ? '' : ' · ${game.broadcasts.take(3).join(', ')}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white60)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SportsLogo(
                      url: game.second.logoUrl,
                      size: 44,
                      fallback: game.second.abbreviation,
                      color: game.second.color),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                  matches.isEmpty
                      ? (matching
                          ? 'Still looking for channels…'
                          : 'No channel found for this game')
                      : 'On ${matches.length} channel${matches.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, letterSpacing: 1, color: Colors.white54)),
              const SizedBox(height: 6),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < matches.length; i++)
                      TvMenuTile(
                        autofocus: i == 0,
                        titleMaxLines: 2,
                        leading: _ChannelLogo(channel: matches[i].channel),
                        title: matches[i].channel.name,
                        subtitle: matches[i].detail == null ||
                                matches[i].reason == MatchReason.name
                            ? matches[i].reason.label
                            : '${matches[i].reason.label} · ${matches[i].detail}',
                        onTap: () => Navigator.of(context)
                            .pop(_WatchAction(matches[i].channel)),
                      ),
                    TvMenuTile(
                      autofocus: matches.isEmpty,
                      icon: Icons.search,
                      title: matches.isEmpty
                          ? 'Pick the channel'
                          : 'Choose a different channel',
                      subtitle: 'Search your channels — it can be remembered '
                          'for this game or team',
                      onTap: () => Navigator.of(context).pop(_PickAction()),
                    ),
                    if (hasPick)
                      TvMenuTile(
                        icon: Icons.restart_alt,
                        title: 'Forget my pick',
                        subtitle: 'Go back to the automatic match',
                        onTap: () =>
                            Navigator.of(context).pop(_ForgetPickAction()),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: url == null || url.isEmpty
          ? const Icon(Icons.live_tv, color: Colors.white54, size: 20)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              memCacheWidth: 96,
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.live_tv, color: Colors.white54, size: 20),
            ),
    );
  }
}

enum _PickScope { game, first, second }

class _PickScopeDialog extends StatelessWidget {
  const _PickScopeDialog({required this.game, required this.channel});
  final SportsGame game;
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF15151A),
      title: const Text('Remember this channel?'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TvMenuTile(
              autofocus: true,
              icon: Icons.event,
              title: 'Just this game',
              subtitle: 'Best for channels named after one game',
              onTap: () => Navigator.of(context).pop(_PickScope.game),
            ),
            for (final (scope, team) in [
              (_PickScope.first, game.first),
              (_PickScope.second, game.second),
            ])
              TvMenuTile(
                leading: SportsLogo(
                    url: team.logoUrl,
                    size: 36,
                    fallback: team.abbreviation,
                    color: team.color),
                title: 'Always for the ${team.shortName}',
                subtitle: 'Best for a regular channel, like a regional network',
                onTap: () => Navigator.of(context).pop(scope),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditLeaguesDialog extends StatefulWidget {
  const _EditLeaguesDialog({required this.selected});
  final List<String> selected;

  @override
  State<_EditLeaguesDialog> createState() => _EditLeaguesDialogState();
}

class _EditLeaguesDialogState extends State<_EditLeaguesDialog> {
  late final Set<String> _on = widget.selected.toSet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: const Color(0xFF15151A),
      title: const Text('Leagues'),
      content: SizedBox(
        width: 460,
        height: 420,
        child: ListView(
          children: [
            for (final (i, l) in kSportsLeagues.indexed)
              TvMenuTile(
                autofocus: i == 0,
                leading: SportsLogo(url: l.logoUrl, size: 36),
                title: l.name,
                trailing: Icon(
                    _on.contains(l.id)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        _on.contains(l.id) ? scheme.primary : Colors.white38),
                onTap: () => setState(() {
                  if (!_on.remove(l.id)) _on.add(l.id);
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _on.isEmpty
              ? null
              : () => Navigator.of(context).pop([
                    for (final l in kSportsLeagues)
                      if (_on.contains(l.id)) l.id,
                  ]),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Manual "which channel is this game on" search. Quick chips (team names,
/// league, networks) avoid typing — on a Fire Stick the on-screen keyboard
/// is slow and swallows Back (CLAUDE.md §10) — but a text field is there
/// for anything else.
class _ChannelPickerScreen extends StatefulWidget {
  const _ChannelPickerScreen({required this.game, required this.matcher});
  final SportsGame game;
  final SportsChannelMatcher matcher;

  @override
  State<_ChannelPickerScreen> createState() => _ChannelPickerScreenState();
}

class _ChannelPickerScreenState extends State<_ChannelPickerScreen> {
  final _controller = TextEditingController();
  late final List<FocusNode> _chipNodes;
  late final FocusNode _fieldNode = FocusNode(onKeyEvent: _onFieldKey);
  final _firstResult = FocusNode();
  late String _query;
  late final List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    final g = widget.game;
    _suggestions = {
      g.first.shortName,
      g.second.shortName,
      g.league.shortName,
      ...g.broadcasts.take(4),
    }.toList();
    _chipNodes = [for (final _ in _suggestions) FocusNode()];
    _query = g.second.shortName;
    _controller.text = _query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chipNodes[_suggestions.indexOf(_query)].requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final n in _chipNodes) {
      n.dispose();
    }
    _fieldNode.dispose();
    _firstResult.dispose();
    super.dispose();
  }

  /// `EditableText` keeps the arrow keys for itself, so after Back closes the
  /// keyboard (Formuler) the D-pad had no way out of the field. The field's
  /// own node sees keys before EditableText's shortcuts do: Down -> results,
  /// Up -> suggestion chips, OK -> reopen the keyboard (Flutter only raises
  /// it when the field *gains* focus) — same idea as Add Playlist's
  /// `_handleFieldEscapeKey`.
  KeyEventResult _onFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_firstResult.context == null) return KeyEventResult.ignored;
      _firstResult.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final i = _suggestions.indexOf(_query);
      _chipNodes[i < 0 ? 0 : i].requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setQuery(String q) {
    _controller.text = q;
    setState(() => _query = q);
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.matcher.search(_query);
    final epg = context.read<EpgService>();
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: 'Pick the channel for ${widget.game.title}',
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (i, s) in _suggestions.indexed)
                      SportsChip(
                        focusNode: _chipNodes[i],
                        label: s,
                        selected: _query == s,
                        compact: true,
                        onFocus: () {},
                        onTap: () => _setQuery(s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _controller,
                focusNode: _fieldNode,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search channels',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Text(
                  results.isEmpty
                      ? 'No channels match "$_query"'
                      : '${results.length}${results.length >= 200 ? '+' : ''} channels',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final c = results[i];
                    final now = epg.getCurrentProgram(c.epgId)?.title;
                    return TvMenuTile(
                      focusNode: i == 0 ? _firstResult : null,
                      titleMaxLines: 2,
                      leading: _ChannelLogo(channel: c),
                      title: c.name,
                      subtitle:
                          now == null ? c.group : '${c.group} · Now: $now',
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
