import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../services/catchup_session.dart';
import '../services/epg_service.dart';
import '../utils/refined_finish.dart';
import '../utils/time_format.dart';
import 'player_side_panel.dart';

/// The playing channel's schedule in the fullscreen live player (OK, Up to
/// "Channel schedule", OK; owner + a user's TiviMate picture, 2026-10-28):
/// programmes on the left, the selected one's details on the right. Opens
/// on the programme playing; OK on a past programme the channel keeps in
/// catch-up plays it from the start, OK on the one on now goes back to
/// live. Back closes it (PlayerScreen's PopScope).
///
/// One Focus node, the selected row only drawn highlighted (no node per
/// row, CLAUDE.md §10); the selection is kept by start time, so rows
/// arriving later (lazy guide load) don't move it.
class ChannelSchedulePanel extends StatefulWidget {
  const ChannelSchedulePanel({
    super.key,
    required this.channel,
    required this.onClose,
    required this.onCatchup,
    required this.onLive,
    this.at,
  });

  /// The live channel (catch-up's own live channel while it plays).
  final Channel channel;

  /// Catch-up playhead; null = live.
  final DateTime? at;
  final VoidCallback onClose;

  /// Plays [Channel]'s catch-up from a programme's start.
  final void Function(DateTime start) onCatchup;

  /// Back to the live channel (from catch-up).
  final VoidCallback onLive;

  @override
  State<ChannelSchedulePanel> createState() => _ChannelSchedulePanelState();
}

class _ChannelSchedulePanelState extends State<ChannelSchedulePanel> {
  static const double _rowHeight = 56;

  final FocusNode _focus = FocusNode(debugLabel: 'channel-schedule');
  final ScrollController _scroll = ScrollController();

  /// Start of the selected programme.
  DateTime? _selected;

  /// Row count when the selection was last centred: rows arriving later
  /// re-centre it, a plain move only keeps it on screen.
  int _centredFor = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  DateTime get _playhead => widget.at ?? DateTime.now();

  List<EpgProgram> _programmes(EpgService epg) =>
      epg.getPrograms(widget.channel.epgId);

  int _indexOf(List<EpgProgram> list) {
    if (list.isEmpty) return -1;
    final sel = _selected;
    if (sel != null) {
      final i = list.indexWhere((p) => p.start == sel);
      if (i >= 0) return i;
    }
    final t = _playhead;
    final on = list.indexWhere((p) => !p.start.isAfter(t) && p.stop.isAfter(t));
    if (on >= 0) return on;
    final next = list.indexWhere((p) => p.start.isAfter(t));
    return next >= 0 ? next : list.length - 1;
  }

  bool _replayable(EpgProgram p, DateTime now) =>
      widget.channel.hasCatchup &&
      p.start.isBefore(now) &&
      !p.start.isBefore(CatchupSession.oldest(widget.channel, now));

  void _move(List<EpgProgram> list, int step) {
    final i = _indexOf(list);
    if (i < 0) return;
    final next = (i + step).clamp(0, list.length - 1);
    if (next == i) return;
    setState(() => _selected = list[next].start);
  }

  void _activate(List<EpgProgram> list) {
    final i = _indexOf(list);
    if (i < 0) return;
    final p = list[i];
    final now = DateTime.now();
    final t = _playhead;
    final playing = !p.start.isAfter(t) && p.stop.isAfter(t);
    final onNow = !p.start.isAfter(now) && p.stop.isAfter(now);
    if (playing) {
      widget.onClose();
    } else if (onNow) {
      widget.onClose();
      widget.onLive();
    } else if (_replayable(p, now)) {
      widget.onClose();
      widget.onCatchup(p.start);
    }
  }

