import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';

/// The existing per-viewer quality preference, moved out of the league bar.
class SportsQualitySettingsScreen extends StatefulWidget {
  const SportsQualitySettingsScreen({super.key});

  @override
  State<SportsQualitySettingsScreen> createState() =>
      _SportsQualitySettingsScreenState();
}

class _SportsQualitySettingsScreenState
    extends State<SportsQualitySettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late bool _enabled;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _enabled = _storage.getSportsPreferQuality();
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
    await _storage.setSportsPreferQuality(value);
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: tr('Prefer highest quality'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TvSwitchListTile(
              key: const ValueKey('sports-prefer-quality'),
              focusNode: _focus,
              title: Text(tr('Prefer highest quality')),
              subtitle:
                  Text(tr('Prefer higher-quality channels among game matches')),
              value: _enabled,
              onChanged: _save,
            ),
            const SizedBox(height: 12),
            Text(tr(
                'On by default. Your saved channel choices still come first. Turn this off to keep the usual match order. Saved for this viewer.')),
          ],
        ),
      );
}
