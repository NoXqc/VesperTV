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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // +772: Down from the profiles moved the focus to a card but left the
  // strip big (the card's onFocus saw _inProfiles already false).
  testWidgets('profile strip shrinks again after Up then Down', (tester) async {
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
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider<ArchiveService>.value(value: archive),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();

    bool compact() => tester
        .widgetList<ProfileCard>(find.byType(ProfileCard))
        .every((c) => c.compact);
    bool onProfile() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ProfileCard>() !=
        null;

    expect(onProfile(), isFalse);
    expect(compact(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(onProfile(), isTrue);
    expect(compact(), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(onProfile(), isFalse);
    expect(compact(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    archive.dispose();
    prefs.dispose();
  });
}
