import '../widgets/glass_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/sports.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/tv_theme.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/sports_widgets.dart';
import '../widgets/game_score_alert_menu_tile.dart';
import '../widgets/tv_menu_tile.dart';
import '../l10n/l10n.dart';

const _bankSports = [
  ('football', 'Football 🏈'),
  ('soccer', 'Football ⚽'),
  ('hockey', 'Hockey 🏒'),
  ('basketball', 'Basketball 🏀'),
  ('baseball', 'Baseball ⚾'),
  ('golf', 'Golf ⛳'),
  ('fighting', 'Fighting 🥊'),
  ('racing', 'Motorsport 🏎️'),
  ('tennis', 'Tennis 🎾'),
  ('rugby', 'Rugby 🏉'),
  ('cricket', 'Cricket 🏏'),
  ('darts', 'Darts 🎯'),
  ('volleyball', 'Volleyball 🏐'),
  ('australian-football', 'Australian football 🏉'),
];

String _bankSport(SportsLeague league) => switch (league.sport) {
      'mma' || 'boxing' || 'wrestling' => 'fighting',
      'rugby-league' => 'rugby',
      final sport => sport,
    };

/// Which leagues the Sports tab shows, and which extra leagues it knows.
///
/// "Your leagues" = the 13 base leagues ([kSportsLeagues], can be hidden but
/// never removed) plus leagues added from the bank. OK toggles shown/hidden;
/// holding OK opens the league's menu: make it the favourite (Sports Trak
/// opens on it, its games lead the player's Live now) and, for an added
/// league, send it back to the bank. "League bank" =
/// [kSportsLeagueBank] minus what's added, in collapsible sports; OK adds (and
/// shows) a league. Saves on every change; pops `true` if anything changed.
///
/// Two columns side by side on a wide screen (Left/Right switch column,
/// explicit like the rest of Sports — CLAUDE.md §10), one list on a phone.
class SportsLeagueManagerScreen extends StatefulWidget {
  const SportsLeagueManagerScreen({super.key});

  @override
  State<SportsLeagueManagerScreen> createState() =>
      _SportsLeagueManagerScreenState();
}

class _SportsLeagueManagerScreenState extends State<SportsLeagueManagerScreen> {
  late final StorageService _storage = context.read<StorageService>();

  /// Shown league ids, in the Sports tab's chip order.
  late List<String> _shown;

  /// Added bank league ids, in the order added.
  late List<String> _added;

  /// The favourite league id, or null.
  late String? _favorite = _storage.getSportsFavoriteLeague();
  bool _changed = false;

  final _yoursScope = FocusScopeNode(debugLabel: 'leagues-yours');
  final _bankScope = FocusScopeNode(debugLabel: 'leagues-bank');
  final Map<String, FocusNode> _nodes = {};
  final Set<String> _expandedSports = {};

  FocusNode _node(String id) => _nodes.putIfAbsent(id, FocusNode.new);

  @override
  void initState() {
    super.initState();
    _added = [
      for (final id in _storage.getSportsAddedLeagues())
        if (kSportsLeagueBank.any((l) => l.id == id)) id,
    ];
    _shown = [
      for (final id in _storage.getSportsLeagues() ?? kDefaultSportsLeagueIds)
        if (_isAvailable(id)) id,
    ];
    if (_shown.isEmpty) _shown = [...kDefaultSportsLeagueIds];
  }

