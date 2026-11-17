import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/scrub_steps.dart';
import 'package:nox_iptv/widgets/player_controls.dart';

// Owner, 2026-11-17: Fast-forward / Rewind on the seek bar "jumped many
// minutes" and the line didn't follow the seek. Steps grew with every press
// (key repeats included) and the marker went back to the old position
// before the seek landed.

class _Controller extends VideoPlayerHdrController {
  _Controller() : super.networkUrl(Uri.parse('https://example.com/movie')) {
    value = const VideoPlayerHdrValue(
        duration: Duration(hours: 2),
        position: Duration(minutes: 5),
        isInitialized: true,
        size: Size(1920, 1080));
  }

  final seeks = <Duration>[];

  /// The player hasn't reached the target yet: the position stays.
  @override
  Future<void> seekTo(Duration position) async => seeks.add(position);

  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
}

void main() {
  group('ScrubSteps', () {
    late DateTime now;
    late ScrubSteps steps;
    setUp(() {
      now = DateTime(2026, 11, 17, 20);
      steps = ScrubSteps(clock: () => now);
    });

    Duration? at(int ms, {bool? repeat}) {
      now = DateTime(2026, 11, 17, 20).add(Duration(milliseconds: ms));
      return steps.next(repeat: repeat);
    }

    test('taps are always 10 s', () {
      for (var i = 0; i < 12; i++) {
        expect(at(i * 500, repeat: false), const Duration(seconds: 10));
      }
    });

    test('a held key grows with time, at most 5 steps a second', () {
      final moved = <int>[];
      expect(at(0, repeat: false), const Duration(seconds: 10));
      // A remote repeating 20 times a second for 8 s.
      for (var ms = 450; ms <= 8000; ms += 50) {
        final step = at(ms, repeat: true);
        if (step != null) moved.add(step.inSeconds);
      }
      expect(moved.length, lessThanOrEqualTo(8 * 5));
      expect(moved.first, 10);
      expect(moved.toSet(), {10, 30, 60, 120, 300});
      // 8 s of holding: well under the 2-hour movie (count-based steps were
      // past 2 hours after 2 s).
      final total = moved.fold(10, (a, b) => a + b);
      expect(total, lessThan(70 * 60));
      expect(total, greaterThan(20 * 60));
    });

    test('a shortcut callback guesses repeats from the time between presses',
        () {
      expect(at(0), const Duration(seconds: 10));
      expect(at(100), isNull); // repeat too soon
      expect(at(250), const Duration(seconds: 10));
      // 2 s of repeats every 100 ms: 30 s steps by then.
      Duration? last;
      for (var ms = 350; ms <= 2050; ms += 100) {
        last = at(ms) ?? last;
      }
      expect(last, const Duration(seconds: 30));
      // Let go, press again later: a tap.
      expect(at(5000), const Duration(seconds: 10));
    });
  });

  testWidgets('seek bar: six taps = 1 minute, the marker waits for the seek',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _Controller();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: AppPreferences(storage),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PlayerControls(
              controller: controller,
              title: 'Movie',
              channelId: 'c',
              isLive: false,
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      ),
    ));
    final bar = tester
        .widgetList<Focus>(find.byType(Focus))
        .firstWhere((f) => f.focusNode?.debugLabel == 'scrub-bar')
        .focusNode!;
    bar.requestFocus();
    await tester.pump();
    final width = tester.getSize(find.byType(Slider)).width;

    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await tester.pump();
    expect(find.text('6:00  (+1:00)'), findsOneWidget);
    // The label floats above the bar: the bar keeps its width, so the thumb
    // only moves by the step (it took the bar's room and moved every point).
    expect(tester.getSize(find.byType(Slider)).width, width);

    double slider() => tester.widget<Slider>(find.byType(Slider)).value;
    expect(slider(), const Duration(minutes: 6).inMilliseconds);

    // 700 ms after the last press: one seek; the marker stays on 6:00 while
    // the player still reports 5:00.
    await tester.pump(const Duration(milliseconds: 750));
    expect(controller.seeks, [const Duration(minutes: 6)]);
    expect(find.textContaining('(+'), findsNothing);
    expect(slider(), const Duration(minutes: 6).inMilliseconds);

    // The player gets there: the marker follows the player again.
    controller.value = controller.value
        .copyWith(position: const Duration(minutes: 6, seconds: 1));
    await tester.pump();
    expect(slider(), const Duration(minutes: 6, seconds: 1).inMilliseconds);
  });
}
