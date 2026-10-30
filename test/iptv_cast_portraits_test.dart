import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/series_details.dart';
import 'package:nox_iptv/models/vod_details.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/screens/movie_detail_screen.dart';
import 'package:nox_iptv/screens/series_detail_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_discovery_service.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/archive_discovery_panel.dart';
import 'package:nox_iptv/widgets/detail_header.dart';
import 'package:nox_iptv/widgets/iptv_cast_panel.dart';
import 'package:nox_iptv/widgets/poster_card.dart';

class _Storage extends StorageService {
  @override
  Future<void> writeCacheFile(String name, String content) async {}
}

Channel movie([String id = '10', String name = 'Original (2020)']) => Channel(
    id: 'p::xt_vod_$id',
    rawId: 'xt_vod_$id',
    playlistId: 'p',
    name: name,
    group: 'Movies',
    url: 'https://fixture.test/$id',
    onDemand: true,
    tmdbId: id,
    releaseDate: DateTime(2020));
XtreamSeries show() => XtreamSeries(
    seriesId: 1,
    playlistId: 'p',
    name: 'A Show (2020)',
    categoryId: 's',
    tmdbId: '30',
    releaseDate: DateTime(2020));

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  final vod = [movie(), movie('20', 'Another (2020)')];
  final shows = [show()];
  final asked = <String>[];
  @override
  List<PlaylistProfile> get profiles => [
        PlaylistProfile(
            id: 'p',
            name: 'Fixture',
            mode: 'xtream',
            sortOrder: 0,
            createdAt: DateTime(2020))
      ];
  @override
  List<Channel> get allCachedVod => vod;
  @override
  VodDetails? peekVodDetails(String id) =>
      const VodDetails(cast: 'Provider Actor', releaseDate: '2020-01-01');
  @override
  Future<VodDetails> getVodDetails(Channel channel) async =>
      peekVodDetails(channel.id)!;
  @override
  Future<SeriesEpisodesResult> loadSeriesEpisodes(XtreamSeries series,
          {bool plotOnly = false}) async =>
      (
        episodes: {
          1: [
            Channel(
                id: 'p::xt_ep_1',
                rawId: 'xt_ep_1',
                playlistId: 'p',
                name: 'Episode 1',
                group: 'Shows',
                url: 'https://fixture.test/1',
                onDemand: true)
          ]
        },
        plot: 'Plot',
        details: const SeriesDetails(
            cast: 'Provider Actor', releaseDate: '2020-01-01')
      );
  @override
  Future<List<Channel>> searchVisibleVod(String query, List<String> playlistIds,
      {int limit = 200}) async {
    asked.add('movie:$query:$limit');
    return vod;
  }

  @override
  Future<List<XtreamSeries>> searchVisibleSeries(
      String query, List<String> playlistIds,
      {int limit = 200}) async {
    asked.add('series:$query:$limit');
    return shows;
  }

  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      category == 'vod' ? vod : [];
  @override
  List<XtreamSeries> visibleSeries(
          {String? playlistId, String? categoryName}) =>
      shows;
}

Map<String, dynamic> castBody({bool portraits = false}) => {
      'cast': [
        for (var i = 0; i < 12; i++)
          {
            'id': 100 + i,
            'name': 'Actor $i',
            'character': 'Role $i',
            if (portraits) 'profile_path': '/actor$i.jpg',
          }
      ]
    };

class _Discovery extends ArchiveDiscoveryService {
  _Discovery(this.requests)
      : super(client: MockClient((r) async {
          requests.add(r.url.path);
          return http.Response(
              jsonEncode(r.url.path.contains('/person/')
                  ? {
                      'cast': [
                        {
                          'id': 20,
                          'title': 'Another',
                          'release_date': '2020-01-01',
                          'media_type': 'movie'
                        },
                        {
                          'id': 30,
                          'name': 'A Show',
                          'first_air_date': '2020-01-01',
                          'media_type': 'tv'
                        }
                      ]
                    }
                  : castBody()),
              200);
        }));
  final List<String> requests;
}

