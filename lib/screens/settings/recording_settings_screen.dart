import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/recording_service.dart';
import '../../utils/time_format.dart';
import '../../utils/tv_theme.dart';
import '../../widgets/download_sheet.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/tv_menu_tile.dart';
import 'network_folder_screen.dart';

/// Settings > Device & data > Recordings: margins, the disk cap, where
/// recordings and downloads go (app storage, a USB drive / SD card, or a
/// network folder) and the download speed limit / start time. OK on a row
/// steps to its next value (no keyboard on a TV).
class RecordingSettingsScreen extends StatefulWidget {
  const RecordingSettingsScreen({super.key});

  @override
  State<RecordingSettingsScreen> createState() =>
      _RecordingSettingsScreenState();
}

class _RecordingSettingsScreenState extends State<RecordingSettingsScreen> {
  final _service = RecordingService.instance;
  List<RecordingVolume> _volumes = const [];

  static const _before = [0, 2, 5, 10, 15];
  static const _after = [15, 30, 45, 60, 90];
  static const _caps = [5, 10, 20, 50, 100, 200];

  /// Suggested download start times (minutes after midnight).
  static const _startTimes = [0, 60, 120, 180, 240, 300, 1320, 1380];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _service.init();
    final v = await _service.volumes();
    if (mounted) setState(() => _volumes = v);
  }

  static int _next(List<int> options, int current) {
    final i = options.indexOf(current);
    return options[(i + 1) % options.length];
  }

  static String _gb(int bytes) =>
      '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

  Future<void> _set(RecordingSettings s) async {
    await _service.updateSettings(s);
    if (mounted) setState(() {});
  }

  static String _speedHelp(String speed) => switch (speed) {
        'watch' => tr(
            'About the video\'s own bitrate: to the provider it looks like someone watching. The safest choice.'),
        'none' =>
          tr('As fast as the source sends. Some providers don\'t allow this.'),
        _ => tr('At most this speed.'),
      };

  Future<void> _openNetworkFolder() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NetworkFolderScreen()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _service.settings;
    final current = _volumes.where((v) => v.path == s.folder).firstOrNull ??
        _volumes.where((v) => !v.network).firstOrNull;
    const speeds = RecordingSettings.downloadSpeeds;
    final at = s.downloadAt;
    final startLabel =
        TimeFormat.hm.format(DateTime(2000, 1, 1, at ~/ 60, at % 60));
    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('Recordings'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TvMenuTile(
              autofocus: true,
              icon: Icons.first_page,
              title: tr('Start early: {min} min', {'min': s.minutesBefore}),
              subtitle: tr('Before the game\'s scheduled start'),
              onTap: () => _set(
                  s.copyWith(minutesBefore: _next(_before, s.minutesBefore))),
            ),
            TvMenuTile(
              icon: Icons.last_page,
              title: tr('Keep recording: {min} min', {'min': s.minutesAfter}),
              subtitle: tr('After the scheduled end, for overtime and delays'),
              onTap: () =>
                  _set(s.copyWith(minutesAfter: _next(_after, s.minutesAfter))),
            ),
            TvMenuTile(
              icon: Icons.storage,
              title: tr('Space for recordings: {gb} GB', {'gb': s.capGb}),
              subtitle: tr(
                  '{used} used. Recording stops when this is full or the storage has less than 1 GB left.',
                  {'used': _gb(_service.usedBytes)}),
              onTap: () => _set(s.copyWith(capGb: _next(_caps, s.capGb))),
            ),
            const SizedBox(height: 12),
            Text(tr('Downloads'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            TvMenuTile(
              icon: Icons.speed,
              title: tr('Speed limit: {speed}',
                  {'speed': downloadSpeedLabel(s.downloadSpeed)}),
              subtitle:
                  '${_speedHelp(s.downloadSpeed)} ${tr('Always slower while you watch something.')}',
              onTap: () => _set(s.copyWith(
                  downloadSpeed: speeds[
                      (speeds.indexOf(s.downloadSpeed) + 1) % speeds.length])),
            ),
            TvMenuTile(
              icon: Icons.nightlight_round,
              title: tr('Suggested start: {time}', {'time': startLabel}),
              subtitle: tr(
                  'What Download offers first: overnight, while nobody watches'),
              onTap: () => _set(s.copyWith(downloadAt: _next(_startTimes, at))),
            ),
            const SizedBox(height: 12),
            Text(tr('Save recordings and downloads to'),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final v in _volumes)
              TvMenuTile(
                icon: v.network
                    ? Icons.lan_outlined
                    : v.removable
                        ? Icons.usb
                        : Icons.phone_android,
                title: v.network
                    ? tr('Network folder')
                    : v.removable
                        ? tr('USB drive / SD card')
                        : tr('This device'),
                subtitle: v.network
                    ? s.network?.display ?? ''
                    : tr('{free} free of {total}',
                        {'free': _gb(v.free), 'total': _gb(v.total)}),
                trailing: identical(v, current)
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => _set(s.copyWith(folder: v.path)),
              ),
            TvMenuTile(
              icon: Icons.settings_ethernet,
              title: s.network == null
                  ? tr('Set up a network folder')
                  : tr('Network folder settings'),
              subtitle: tr('A shared folder on a computer or NAS (SMB)'),
              onTap: _openNetworkFolder,
            ),
            if (_volumes.where((v) => !v.network).length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tr('Plug in a USB drive or SD card to record to it. Recordings on this device are deleted if VesperTV is uninstalled.'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
