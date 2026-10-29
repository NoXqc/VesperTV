import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const source =
      ArchiveSource(manifestUrl: 'https://a.example/manifest.json', name: 'A');
  const movie = ArchiveMeta(id: 'tt1', type: ArchiveType.movie, name: 'M');
  const show = ArchiveMeta(id: 'tt2', type: ArchiveType.series, name: 'S');

  Future<ArchiveService> service() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([source.toJson()]),
    });
    final storage = StorageService();
    await storage.init();
    return ArchiveService(storage);
  }

  test('Favourites: a row per category, before Recently watched', () async {
    final s = await service();
    expect(await s.toggleFavorite(source, movie), isTrue);
    expect(await s.toggleFavorite(source, show), isTrue);
    await s.recordWatched(source, movie);

    final allMovies = s.rows(ArchiveType.movie);
    expect(allMovies.first.continuations, isNotNull);
    final movies = allMovies.where((r) => r.continuations == null).toList();
    expect(movies.first.isFavorites, isTrue);
    expect(movies.first.isHistory, isFalse);
    expect(movies.first.items.single.id, 'tt1');
    expect(movies[1].isHistory, isTrue);
    expect(movies.first.key, isNot(movies[1].key));

    final shows = s.rows(ArchiveType.series);
    expect(shows.single.isFavorites, isTrue);
    expect(shows.single.items.single.id, 'tt2');
    expect(s.isFavorite(source, show), isTrue);
  });

  test('toggling again removes it, and the empty row goes', () async {
    final s = await service();
    await s.toggleFavorite(source, movie);
    expect(await s.toggleFavorite(source, movie), isFalse);
    expect(s.isFavorite(source, movie), isFalse);
    expect(s.rows(ArchiveType.movie), isEmpty);
  });
}
