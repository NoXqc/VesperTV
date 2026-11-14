import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_catalog_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Expand collection's Sort and Filter (owner, 2026-11-13): sorting loads
/// the whole catalog first, the Filter menu narrows by catalog / genre /
/// decade, and upcoming titles carry Coming soon.
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

final _file = [
  {
    'id': 'streaming',
    'title': 'Streaming',
    'folders': [
      {
        'id': 'netflix',
        'title': 'Netflix',
        'catalogSources': [
          {'addonId': 'aio', 'catalogId': 'nf.movies', 'type': 'movie'},
          {'addonId': 'aio', 'catalogId': 'nf.shows', 'type': 'series'},
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
  ],
);

/// 120 movies, 50 a page (the tile's first load reads 2 pages: 100), and 3
/// shows that start next month.
Map<String, Object?> _movie(int i) => {
      'id': 'ttm$i',
      'type': 'movie',
      'name': 'M$i',
      'released': '${2000 + i % 25}-03-01T00:00:00.000Z',
      'genres': [i.isEven ? 'Drama' : 'Comedy'],
      'popularity': i.toDouble(),
    };

Map<String, Object?> _show(int i) => {
      'id': 'tts$i',
      'type': 'series',
      'name': 'S$i',
      'released': '2099-12-01T00:00:00.000Z',
      'genres': ['Drama'],
    };

Future<(ArchiveService, StorageService, AppPreferences)> _setUp() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([_aio.toJson()]),
  });
  final storage = StorageService();
  await storage.init();
  final api = ArchiveApiService(client: MockClient((request) async {
    final segs = request.url.pathSegments;
    final at = segs.indexOf('catalog');
    if (at < 0) {
      return http.Response.bytes(utf8.encode(jsonEncode(_file)), 200);
    }
    final id = segs[at + 2].replaceAll('.json', '');
    final extra = segs.length > at + 3 ? segs[at + 3] : '';
    final skip =
        int.tryParse(RegExp(r'skip=(\d+)').firstMatch(extra)?.group(1) ?? '') ??
            0;
    final metas = id == 'nf.movies'
        ? [for (var i = skip; i < 120 && i < skip + 50; i++) _movie(i)]
        : (skip == 0 ? [for (var i = 0; i < 3; i++) _show(i)] : const []);
    return http.Response.bytes(utf8.encode(jsonEncode({'metas': metas})), 200);
  }));
  final prefs = AppPreferences(storage);
  await prefs.init();
  prefs.isTelevision = true;
  return (ArchiveService(storage, api: api, cache: _Cache()), storage, prefs);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

List<PosterCard> _cards(WidgetTester tester) =>
    tester.widgetList<PosterCard>(find.byType(PosterCard)).toList();

void main() {
  testWidgets('Sort loads every page; Filter narrows; Coming soon tags',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (service, storage, prefs) = await _setUp();
    await service.importCollections('https://x.example/collections.json');
    final folder = service.collections.single.folders.single;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ArchiveService>.value(value: service),
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
          theme: ThemeData.dark(),
          home: ArchiveCatalogScreen.folder(
              folder: folder, collection: 'Streaming')),
    ));
    await tester.pumpAndSettle();

    // The tile's first load: 2 pages of movies + the shows.
    expect(
        find.text('Streaming   ·   Netflix   ·   103 titles'), findsOneWidget);
    expect(_cards(tester).first.title, 'M0');

    // Up from the top row: the type switch (All); Left x2 = Sort.
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focused, 'archive-grid-filter');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focused, 'archive-grid-sort');

    // Sort > Newest: the rest of the catalog loads, upcoming shows first
    // with their Coming soon tag.
    await _press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Most popular'), findsOneWidget,
        reason: 'the titles carry a popularity score');
    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(
        find.text('Streaming   ·   Netflix   ·   123 titles'), findsOneWidget,
        reason: 'page 3 (movies 100-119) loaded for the sort');
    final sorted = _cards(tester);
    expect(sorted.first.title, 'S0');
    expect(sorted.first.tag, 'Coming soon');
    expect(sorted[3].title, 'M24', reason: 'then 2024 releases');
    expect(find.text('Sort  ·  Newest'), findsOneWidget);

    // Filter > Comedy: odd movies only (60), the button counts 1.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'archive-grid-filters');
    await _press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Netflix Movies'), findsOneWidget,
        reason: 'a tile with 2 catalogs offers them');
    await tester.tap(find.text('Comedy'));
    await tester.pumpAndSettle();
    expect(
        find.text('Streaming   ·   Netflix   ·   60 titles'), findsOneWidget);
    expect(find.text('Filter  ·  1'), findsOneWidget);

    // + the 2000s: Comedy and 2000-2009 (odd i, i % 25 < 10).
    await _press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('2000s'));
    await tester.pumpAndSettle();
    final cards = _cards(tester);
    expect(cards.isNotEmpty, isTrue);
    expect(find.text('Filter  ·  2'), findsOneWidget);
    expect(find.textContaining(RegExp(r'·   2\d titles$')), findsOneWidget);

    // Clear filters: back to everything, still Newest.
    await _press(tester, LogicalKeyboardKey.enter);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(
        find.text('Streaming   ·   Netflix   ·   123 titles'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);

    // Down: back into the grid on the first card.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_focused, 'archive-grid-first');

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });
}
