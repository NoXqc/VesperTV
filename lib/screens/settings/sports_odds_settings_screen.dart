import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';

/// Settings > Sports Trak > Betting odds: the scoreboard's lines on game
/// cards and in the stats pop-up. Off by default, per viewer.
class SportsOddsSettingsScreen extends StatefulWidget {
  const SportsOddsSettingsScreen({super.key});

  @override
  State<SportsOddsSettingsScreen> createState() =>
      _SportsOddsSettingsScreenState();
}

class _SportsOddsSettingsScreenState extends State<SportsOddsSettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late bool _enabled;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _enabled = _storage.getSportsShowOdds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save(bool value) async {
    if (!mounted || _storage.viewerGeneration != _viewer) return;
    setState(() => _enabled = value);
    await _storage.setSportsShowOdds(value);
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: tr('Betting odds'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TvSwitchListTile(
              focusNode: _focus,
              title: Text(tr('Show betting odds')),
              subtitle: Text(tr(
                  'The line and over/under on game cards, more in the game stats')),
              value: _enabled,
              onChanged: _save,
            ),
            const SizedBox(height: 12),
            Text(tr(
                'Odds come with the scores (one sportsbook, mostly North American leagues) and show before and during a game. Display only: {app} never takes bets or links to a sportsbook. Saved for this viewer.',
                {'app': AppConstants.appName})),
          ],
        ),
      );
}
