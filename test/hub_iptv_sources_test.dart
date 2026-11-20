import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/hub_iptv_sources.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _meta = ArchiveMeta(
    id: 'tmdb:899082',
    type: ArchiveType.movie,
    name: 'Violent Night',
    year: '2022');

const _addon = ArchiveSource(
    manifestUrl: 'https://addon.example/manifest.json',
    name: 'Addon',
    searchCatalogsChecked: true,
    imdbResources: {
      'stream': ['movie', 'series']
    },
    catalogs: [
      ArchiveCatalog(type: ArchiveType.movie, id: 'movies', name: 'Movies')
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('matching', () {
    bool match(String name, {String? tmdb, int? year, String? otherTmdb}) =>
        HubIptvSources.matches(
            key: 'violent night',
            tmdb: tmdb,
            year: 2022,
            name: name,
            otherTmdb: otherTmdb,
            otherYear: year);

    test('same title and year, provider decorations ignored', () {
      expect(match('EN - Violent Night (2022) 4K', year: 2022), isTrue);
      expect(match('Violent Night', year: 2023), isTrue);
      expect(match('Violent Night'), isTrue);
    });
    test('another year or another title is not the same film', () {
      expect(match('Violent Night', year: 1998), isFalse);
      expect(match('Violent Night 2', year: 2022), isFalse);
    });
    test('a TMDB id on both sides decides', () {
      expect(match('Some other name', tmdb: '1', otherTmdb: '1'), isTrue);
      expect(match('Violent Night', tmdb: '1', otherTmdb: '2'), isFalse);
    });
    test('helpers', () {
      expect(HubIptvSources.tmdbOf(_meta), '899082');
      expect(HubIptvSources.yearOf('2019–2023'), 2019);
      expect(HubIptvSources.episodeInName('S1E3 — Pilot'), 3);
      expect(HubIptvSources.episodeInName('Show S02E10 1080p'), 10);
      expect(HubIptvSources.episodeInName('Show 1x07'), 7);
      expect(HubIptvSources.episodeInName('Pilot'), isNull);
    });
  });

  test('IPTV copies join the Sources list only when the switch is on',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([_addon.toJson()])
    });
    final storage = StorageService();
    await storage.init();
    final api = ArchiveApiService(
        client: MockClient((r) async => http.Response(
            jsonEncode({
              'streams': [
                {
                  'url': 'https://media.example/addon.mkv',
                  'name': 'Addon 1080p'
                }
              ]
            }),
            200)));
    final hub = ArchiveService(storage, api: api);
    var asked = 0;
    hub.iptvStreams = (meta, episode, active) async {
      asked++;
      return const [
        ArchiveStream(
            url: 'http://iptv.example/movie/u/p/1.mkv',
            name: 'IPTV 4K',
            title: 'EN - Violent Night (2022) 4K\nHome')
      ];
    };

    var options = await hub.streams(_addon, _meta);
    expect(asked, 0);
    expect(
        options.map((o) => o.stream.url), ['https://media.example/addon.mkv']);

    await hub.setIptvSources(true);
    options = await hub.streams(_addon, _meta);
    expect(asked, 1);
    expect(options.map((o) => o.stream.url).toSet(), {
      'https://media.example/addon.mkv',
      'http://iptv.example/movie/u/p/1.mkv',
    });
    final iptv =
        options.firstWhere((o) => ArchiveService.isIptvSource(o.source));
    expect(iptv.source.name, 'IPTV');
    hub.dispose();
  });
}
