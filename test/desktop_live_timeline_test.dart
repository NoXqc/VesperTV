import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/catchup_session.dart';
import 'package:nox_iptv/services/live_timeshift.dart';
import 'package:nox_iptv/utils/skip_step.dart';
import 'package:nox_iptv/widgets/desktop_live_timeline.dart';

/// The computers / iPhone / Apple TV player's live timeline (the remote
/// bar's line 2): Up reaches it on a catch-up channel or with Live pause &
/// rewind on, Left / Right move a target (Skip buttons steps, a held key's
/// grow), OK plays there, Back / Down / leaving cancel.
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

final _plain = Channel(
  id: 'p::plain',
  rawId: 'plain',
  playlistId: 'p',
  name: 'Plain channel',
  group: 'News',
  url: 'http://host:80/live/u/pw/12.ts',
);

void main() {
  late DateTime now;
  late LiveScrubController scrub;
  late FocusNode timeline;
  late FocusNode play;
  late ValueNotifier<TimeshiftState?> shift;
  late List<DateTime> went;
  late int downs;

  setUp(() {
    SkipStep.seconds = 10;
    now = DateTime(2026, 11, 28, 20, 30);
    scrub = LiveScrubController();
    timeline = FocusNode(debugLabel: 'timeline');
    play = FocusNode(debugLabel: 'play');
    shift = ValueNotifier(null);
    went = [];
    downs = 0;
  });

  Future<void> pump(WidgetTester tester, Channel channel,
      {bool guide = true}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(children: [
            SizedBox(
              width: 900,
              child: DesktopLiveTimeline(
                channel: channel,
                epgId: channel.rawId,
                timeshift: shift,
                scrub: scrub,
                focusNode: timeline,
                onGo: went.add,
                onDown: () {
                  downs++;
                  play.requestFocus();
                },
                programme: guide
                    ? EpgProgram(
                        channelId: channel.rawId,
                        title: 'News at nine',
                        start: now.subtract(const Duration(minutes: 30)),
                        stop: now.add(const Duration(minutes: 30)))
                    : null,
                clock: () => now,
              ),
            ),
            Focus(
                focusNode: play, child: const SizedBox(width: 40, height: 40)),
          ]),
        ),
      ),
    ));
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('catch-up channel: Left / Right move a target, OK plays there',
      (tester) async {
    await pump(tester, _cu);
    timeline.requestFocus();
    await tester.pump();
    expect(timeline.hasFocus, isTrue);
    expect(find.text('◀ Catch-up'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.value, now.subtract(const Duration(seconds: 10)));
    expect(find.textContaining('(−0:10)'), findsOneWidget);
    // Taps: one Skip buttons step each.
    now = now.add(const Duration(seconds: 1));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.value, DateTime(2026, 11, 28, 20, 29, 40));
    now = now.add(const Duration(seconds: 1));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(scrub.value, DateTime(2026, 11, 28, 20, 29, 50));
    expect(went, isEmpty, reason: 'nothing plays before OK');
    await press(tester, LogicalKeyboardKey.select);
    expect(went, [DateTime(2026, 11, 28, 20, 29, 50)]);
    expect(scrub.value, isNull);
    expect(timeline.hasFocus, isTrue);
  });

  testWidgets('a held key grows its steps and stops at the ends',
      (tester) async {
    await pump(tester, _cu);
    timeline.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(scrub.value, now.subtract(const Duration(seconds: 10)));
    // flutter-tvos repeats a held arrow: 2 s of repeats every 250 ms.
    final start = now;
    for (var i = 0; i < 8; i++) {
      now = now.add(const Duration(milliseconds: 250));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    // 10 s, then 10 s steps for 1.5 s, 30 s steps after (ScrubSteps).
    final back = start.difference(scrub.value!);
    expect(back, greaterThan(const Duration(seconds: 90)));
    expect(back, lessThan(const Duration(seconds: 200)));
    // Right never goes past now.
    for (var i = 0; i < 40; i++) {
      now = now.add(const Duration(milliseconds: 400));
      await press(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(scrub.value, now);
  });

  testWidgets('never before the channel\'s catch-up days', (tester) async {
    await pump(tester, _cu);
    timeline.requestFocus();
    await tester.pump();
    scrub.value =
        CatchupSession.oldest(_cu, now).add(const Duration(seconds: 5));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.value, CatchupSession.oldest(_cu, now));
  });

  testWidgets('Back, Down and leaving cancel the target', (tester) async {
    await pump(tester, _cu);
    timeline.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.value, isNotNull);
    await press(tester, LogicalKeyboardKey.escape);
    expect(scrub.value, isNull);
    expect(timeline.hasFocus, isTrue, reason: 'Back only drops the target');
    // The player's Back (PopScope) asks the controller first.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.cancel('Back'), isTrue);
    expect(scrub.cancel('Back'), isFalse);
    // Down: back to the buttons.
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(downs, 1);
    expect(play.hasFocus, isTrue);
    expect(scrub.value, isNull);
    // Leaving another way (the bar hides): cancelled too.
    timeline.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowLeft);
    play.requestFocus();
    await tester.pump();
    expect(scrub.value, isNull);
    expect(went, isEmpty);
  });

  testWidgets('Up stays on the timeline; OK without a target does nothing',
      (tester) async {
    await pump(tester, _cu);
    timeline.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(timeline.hasFocus, isTrue);
    await press(tester, LogicalKeyboardKey.select);
    expect(went, isEmpty);
  });

  testWidgets('no catch-up and no Live pause & rewind: not a remote target',
      (tester) async {
    await pump(tester, _plain);
    timeline.requestFocus();
    await tester.pump();
    expect(timeline.hasFocus, isFalse);
    expect(timeline.canRequestFocus, isFalse);
  });

  testWidgets('Live pause & rewind only: rewinds inside what is kept',
      (tester) async {
    shift.value = const TimeshiftState(
        on: true,
        behind: Duration(seconds: 1),
        available: Duration(minutes: 5),
        window: Duration(minutes: 30));
    await pump(tester, _plain);
    timeline.requestFocus();
    await tester.pump();
    expect(timeline.hasFocus, isTrue);
    expect(find.text('◀ Rewind'), findsOneWidget);
    scrub.value = now.subtract(const Duration(minutes: 4, seconds: 55));
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.value, now.subtract(const Duration(minutes: 5)));
    await press(tester, LogicalKeyboardKey.enter);
    expect(went, [now.subtract(const Duration(minutes: 5))]);
  });

  testWidgets('behind live: the marker starts from the picture',
      (tester) async {
    shift.value = const TimeshiftState(
        on: true,
        behind: Duration(minutes: 2),
        available: Duration(minutes: 20),
        window: Duration(minutes: 30));
    await pump(tester, _cu);
    expect(find.byKey(const ValueKey('live-scrub-marker')), findsOneWidget);
    timeline.requestFocus();
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(scrub.value, now.subtract(const Duration(minutes: 2, seconds: 10)));
  });

  testWidgets('no guide listing: the kept minutes are the bar', (tester) async {
    await pump(tester, _plain, guide: false);
    final bar = find.descendant(
        of: find.byType(DesktopLiveTimeline), matching: find.byType(Row));
    expect(bar, findsNothing);
    shift.value = const TimeshiftState(
        on: true,
        behind: Duration(seconds: 1),
        available: Duration(minutes: 3),
        window: Duration(minutes: 30));
    await tester.pump();
    expect(bar, findsOneWidget);
  });

  testWidgets(
      'the gold tag: nothing at live, "−m:ss" behind, the gathered '
      'target', (tester) async {
    final target = ValueNotifier<Duration?>(null);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: DesktopTimeshiftTag(state: shift, target: target)))));
    expect(find.byKey(const ValueKey('timeshift-tag')), findsNothing);
    shift.value = const TimeshiftState(
        on: true,
        behind: Duration(seconds: 2),
        available: Duration(minutes: 3),
        window: Duration(minutes: 30));
    await tester.pump();
    expect(find.byKey(const ValueKey('timeshift-tag')), findsNothing);
    shift.value = const TimeshiftState(
        on: true,
        behind: Duration(minutes: 1, seconds: 23),
        available: Duration(minutes: 3),
        window: Duration(minutes: 30));
    await tester.pump();
    expect(find.text('−1:23'), findsOneWidget);
    target.value = const Duration(minutes: 2);
    await tester.pump();
    expect(find.text('−2:00'), findsOneWidget);
  });
}
