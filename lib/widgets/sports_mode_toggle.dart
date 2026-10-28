import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../services/app_preferences.dart';
import '../services/desktop_mini_player.dart';
import '../services/playback_service.dart';
import 'settings_scaffold.dart';
import 'tv_switch_list_tile.dart';

/// Both entries change one viewer preference and return to the rebuilt home.
class SportsModeToggle extends StatefulWidget {
  const SportsModeToggle({super.key});

  @override
  State<SportsModeToggle> createState() => _SportsModeToggleState();
}

class _SportsModeToggleState extends State<SportsModeToggle> {
  bool _saving = false;

  Future<void> _change(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    final prefs = context.read<AppPreferences>();
    final navigator = Navigator.of(context);
    try {
      // A new home must not leave an invisible preview using a connection.
      await context.read<PlaybackService>().stop();
      if (Platform.isWindows) DesktopMiniPlayer.instance.clear();
      if (!mounted) return;
      await prefs.setSportsMode(value);
      if (navigator.mounted) navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('Could not change Sports Mode. Try again.'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => TvSwitchListTile(
        title: Text(tr('Sports Mode')),
        subtitle: Text(tr(
            'Make Sports Trak your home, with your top five leagues at the side.')),
        value: context.watch<AppPreferences>().sportsMode,
        onChanged: _change,
      );
}

class SportsModeSettingsScreen extends StatelessWidget {
  const SportsModeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
        title: tr('Sports Mode'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [SportsModeToggle()],
        ),
      );
}
