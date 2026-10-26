import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/phone_picture_in_picture.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

class _Controller extends VideoPlayerHdrController {
  _Controller() : super.networkUrl(Uri.parse('https://example.com/video'));
  int pauses = 0;
  void playing(bool playing) {
    value = VideoPlayerHdrValue(
        duration: const Duration(minutes: 30),
        size: const Size(1920, 1080),
        isInitialized: true,
        isPlaying: playing);
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing(false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vespertv/phone_pip');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> native(String method, dynamic arguments) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall(method, arguments)),
            (_) {});
  }

  Widget app(_Controller controller,
          {bool tv = false, GlobalKey<NavigatorState>? nav}) =>
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [appRouteObserver],
        home: PhonePictureInPicture(
          controller: controller,
          isTelevision: tv,
          builder: (context, pip) =>
              Scaffold(body: Text(pip ? 'video only' : 'controls')),
        ),
      );

  testWidgets('only initialized playing phone video arms PiP; close pauses',
      (tester) async {
    final controller = _Controller();
    await tester.pumpWidget(app(controller));
    expect(calls.last.arguments['enabled'], false);
    controller.playing(true);
    await tester.pump();
    expect(calls.last.arguments['enabled'], true);
    expect(calls.last.arguments['aspect'], closeTo(16 / 9, 0.001));
    await native('modeChanged', true);
    await tester.pump();
    expect(find.text('video only'), findsOneWidget);
    expect(controller.value.isPlaying, true);
    await native('modeChanged', false);
    await tester.pump();
    expect(find.text('controls'), findsOneWidget);
    expect(controller.pauses, 0);
    await native('stopped', null);
    await tester.pump();
    expect(controller.pauses, 1);
    expect(calls.last.arguments['enabled'], false);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'covering player disarms PiP, returning rearms, disposal releases',
      (tester) async {
    final controller = _Controller()..playing(true);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(controller, nav: nav));
    expect(calls.last.arguments['enabled'], true);
    nav.currentState!
        .push<void>(MaterialPageRoute(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(calls.last.arguments['enabled'], false);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(calls.last.arguments['enabled'], true);
    await tester.pumpWidget(const SizedBox());
    expect(calls.last.arguments['enabled'], false);
    await controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('TV never registers or arms phone PiP', (tester) async {
    final controller = _Controller()..playing(true);
    await tester.pumpWidget(app(controller, tv: true));
    expect(calls, isEmpty);
    await native('stopped', null);
    expect(controller.pauses, 0);
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
