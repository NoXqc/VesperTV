import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

VideoAudioTrack _audio(String id, String? label, String? lang,
        {bool selected = false}) =>
    VideoAudioTrack(
        id: id, label: label, language: lang, isSelected: selected);

SubtitleTrack _sub(int track, String? lang,
        {bool forced = false, bool cc = false, String? label}) =>
    SubtitleTrack(
        group: track,
        track: 0,
        language: lang,
        label: label,
        forced: forced,
        closedCaptions: cc);

void main() {
  test('language asked by code or by name', () {
    expect(trackLanguageCode('en'), 'en');
    expect(trackLanguageCode('eng'), 'eng');
    expect(trackLanguageCode('English'), 'en');
    expect(trackLanguageCode('french'), 'fr');
    expect(trackLanguageCode('Français'), 'fr');
    expect(trackLanguageCode('Spanish'), 'es');
    expect(trackLanguageCode('off'), isNull);
    expect(trackLanguageCode('klingon'), isNull);
  });

  test('audio: the plain track in that language, not the commentary', () {
    final tracks = [
      _audio('1', 'Русский', 'ru', selected: true),
      _audio('2', 'Commentary', 'en'),
      _audio('3', 'Original', 'en'),
      _audio('4', null, 'uk'),
    ];
    expect(pickAudioTrack(tracks, 'en')?.id, '3');
    expect(pickAudioTrack(tracks, 'eng')?.id, '3');
    expect(pickAudioTrack(tracks, 'ru')?.id, '1');
    expect(pickAudioTrack(tracks, 'fr'), isNull);
    // Only a commentary in that language: still that.
    expect(pickAudioTrack([_audio('2', 'Commentary', 'en')], 'en')?.id, '2');
  });

  test('subtitles: full before forced, captions only when asked', () {
    final tracks = [
      _sub(1, 'en', forced: true),
      _sub(2, 'en'),
      _sub(3, 'fr'),
      _sub(4, null, cc: true),
    ];
    expect(pickSubtitleTrack(tracks, 'en')?.group, 2);
    expect(pickSubtitleTrack(tracks, 'en', forced: true)?.group, 1);
    expect(pickSubtitleTrack(tracks, 'fre')?.group, 3);
    expect(pickSubtitleTrack(tracks, 'cc')?.group, 4);
    expect(pickSubtitleTrack(tracks, 'de'), isNull);
  });
}
