import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/screens/settings/playlist_manager_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';

class _Playlists extends PlaylistManager {
  _Playlists() : super(StorageService(), CatalogDatabase());
  final entries = [
    for (var i = 1; i <= 2; i++)
      PlaylistProfile(
          id: '$i',
          name: 'Playlist $i',
          mode: 'm3u',
          m3uUrl: 'https://example.com/list$i',
          enabled: i == 1,
          sortOrder: i,
          createdAt: DateTime(2026)),
  ];
  final changes = <String>[];
  @override
  List<PlaylistProfile> get profiles => entries;
  @override
  Map<String, int>? summaryFor(String id) => null;
  @override
  DateTime? lastLoadedFor(String id) => null;
  @override
  Future<void> removePlaylist(String id) async {
    changes.add('delete:$id');
    entries.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  @override
  Future<void> setPlaylistEnabled(String id, bool enabled) async {
    changes.add('enable:$id');
    entries.firstWhere((p) => p.id == id).enabled = enabled;
    notifyListeners();
  }
}

Future<_Playlists> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playlists = _Playlists();
  final prefs = AppPreferences(StorageService())
    ..layoutMode = 'auto'
    ..palette = AppConstants.cyberpunkPalettes.first;
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<PlaylistManager>.value(value: playlists),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
          theme: ThemeData.dark(), home: const PlaylistManagerScreen())));
  await tester.pumpAndSettle();
  return playlists;
}

Finder _row(String id) => find.byKey(ValueKey('playlist-row-$id'));

void main() {
  testWidgets('D-pad highlighting updates the pane without enabling a playlist',
      (tester) async {
    final playlists = await _open(tester, const Size(1440, 900));
    expect(find.text('https://example.com/list1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/list2'), findsOneWidget);
    expect(find.text('https://example.com/list1'), findsNothing);
    expect(playlists.entries.last.enabled, isFalse);
    expect(playlists.changes, isEmpty);
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/list2'), findsOneWidget);
    expect(
        FocusScope.of(FocusManager.instance.primaryFocus!.context!).debugLabel,
        'Playlist details');
    expect(tester.takeException(), isNull);
  });

  testWidgets('click selects inline and deleting keeps the manager open',
      (tester) async {
    final playlists = await _open(tester, const Size(1280, 720));
    await tester.tap(_row('2'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/list2'), findsOneWidget);
    expect(
        FocusScope.of(FocusManager.instance.primaryFocus!.context!).debugLabel,
        'Playlist details');
    await tester.tap(find.byTooltip('Delete playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(playlists.changes, ['delete:2']);
    expect(find.byType(PlaylistManagerScreen), findsOneWidget);
    expect(find.text('https://example.com/list1'), findsOneWidget);
    expect(_row('2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow layout keeps selection and readable details on one page',
      (tester) async {
    await _open(tester, const Size(390, 844));
    await tester.ensureVisible(_row('2'));
    await tester.tap(_row('2'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('https://example.com/list2'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/list2'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting the last playlist leaves Add Playlist on the same page',
      (tester) async {
    final playlists = await _open(tester, const Size(1280, 720));
    playlists.entries.removeLast();
    playlists.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Add Playlist'), findsOneWidget);
    expect(find.textContaining('No playlists yet'), findsOneWidget);
    expect(find.byType(PlaylistManagerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
