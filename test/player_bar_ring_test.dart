import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_controls.dart';

// The player bar has one focus highlight (owner photos, 2026-11-19: play /
// pause showed Material's faint grey circle beside the -10 / +10 rings),
// and one OK press acts once (the Homatics remote repeats OK ~420 ms later).

class _Controller extends VideoPlayerHdrController {
  _Controller() : super.networkUrl(Uri.parse('https://example.com/movie')) {
    value = const VideoPlayerHdrValue(
        duration: Duration(hours: 2),
        position: Duration(minutes: 5),
        isInitialized: true,
        size: Size(1920, 1080));
  }
  int plays = 0;
  @override
  Future<void> play() async => plays++;
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
}

void main() {
  Future<_Controller> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    tester.view.physicalSize = const Size(1920, 1080);
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
                    title: 'A movie',
                    channelId: 'c',
                    isLive: false,
                  )))),
    ));
    await tester.pump();
    return controller;
  }

  Decoration? ringOf(WidgetTester tester, IconData icon) => tester
      .widget<Container>(find
          .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
          .first)
      .decoration;

  Future<void> focus(WidgetTester tester, IconData icon) async {
    Focus.of(tester.element(find.byIcon(icon))).requestFocus();
    await tester.pumpAndSettle();
  }

  testWidgets('play / pause has the same focus ring as -10', (tester) async {
    await pump(tester);
    final resting = ringOf(tester, Icons.play_arrow);
    await focus(tester, Icons.replay_10);
    final skip = ringOf(tester, Icons.replay_10);
    await focus(tester, Icons.play_arrow);
    final play = ringOf(tester, Icons.play_arrow);
    expect(play, isNot(resting), reason: 'focus shows');
    expect(play, skip, reason: 'one focus look in the bar');
    expect((play as BoxDecoration).border, isNotNull);
  });

  testWidgets('one OK = one play, the remote repeat does nothing',
      (tester) async {
    final controller = await pump(tester);
    await focus(tester, Icons.play_arrow);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(controller.plays, 1);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(controller.plays, 2, reason: 'a tap works too');
  });
}
