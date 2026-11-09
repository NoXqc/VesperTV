import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_exit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const device = MethodChannel('com.nox.nox_iptv/device_type');
  const window = MethodChannel('window_manager');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(device, null)
      ..setMockMethodCallHandler(window, null);
    AppExit.beforeWarm = null;
    AppExit.afterWarm = null;
    AppExit.beforeQuit = null;
    AppExit.isWindows = false;
    AppExit.resetQuit();
  });

  List<String> recordWindow() {
    final events = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(window, (call) async {
      events.add(call.method);
      return null;
    });
    return events;
  }

  // Closing the window with players still open crashed libmpv on Linux
  // (Steam Machine, 2026-11-08): the players close first.
  test('a computer quits: players close first, then the window', () async {
    AppExit.isWindows = true;
    final events = recordWindow();
    AppExit.beforeQuit = () async => events.add('players');
    await AppExit.full();
    expect(events, ['players', 'destroy']);
    // The close button again while quitting: nothing more.
    await AppExit.quit();
    expect(events, ['players', 'destroy']);
  });

  testWidgets('a player that never closes keeps the window at most 5 s',
      (tester) async {
    AppExit.isWindows = true;
    final events = recordWindow();
    AppExit.beforeQuit = () => Completer<void>().future;
    var done = false;
    unawaited(AppExit.quit().then((_) => done = true));
    await tester.pump(const Duration(seconds: 4));
    expect(events, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(events, ['destroy']);
    expect(done, isTrue);
  });

  test('warm exit stops playback, goes to the background, resumes once',
      () async {
    AppExit.isWindows = false;
    final events = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, (call) async {
      events.add(call.method);
      return call.method == 'moveTaskToBack' ? true : null;
    });
    AppExit.beforeWarm = () async => events.add('stop');
    AppExit.afterWarm = () => events.add('resume');

    // A resume without a warm exit (Home key, screensaver) does nothing.
    AppExit.resumed();
    expect(events, isEmpty);

    await AppExit.warm();
    expect(events, ['stop', 'moveTaskToBack']);
    AppExit.resumed();
    AppExit.resumed();
    expect(events, ['stop', 'moveTaskToBack', 'resume']);
  });

  test('Back at the root: Android leaves at once, never asks', () async {
    AppExit.isWindows = false;
    final events = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, (call) async {
      events.add(call.method);
      return call.method == 'moveTaskToBack' ? true : null;
    });
    var asked = false;
    await AppExit.back(() async => asked = true);
    expect(asked, isFalse);
    expect(events, ['moveTaskToBack']);
  });

  test('Back at the root on a computer asks first; Stay stays', () async {
    AppExit.isWindows = true;
    addTearDown(() => AppExit.isWindows = false);
    final events = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, (call) async {
      events.add(call.method);
      return true;
    });
    var asked = 0;
    await AppExit.back(() async {
      asked++;
      return false; // Stay
    });
    expect(asked, 1);
    expect(events, isEmpty, reason: 'no warm exit on a computer');
  });
}
