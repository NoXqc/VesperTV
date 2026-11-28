import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../services/catchup_session.dart';
import '../services/epg_service.dart';
import '../services/live_timeshift.dart';
import '../utils/scrub_steps.dart';
import '../utils/time_format.dart';
import 'gold_tag.dart';

/// The target picked on [DesktopLiveTimeline] (a wall-clock time), null
/// while nothing is picked. The player's Back cancels it first ([cancel]).
class LiveScrubController extends ValueNotifier<DateTime?> {
  LiveScrubController() : super(null);

  /// Drops a target OK hasn't confirmed; true when there was one.
  bool cancel(String why) {
    final t = value;
    if (t == null) return false;
    value = null;
    debugPrint('LiveScrub: cancelled ($why), target was ${liveScrubClock(t)}');
    return true;
  }
}

/// Line 2 of the Apple TV / TV-remote live info bar (computers / iPhone /
/// Apple TV player): the programme's start, how far it is, its end; a
/// remote target like Android's `_LiveTimeline` when the channel has
/// catch-up or Live pause & rewind runs ([timeshift]). Up from the bar's
/// buttons reaches it; Left / Right move a marker back in time (Skip
/// buttons steps, a held key's grow: [ScrubSteps]) and float the target's
/// time above it; OK plays there ([onGo]: what's kept first, then
/// catch-up); Back or leaving without OK cancels. Down = back to the
/// buttons ([onDown]). Explicit keys (CLAUDE.md §10 D-pad focus): Left /
/// Right / Up / Down never reach the default traversal.
class DesktopLiveTimeline extends StatefulWidget {
  const DesktopLiveTimeline({
    super.key,
    required this.channel,
    required this.epgId,
    required this.timeshift,
    required this.scrub,
    required this.focusNode,
    required this.onGo,
    this.onDown,
    this.onActivity,
    this.programme,
    this.clock,
  });

  final Channel channel;
  final String epgId;

  /// Live pause & rewind's state (null = off).
  final ValueListenable<TimeshiftState?> timeshift;
  final LiveScrubController scrub;
  final FocusNode focusNode;

  /// OK on a target.
  final void Function(DateTime target) onGo;
  final VoidCallback? onDown;
  final VoidCallback? onActivity;

  /// The programme on now (tests); null = the guide's.
  final EpgProgram? programme;
  final DateTime Function()? clock;

  @override
  State<DesktopLiveTimeline> createState() => _DesktopLiveTimelineState();
}

