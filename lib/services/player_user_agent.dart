import 'package:package_info_plus/package_info_plus.dart';
import 'package:video_player_android/video_player_android.dart'
    show AndroidVideoPlayer;

/// What VesperTV's Android player tells a stream server it is (owner,
/// 2026-11-25: Tuliprox's player column showed iMPlayer, TiviMate… and
/// "ExoPlayer" for VesperTV, the player library's own default). Every
/// Android stream without its own User-Agent sends this: the first play,
/// a native channel change (`NativeVideoSurface.replaceLive`, which sent
/// Android's "Dalvik/..." before), Multiview tiles. "ExoPlayerLib" stays
/// at the end for providers that look for it. Computers keep their own
/// (`kDesktopStreamUserAgent`: mpv's "libmpv" is blocked by some panels).
class PlayerUserAgent {
  PlayerUserAgent._();

  /// The media3 version the vendored player builds with (ExoPlayer logs it
  /// as `AndroidXMedia3/1.9.2`).
  static const exoPlayerLib = '1.9.2';

  static String forVersion(String version) =>
      'VesperTV/$version (Linux; Android) ExoPlayerLib/$exoPlayerLib';

  /// The current one (also for requests that should look like the player).
  static String get value => AndroidVideoPlayer.defaultUserAgent;

  /// Once at startup, before anything plays.
  static Future<void> init() async {
    var version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {/* The name without a version still says VesperTV. */}
    AndroidVideoPlayer.defaultUserAgent = version.isEmpty
        ? 'VesperTV (Linux; Android) ExoPlayerLib/$exoPlayerLib'
        : forVersion(version);
  }
}
