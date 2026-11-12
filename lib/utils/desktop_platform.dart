import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// True on a computer (Windows or macOS): the media_kit player stack
/// (`DesktopPlayerScreen`, `DesktopMiniPlayer`), window_manager, mouse
/// layouts. Everything else is the Android stack (video_player_hdr + the
/// app's Kotlin channels), which a desktop never reaches.
///
/// Use `Platform.isWindows` only for what is really Windows: drive letters,
/// WebView2, the `.zip` release asset, `Documents\VesperTV` naming.
bool get isDesktop => Platform.isWindows || Platform.isMacOS;

/// [isDesktop] for presentation and layout decisions that follow Flutter's
/// target platform instead of dart:io, so widget tests can exercise either
/// layout on any host. Same answer as [isDesktop] on a real device.
bool get isDesktopTarget =>
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// True where playback goes through media_kit (mpv): the computers plus
/// iPhone/iPad. Apple's own player (video_player's iOS backend, AVPlayer)
/// can't open raw MPEG-TS live streams or MKV files, which most IPTV
/// providers and Media Hub sources send, so iOS takes the desktop player
/// stack (`DesktopPlayerScreen`, `DesktopMiniPlayer`, Multiview) while
/// keeping the touch layout. Layout, window and mouse decisions stay on
/// [isDesktop].
bool get usesMediaKit => isDesktop || Platform.isIOS;

/// [usesMediaKit] by Flutter's target platform, for the code paths that
/// already follow [isDesktopTarget] so widget tests pick either stack.
bool get usesMediaKitTarget =>
    isDesktopTarget || defaultTargetPlatform == TargetPlatform.iOS;

/// iPhone / iPad by Flutter's target platform: the media_kit player with a
/// touch layout instead of the computer's mouse bar.
bool get isIosTarget => defaultTargetPlatform == TargetPlatform.iOS;

/// media_kit's `Video` widget pauses its player when the app goes to the
/// background and never resumes it. On an iPhone, Home or the lock screen
/// then stopped every movie (owner, 2026-11-09): the app plays on in the
/// background there (UIBackgroundModes audio). Computers keep the default.
bool get mediaKitPausesInBackground => !isIosTarget;

/// No system Back button or key here (a computer, an iPhone): screens that
/// rely on it show their own back arrow.
bool get needsBackArrow => isDesktop || Platform.isIOS;
