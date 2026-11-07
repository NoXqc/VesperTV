import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../utils/constants.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';

/// Settings > Sports Trak > Game card size. Large is the original card;
/// Medium and Small fit more games on screen for viewers sitting closer than
/// the usual 10 ft. Saved per viewer.
class SportsCardSizeSettingsScreen extends StatefulWidget {
  const SportsCardSizeSettingsScreen({super.key});

  /// Card scale for a stored size (see `StorageService.getSportsCardSize`).
  static double scaleFor(String size) => switch (size) {
        'medium' => 0.85,
        'small' => 0.72,
        _ => 1.0,
      };

  @override
  State<SportsCardSizeSettingsScreen> createState() =>
      _SportsCardSizeSettingsScreenState();
}

class _SportsCardSizeSettingsScreenState
    extends State<SportsCardSizeSettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late String _size;

  static const _sizes = [
    (
      'large',
      Icons.crop_square,
      'Large',
      'The original size, for watching from across the room'
    ),
    (
      'medium',
      Icons.photo_size_select_large,
      'Medium',
      'Smaller cards, more games on screen'
    ),
    (
      'small',
      Icons.photo_size_select_small,
      'Small',
      'The most games on screen, for sitting close to the TV'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _size = _storage.getSportsCardSize();
  }

  Future<void> _save(String value) async {
    if (!mounted || _storage.viewerGeneration != _viewer) return;
    setState(() => _size = value);
    await _storage.setSportsCardSize(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsScaffold(
      title: tr('Game card size'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (id, icon, title, subtitle) in _sizes)
            TvMenuTile(
              key: ValueKey('sports-card-size-$id'),
              autofocus: id == _size,
              icon: icon,
              title: tr(title),
              subtitle: tr(subtitle),
              trailing: id == _size
                  ? Icon(Icons.check, color: scheme.primary)
                  : const SizedBox.shrink(),
              onTap: () => _save(id),
            ),
          const SizedBox(height: 12),
          Text(tr(
              'Changes the game cards in {tab} rows, See all and Live now. Large is the original size. Saved for this viewer.',
              {'tab': AppConstants.sportsTabName})),
        ],
      ),
    );
  }
}
