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

/// uzumaki (Fire TV, Discord 2026-11-21): "When I select a group, no channel
/// is selected". OK on a group must land on the new group's first channel
/// whatever the old list looked like, in the list guide and the Timeline,
/// and never pass through the old group's rows on the way (on the Homatics
/// the old list's row 0 took focus and the new group opened with nothing
/// focused: owner photo, same day).
class _Groups extends PlaylistManager {
  _Groups(StorageService storage) : super(storage, CatalogDatabase());

  static Channel _ch(String id, String name, String group) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: group,
      url: 'https://example.com/$id');

  late final a = [for (var i = 1; i <= 40; i++) _ch('a$i', 'Liga $i', 'Liga')];
  late final b = [for (var i = 1; i <= 3; i++) _ch('b$i', 'Ligue $i', 'Ligue')];

  @override
  List<Channel> get channels => [...a, ...b];

  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'Liga', playlistId: 'p', channels: a),
        M3uGroup(title: 'Ligue', playlistId: 'p', channels: b),
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

  Future<(PlaybackService, _Groups)> pumpHome(WidgetTester tester,
      {bool keepOpen = true, String mode = 'live'}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = mode;
    prefs.keepGroupsOpen = keepOpen;
    final playlist = _Groups(storage);
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
    return (playback, playlist);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  Future<void> focusText(WidgetTester tester, String text) async {
    Focus.of(tester.element(find.text(text).first)).requestFocus();
    await settle(tester);
  }

  String? focusedRowText(WidgetTester tester) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return null;
    final texts = find.descendant(
        of: find.byElementPredicate((e) => e == ctx),
        matching: find.byType(Text));
    return texts.evaluate().map((e) => (e.widget as Text).data).join('|');
  }

  /// Every row that had focus on the way, by its texts.
  Future<List<String?>> pickGroup(WidgetTester tester, String group) async {
    await focusText(tester, group);
    final path = <String?>[];
    void note() => path.add(focusedRowText(tester));
    FocusManager.instance.addListener(note);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    FocusManager.instance.removeListener(note);
    return path;
  }

  testWidgets('OK on a group from an untouched list: its first channel',
      (tester) async {
    await pumpHome(tester);
    await pickGroup(tester, 'Liga');
    await pickGroup(tester, 'Ligue');
    expect(focusedRowText(tester), startsWith('Ligue 1'));
  });

  testWidgets('OK on a group after scrolling far down the old one',
      (tester) async {
    await pumpHome(tester);
    await pickGroup(tester, 'Liga');
    expect(focusedRowText(tester), startsWith('Liga 1'));
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await settle(tester);
    expect(find.text('Liga 1').hitTestable(), findsNothing,
        reason: 'the old list is scrolled past its first row');
    await pickGroup(tester, 'Ligue');
    expect(focusedRowText(tester), startsWith('Ligue 1'));
  });

  testWidgets('OK on a group while the old first row is the playing channel',
      (tester) async {
    final (playback, playlist) = await pumpHome(tester);
    playback.currentChannel = playlist.a.first;
    await pickGroup(tester, 'Liga');
    await pickGroup(tester, 'Ligue');
    expect(focusedRowText(tester), startsWith('Ligue 1'));
  });

  testWidgets("groups that fold away: never the old group's rows on the way",
      (tester) async {
    await pumpHome(tester, keepOpen: false);
    await pickGroup(tester, 'Liga');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    final path = await pickGroup(tester, 'Ligue');
    expect(path.where((t) => t != null && t.startsWith('Liga')), isEmpty,
        reason: "the old list's row 0 took focus first: $path");
    expect(focusedRowText(tester), startsWith('Ligue 1'));
  });

  testWidgets('Timeline guide: OK on a group goes to its first channel',
      (tester) async {
    await pumpHome(tester, keepOpen: false, mode: 'timeline');
    await pickGroup(tester, 'Liga');
    final primary = FocusManager.instance.primaryFocus;
    expect(primary?.debugLabel, isNot('group-row'),
        reason: 'focus stayed on the group');
    // .last: the description above the guide names it too.
    final row = tester.getRect(find.text('Liga 1').last);
    expect(primary!.rect.top, lessThan(row.bottom));
    expect(primary.rect.bottom, greaterThan(row.top),
        reason: "not on the first channel's row");
  });
}
