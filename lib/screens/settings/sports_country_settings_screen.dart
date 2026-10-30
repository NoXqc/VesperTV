import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/sports_channel_countries.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';

/// Sports Trak settings starts with country preferences; the parent Settings
/// category has room for further sports controls without changing this page.
class SportsCountrySettingsScreen extends StatefulWidget {
  const SportsCountrySettingsScreen({super.key});
  @override
  State<SportsCountrySettingsScreen> createState() =>
      _SportsCountrySettingsScreenState();
}

class _SportsCountrySettingsScreenState
    extends State<SportsCountrySettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _selected = _storage
        .getSportsPreferredCountries()
        .map(SportsChannelCountries.normalize)
        .whereType<String>()
        .toSet();
  }

  Future<void> _save(Set<String> next) async {
    if (!mounted || _storage.viewerGeneration != _viewer) return;
    setState(() => _selected = next);
    await _storage.setSportsPreferredCountries(next.toList());
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
      title: tr('Preferred channel countries'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr(
              'Prefer these countries among channels that match the game. Other countries remain available. Your game and team channel choices still come first.')),
          const SizedBox(height: 12),
          Text(tr(
              'Selected countries have equal priority. Match evidence comes first, then preferred playlist, country and video quality. Saved for this viewer.')),
          const SizedBox(height: 12),
          TvMenuTile(
              key: const ValueKey('country-automatic'),
              autofocus: true,
              icon: Icons.public,
              title: tr('No country preference'),
              subtitle: tr('Rank countries equally'),
              trailing: Icon(_selected.isEmpty
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: () => _save({})),
          for (final country in SportsChannelCountries.names.entries)
            TvMenuTile(
                key: ValueKey('country-${country.key}'),
                icon: Icons.flag_outlined,
                title: tr(country.value),
                subtitle: country.key,
                trailing: Icon(_selected.contains(country.key)
                    ? Icons.check_box
                    : Icons.check_box_outline_blank),
                onTap: () {
                  final next = {..._selected};
                  if (!next.remove(country.key)) next.add(country.key);
                  _save(next);
                }),
        ],
      ));
}
