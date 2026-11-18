import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_category.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/content_updates.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/xtream_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Settings > Startup > Update while VesperTV is closed: what's due comes
/// from the saved times alone, the runner does the guide then the due
/// playlists, and a stopped run never counts as a full sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  final now = DateTime(2026, 11, 16, 12);

  PlaylistProfile playlist(String id,
          {String mode = 'xtream', String? epg, bool enabled = true}) =>
      PlaylistProfile(
          id: id,
          name: id,
          mode: mode,
          epgUrl: epg,
          enabled: enabled,
          sortOrder: 0,
          syncFrequencyHours: 6,
          createdAt: DateTime(2026));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    await storage.setRefreshInterval(180);
  });

  group('ContentDue', () {
    test('nothing configured: nothing due', () {
      expect(ContentDue.guideDue(storage, now), isFalse);
      expect(ContentDue.playlistsDue(storage, now), 0);
      expect(ContentDue.next(storage, now), isNull);
    });

    test('a guide never refreshed and a playlist never synced are due',
        () async {
      await storage.setPlaylists([playlist('a', epg: 'http://x/epg.xml')]);
      expect(ContentDue.guideDue(storage, now), isTrue);
      expect(ContentDue.playlistsDue(storage, now), 1);
    });

    test('recent ones are not, and next is the earliest', () async {
      await storage.setPlaylists([
        playlist('a', epg: 'http://x/epg.xml'),
        playlist('b'),
      ]);
      await storage.setEpgLastUpdated(now.subtract(const Duration(hours: 1)));
      await storage.setLastFullSyncAt(
          'a', now.subtract(const Duration(hours: 5)));
      await storage.setLastFullSyncAt(
          'b', now.subtract(const Duration(hours: 1)));
      expect(ContentDue.guideDue(storage, now), isFalse);
      expect(ContentDue.playlistsDue(storage, now), 0);
      // a: 6 h after its sync = 1 h from now; the guide: 2 h; b: 5 h.
      expect(ContentDue.next(storage, now), now.add(const Duration(hours: 1)));
      expect(
          ContentDue.playlistsDue(storage, now.add(const Duration(hours: 2))),
          1);
      expect(ContentDue.guideDue(storage, now.add(const Duration(hours: 2))),
          isTrue);
    });

    test('disabled playlists and M3U playlists never sync', () async {
      await storage.setPlaylists([
        playlist('off', enabled: false, epg: 'http://x/off.xml'),
        playlist('m3u', mode: 'm3u'),
      ]);
      expect(ContentDue.playlistsDue(storage, now), 0);
      // The disabled one's guide doesn't count either.
      expect(ContentDue.guideDue(storage, now), isFalse);
    });
  });

  group('ContentUpdateRunner', () {
    test('nothing due: loads nothing', () async {
      var prepared = false;
      final outcome = await ContentUpdateRunner(
        storage: storage,
        prepare: () async => prepared = true,
        refreshGuide: () async => fail('no guide'),
        syncPlaylists: () async => fail('no sync'),
        now: () => now,
      ).run();
      expect(outcome.result, 'nothing_due');
      expect(prepared, isFalse);
    });

    test('guide first, then the due playlists', () async {
      await storage.setPlaylists([playlist('a', epg: 'http://x/epg.xml')]);
      final steps = <String>[];
      final outcome = await ContentUpdateRunner(
        storage: storage,
        prepare: () async => steps.add('prepare'),
        refreshGuide: () async {
          steps.add('guide');
          return true;
        },
        syncPlaylists: () async {
          steps.add('sync');
          return (1, 1);
        },
        now: () => now,
      ).run();
      expect(steps, ['prepare', 'guide', 'sync']);
      expect(outcome.toJson(),
          {'result': 'ok', 'guide': 'updated', 'synced': 1, 'due': 1});
    });

    test('a failed guide or an unfinished playlist is partial', () async {
      await storage.setPlaylists([playlist('a', epg: 'http://x/epg.xml')]);
      final outcome = await ContentUpdateRunner(
        storage: storage,
        refreshGuide: () async => false,
        syncPlaylists: () async => (0, 1),
        now: () => now,
      ).run();
      expect(outcome.result, 'partial');
      expect(outcome.guide, 'failed');
    });

    test('stopped (the app opened): nothing more starts', () async {
      await storage.setPlaylists([playlist('a', epg: 'http://x/epg.xml')]);
      final outcome = await ContentUpdateRunner(
        storage: storage,
        stopReason: () => 'app_opened',
        refreshGuide: () async => fail('no guide'),
        syncPlaylists: () async => fail('no sync'),
        now: () => now,
      ).run();
      expect(outcome.toJson(), {
        'result': 'stopped(app_opened)',
        'guide': 'stopped',
        'synced': 0,
        'due': 1
      });
    });
  });

  group('PlaylistSession stop', () {
    late Directory temp;
    late HttpServer server;
    CatalogDatabase? catalog;

    setUp(() async {
      HttpOverrides.global = null; // the test binding fakes HTTP otherwise
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      temp = await Directory.systemTemp.createTemp('vesper-closed-');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        request.response
          ..headers.contentType = ContentType.json
          ..write('[]')
          ..close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await catalog?.close();
      await temp.delete(recursive: true);
    });

    PlaylistSession session() {
      final s = PlaylistSession(
          profile: playlist('p'),
          storage: storage,
          catalogDb: catalog =
              CatalogDatabase(databasePath: '${temp.path}/catalog.db'),
          favoriteIds: () => {},
          favoriteSeriesIds: () => {},
          isRestrictedViewer: () => false,
          onNotify: () {});
      s.xtreamApi = XtreamApiService(
          server: 'http://127.0.0.1:${server.port}',
          username: 'u',
          password: 'p',
          playlistId: 'p');
      s.vodCategories = [
        for (var i = 0; i < 12; i++) XtreamCategory(id: '$i', name: 'Movies $i')
      ];
      return s;
    }

    test('a stopped pass is not a full sync', () async {
      final s = session();
      var asked = 0;
      final done = await s.refreshAllCategories(stop: () => ++asked > 3);
      expect(done, isFalse);
      expect(storage.getLastFullSyncAt('p'), isNull);
      expect(s.needsFullSync(), isTrue);
    });

    test('a pass that runs to the end is', () async {
      final s = session();
      expect(await s.refreshAllCategories(stop: () => false), isTrue);
      expect(storage.getLastFullSyncAt('p'), isNotNull);
      expect(s.needsFullSync(), isFalse);
    });
  });
}
