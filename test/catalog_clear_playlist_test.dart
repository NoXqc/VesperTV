import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late CatalogDatabase catalog;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-clear-');
    catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
  });
  tearDown(() async {
    await catalog.close();
    await temp.delete(recursive: true);
  });

  Channel entry(String playlist, int n) => Channel(
      id: '$playlist::e$n',
      rawId: 'e$n',
      playlistId: playlist,
      name: 'Show S01E$n',
      group: 'Shows',
      url: 'https://example.test/$playlist/$n.mkv',
      onDemand: true);

  Future<void> store(String playlist, int count) => catalog.writeM3uRows(
        vod: [
          for (var n = 0; n < count; n++)
            CatalogDatabase.vodRow('Movies', entry(playlist, n), importMark: 1)
        ],
        episodes: [
          for (var n = 0; n < count; n++)
            CatalogDatabase.episodeRow(entry(playlist, n),
                seriesId: 7, season: 1, episode: n, importMark: 1)
        ],
      );

  Future<int> episodes(String playlist) async =>
      (await catalog.getM3uEpisodes(playlist, 7))
          .values
          .fold<int>(0, (sum, list) => sum + list.length);

  test('clearing one playlist keeps the other one\'s rows', () async {
    await store('a', 25000);
    await store('b', 30);
    await catalog.clearForPlaylist('a');
    expect(await episodes('a'), 0);
    expect(await catalog.getVodCategoryCount('a', 'Movies'), 0);
    expect(await episodes('b'), 30);
    expect(await catalog.getVodCategoryCount('b', 'Movies'), 30);

    // The last playlist with episodes: the table is emptied at once.
    await catalog.clearForPlaylist('b');
    expect(await episodes('b'), 0);
    expect(await catalog.getVodCategoryCount('b', 'Movies'), 0);
  });
}