class _TitleRoutes extends NavigatorObserver {
  final opened = <MovieDetailScreen>[];
  final shows = <SeriesDetailScreen>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null || route is! MaterialPageRoute) return;
    final page = route.builder(navigator!.context);
    if (page is MovieDetailScreen) {
      opened.add(page);
      scheduleMicrotask(() => navigator!.removeRoute(route));
    } else if (page is SeriesDetailScreen) {
      shows.add(page);
      scheduleMicrotask(() => navigator!.removeRoute(route));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    await storage.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });
  tearDown(() => L10n.code = 'en');

  for (final type in [ArchiveType.movie, ArchiveType.series]) {
    test(
        'direct $type TMDB cast lookup is bounded, cached and carries portraits/roles',
        () async {
      final requests = <Uri>[];
      final api = ArchiveDiscoveryService(client: MockClient((r) async {
        requests.add(r.url);
        return http.Response(jsonEncode(castBody(portraits: true)), 200);
      }));
      final meta = ArchiveMeta(id: 'tmdb:10', type: type, name: 'Original');
      expect(await api.castForTitle(meta, '', 'en'), isEmpty);
      expect(requests, isEmpty);
      final cast = await api.castForTitle(meta, 'fixture-key', 'fr');
      expect(cast, hasLength(12));
      expect(cast.first.image, 'https://image.tmdb.org/t/p/w342/actor0.jpg');
      expect(cast.first.role, 'Role 0');
      await api.castForTitle(meta, 'fixture-key', 'fr');
      expect(requests, hasLength(1));
      expect(requests.single.path,
          '/3/${type == ArchiveType.movie ? 'movie' : 'tv'}/10/credits');
      expect(requests.single.queryParameters['language'], 'fr');
      api.dispose();
    });
  }

  test(
      'missing/zero provider id resolves a decorated title only with exact title and year',
      () async {
    for (final type in [ArchiveType.movie, ArchiveType.series]) {
      final requests = <Uri>[];
      final api = ArchiveDiscoveryService(client: MockClient((r) async {
        requests.add(r.url);
        return http.Response(
            jsonEncode(r.url.path.contains('/search/')
                ? {
                    'results': [
                      {
                        'id': 10,
                        type == ArchiveType.movie ? 'title' : 'name':
                            'Original',
                        type == ArchiveType.movie
                            ? 'release_date'
                            : 'first_air_date': '2020-01-01'
                      },
                      {
                        'id': 99,
                        type == ArchiveType.movie ? 'title' : 'name':
                            'Original',
                        type == ArchiveType.movie
                            ? 'release_date'
                            : 'first_air_date': '1990-01-01'
                      }
                    ]
                  }
                : castBody()),
            200);
      }));
      final result = await api.castForTitle(
          ArchiveMeta(
              id: 'iptv:1', type: type, name: 'EN - Original (2020) FHD'),
          'fixture-key',
          'en');
      expect(result.first.name, 'Actor 0');
      expect(requests.first.queryParameters['query'], 'Original');
      expect(
          requests.first.queryParameters[
              type == ArchiveType.movie ? 'year' : 'first_air_date_year'],
          '2020');
      expect(requests.last.path, contains('/10/credits'));
      api.dispose();
    }
  });

  test('ambiguous remakes or fuzzy titles never show the wrong cast', () async {
    for (final results in [
      [
        {'id': 1, 'title': 'Original'},
        {'id': 2, 'title': 'Original'}
      ],
      [
        {'id': 1, 'title': 'Original Sequel'}
      ],
    ]) {
      final requests = <Uri>[];
      final api = ArchiveDiscoveryService(client: MockClient((r) async {
        requests.add(r.url);
        return http.Response(jsonEncode({'results': results}), 200);
      }));
      expect(
          await api.castForTitle(
              const ArchiveMeta(
                  id: 'iptv:1', type: ArchiveType.movie, name: 'Original'),
              'fixture-key',
              'en'),
          isEmpty);
      expect(requests, hasLength(1));
      api.dispose();
    }
  });

  Future<_Playlist> open(WidgetTester tester,
      {required bool series,
      bool key = true,
      Size size = const Size(1280, 720),
      double scale = 1,
      List<String>? requests,
      NavigatorObserver? observer,
      ArchiveDiscoveryService? discovery}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (key) await storage.setTmdbApiKey('fixture-key');
    final prefs = AppPreferences(storage);
    await prefs.init();
    final playlist = _Playlist(storage);
    final playback = PlaybackService(storage, playlist);
    addTearDown(() {
      playback.dispose();
      playlist.dispose();
      prefs.dispose();
    });
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider.value(value: playback),
        ],
        child: MaterialApp(
            navigatorObservers: [if (observer != null) observer],
            theme: ThemeData.dark(),
            builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: series
                ? SeriesDetailScreen(
                    series: show(),
                    castDiscovery: discovery ?? _Discovery(requests ?? []))
                : MovieDetailScreen(
                    channel: movie(),
                    castDiscovery: discovery ?? _Discovery(requests ?? [])))));
    await tester.pumpAndSettle();
    return playlist;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  test('numeric movie titles are not mistaken for a release year', () async {
    final requests = <Uri>[];
    final api = ArchiveDiscoveryService(client: MockClient((r) async {
      requests.add(r.url);
      return http.Response(
          jsonEncode(r.url.path.contains('/search/')
              ? {
                  'results': [
                    {'id': 1, 'title': '1917', 'release_date': '2019-01-01'}
                  ]
                }
              : castBody()),
          200);
    }));
    expect(
        await api.castForTitle(
            const ArchiveMeta(
                id: 'iptv:1', name: '1917', type: ArchiveType.movie),
            'fixture-key',
            'en'),
        hasLength(12));
    expect(requests.first.queryParameters['query'], '1917');
    expect(requests.first.queryParameters.containsKey('year'), false);
    api.dispose();
  });

  for (final language in ['en', 'fr', 'es', 'it', 'el']) {
    testWidgets('IPTV portrait row supports phone large text in $language',
        (tester) async {
      L10n.code = language;
      await open(tester, series: true, size: const Size(390, 760), scale: 1.4);
      expect(find.text('Actor 0'), findsOneWidget);
      expect(find.text(tr('Metadata provided by TMDB.')), findsOneWidget);
      expect(tester.takeException(), null);
      await close(tester);
    });
  }

  testWidgets('failed metadata leaves Play usable and offers a cast retry',
      (tester) async {
    final api = ArchiveDiscoveryService(
        client: MockClient((_) async => http.Response('{}', 401)));
    await open(tester, series: false, discovery: api);
    final play = tester.widget<DetailPillButton>(
        find.widgetWithText(DetailPillButton, 'Play'));
    expect(play.focusNode.hasFocus, true);
    expect(find.text('Actor 0'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester);
  });

  for (final series in [false, true]) {
    for (final size in [const Size(1280, 720), const Size(390, 760)]) {
      testWidgets(
          'IPTV ${series ? 'show' : 'movie'} portraits have remote entry/row/return at $size',
          (tester) async {
        final requested = <String>[];
        await open(tester, series: series, size: size, requests: requested);
        expect(
            requested, [series ? '/3/tv/30/credits' : '/3/movie/10/credits']);
        expect(find.byType(IptvCastPanel), findsOneWidget);
        expect(find.text('Customize title page'), findsNothing);
        final castButton = find.widgetWithText(DetailPillButton, 'Cast');
        await tester.ensureVisible(castButton);
        await tester.pumpAndSettle();
        await tester.tap(castButton);
        await tester.pumpAndSettle();
        final entry = tester
            .widget<ArchiveDiscoveryPanel>(find.byType(ArchiveDiscoveryPanel))
            .entryNode;
        expect(entry.hasFocus, true);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
            FocusManager.instance.primaryFocus?.debugLabel, 'discovery-cast');
        for (var i = 0; i < 10; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        }
        await tester.pumpAndSettle();
        final actor = find.widgetWithText(PosterCard, 'Actor 10');
        expect(actor.hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.text('Another'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.widget<PosterCard>(actor).focusNode?.hasFocus, true);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(entry.hasFocus, true);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        if (series) {
          expect(FocusManager.instance.primaryFocus?.debugLabel,
              size.width >= 640 ? 'episode-0' : 'series-play');
        } else {
          expect(tester.widget<DetailPillButton>(castButton).focusNode.hasFocus,
              true);
        }
        expect(tester.takeException(), null);
        if (size.width >= 640) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(entry.hasFocus, true);
        }
        await close(tester);
      });
    }
    testWidgets(
        'no key leaves IPTV ${series ? 'show' : 'movie'} cast names and makes no lookup',
        (tester) async {
      final requested = <String>[];
      await open(tester, series: series, key: false, requests: requested);
      expect(requested, isEmpty);
      expect(find.byType(IptvCastPanel), findsNothing);
      expect(find.widgetWithText(DetailPillButton, 'Cast'), findsOneWidget);
      expect(tester.takeException(), null);
      await close(tester);
    });
  }

  testWidgets(
      'actor credits open the matching IPTV movie through a bounded visible search',
      (tester) async {
    final routes = _TitleRoutes();
    final playlist = await open(tester, series: false, observer: routes);
    final castButton = find.widgetWithText(DetailPillButton, 'Cast');
    await tester.ensureVisible(castButton);
    await tester.pumpAndSettle();
    await tester.tap(castButton);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Another'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(playlist.asked, ['movie:Another:40']);
    expect(routes.opened.single.channel.id, 'p::xt_vod_20');
    expect(tester.takeException(), null);
    await close(tester);
  });

  testWidgets('actor credits can open an IPTV show without a Media Hub source',
      (tester) async {
    final routes = _TitleRoutes();
    final playlist = await open(tester, series: false, observer: routes);
    final castButton = find.widgetWithText(DetailPillButton, 'Cast');
    await tester.ensureVisible(castButton);
    await tester.pumpAndSettle();
    await tester.tap(castButton);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(playlist.asked, ['series:A Show:40']);
    expect(routes.shows.single.series.id, 'p::series_1');
    expect(routes.opened, isEmpty);
    expect(tester.takeException(), null);
    await close(tester);
  });

  testWidgets(
      'unavailable actor credit reports no playlist match instead of opening Media Hub',
      (tester) async {
    final routes = _TitleRoutes();
    final playlist = await open(tester, series: false, observer: routes);
    playlist.vod.removeLast();
    final castButton = find.widgetWithText(DetailPillButton, 'Cast');
    await tester.ensureVisible(castButton);
    await tester.pumpAndSettle();
    await tester.tap(castButton);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(routes.opened, isEmpty);
    expect(find.text('No matching title found in your playlists.'),
        findsOneWidget);
    expect(tester.takeException(), null);
    await close(tester);
  });

  testWidgets('old-viewer cast requests cannot publish actor names',
      (tester) async {
    await storage.setTmdbApiKey('fixture-key');
    final gate = Completer<http.Response>();
    final api = ArchiveDiscoveryService(client: MockClient((_) => gate.future));
    final entry = FocusNode();
    await tester.pumpWidget(Provider<StorageService>.value(
        value: storage,
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ArchiveDiscoveryPanel.iptvCast(
                        meta: const ArchiveMeta(
                            id: 'tmdb:1',
                            name: 'Original',
                            type: ArchiveType.movie),
                        entryNode: entry,
                        onReturn: () {},
                        openTitle: (_) async {},
                        discovery: api))))));
    await tester.pump();
    await storage.setActiveViewerId('other');
    gate.complete(http.Response(jsonEncode(castBody()), 200));
    await tester.pumpAndSettle();
    expect(find.text('Actor 0'), findsNothing);
    expect(tester.takeException(), null);
    await close(tester);
    entry.dispose();
  });
}
