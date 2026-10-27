import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../models/channel.dart';
import 'subtitle_tracks.dart';

/// Explicit content type for the shared Android movie/episode player.
/// Never infer VOD from the container, URL, track format or reported duration.
class VodBuffering {
  static const _stats = MethodChannel('vespertv/stats');

  static bool appliesTo(Channel channel) =>
      !channel.isLive && !channel.transientPlayback;

  static Future<void> configure(
      VideoPlayerHdrController controller, Channel channel) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _stats.invokeMethod<void>('setOnDemandBuffering', {
        'playerId': SubtitleTracks.playerIdOf(controller),
        'on': appliesTo(channel),
      });
    } on MissingPluginException {
      // Older platform implementations retain their existing buffering policy.
    } on PlatformException catch (e) {
      debugPrint('VodBuffer: configuration failed (${e.code})');
    }
  }
}
