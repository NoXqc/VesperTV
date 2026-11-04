import 'dart:io';

import 'package:flutter/services.dart';

/// Closes VesperTV and opens it again. Every service keeps the setup it
/// loaded in memory, so settings that sync holds for "the next launch"
/// (playlists, Media Hub sources...) only load on a cold start.
Future<void> restartApp() async {
  try {
    if (Platform.isAndroid) {
      // MainActivity queues a fresh launch, then ends this process.
      await const MethodChannel('com.nox.nox_iptv/device_type')
          .invokeMethod<bool>('restartApp');
    } else if (Platform.isWindows) {
      await Process.start(Platform.resolvedExecutable, const [],
          mode: ProcessStartMode.detached);
    }
  } catch (_) {
    // No relaunch: closing still loads everything the next time it opens.
  }
  exit(0);
}
