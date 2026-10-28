import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_controls.dart';

// The full-screen player bar on a phone: clear of the system navigation
// bar, and on two lines in portrait so its buttons aren't tiny (Pixel 10
// Pro XL, Discord 2026-10-28).

class _Controller extends VideoPlayerHdrController {
  _Controller() : super.networkUrl(Uri.parse('https://example.com/movie')) {
    value = const VideoPlayerHdrValue(
        duration: Duration(hours: 2),
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
  Future<void> pump(WidgetTester tester, Size size,
      {required bool inset}) async {
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
      child: MaterialApp(
          home: Scaffold(
              body: Align(
                  alignment: Alignment.bottomCenter,
                  child: PlayerControls(
                    insetForSystemBars: inset,
                    controller: _Controller(),
                    title: 'Sky Sports Cricket',
                    channelId: 'c',
                    isLive: false,
                  )))),
    ));
  }

  double playTop(WidgetTester tester) =>
      tester.getTopLeft(find.byIcon(Icons.play_arrow)).dy;
  double titleTop(WidgetTester tester) =>
      tester.getTopLeft(find.text('Sky Sports Cricket')).dy;

  testWidgets('portrait phone: buttons on their own line, above the nav bar',
      (tester) async {
    await pump(tester, const Size(412, 900), inset: true);
    expect(playTop(tester), greaterThan(titleTop(tester) + 10));
    // The play button sits above the 48 px navigation bar.
    expect(tester.getBottomLeft(find.byIcon(Icons.play_arrow)).dy,
        lessThan(900 - 48));
    // Not scaled down to the old 60% strip.
    expect(
        tester.getSize(find.byIcon(Icons.play_arrow)).width, greaterThan(18));
  });

  testWidgets('landscape keeps one line', (tester) async {
    await pump(tester, const Size(1280, 720), inset: true);
    expect((playTop(tester) - titleTop(tester)).abs(), lessThan(16));
  });

  testWidgets('inline previews are unchanged (no inset, one line)',
      (tester) async {
    await pump(tester, const Size(412, 900), inset: false);
    expect((playTop(tester) - titleTop(tester)).abs(), lessThan(16));
  });
}
