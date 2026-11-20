import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/desktop_multiview_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Multiview with a TV remote (Apple TV uses the computers' Multiview):
/// Discord, 2026-11-20, "clicking on the + does nothing". The screen-sized
/// key wrapper had focus, so no arrow found a screen and OK did nothing.
final _channels = [
  for (final name in ['Channel A', 'Channel B', 'Channel C'])
    Channel(
        id: 'p::$name',
        rawId: name,
        playlistId: 'p',
        name: name,
        group: 'News',
        url: 'http://host/live/$name.ts'),
];

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      _channels;
}

void main() {
  Future<void> pump(WidgetTester tester,
      {required bool tv, WidgetBuilder? home}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setMultiviewMain(false);
    await storage.setMultiviewQuad(true);
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = tv;
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider<PlaylistManager>(
            create: (_) => _Playlist(storage)),
      ],
      child: MaterialApp(
          home: home == null
              ? const DesktopMultiviewScreen()
              : Builder(builder: home)),
    ));
    await tester.pump();
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  bool rowFocused(WidgetTester tester, String name) =>
      Focus.of(tester.element(find.text(name))).hasPrimaryFocus;

  testWidgets('a remote starts on the first screen and arrows move between',
      (tester) async {
    await pump(tester, tv: true);
    expect(focused(), 'desktop-multiview-cell-0');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(), 'desktop-multiview-cell-1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'desktop-multiview-cell-3');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(focused(), 'desktop-multiview-cell-2');
  });

  testWidgets('OK on an empty screen opens the picker on the first channel',
      (tester) async {
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Search channels...'), findsOneWidget);
    // The list has the remote, not the search field (its arrows would move
    // a cursor), and the keyboard waits for OK.
    expect(rowFocused(tester, 'Channel A'), isTrue);
    expect(focused(), isNot('desktop-multiview-search'));
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rowFocused(tester, 'Channel B'), isTrue);
    // Back closes the picker onto the screen it was opened from.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Search channels...'), findsNothing);
    expect(focused(), 'desktop-multiview-cell-1');
  });

  testWidgets('a computer keeps typing in the picker at once', (tester) async {
    await pump(tester, tv: false);
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();
    expect(focused(), 'desktop-multiview-search');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets('Back leaves Multiview (nothing playing: no channel back)',
      (tester) async {
    Object? result = 'unset';
    await pump(tester,
        tv: true,
        home: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Channel>(
                    MaterialPageRoute(
                        builder: (_) => const DesktopMultiviewScreen()));
              },
              child: const Text('open'),
            ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(focused(), 'desktop-multiview-cell-0');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMultiviewScreen), findsNothing);
    expect(result, isNull);
  });
}
