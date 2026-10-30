import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';

class SportsLeagueVisibilitySettingsScreen extends StatefulWidget {
  const SportsLeagueVisibilitySettingsScreen({super.key});

  @override
  State<SportsLeagueVisibilitySettingsScreen> createState() =>
      _SportsLeagueVisibilitySettingsScreenState();
}

class _SportsLeagueVisibilitySettingsScreenState
    extends State<SportsLeagueVisibilitySettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late bool _enabled;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _enabled = _storage.getSportsHideEmptyLeagues();
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
    await _storage.setSportsHideEmptyLeagues(value);
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: tr('Hide leagues with no games'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TvSwitchListTile(
              focusNode: _focus,
              title: Text(tr('Hide leagues with no games')),
              subtitle:
                  Text(tr('Show only leagues with games on the selected day')),
              value: _enabled,
              onChanged: _save,
            ),
            const SizedBox(height: 12),
            Text(tr(
                'Follows the selected day in Sports Trak. Leagues stay visible while schedules are loading or unavailable. Your saved leagues and their order are kept in Edit leagues. Saved for this viewer.')),
          ],
        ),
      );
}
