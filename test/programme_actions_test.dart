import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/programme_reminders.dart';
import 'package:nox_iptv/services/recording_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/programme_actions.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'programme_reminders_test.dart' show programme, programmeChannel;

class _Recorder extends RecordingService {
  _Recorder() : super.forTesting(Directory('.'));
  @override
  final items = <RecordingEntry>[];
  int requests = 0;
  bool room = true;
  bool fail = false;
  Future<void>? gate;
  RecordingEntry? conflict;
  @override
  Future<void> init() async {}
  @override
  Future<void> askNotifications() async {}
  @override
  Future<bool> hasRoom() async => room;
  @override
  RecordingEntry? entryForProgramme(Channel c, EpgProgram p) =>
      items.firstOrNull;
  @override
  RecordingEntry? programmeConflict(
          Channel c, EpgProgram p, int maxConnections) =>
      conflict;
  @override
  Future<RecordingEntry> recordProgramme(Channel c, EpgProgram p,
      {int maxConnections = 1}) async {
    requests++;
    await gate;
    if (fail) throw StateError('fixture');
    final entry = RecordingEntry(
        id: 'fixture',
        title: p.title,
        league: c.name,
        gameKey: '',
        leagueId: '',
        gameStart: p.start,
        startAt: p.start,
        endAt: p.stop,
        channelId: c.id,
        channelName: c.name,
        playlistId: c.playlistId,
        url: c.url,
        path: 'fixture.ts',
        programmeKey: programmeKey(c, p));
    items.add(entry);
    notifyListeners();
    return entry;
  }

  @override
  Future<void> cancelProgramme(RecordingEntry entry) async {
    items.remove(entry);
    notifyListeners();
  }

  SeriesRule? rule;
  bool? skipRepeats;
  List<EpgProgram> guide = const [];
  @override
  SeriesRule? seriesFor(Channel channel, String title) => rule;
  @override
  Future<({SeriesRule rule, int added, int conflicts})> addSeries(
      Channel channel, EpgProgram programme, List<EpgProgram> upcoming,
      {bool skipRepeats = false, int maxConnections = 1}) async {
    this.skipRepeats = skipRepeats;
    guide = upcoming;
    rule = SeriesRule(
        id: 's1',
        title: programme.title,
        channelId: channel.id,
        channelName: channel.name,
        playlistId: channel.playlistId,
        created: DateTime.now());
    notifyListeners();
    return (rule: rule!, added: 3, conflicts: 1);
  }

  @override
  Future<void> stopSeries(SeriesRule rule) async {
    this.rule = null;
    notifyListeners();
  }
}

void main() {
  late ProgrammeReminders reminders;
  late StorageService storage;
  late _Recorder recordings;
  late EpgProgram show;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    recordings = _Recorder();
    show = programme(DateTime.now().add(const Duration(minutes: 20)));
  });
  tearDown(() => {reminders.dispose(), recordings.dispose()});
  Future<void> pump(WidgetTester tester,
      {double width = 960,
      double scale = 1,
      Future<List<EpgProgram>> Function()? upcoming}) async {
    reminders = ProgrammeReminders(storage);
    tester.view.physicalSize = Size(width, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
            builder: (context) => Scaffold(
                body: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: TextButton(
                        child: const Text('Open'),
                        onPressed: () => showProgrammeActions(context,
                            channel: programmeChannel,
                            programme: show,
                            reminders: reminders,
                            recordings: recordings,
                            upcoming: upcoming)))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'D-pad reminder, reopen and cancel; Record remains independently reachable',
      (tester) async {
    await pump(tester);
    await press(tester, LogicalKeyboardKey.select);
    expect(reminders.isSet(programmeChannel, show), isTrue);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel reminder'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    expect(reminders.isSet(programmeChannel, show), isFalse);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(recordings.requests, 1);
    expect(recordings.items.single.title, show.title);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel recording'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(recordings.items, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Record series: D-pad to it, pick skip repeats, reopen to stop it',
      (tester) async {
    final later = programme(DateTime.now().add(const Duration(days: 1)));
    await pump(tester, upcoming: () async => [later]);
    expect(find.text('Record series…'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    // The choice: every airing first, Back returns to the menu.
    expect(find.text('Every airing'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Every airing'), findsNothing);
    expect(find.text('Record series…'), findsOneWidget);
    expect(recordings.rule, isNull);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(recordings.skipRepeats, isTrue);
    expect(recordings.guide, [later]);
    expect(find.text('Record series…'), findsNothing);
    expect(
        find.text(
            'Series recording on: 3 scheduled · 1 skipped (no free connection)'),
        findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Stop series recording'), findsOneWidget);
    await tester.tap(find.text('Stop series recording'));
    await tester.pumpAndSettle();
    expect(recordings.rule, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('no guide lookup given: no Record series', (tester) async {
    await pump(tester);
    expect(find.text('Record series…'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'busy guard and failure show no phantom success; Back closes only the menu',
      (tester) async {
    final pending = Completer<void>();
    recordings.gate = pending.future;
    recordings.fail = true;
    await pump(tester);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(
        tester
            .widget<TvMenuTile>(find.byKey(const ValueKey('programme-record')))
            .enabled,
        isFalse);
    pending.complete();
    await tester.pumpAndSettle();
    expect(recordings.requests, 1);
    expect(recordings.items, isEmpty);
    expect(
        find.text(
            'Could not schedule recording. Check recording storage and try again.'),
        findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('narrow screen scroll and large text keep actions accessible',
      (tester) async {
    await pump(tester, width: 430, scale: 1.7);
    expect(tester.takeException(), isNull);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(recordings.requests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
