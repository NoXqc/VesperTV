import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/desktop_platform.dart';

/// iPhone / iPad: a folder picked once in Files (iCloud Drive, OneDrive,
/// Google Drive, an SMB server added to Files…) where Settings > Backup &
/// restore saves, lists and restores backups instead of On My iPhone (owner,
/// 2026-11-22: "save on their cloud, similar to SMB or external storage").
///
/// Native side: `VesperBackupFolder` in ios/Runner/AppDelegate.swift. The
/// folder is kept as a bookmark (iOS's lasting permission for a folder
/// outside the app), every read and write is coordinated with the Files
/// provider, and a backup that isn't downloaded yet (iCloud) is fetched when
/// it is read. Not on Apple TV (no Files app) or any other system.
class BackupFolder {
  BackupFolder({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vespertv/backup_folder');

  final MethodChannel _channel;

  static bool get supported => Platform.isIOS && !isAppleTv;

  /// The chosen folder's name, or null for On My iPhone (none chosen).
  /// Throws a [PlatformException] `UNREACHABLE` when the folder was chosen
  /// but can't be opened any more (removed, signed out of the provider).
  Future<String?> name() => _channel.invokeMethod<String>('name');

  /// Opens the Files folder picker; the picked folder's name, or null when
  /// cancelled.
  Future<String?> choose() => _channel.invokeMethod<String>('choose');

  /// Back to On My iPhone.
  Future<void> clear() => _channel.invokeMethod<void>('clear');

  /// Saves [content] as [name] in the folder; the id to read it back.
  Future<String> write(String name, String content) async =>
      await _channel
          .invokeMethod<String>('write', {'name': name, 'content': content}) ??
      name;

  /// The folder's backup files: `{id, name, modified (ms), size}`.
  Future<List<Map<Object?, Object?>>> list() async =>
      await _channel.invokeListMethod<Map<Object?, Object?>>('list') ??
      const [];

  Future<String> read(String id) async =>
      await _channel.invokeMethod<String>('read', {'id': id}) ?? '';

  Future<bool> delete(String id) async =>
      await _channel.invokeMethod<bool>('delete', {'id': id}) ?? false;
}
