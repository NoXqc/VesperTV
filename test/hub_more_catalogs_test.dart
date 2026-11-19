import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_catalog_screen.dart';
import 'package:nox_iptv/screens/archive_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Media Hub > More catalogs (woodbooger, Discord 2026-11-19): catalogs an
/// add-on keeps off the home screen (AIOMetadata's Home switch off: a
/// required genre, [ArchiveCatalog.homeHidden]) stay out of the rows but
/// can be opened one at a time as a full grid.
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

const _aio = ArchiveSource(
  manifestUrl: 'https://aio.example/x/manifest.json',
  name: 'AIOMetadata',
  addonId: 'aio',
  listOnly: true,
  catalogs: [
    ArchiveCatalog(
        type: ArchiveType.movie, id: 'tmdb.trending', name: 'TMDB Trending'),
    ArchiveCatalog(
        type: ArchiveType.movie,
        id: 'tmdb.top',
        name: 'TMDB Top Rated',
        homeHidden: true),
    ArchiveCatalog(
        type: ArchiveType.series,
        id: 'tmdb.top',
        name: 'TMDB Top Rated',
        homeHidden: true),
  ],
);

Future<(ArchiveService, StorageService)> _setUp(List<ArchiveSource> sources,
    {List<String>? asked}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources:
        jsonEncode([for (final s in sources) s.toJson()]),
  });
  final storage = StorageService();
  await storage.init();
  final api = ArchiveApiService(client: MockClient((request) async {
    final segs = request.url.pathSegments;
    final at = segs.indexOf('catalog');
    if (at < 0) return http.Response('{}', 404);
    final type = segs[at + 1];
    final id = segs[at + 2].split('.json').first;
    asked?.add('$type/${segs.skip(at + 2).join('/')}');
    return http.Response.bytes(
        utf8.encode(jsonEncode({
          'metas': [
            for (var i = 0; i < 3; i++)
              {'id': 'tt$type$id$i', 'type': type, 'name': '$type $id $i'}
          ]
        })),
        200);
  }));
  return (ArchiveService(storage, api: api, cache: _Cache()), storage);
}

Future<Widget> _app(ArchiveService service, StorageService storage) async {
  final prefs = AppPreferences(storage);
  await prefs.init();
  prefs.isTelevision = true;
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ArchiveService>.value(value: service),
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
    ],
    child: MaterialApp(
        navigatorObservers: [appRouteObserver],
        theme: ThemeData.dark(),
        home: const ArchiveScreen()),
  );
}

void main() {
  test('only the catalogs kept off the home screen, of the type asked',
      () async {
    final (service, _) = await _setUp([_aio]);
    List<String> names(ArchiveType t) => [
          for (final (s, c) in service.browseOnlyCatalogs(t))
            '${s.name}|${c.type.wire}|${c.id}'
        ];
    expect(names(ArchiveType.movie), ['AIOMetadata|movie|tmdb.top']);
    expect(names(ArchiveType.series), ['AIOMetadata|series|tmdb.top']);
    service.dispose();
  });

  test('an add-on under Other lists them only while Other is picked', () async {
    const other = ArchiveSource(
      manifestUrl: 'https://other.example/manifest.json',
      name: 'Other add-on',
      listOnly: true,
      catalogs: [
        ArchiveCatalog(
            type: ArchiveType.movie,
            id: 'hidden',
            name: 'Hidden',
            homeHidden: true),
      ],
    );
    final (service, _) = await _setUp([_aio, other]);
    await service.setUnderOther(
        service.sources.firstWhere((s) => s.name == 'Other add-on'), true);
    expect(service.browseOnlyCatalogs(ArchiveType.movie).map((e) => e.$2.id),
        ['tmdb.top']);
    await service.setGenre(ArchiveType.movie, ArchiveService.otherGenre);
    expect(service.browseOnlyCatalogs(ArchiveType.movie).map((e) => e.$2.id),
        ['hidden']);
    service.dispose();
  });

  test('a browsed catalog is its page alone, asked without a genre', () async {
    final asked = <String>[];
    final (service, _) = await _setUp([_aio], asked: asked);
    final (s, c) = service.browseOnlyCatalogs(ArchiveType.movie).single;
    final folder = service.browseFolder(s, c);
    expect(folder.title, 'TMDB Top Rated');
    // Not the series catalog of the same name (a tile's page would add it).
    expect(service.folderPageCatalogs(folder).map((e) => e.$2.type),
        [ArchiveType.movie]);
    await service.loadFolder(folder);
    expect(asked, ['movie/tmdb.top.json']);
    expect(service.folderRows(folder).single.items.map((m) => m.name),
        ['movie tmdb.top 0', 'movie tmdb.top 1', 'movie tmdb.top 2']);
    service.dispose();
  });

  testWidgets('the bar opens a hidden catalog as a full grid', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp([_aio]);
    await tester.pumpWidget(await _app(service, storage));
    await tester.pumpAndSettle();

    expect(find.text('TMDB Trending'), findsWidgets);
    expect(find.text('TMDB Top Rated'), findsNothing,
        reason: 'kept off the rows, as AIOMetadata asks');
    await tester.tap(find.text('More catalogs'));
    await tester.pumpAndSettle();
    expect(find.text('TMDB Top Rated'), findsOneWidget);
    await tester.tap(find.text('TMDB Top Rated'));
    await tester.pumpAndSettle();

    expect(find.byType(ArchiveCatalogScreen), findsOneWidget);
    expect(find.text('AIOMetadata   ·   TMDB Top Rated   ·   3 titles'),
        findsOneWidget);
    expect(
        tester
            .widgetList<PosterCard>(find.byType(PosterCard))
            .map((c) => c.title),
        ['movie tmdb.top 0', 'movie tmdb.top 1', 'movie tmdb.top 2']);

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('one OK opens the picker; the remote repeat picks nothing',
      (tester) async {
    // Owner, +889 on the Homatics: one press opened the first catalog (its
    // remote sends an OK repeat ~420 ms after a press).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp([_aio]);
    await tester.pumpWidget(await _app(service, storage));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('More catalogs'))).requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('TMDB Top Rated'), findsOneWidget, reason: 'picker open');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveCatalogScreen), findsNothing);
    expect(find.text('TMDB Top Rated'), findsOneWidget,
        reason: 'still choosing');

    // A real second press picks the focused catalog.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveCatalogScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('no hidden catalogs: no More catalogs button', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp([
      const ArchiveSource(
        manifestUrl: 'https://aio.example/x/manifest.json',
        name: 'AIOMetadata',
        listOnly: true,
        catalogs: [
          ArchiveCatalog(
              type: ArchiveType.movie,
              id: 'tmdb.trending',
              name: 'TMDB Trending'),
        ],
      ),
    ]);
    await tester.pumpWidget(await _app(service, storage));
    await tester.pumpAndSettle();
    expect(find.text('TMDB Trending'), findsWidgets);
    expect(find.text('More catalogs'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
