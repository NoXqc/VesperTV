import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../utils/video_quality.dart';
import 'data_pool_card.dart';

/// The Windows player bar's badges, like Android's quality / FPS / audio
/// channel pills: HD / FHD / 4K from the decoded picture
/// ([qualityLabelForTrack]), its frame rate, and 5.1 / 7.1 sound. Read
/// from mpv every 5 s (no event for a mid-stream change). Hidden while
/// nothing is reported.
class DesktopQualityBadges extends StatefulWidget {
  const DesktopQualityBadges({super.key, required this.player});

  final Player player;

  @override
  State<DesktopQualityBadges> createState() => _DesktopQualityBadgesState();
}

class _DesktopQualityBadgesState extends State<DesktopQualityBadges> {
  String? _quality;
  int? _fps;
  String? _channels;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<String> _get(NativePlayer native, String name) async {
    try {
      return (await native.getProperty(name)).trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _refresh() async {
    final native = widget.player.platform;
    if (native is! NativePlayer) return;
    final w = int.tryParse(await _get(native, 'video-params/w'));
    final h = int.tryParse(await _get(native, 'video-params/h'));
    final fps = double.tryParse(await _get(native, 'container-fps')) ??
        double.tryParse(await _get(native, 'estimated-vf-fps'));
    final channels =
        int.tryParse(await _get(native, 'audio-params/channel-count'));
    final quality =
        h == null ? null : qualityLabelForTrack(height: h, width: w);
    final fpsLabel = fps == null || fps <= 0 ? null : fps.round();
    // Stereo / mono is the common case: no badge (same as Android).
    final channelsLabel = channels == null || channels <= 2
        ? null
        : DataPoolCard.channelsName(channels);
    if (!mounted) return;
    if (quality != _quality || fpsLabel != _fps || channelsLabel != _channels) {
      setState(() {
        _quality = quality;
        _fps = quality == null ? null : fpsLabel;
        _channels = channelsLabel;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glow = Color.lerp(scheme.primary, scheme.secondary, 0.5)!;
    final pills = [
      if (_quality case final q?) q,
      if (_fps case final f?) '$f FPS',
      if (_channels case final c?) c,
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, text) in pills.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          _Pill(text, glow: glow),
        ],
      ],
    );
  }
}

/// Same pill as Android's `_InfoPill` (player_controls.dart).
class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.glow});

  final String text;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: glow, width: 1),
        boxShadow: [
          BoxShadow(
              color: glow.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 0.5),
        ],
      ),
      child: Text(text,
          style: TextStyle(
              color: glow,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }
}
