import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../services/storage_service.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_switch_list_tile.dart';

class SportsPhoneNotificationsSettingsScreen extends StatefulWidget {
  const SportsPhoneNotificationsSettingsScreen({super.key});
  @override
  State<SportsPhoneNotificationsSettingsScreen> createState() =>
      _SportsPhoneNotificationsSettingsState();
}

class _SportsPhoneNotificationsSettingsState
    extends State<SportsPhoneNotificationsSettingsScreen> {
  late final StorageService _storage;
  late final int _viewer;
  late bool _reminders, _goals;
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _storage = context.read<StorageService>();
    _viewer = _storage.viewerGeneration;
    _reminders = _storage.getPhoneGameReminders();
    _goals = _storage.getPhoneGoalAlerts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save(bool goals, bool value) async {
    if (_storage.viewerGeneration != _viewer) return;
    if (goals) {
      await _storage.setPhoneGoalAlerts(value);
    } else {
      await _storage.setPhoneGameReminders(value);
    }
    if (mounted) {
      setState(() {
        if (goals) {
          _goals = value;
        } else {
          _reminders = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => SettingsScaffold(
      title: tr('Phone notifications'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TvSwitchListTile(
            focusNode: _focus,
            title: Text(tr('Game reminders')),
            value: _reminders,
            onChanged: (v) => _save(false, v)),
        TvSwitchListTile(
            title: Text(tr('Goal alerts')),
            value: _goals,
            onChanged: (v) => _save(true, v)),
        const SizedBox(height: 12),
        Text(tr(
            'Notify this phone for game reminders and subscribed goals, even when the app is closed. Saved for this viewer.')),
      ]));
}
