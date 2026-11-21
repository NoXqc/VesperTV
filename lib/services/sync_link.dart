import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cloud_transfer.dart' show cloudTransferBase;

/// The link a Link a device QR holds (2026-11-20, owner: "Sync a phone?
/// Scan the QR code"): the 16-digit code after the `#`, which browsers
/// never send, so it never reaches a server. A phone's camera opens
/// VesperTV with it (Android App Link, verified by the relay's
/// `/.well-known/assetlinks.json`); without the app the relay's `/sync`
/// page shows the code to type.
String syncLinkUrl(String code) => '$cloudTransferBase/sync#$code';

/// Codes from a scanned Link a device QR (`SyncLinkBridge.kt`): main.dart
/// sets [open] (Sync with the join screen, the code filled in; it asks
/// before joining) and calls [openPending] once the UI is up, like the TV
/// launcher's cards. Android only.
class SyncLinks {
  SyncLinks._();
  static final instance = SyncLinks._();

  static const _channel = MethodChannel('vespertv/sync_link');

  Future<void> Function(String code)? open;
  bool _attached = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// A link that arrives while the app runs opens at once.
  void attach() {
    if (_attached || !_supported) return;
    _attached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link') unawaited(openPending());
    });
  }

  /// The app was opened by a scanned QR and its code wasn't taken yet
  /// (main.dart then skips the "add your first playlist?" prompt).
  Future<bool> get hasPending async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('has') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openPending() async {
    final show = open;
    if (show == null || !_supported) return;
    String? code;
    try {
      code = await _channel.invokeMethod<String>('take');
    } catch (_) {
      return;
    }
    if (code == null) return;
    debugPrint('SyncLink: opened from a Link a device QR');
    await show(code);
  }
}
