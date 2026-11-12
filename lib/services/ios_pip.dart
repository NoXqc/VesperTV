import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';

/// iPhone / iPad picture-in-picture (`vespertv/pip`, `VesperPip` in
/// `ios/Runner/AppDelegate.swift`). iOS only floats Apple's own player, so
/// [DesktopPlayerScreen] stops mpv and hands the stream to an AVPlayer
/// here; [onStopped] says when the PiP window closed, with or without
/// coming back to the app, and where the video got to.
class IosPip {
  static const _channel = MethodChannel('vespertv/pip');
  static bool _listening = false;

  /// The PiP window closed: [restore] = the user came back to the app
  /// with its restore button (else it was closed with X); [position] in
  /// seconds (0 for live).
  static void Function(bool restore, double position)? onStopped;

  /// The PiP button shows on iOS only.
  static bool get available => Platform.isIOS;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'stopped') return;
      final args = (call.arguments as Map?) ?? const {};
      onStopped?.call(
          args['restore'] == true, (args['position'] as num?)?.toDouble() ?? 0);
    });
  }

  /// Opens [url] in Apple's player and floats it. Null when PiP started,
  /// else a short reason for Send log (never shown as is).
  static Future<String?> start({
    required String url,
    required bool live,
    double position = 0,
    Map<String, String> headers = const {},
  }) async {
    _listen();
    try {
      return await _channel.invokeMethod<String>('start', {
        'url': url,
        'live': live,
        'position': position,
        'headers': headers,
      });
    } on PlatformException catch (e) {
      return 'platform: ${e.code}';
    } on MissingPluginException {
      return 'missing-plugin';
    }
  }

  /// Ends PiP from the app (Watch here, or the player closing). Returns
  /// where Apple's player got to, in seconds.
  static Future<double> stop() async {
    try {
      return (await _channel.invokeMethod<num>('stop'))?.toDouble() ?? 0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// The link Apple's player gets for [channel], or null when it can't
  /// play it at all. AVPlayer opens HLS and MP4/MOV, not MKV, AVI, WebM or
  /// raw MPEG-TS. Xtream live channels have an HLS twin: `…/live/u/p/id.ts`
  /// (or the short `…/u/p/id`) is also served as `…/live/u/p/id.m3u8`.
  /// Anything unknown is tried (Media Hub links often have no extension);
  /// a failure brings our player back.
  static String? urlFor(Channel channel) =>
      linkFor(channel.url, live: channel.isLive && !channel.transientPlayback);

  @visibleForTesting
  static String? linkFor(String url, {required bool live}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    final path = uri.path.toLowerCase();
    if (live) {
      if (path.endsWith('.m3u8')) return url;
      final segments =
          uri.pathSegments.where((s) => s.isNotEmpty).toList(growable: false);
      if (path.endsWith('.ts')) {
        // Xtream: /live/user/pass/id.ts -> .m3u8. Another server's raw TS
        // has no HLS twin we know of.
        if (segments.length == 4 && segments.first == 'live') {
          return uri
              .replace(
                  path: '${uri.path.substring(0, uri.path.length - 3)}.m3u8')
              .toString();
        }
        return null;
      }
      // Xtream's short form: /user/pass/id (numeric id, no extension).
      if (segments.length == 3 && int.tryParse(segments.last) != null) {
        return uri.replace(pathSegments: [
          'live',
          ...segments.take(2),
          '${segments.last}.m3u8'
        ]).toString();
      }
      return url;
    }
    const unplayable = ['.mkv', '.avi', '.webm', '.ts', '.flv', '.wmv'];
    if (unplayable.any(path.endsWith)) return null;
    return url;
  }
}
