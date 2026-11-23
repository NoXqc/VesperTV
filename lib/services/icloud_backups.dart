import 'dart:io';

import 'package:flutter/services.dart';

import '../l10n/l10n.dart';

/// One device's backup in the viewer's iCloud.
class ICloudBackupEntry {
  const ICloudBackupEntry({
    required this.id,
    required this.device,
    required this.app,
    required this.modified,
    required this.size,
    required this.mine,
  });

  factory ICloudBackupEntry.fromMap(Map<Object?, Object?> m) =>
      ICloudBackupEntry(
        id: m['id'] as String,
        device: (m['device'] as String?) ?? '',
        app: (m['app'] as String?) ?? '',
        modified: DateTime.fromMillisecondsSinceEpoch(
            ((m['modified'] as num?) ?? 0).toInt()),
        size: ((m['size'] as num?) ?? 0).toInt(),
        mine: m['mine'] == true,
      );

  final String id;

  /// The device that saved it ("iPhone", "Apple TV").
  final String device;

  /// The VesperTV version that saved it ("1.0.74+965").
  final String app;
  final DateTime modified;
  final int size;

  /// Saved by this device.
  final bool mine;
}

/// iPhone, iPad and Apple TV: backups in the viewer's own iCloud (Apple's
/// CloudKit, the private database of the container
/// `iCloud.app.vespertv.player`). Nothing to sign in to in VesperTV: it is
/// the Apple ID the device already uses, and only that Apple ID can read
/// it. Each device keeps its newest backup there (one record per device,
/// replaced by the next), so an Apple TV can restore what the iPhone saved
/// (BallerMC, Discord, 2026-11-22) and a purged Apple TV can restore its own.
///
/// Native side: `VesperICloud` in ios/Runner/AppDelegate.swift and
/// tvos/Runner/AppDelegate.swift. It answers `NOT_SET_UP` until the app is
/// built with the iCloud entitlement (Info.plist `VesperICloudContainer`):
/// setup steps in dev-notes/icloud-backups.md.
class ICloudBackups {
  ICloudBackups({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vespertv/icloud');

  final MethodChannel _channel;

  /// iPhone, iPad and Apple TV (Platform.isIOS is true on tvOS).
  static bool get supported => Platform.isIOS;

  /// 'available', 'noAccount', 'restricted', 'unavailable' or 'notSetUp'.
  Future<String> status() async {
    try {
      return await _channel.invokeMethod<String>('status') ?? 'unavailable';
    } on PlatformException catch (e) {
      return e.code == 'NOT_SET_UP' ? 'notSetUp' : 'unavailable';
    } on MissingPluginException {
      return 'notSetUp';
    }
  }

  /// Replaces this device's backup in iCloud with [content].
  Future<void> save(String content, {required String app}) =>
      _channel.invokeMethod<void>('save', {'content': content, 'app': app});

  /// Every device's backup, newest first.
  Future<List<ICloudBackupEntry>> list() async {
    final raw =
        await _channel.invokeListMethod<Map<Object?, Object?>>('list') ??
            const [];
    return [for (final m in raw) ICloudBackupEntry.fromMap(m)]
      ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  Future<String> read(String id) async =>
      await _channel.invokeMethod<String>('read', {'id': id}) ?? '';

  Future<void> delete(String id) =>
      _channel.invokeMethod<void>('delete', {'id': id});

  /// What to tell the viewer when [status] isn't 'available'.
  static String statusMessage(String status) => switch (status) {
        'noAccount' => tr(
            'Sign in to iCloud in this device\'s Settings to keep backups in iCloud.'),
        'restricted' => tr('iCloud is restricted on this device.'),
        'notSetUp' => tr('iCloud backups aren\'t available in this build yet.'),
        _ => tr('iCloud can\'t be reached right now. Try again later.'),
      };

  /// A failed call, in words.
  static String errorMessage(Object error) {
    if (error is PlatformException) {
      return switch (error.code) {
        'NOT_SET_UP' => statusMessage('notSetUp'),
        'NO_ACCOUNT' => statusMessage('noAccount'),
        'RESTRICTED' => statusMessage('restricted'),
        'QUOTA' => tr('Your iCloud storage is full.'),
        'NETWORK' => statusMessage('unavailable'),
        _ => error.message ?? error.code,
      };
    }
    return '$error';
  }
}
