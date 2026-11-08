import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_exit.dart';
import 'package:nox_iptv/utils/desktop_platform.dart';

/// Android's root Back: a warm exit ([AppExit.back] -> moveTaskToBack),
/// whatever computer runs the tests. Returns one entry per warm exit.
List<String> recordWarmExits() {
  const channel = MethodChannel('com.nox.nox_iptv/device_type');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final exits = <String>[];
  AppExit.isWindows = false;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'moveTaskToBack') {
      exits.add('warm');
      return true;
    }
    return null;
  });
  addTearDown(() {
    AppExit.isWindows = isDesktop;
    messenger.setMockMethodCallHandler(channel, null);
  });
  return exits;
}
