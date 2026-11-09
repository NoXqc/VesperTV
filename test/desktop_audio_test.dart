import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nox_iptv/services/audio_track_preferences.dart';
import 'package:nox_iptv/services/desktop_audio.dart';

/// Windows audio tracks (media_kit / mpv): the Android picker's labels and
/// the same remembered choice (language + label, never a track id).
void main() {
  test('labels: language and name, else Audio n, plus codec and layout', () {
    expect(
        DesktopAudio.label(
            const AudioTrack('1', 'Commentary', 'eng',
                codec: 'eac3', channelscount: 6),
            0),
        'English (Commentary) · E-AC-3 · 5.1');
    expect(
        DesktopAudio.label(
            const AudioTrack('2', null, 'fre', codec: 'aac', channelscount: 2),
            1),
        'Français · AAC · Stereo');
    // "MIS" / "UND" tell nobody anything: "Audio n" instead.
    expect(
        DesktopAudio.label(const AudioTrack('3', null, 'mis', codec: 'ac3'), 2),
        'Audio 3 · AC-3');
    expect(DesktopAudio.label(const AudioTrack('4', null, null), 3), 'Audio 4');
  });

  test('a remembered choice finds the same track on the next file', () {
    const tracks = [
      AudioTrack('1', 'Main', 'eng', codec: 'eac3'),
      AudioTrack('2', 'Commentary', 'eng', codec: 'aac'),
      AudioTrack('3', null, 'spa', codec: 'aac'),
    ];
    expect(
        DesktopAudio.match(tracks, {'lang': 'eng', 'label': 'Commentary'})?.id,
        '2');
    expect(DesktopAudio.match(tracks, {'lang': 'spa'})?.id, '3');
    // Same language, label gone: the first track in that language.
    expect(
        DesktopAudio.match(tracks, {'lang': 'en', 'label': 'Other'})?.id, '1');
    expect(DesktopAudio.match(tracks, {'lang': 'ger'}), isNull);
    // The shared matcher Android uses gives the same answer.
    expect(
        AudioTrackPreferences.matchWith(
            tracks, {'lang': 'eng', 'label': 'Main'},
            language: (t) => t.language, label: (t) => t.title)?.id,
        '1');
  });

  test('passthrough and delay settings are kept for new players', () {
    DesktopAudio.set(passthrough: true, delayMs: 250);
    expect(DesktopAudio.passthrough, isTrue);
    expect(DesktopAudio.delayMs, 250);
    DesktopAudio.set(passthrough: false, delayMs: 0);
    expect(DesktopAudio.passthrough, isFalse);
  });
}
