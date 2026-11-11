import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/screens/hub_folder_screen.dart';
import 'package:nox_iptv/screens/settings/hub_collections_pane.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/collection_tile.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Media Hub tab with a collection (owner, 2026-11-11): a row of
/// tiles after Continue watching, OK opens the tile's page of catalogs,
/// and the catalogs it holds leave the tab's rows.
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

// No pictures: the tiles draw their names (no network images in tests).
final _file = [
  {
    'id': 'streaming',
    'title': '🎬 Streaming',
    'folders': [
      {
        'id': 'netflix',
        'title': 'Netflix',
        'catalogSources': [
          {'addonId': 'aio', 'catalogId': 'nf.movies', 'type': 'movie'},
          {'addonId': 'aio', 'catalogId': 'nf.shows', 'type': 'series'},
        ]
      },
      {
        'id': 'prime',
        'title': 'Prime Video',
        'tileShape': 'POSTER',
        'catalogSources': [
          {'addonId': 'aio', 'catalogId': 'pv.movies', 'type': 'movie'},
        ]
      },
    ]
  }
];

const _aio = ArchiveSource(
  manifestUrl: 'https://aio.example/x/manifest.json',
  name: 'AIOMetadata',
  addonId: 'aio',
  listOnly: true,
  catalogs: [
    ArchiveCatalog(
        type: ArchiveType.movie, id: 'nf.movies', name: 'Netflix Movies'),
    ArchiveCatalog(
        type: ArchiveType.series, id: 'nf.shows', name: 'Netflix Shows'),
    ArchiveCatalog(
        type: ArchiveType.movie, id: 'pv.movies', name: 'Prime Movies'),
    ArchiveCatalog(type: ArchiveType.movie, id: 'popular', name: 'Popular'),
  ],
);

Future<(ArchiveService, StorageService)> _setUp(
    {ArchiveSource source = _aio, Object? file}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([source.toJson()]),
  });
  final storage = StorageService();
  await storage.init();
  final api = ArchiveApiService(client: MockClient((request) async {
    final segs = request.url.pathSegments;
    final at = segs.indexOf('catalog');
    if (at < 0) {
      return http.Response.bytes(utf8.encode(jsonEncode(file ?? _file)), 200);
    }
    final type = segs[at + 1];
    final id = segs[at + 2].split('.json').first;
    return http.Response.bytes(
        utf8.encode(jsonEncode({
          'metas': [
            for (var i = 0; i < 3; i++)
              {'id': 'tt$id$i', 'type': type, 'name': '$id $i'}
          ]
        })),
        200);
  }));
  return (ArchiveService(storage, api: api, cache: _Cache()), storage);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

/// The focused poster's title.
String? _focusedPoster(WidgetTester tester) => tester
    .widgetList<PosterCard>(find.byType(PosterCard))
    .where((c) => c.focusNode?.hasFocus ?? false)
    .firstOrNull
    ?.title;

Widget _app(ArchiveService service, StorageService storage, Widget home) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<AppPreferences>.value(
            value: AppPreferences(storage)..isTelevision = true),
      ],
      child: MaterialApp(
          navigatorObservers: [appRouteObserver],
          theme: ThemeData.dark(),
          home: home),
    );

