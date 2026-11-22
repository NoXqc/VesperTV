import 'package:flutter_tvos/flutter_tvos.dart';

import '../utils/desktop_platform.dart';

/// How the Siri Remote's touch surface turns into arrow keys on Apple TV.
///
/// The flutter-tvos engine makes the arrows itself; its stock thresholds
/// (one arrow per 0.3 of the pad, auto-repeat after 3 small moves) moved
/// focus at the lightest touch (Discord, itSoTek on an Apple TV 4K 3rd gen,
/// 2026-11-21: "I barely touch it and things just start happening"). The
/// `flutter_tvos` package sends the engine other values ([TvRemoteConfig]).
/// Settings > Backup & devices > Remote > Touch surface, this device only.
class AppleTvRemote {
  AppleTvRemote._();

  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
  static const levels = [low, normal, high];

  /// The engine's own values ([high]) were too eager: [normal] is the
  /// default.
  static TvRemoteConfig configFor(String level) => switch (level) {
        low => const TvRemoteConfig(
            shortSwipeThreshold: 0.65,
            fastSwipeThreshold: 0.85,
            dpadDeadZone: 0.65,
            continuousSwipeMoveThreshold: 8,
            keyRepeatInitialDelay: Duration(milliseconds: 550),
            keyRepeatInterval: Duration(milliseconds: 110),
          ),
        high => const TvRemoteConfig(),
        _ => const TvRemoteConfig(
            shortSwipeThreshold: 0.5,
            fastSwipeThreshold: 0.7,
            dpadDeadZone: 0.55,
            continuousSwipeMoveThreshold: 6,
            keyRepeatInitialDelay: Duration(milliseconds: 500),
            keyRepeatInterval: Duration(milliseconds: 90),
          ),
      };

  static String levelOf(String? saved) =>
      levels.contains(saved) ? saved! : normal;

  /// Sends [level]'s values to the engine (the first call also connects
  /// the package to it). Nothing happens off Apple TV.
  static void apply(String? level) {
    if (!isAppleTv) return;
    final remote = TvRemoteController.instance;
    remote.config = configFor(levelOf(level));
    remote.init();
  }
}
