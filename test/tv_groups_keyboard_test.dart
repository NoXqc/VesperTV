import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings > Interface > Live TV (a Windows keyboard viewer, 2026-11-14):
/// Show channels while moving through groups, and Keep groups open.
class _TwoGroups extends PlaylistManager {
  _TwoGroups(StorageService storage) : super(storage, CatalogDatabase());

  static Channel _ch(String id, String name, String group) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: group,
      url: 'https://example.com/$id');

  final a = _ch('a', 'Alpha One', 'Group A');
  final b = _ch('b', 'Bravo One', 'Group B');

  @override
  List<Channel> get channels => [a, b];

  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'Group A', playlistId: 'p', channels: [a]),
        M3uGroup(title: 'Group B', playlistId: 'p', channels: [b]),
      ];

  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [
        for (final c in channels)
          if (groupTitle == null || c.group == groupTitle) c
      ];
}

class _NoGuide extends EpgService {
  _NoGuide(super.storage);

  @override
  List<EpgProgram> getPrograms(String channelId) => [];
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });

  Future<void> pumpHome(WidgetTester tester,
      {required bool follow, required bool keepOpen}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = 'live';
    prefs.groupsFollowFocus = follow;
    prefs.keepGroupsOpen = keepOpen;
    final playlist = _TwoGroups(storage);
    final playback = PlaybackService(storage, playlist);
    final epg = _NoGuide(storage);
    final viewers = ViewerProfileService(storage, playlist, playback);
    await tester.pumpWidget(MultiProvider(providers: [
      Provider.value(value: storage),
      ChangeNotifierProvider.value(value: prefs),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider.value(value: playback),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider.value(value: viewers),
    ], child: const MaterialApp(home: TvHomeScreen())));
    await tester.pumpAndSettle();
    // The one-off launch-update delay/timeout, in virtual time.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 16));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      viewers.dispose();
      playlist.dispose();
      prefs.dispose();
      epg.dispose();
      await tester.pump();
    });
  }

  Future<void> focusText(WidgetTester tester, String text) async {
    Focus.of(tester.element(find.text(text).first)).requestFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  testWidgets('moving through groups shows their channels, focus stays',
      (tester) async {
    await pumpHome(tester, follow: true, keepOpen: false);
    await focusText(tester, 'Group A');
    expect(find.text('Alpha One'), findsOneWidget);
    expect(find.text('Bravo One'), findsNothing);
    await focusText(tester, 'Group B');
    expect(find.text('Bravo One'), findsOneWidget);
    expect(find.text('Alpha One'), findsNothing);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
        focused != null &&
            find
                .ancestor(
                    of: find.byWidget(focused.widget),
                    matching: find.text('Group B'))
                .evaluate()
                .isEmpty &&
            find
                .descendant(
                    of: find.byWidget(focused.widget),
                    matching: find.text('Group B'))
                .evaluate()
                .isNotEmpty,
        isTrue,
        reason: 'still on the Group B row');
  });

  testWidgets('without the setting a highlight changes nothing',
      (tester) async {
    await pumpHome(tester, follow: false, keepOpen: false);
    await focusText(tester, 'Group A');
    await focusText(tester, 'Group B');
    expect(find.text('Bravo One'), findsNothing,
        reason: 'OK still picks the group');
  });

  for (final keepOpen in [true, false]) {
    testWidgets('Keep groups open = $keepOpen', (tester) async {
      await pumpHome(tester, follow: true, keepOpen: keepOpen);
      await focusText(tester, 'Group B');
      // Into the channels (Right / OK).
      await focusText(tester, 'Bravo One');
      expect(find.text('Group A').hitTestable(),
          keepOpen ? findsOneWidget : findsNothing);
    });
  }
}
