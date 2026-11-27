import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/device_memory_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/live_group_styles.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/group_colors.dart';
import 'package:nox_iptv/widgets/live_style_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live group styles on the TV (owner, 2026-11-26): Colour… on
/// Favourites / History too, and Live styles… (moving backgrounds from the
/// bank) that move only while the remote is on the row.
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
  late final b = [for (var i = 1; i <= 2; i++) _ch('b$i', 'Cup $i', 'Cup')];

  @override
  List<Channel> get channels => [...a, ...b];

  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'Liga', playlistId: 'p', channels: a),
        M3uGroup(title: 'Cup', playlistId: 'p', channels: b),
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
    // TV boxes: styles follow the remote (touch screens move on show).
    DeviceTypeService.television = true;
    addTearDown(() => DeviceTypeService.television = false);
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

  /// A row with a live style: no pumpAndSettle while one moves.
  Future<void> steps(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Finder specialRow(String label) => find.descendant(
      of: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_SelectableRow'),
      matching: find.text(label));

  Future<void> holdSpecial(WidgetTester tester, String label) async {
    Focus.of(tester.element(specialRow(label).first)).requestFocus();
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    // HoldToActivate wants the remote's repeats as proof of a hold.
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await settle(tester);
  }

  /// Taps a menu row, scrolled into view first (the colour menu scrolls on
  /// a TV-sized screen).
  Future<void> tapRow(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pump();
    await tester.tap(find.text(text).last);
  }

  /// The fade behind a Favourites / History row, if any.
  Color? specialFadeOf(WidgetTester tester, String label) {
    for (final box in tester.widgetList<DecoratedBox>(find.ancestor(
        of: specialRow(label).first, matching: find.byType(DecoratedBox)))) {
      final d = box.decoration;
      if (d is BoxDecoration && d.gradient is LinearGradient) {
        final first = (d.gradient! as LinearGradient).colors.first;
        if (first.a > 0.3 && first.a < 0.5) return first.withValues(alpha: 1);
      }
    }
    return null;
  }

  Finder styleIn(Finder row) => find.ancestor(
      of: row,
      matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_StyledRowBox'));

  bool hasStyle(WidgetTester tester, Finder row) => find
      .descendant(of: styleIn(row), matching: find.byType(LiveStyleBackground))
      .evaluate()
      .isNotEmpty;

  /// The style clock of [row]'s live style (it only runs while moving).
  double clockOf(WidgetTester tester, Finder row) => (tester
          .widget<CustomPaint>(find
              .descendant(of: styleIn(row), matching: find.byType(CustomPaint))
              .first)
          .painter! as LiveStylePainter)
      .time
      .value;

  setUp(() => LiveGroupStyles.instance.debugUse(LiveGroupStyles.parse(
      File('docs/styles/group-styles.json').readAsStringSync())));
  tearDown(LiveGroupStyles.instance.debugReset);

  testWidgets('Favourites and History: hold = Colour… + their own action',
      (tester) async {
    final playlist = await pumpHome(tester);
    await holdSpecial(tester, 'Favourites');
    expect(find.text('Colour…'), findsOneWidget);
    expect(find.text('Clear favourites…'), findsOneWidget);
    await tapRow(tester, 'Colour…');
    await settle(tester);
    await tapRow(tester, 'Red');
    await settle(tester);
    expect(playlist.groupColorOf(null, '__favorites__'), 'red');
    await focusRow(tester, 'Liga');
    expect(specialFadeOf(tester, 'Favourites'), GroupColor.of('red'));
    expect(specialFadeOf(tester, 'History'), isNull);

    // What a hold did before is one step away.
    await holdSpecial(tester, 'Favourites');
    await tapRow(tester, 'Clear favourites…');
    await settle(tester);
    expect(find.text('Clear favourites?'), findsOneWidget);
    await tapRow(tester, 'Cancel');
    await settle(tester);

    await holdSpecial(tester, 'History');
    expect(find.text('Delete watched history…'), findsOneWidget);
    await tapRow(tester, 'Delete watched history…');
    await settle(tester);
    expect(find.text('Delete watched history?'), findsOneWidget);
    await tapRow(tester, 'Cancel');
    await settle(tester);

    await holdSpecial(tester, 'History');
    await tapRow(tester, 'Colour…');
    await settle(tester);
    await tapRow(tester, 'Green');
    await settle(tester);
    expect(playlist.groupColorOf(null, '__history__'), 'green');
    await focusRow(tester, 'Liga');
    expect(specialFadeOf(tester, 'History'), GroupColor.of('green'));
  });

  testWidgets('Live styles…: the bank, then a style that moves on focus only',
      (tester) async {
    final playlist = await pumpHome(tester);
    await holdOk(tester, 'Mine');
    await tapRow(tester, 'Colour…');
    await settle(tester);
    expect(find.text('Live styles…'), findsOneWidget);
    await tapRow(tester, 'Live styles…');
    await steps(tester);
    // By category, each a moving preview.
    expect(find.text('Live styles'), findsOneWidget);
    for (final name in ['Seasonal', 'Vesper', 'Sports', 'Fun']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.byType(LiveStyleBackground), findsWidgets);
    await tapRow(tester, 'Snowfall');
    await steps(tester);
    expect(playlist.groupColorOf(null, 'Mine'), 'style:snowfall');
    expect(find.text('Live styles'), findsNothing);

    // On it: moving. Elsewhere: still (no frames asked for).
    Focus.of(tester.element(rowText('Mine').first)).requestFocus();
    await steps(tester);
    expect(hasStyle(tester, rowText('Mine').first), isTrue);
    final before = clockOf(tester, rowText('Mine').first);
    await steps(tester);
    expect(clockOf(tester, rowText('Mine').first), greaterThan(before),
        reason: 'moving');
    Focus.of(tester.element(rowText('Liga').first)).requestFocus();
    await steps(tester);
    await tester.pumpAndSettle();
    expect(hasStyle(tester, rowText('Mine').first), isTrue,
        reason: 'still there at rest');
    final rest = clockOf(tester, rowText('Mine').first);
    await steps(tester);
    expect(clockOf(tester, rowText('Mine').first), rest, reason: 'still');
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(hasStyle(tester, rowText('Liga').first), isFalse);

    // The menu ticks Live styles…; No colour clears it.
    Focus.of(tester.element(rowText('Mine').first)).requestFocus();
    await steps(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await steps(tester);
    await tapRow(tester, 'Colour…');
    await steps(tester);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tapRow(tester, 'No colour');
    await steps(tester);
    expect(playlist.groupColorOf(null, 'Mine'), isNull);
    expect(hasStyle(tester, rowText('Mine').first), isFalse);
  });

  testWidgets('Select more groups lists Favourites and History first',
      (tester) async {
    final playlist = await pumpHome(tester);
    await holdOk(tester, 'Mine');
    await tapRow(tester, 'Colour…');
    await settle(tester);
    await tapRow(tester, 'Select more groups…');
    await settle(tester);
    final picker = find
        .byWidgetPredicate((w) => w.runtimeType.toString() == 'GroupMultiPick');
    final names = [
      for (final t in tester.widgetList<Text>(
          find.descendant(of: picker, matching: find.byType(Text))))
        t.data,
    ];
    expect(names.indexOf('Favourites'), lessThan(names.indexOf('Mine')));
    expect(names.indexOf('History'), lessThan(names.indexOf('Mine')));
    await tester
        .tap(find.descendant(of: picker, matching: find.text('Favourites')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(find.text('Colour for 2 groups'), findsOneWidget);
    await tapRow(tester, 'Live styles…');
    await steps(tester);
    expect(find.text('Live style for 2 groups'), findsOneWidget);
    await tapRow(tester, 'Christmas');
    await steps(tester);
    expect(playlist.groupColorOf(null, 'Mine'), 'style:christmas');
    expect(playlist.groupColorOf(null, '__favorites__'), 'style:christmas');
  });
}
