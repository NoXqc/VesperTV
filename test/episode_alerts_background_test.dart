import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_service.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/episode_alert_lookup.dart';
import 'package:nox_iptv/services/episode_alerts.dart';
import 'package:nox_iptv/services/episode_alerts_background.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late List<EpisodeNotice> posted;
  late int lookups;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    posted = [];
    lookups = 0;
  });

  Future<void> seed(
      {String viewer = 'main',
      DateTime? checked,
      String key = 'iptv:p:7'}) async {
    await storage.setEpisodeAlerts(
        jsonEncode({
          'shows': [
            FollowedShow(
                    key: key,
                    title: 'Show ABC',
                    playlistId: 'p',
                    seriesId: 7,
                    lastSeason: 1,
                    lastEpisode: 2,
                    checkedAt: checked ??
                        DateTime.now().subtract(const Duration(hours: 4)))
                .toJson()
          ],
          'notices': [],
        }),
        viewerId: viewer);
  }

  EpisodeBackgroundRunner runner(
          {Future<bool> Function()? allowed,
          Future<EpisodeStatus?> Function(StorageService, FollowedShow)? lookup,
          Future<void> Function(StorageService, String, String)? persist}) =>
      EpisodeBackgroundRunner(
        storage: storage,
        canRun: allowed ?? () async => true,
        lookup: lookup ??
            (_, show) async {
              lookups++;
              return const EpisodeStatus(season: 1, episode: 3);
            },
        notify: (notice) async => posted.add(notice),
        persist: persist,
      );

  test('foreground skips all lookups and writes', () async {
    await seed();
    final before = storage.getEpisodeAlerts();
    final result = await runner(allowed: () async => false).run();
    expect(result.result, 'skipped(foreground)');
    expect(lookups, 0);
    expect(posted, isEmpty);
    expect(storage.getEpisodeAlerts(), before);
  });

  test('no follows and recently checked shows do no network work', () async {
    expect((await runner().run()).result, 'skipped(no_follows)');
    await seed(
        checked:
            DateTime.now().subtract(const Duration(hours: 2, minutes: 59)));
    expect((await runner().run()).result, 'skipped(recent)');
    expect(lookups, 0);
    expect(posted, isEmpty);
  });

  test('three-hour due boundary is shared by foreground and background', () {
    final now = DateTime(2026, 11, 5, 20);
    final show = FollowedShow(key: 's', title: 'Show', checkedAt: now);
    expect(
        EpisodeAlerts.isDue(
            show,
            now
                .add(const Duration(hours: 3))
                .subtract(const Duration(milliseconds: 1))),
        isFalse);
    expect(
        EpisodeAlerts.isDue(show, now.add(const Duration(hours: 3))), isTrue);
  });

  test(
      'all viewers checked without changing the active viewer or leaking names',
      () async {
    final kid = ViewerProfile(
        id: 'kid',
        name: 'Private name',
        colorIndex: 1,
        isRestricted: true,
        createdAt: DateTime.now());
    await storage.setViewerProfiles([ViewerProfile.main(), kid]);
    await seed();
    await seed(viewer: 'kid', key: 'iptv:p:8');
    final result = await runner().run();
    expect(result.shows, 2);
    expect(result.fresh, 2);
    expect(lookups, 2);
    expect(storage.getActiveViewerId(), 'main');
    expect(posted.map((n) => n.title), everyElement('Show ABC'));
    final scoped = StorageService();
    await scoped.init(viewerId: 'kid', migrate: false);
    expect(EpisodeAlerts(scoped).notices.single.episode, 3);
    final disk = StorageService();
    await disk.init();
    expect(disk.getActiveViewerId(), 'main');
  });

  test('same show across viewers creates both Home notices but posts once',
      () async {
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'other',
          name: 'Other',
          colorIndex: 1,
          isRestricted: false,
          createdAt: DateTime.now())
    ]);
    await seed();
    await seed(viewer: 'other');
    final result = await runner().run();
    expect(result.shows, 2);
    expect(result.fresh, 1);
    expect(posted, hasLength(1));
    final scoped = StorageService();
    await scoped.init(viewerId: 'other', migrate: false);
    expect(EpisodeAlerts(scoped).notices, hasLength(1));
  });

  test('worker checkpoints prevent another worker and foreground double-notify',
      () async {
    await seed();
    final foreground = EpisodeAlerts(storage);
    foreground.lookup = (_) async => const EpisodeStatus(season: 1, episode: 3);
    foreground.systemNotify = (notice) async => posted.add(notice);
    foreground.beforeCheck = foreground.refreshFromDisk;
    expect((await runner().run()).fresh, 1);
    expect((await runner().run()).result, 'skipped(recent)');
    await foreground.checkAll(force: true);
    expect(posted, hasLength(1));
    expect(foreground.notices.single.episode, 3);
    foreground.dispose();
  });

  test('foreground return during lookup cancels write and notification',
      () async {
    await seed();
    final before = storage.getEpisodeAlerts();
    var allowed = true;
    final result = await runner(
        allowed: () async => allowed,
        lookup: (_, show) async {
          allowed = false;
          return const EpisodeStatus(season: 1, episode: 3);
        }).run();
    expect(result.result, 'skipped(foreground)');
    expect(posted, isEmpty);
    expect(storage.getEpisodeAlerts(), before);
  });

  test('invalidated compare-and-set never posts or overwrites newer choices',
      () async {
    await seed();
    final result = await runner(persist: (scoped, viewer, data) async {
      await storage.setEpisodeAlerts('{"shows":[],"notices":[]}');
      throw StateError('checkpoint invalidated');
    }).run();
    expect(result.result, 'error');
    expect(posted, isEmpty);
    expect(EpisodeAlerts(storage).shows, isEmpty);
  });

  test('unavailable or offline lookups leave checkpoints untouched for retry',
      () async {
    await seed();
    final before = storage.getEpisodeAlerts();
    final result =
        await runner(lookup: (_, show) async => throw StateError('offline'))
            .run();
    expect(result.result, 'error');
    expect(result.fresh, 0);
    expect(storage.getEpisodeAlerts(), before);
    expect(posted, isEmpty);
  });

  test('checkpoint is durable before the OS notifier is called', () async {
    await seed();
    final alerts = EpisodeAlerts(storage);
    alerts.lookup = (_) async => const EpisodeStatus(season: 1, episode: 3);
    alerts.systemNotify = (notice) async {
      expect(EpisodeAlerts(storage).show(notice.showKey)!.lastEpisode, 3);
      expect(EpisodeAlerts(storage).notices.single.episode, 3);
      throw StateError('notifications denied');
    };
    await alerts.checkAll();
    expect(alerts.notices, hasLength(1));
    alerts.dispose();
  });

  test('headless IPTV fetches only the followed series with stored credentials',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final queries = <Map<String, String>>[];
    final subscription = server.listen((request) async {
      queries.add(request.uri.queryParameters);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'info': {},
        'episodes': {
          '1': [
            {
              'id': '71',
              'season': 1,
              'episode_num': 3,
              'title': 'Episode 3',
              'container_extension': 'mp4'
            }
          ]
        }
      }));
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final archive = ArchiveService(storage);
    addTearDown(archive.dispose);
    await storage.setPlaylists([
      PlaylistProfile(
          id: 'p',
          name: 'Fixture',
          mode: 'xtream',
          xtreamServer: 'http://127.0.0.1:${server.port}',
          xtreamUsername: 'fixture',
          xtreamPassword: 'fixture',
          sortOrder: 0,
          createdAt: DateTime.now())
    ]);
    final lookup = EpisodeAlertLookup.background(storage, archive);
    final result = await HttpOverrides.runWithHttpOverrides(
        () => lookup.lookup(FollowedShow(
            key: 'iptv:p:7', title: 'Show ABC', playlistId: 'p', seriesId: 7)),
        _RealHttp());
    expect(result!.episode, 3);
    expect(queries, hasLength(1));
    expect(queries.single['action'], 'get_series_info');
    expect(queries.single['series_id'], '7');
    expect(queries.single['username'], 'fixture');
    final profile = storage.getPlaylists().single..enabled = false;
    await storage.setPlaylists([profile]);
    expect(
        await lookup.lookup(FollowedShow(
            key: 'iptv:p:7', title: 'Show ABC', playlistId: 'p', seriesId: 7)),
        isNull);
    expect(queries, hasLength(1));
  });

  test('headless Media Hub reads only metadata and ignores future episodes',
      () async {
    const source = ArchiveSource(
        manifestUrl: 'https://fixture.test/manifest.json', name: 'Fixture');
    await storage.setArchiveSourcesJson(jsonEncode([source.toJson()]));
    final prefs = await SharedPreferences.getInstance();
    final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          jsonEncode({
            'meta': {
              'id': 'show',
              'type': 'series',
              'name': 'Show ABC',
              'videos': [
                {
                  'id': 'show:1:3',
                  'season': 1,
                  'episode': 3,
                  'title': 'Now',
                  'released': '2020-01-01'
                },
                {
                  'id': 'show:1:4',
                  'season': 1,
                  'episode': 4,
                  'title': 'Later',
                  'released': '2099-01-01'
                }
              ]
            }
          }),
          200);
    });
    final archive =
        ArchiveService(storage, api: ArchiveApiService(client: client));
    addTearDown(() {
      archive.dispose();
      client.close();
    });
    final result = await EpisodeAlertLookup.background(storage, archive).lookup(
        FollowedShow(
            key: 'hub:show',
            title: 'Show ABC',
            sourceUrl: source.manifestUrl,
            meta: {'id': 'show', 'type': 'series', 'name': 'Show ABC'}));
    expect(result!.episode, 3);
    expect(result.next!.episode, 4);
    expect(paths, ['/meta/series/show.json']);
    expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before,
        reason: 'no migrations, catalog/cache writes or identity registration');
  });

  test('notification formatting uses saved language and stable per-show id',
      () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('vespertv/notify');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      L10n.code = 'en';
    });
    await L10n.apply('fr');
    await EpisodeAlertLookup.notify(EpisodeNotice(
        showKey: 'iptv:p:7',
        title: 'Show ABC',
        season: 1,
        episode: 3,
        at: DateTime.now()));
    expect(calls.single.arguments['title'], 'Show ABC');
    expect(calls.single.arguments['text'], contains('S1 E3'));
    expect(calls.single.arguments['channel'], 'Nouveaux épisodes');
    expect(calls.single.arguments['id'],
        EpisodeAlertLookup.notificationId('iptv:p:7'));
    expect(EpisodeAlertLookup.notificationId('iptv:p:7'),
        isNot(EpisodeAlertLookup.notificationId('iptv:p:8')));
  });

  test('notification tap waits for app/profile readiness and is consumed once',
      () async {
    const channel = EpisodeAlertsBackground.channel;
    var pending = true, ready = false, opened = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'hasTap') return pending;
      if (call.method == 'clearTap') {
        pending = false;
        return null;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final alerts = EpisodeAlerts(storage);
    final bridge = EpisodeAlertsBackground(alerts, onOpen: () {
      if (!ready) return false;
      opened++;
      return true;
    });
    expect(await bridge.openPending(), isFalse);
    expect(pending, isTrue);
    ready = true;
    expect(await Future.wait([bridge.openPending(), bridge.openPending()]),
        [true, false]);
    expect(await bridge.openPending(), isFalse);
    expect(opened, 1);
    bridge.dispose();
    alerts.dispose();
  });
}
