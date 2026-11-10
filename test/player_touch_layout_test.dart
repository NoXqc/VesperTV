import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_controls.dart';

// Phones / tablets: the full-screen player in the iPhone player's look
// (owner, 2026-11-09). The bar keeps the seek bar with both times, the
// badges and the buttons; the title moved to the top bar and play/pause
// +-10 to the middle of the picture (PlayerTouchTransport).

class _Controller extends VideoPlayerHdrController {
  _Controller() : super.networkUrl(Uri.parse('https://example.com/movie')) {
    value = const VideoPlayerHdrValue(
        duration: Duration(hours: 2, minutes: 25),
        position: Duration(minutes: 5),
        isInitialized: true,
        size: Size(1920, 1080));
  }
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
}

void main() {
  Future<void> pump(WidgetTester tester, Size size, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: AppPreferences(storage),
      child: MaterialApp(home: Scaffold(body: child)),
    ));
  }

  Widget bar() => Align(
        alignment: Alignment.bottomCenter,
        child: PlayerControls(
          insetForSystemBars: true,
          touchLayout: true,
          controller: _Controller(),
          title: 'Spider-Man: Brand New Day',
          channelId: 'c',
          isLive: false,
          isFavorite: false,
          onToggleFavorite: () {},
        ),
      );

  for (final size in const [Size(412, 900), Size(915, 412)]) {
    testWidgets('touch bar at $size: times + seek, no title or transport',
        (tester) async {
      await pump(tester, size, bar());
      expect(tester.takeException(), isNull);
      expect(find.text('Spider-Man: Brand New Day'), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.replay_10), findsNothing);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.text('2:25:00'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // The favourite button at full touch size, above the nav bar.
      final star = find.byIcon(Icons.star_border);
      expect(star, findsOneWidget);
      expect(tester.getSize(star).width, greaterThanOrEqualTo(24));
      expect(tester.getBottomLeft(star).dy, lessThan(size.height - 48));
    });
  }

  testWidgets('middle transport: -10 / play / +10 on a movie, play on live',
      (tester) async {
    await pump(
        tester,
        const Size(915, 412),
        Center(
            child: PlayerTouchTransport(
                controller: _Controller(), isLive: false)));
    expect(find.byIcon(Icons.replay_10), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.forward_10), findsOneWidget);
    expect(tester.getSize(find.byIcon(Icons.play_arrow)).width, 48);

    await pump(
        tester,
        const Size(915, 412),
        Center(
            child:
                PlayerTouchTransport(controller: _Controller(), isLive: true)));
    expect(find.byIcon(Icons.replay_10), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('TV keeps the one-row bar with the title and transport',
      (tester) async {
    await pump(
        tester,
        const Size(1280, 720),
        Align(
          alignment: Alignment.bottomCenter,
          child: PlayerControls(
            controller: _Controller(),
            title: 'Spider-Man: Brand New Day',
            channelId: 'c',
            isLive: false,
          ),
        ));
    expect(find.text('Spider-Man: Brand New Day'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
