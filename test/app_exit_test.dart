import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_exit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const device = MethodChannel('com.nox.nox_iptv/device_type');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, null);
    AppExit.beforeWarm = null;
    AppExit.afterWarm = null;
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
