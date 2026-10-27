import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/search_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/poster_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Playlists extends PlaylistManager {
  _Playlists(super.storage, super.catalogDb);
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [
        Channel(
            id: category,
            rawId: category,
            playlistId: 'p',
            name: 'Spider-Man $category',
            group: category,
            url: 'https://example.test/video')
      ];
}

void main() {
  testWidgets(
      'global search uses broad title matching for live, M3U movies and M3U shows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final playlists = _Playlists(storage, CatalogDatabase());
    final hub = ArchiveService(storage);
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlists),
          ChangeNotifierProvider<ArchiveService>.value(value: hub),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SearchScreen(initialScope: 'all'))));
    await tester.enterText(find.byType(TextField), 'spiderman');
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<PosterCard>(find.byType(PosterCard))
            .map((p) => p.title),
        ['Spider-Man tv', 'Spider-Man vod', 'Spider-Man series']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    playlists.dispose();
    hub.dispose();
    prefs.dispose();
  });
}
