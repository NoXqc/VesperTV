// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/widgets.dart';

import '../utils/desktop_platform.dart';

/// Apple TV: back on screen after the TV / Home button.
///
/// media_kit's `Video` pauses its player when the app goes to the background
/// ([mediaKitPausesInBackground]: Apple TV has no background audio) and
/// never plays it again, and tvOS suspends the app, so the stream's
/// connection is gone too. Android's warm return resumes the last channel
/// (`AppExit.afterWarm`); Apple TV never takes that path (`AppExit.warm`
/// leaves it to the system), so a live channel came back as a still,
/// paused picture. The players reopen live from here (a movie stays paused
/// where it was: the viewer presses Play).
///
/// Only a real hide counts (Home screen, another app, the screen saver);
/// Control Center or Siri over the app only make it inactive.
class AppleTvComeback {
  AppleTvComeback._();

  /// Calls [onBack] with how long the app was hidden, each time it comes
  /// back on screen. Null (nothing to dispose) off Apple TV. [enabled] is
  /// for tests.
  static AppLifecycleListener? listen(void Function(Duration away) onBack,
      {bool? enabled}) {
    if (!(enabled ?? isAppleTv)) return null;
    DateTime? hiddenAt;
    return AppLifecycleListener(
      onHide: () => hiddenAt ??= DateTime.now(),
      onResume: () {
        final at = hiddenAt;
        hiddenAt = null;
        if (at != null) onBack(DateTime.now().difference(at));
      },
    );
  }
}
