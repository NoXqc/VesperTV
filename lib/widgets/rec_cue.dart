import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/sports.dart';
import '../services/recording_service.dart';

/// The red recording cue: a dot by a channel that is being recorded now,
/// a "● REC" pill in the player and on Sports Trak games (outlined dot when
/// the game is only scheduled). Nothing on devices without recording.
class RecDot extends StatelessWidget {
  const RecDot({super.key, required this.channel, this.size = 8});

  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!RecordingService.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: RecordingService.instance,
      builder: (context, _) {
        if (RecordingService.instance.recordingOf(channel) == null) {
          return const SizedBox.shrink();
        }
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Colors.redAccent),
        );
      },
    );
  }
}

/// "● REC" while [channel] (or [game]) records; for a game also the
/// scheduled look (outlined dot). Give one of the two.
class RecPill extends StatelessWidget {
  const RecPill({super.key, this.channel, this.game, this.small = false})
      : assert(channel != null || game != null);

  final Channel? channel;
  final SportsGame? game;

  /// Game cards: tighter, to fit beside the league name.
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (!RecordingService.supported) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: RecordingService.instance,
      builder: (context, _) {
        final service = RecordingService.instance;
        final RecState? state = channel != null
            ? service.recordingOf(channel!)?.state
            : service.entryFor(game!)?.state;
        final recording = state == RecState.recording;
        final scheduled =
            state == RecState.scheduled || state == RecState.waiting;
        if (!recording && !scheduled) return const SizedBox.shrink();
        final dot = small ? 7.0 : 8.0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
              horizontal: small ? 5 : 7, vertical: small ? 1.5 : 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(small ? 8 : 6),
            border: Border.all(
                color: recording ? Colors.redAccent : Colors.white38, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recording ? Colors.redAccent : null,
                  border: recording
                      ? null
                      : Border.all(color: Colors.redAccent, width: 1.4),
                ),
              ),
              SizedBox(width: small ? 3 : 4),
              Text(
                'REC',
                style: TextStyle(
                    color: recording ? Colors.redAccent : Colors.white70,
                    fontSize: small ? 9.5 : 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    height: 1.1),
              ),
            ],
          ),
        );
      },
    );
  }
}
