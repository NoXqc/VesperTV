import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';

const _playlist = '#EXTM3U\n'
    '#EXTINF:-1 tvg-id="film-42" group-title="EN Movies",Movie\n'
    'https://example.com/movie.mp4\n'
    '#EXTINF:-1 group-title="TV Shows",Episode\n'
    'https://example.com/episode.mkv\n'
    '#EXTINF:-1 tvg-id="station" group-title="Live",Station\n'
    'https://example.com/live.m3u8\n'
    '#EXTINF:-1 tvg-id="news" group-title="Live",News\n'
    'https://example.com/news.m3u8\n';

/// Cache files in a temp folder instead of path_provider's.
class _DirStorage extends StorageService {
  _DirStorage(this.dir);
  final Directory dir;
  @override
  Future<String> rawCachePath(String name, String ext) async =>
      '${dir.path}/$name.$ext';
  @override
  Future<String?> cacheFilePath(String name) async {
    final f = File('${dir.path}/$name.json');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}

PlaylistSession _session(StorageService storage, String url) => PlaylistSession(
      profile: PlaylistProfile(
          id: 'p',
          name: 'M3U',
          mode: 'm3u',
          m3uUrl: url,
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: CatalogDatabase(),
      favoriteIds: () => {'p::film-42'},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M3U text is saved while loading and restored without the source',
      () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('m3u_source_test_');
    addTearDown(() => temp.delete(recursive: true));
    final playlist = File('${temp.path}/list.m3u');
    await playlist.writeAsString(_playlist);
    final storage = _DirStorage(temp);
    await storage.init();
    // An old JSON cache from before the source cache: dropped by the load.
    final oldJson = File('${temp.path}/m3u_channels_p.json');
    await oldJson.writeAsString('[]');

    final url = Uri.file(playlist.path).toString();
    final first = _session(storage, url);
    await first.loadFromUrl(url);
    expect(first.error, isNull);
    expect(first.channels, hasLength(4));
    final saved = File('${temp.path}/m3u_source_p.m3u');
    expect(await saved.readAsString(), _playlist);
    expect(await File('${saved.path}.part').exists(), isFalse);
    expect(await oldJson.exists(), isFalse);

    // The playlist itself is gone: only the saved text can fill this one.
    await playlist.delete();
    final second = _session(storage, url);
    await second.restoreOrLoad();
    expect(second.error, isNull);
    expect(second.channels.map((c) => c.id),
        ['p::film-42', 'p::ch_2', 'p::station', 'p::news']);
    final movie = second.visibleChannels(category: 'vod').single;
    expect(movie.isFavorite, isTrue);
    expect(movie.isLive, isFalse);
    expect(second.visibleChannels(category: 'tv'), hasLength(2));
    expect(second.tvGroups.map((g) => g.title), ['Live']);
  });

  test('a failed load keeps the previous saved text', () async {
    final temp = await Directory.systemTemp.createTemp('m3u_source_test_');
    addTearDown(() => temp.delete(recursive: true));
    final saved = File('${temp.path}/saved.m3u');
    await saved.writeAsString(_playlist);
    await expectLater(
        M3uParser.fetchAndParseInBackground(
            Uri.file('${temp.path}/missing.m3u').toString(),
            playlistId: 'p',
            saveTo: saved.path),
        throwsA(anything));
    expect(await saved.readAsString(), _playlist);
    expect(await File('${saved.path}.part').exists(), isFalse);
  });

  test('entries share one group title string', () {
    final entries = M3uParser.parse(_playlist, playlistId: 'p');
    expect(identical(entries[2].group, entries[3].group), isTrue);
  });
}
