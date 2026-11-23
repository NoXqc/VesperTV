import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/from_another_device_screen.dart';
import 'package:nox_iptv/screens/welcome_add_playlist_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/cloud_sync_service.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/mode_button.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A sync that never reaches the server.
class _OffSync extends CloudSyncService {
  _OffSync(super.storage);
  @override
  SyncStatus get status => SyncStatus.off;
}

/// First launch: "From another device" (BallerMC, Discord, 2026-11-22: a new
/// Apple TV install offered only Skip / Add Playlist).
void main() {
  Future<AppPreferences> prefsFor(StorageService storage,
      {bool tv = true}) async {
    final prefs = AppPreferences(storage)..isTelevision = tv;
    await prefs.init();
    return prefs;
  }

  Future<void> tvSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final lang in ['en', 'fr', 'de', 'el', 'uk']) {
    testWidgets('welcome screen: three buttons in one row on a TV ($lang)',
        (tester) async {
      await tvSize(tester);
      await L10n.apply(lang);
      addTearDown(() => L10n.apply('en'));
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final prefs = await prefsFor(storage);
      addTearDown(prefs.dispose);
      WelcomeChoice? answer;
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: prefs,
          child: WelcomeAddPlaylistScreen(onRespond: (v) => answer = v)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // no overflow

      final buttons = find.byType(ModeButton);
      expect(buttons, findsNWidgets(3));
      final tops = [
        for (var i = 0; i < 3; i++) tester.getTopLeft(buttons.at(i)).dy
      ];
      final heights = [
        for (var i = 0; i < 3; i++) tester.getSize(buttons.at(i)).height
      ];
      expect(tops.toSet(), hasLength(1)); // one row
      expect(heights.toSet(), hasLength(1)); // same height if one wraps

      await tester.tap(find.text(tr('From another device')));
      expect(answer, WelcomeChoice.fromAnotherDevice);
      await tester.tap(find.text(tr('Skip for now')));
      expect(answer, WelcomeChoice.skip);
      await tester.tap(find.text(tr('Add Playlist')));
      expect(answer, WelcomeChoice.addPlaylist);
    });
  }

  testWidgets('a phone stacks them: Add Playlist, From another device, Skip',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = await prefsFor(storage, tv: false);
    addTearDown(prefs.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs, child: WelcomeAddPlaylistScreen(onRespond: (_) {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final y = [
      for (final label in [
        'Add Playlist',
        'From another device',
        'Skip for now'
      ])
        tester.getTopLeft(find.text(label)).dy
    ];
    expect(y[0] < y[1] && y[1] < y[2], isTrue);
  });

  group('FromAnotherDeviceScreen', () {
    Future<void> pump(WidgetTester tester) async {
      await tvSize(tester);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final prefs = await prefsFor(storage);
      final sync = _OffSync(storage);
      addTearDown(sync.dispose);
      addTearDown(prefs.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<CloudSyncService>.value(value: sync),
          ChangeNotifierProvider.value(value: prefs),
          Provider.value(value: ParentalPin(storage)),
          Provider.value(value: storage),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(), home: const FromAnotherDeviceScreen()),
      ));
      await tester.pumpAndSettle();
    }

    TvMenuTile tile(WidgetTester tester, String title) =>
        tester.widget<TvMenuTile>(find.widgetWithText(TvMenuTile, title));

    testWidgets('Sync is focused first; a backup only where files exist',
        (tester) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(TvMenuTile, 'Sync'), findsOneWidget);
      expect(tile(tester, 'Sync').autofocus, isTrue);
      expect(find.widgetWithText(TvMenuTile, 'Receive a transfer'),
          findsOneWidget);
      expect(find.widgetWithText(TvMenuTile, 'Restore a backup'),
          FromAnotherDeviceScreen.offersBackup ? findsOneWidget : findsNothing);
    });

    testWidgets('Sync opens I have a code over Sync (never Set up sync first)',
        (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(TvMenuTile, 'Sync'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('I have a code'), findsWidgets);
      expect(find.text('Set up sync'), findsNothing);
      // Back = Sync's own page, then this one.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Set up sync'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TvMenuTile, 'Receive a transfer'),
          findsOneWidget);
    });

    testWidgets('Receive a transfer opens the receiving side', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(TvMenuTile, 'Receive a transfer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Receive on this device'), findsOneWidget);
      expect(find.text('Send from this device'), findsNothing);
    });
  });
}
