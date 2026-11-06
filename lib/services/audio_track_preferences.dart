import 'dart:convert';

import 'package:video_player_hdr/video_player_hdr.dart';

import '../models/channel.dart';
import 'storage_service.dart';
import 'subtitle_tracks.dart';

/// Viewer-scoped VOD choices. Track IDs are session-local: store language/label.
class AudioTrackPreferences {
  static Map<String, dynamic> _choices(StorageService storage) {
    try {
      return Map<String, dynamic>.from(
          jsonDecode(storage.getAudioTrackChoicesJson() ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic>? choice(StorageService storage, Channel channel) {
    final key = SubtitleTracks.seriesKeyOf(channel);
    if (key == null) return null;
    final saved = _choices(storage)[key];
    if (saved is Map) return Map<String, dynamic>.from(saved);
    final lang = storage.getPreferredAudioLanguage();
    return lang.isEmpty ? null : {'lang': lang};
  }

  static Future<void> remember(
          StorageService storage, Channel channel, VideoAudioTrack track) =>
      rememberChoice(storage, channel,
          language: track.language, label: track.label);

  /// [remember] for any player's track (Windows: media_kit's `AudioTrack`).
  static Future<void> rememberChoice(StorageService storage, Channel channel,
      {String? language, String? label}) async {
    final key = SubtitleTracks.seriesKeyOf(channel);
    if (key == null) return;
    final all = _choices(storage);
    all[key] = {'lang': language, 'label': label};
    await storage.setAudioTrackChoicesJson(jsonEncode(all));
  }

  static VideoAudioTrack? match(
          List<VideoAudioTrack> tracks, Map<String, dynamic> choice) =>
      matchWith(tracks, choice,
          language: (t) => t.language, label: (t) => t.label);

  /// [match] for any player's tracks: same language (the label decides
  /// between several), or the same label when the choice had no language.
  static T? matchWith<T>(List<T> tracks, Map<String, dynamic> choice,
      {required String? Function(T) language,
      required String? Function(T) label}) {
    final lang = choice['lang'] as String?;
    final wanted = choice['label'] as String?;
    final candidates = tracks.where((track) =>
        sameTrackLanguage(language(track), lang) ||
        ((lang == null || lang.isEmpty || lang == 'und') &&
            wanted != null &&
            wanted.isNotEmpty &&
            label(track) == wanted));
    return candidates
            .where((t) => wanted != null && label(t) == wanted)
            .firstOrNull ??
        candidates.firstOrNull;
  }

  static Future<void> apply(StorageService storage, Channel channel,
      VideoPlayerHdrController controller,
      {required bool Function() isCurrent}) async {
    final saved = choice(storage, channel);
    if (saved == null) return;
    final viewer = storage.getActiveViewerId();
    final initial = jsonEncode(saved);
    bool current() =>
        isCurrent() &&
        storage.getActiveViewerId() == viewer &&
        jsonEncode(choice(storage, channel)) == initial;
    try {
      for (var attempt = 0; attempt < 6 && current(); attempt++) {
        final tracks = await controller.getAudioTracks();
        if (!current()) return;
        final picked = match(tracks, saved);
        if (picked != null) {
          if (!picked.isSelected) await controller.selectAudioTrack(picked.id);
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {
      // Unsupported device or disposed player. Keep the file's default audio.
    }
  }
}
