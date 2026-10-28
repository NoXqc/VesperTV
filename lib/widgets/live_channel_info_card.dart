import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/catchup_session.dart';
import '../services/epg_service.dart';
import '../services/playlist_manager.dart';
import '../utils/time_format.dart';
import 'gold_tag.dart';

/// Compact live/catch-up information, with the schedule action inside its header.
/// The player's existing node/key handler still owns all remote navigation.
class LiveChannelInfoCard extends StatelessWidget {
  const LiveChannelInfoCard(
      {super.key,
      required this.channel,
      required this.scheduleFocus,
      required this.onScheduleKey,
      required this.onSchedule,
      this.at,
      this.touch = false});
  final Channel channel;
  final DateTime? at;
  final FocusNode scheduleFocus;
  final FocusOnKeyEventCallback onScheduleKey;
  final VoidCallback onSchedule;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final epg = context.watch<EpgService>();
    final program = at == null
        ? epg.getCurrentProgram(channel.epgId)
        : CatchupSession.programmeAt(epg.getPrograms(channel.epgId), at!);
    final playlist = context
        .watch<PlaylistManager>()
        .playlistNameFor(channel.playlistId)
        .trim();
    final now = at ?? DateTime.now();
    final logo = channel.logoUrl;
    return Container(
      key: const ValueKey('live-info-card'),
      constraints: const BoxConstraints(maxWidth: 620),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IgnorePointer(
            child: SizedBox(
                width: 40,
                height: 40,
                child: logo != null && logo.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logo,
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.tv, color: Colors.white54))
                    : const Icon(Icons.tv, color: Colors.white54))),
        const SizedBox(width: 10),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final inline = constraints.maxWidth >= 460 &&
              MediaQuery.textScalerOf(context).scale(12) <= 16;
          final action = _ScheduleAction(
              focusNode: scheduleFocus,
              onKey: onScheduleKey,
              onTap: onSchedule,
              touch: touch);
          final progress = LinearProgressIndicator(
              minHeight: 3,
              value: program != null && program.stop.isAfter(program.start)
                  ? (now.difference(program.start).inSeconds /
                          program.stop.difference(program.start).inSeconds)
                      .clamp(0.0, 1.0)
                  : 0);
          return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600))),
                  if (playlist.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: GoldTag(label: playlist, compact: true))),
                  ],
                  if (inline) ...[const SizedBox(width: 10), action],
                ]),
                if (program == null)
                  Text(tr('No program data available'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12))
                else ...[
                  Text(program.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 3),
                  Flex(
                      direction: inline ? Axis.horizontal : Axis.vertical,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: inline
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            '${TimeFormat.hm.format(program.start)} - ${TimeFormat.hm.format(program.stop)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        SizedBox(
                            width: inline ? 10 : 0, height: inline ? 0 : 3),
                        if (inline) Expanded(child: progress) else progress,
                      ]),
                  if (program.description?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 3),
                    Text(program.description!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ],
                if (!inline) ...[
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: action)
                ],
              ]);
        })),
      ]),
    );
  }
}

class _ScheduleAction extends StatelessWidget {
  const _ScheduleAction(
      {required this.focusNode,
      required this.onKey,
      required this.onTap,
      required this.touch});
  final FocusNode focusNode;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final bool touch;
  @override
  Widget build(BuildContext context) => Focus(
      focusNode: focusNode,
      onKeyEvent: onKey,
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        final accent = Theme.of(context).colorScheme.primary;
        return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              key: const ValueKey('player-schedule-control'),
              constraints:
                  BoxConstraints(minHeight: touch ? 44 : 28, maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: focused
                      ? Color.lerp(Colors.black, accent, 0.3)
                      : Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: focused ? accent : Colors.white24, width: 1.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_note,
                    size: 14, color: focused ? accent : Colors.white70),
                const SizedBox(width: 5),
                Flexible(
                    child: Text(tr('Channel schedule'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: focused ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_up,
                    size: 14, color: Colors.white54),
              ]),
            ));
      }));
}
