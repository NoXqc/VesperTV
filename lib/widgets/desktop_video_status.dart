import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../services/app_preferences.dart';

/// Android's video pane shows a spinner until the stream gives a picture,
/// and while it waits for data. The same over a media_kit picture on a TV
/// remote (Apple TV: the full-screen player and the guide's preview), where
/// a stream that opened slowly was plain black (owner, 2026-11-20: both TV
/// apps must look the same).
class DesktopBufferingSpinner extends StatefulWidget {
  const DesktopBufferingSpinner({super.key, required this.player});

  final Player player;

  @override
  State<DesktopBufferingSpinner> createState() =>
      _DesktopBufferingSpinnerState();
}

class _DesktopBufferingSpinnerState extends State<DesktopBufferingSpinner> {
  List<StreamSubscription<Object?>> _subs = const [];
  late bool _waiting;

  @override
  void initState() {
    super.initState();
    _waiting = _isWaiting();
    _subscribe();
  }

  @override
  void didUpdateWidget(DesktopBufferingSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player == widget.player) return;
    _cancel();
    _waiting = _isWaiting();
    _subscribe();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _subscribe() {
    final stream = widget.player.stream;
    _subs = [
      stream.width.listen((_) => _update()),
      stream.buffering.listen((_) => _update()),
      stream.playing.listen((_) => _update()),
      stream.position.listen((_) => _update()),
    ];
  }

  void _cancel() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs = const [];
  }

  /// No picture yet, or waiting for data; a stream with sound only counts
  /// as playing once it has played 2 s.
  bool _isWaiting() {
    final s = widget.player.state;
    if (s.buffering) return true;
    if (s.width != null) return false;
    return !(s.playing && s.position > const Duration(seconds: 2));
  }

  void _update() {
    final waiting = _isWaiting();
    if (mounted && waiting != _waiting) setState(() => _waiting = waiting);
  }

  @override
  Widget build(BuildContext context) => _waiting
      ? const IgnorePointer(child: Center(child: CircularProgressIndicator()))
      : const SizedBox.shrink();
}

/// A media_kit picture with [DesktopBufferingSpinner] over it on a TV
/// remote (Apple TV: Home's mini player, Sports Trak's player); a computer
/// keeps the plain picture.
class DesktopVideoWithSpinner extends StatelessWidget {
  const DesktopVideoWithSpinner(
      {super.key, required this.video, required this.player});

  final Widget video;
  final Player player;

  @override
  Widget build(BuildContext context) {
    if (!(context.read<AppPreferences?>()?.isTelevision ?? false)) {
      return video;
    }
    return Stack(fit: StackFit.expand, children: [
      video,
      DesktopBufferingSpinner(player: player),
    ]);
  }
}
