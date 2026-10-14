import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/sports.dart';
import '../services/storage_service.dart';
import '../utils/tv_theme.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/section_label.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/sports_widgets.dart';
import '../widgets/tv_menu_tile.dart';
import '../l10n/l10n.dart';

/// Which leagues the Sports tab shows, and which extra leagues it knows.
///
/// "Your leagues" = the 13 base leagues ([kSportsLeagues], can be hidden but
/// never removed) plus leagues added from the bank. OK toggles shown/hidden;
/// holding OK on an added league sends it back to the bank. "League bank" =
/// [kSportsLeagueBank] minus what's added, grouped by region; OK adds (and
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
  bool _changed = false;

  final _yoursScope = FocusScopeNode(debugLabel: 'leagues-yours');
  final _bankScope = FocusScopeNode(debugLabel: 'leagues-bank');
  final Map<String, FocusNode> _nodes = {};

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
        for (final l in kSportsLeagueBank)
          if (!_added.contains(l.id)) l
      ];

  Future<void> _save() async {
    _changed = true;
    await _storage.setSportsAddedLeagues(_added);
    await _storage.setSportsLeagues(_shown);
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
    final bank = _bank;
    final i = bank.indexWhere((b) => b.id == l.id);
    setState(() {
      _added.add(l.id);
      if (!_shown.contains(l.id)) _shown.add(l.id);
    });
    _save();
    // Keep the D-pad in the bank, on the league that took this one's place.
    final rest = _bank;
    if (rest.isNotEmpty) _focusLater(rest[i.clamp(0, rest.length - 1)].id);
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
      final node = _nodes[id];
      if (node?.context == null) return;
      node!.requestFocus();
      Scrollable.ensureVisible(node.context!, alignment: 0.5);
    });
  }

  void _focusColumn(FocusScopeNode scope, List<SportsLeague> leagues) {
    if (scope.hasFocus || leagues.isEmpty) return;
    if (scope.focusedChild != null) {
      scope.requestFocus();
    } else {
      _node(leagues.first.id).requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final yours = _yours;
    final bank = _bank;
    final yoursTiles = [
      for (final (i, l) in yours.indexed) _yourTile(l, autofocus: i == 0),
    ];
    final bankTiles = <Widget>[
      for (final region in kSportsLeagueRegions)
        if (bank.any((l) => l.region == region)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
            child: SectionLabel(tr(region)),
          ),
          for (final l in bank)
            if (l.region == region) _bankTile(l),
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
        child: ListView(
          children: [
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
              _focusColumn(_yoursScope, yours),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _focusColumn(_bankScope, bank),
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
                    Expanded(child: ListView(children: yoursTiles)),
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
                    Expanded(child: ListView(children: bankTiles)),
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
                              Text(tr('League manager'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Text(tr('OK: show/hide or add · Hold OK on an added league to send it back to the bank'),
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
    return HoldToActivate(
      key: ValueKey('yours:${l.id}'),
      onTap: () => _toggleShown(l),
      onHold: l.isBase ? null : () => _remove(l),
      child: TvMenuTile(
        focusNode: _node(l.id),
        autofocus: autofocus,
        leading: SportsLogo(url: l.logoUrl, size: 36, fallback: l.shortName),
        title: l.name,
        subtitle: l.isBase ? null : tr('Added · hold to send back'),
        trailing: Icon(
            shown ? Icons.check_circle : Icons.radio_button_unchecked,
            color: shown ? scheme.primary : Colors.white38),
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
}
