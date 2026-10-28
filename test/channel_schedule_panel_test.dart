import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/programme_reminders.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/widgets/channel_schedule_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's Channel schedule (OK, Up, OK): opens on the programme
/// playing, OK on a past one = catch-up from its start, OK on the one on
/// now from catch-up = back to live, upcoming ones do nothing.
final _cu = Channel(
  id: 'p::cu.ca',
  rawId: 'cu.ca',
  playlistId: 'p',
  name: 'Catchup channel',
  group: 'News',
  url: 'http://host:80/live/u/pw/11.ts',
  catchupDays: 2,
  catchupKind: CatchupKind.xc,
  streamId: '11',
);

/// Half-hour programmes from 6 h ago to 6 h ahead.
class _Epg extends EpgService {
  _Epg(super.storage);
  final DateTime base = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour)
        .subtract(const Duration(hours: 6));
  }();
  late final List<EpgProgram> rows = [
    for (var i = 0; i < 24; i++)
      EpgProgram(
          channelId: 'cu.ca',
          title: 'Show $i',
          description: 'About show $i',
          start: base.add(Duration(minutes: 30 * i)),
          stop: base.add(Duration(minutes: 30 * (i + 1)))),
  ];

  @override
  List<EpgProgram> getPrograms(String channelId) => rows;
}

void main() {
  late _Epg epg;
  late StorageService storage;
  late ProgrammeReminders reminders;
  late PlaylistManager playlists;
  final caught = <DateTime>[];
  var closed = 0;
  var live = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    epg = _Epg(storage);
    playlists = PlaylistManager(storage, CatalogDatabase());
    caught.clear();
    closed = 0;
    live = 0;
  });
  tearDown(() {
    reminders.dispose();
    playlists.dispose();
  });

  Future<void> pump(WidgetTester tester, {DateTime? at}) async {
    reminders = ProgrammeReminders(storage);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<EpgService>.value(value: epg),
        ChangeNotifierProvider<ProgrammeReminders>.value(value: reminders),
        ChangeNotifierProvider<PlaylistManager>.value(value: playlists),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ChannelSchedulePanel(
            channel: _cu,
            at: at,
            onClose: () => closed++,
            onCatchup: caught.add,
            onLive: () => live++,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  // Programme 12 is on now (6 h after the base, current half hour).
  int onNow() {
    final now = DateTime.now();
    return epg.rows
        .indexWhere((p) => !p.start.isAfter(now) && p.stop.isAfter(now));
  }

  testWidgets(
      'opens on the programme on now, Up + OK = catch-up from its start',
      (tester) async {
    await pump(tester);
    final i = onNow();
    expect(find.text('About show $i'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(find.text('About show ${i - 1}'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    expect(caught, [epg.rows[i - 1].start]);
    expect(closed, 1);
  });

  testWidgets(
      'OK on the playing programme closes; upcoming opens actions and Back restores the row',
      (tester) async {
    await pump(tester);
    await press(tester, LogicalKeyboardKey.select);
    expect(closed, 1);
    expect(caught, isEmpty);
    expect(live, 0);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(closed, 1);
    expect(caught, isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Remind me'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Remind me'), findsNothing);
    expect(find.text('Upcoming  ·  OK to remind or record'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'channel-schedule');
  });

  testWidgets('from catch-up: opens on the playhead, OK on now = back to live',
      (tester) async {
    final i = onNow();
    final at = epg.rows[i - 4].start.add(const Duration(minutes: 10));
    await pump(tester, at: at);
    expect(find.text('About show ${i - 4}'), findsOneWidget);

    for (var n = 0; n < 4; n++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    await press(tester, LogicalKeyboardKey.select);
    expect(live, 1);
    expect(closed, 1);
    expect(caught, isEmpty);
  });

  testWidgets('Rewind / Fast-forward page through the list', (tester) async {
    await pump(tester);
    final i = onNow();
    // A page is more rows than are left: the last show, then a page back.
    await press(tester, LogicalKeyboardKey.mediaFastForward);
    expect(find.text('About show 23'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.mediaRewind);
    expect(find.text('About show 23'), findsNothing);
    expect(find.text('About show $i'), findsNothing);
    expect(caught, isEmpty);
    expect(live, 0);
  });

  testWidgets('opening OK repeats/key-up never arm a reminder; fresh OK does',
      (tester) async {
    await pump(tester);
    final next = epg.rows[onNow() + 1];
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(reminders.isSet(_cu, next), isFalse);
    expect(find.text('Remind me'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(reminders.isSet(_cu, next), isTrue);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'channel-schedule');
  });
}
