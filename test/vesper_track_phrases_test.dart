import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_ai.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_commands.dart';

void main() {
  Map<String, Object?>? p(String s) => parseVesperCommand(s)?.args;

  setUp(() => L10n.code = 'en');

  test('subtitles off in every app language', () {
    for (final s in [
      'subtitles off',
      'turn off the subtitles',
      'no subtitles',
      'turn off closed captions',
      'enlève les sous-titres',
      'pas de sous-titres',
      'désactive les sous-titres',
      'quita los subtítulos',
      'sin subtítulos',
      'togli i sottotitoli',
      'Untertitel aus',
      'keine Untertitel',
      'κλείσε τους υπότιτλους',
    ]) {
      expect(p(s), {'action': 'subtitle', 'language': 'off'}, reason: s);
    }
  });

  test('subtitles in a language', () {
    for (final (s, code) in [
      ('French subtitles', 'fr'),
      ('turn on English subtitles', 'en'),
      ('switch the subtitles to Spanish', 'es'),
      ('Hey Vesper, subtitles in Greek please', 'el'),
      ('mets les sous-titres en anglais', 'en'),
      ('sous-titres français', 'fr'),
      ('pon los subtítulos en inglés', 'en'),
      ('metti i sottotitoli in italiano', 'it'),
      ('deutsche Untertitel', 'de'),
      ('Untertitel auf Englisch', 'en'),
    ]) {
      expect(p(s), {'action': 'subtitle', 'language': code}, reason: s);
    }
    expect(
        p('turn on closed captions'), {'action': 'subtitle', 'language': 'cc'});
    expect(p('CC on'), {'action': 'subtitle', 'language': 'cc'});
  });

  test('audio in a language', () {
    for (final (s, code) in [
      ('French audio', 'fr'),
      ('switch the audio to English', 'en'),
      ('the Spanish version', 'es'),
      ('audio en anglais', 'en'),
      ('mets la version française', 'fr'),
      ('cambia el audio a inglés', 'en'),
      ('audio in italiano', 'it'),
      ('Ton auf Deutsch', 'de'),
    ]) {
      expect(p(s), {'action': 'audio_track', 'language': code}, reason: s);
    }
  });

  test('which tracks', () {
    for (final s in [
      'which audio tracks',
      'audio tracks',
      'change the audio',
      'quelles pistes audio'
    ]) {
      expect(p(s), {'action': 'audio_tracks'}, reason: s);
    }
    for (final s in [
      'subtitles',
      'which subtitles are there',
      'quels sous-titres',
      'turn on subtitles'
    ]) {
      expect(p(s), {'action': 'subtitles'}, reason: s);
    }
  });

  test('never steals other commands', () {
    // Volume, a game feed, a title, the app language.
    expect(p('turn off the sound'), isNull);
    expect(p('turn the sound on'), isNull);
    expect(parseVesperCommand('find the English feed of the Habs game')?.tool,
        'play_game');
    expect(parseVesperCommand('play The French Dispatch')?.args['action'],
        isNot('audio_track'));
    expect(p('subtitles and audio in French'), isNull);
    expect(p('English and French subtitles'), isNull);
  });

  test('replies name the track or list them', () {
    VesperReply r(String action, Map<String, Object?> result,
            [Map<String, Object?> args = const {}]) =>
        VesperAi.describeResult(
            VesperCommand('player', {'action': action, ...args}), result);
    expect(r('subtitle', {'done': 'subtitles off'}).text, 'Subtitles: Off');
    expect(r('subtitle', {'done': 'subtitles: Français'}).text,
        'Subtitles: Français');
    expect(r('audio_track', {'done': 'audio: English · E-AC-3 5.1'}).text,
        'Audio: English · E-AC-3 5.1');
    expect(
        r('audio_tracks', {
          'tracks': [
            {'track': 1, 'name': 'English', 'playing': true},
            {'track': 2, 'name': 'Français'},
          ]
        }).text,
        'Audio tracks: ▶ English · Français');
    expect(
        r('subtitles', {
          'tracks': [
            {'track': 1, 'name': 'English'},
          ],
          'off': true,
        }).text,
        'Subtitles: English · ▶ Off');
    expect(r('subtitles', {'tracks': [], 'off': true}).text,
        'No subtitles in this file.');
    expect(
        r('audio_track', {'error': 'No Deutsch audio in this stream.'},
            {'language': 'de'}).text,
        'That language is not in this stream.');
    expect(
        r('subtitle', {'error': 'This channel has no closed captions.'},
            {'language': 'cc'}).text,
        'This channel has no closed captions.');
  });
}
