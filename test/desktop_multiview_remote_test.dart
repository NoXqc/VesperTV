import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/desktop_multiview_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/widgets/sports_mode_live_panel.dart';
import 'package:nox_iptv/screens/multiview_screen.dart' show MultiviewCellTile;
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Multiview with a TV remote (Apple TV): Android's Multiview on the
/// media_kit players (owner, 2026-11-20: both TV apps the same). Discord,
/// 2026-11-20, "clicking on the + does nothing": the screen-sized key
/// wrapper had focus, so no arrow found a screen and OK did nothing.
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

class _Epg extends EpgService {
  _Epg(super.storage);
}

void main() {
  Future<void> pump(WidgetTester tester,
      {required bool tv, WidgetBuilder? home, bool tips = false}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setMultiviewMain(false);
    await storage.setMultiviewQuad(true);
    await storage.setMultiviewHideTips(!tips);
    final playlist = _Playlist(storage);
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = tv;
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
        ChangeNotifierProvider<EpgService>(create: (_) => _Epg(storage)),
        ChangeNotifierProvider<PlaybackService>(
            create: (_) => PlaybackService(storage, playlist)),
      ],
      child: MaterialApp(
          home: home == null
              ? const DesktopMultiviewScreen()
              : Builder(builder: home)),
    ));
    await tester.pump();
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  testWidgets('a remote: one screen with focus, the header on Up',
      (tester) async {
    await pump(tester, tv: true);
    await tester.pump();
    expect(focused(), 'desktop-multiview-cell-0');
    // Android's tiles, one screen to start with (Add screen adds more).
    expect(find.byType(MultiviewCellTile), findsOneWidget);
    // The header slides away after 4 s; a small Up arrow says it's there.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(focused(), 'desktop-multiview-header-first');
    expect(find.text('Add screen'), findsOneWidget);
    expect(find.text('Equal screens'), findsOneWidget);
    // Down: back to the screen.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(focused(), 'desktop-multiview-cell-0');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('OK on the empty screen opens the live guide, Back closes it',
      (tester) async {
    await pump(tester, tv: true);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SportsModeLivePanel), findsOneWidget);
    for (var i = 0;
        i < 3 && find.byType(SportsModeLivePanel).evaluate().isNotEmpty;
        i++) {
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SportsModeLivePanel), findsNothing);
    // Still in Multiview, on the screen it was opened from.
    expect(find.byType(DesktopMultiviewScreen), findsOneWidget);
    expect(focused(), 'desktop-multiview-cell-0');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Add screen from the header: screen 2, the guide, no header',
      (tester) async {
    await pump(tester, tv: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SportsModeLivePanel), findsOneWidget);
    expect(find.byType(MultiviewCellTile), findsNWidgets(2));
    // The header slid away: it stayed over the guide's titles (tour, +921).
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide).last).offset,
        const Offset(0, -1));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a remote: the tips first, OK closes them onto screen 1',
      (tester) async {
    await pump(tester, tv: true, tips: true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Before you start'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Before you start'), findsNothing);
    expect(focused(), 'desktop-multiview-cell-0');
    await tester.pump(const Duration(seconds: 5));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(focused(), 'desktop-multiview-cell-0');
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DesktopMultiviewScreen), findsNothing);
    expect(result, isNull);
  });
}
