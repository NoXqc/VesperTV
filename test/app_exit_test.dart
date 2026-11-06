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
}
