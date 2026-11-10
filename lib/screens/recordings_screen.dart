import '../widgets/glass_menu.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/network_files.dart';
import '../services/recording_service.dart';
import '../utils/constants.dart';
import '../utils/time_format.dart';
import '../utils/tv_theme.dart';
import '../widgets/download_sheet.dart';
import '../widgets/hold_to_activate.dart';
import '../widgets/hd_network_image.dart';
import '../utils/image_urls.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/sports_widgets.dart';
import '../widgets/tv_menu_tile.dart';
import 'player_screen.dart';

/// The Recordings tab (Android): what's recording or downloading, what's
/// scheduled, and what's been recorded or downloaded. A game shows as a Sports Trak style card with
/// both teams (never the score); a channel recording as a card with the
/// channel's logo and the guide programme that was on. OK = play (a
/// recording in progress plays live through the recorder's tap), hold
/// OK = Play from the start / Stop / Cancel / Delete.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final _service = RecordingService.instance;

  /// The network folder's videos (other devices' downloads and
  /// recordings): copied here for watching offline, or played from there.
  List<NetworkFile> _netFiles = const [];
  String? _netError;
  bool _netLoading = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    unawaited(_service.init().then((_) async {
      await _service.refreshStatus();
      await _loadNetwork();
    }));
  }

  Future<void> _loadNetwork() async {
    if (_service.settings.network == null) return;
    setState(() => _netLoading = true);
    final r = await _service.networkFiles();
    if (!mounted) return;
    setState(() {
      _netLoading = false;
      _netFiles = r.files;
      _netError = r.error;
    });
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _open(RecordingEntry r) async {
    if (r.isDownload) {
      return r.complete ? playDownload(context, r) : downloadMenu(context, r);
    }
    if (r.state == RecState.recording) {
      // Live, from the recorder's tap (PlaybackService.openUrlFor).
      return _push(_liveChannel(r));
    }
    if (r.playable) return _push(_service.channelFor(r));
    return _menu(r);
  }

  Channel _liveChannel(RecordingEntry r) {
    final i = r.channelId.indexOf('::');
    return Channel(
      id: r.channelId,
      rawId: i < 0 ? r.channelId : r.channelId.substring(i + 2),
      playlistId: r.playlistId,
      name: r.channelName,
      group: r.league,
      url: r.url,
      logoUrl: r.channelLogo,
    );
  }

  Future<void> _push(Channel c) => Navigator.of(context)
      .push(PlayerPageRoute(builder: (_) => PlayerScreen(channel: c)));

  Future<void> _menu(RecordingEntry r) async {
    if (r.isDownload) return downloadMenu(context, r);
    final action = await showGlassMenu<String>(
      context: context,
      builder: (context) => SwallowHeldActivate(
        child: GlassMenuDialog(
          title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r.state == RecState.recording) ...[
                  TvMenuTile(
                    autofocus: true,
                    icon: Icons.live_tv,
                    title: tr('Watch live'),
                    subtitle: r.channelName,
                    onTap: () => Navigator.of(context).pop('live'),
                  ),
                  if (r.bytes > 0)
                    TvMenuTile(
                      icon: Icons.replay,
                      title: tr('Play from the start'),
                      subtitle: tr('What has been recorded so far'),
                      onTap: () => Navigator.of(context).pop('play'),
                    ),
                  TvMenuTile(
                    icon: Icons.stop_circle_outlined,
                    title: tr('Stop recording'),
                    subtitle: tr('Keeps what has been recorded'),
                    onTap: () => Navigator.of(context).pop('stop'),
                  ),
                ] else if (r.state == RecState.scheduled ||
                    r.state == RecState.waiting)
                  TvMenuTile(
                    autofocus: true,
                    icon: Icons.event_busy,
                    title: tr('Cancel recording'),
                    subtitle: _when(r),
                    onTap: () => Navigator.of(context).pop('stop'),
                  )
                else if (r.playable)
                  TvMenuTile(
                    autofocus: true,
                    icon: Icons.play_arrow,
                    title: tr('Play'),
                    subtitle: _size(r.bytes),
                    onTap: () => Navigator.of(context).pop('play'),
                  ),
                if (r.state != RecState.scheduled &&
                    r.state != RecState.waiting &&
                    r.state != RecState.recording)
                  TvMenuTile(
                    autofocus: !r.playable,
                    icon: Icons.delete_outline,
                    title: tr('Delete recording'),
                    subtitle: r.bytes > 0
                        ? tr('Frees {size}', {'size': _size(r.bytes)})
                        : tr('Removes it from the list'),
                    onTap: () => Navigator.of(context).pop('delete'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'live':
        await _push(_liveChannel(r));
      case 'play':
        await _push(_service.channelFor(r));
      case 'stop':
        await _service.stop(r);
      case 'delete':
        await _service.delete(r);
    }
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  static String _when(RecordingEntry r) {
    final start = r.startAt;
    final now = DateTime.now();
    final sameDay = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final day = sameDay ? tr('Today') : DateFormat('EEE d MMM').format(start);
    return '$day ${TimeFormat.hm.format(start)}–${TimeFormat.hm.format(r.endAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final all =
        _service.items.where((r) => r.state != RecState.cancelled).toList();
    final now = all
        .where((r) => !r.isDownload && r.state == RecState.recording)
        .toList();
    // Oldest start first: the order the recorder takes them in.
    final downloading = all
        .where((r) =>
            r.isDownload &&
            (r.state == RecState.recording || r.state == RecState.queued))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final upcoming = all
        .where(
            (r) => r.state == RecState.scheduled || r.state == RecState.waiting)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    bool finished(RecordingEntry r) =>
        r.state != RecState.recording &&
        r.state != RecState.queued &&
        r.state != RecState.scheduled &&
        r.state != RecState.waiting;
    final downloads = all.where((r) => r.isDownload && finished(r)).toList();
    final done = all.where((r) => !r.isDownload && finished(r)).toList();
    final auto = _service.autoTeam;
    final offered = _service.networkFilesToOffer(_netFiles);
    final networkBytes =
        all.fold<int>(0, (s, r) => r.onNetwork ? s + r.bytes : s);
    var first = true;
    Widget section(String title, List<RecordingEntry> list) {
      final autofocus = first;
      first = false;
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12, letterSpacing: 1.2, color: Colors.white54)),
            const SizedBox(height: 8),
            Wrap(
              children: [
                for (var i = 0; i < list.length; i++)
                  list[i].isDownload
                      ? _DownloadCard(
                          entry: list[i],
                          autofocus: autofocus && i == 0,
                          status: _status(list[i]),
                          onTap: () => _open(list[i]),
                          onHold: () => _menu(list[i]),
                        )
                      : _RecordingCard(
                          entry: list[i],
                          autofocus: autofocus && i == 0,
                          status: _status(list[i]),
                          onTap: () => _open(list[i]),
                          onHold: () => _menu(list[i]),
                        ),
              ],
            ),
          ],
        ),
      );
    }

    return withTvThemeIfNeeded(
      context,
      (context) => SettingsScaffold(
        title: tr('Recordings'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            if (auto != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Icon(Icons.event_repeat,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                      tr('Recording every {team} game',
                          {'team': auto.teamName}),
                      style: const TextStyle(color: Colors.white70)),
                ]),
              ),
            if (all.isEmpty && offered.isEmpty && !_netLoading)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  '${tr('Nothing recorded yet. Hold OK on a game in {tab} and pick Record, or hold OK on a live channel.', {
                        'tab': AppConstants.sportsTabName
                      })}\n${tr('Downloads: the Download button on a movie or show page.')}',
                  style: const TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ),
            if (now.isNotEmpty) section(tr('Recording now'), now),
            if (downloading.isNotEmpty) section(tr('Downloading'), downloading),
            if (upcoming.isNotEmpty) section(tr('Scheduled'), upcoming),
            if (downloads.isNotEmpty) section(tr('Downloads'), downloads),
            if (done.isNotEmpty) section(tr('Recorded'), done),
            if (_service.settings.network != null)
              _networkSection(offered, autofocus: first),
            if (all.isNotEmpty)
              Text(
                [
                  tr('{used} of {cap} GB used', {
                    'used': _size(_service.usedBytes),
                    'cap': _service.settings.capGb,
                  }),
                  // The cap is this device's; the share has its own disk.
                  if (networkBytes > 0)
                    tr('{size} in the network folder',
                        {'size': _size(networkBytes)}),
                ].join(' · '),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  /// "Network folder": what other devices saved there. OK = Copy to this
  /// device / Play from the network folder.
  Widget _networkSection(List<NetworkFile> files, {required bool autofocus}) {
    Widget note(String text) => Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Text(text,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('On the network folder').toUpperCase(),
              style: const TextStyle(
                  fontSize: 12, letterSpacing: 1.2, color: Colors.white54)),
          const SizedBox(height: 8),
          if (_netLoading && files.isEmpty)
            note(tr('Looking in the network folder…'))
          else if (_netError != null)
            note(tr("The network folder can't be reached: {reason}",
                {'reason': tr(_netError!)}))
          else if (files.isEmpty)
            note(tr(
                'Nothing new there. Downloads and recordings that another device saves there show up here.'))
          else
            Wrap(children: [
              for (var i = 0; i < files.length; i++)
                _DownloadCard(
                  entry: _displayEntry(files[i]),
                  autofocus: autofocus && i == 0,
                  status: _size(files[i].size),
                  icon: Icons.folder_shared_outlined,
                  onTap: () => networkFileMenu(context, files[i]),
                  onHold: () => networkFileMenu(context, files[i]),
                ),
            ]),
        ],
      ),
    );
  }

  /// A network file drawn like a download card (poster, title, show).
  static RecordingEntry _displayEntry(NetworkFile f) => RecordingEntry(
        id: f.path,
        title: f.title,
        league: f.group,
        gameKey: '',
        leagueId: '',
        gameStart: f.modified,
        startAt: f.modified,
        endAt: f.modified,
        channelId: '',
        channelName: '',
        playlistId: '',
        url: '',
        path: f.path,
        kind: 'download',
        poster: f.poster,
        state: RecState.done,
        bytes: f.size,
        totalBytes: f.size,
      );

  String _status(RecordingEntry r) {
    if (r.isDownload) return _downloadStatus(r);
    return switch (r.state) {
      RecState.recording => tr('REC · {size}', {'size': _size(r.bytes)}),
      RecState.queued => tr('Waiting'),
      RecState.scheduled => _when(r),
      RecState.waiting => tr('Waiting for a channel'),
      RecState.done ||
      RecState.stopped =>
        '${DateFormat('EEE d MMM').format(r.gameStart)} · ${_size(r.bytes)}',
      RecState.interrupted =>
        tr('Interrupted · {size}', {'size': _size(r.bytes)}),
      RecState.missed => tr('Missed'),
      RecState.failed => tr('Failed'),
      RecState.cancelled => '',
    };
  }

  String _percent(RecordingEntry r) =>
      r.progress == null ? _size(r.bytes) : '${(r.progress! * 100).floor()}%';

  String _downloadStatus(RecordingEntry r) => switch (r.state) {
        RecState.recording => r.progress == null
            ? _size(r.bytes)
            : '${_percent(r)} · ${_size(r.bytes)} / ${_size(r.totalBytes)}',
        RecState.queued => r.note == 'connection'
            ? tr('Waits for a free connection')
            : tr('Waiting its turn'),
        RecState.scheduled => downloadStartLabel(r.startAt, DateTime.now()),
        RecState.done when r.complete =>
          tr('Downloaded · {size}', {'size': _size(r.bytes)}),
        RecState.interrupted => tr('Interrupted · {pct}', {'pct': _percent(r)}),
        RecState.failed => tr('Failed'),
        RecState.missed => tr('Missed'),
        _ => tr('Stopped · {pct}', {'pct': _percent(r)}),
      };
}

