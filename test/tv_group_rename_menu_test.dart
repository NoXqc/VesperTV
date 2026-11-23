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

/// Hold OK on a live group > Rename… (owner, 2026-11-23): the dialog
/// starts on the group's name, Save renames it through PlaylistManager,
/// and a renamed group offers Use the provider's name.
class _Groups extends PlaylistManager {
  _Groups(StorageService storage) : super(storage, CatalogDatabase());

  final renames = <String>[];
  String ligaTitle = 'Liga';

  @override
  Future<String?> renameLiveGroup(
      String playlistId, String shown, String name) async {
    renames.add('$playlistId|$shown|$name');
    ligaTitle = name.isEmpty ? 'Liga' : name;
    notifyListeners();
    return ligaTitle;
  }

  @override
  bool isLiveGroupRenamed(String playlistId, String title) =>
      title != 'Liga' && title == ligaTitle;

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
        M3uGroup(title: ligaTitle, playlistId: 'p', channels: a),
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

  Future<void> holdOk(WidgetTester tester, String text) async {
    await focusText(tester, text);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await settle(tester);
  }

  testWidgets('Rename… on a live group renames it', (tester) async {
    final (_, playlist) = await pumpHome(tester);
    await holdOk(tester, 'Liga');
    expect(find.text('Rename…'), findsOneWidget);
    expect(find.text("Use the provider's name"), findsNothing);
    await tester.tap(find.text('Rename…'));
    await settle(tester);
    expect(find.text('Rename group'), findsOneWidget);
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller!.text, 'Liga');
    // The TV gate keeps the field read-only until OK: type into it.
    tester.widget<TextField>(field).controller!.text = 'Spain';
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(playlist.renames, ['p|Liga|Spain']);
    expect(find.text('Spain'), findsWidgets);

    await holdOk(tester, 'Spain');
    await tester.tap(find.text("Use the provider's name"));
    await settle(tester);
    expect(playlist.renames.last, 'p|Spain|');
    expect(find.text('Liga'), findsWidgets);
  });
}