class _DesktopLiveTimelineState extends State<DesktopLiveTimeline> {
  late ScrubSteps _steps = ScrubSteps(clock: widget.clock);
  Timer? _tick;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    widget.timeshift.addListener(_changed);
    widget.scrub.addListener(_changed);
    // The bar up to now moves on its own.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _changed());
  }

  @override
  void didUpdateWidget(covariant DesktopLiveTimeline old) {
    super.didUpdateWidget(old);
    if (old.timeshift != widget.timeshift) {
      old.timeshift.removeListener(_changed);
      widget.timeshift.addListener(_changed);
    }
    if (old.scrub != widget.scrub) {
      old.scrub.removeListener(_changed);
      widget.scrub.addListener(_changed);
    }
    if (old.clock != widget.clock) _steps = ScrubSteps(clock: widget.clock);
  }

  @override
  void dispose() {
    widget.timeshift.removeListener(_changed);
    widget.scrub.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  TimeshiftState? get _shift {
    final ts = widget.timeshift.value;
    return ts != null && ts.on ? ts : null;
  }

  bool get _canScrub => widget.channel.hasCatchup || _shift != null;

  /// The time on screen: now, or behind it in what's kept.
  DateTime _playingAt(DateTime now) {
    final ts = _shift;
    return ts == null || ts.atLive ? now : now.subtract(ts.behind);
  }

  DateTime _oldest(DateTime now) => widget.channel.hasCatchup
      ? CatchupSession.oldest(widget.channel, now)
      : now.subtract(_shift?.available ?? Duration.zero);

  void _move(int sign, {required bool repeat}) {
    widget.onActivity?.call();
    final step = _steps.next(repeat: repeat);
    if (step == null) return;
    final now = _now();
    final from = widget.scrub.value ?? _playingAt(now);
    var next = from.add(step * sign);
    final oldest = _oldest(now);
    if (next.isBefore(oldest)) next = oldest;
    if (next.isAfter(now)) next = now;
    widget.scrub.value = next;
    _say('LiveScrub: step ${sign < 0 ? '-' : '+'}${step.inSeconds} s -> '
        '${liveScrubClock(next)} (${_clock(now.difference(next))} behind '
        'live${next == oldest ? ', the oldest' : ''})');
  }

  void _go() {
    final target = widget.scrub.value;
    _steps.reset();
    if (target == null) return;
    widget.scrub.value = null;
    debugPrint('LiveScrub: OK at ${liveScrubClock(target)} '
        '(${_clock(_now().difference(target))} behind live)');
    widget.onGo(target);
  }

  static final _ok = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  static final _back = {
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _move(-1, repeat: event is KeyRepeatEvent);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _move(1, repeat: event is KeyRepeatEvent);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent) {
        widget.scrub.cancel('Down');
        _steps.reset();
        widget.onDown?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    if (_ok.contains(key)) {
      if (event is KeyDownEvent) _go();
      return KeyEventResult.handled;
    }
    if (_back.contains(key) && widget.scrub.value != null) {
      if (event is KeyDownEvent) {
        widget.scrub.cancel('Back');
        _steps.reset();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    var programme = widget.programme;
    if (programme == null) {
      try {
        programme = context.watch<EpgService>().getCurrentProgram(widget.epgId);
      } on ProviderNotFoundException {
        programme = null;
      }
    }
    final shift = _shift;
    // No guide listing: what's kept is the bar (Android hid it).
    final DateTime start, end;
    if (programme != null &&
        programme.stop.difference(programme.start).inSeconds > 0) {
      start = programme.start;
      end = programme.stop;
    } else if (shift != null) {
      start = now.subtract(shift.window);
      end = now;
    } else {
      return const SizedBox.shrink();
    }
    final span = end.difference(start).inSeconds;
    double at(DateTime t) =>
        (t.difference(start).inSeconds / span).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;
    final focused = widget.focusNode.hasFocus;
    final target = widget.scrub.value;
    final playing = _playingAt(now);
    final behind = shift != null && !shift.atLive;
    final hm = TimeFormat.hm;
    const timeStyle = TextStyle(color: Colors.white70, fontSize: 13);
    final bar = SizedBox(
      height: 18,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            Container(
                height: focused ? 5 : 3,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3))),
            Container(
                width: w * at(now),
                height: focused ? 5 : 3,
                decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(3))),
            if (target != null || focused || behind)
              Positioned(
                key: const ValueKey('live-scrub-marker'),
                left: (w * at(target ?? playing)) - (focused ? 8 : 6),
                child: Container(
                  width: focused ? 16 : 12,
                  height: focused ? 16 : 12,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary, width: 2)),
                ),
              ),
          ],
        );
      }),
    );
    final row = Stack(clipBehavior: Clip.none, children: [
      Row(children: [
        Text(hm.format(start), style: timeStyle),
        const SizedBox(width: 10),
        Expanded(child: bar),
        const SizedBox(width: 10),
        Text(hm.format(end), style: timeStyle),
      ]),
      if (target != null)
        _Note(
          key: const ValueKey('live-scrub-note'),
          at: at(target),
          text: '${hm.format(target)}  (−${_clock(now.difference(target))})',
        )
      else if (focused && _canScrub)
        _Note(
            at: behind ? at(playing) : 1,
            text: shift != null && !widget.channel.hasCatchup
                ? tr('◀ Rewind')
                : tr('◀ Catch-up'),
            color: scheme.primary),
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: _canScrub,
        skipTraversal: !_canScrub,
        onKeyEvent: _onKey,
        onFocusChange: (has) {
          if (has) {
            debugPrint(
                'LiveScrub: focus in (${widget.channel.hasCatchup ? 'catch-up ${widget.channel.catchupDays} day(s)' : 'no catch-up'}'
                '${shift == null ? '' : ', ${_clock(shift.available)} kept, ${_clock(shift.behind)} behind live'})');
          } else {
            widget.scrub.cancel('focus left');
            _steps.reset();
            debugPrint('LiveScrub: focus out');
          }
          setState(() {});
        },
        child: row,
      ),
    );
  }

  static final _said = <String, DateTime>{};

  /// One line a second at most (held keys repeat up to 20 a second).
  static void _say(String line) {
    final now = DateTime.now();
    final last = _said['step'];
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _said['step'] = now;
    debugPrint(line);
  }

  static String _clock(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}

/// "14:03:27" for Send log.
String liveScrubClock(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

/// The timeline's label floating above it ([at]: 0 = left end, 1 = right).
class _Note extends StatelessWidget {
  const _Note({super.key, required this.at, required this.text, this.color});

  final double at;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        bottom: 26,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment(at.clamp(0.0, 1.0) * 2 - 1, 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color ?? Colors.white)),
            ),
          ),
        ),
      );
}

/// "−1:23" (gold) while Live pause & rewind is behind live, or where the
/// gathered skip presses will land; nothing at live. Android's
/// `TimeshiftBehindTag` on the media_kit player.
class DesktopTimeshiftTag extends StatelessWidget {
  const DesktopTimeshiftTag({
    super.key,
    required this.state,
    required this.target,
    this.fontSize = 12,
    this.margin = const EdgeInsets.only(left: 8),
  });

  final ValueListenable<TimeshiftState?> state;
  final ValueListenable<Duration?> target;
  final double? fontSize;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration?>(
        valueListenable: target,
        builder: (context, gathering, _) =>
            ValueListenableBuilder<TimeshiftState?>(
          valueListenable: state,
          builder: (context, ts, _) {
            if (ts == null || !ts.on) return const SizedBox.shrink();
            final behind = gathering ?? ts.behind;
            if (gathering == null && ts.atLive) return const SizedBox.shrink();
            return GoldTag(
              key: const ValueKey('timeshift-tag'),
              label: behind <= TimeshiftState.liveEdge
                  ? tr('LIVE')
                  : LiveTimeshift.behindLabel(behind),
              fontSize: fontSize,
              margin: margin,
            );
          },
        ),
      );
}
