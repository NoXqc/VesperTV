import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../screens/player_screen.dart';
import '../services/device_memory_service.dart';
import '../services/network_files.dart';
import '../services/playback_service.dart';
import '../services/recording_service.dart';
import '../utils/time_format.dart';
import 'detail_header.dart';
import 'glass_menu.dart';
import 'hold_to_activate.dart';
import 'tv_menu_tile.dart';

/// Downloads (Android): a movie / episode saved to this device, a USB
/// drive or the network folder to watch offline. RecordingService does the
/// work (the recorder's foreground service, one at a time, resumable).
bool get downloadsAvailable => RecordingService.supported;

String _size(int bytes) => bytes >= 1024 * 1024 * 1024
    ? '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB'
    : '${(bytes / (1024 * 1024)).round()} MB';

/// "Like watching", "10 Mbit/s", "No limit" (Settings and the sheet).
String downloadSpeedLabel(String speed) => switch (speed) {
      'watch' => tr('Like watching'),
      'none' => tr('No limit'),
      _ => tr('{n} Mbit/s', {'n': speed}),
    };

String _duration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return tr('{m} min', {'m': m < 1 ? 1 : m});
  return tr('{h} h {m} min',
      {'h': m ~/ 60, 'm': (m % 60).toString().padLeft(2, '0')});
}

/// "Tonight at 2:00", "Today at 14:00", "Tomorrow at 9:00".
String downloadStartLabel(DateTime at, DateTime now) {
  final time = TimeFormat.hm.format(at);
  final today =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (today) {
    return at.hour >= 17
        ? tr('Tonight at {time}', {'time': time})
        : tr('Today at {time}', {'time': time});
  }
  return at.hour < 6
      ? tr('Tonight at {time}', {'time': time})
      : tr('Tomorrow at {time}', {'time': time});
}

