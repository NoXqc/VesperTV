import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A list-only metadata add-on (AIOMetadata set to Portuguese) gives the
/// title page its own details; Cinemeta (English only) stays the fallback.
/// User report, 2026-11-09.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const preview = ArchiveMeta(
      id: 'tt1', type: ArchiveType.series, name: 'Título', imdbId: 'tt1');

  ArchiveSource listOnly({bool meta = true}) => ArchiveSource(
        manifestUrl: 'https://aio.example/cfg/manifest.json',
        name: 'AIOMetadata',
        listOnly: true,
        catalogs: const [
          ArchiveCatalog(type: ArchiveType.series, id: 'pt', name: 'Séries')
        ],
        imdbResources: meta
            ? const {
                'meta': ['movie', 'series']
              }
            : const {},
      );

  Map<String, dynamic> series(String id, String name, String episode,
          {String episodeId = 'tt1:1:1'}) =>
      {
        'meta': {
          'id': id,
          'type': 'series',
          'name': name,
          'description': name == 'Title' ? 'English' : 'Português',
          'videos': [
            {'id': episodeId, 'title': episode, 'season': 1, 'episode': 1}
          ],
        }
      };

  Future<(ArchiveService, List<Uri>)> service(
      Map<String, dynamic>? Function(Uri) aio) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final requests = <Uri>[];
    final api = ArchiveApiService(client: MockClient((r) async {
      requests.add(r.url);
      if (r.url.host == 'aio.example') {
        final body = aio(r.url);
        return body == null
            ? http.Response('nope', 500)
            : http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }
      return http.Response(jsonEncode(series('tt1', 'Title', 'Pilot')), 200);
    }));
    final s = ArchiveService(storage, api: api);
    addTearDown(s.dispose);
    return (s, requests);
  }

  test('details and episode names come from the metadata add-on', () async {
    final (s, requests) =
        await service((_) => series('tt1', 'Título', 'Piloto'));
    final full = (await s.meta(listOnly(), preview))!;
    expect(full.name, 'Título');
    expect(full.description, 'Português');
    expect(full.videos.single.title, 'Piloto');
    expect(full.videos.single.id, 'tt1:1:1');
    expect(requests.single.toString(),
        'https://aio.example/cfg/meta/series/tt1.json');
  });

  test('a list without a meta resource still uses Cinemeta', () async {
    final (s, requests) =
        await service((_) => series('tt1', 'Título', 'Piloto'));
    final full = (await s.meta(listOnly(meta: false), preview))!;
    expect(full.name, 'Title');
    expect(requests.every((u) => u.host != 'aio.example'), isTrue);
  });

  test('ids that are not IMDb ids fall back to Cinemeta', () async {
    final (s, _) = await service(
        (_) => series('tmdb:5', 'Título', 'Piloto', episodeId: 'tmdb:5:1:1'));
    expect((await s.meta(listOnly(), preview))!.name, 'Title');
    final (s2, _) = await service(
        (_) => series('tt1', 'Título', 'Piloto', episodeId: 'tmdb:5:1:1'));
    expect((await s2.meta(listOnly(), preview))!.name, 'Title');
  });

  test('a failing metadata add-on falls back to Cinemeta', () async {
    final (s, _) = await service((_) => null);
    expect((await s.meta(listOnly(), preview))!.name, 'Title');
  });
}
