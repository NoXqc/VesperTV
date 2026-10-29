import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/archive_library.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/media_server_api.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';

const _a = ArchiveSource(
    manifestUrl: 'https://a.example/manifest.json',
    name: 'A',
    searchCatalogsChecked: true,
    catalogs: [
      ArchiveCatalog(type: ArchiveType.movie, id: 'one', name: 'One'),
      ArchiveCatalog(type: ArchiveType.movie, id: 'two', name: 'Two')
    ]);
const _b =
    ArchiveSource(manifestUrl: 'https://b.example/manifest.json', name: 'B');

class _ServerLookup extends MediaServerApi {
  String? query;
  @override
  Future<List<ArchiveMeta>> fetchCatalog(
      ArchiveSource source, ArchiveCatalog catalog,
      {int skip = 0, String? search}) async {
    query = search;
    return const [
      ArchiveMeta(
          id: 'server-item-beyond-page-one',
          imdbId: 'tt999',
          type: ArchiveType.movie,
          name: 'A recommendation',
          year: '2026')
    ];
  }
}

class _Cache extends ArchiveCache {
  @override
  Future<DateTime?> fetchedAt(String source, ArchiveCatalog catalog) async =>
      null;
  @override
  Future<void> write(
      String source, ArchiveCatalog catalog, List<ArchiveMeta> items) async {}
}

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([_a.toJson(), _b.toJson()])
  });
  final storage = StorageService();
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'selected recommendation finds server titles beyond loaded catalog pages',
      () async {
    final storage = await _storage();
    const source = ArchiveSource(
        manifestUrl: 'https://server.example',
        name: 'My server',
        server: MediaServerLogin(
            kind: MediaServerKind.jellyfin,
            userId: 'fixture',
            token: 'fixture',
            deviceId: 'fixture'),
        catalogs: [
          ArchiveCatalog(type: ArchiveType.movie, id: 'library', name: 'Movies')
        ]);
    await storage.setArchiveSourcesJson(jsonEncode([source.toJson()]));
    final server = _ServerLookup();
    final hub = ArchiveService(storage, servers: server);
    final result = await hub.findServerTitle(const ArchiveMeta(
        id: 'tt999',
        name: 'A recommendation',
        type: ArchiveType.movie,
        year: '2026'));
    expect(server.query, 'A recommendation');
    expect(result!.source.name, 'My server');
    expect(result.meta.id, 'server-item-beyond-page-one');
    hub.dispose();
  });
  test('a later IMDb mapping unifies earlier TMDB-only progress and favorites',
      () async {
    final storage = await _storage();
    final hub = ArchiveService(storage);
    const old =
        ArchiveMeta(id: 'tmdb:42', name: 'Movie', type: ArchiveType.movie);
    const mapped = ArchiveMeta(
        id: 'tmdb:42', imdbId: 'tt42', name: 'Movie', type: ArchiveType.movie);
    const imdb =
        ArchiveMeta(id: 'tt42', name: 'Movie', type: ArchiveType.movie);
    final a = ArchiveService.channelId(_a, old.id, episode: false);
    final b = ArchiveService.channelId(_b, imdb.id, episode: false);
    hub.registerIdentity(_a, old);
    await storage.setLastDuration(a, 10000);
    await storage.setLastPosition(a, 4000);
    await hub.toggleFavorite(_a, old);
    await hub.recordWatched(_a, old);
    hub.registerIdentity(_b, mapped);
    hub.registerIdentity(_b, imdb);
    expect(storage.getLastPosition(b), 4000);
    await storage.setLastPosition(b, 6000);
    expect(storage.getLastPosition(a), 6000);
    expect(hub.isFavorite(_b, imdb), true);
    await hub.recordWatched(_b, imdb);
    expect(hub.recentlyWatched(), hasLength(1));
    hub.dispose();
  });
  test(
      'migrate progress across known titles, retain it on restart, isolate profiles',
      () async {
    final storage = await _storage();
    final hub = ArchiveService(storage);
    const first = ArchiveMeta(
        id: 'tmdb:10', imdbId: 'tt100', name: 'Movie', type: ArchiveType.movie);
    const second =
        ArchiveMeta(id: 'tt100', name: 'Movie', type: ArchiveType.movie);
    final a = ArchiveService.channelId(_a, first.id, episode: false);
    final b = ArchiveService.channelId(_b, second.id, episode: false);
    await storage.setLastPosition(a, 2500);
    await storage.setLastDuration(a, 10000);
    hub.registerIdentity(_a, first);
    hub.registerIdentity(_b, second);
    expect(storage.getLastPosition(b), 2500);
    expect(storage.getWatchedFraction(b), .25);
    await storage.setLastPosition(b, 5000);
    expect(storage.getLastPosition(a), 5000);
    await hub.recordWatched(_a, first);
    await hub.recordWatched(_b, second);
    expect(hub.continueWatching(ArchiveType.movie), hasLength(1));
    await hub.toggleFavorite(_a, first);
    expect(hub.isFavorite(_b, second), true);
    await storage.setActiveViewerId('other');
    hub.registerIdentity(_b, second);
    expect(storage.getLastPosition(b), 0);
    expect(hub.continueWatching(ArchiveType.movie), isEmpty);
    expect(hub.isFavorite(_b, second), false);
    await storage.setActiveViewerId(AppConstants.mainViewerId);
    expect(storage.getLastPosition(a), 5000);
    // Let alias persistence settle before recreating the preference reader.
    await Future<void>.delayed(Duration.zero);
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getLastPosition(b), 5000);
    const custom = ArchiveMeta(
        id: 'tt100',
        name: 'Custom',
        type: ArchiveType.movie,
        wireType: 'CustomVideo');
    expect(archiveTitleIdentity(_a, custom),
        isNot(archiveTitleIdentity(_b, custom)));
    hub.dispose();
  });

  test(
      'continue watching resumes the exact episode and separates future next-up',
      () async {
    final storage = await _storage();
    final hub = ArchiveService(storage);
    const episodes = [
      ArchiveVideo(
          id: 'tt200:1:1',
          title: 'First',
          season: 1,
          episode: 1,
          released: '2020-01-01'),
      ArchiveVideo(
          id: 'tt200:1:2',
          title: 'Second',
          season: 1,
          episode: 2,
          released: '2020-01-02'),
      ArchiveVideo(
          id: 'tt200:1:3',
          title: 'Future',
          season: 1,
          episode: 3,
          released: '2099-01-03')
    ];
    const show = ArchiveMeta(
        id: 'tt200',
        name: 'A series',
        type: ArchiveType.series,
        videos: episodes);
    hub.registerIdentity(_a, show);
    final first = ArchiveService.channelId(_a, episodes[0].id, episode: true);
    final second = ArchiveService.channelId(_a, episodes[1].id, episode: true);
    await storage.setLastDuration(first, 10000);
    await storage.setLastPosition(first, 10000);
    await storage.setLastDuration(second, 10000);
    await storage.setLastPosition(second, 2500);
    await hub.recordWatched(_a, show, episode: episodes[1]);
    final resume = hub.continueWatching(ArchiveType.series).single;
    expect(resume.episode!.id, episodes[1].id);
    expect(resume.resume, true);
    expect(resume.progress, .25);
    await storage.setLastPosition(second, 10000);
    expect(hub.continueWatching(ArchiveType.series), isEmpty);
    expect(
        hub
            .continueWatching(ArchiveType.series, upcoming: true)
            .single
            .episode!
            .id,
        episodes[2].id);
    hub.dispose();
  });

  test(
      'row order, visibility and names persist per viewer without disabling source',
      () async {
    final storage = await _storage();
    final api = ArchiveApiService(
        client: MockClient((r) async => http.Response(
            jsonEncode({
              'metas': [
                {'id': r.url.path, 'type': 'movie', 'name': r.url.path}
              ]
            }),
            200)));
    final hub = ArchiveService(storage, api: api, cache: _Cache());
    await hub.refresh();
    final before = hub.rows(ArchiveType.movie);
    expect(before.map((r) => r.title), ['One', 'Two']);
    await hub.moveRow(ArchiveType.movie, before.last.key, -1);
    await hub.renameRow(before.last.key, 'My movies');
    await hub.setRowFlag(before.first.key, 'hidden', true);
    expect(hub.rows(ArchiveType.movie).single.title, 'My movies');
    expect(hub.enabledSources, hasLength(2));
    expect(hub.rows(ArchiveType.movie, includeHidden: true), hasLength(2));
    await storage.setActiveViewerId('other');
    expect(hub.rows(ArchiveType.movie).map((r) => r.title), ['One', 'Two']);
    hub.dispose();
    api.close();
  });
}
