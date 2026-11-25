import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../services/live_timeshift.dart';

// Overlays both TV players draw over the picture (Android's PlayerScreen
// and the Apple TV player, DesktopPlayerScreen): the same card and cue on
// both, so the two TV apps look the same (owner, 2026-11-20).

/// A Netflix-style "Up Next" card in the corner of the screen once an
/// episode is close to ending — [PlaybackService] already auto-advances
/// at 30 seconds remaining; this surfaces that instead of letting it
/// happen silently, and lets the user jump immediately or cancel it for
/// this episode. Reads the position once a second ([progress]).
class UpNextBubble extends StatelessWidget {
  const UpNextBubble({
    super.key,
    required this.mode,
    required this.progress,
    required this.nextChannel,
    required this.onPlayNow,
    required this.onDismiss,
  });

  /// [StorageService.getUpNextMode]: early / end / off (no bubble).
  final String mode;

  /// Where the player is (Android's controller, the Apple TV player's
  /// mpv): both players share this card.
  final ({Duration position, Duration duration}) Function() progress;
  final Channel? nextChannel;
  final VoidCallback onPlayNow;
  final VoidCallback onDismiss;

  static const _showAt = Duration(seconds: 45);
  static const _autoAdvanceAt = Duration(seconds: 30);

  // Every branch below returns a `Positioned`, never a bare widget — this
  // sits directly in PlayerScreen's Stack (not wrapped in Positioned at
  // the call site), and Stack's sizing rule is "size to fill the available
  // space only if EVERY child is Positioned; otherwise size to fit the
  // non-positioned children instead". A single bare `SizedBox.shrink()`
  // here (the "nothing to show" case, which is most of the time) used to
  // demote the whole Stack to a non-positioned-children layout, and since
  // that shrink box's natural size is zero, the entire Stack — video
  // included — collapsed to 0x0 and painted nothing. This was the actual
  // cause of the black fullscreen screen; confirmed via a LayoutBuilder +
  // RenderBox size dump (NOX_DIAG) showing bounded incoming constraints
  // but a 0x0 resulting Stack size.
  static const _hidden = Positioned(
      right: 24, bottom: 110, width: 0, height: 0, child: SizedBox.shrink());

  static final _ticks =
      Stream<void>.periodic(const Duration(seconds: 1)).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    final next = nextChannel;
    if (next == null || mode == 'off') return _hidden;
    final atEnd = mode == 'end';
    // Once a second, not on every 100 ms position change: it stays hidden
    // until the last minutes, and each change was a frame drawn.
    return StreamBuilder<void>(
      stream: _ticks,
      builder: (context, _) {
        final value = progress();
        final duration = value.duration;
        if (duration <= Duration.zero) return _hidden;
        final remaining = duration - value.position;
        // When the episode ends: the last 15 s count down to the end.
        if (remaining > (atEnd ? const Duration(seconds: 15) : _showAt) ||
            remaining < Duration.zero) {
          return _hidden;
        }

        final countdown = (remaining - (atEnd ? Duration.zero : _autoAdvanceAt))
            .inSeconds
            .clamp(0, 999);
        final hasLogo = next.logoUrl != null && next.logoUrl!.isNotEmpty;

        return Positioned(
          right: 24,
          bottom: 110,
          width: 320,
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: hasLogo
                          ? CachedNetworkImage(
                              imageUrl: next.logoUrl!,
                              fit: BoxFit.cover,
                              // A small logo: decoded small, not at the file's size (CLAUDE.md §10 (6)).
                              memCacheWidth: 192,
                              errorWidget: (_, __, ___) =>
                                  const _FallbackIcon(),
                            )
                          : const _FallbackIcon(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('Up Next'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text(
                          next.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countdown > 0
                              ? tr('Playing in {countdown}s',
                                  {'countdown': countdown})
                              : tr('Playing now...'),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 30),
                        tooltip: tr('Play now'),
                        onPressed: onPlayNow,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 18),
                        tooltip: tr('Dismiss'),
                        onPressed: onDismiss,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: const Icon(Icons.movie, color: Colors.white38, size: 28),
    );
  }
}

/// Where the remote's Fast-forward / Rewind will land: the target time
/// and the jump (movies, episodes, catch-up), or how far back from now
/// (live rewind).
/// Live pause & rewind: where the gathered skip presses land ("−1:15"
/// behind live, or LIVE), until the jump.
class TimeshiftCue extends StatelessWidget {
  const TimeshiftCue({super.key, required this.target, required this.from});

  /// Behind live after the jump.
  final Duration target;

  /// Behind live now.
  final Duration from;

  @override
  Widget build(BuildContext context) {
    final back = target > from;
    final live = target <= TimeshiftState.liveEdge;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(back ? Icons.fast_rewind : Icons.fast_forward,
              color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          Text(live ? tr('LIVE') : LiveTimeshift.behindLabel(target),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SkipCue extends StatelessWidget {
  const SkipCue(
      {super.key,
      required this.target,
      required this.live,
      required this.position,
      required this.duration});

  final Duration target;
  final bool live;
  final Duration position;
  final Duration duration;

  static String _clock(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final forward = !live && target >= position;
    final text = live
        ? tr('{m} min back', {'m': target.inMinutes})
        : '${_clock(target)} / ${_clock(duration)}   '
            '(${forward ? '+' : '−'}${_clock((target - position).abs())})';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(forward ? Icons.fast_forward : Icons.fast_rewind,
              color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
