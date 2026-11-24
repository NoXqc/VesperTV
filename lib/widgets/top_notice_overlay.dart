import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/refined_finish.dart';
import 'popup_surface.dart';

/// One message for [TopNoticeOverlay].
class TopNoticeMessage {
  const TopNoticeMessage(this.id, this.text, this.duration);
  final int id;
  final String text;
  final Duration duration;
}

/// A short message that rolls down from the top of the screen: the
/// player's Sources and Tuliprox messages. A snackbar at the bottom covered
/// the player bar, its options row and the Sources list (owner, 2026-11-23).
class TopNotice {
  TopNotice._();

  static final ValueNotifier<TopNoticeMessage?> current = ValueNotifier(null);
  static int _next = 0;

  /// Shows [text] for [duration]; a newer message replaces it.
  static void show(String text,
      {Duration duration = const Duration(seconds: 5)}) {
    current.value = TopNoticeMessage(++_next, text, duration);
  }
}

/// App-wide, like the goal card: never takes focus or touches, so the
/// remote keeps working on whatever is under it.
class TopNoticeOverlay extends StatefulWidget {
  const TopNoticeOverlay({super.key});

  @override
  State<TopNoticeOverlay> createState() => _TopNoticeOverlayState();
}

class _TopNoticeOverlayState extends State<TopNoticeOverlay> {
  TopNoticeMessage? _shown;
  bool _visible = false;
  Timer? _hide;

  static const _slide = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();
    TopNotice.current.addListener(_onMessage);
  }

  @override
  void dispose() {
    TopNotice.current.removeListener(_onMessage);
    _hide?.cancel();
    super.dispose();
  }

  void _onMessage() {
    final m = TopNotice.current.value;
    if (m == null || !mounted) return;
    _hide?.cancel();
    final rollIn = _shown == null;
    setState(() {
      _shown = m;
      _visible = !rollIn;
    });
    if (rollIn) {
      // Built above the screen first, then slides down.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shown?.id == m.id) setState(() => _visible = true);
      });
    }
    _hide = Timer(m.duration, () {
      if (mounted && _shown?.id == m.id) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _shown;
    if (m == null) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final clear = transparentPopups(context);
    return IgnorePointer(
      child: ExcludeFocus(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, -1.6),
                duration: _slide,
                curve: Curves.easeOutCubic,
                onEnd: () {
                  // Gone from the tree once rolled back up: nothing left
                  // to repaint.
                  if (!_visible && mounted) setState(() => _shown = null);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      key: const ValueKey('top-notice'),
                      color: clear
                          ? Colors.transparent
                          : RefinedFinish.surface(
                              context, const Color(0xFA15171C)),
                      elevation: clear ? 0 : 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: clear
                            ? BorderSide.none
                            : BorderSide(color: accent.withValues(alpha: 0.55)),
                      ),
                      child: PopupTextShadow(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: Text(m.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.35)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
