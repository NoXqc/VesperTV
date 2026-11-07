import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/vesper_tools.dart';
import 'package:nox_iptv/services/vesper_ai/watch_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Host implements VesperHost {
  @override
  Future<bool> confirm(String question, Map<String, Object?> args) async =>
      true;
  @override
  Future<void> playChannel(Channel channel) async {}
  @override
  Future<void> openSeries(XtreamSeries series) async {}
  @override
  Future<bool> openSection(String section, {String? query}) async => true;
  @override
  void showMessage(String text) {}
}

const _dune =
    ArchiveMeta(id: 'tt1160419', type: ArchiveType.movie, name: 'Dune');
const _severance =
    ArchiveMeta(id: 'tt11280740', type: ArchiveType.series, name: 'Severance');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('watch list', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
    });

    test('Media Hub titles keep their source and type', () async {
      final list = WatchList.instance;
      final movie =
          WatchListItem(hub: const HubTitle('https://a/manifest.json', _dune));
      final show = WatchListItem(
          hub: const HubTitle('https://a/manifest.json', _severance));
      expect(await list.toggle(storage, movie), isTrue);
      expect(await list.toggle(storage, show), isTrue);

      final saved = list.load(storage);
      expect(saved.map((i) => i.title), ['Severance', 'Dune']);
      expect(saved.first.isShow, isTrue);
      expect(saved.last.isShow, isFalse);
      expect(saved.last.hub!.sourceUrl, 'https://a/manifest.json');
      expect(saved.last.kind, 'hub_movie');
      expect(list.contains(storage, movie.id), isTrue);

      // The Watch list button again: off the list.
      expect(await list.toggle(storage, movie), isFalse);
      expect(list.contains(storage, movie.id), isFalse);
      expect(list.load(storage).map((i) => i.title), ['Severance']);
    });

    test('the same title from another source is a separate entry', () {
      final a = WatchListItem(hub: const HubTitle('https://a/m.json', _dune));
      final b = WatchListItem(hub: const HubTitle('https://b/m.json', _dune));
      expect(a.id, isNot(b.id));
    });
  });

  group('watchlist tool', () {
    late VesperToolbox box;
    late StorageService storage;
    final searched = <String>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('vesper_watch_');
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/list.m3u');
      await file.writeAsString([
        '#EXTM3U',
        '#EXTINF:-1 tvg-id="tsn1" group-title="CA| SPORTS",CA: TSN 1',
        'http://x/1.ts',
        '',
      ].join('\n'));
      storage = StorageService();
      await storage.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
      addTearDown(catalog.close);
      final manager = PlaylistManager(storage, catalog);
      addTearDown(manager.dispose);
      await manager.addPlaylist(PlaylistProfile(
          id: 'p',
          name: 'Home',
          mode: 'm3u',
          m3uUrl: Uri.file(file.path).toString(),
          sortOrder: 0,
          createdAt: DateTime(2026)));
      await manager.loadPlaylist('p');
      final prefs = AppPreferences(storage);
      await prefs.init();
      searched.clear();
      box = VesperToolbox(
        playlist: manager,
        playback: PlaybackService(storage, manager),
        epg: EpgService(storage),
        storage: storage,
        prefs: prefs,
        host: _Host(),
        findHubTitle: (name) async {
          searched.add(name);
          return name == 'dune'
              ? const HubTitle('https://a/manifest.json', _dune)
              : null;
        },
      );
    });

    test('adds a Media Hub title by name and lists it', () async {
      final added = await box.call(
          'watchlist', {'action': 'add', 'name': 'dune', 'note': 'Friday'});
      expect(added['added'], isTrue, reason: '$added');
      expect(added['source'], 'Media Hub');
      expect(searched, ['dune']);

      final listed = await box.call('watchlist', {'action': 'list'});
      final entry = (listed['watchlist'] as List).single as Map;
      expect(entry['title'], 'Dune');
      expect(entry['source'], 'Media Hub');
      expect(entry['note'], 'Friday');
      expect('${entry['ref']}', startsWith('h'));

      // Its ref from the list removes it again.
      final removed = await box
          .call('watchlist', {'action': 'remove', 'ref': entry['ref']});
      expect(removed['removed'], isTrue, reason: '$removed');
      expect(WatchList.instance.load(storage), isEmpty);
    });

    test('remove by name takes what is on the list', () async {
      await box.call('watchlist', {'action': 'add', 'name': 'dune'});
      searched.clear();
      final removed =
          await box.call('watchlist', {'action': 'remove', 'name': 'Dune'});
      expect(removed, {'removed': true, 'title': 'Dune'});
      expect(searched, isEmpty, reason: 'no new search for a saved title');
    });

    test('source iptv never asks Media Hub', () async {
      final r = await box.call(
          'watchlist', {'action': 'add', 'name': 'dune', 'source': 'iptv'});
      expect(r['error'], isNotNull);
      expect(searched, isEmpty);
    });
  });
}