/// The sheet before a download: what it costs (a provider connection,
/// Wi-Fi), the advice to download overnight with the time (Left / Right
/// change it), Download now and Cancel. Then queues [items]. True when
/// queued.
Future<bool> confirmDownload(
    BuildContext context, List<DownloadItem> items) async {
  if (items.isEmpty) return false;
  final rs = RecordingService.instance;
  await rs.init();
  final vol = await rs.currentVolume();
  if (!context.mounted) return false;
  final at = await showGlassMenu<DateTime>(
    context: context,
    builder: (_) => SwallowHeldActivate(
        child: _DownloadSheet(items: items, volume: vol, service: rs)),
  );
  if (at == null || !context.mounted) return false;
  final now = DateTime.now();
  final later = at.isAfter(now.add(const Duration(minutes: 1)));
  if (later) {
    final minutes = at.hour * 60 + at.minute;
    if (minutes != rs.settings.downloadAt) {
      await rs.updateSettings(rs.settings.copyWith(downloadAt: minutes));
    }
  }
  await rs.download(items, at: later ? at : null);
  await rs.askNotifications();
  if (!context.mounted) return true;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    content: Text(later
        ? tr('Download set for {when}. It shows in Recordings.',
            {'when': downloadStartLabel(at, now)})
        : tr('Downloading. It shows in Recordings.')),
    duration: const Duration(seconds: 3),
  ));
  return true;
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet(
      {required this.items, required this.volume, required this.service});

  final List<DownloadItem> items;
  final RecordingVolume? volume;
  final RecordingService service;

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  late int _at = widget.service.settings.downloadAt;

  DateTime get _start => RecordingService.nextStart(_at, DateTime.now());

  // Dart's % is never negative: 0:00 - 30 min wraps to 23:30.
  void _shift(int minutes) => setState(() => _at = (_at + minutes) % (24 * 60));

  /// "About 4.2 GB · about 1 h 40 min at your speed limit", when known.
  String? _estimate() {
    final items = widget.items;
    final size = items.every((i) => i.totalBytes > 0)
        ? items.fold<int>(0, (s, i) => s + i.totalBytes)
        : 0;
    final secs = items.every((i) => i.durationSec > 0)
        ? items.fold<int>(0, (s, i) => s + i.durationSec)
        : 0;
    final speed = widget.service.settings.downloadSpeed;
    final mbit = int.tryParse(speed);
    Duration? time;
    if (speed == 'watch' && secs > 0) {
      // Like watching runs at 1.25x the file's own bitrate.
      time = Duration(seconds: secs * 4 ~/ 5);
    } else if (size > 0 && mbit != null) {
      time = Duration(seconds: size * 8 ~/ (mbit * 1000000));
    }
    final parts = [
      if (size > 0) tr('About {size}', {'size': _size(size)}),
      if (time != null)
        tr('about {time} at your speed limit ({speed})', {
          'time': _duration(time),
          'speed': downloadSpeedLabel(speed),
        }),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final iptv = items.any((i) => i.playlistId.isNotEmpty);
    final vol = widget.volume;
    final where = vol == null
        ? tr('This device')
        : vol.network
            ? tr('Network folder')
            : vol.removable
                ? tr('USB drive / SD card')
                : tr('This device');
    final free = vol != null && vol.free >= 0
        ? tr('{free} free', {'free': _size(vol.free)})
        : null;
    final estimate = _estimate();
    final television = DeviceTypeService.television;
    final start = _start;
    return GlassMenuDialog(
      title: Text(
        items.length == 1
            ? tr('Download "{title}"', {'title': items.single.title})
            : tr('Download {n} episodes', {'n': items.length}),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.info_outline,
                          size: 18, color: Colors.amberAccent),
                    ),
                    Expanded(
                      child: Text(
                        iptv
                            ? tr(
                                'A download uses one connection to your provider. On an account with only one, it waits while you watch. It can slow your stream on Wi-Fi, and some providers don\'t allow downloads.')
                            : tr(
                                'It can slow what you watch on Wi-Fi while it runs.'),
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: Colors.white70),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(tr('Best: download overnight.'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (estimate != null) estimate,
                      tr('Saves to {where}', {'where': where}) +
                          (free == null ? '' : ' ($free)'),
                    ].join('\n'),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _shift(-30),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _shift(30),
              },
              child: TvMenuTile(
                autofocus: true,
                icon: Icons.nightlight_round,
                title: downloadStartLabel(start, DateTime.now()),
                subtitle: television
                    ? tr('◀ ▶ change the time')
                    : tr('Tap the arrows to change the time'),
                trailing: television
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _shift(-30)),
                        IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _shift(30)),
                      ]),
                onTap: () => Navigator.of(context).pop(start),
              ),
            ),
            TvMenuTile(
              icon: Icons.download_rounded,
              title: tr('Download now'),
              subtitle: iptv
                  ? tr(
                      'Waits while you watch, if your account has one connection')
                  : null,
              onTap: () => Navigator.of(context).pop(DateTime.now()),
            ),
            TvMenuTile(
              icon: Icons.close,
              title: tr('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Download button on a movie page (IPTV and Media Hub). [build]
/// makes the item when pressed (Media Hub asks which stream first); null
/// = nothing to download. Once queued it shows the download's state, and
/// OK opens Play / Resume / Stop / Delete.
class DownloadButton extends StatefulWidget {
  const DownloadButton({
    super.key,
    required this.sourceId,
    required this.build,
    required this.focusNode,
    required this.scale,
    this.onFocused,
  });

  final String sourceId;
  final Future<List<DownloadItem>?> Function(BuildContext context) build;
  final FocusNode focusNode;
  final double scale;
  final VoidCallback? onFocused;

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  final _service = RecordingService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    unawaited(_service.init());
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _press() async {
    if (_busy) return;
    final existing = _service.downloadFor(widget.sourceId);
    if (existing != null) return downloadMenu(context, existing);
    setState(() => _busy = true);
    try {
      final items = await widget.build(context);
      if (items == null || items.isEmpty || !mounted) return;
      await confirmDownload(context, items);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _service.downloadFor(widget.sourceId);
    final (icon, label) =
        _busy ? (Icons.hourglass_top, tr('Download')) : downloadButtonLook(r);
    return DetailPillButton(
      focusNode: widget.focusNode,
      icon: icon,
      label: label,
      selected: r != null,
      scale: widget.scale,
      onPressed: _press,
      onFocused: widget.onFocused,
    );
  }
}

/// The Download button's icon and words for [r]'s state (null = none).
(IconData, String) downloadButtonLook(RecordingEntry? r) {
  if (r == null) return (Icons.download_rounded, tr('Download'));
  return switch (r.state) {
    RecState.scheduled => (
        Icons.schedule,
        tr('Download at {time}', {'time': TimeFormat.hm.format(r.startAt)})
      ),
    RecState.queued => (Icons.hourglass_top, tr('Waiting to download')),
    RecState.recording => (
        Icons.downloading_rounded,
        r.progress != null
            ? tr('Downloading {pct}%', {'pct': (r.progress! * 100).floor()})
            : tr('Downloading {size}', {'size': _size(r.bytes)})
      ),
    RecState.done when r.complete => (
        Icons.download_done_rounded,
        tr('Downloaded')
      ),
    _ => (Icons.file_download_off_rounded, tr('Download stopped')),
  };
}

/// Hold / OK menu for a download (its page's button and the Recordings
/// tab): Play, Resume, Download now, Stop, Delete — whatever applies.
Future<void> downloadMenu(BuildContext context, RecordingEntry r) async {
  final rs = RecordingService.instance;
  final active = r.state == RecState.recording || r.state == RecState.queued;
  final waiting = r.state == RecState.scheduled;
  final canResume = !active && !waiting && !r.complete;
  final action = await showGlassMenu<String>(
    context: context,
    builder: (context) => SwallowHeldActivate(
      child: GlassMenuDialog(
        title: Text(r.league.isEmpty ? r.title : '${r.league} · ${r.title}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (r.playable)
              TvMenuTile(
                autofocus: true,
                icon: Icons.play_arrow,
                title: r.complete ? tr('Play') : tr('Play what\'s downloaded'),
                subtitle: r.progress != null && !r.complete
                    ? tr('{done} of {total}',
                        {'done': _size(r.bytes), 'total': _size(r.totalBytes)})
                    : _size(r.bytes),
                onTap: () => Navigator.of(context).pop('play'),
              ),
            if (canResume)
              TvMenuTile(
                autofocus: !r.playable,
                icon: Icons.download_rounded,
                title: tr('Resume download'),
                subtitle: r.error.isNotEmpty ? tr(r.error) : null,
                onTap: () => Navigator.of(context).pop('resume'),
              ),
            if (waiting)
              TvMenuTile(
                autofocus: !r.playable,
                icon: Icons.download_rounded,
                title: tr('Download now'),
                subtitle: tr('Instead of {time}',
                    {'time': TimeFormat.hm.format(r.startAt)}),
                onTap: () => Navigator.of(context).pop('now'),
              ),
            if (active || waiting)
              TvMenuTile(
                autofocus: !r.playable && active,
                icon: Icons.stop_circle_outlined,
                title: waiting ? tr('Cancel download') : tr('Stop download'),
                subtitle: active ? tr('Keeps what has been downloaded') : null,
                onTap: () => Navigator.of(context).pop('stop'),
              ),
            if (!active)
              TvMenuTile(
                icon: Icons.delete_outline,
                title: tr('Delete download'),
                subtitle: r.bytes > 0
                    ? tr('Frees {size}', {'size': _size(r.bytes)})
                    : tr('Removes it from the list'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
          ]),
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'play':
      await playDownload(context, r);
    case 'resume':
    case 'now':
      await rs.resumeDownload(r);
    case 'stop':
      await rs.stop(r);
    case 'delete':
      await rs.delete(r);
  }
}

/// Plays a downloaded file (local, or the network folder through the
/// recorder's local server — PlaybackService.openUrlFor).
Future<void> playDownload(BuildContext context, RecordingEntry r) async {
  final channel = RecordingService.instance.channelFor(r);
  await context.read<PlaybackService>().play(channel);
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(PlayerPageRoute(builder: (_) => PlayerScreen(channel: channel)));
}

/// A video in the network folder that another device saved: copy it to
/// this device (offline: a trip, the car) or play it from the share.
Future<void> networkFileMenu(BuildContext context, NetworkFile f) async {
  final action = await showGlassMenu<String>(
    context: context,
    builder: (context) => SwallowHeldActivate(
      child: GlassMenuDialog(
        title: Text(f.group.isEmpty ? f.title : '${f.group} · ${f.title}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TvMenuTile(
              autofocus: true,
              icon: Icons.download_for_offline_outlined,
              title: tr('Copy to this device'),
              subtitle: tr('{size}, to watch without the network',
                  {'size': _size(f.size)}),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            TvMenuTile(
              icon: Icons.play_arrow,
              title: tr('Play from the network folder'),
              onTap: () => Navigator.of(context).pop('play'),
            ),
          ]),
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'copy':
      await RecordingService.instance.copyToDevice(f);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr('Copying to this device. It shows under Downloading.'))));
    case 'play':
      final channel = f.toChannel();
      await context.read<PlaybackService>().play(channel);
      if (!context.mounted) return;
      await Navigator.of(context).push(
          PlayerPageRoute(builder: (_) => PlayerScreen(channel: channel)));
  }
}