  KeyEventResult _onKey(List<EpgProgram> list, KeyEvent event) {
    final key = event.logicalKey;
    final select = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
    final arrow = key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    if (!select && !arrow && key != LogicalKeyboardKey.escape) {
      // Play/Pause, CH+/CH-… reach the player.
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onClose();
    } else if (select) {
      // Down only: the OK that opened this mustn't play a row.
      if (event is KeyDownEvent) _activate(list);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(list, -1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _move(list, 1);
    }
    return KeyEventResult.handled;
  }

  /// Keeps the selected row on screen — jumpTo, never animateTo (§10).
  void _keepVisible(int index, int count) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || index < 0) return;
      final pos = _scroll.position;
      final top = index * _rowHeight;
      if (_centredFor != count) {
        _centredFor = count;
        _scroll.jumpTo((top - (pos.viewportDimension - _rowHeight) / 2)
            .clamp(0.0, pos.maxScrollExtent));
      } else if (top < pos.pixels) {
        _scroll.jumpTo(top);
      } else if (top + _rowHeight > pos.pixels + pos.viewportDimension) {
        _scroll.jumpTo((top + _rowHeight - pos.viewportDimension)
            .clamp(0.0, pos.maxScrollExtent));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final epg = context.watch<EpgService>();
    return ValueListenableBuilder<int>(
      valueListenable: epg.guideRowsLoaded,
      builder: (context, _, __) {
        final list = _programmes(epg);
        final index = _indexOf(list);
        _keepVisible(index, list.length);
        final width = MediaQuery.sizeOf(context).width;
        final panelWidth = width < PlayerSidePanel.width / 0.88
            ? width * 0.88
            : PlayerSidePanel.width;
        return Focus(
          focusNode: _focus,
          onKeyEvent: (_, e) => _onKey(list, e),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: panelWidth,
                child: GestureDetector(
                  onTap: () {},
                  child: _buildList(context, list, index),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  // Touch: a tap beside the panel closes it.
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: index < 0 || width < 720
                      ? const SizedBox.expand()
                      : Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 24, 0),
                            child: _Details(
                                programme: list[index],
                                playhead: _playhead,
                                replayable:
                                    _replayable(list[index], DateTime.now())),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, List<EpgProgram> list, int index) {
    final accent = Theme.of(context).colorScheme.primary;
    final logo = widget.channel.logoUrl;
    final now = DateTime.now();
    final day = index >= 0 ? list[index].start : now;
    final sameDay =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return Material(
      color:
          RefinedFinish.surface(context, Colors.black.withValues(alpha: 0.62)),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: (logo != null && logo.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: logo,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.tv, color: Colors.white54))
                        : const Icon(Icons.tv, color: Colors.white54),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.channel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        Text(
                            sameDay
                                ? tr('Today')
                                : DateFormat.MMMEd().format(day),
                            style: TextStyle(color: accent, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(tr('No program data available'),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: list.length,
                      itemExtent: _rowHeight,
                      itemBuilder: (context, i) =>
                          _row(list, i, i == index, accent, now),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                  tr('▲ ▼ programmes  ·  OK to watch  ·  Back to close'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      List<EpgProgram> list, int i, bool selected, Color accent, DateTime now) {
    final p = list[i];
    final t = _playhead;
    final playing = !p.start.isAfter(t) && p.stop.isAfter(t);
    final past = !p.stop.isAfter(now);
    final replay = _replayable(p, now) && !playing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        canRequestFocus: false,
        onTap: () {
          setState(() => _selected = p.start);
          _activate(list);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? Color.lerp(Colors.black, accent, 0.25)
                : Colors.transparent,
            border: Border.all(
                color: selected ? accent : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(TimeFormat.hm.format(p.start),
                    maxLines: 1,
                    style: TextStyle(
                        color: playing
                            ? accent
                            : past
                                ? Colors.white54
                                : Colors.white70,
                        fontSize: 14)),
              ),
              Expanded(
                child: Text(p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: playing
                            ? accent
                            : past && !replay
                                ? Colors.white60
                                : Colors.white,
                        fontSize: 15,
                        fontWeight:
                            playing ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (playing)
                Icon(Icons.play_arrow_rounded, color: accent, size: 20)
              else if (replay)
                const Icon(Icons.history, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selected programme: title, day + time, length, progress when on,
/// the full description and what OK does.
class _Details extends StatelessWidget {
  const _Details(
      {required this.programme,
      required this.playhead,
      required this.replayable});

  final EpgProgram programme;
  final DateTime playhead;
  final bool replayable;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final now = DateTime.now();
    final accent = Theme.of(context).colorScheme.primary;
    final minutes = p.stop.difference(p.start).inMinutes;
    final playing = !p.start.isAfter(playhead) && p.stop.isAfter(playhead);
    final onNow = !p.start.isAfter(now) && p.stop.isAfter(now);
    final hint = playing
        ? null
        : onNow
            ? tr('On now  ·  OK to watch live')
            : replayable
                ? tr('Catch-up  ·  OK to watch from the start')
                : p.start.isAfter(now)
                    ? tr('Upcoming')
                    : null;
    final progress = playing && p.stop.isAfter(p.start)
        ? (playhead.difference(p.start).inSeconds /
                p.stop.difference(p.start).inSeconds)
            .clamp(0.0, 1.0)
        : null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        // Like the info card: the picture shows through.
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                  '${TimeFormat.dayTime(p.start)} - ${TimeFormat.hm.format(p.stop)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 10),
              if (progress != null) ...[
                Expanded(child: LinearProgressIndicator(value: progress)),
                const SizedBox(width: 10),
              ],
              Text(tr('{m} min', {'m': minutes}),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          if (p.description != null && p.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p.description!.trim(),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(hint, style: TextStyle(color: accent, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
