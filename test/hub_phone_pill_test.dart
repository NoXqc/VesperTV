import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:nox_iptv/widgets/phone_pill_bar.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phone Media Hub (owner, 2026-11-20): Back + title + Refresh on top,
/// search + Menu under it, no empty hero, and the TV home's bottom pill
/// with Movies / TV Shows / Sources / Servers / Discover.
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

Future<Widget> _app(ArchiveService service, StorageService storage,
    {bool television = false}) async {
  final prefs = AppPreferences(storage);
  await prefs.init();
  prefs.isTelevision = television;
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
  Future<ArchiveService> pumpPhone(WidgetTester tester,
      {List<ArchiveSource> sources = const [_aio],
      Size size = const Size(390, 844),
      bool television = false}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage) = await _setUp(sources);
    await tester
        .pumpWidget(await _app(service, storage, television: television));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    });
    return service;
  }

  Finder pill() => find.byType(PhonePillBar);
  Finder inPill(String text) =>
      find.descendant(of: pill(), matching: find.text(text));
  List<String> pillLabels(WidgetTester tester) => [
        for (final item in tester.widget<PhonePillBar>(pill()).items) item.label
      ];

  double centreY(WidgetTester tester, Finder f) => tester.getCenter(f).dy;

  testWidgets('phone: one top row, rows right under it, the pill',
      (tester) async {
    await pumpPhone(tester);
    expect(pillLabels(tester),
        ['Movies', 'TV Shows', 'Sources', 'Sort', 'Discover']);
    expect(tester.widget<PhonePillBar>(pill()).items.first.selected, isTrue);
    // Top row (owner, 2026-11-20): Back, the title, a small search,
    // Servers, Refresh - all on one line.
    final row = centreY(tester, find.text('Media Hub'));
    for (final f in [
      find.byIcon(Icons.arrow_back),
      find.text('Search'),
      find.byIcon(Icons.dns_outlined),
      find.byIcon(Icons.refresh),
    ]) {
      expect(f, findsOneWidget);
      expect((centreY(tester, f) - row).abs(), lessThan(4));
    }
    final search = tester.getRect(find.text('Search'));
    expect(
        search.left, greaterThan(tester.getRect(find.text('Media Hub')).right));
    expect(search.right,
        lessThan(tester.getRect(find.byIcon(Icons.dns_outlined)).left));
    // The old dropdown, Menu and search row are gone.
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    expect(find.text('Menu'), findsNothing);
    expect(find.text('Search movies'), findsNothing);
    expect(find.byIcon(Icons.extension_outlined), findsOneWidget,
        reason: 'Sources: in the pill only');
    // No empty hero between the top row and the first row.
    final firstRow = tester.getTopLeft(find.text('TMDB Trending').first).dy;
    expect(firstRow - row, lessThan(70));
    // The pill sits at the bottom, under the rows.
    expect(tester.getBottomLeft(pill()).dy, greaterThan(800));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: a narrow phone still fits the top row', (tester) async {
    await pumpPhone(tester, size: const Size(320, 640));
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: TV Shows in the pill switches the type', (tester) async {
    await pumpPhone(tester);
    await tester.tap(inPill('TV Shows'));
    await tester.pumpAndSettle();
    final items = tester.widget<PhonePillBar>(pill()).items;
    expect(items[0].selected, isFalse);
    expect(items[1].selected, isTrue);
    // The test add-on's only TV show catalog is kept off the rows.
    expect(find.text('Nothing here yet.'), findsOneWidget);
    await tester.tap(inPill('Movies'));
    await tester.pumpAndSettle();
    expect(tester.widget<PhonePillBar>(pill()).items.first.selected, isTrue);
    expect(find.text('TMDB Trending'), findsWidgets);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: Discover opens the catalogs kept off the rows',
      (tester) async {
    await pumpPhone(tester);
    expect(find.text('TMDB Top Rated'), findsNothing);
    await tester.tap(inPill('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TMDB Top Rated'));
    await tester.pumpAndSettle();
    expect(find.byType(ArchiveCatalogScreen), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: Sort in the pill is the old Menu, minus More catalogs',
      (tester) async {
    await pumpPhone(tester);
    await tester.tap(inPill('Sort'));
    await tester.pumpAndSettle();
    expect(find.text('Watch list'), findsOneWidget);
    expect(find.text('More catalogs'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('phone: no hidden catalogs, no Discover', (tester) async {
    await pumpPhone(tester, sources: const [
      ArchiveSource(
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
    expect(pillLabels(tester), ['Movies', 'TV Shows', 'Sources', 'Sort']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a TV box keeps the rail, no pill', (tester) async {
    await pumpPhone(tester, size: const Size(1280, 720), television: true);
    expect(pill(), findsNothing);
    expect(find.text('More catalogs'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
