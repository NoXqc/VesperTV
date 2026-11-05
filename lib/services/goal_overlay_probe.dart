import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

enum OverlayProbeAccess { granted, settings, unavailable }

class OverlayProbeStatus {
  const OverlayProbeStatus({
    this.access = OverlayProbeAccess.unavailable,
    this.canOpenSettings = false,
    this.running = false,
    this.result,
  });

  final OverlayProbeAccess access;
  final bool canOpenSettings;
  final bool running;
  final String? result;
}

/// One-shot native capability test. No score service, subscriptions or storage.
class GoalOverlayProbe {
  static const channel = MethodChannel('vespertv/goal_overlay_probe');

  static Future<OverlayProbeStatus> status() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('status');
      final result = data?['result'];
      return OverlayProbeStatus(
        access: switch (data?['access']) {
          'granted' => OverlayProbeAccess.granted,
          'settings' => OverlayProbeAccess.settings,
          _ => OverlayProbeAccess.unavailable,
        },
        canOpenSettings: data?['canOpenSettings'] == true,
        running: data?['running'] == true,
        result: result is String ? result : null,
      );
    } on PlatformException {
      return const OverlayProbeStatus();
    } on MissingPluginException {
      return const OverlayProbeStatus();
    }
  }

  static Future<bool> openSettings() async {
    try {
      return await channel.invokeMethod<bool>('openSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> testPopup() async {
    try {
      return await channel.invokeMethod<bool>('testPopup', {
            'title': tr('VesperTV overlay test'),
            'message': tr('This test closes after 6 seconds.'),
            'waiting': tr('Test popup in 10 seconds. Switch to another app.'),
            'channelName': tr('Overlay tests'),
            'cancel': tr('Cancel'),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
