import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';

/// Settings > Sports Trak > Games layout: the game cards (default) or the
/// opt-in Guide, a TV guide-style list (a user's mockup on Discord, owner
/// 2026-11-07: an option, never a replacement). Saved per viewer.
class SportsLayoutSettingsScreen extends StatefulWidget {
  const SportsLayoutSettingsScreen({super.key});

  @override
  State<SportsLayoutSettingsScreen> createState() =>
      _SportsLayoutSettingsScreenState();
}

class _SportsLayoutSettingsScreenState
    extends State<SportsLayoutSettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late String _layout;

  static const _layouts = [
    ('cards', Icons.view_carousel_outlined, 'Cards', 'Game cards in rows'),
    (
      'guide',
      Icons.view_list,
      'Guide',
      'A TV guide-style list, one game per row'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _layout = _storage.getSportsLayout();
  }

  Future<void> _save(String value) async {
    if (!mounted || _storage.viewerGeneration != _viewer) return;
    setState(() => _layout = value);
    await _storage.setSportsLayout(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsScaffold(
      title: tr('Games layout'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (id, icon, title, subtitle) in _layouts)
            TvMenuTile(
              key: ValueKey('sports-layout-$id'),
              autofocus: id == _layout,
              icon: icon,
              title: tr(title),
              subtitle: tr(subtitle),
              trailing: id == _layout
                  ? Icon(Icons.check, color: scheme.primary)
                  : const SizedBox.shrink(),
              onTap: () => _save(id),
            ),
          const SizedBox(height: 12),
          Text(tr(
              'Guide lists the day\'s games under the matchup, one per row, with the league, the score or start time and the channel. Moving through the leagues on the left shows their games. OK watches, OK again is full screen, hold OK opens the game menu. Cards stays the default. Saved for this viewer.')),
        ],
      ),
    );
  }
}
