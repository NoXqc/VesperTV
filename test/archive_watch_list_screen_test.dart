import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/screens/archive_watch_list_screen.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vesper_ai/watch_list.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _source = ArchiveSource(
    manifestUrl: 'https://source.example/manifest.json',
    name: 'Source',
    catalogs: [
      ArchiveCatalog(type: ArchiveType.movie, id: 'all', name: 'All')
    ]);

void main() {
  testWidgets('Media Hub Watch list: Movies and TV Shows rows, hold removes',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([_source.toJson()])
    });
    final storage = StorageService();
    await storage.init();
    final service = ArchiveService(storage, cache: _Cache());
    addTearDown(service.dispose);
    final list = WatchList.instance;
    await list.add(
        storage,
        WatchListItem(
            hub: const HubTitle(
                'https://source.example/manifest.json',
                ArchiveMeta(
                    id: 'tt1', type: ArchiveType.movie, name: 'Dune'))));
    await list.add(
        storage,
        WatchListItem(
            hub: const HubTitle(
                'https://source.example/manifest.json',
                ArchiveMeta(
                    id: 'tt2', type: ArchiveType.series, name: 'Severance'))));
    // IPTV entries belong to Movies / TV Shows, not this page.
    expect(list.load(storage), hasLength(2));

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: service),
      ],
      child: const MaterialApp(home: ArchiveWatchListScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Movies (1)'), findsOneWidget);
    expect(find.text('TV Shows (1)'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Severance'), findsOneWidget);

    // Remote: the first row's card has focus, Down goes to TV Shows.
    final focused = FocusManager.instance.primaryFocus;
    expect(focused?.debugLabel, 'hub-watch-movie-0');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'hub-watch-show-0');

    // Long press = hold OK: off the list, the row goes.
    await tester.longPress(find.text('Severance'));
    await tester.pumpAndSettle();
    expect(find.text('Severance'), findsNothing);
    expect(find.text('TV Shows (1)'), findsNothing);
    expect(list.load(storage).map((i) => i.title), ['Dune']);
  });
}
