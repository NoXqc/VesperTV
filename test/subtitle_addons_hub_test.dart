import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/addon_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/subtitle_tracks.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Subtitle add-ons (Settings > Add-ons) for Media Hub titles, asked with the
// title's IMDb id; and the preferred subtitle language falling back to them.

const _source = ArchiveSource(
  manifestUrl: 'https://aio.example/manifest.json',
  name: 'NoxAIO',
  catalogs: [
    ArchiveCatalog(type: ArchiveType.movie, id: 'tmdb.top', name: 'Popular'),
  ],
);

Future<StorageService> _storage({String? preferred}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([_source.toJson()]),
  });
  final storage = StorageService();
  await storage.init();
  await AddonService(storage).save(const [
    Addon(
        manifestUrl: AddonService.openSubtitlesManifest,
        name: 'OpenSubtitles v3',
        enabled: true),
  ]);
  if (preferred != null) await storage.setPreferredSubtitleLanguage(preferred);
  return storage;
}

/// OpenSubtitles answering for whatever id is asked; [asked] records paths.
MockClient _subtitles(List<String> asked) => MockClient((r) async {
      asked.add(r.url.path);
      return http.Response(
          jsonEncode({
            'subtitles': [
              {'url': 'https://subs.example/1.srt', 'lang': 'eng'},
              {'url': 'https://subs.example/2.srt', 'lang': 'fre'},
            ]
          }),
          200);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Media Hub channels carry the IMDb id, also for tmdb: titles', () async {
    final service = ArchiveService(await _storage());
    const stream = ArchiveStream(url: 'https://cdn.example/v.mkv');
    final tmdbMovie = service.channelFor(
        _source,
        const ArchiveMeta(
            id: 'tmdb:557',
            type: ArchiveType.movie,
            name: 'Spider-Man',
            imdbId: 'tt0145487'),
        stream);
    expect(tmdbMovie.imdbId, 'tt0145487');
    expect(AddonService.supports(tmdbMovie), isTrue);

    final episode = service.channelFor(
        _source,
        const ArchiveMeta(
            id: 'tt0903747', type: ArchiveType.series, name: 'BB'),
        stream,
        episode: const ArchiveVideo(
            id: 'tt0903747:2:3',
            title: 'Bit by a Dead Bee',
            season: 2,
            episode: 3));
    expect(episode.imdbId, 'tt0903747');
    // Survives the history/resume round trip.
    expect(Channel.fromJson(episode.toJson()).imdbId, 'tt0903747');

    final noId = service.channelFor(
        _source,
        const ArchiveMeta(id: 'tmdb:1', type: ArchiveType.movie, name: 'X'),
        stream);
    expect(AddonService.supports(noId), isFalse);
    service.dispose();
  });

  test('add-ons are asked with the IMDb id (movie, episode)', () async {
    final storage = await _storage();
    final service = ArchiveService(storage);
    const stream = ArchiveStream(url: 'https://cdn.example/v.mkv');
    final asked = <String>[];
    await http.runWithClient(() async {
      final movie = service.channelFor(
          _source,
          const ArchiveMeta(
              id: 'tmdb:557',
              type: ArchiveType.movie,
              name: 'Spider-Man',
              imdbId: 'tt0145487'),
          stream);
      final found = await AddonService(storage).search(movie);
      expect(found, hasLength(2));
      final episode = service.channelFor(
          _source,
          const ArchiveMeta(
              id: 'tt0903747', type: ArchiveType.series, name: 'BB'),
          stream,
          episode: const ArchiveVideo(
              id: 'tt0903747:2:3', title: 'Bee', season: 2, episode: 3));
      await AddonService(storage).search(episode);
    }, () => _subtitles(asked));
    expect(asked, [
      '/subtitles/movie/tt0145487.json',
      '/subtitles/series/tt0903747:2:3.json',
    ]);
    service.dispose();
  });

  test('preferred language: flagged, matched online across code styles',
      () async {
    final storage = await _storage(preferred: 'fr');
    final service = ArchiveService(storage);
    final movie = service.channelFor(
        _source,
        const ArchiveMeta(
            id: 'tmdb:557',
            type: ArchiveType.movie,
            name: 'Spider-Man',
            imdbId: 'tt0145487'),
        const ArchiveStream(url: 'https://cdn.example/v.mkv'));
    expect(SubtitleTracks.seriesChoiceFor(storage, movie),
        {'kind': 'embedded', 'lang': 'fr', 'preferred': true});

    final match = await http.runWithClient(
        () => SubtitleTracks.preferredOnline(storage, movie, 'fr'),
        () => _subtitles([]));
    expect(match?.lang, 'fre');

    // An explicit choice wins until the player's row forgets it.
    await SubtitleTracks.rememberForSeries(storage, movie);
    expect(SubtitleTracks.seriesChoiceFor(storage, movie)?['kind'], 'off');
    await SubtitleTracks.forgetForSeries(storage, movie);
    expect(SubtitleTracks.seriesChoiceFor(storage, movie)?['preferred'], true);
    service.dispose();
  });
}
