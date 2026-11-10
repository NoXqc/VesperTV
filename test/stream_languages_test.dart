import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_playback_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/archive_stream_size.dart';
import 'package:nox_iptv/services/stream_languages.dart';

ArchiveStreamOption _option(String name, String title, {String key = 'a'}) =>
    ArchiveStreamOption(
        source: ArchiveSource(
            manifestUrl: 'https://$key.example/manifest.json', name: key),
        stream: ArchiveStream(
            url: 'https://media.example/${name.hashCode}-${title.hashCode}',
            name: name,
            title: title));

void main() {
  test('reads the languages a label names', () {
    expect(streamLanguagesOf('The.Avengers.2012.2160p.MULTi.TrueHD').multi,
        isTrue);
    expect(streamLanguagesOf('Torrentio 4k 🇷🇺 / 🇺🇦').codes, {'ru', 'uk'});
    expect(streamLanguagesOf('🗣 English | Russian').codes, {'en', 'ru'});
    expect(streamLanguagesOf('Movie.2012.TRUEFRENCH.1080p').codes, {'fr'});
    expect(streamLanguagesOf('Movie.2012.iTA.ENG.1080p').codes, {'it', 'en'});
    // Subtitles aren't audio.
    expect(streamLanguagesOf('Movie.2012.VOSTFR.1080p').codes, isEmpty);
    expect(streamLanguagesOf('Movie 1080p Multi Subs').multi, isFalse);
    expect(streamLanguagesOf('Movie 1080p Eng Subs').codes, isEmpty);
    // Ordinary words and titles aren't languages.
    expect(streamLanguagesOf('La Vie en Rose 2007 1080p').codes, isEmpty);
    expect(streamLanguagesOf('It 2017 1080p de luxe').codes, isEmpty);
  });

  test('fit: only the language > among others > unknown > only others', () {
    expect(streamLanguageFit('Movie 2160p Remux', 'en'), 3,
        reason: 'untagged releases are English');
    expect(streamLanguageFit('Movie 2160p English', 'en'), 3);
    expect(streamLanguageFit('Movie 🇬🇧 / 🇺🇦', 'en'), 2);
    expect(streamLanguageFit('Movie MULTi', 'en'), 2);
    expect(streamLanguageFit('Movie MULTi 🇷🇺', 'en'), 1);
    expect(streamLanguageFit('Movie 🇷🇺 / 🇺🇦', 'en'), 0);
    expect(streamLanguageFit('Movie 1080p', 'fr'), 1);
    expect(streamLanguageFit('Movie TRUEFRENCH', 'fr'), 3);
    expect(streamLanguageFit('Movie 🇬🇧', 'fr'), 0);
  });

  group('ranking', () {
    final dub = _option(
        'Torrentio\n4k DV', 'Avengers 2160p Remux 🇷🇺 / 🇺🇦 💾 80 GB');
    final english =
        _option('Torrentio\n4k DV', 'Avengers 2160p Remux 💾 70 GB');
    final hd = _option('Torrentio\n1080p', 'Avengers 1080p BluRay 💾 12 GB');

    test('the viewer\'s audio language puts a dub last', () {
      const prefs = ArchivePlaybackPreferences(audioLanguage: 'en');
      expect(prefs.ranked([dub, hd, english]), [english, hd, dub]);
      expect(
          prefs.bestLanguage(prefs.ranked([dub, hd, english])), [english, hd]);
    });

    test('a file with English among other languages counts as English', () {
      // The Batman (owner, 2026-11-09): the largest file with English
      // audio, not the largest English-only one.
      final multi = _option('Torrentio\n4k DV',
          'Avengers 2160p Remux 🗣 English | Russian | Ukrainian 💾 77.3 GB');
      const prefs = ArchivePlaybackPreferences(audioLanguage: 'en');
      final best = prefs.bestLanguage(prefs.ranked([english, dub, multi]));
      expect(best, [english, multi]);
      expect(largestArchiveStream(best), multi);
      const filtered = ArchivePlaybackPreferences(language: 'en');
      expect(filtered.ranked([dub, multi, english]), [multi, english]);
    });

    test('with no language set, the app language only demotes dubs', () {
      const prefs = ArchivePlaybackPreferences(appLanguage: 'en');
      expect(prefs.ranked([dub, hd, english]), [english, hd, dub]);
      const french = ArchivePlaybackPreferences(appLanguage: 'fr');
      // Untagged isn't French, but isn't "only another language" either.
      expect(french.ranked([hd, english]), [english, hd]);
    });

    test('Media Hub language leaves out streams that do not fit', () {
      const prefs = ArchivePlaybackPreferences(language: 'en');
      expect(prefs.ranked([dub, hd, english]), [english, hd]);
      expect(prefs.ranked([dub]), isEmpty);
      expect(prefs.ranked([dub], strict: false), [dub]);
    });

    test('no language at all keeps the old order', () {
      const prefs = ArchivePlaybackPreferences();
      expect(prefs.ranked([dub, hd, english]), [dub, english, hd]);
    });
  });
}
