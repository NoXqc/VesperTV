import 'package:flutter/material.dart';

/// How far one tap of the skip buttons jumps, and the remote's Rewind /
/// Fast-forward (owner, 2026-11-25: "-30/+30 or -15/+15, it could also apply
/// to our normal -/+10 skip button"). Settings > Playback > Skip buttons;
/// movies, episodes, catch-up and Live pause & rewind all use it. Set from
/// [StorageService.getSkipSeconds] at startup and on change.
class SkipStep {
  SkipStep._();

  static const choices = [5, 10, 15, 30, 60];
  static const defaultSeconds = 10;

  static int _seconds = defaultSeconds;
  static int get seconds => _seconds;
  static set seconds(int s) {
    _seconds = choices.contains(s) ? s : defaultSeconds;
    changes.value = _seconds;
  }

  /// [seconds] as it changes (the options row's Skip tile shows it).
  static final ValueNotifier<int> changes = ValueNotifier(defaultSeconds);

  static Duration get tap => Duration(seconds: _seconds);

  /// Material's own icon for 5 / 10 / 30, else null ([SkipIcon] draws one).
  static IconData? builtinIcon({required bool forward}) => switch (_seconds) {
        5 => forward ? Icons.forward_5 : Icons.replay_5,
        10 => forward ? Icons.forward_10 : Icons.replay_10,
        30 => forward ? Icons.forward_30 : Icons.replay_30,
        _ => null,
      };
}

/// The skip button's glyph for [SkipStep.seconds]: Material's replay_10 /
/// forward_10 family where it exists, else the round arrow with the number
/// inside (15, 60), drawn the same size.
class SkipIcon extends StatelessWidget {
  const SkipIcon(
      {super.key, required this.forward, this.size = 24, this.color});

  final bool forward;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final builtin = SkipStep.builtinIcon(forward: forward);
    final c = color ?? IconTheme.of(context).color;
    if (builtin != null) return Icon(builtin, size: size, color: c);
    final arrow = Icon(Icons.replay, size: size, color: c);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        forward ? Transform.flip(flipX: true, child: arrow) : arrow,
        Padding(
          padding: EdgeInsets.only(top: size * 0.12),
          child: Text('${SkipStep.seconds}',
              style: TextStyle(
                  color: c,
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w700,
                  height: 1)),
        ),
      ]),
    );
  }
}
