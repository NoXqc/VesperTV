import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/goal_overlay_probe.dart';
import 'tv_menu_tile.dart';

/// Android TV-only settings. Native owns both timers, even after this unmounts.
class GoalOverlayProbeSettings extends StatefulWidget {
  const GoalOverlayProbeSettings({super.key});

  @override
  State<GoalOverlayProbeSettings> createState() =>
      _GoalOverlayProbeSettingsState();
}

class _GoalOverlayProbeSettingsState extends State<GoalOverlayProbeSettings>
    with WidgetsBindingObserver {
  OverlayProbeStatus? _status;
  bool _busy = false;
  int _request = 0;
  Timer? _completion;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final request = ++_request;
    final status = await GoalOverlayProbe.status();
    if (!mounted || request != _request) return;
    setState(() => _status = status);
    _completion?.cancel();
    if (status.running && _active) {
      // Capability status only: score/network polling is deliberately absent.
      _completion = Timer(const Duration(seconds: 2), _refresh);
    }
  }

  Future<void> _openSettings() async {
    setState(() => _busy = true);
    final opened = await GoalOverlayProbe.openSettings();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!opened) {
      setState(() => _status = const OverlayProbeStatus());
    } else {
      await _refresh();
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final started = await GoalOverlayProbe.testPopup();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(started
            ? 'Test popup in 10 seconds. Switch to another app.'
            : 'The overlay test could not start. Check overlay access and try again.'))));
    await _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _completion?.cancel();
    ++_request;
    if (_active) unawaited(_refresh());
  }

  @override
  void dispose() {
    ++_request;
    _completion?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final label = status == null
        ? tr('Checking overlay access…')
        : switch (status.access) {
            OverlayProbeAccess.granted => tr('Overlay access granted'),
            OverlayProbeAccess.settings =>
              tr('Open settings to allow overlays'),
            OverlayProbeAccess.unavailable =>
              tr('Overlay access not available'),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.picture_in_picture_alt),
          title: Text(tr('Alerts over other apps (beta)')),
          subtitle: Text(label),
        ),
        TvMenuTile(
          icon: Icons.settings_outlined,
          title: tr('Open overlay settings'),
          subtitle: tr(
              'Allow VesperTV to display over other apps, then return here.'),
          enabled: !_busy && (status?.canOpenSettings ?? false),
          onTap: _openSettings,
        ),
        TvMenuTile(
          icon: Icons.visibility_outlined,
          title: tr('Test popup over other apps'),
          subtitle: tr(status?.running == true
              ? 'Overlay test running. Switch to another app.'
              : 'Waits 10 seconds, shows a test card for 6 seconds, then stops.'),
          enabled: !_busy &&
              status?.access == OverlayProbeAccess.granted &&
              status?.running != true,
          onTap: _test,
        ),
        if (status?.result != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(tr(status!.result == 'completed'
                ? 'Test finished. Check whether the popup appeared in the other app.'
                : status.result == 'cancelled'
                    ? 'Overlay test cancelled.'
                    : 'The overlay test could not run on this device.')),
          ),
      ],
    );
  }
}
