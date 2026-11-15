import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// True on a computer (Windows, macOS or Linux): the media_kit player stack
/// (`DesktopPlayerScreen`, `DesktopMiniPlayer`), window_manager, mouse
/// layouts. Everything else is the Android stack (video_player_hdr + the
/// app's Kotlin channels), which a desktop never reaches.
///
/// Use `Platform.isWindows` only for what is really Windows: drive letters,
/// WebView2, the `.zip` release asset, `Documents\VesperTV` naming.
bool get isDesktop =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// [isDesktop] for presentation and layout decisions that follow Flutter's
/// target platform instead of dart:io, so widget tests can exercise either
/// layout on any host. Same answer as [isDesktop] on a real device.
bool get isDesktopTarget =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

/// True where playback goes through media_kit (mpv): the computers plus
/// iPhone/iPad. Apple's own player (video_player's iOS backend, AVPlayer)
/// can't open raw MPEG-TS live streams or MKV files, which most IPTV
/// providers and Media Hub sources send, so iOS takes the desktop player
/// stack (`DesktopPlayerScreen`, `DesktopMiniPlayer`, Multiview) while
/// keeping the touch layout. Layout, window and mouse decisions stay on
/// [isDesktop].
///
/// Not on Apple TV ([isAppleTv]): media_kit has no tvOS build, so for now
/// it takes the Android TV stack with Apple's player (video_player_tvos).
bool get usesMediaKit => isDesktop || (Platform.isIOS && !isAppleTv);

/// [usesMediaKit] by Flutter's target platform, for the code paths that
/// already follow [isDesktopTarget] so widget tests pick either stack.
bool get usesMediaKitTarget =>
    isDesktopTarget ||
    (defaultTargetPlatform == TargetPlatform.iOS && !isAppleTv);

/// iPhone / iPad by Flutter's target platform: the media_kit player with a
/// touch layout instead of the computer's mouse bar.
bool get isIosTarget =>
    defaultTargetPlatform == TargetPlatform.iOS && !isAppleTv;

/// Apple TV, built with the community flutter-tvos engine. Its Dart VM
/// reports `Platform.isIOS` (and Flutter's target platform iOS) too, so
/// everything above that means "iPhone / iPad" excludes it. Read through
/// `operatingSystem`: the engine's own `Platform.isTvOS` doesn't exist in
/// the stock SDK this project analyses and tests with. Apple TV keeps the
/// App Store rules ([appStoreBuild]) and uses the TV layout.
bool get isAppleTv => Platform.operatingSystem == 'tvos';

/// media_kit's `Video` widget pauses its player when the app goes to the
/// background and never resumes it. On an iPhone, Home or the lock screen
/// then stopped every movie (owner, 2026-11-09): the app plays on in the
/// background there (UIBackgroundModes audio). Computers keep the default.
bool get mediaKitPausesInBackground => !isIosTarget;

/// No system Back button or key here (a computer, an iPhone): screens that
/// rely on it show their own back arrow.
/// Not on Apple TV: the Siri Remote's Back (Menu) button pops the route.
bool get needsBackArrow => isDesktop || (Platform.isIOS && !isAppleTv);