  @override
  void dispose() {
    _yoursScope.dispose();
    _bankScope.dispose();
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  bool _isAvailable(String id) =>
      kSportsLeagues.any((l) => l.id == id) || _added.contains(id);

  List<SportsLeague> get _yours => [
        ...kSportsLeagues,
        for (final id in _added) sportsLeagueById(id)!,
      ];

  List<SportsLeague> get _bank => [
        for (final (sport, _) in _bankSports)
          for (final l in kSportsLeagueBank)
            if (_bankSport(l) == sport && !_added.contains(l.id)) l
      ];

  /// The exact visible row order, including sport headers. Collapsed leagues
  /// never participate in traversal or focus restoration after an addition.
  List<String> _bankRows(List<SportsLeague> bank) => [
        for (final (sport, _) in _bankSports)
          if (bank.any((l) => _bankSport(l) == sport)) ...[
            'bank-sport:$sport',
            if (_expandedSports.contains(sport))
              for (final l in bank)
                if (_bankSport(l) == sport) l.id,
          ],
      ];

  Future<void> _save() async {
    _changed = true;
    // A hidden or sent-back league stops being the favourite.
    if (_favorite != null && !_shown.contains(_favorite)) _favorite = null;
    await _storage.setSportsAddedLeagues(_added);
    await _storage.setSportsLeagues(_shown);
    await _storage.setSportsFavoriteLeague(_favorite);
  }

  /// Hold OK on one of your leagues: favourite on/off, send back (added).
  Future<void> _openMenu(SportsLeague l) async {
    final favorite = _favorite == l.id;
    final action = await showGlassMenu<String>(
      context: context,
      // Opened by a hold: drop the held OK's repeats.
      builder: (context) => SwallowHeldActivate(
        child: GlassMenuDialog(
          title: Text(l.name),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvMenuTile(
                  autofocus: true,
                  icon: favorite ? Icons.star_outline : Icons.star,
                  title: favorite
                      ? tr('Remove from favourite')
                      : tr('Make favourite league'),
                  subtitle: favorite
                      ? null
                      : tr(
                          '{tab} opens on it and its games come first in Live now',
                          {'tab': AppConstants.sportsTabName}),
                  onTap: () => Navigator.of(context).pop('favorite'),
                ),
                LeagueGoalAlertMenuTile(
                    league: l, onDone: () => Navigator.of(context).pop()),
                if (!l.isBase)
                  TvMenuTile(
                    icon: Icons.remove_circle_outline,
                    title: tr('Send back to the league bank'),
                    onTap: () => Navigator.of(context).pop('remove'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'favorite') {
      setState(() {
        _favorite = favorite ? null : l.id;
        // The favourite is always shown.
        if (!favorite && !_shown.contains(l.id)) _shown.add(l.id);
      });
      await _save();
    } else if (action == 'remove') {
      _remove(l);
    }
  }

  void _toggleShown(SportsLeague l) {
    if (_shown.contains(l.id)) {
      // The Sports tab needs at least one league.
      if (_shown.length == 1) return;
      setState(() => _shown.remove(l.id));
    } else {
      setState(() => _shown.add(l.id));
    }
    _save();
  }

  void _add(SportsLeague l) {
    final rows = _bankRows(_bank);
    final i = rows.indexOf(l.id);
    setState(() {
      _added.add(l.id);
      if (!_shown.contains(l.id)) _shown.add(l.id);
    });
    _save();
    // Prefer the following visible row even when an exhausted sport's header
    // disappears too. If the bank is exhausted, follow the added league left.
    final rest = _bankRows(_bank);
    final next = rows.skip(i + 1).where(rest.contains).firstOrNull;
    final previous =
        rows.take(i).toList().reversed.where(rest.contains).firstOrNull;
    _focusLater(next ?? previous ?? l.id);
  }

  void _remove(SportsLeague l) {
    if (l.isBase) return;
    final yours = _yours;
    final i = yours.indexWhere((y) => y.id == l.id);
    if (_shown.length == 1 && _shown.first == l.id) return;
    setState(() {
      _added.remove(l.id);
      _shown.remove(l.id);
    });
    _save();
    final rest = _yours;
    _focusLater(rest[i.clamp(0, rest.length - 1)].id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(tr('{name} is back in the league bank', {'name': l.name})),
        duration: const Duration(seconds: 2)));
  }

  void _focusLater(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusRow(id);
    });
  }

  void _focusRow(String id) {
    final node = _nodes[id];
    if (node?.context == null) return;
    node!.requestFocus();
    Scrollable.ensureVisible(node.context!,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    Scrollable.ensureVisible(node.context!,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
  }

  void _focusColumn(FocusScopeNode scope, List<String> rows) {
    if (scope.hasFocus || rows.isEmpty) return;
    if (scope.focusedChild != null) {
      scope.requestFocus();
    } else {
      _focusRow(rows.first);
    }
  }

  void _moveRow(List<String> rows, int direction) {
    final index = rows.indexWhere((id) => _nodes[id]?.hasFocus ?? false);
    if (index < 0) return;
    _focusRow(rows[(index + direction).clamp(0, rows.length - 1)]);
  }

  Widget _scrollingRows(List<String> rows, List<Widget> tiles) =>
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _moveRow(rows, -1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _moveRow(rows, 1),
        },
        // Build every expanded row so the remote can reach past the viewport.
        // The bank is small and collapsed leagues have no mounted rows.
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: tiles),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final yours = _yours;
    final bank = _bank;
    final yoursRows = [for (final l in yours) l.id];
    final bankRows = _bankRows(bank);
    final yoursTiles = [
      for (final (i, l) in yours.indexed) _yourTile(l, autofocus: i == 0),
    ];
    final bankTiles = <Widget>[
      for (final (sport, label) in _bankSports)
        if (bank.any((l) => _bankSport(l) == sport)) ...[
          _sportTile(sport, label),
          if (_expandedSports.contains(sport))
            for (final l in bank)
              if (_bankSport(l) == sport) _bankTile(l),
        ],
      if (bank.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(tr('Every league is added.'),
              style: const TextStyle(color: Colors.white54)),
        ),
    ];

    final Widget body;
    if (narrow) {
      body = FocusScope(
        node: _yoursScope,
        child: _scrollingRows(
          [...yoursRows, ...bankRows],
          [
            _columnTitle(tr('Your leagues')),
            ...yoursTiles,
            const SizedBox(height: 12),
            _columnTitle(tr('League bank')),
            ...bankTiles,
          ],
        ),
      );
    } else {
      body = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _focusColumn(_yoursScope, yoursRows),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _focusColumn(_bankScope, bankRows),
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FocusScope(
                node: _yoursScope,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _columnTitle(tr('Your leagues')),
                    Expanded(child: _scrollingRows(yoursRows, yoursTiles)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: FocusScope(
                node: _bankScope,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _columnTitle(tr('League bank')),
                    Expanded(child: _scrollingRows(bankRows, bankTiles)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SportsScreenFrame(
        child: withTvThemeIfNeeded(
          context,
          (context) => Stack(
            children: [
              const Positioned.fill(child: SettingsGradientBackground()),
              Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              const SportsBackButton(),
                              Expanded(
                                child: Text(tr('League manager'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                        Text(tr('OK: show/hide or add · Hold OK: favourite league, or send an added league back to the bank'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 10),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _columnTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      );

  Widget _yourTile(SportsLeague l, {required bool autofocus}) {
    final shown = _shown.contains(l.id);
    final scheme = Theme.of(context).colorScheme;
    final favorite = _favorite == l.id;
    final subtitle = [
      if (favorite) tr('Favourite league'),
      if (!l.isBase) tr('Added · hold to send back'),
    ].join(' · ');
    return HoldToActivate(
      key: ValueKey('yours:${l.id}'),
      onTap: () => _toggleShown(l),
      onHold: () => _openMenu(l),
      child: TvMenuTile(
        focusNode: _node(l.id),
        autofocus: autofocus,
        leading: SportsLogo(url: l.logoUrl, size: 36, fallback: l.shortName),
        title: l.name,
        subtitle: subtitle.isEmpty ? null : subtitle,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (favorite)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.star, color: scheme.primary),
            ),
          Icon(shown ? Icons.check_circle : Icons.radio_button_unchecked,
              color: shown ? scheme.primary : Colors.white38),
        ]),
        onTap: () => _toggleShown(l),
      ),
    );
  }

  Widget _bankTile(SportsLeague l) {
    return TvMenuTile(
      key: ValueKey('bank:${l.id}'),
      focusNode: _node(l.id),
      leading: SportsLogo(url: l.logoUrl, size: 36, fallback: l.shortName),
      title: l.name,
      trailing: const Icon(Icons.add_circle_outline, color: Colors.white54),
      onTap: () => _add(l),
    );
  }

  Widget _sportTile(String sport, String label) {
    final expanded = _expandedSports.contains(sport);
    final id = 'bank-sport:$sport';
    return Semantics(
      expanded: expanded,
      child: TvMenuTile(
        key: ValueKey(id),
        focusNode: _node(id),
        icon: expanded ? Icons.folder_open_outlined : Icons.folder_outlined,
        title: tr(label),
        trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
        onTap: () {
          setState(() {
            if (expanded) {
              _expandedSports.remove(sport);
            } else {
              _expandedSports.add(sport);
            }
          });
          _focusLater(id);
        },
      ),
    );
  }
}
