import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "movies" / "shows" catalog types (AIOMetadata's display type, owner
/// 2026-11-11: an add-on's movie catalogs landed under Other / shows) are
/// movies and series; requests still say the add-on's own word.
class _Cache extends ArchiveCache {
  @override
  Future<List<ArchiveMeta>> read(
          String sourceKey, ArchiveCatalog catalog) async =>
      const [];

  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;

  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a movies catalog is a movie catalog asked as movies', () {
    final c = ArchiveCatalog.fromJson(
        {'type': 'movies', 'id': 'netflix.new', 'name': 'Netflix - New'})!;
    expect(c.type, ArchiveType.movie);
    expect(c.wireType, isNull, reason: 'not a custom type (no Other)');
    expect(c.wire, 'movie');
    expect(c.requestWire, 'movies');
    final again = ArchiveCatalog.fromJson(c.toJson())!;
    expect(again.requestWire, 'movies', reason: 'kept when saved');
    expect(again.wireType, isNull);

    final shows = ArchiveCatalog.fromJson(
        {'type': 'shows', 'id': 'netflix.new', 'name': 'Netflix - New'})!;
    expect(shows.type, ArchiveType.series);
    expect(shows.requestWire, 'shows');

    final custom = ArchiveCatalog.fromJson(
        {'type': 'channel', 'id': 'c', 'name': 'Channels'})!;
    expect(custom.wireType, 'channel', reason: 'real custom types unchanged');
    expect(custom.requestWire, 'channel');
  });

  test('a movies title is a movie (streams asked as movie)', () {
    final m =
        ArchiveMeta.fromJson({'id': 'tt1', 'type': 'movies', 'name': 'X'})!;
    expect(m.type, ArchiveType.movie);
    expect(m.wireType, isNull);
    final fromCatalog = ArchiveMeta.fromJson({'id': 'tt2', 'name': 'Y'},
        fallbackType: ArchiveType.movie, fallbackWire: 'movie')!;
    expect(fromCatalog.wireType, isNull);
  });

  test('the service shows it as a Movies row and asks /catalog/movies/',
      () async {
    final source = ArchiveSource(
      manifestUrl: 'https://aio.example/abc/manifest.json',
      name: 'AIOMetadata',
      addonId: 'aio-metadata',
      listOnly: true,
      catalogs: [
        ArchiveCatalog.fromJson(
            {'type': 'movies', 'id': 'netflix.new', 'name': 'Netflix - New'})!,
      ],
    );
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([source.toJson()]),
    });
    final storage = StorageService();
    await storage.init();
    final asked = <String>[];
    final hub = ArchiveService(storage,
        api: ArchiveApiService(client: MockClient((request) async {
      asked.add(request.url.path);
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'metas': [
              {'id': 'tt7', 'type': 'movie', 'name': 'A movie'}
            ]
          })),
          200);
    })), cache: _Cache());
    await hub.refresh(force: true);
    expect(asked, contains('/abc/catalog/movies/netflix.new.json'));
    expect([for (final r in hub.rows(ArchiveType.movie)) r.title],
        contains('Netflix - New'));
    expect([for (final r in hub.rows(ArchiveType.series)) r.title],
        isNot(contains('Netflix - New')));
  });
}