void main() {
  testWidgets('tiles after the rows they replace; OK opens the page',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp();
    await service.importCollections('https://x.example/collections.json');
    await tester.pumpWidget(_app(service, storage, const ArchiveScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Streaming'), findsOneWidget);
    expect(find.byType(CollectionTile), findsNWidgets(2));
    expect(find.text('Popular'), findsWidgets,
        reason: 'a catalog in no collection stays a row (and a bar jump)');
    expect(find.text('Netflix Movies'), findsNothing,
        reason: 'the tiles hold their catalogs');

    // Rail -> the first row, the tiles.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'archive-card');
    expect(find.text('Streaming · 2 catalogs'), findsOneWidget,
        reason: 'the hero names the collection');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Streaming · 1 catalogs'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowLeft);

    // OK: Netflix's page, its two catalogs, the first title focused.
    await _press(tester, LogicalKeyboardKey.enter);
    expect(find.byType(HubFolderScreen), findsOneWidget);
    expect(find.text('Netflix Movies'), findsOneWidget);
    expect(find.text('Netflix Shows'), findsOneWidget);
    expect(_focused, 'folder-card');
    expect(_focusedPoster(tester), 'nf.movies 0');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedPoster(tester), 'nf.movies 1');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedPoster(tester), 'nf.shows 0');
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focusedPoster(tester), 'nf.movies 1',
        reason: 'back to where it was in that row');

    // Back: the tab again; with the switch off the rows come back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HubFolderScreen), findsNothing);
    await service.setCollectionsHideRows(false);
    await tester.pumpAndSettle();
    expect(find.text('Netflix Movies'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('same-named catalogs on a page say Movies / TV Shows',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const named = ArchiveSource(
      manifestUrl: 'https://aio.example/x/manifest.json',
      name: 'AIOMetadata',
      addonId: 'aio',
      listOnly: true,
      catalogs: [
        ArchiveCatalog(
            type: ArchiveType.movie, id: 'nf.movies', name: '🎬 Netflix'),
        ArchiveCatalog(
            type: ArchiveType.series, id: 'nf.shows', name: '🎬 Netflix'),
        ArchiveCatalog(
            type: ArchiveType.series, id: 'nf.top', name: 'Netflix Top 10'),
      ],
    );
    final (service, storage) = await _setUp(source: named);
    await service.importCollections('https://x.example/collections.json');
    final folder = service.collections.single.folders.first;
    await tester.pumpWidget(_app(service, storage,
        HubFolderScreen(folder: folder, collection: 'Streaming')));
    await tester.pumpAndSettle();
    expect(find.text('Netflix (Movies)'), findsOneWidget);
    expect(find.text('Netflix (TV Shows)'), findsOneWidget);
    expect(find.text('Netflix Top 10'), findsOneWidget,
        reason: 'a catalog named after the tile joins its page');
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('the community pack starts with only Streaming on',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp(file: [
      {
        'id': 'discover',
        'title': '🔭 Discover',
        'folders': [
          {
            'id': 'popular',
            'title': 'Popular',
            'catalogSources': [
              {'addonId': 'aio', 'catalogId': 'popular', 'type': 'movie'}
            ]
          }
        ]
      },
      ..._file,
    ]);
    await tester.pumpWidget(
        _app(service, storage, const Scaffold(body: HubCollectionsPane())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community pack: Nuvio Perfect Collections'));
    await tester.pumpAndSettle();
    expect({for (final c in service.collections) c.label: c.enabled},
        {'Discover': false, 'Streaming': true});
    expect(service.collectionRows(ArchiveType.movie).map((r) => r.customTitle),
        ['Streaming']);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets("a tile's page: a poster held 2 s opens wide, like the tab",
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([_aio.toJson()]),
    });
    final storage = StorageService();
    await storage.init();
    final service = ArchiveService(storage, cache: _Cache(),
        api: ArchiveApiService(client: MockClient((request) async {
      final segs = request.url.pathSegments;
      final at = segs.indexOf('catalog');
      if (at < 0) {
        return http.Response.bytes(utf8.encode(jsonEncode(_file)), 200);
      }
      final id = segs[at + 2].split('.json').first;
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'metas': [
              for (var i = 0; i < 4; i++)
                {
                  'id': 'tt$id$i',
                  'type': segs[at + 1],
                  'name': '$id $i',
                  'background': 'https://img.test/$id$i.jpg'
                }
            ]
          })),
          200);
    })));
    await service.importCollections('https://x.example/collections.json');
    final folder = service.collections.single.folders.first;
    await tester.pumpWidget(_app(service, storage,
        HubFolderScreen(folder: folder, collection: 'Streaming')));
    await tester.pumpAndSettle();
    PosterCard card(String title) => tester.widget<PosterCard>(
        find.byWidgetPredicate((w) => w is PosterCard && w.title == title));

    expect(_focused, 'folder-card');
    expect(card('nf.movies 0').wideWidth, isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(card('nf.movies 0').wideWidth, PosterCard.wideCardWidth,
        reason: 'held two seconds: wide, with its backdrop');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(card('nf.movies 0').wideWidth, isNull, reason: 'closes on a move');
    expect(card('nf.movies 1').wideWidth, isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(card('nf.movies 1').wideWidth, PosterCard.wideCardWidth);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('a tile whose catalogs are gone says so', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp();
    await service.importCollections('https://x.example/collections.json');
    final folder = service.collections.single.folders.first;
    await service.setEnabled(service.sources.single, false);
    await tester.pumpWidget(_app(service, storage,
        HubFolderScreen(folder: folder, collection: 'Streaming')));
    await tester.pumpAndSettle();
    expect(find.textContaining("This tile's catalogs aren't in your add-ons"),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('Settings: import the community pack, a collection row',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp();
    await tester.pumpWidget(
        _app(service, storage, const Scaffold(body: HubCollectionsPane())));
    await tester.pumpAndSettle();
    expect(
        find.text('Community pack: Nuvio Perfect Collections'), findsOneWidget);
    await tester.tap(find.text('Community pack: Nuvio Perfect Collections'));
    await tester.pumpAndSettle();
    expect(service.collections.single.link, kPerfectCollectionsLink);
    expect(find.text('Streaming'), findsOneWidget);
    expect(find.text('2 of 2 tiles found in your add-ons'), findsOneWidget);
    expect(find.text('Community pack: Nuvio Perfect Collections'), findsNothing,
        reason: 'offered only until it is imported');
    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
