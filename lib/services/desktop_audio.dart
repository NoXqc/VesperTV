import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../widgets/data_pool_card.dart';
import 'audio_track_preferences.dart';
import 'storage_service.dart';
import 'subtitle_tracks.dart';

/// Audio on Windows (media_kit / mpv), the same settings as Android's
/// Settings > Playback > Audio: surround passthrough (`audio-spdif`: Dolby
/// Digital, Dolby Atmos inside E-AC-3 / TrueHD, and DTS go to the receiver
/// untouched) and audio delay (`audio-delay`), plus the track labels and
/// the remembered track per movie / series ([AudioTrackPreferences]).
///
/// mpv 0.36 with FFmpeg 6.0 (media_kit's build) can't tell Atmos (E-AC-3
/// JOC) from plain E-AC-3, so Windows shows no ATMOS badge; passthrough
/// still delivers the Atmos stream to a receiver.
class DesktopAudio {
  static bool passthrough = false;
  static int delayMs = 0;

  /// Every stream player made by `configureDesktopStreamPlayer`, so a
  /// change in Settings or the Audio sync dialog reaches the one playing.
  static final _players = <Player>{};

  /// Multiview tiles never pass through: passthrough sound ignores the
  /// app's volume, so muted screens would play (same rule as Android).
  static final _multiview = Expando<bool>();

  static const _spdifCodecs = 'ac3,eac3,dts,dts-hd,truehd';

  static void track(Player player, {required bool multiview}) {
    _players.add(player);
    _multiview[player] = multiview;
    unawaited(applyTo(player));
  }

  static void forget(Player player) => _players.remove(player);

  static Future<void> applyTo(Player player) async {
    final native = player.platform;
    if (native is! NativePlayer) return;
    final spdif = passthrough && _multiview[player] != true;
    try {
      await native.setProperty('audio-spdif', spdif ? _spdifCodecs : '');
      await native.setProperty(
          'audio-delay', (delayMs / 1000).toStringAsFixed(3));
    } catch (e) {
      // A disposed player: it's no longer playing anything.
      _players.remove(player);
    }
  }

  static void set({bool? passthrough, int? delayMs}) {
    if (passthrough != null) DesktopAudio.passthrough = passthrough;
    if (delayMs != null) DesktopAudio.delayMs = delayMs;
    debugPrint('DesktopAudio: passthrough=${DesktopAudio.passthrough} '
        'delay=${DesktopAudio.delayMs} ms (${_players.length} players)');
    for (final player in _players.toList()) {
      unawaited(applyTo(player));
    }
  }

  /// The file's own audio tracks (no auto / off entries, no external file).
  static List<AudioTrack> tracksOf(Player player) => [
        for (final t in player.state.tracks.audio)
          if (t.id != 'auto' && t.id != 'no' && !t.uri) t,
      ];

  /// Language and track name ([audioTrackName]), else "Audio n", then
  /// codec and channel layout (what tells two same-language tracks apart)
  /// - the Android picker's labels.
  static String label(AudioTrack track, int index) {
    final name = audioTrackName(track.title, track.language);
    return [
      name.isNotEmpty ? name : tr('Audio {n}', {'n': index + 1}),
      DataPoolCard.codecName(track.codec),
      DataPoolCard.channelsName(track.channelscount),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }

  static AudioTrack? match(
          List<AudioTrack> tracks, Map<String, dynamic> choice) =>
      AudioTrackPreferences.matchWith(tracks, choice,
          language: (t) => t.language, label: (t) => t.title);

  static Future<void> remember(
          StorageService storage, Channel channel, AudioTrack track) =>
      AudioTrackPreferences.rememberChoice(storage, channel,
          language: track.language, label: track.title);

  /// A movie / episode opens with the track picked last time (or the
  /// preferred audio language), like Android's [AudioTrackPreferences.apply].
  /// The track list exists once the file's header is read, so it waits for
  /// it a few seconds. Quiet when nothing matches.
  static Future<void> applyRemembered(
      StorageService storage, Channel channel, Player player,
      {required bool Function() isCurrent}) async {
    final saved = AudioTrackPreferences.choice(storage, channel);
    if (saved == null) return;
    final viewer = storage.getActiveViewerId();
    bool current() => isCurrent() && storage.getActiveViewerId() == viewer;
    for (var attempt = 0; attempt < 12 && current(); attempt++) {
      final tracks = tracksOf(player);
      if (tracks.isNotEmpty) {
        final picked = match(tracks, saved);
        if (picked != null && player.state.track.audio.id != picked.id) {
          await player.setAudioTrack(picked);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// One Send-log line per stream with its audio tracks, like Android's
  /// `AudioTracks:` line (no URLs).
  static void logTracks(Channel channel, Player player) {
    final tracks = tracksOf(player);
    if (tracks.isEmpty) return;
    debugPrint('DesktopAudioTracks: ${channel.name} n=${tracks.length} '
        '${[
      for (final t in tracks)
        '[${t.language ?? '-'}|${t.title ?? '-'}|${t.codec ?? '-'}|'
            '${t.channelscount ?? '-'}]'
    ].join(' ')}');
  }
}
