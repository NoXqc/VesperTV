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
