import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/widgets/profile_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuidePlaylist;

/// Owner, 2026-11-25: "At the left of the first profile. Can we have a
/// little gear icon for a setting shortcut. Focus should always land on the
/// first profile but going left should show the setting icon."
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Left from the first profile = the Settings gear, then out',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    await storage.setHomeRows([
      for (final kind in HomeRowKind.values)
        kind == HomeRowKind.recentChannels ? kind.id : '-${kind.id}',
    ]);
    final playlist = GuidePlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final prefs = AppPreferences(storage);
    await prefs.init();
    final viewers = ViewerProfileService(storage, playlist, playback);
    final epg = EpgService(storage);
    final archive = ArchiveService(storage);
    await playback.recordWatched(playlist.live);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
          ChangeNotifierProvider<EpgService>.value(value: epg),
          ChangeNotifierProvider<ArchiveService>.value(value: archive),
        ],
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const HomeScreen())),
                        child: const Text('Open Home')))))));
    await tester.tap(find.text('Open Home'));
    await tester.pumpAndSettle();

    final gear = find.byIcon(Icons.settings_outlined);
    expect(gear, findsOneWidget);
    // Owner, 2026-11-26: "kind of hidden to the left with a small
    // indicator": a slim tab until Left reaches it.
    double gearWidth() => tester
        .getSize(find
            .ancestor(of: gear, matching: find.byType(AnimatedContainer))
            .first)
        .width;
    expect(gearWidth(), lessThan(10));
    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
    bool onProfile() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ProfileCard>() !=
        null;

    // Up from the rows lands on the profile, never on the gear.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(onProfile(), isTrue);
    expect(focused(), 'home profile 0');
    expect(gearWidth(), lessThan(10));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focused(), 'home settings');
    expect(gearWidth(), greaterThan(40));
    // Still the full-size row while the gear has the remote.
    expect(
        tester
            .widgetList<ProfileCard>(find.byType(ProfileCard))
            .every((c) => !c.compact),
        isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focused(), 'home profile 0');
    expect(gearWidth(), lessThan(10));

    // Down then Up again: back on the profile, not the gear.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(onProfile(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focused(), 'home profile 0');

    // Left twice: the gear, then out of Home as before.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Open Home'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    archive.dispose();
    prefs.dispose();
  });
}
