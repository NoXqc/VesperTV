import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';
import '../utils/time_format.dart';

/// Settings > Interface > Clock in full screen: the time in a small
/// see-through pill in the full-screen player's top-right corner (owner,
/// 2026-11-12). Android/TV and Windows players. A [Positioned], so it can
/// sit straight in the players' all-Positioned Stacks.
class PlayerClockPill extends StatefulWidget {
  const PlayerClockPill({super.key, required this.top, this.visible = true});

  /// Height the pill takes, for overlays placed under it.
  static const double height = 36;

  final double top;

  /// False while a top bar with its own clock shows (touch layouts).
  final bool visible;

  @override
  State<PlayerClockPill> createState() => _PlayerClockPillState();
}

class _PlayerClockPillState extends State<PlayerClockPill>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  /// One redraw per minute, on the minute (no ticker running between).
  void _schedule() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    _timer = Timer(
        const Duration(minutes: 1) -
            Duration(
                seconds: now.second,
                milliseconds: now.millisecond,
                microseconds: now.microsecond), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _schedule();
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppPreferences, bool>((prefs) => prefs.use24h);
    return Positioned(
      top: widget.top,
      right: 16,
      child: SafeArea(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: widget.visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: RepaintBoundary(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Text(
                  TimeFormat.hm.format(DateTime.now()),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
