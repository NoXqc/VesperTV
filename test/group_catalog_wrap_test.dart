import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/group_catalog_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Expand catalog on a TV (owner photo, 2026-11-17): Right on a row's last
// title went up to Sort at the top right; it goes on to the next row now.

class _Catalog extends CatalogDatabase {
  _Catalog(this.items);
  final List<Channel> items;

  @override
  Future<List<Channel>> getVodCategory(String playlistId, String categoryName,
          {int? limit, String? orderBy}) async =>
      items;
}

void main() {
  testWidgets('Right at the end of a row goes to the next row, Left back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final movies = [
      for (var i = 0; i < 30; i++)
        Channel(
            id: 'p::m$i',
            rawId: 'm$i',
            playlistId: 'p',
            name: 'Movie $i',
            group: '2026 Releases',
            url: 'https://x/m$i.mkv',
            onDemand: true),
    ];
    final catalog = _Catalog(movies);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        Provider<CatalogDatabase>.value(value: catalog),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider<PlaylistManager>(
            create: (_) => PlaylistManager(storage, catalog)),
      ],
      child: const MaterialApp(
        home: GroupCatalogScreen(
            category: 'vod', playlistId: 'p', title: '2026 Releases'),
      ),
    ));
    await tester.pumpAndSettle();

    String? focusedTitle() {
      for (final card
          in tester.widgetList<PosterCard>(find.byType(PosterCard))) {
        if (card.focusNode?.hasFocus ?? false) return card.title;
      }
      return null;
    }

    final first =
        tester.widget<PosterCard>(find.byType(PosterCard).first).focusNode!;
    first.requestFocus();
    await tester.pump();
    expect(focusedTitle(), 'Movie 0');
    var steps = 0;
    final rowTops = <double>{};
    for (var i = 0; i < 40 && focusedTitle() != null; i++) {
      final before = focusedTitle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      if (focusedTitle() == before) break;
      steps++;
      rowTops.add(tester
          .getTopLeft(find.widgetWithText(PosterCard, focusedTitle()!))
          .dy);
    }
    // Right walked every title in order, across rows, and never left the
    // grid for Sort.
    expect(steps, movies.length - 1);
    expect(focusedTitle(), 'Movie ${movies.length - 1}');
    expect(rowTops.length, greaterThan(1));
    // Left from the first title of a row goes to the previous row's last.
    for (var i = 0; i < movies.length - 1; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
    }
    expect(focusedTitle(), 'Movie 0');
    expect(tester.takeException(), isNull);
  });
}
