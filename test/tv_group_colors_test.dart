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
import 'package:nox_iptv/utils/group_colors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hold OK on a group > Colour… (owner, 2026-11-25): the row wears the
/// colour as a fine fade (white name) while the remote is elsewhere and
/// keeps the usual highlight when the remote is on it.
class _Groups extends PlaylistManager {
  _Groups(StorageService storage) : super(storage, CatalogDatabase());

  static Channel _ch(String id, String name, String group) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: name,
      group: group,
      url: 'https://example.com/$id');

  late final a = [for (var i = 1; i <= 3; i++) _ch('a$i', 'Liga $i', 'Liga')];

  @override
  List<Channel> get channels => a;

  @override
  List<M3uGroup> get tvGroups =>
      [M3uGroup(title: 'Liga', playlistId: 'p', channels: a)];

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

  Future<_Groups> pumpHome(WidgetTester tester,
      {String columnLines = ''}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyShowClock: false,
      if (columnLines.isNotEmpty) AppConstants.keyColumnLines: columnLines,
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = 'live';
    prefs.keepGroupsOpen = true;
    final playlist = _Groups(storage);
    await playlist.createUserGroup('Mine');
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
    return playlist;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  Finder rowText(String label) => find.descendant(
      of: find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_GroupRow'),
      matching: find.text(label));

  Future<void> focusRow(WidgetTester tester, String label) async {
    Focus.of(tester.element(rowText(label).first)).requestFocus();
    await settle(tester);
  }

  Future<void> holdOk(WidgetTester tester, String label) async {
    await focusRow(tester, label);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await settle(tester);
  }

  Color? colorOf(WidgetTester tester, String label) =>
      tester.widget<Text>(rowText(label).first).style?.color;

  /// The colour of the fade behind [label]'s row, if any.
  Color? fadeOf(WidgetTester tester, String label) {
    for (final box in tester.widgetList<DecoratedBox>(find.ancestor(
        of: rowText(label).first, matching: find.byType(DecoratedBox)))) {
      final d = box.decoration;
      if (d is BoxDecoration && d.gradient is LinearGradient) {
        final first = (d.gradient! as LinearGradient).colors.first;
        if (first.a > 0.3 && first.a < 0.5) return first.withValues(alpha: 1);
      }
    }
    return null;
  }

  testWidgets('Colour… paints the group at rest, the usual highlight on it',
      (tester) async {
    final playlist = await pumpHome(tester);
    final red = GroupColor.of('red')!;

    // A live group offers it too.
    await holdOk(tester, 'Liga');
    expect(find.text('Colour…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    await holdOk(tester, 'Mine');
    await tester.tap(find.text('Colour…'));
    await settle(tester);
    expect(find.text('Group colour'), findsOneWidget);
    expect(find.text('No colour'), findsOneWidget);
    for (final c in GroupColor.presets) {
      expect(find.text(c.name), findsOneWidget);
    }
    await tester.tap(find.text('Red'));
    await settle(tester);
    expect(playlist.groupColorOf(null, 'Mine'), 'red');

    await focusRow(tester, 'Liga');
    expect(fadeOf(tester, 'Mine'), red, reason: 'a red fade at rest');
    expect(colorOf(tester, 'Mine'), Colors.white,
        reason: 'the name stays white');
    expect(fadeOf(tester, 'Liga'), isNull);

    await focusRow(tester, 'Mine');
    expect(fadeOf(tester, 'Mine'), isNull,
        reason: 'highlighted normally when the remote is on it');

    // The picker starts on the current colour; No colour clears it.
    await holdOk(tester, 'Mine');
    await tester.tap(find.text('Colour…'));
    await settle(tester);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('No colour'));
    await settle(tester);
    expect(playlist.groupColorOf(null, 'Mine'), isNull);
    await focusRow(tester, 'Liga');
    expect(fadeOf(tester, 'Mine'), isNull);
  });

  test('column line colours: theme, accent, white, presets', () {
    const scheme = ColorScheme.dark(primary: Colors.amber);
    expect(columnLineColorOf('', scheme), isNull);
    expect(columnLineColorOf('accent', scheme), Colors.amber);
    expect(columnLineColorOf('white', scheme), Colors.white70);
    expect(columnLineColorOf('blue', scheme), GroupColor.of('blue'));
    expect(columnLineColorOf('mauve', scheme), isNull);
  });

  testWidgets('Column lines colour the lines between the columns',
      (tester) async {
    await pumpHome(tester, columnLines: 'red');
    final colors = [
      for (final d
          in tester.widgetList<VerticalDivider>(find.byType(VerticalDivider)))
        d.color
    ];
    expect(colors, contains(GroupColor.of('red')));
    // The horizontal lines too (owner's photo: tabs column, under the
    // preview, under the guide's hours).
    final across = [
      for (final d in tester.widgetList<Divider>(find.byType(Divider))) d.color
    ];
    expect(across, contains(GroupColor.of('red')));
  });

  testWidgets("Default keeps the theme's lines", (tester) async {
    await pumpHome(tester);
    final colors = [
      for (final d
          in tester.widgetList<VerticalDivider>(find.byType(VerticalDivider)))
        d.color
    ];
    expect(colors, isNot(contains(GroupColor.of('red'))));
    expect(colors.where((c) => c != null && c != Colors.transparent), isEmpty);
    expect([
      for (final d in tester.widgetList<Divider>(find.byType(Divider))) d.color
    ], isNot(contains(GroupColor.of('red'))));
  });
}