/// A download in the Recordings tab: poster, title, how far it got.
class _DownloadCard extends StatefulWidget {
  const _DownloadCard({
    required this.entry,
    required this.status,
    required this.onTap,
    required this.onHold,
    this.autofocus = false,
    this.icon,
  });

  final RecordingEntry entry;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final bool autofocus;

  /// Instead of the download state's icon (a file in the network folder).
  final IconData? icon;

  @override
  State<_DownloadCard> createState() => _DownloadCardState();
}

class _DownloadCardState extends State<_DownloadCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.entry;
    final active = r.state == RecState.recording;
    final bad = r.state == RecState.failed || r.state == RecState.missed;
    final progress = r.progress;
    final poster = (r.poster?.isEmpty ?? true) ? null : r.poster;
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 8),
      child: HoldToActivate(
        onTap: widget.onTap,
        onHold: widget.onHold,
        child: InkWell(
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          onLongPress: widget.onHold,
          // The border + glow is the focus look (InkWell's grey highlight
          // showed around the unscaled card).
          focusColor: Colors.transparent,
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedScale(
            scale: _focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: Container(
              width: _RecordingCard.width,
              height: _RecordingCard.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                // With a poster, the card is the poster's own colours (a soft
                // copy behind a dark scrim), not the Sports Trak sheen: that
                // turned the whole card a flat gold block (owner photo,
                // 2026-11-10).
                color: poster == null
                    ? (_focused ? null : Colors.white.withValues(alpha: 0.07))
                    : Colors.black,
                gradient: poster == null && _focused
                    ? sportsFocusSheen(scheme)
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _focused ? scheme.primary : Colors.white10,
                    width: _focused ? 2.5 : 1),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 16)
                      ]
                    : null,
              ),
              child: Stack(children: [
                if (poster != null) ...[
                  // A tiny decode stretched over the card reads as a blur
                  // without a blur filter's cost (PosterCard does the same).
                  Positioned.fill(
                    child: HdNetworkImage(
                      url: poster,
                      kind: ImageKind.poster,
                      fit: BoxFit.cover,
                      decodeWidth: 24,
                      errorWidget: (_) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.black.withValues(alpha: 0.78),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 76,
                        height: double.infinity,
                        child: poster == null
                            ? Container(
                                color: Colors.white10,
                                child: const Icon(Icons.movie_outlined,
                                    color: Colors.white38))
                            : HdNetworkImage(
                                url: poster,
                                kind: ImageKind.poster,
                                decodeWidth: 160,
                                fit: BoxFit.cover,
                                errorWidget: (_) =>
                                    Container(color: Colors.white10)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.league.isNotEmpty)
                            Text(r.league.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    letterSpacing: 1,
                                    color: Colors.white54)),
                          Text(r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: _focused
                                      ? scheme.primary
                                      : Colors.white)),
                          const Spacer(),
                          if (progress != null && !r.complete) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: Colors.white12,
                                color: active ? scheme.primary : Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 5),
                          ],
                          Row(children: [
                            Icon(
                                widget.icon ??
                                    (r.complete
                                        ? Icons.download_done_rounded
                                        : active
                                            ? Icons.downloading_rounded
                                            : Icons.download_rounded),
                                size: 14,
                                color: bad ? Colors.redAccent : Colors.white60),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(widget.status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: bad
                                          ? Colors.redAccent
                                          : Colors.white70)),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingCard extends StatefulWidget {
  const _RecordingCard({
    required this.entry,
    required this.status,
    required this.onTap,
    required this.onHold,
    this.autofocus = false,
  });

  final RecordingEntry entry;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final bool autofocus;

  // Same size as a Sports Trak game card.
  static const double width = 268;
  static const double height = 132;

  @override
  State<_RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<_RecordingCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.entry;
    final rec = r.state == RecState.recording;
    final bad = r.state == RecState.failed ||
        r.state == RecState.missed ||
        r.state == RecState.interrupted;

    Widget teamLine(String? logo, String name, String abbr, String? color,
        {String? joiner}) {
      return Row(children: [
        SizedBox(
          width: 22,
          child: joiner == null
              ? const SizedBox()
              : Text(joiner,
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ),
        SportsLogo(url: logo, size: 30, fallback: abbr, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ]);
    }

    final body = r.isChannel
        ? Row(children: [
            SportsLogo(
                url: r.channelLogo,
                size: 52,
                fallback: r.channelName.isEmpty
                    ? 'TV'
                    : r.channelName.substring(0, 1),
                color: null),
            const SizedBox(width: 10),
            Expanded(
              child: Text(r.program.isEmpty ? tr('Live channel') : r.program,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ])
        : r.team2.isEmpty
            // Golf / racing: one line, the event.
            ? teamLine(r.logo, r.team1, r.abbr1, r.color1)
            : Column(children: [
                teamLine(r.logo, r.team1, r.abbr1, r.color1),
                const SizedBox(height: 4),
                teamLine(r.logo2, r.team2, r.abbr2, r.color2, joiner: 'vs'),
              ]);

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 8),
      child: HoldToActivate(
        onTap: widget.onTap,
        onHold: widget.onHold,
        child: InkWell(
          autofocus: widget.autofocus,
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          onLongPress: widget.onHold,
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedScale(
            scale: _focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: Container(
              width: _RecordingCard.width,
              height: _RecordingCard.height,
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
              decoration: BoxDecoration(
                color: _focused ? null : Colors.white.withValues(alpha: 0.07),
                gradient: _focused ? sportsFocusSheen(scheme) : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _focused
                        ? scheme.primary
                        : rec
                            ? Colors.redAccent.withValues(alpha: 0.6)
                            : Colors.white10,
                    width: _focused ? 2.5 : 1),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 16)
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                          (r.isChannel ? r.channelName : r.league)
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1,
                              color: Colors.white54)),
                    ),
                    const SizedBox(width: 6),
                    if (rec)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.redAccent),
                      ),
                    Text(widget.status,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color:
                                rec || bad ? Colors.redAccent : Colors.white)),
                  ]),
                  const Spacer(),
                  body,
                  const Spacer(),
                  if (!r.isChannel && r.channelName.isNotEmpty)
                    Text(r.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
