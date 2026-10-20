import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

/// One backup file in the backup folder.
class BackupEntry {
  const BackupEntry({
    required this.id,
    required this.name,
    required this.modified,
    required this.size,
  });

  /// A `content://` URI or a file path — whatever [BackupService] needs to
  /// read or delete it again.
  final String id;
  final String name;
  final DateTime modified;
  final int size;

  bool get isAuto => name.startsWith(BackupService.autoPrefix);
}

/// Settings > Backup & restore: the whole setup ([StorageService
/// .exportForBackup] — playlists, every viewer's favourites, hidden groups,
/// channel order, progress, Media Hub, Trakt/Simkl, settings) as one JSON
/// file in Download/VesperTV on Android (`BackupStore.kt`, survives an
/// uninstall) or Documents\VesperTV on Windows. Catalog/EPG caches aren't
/// in it — they download again after a restore, as after a transfer.
///
/// Automatic backups (off by default) run at most once a week, at startup
/// ([maybeAutoBackup]); only the newest [keepAuto] of them are kept.
/// Manual backups are never deleted by the app.
class BackupService {
  BackupService(this._storage);

  final StorageService _storage;

  static const _channel = MethodChannel('com.nox.nox_iptv/backup');
  static const manualPrefix = 'vespertv-backup-';
  static const autoPrefix = 'vespertv-autobackup-';
  static const _format = 'vespertv-backup';
  static const keepAuto = 5;
  static const autoInterval = Duration(days: 7);

  static bool get supported => Platform.isAndroid || Platform.isWindows;

  /// Where the files go, as the user would look for it.
  static String get locationLabel =>
      Platform.isWindows ? r'Documents\VesperTV' : 'Download/VesperTV';

  Future<Directory> _windowsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'VesperTV')).create(recursive: true);
  }

  /// Android 9 and older ask for storage access (once); everything else is
  /// always true.
  Future<bool> ensurePermission({required bool write}) async {
    if (!Platform.isAndroid) return true;
    return await _channel
            .invokeMethod<bool>('ensurePermission', {'write': write}) ??
        false;
  }

  Future<bool> _hasPermission({required bool write}) async {
    if (!Platform.isAndroid) return true;
    return await _channel
            .invokeMethod<bool>('hasPermission', {'write': write}) ??
        false;
  }

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// Writes a backup of the current setup and returns it.
  Future<BackupEntry> create({bool auto = false}) async {
    final info = await PackageInfo.fromPlatform();
    final now = DateTime.now();
    final content = jsonEncode({
      'format': _format,
      'formatVersion': 1,
      'app': '${info.version}+${info.buildNumber}',
      'platform': Platform.operatingSystem,
      'created': now.toIso8601String(),
      'data': _storage.exportForBackup(),
    });
    final name = '${auto ? autoPrefix : manualPrefix}${_stamp(now)}.json';
    final String id;
    if (Platform.isAndroid) {
      id = await _channel.invokeMethod<String>(
              'save', {'name': name, 'content': content}) ??
          '';
    } else {
      final file = File(p.join((await _windowsDir()).path, name));
      await file.writeAsString(content, flush: true);
      id = file.path;
    }
    if (auto) await _pruneAuto();
    return BackupEntry(
        id: id, name: name, modified: now, size: utf8.encode(content).length);
  }

  /// Newest first.
  Future<List<BackupEntry>> list() async {
    final entries = <BackupEntry>[];
    if (Platform.isAndroid) {
      final raw = await _channel.invokeListMethod<Map>('list') ?? const [];
      for (final m in raw) {
        entries.add(BackupEntry(
          id: m['id'] as String,
          name: m['name'] as String,
          modified: DateTime.fromMillisecondsSinceEpoch(
              (m['modified'] as num).toInt()),
          size: (m['size'] as num).toInt(),
        ));
      }
    } else if (Platform.isWindows) {
      await for (final f in (await _windowsDir()).list()) {
        final name = p.basename(f.path);
        if (f is! File ||
            !name.startsWith('vespertv-') ||
            !name.endsWith('.json')) {
          continue;
        }
        final stat = await f.stat();
        entries.add(BackupEntry(
            id: f.path, name: name, modified: stat.modified, size: stat.size));
      }
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    return entries;
  }

  /// The setup stored in [entry], ready for [StorageService.importForBackup].
  /// Throws [FormatException] for a file that isn't a VesperTV backup.
  Future<Map<String, Object?>> load(BackupEntry entry) async {
    final raw = Platform.isAndroid
        ? await _channel.invokeMethod<String>('read', {'id': entry.id}) ?? ''
        : await File(entry.id).readAsString();
    return decode(raw);
  }

  /// Android: a backup picked with the system file picker (after a
  /// reinstall on Android 11+, where [list] can't see the old files). Null
  /// when cancelled; a [PlatformException] `NO_PICKER` when the device has
  /// no picker (Fire TV).
  Future<Map<String, Object?>?> pickAndLoad() async {
    final raw = await _channel.invokeMethod<String>('pick');
    return raw == null ? null : decode(raw);
  }

  static Map<String, Object?> decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('not a VesperTV backup');
    }
    if (json is! Map || json['format'] != _format || json['data'] is! Map) {
      throw const FormatException('not a VesperTV backup');
    }
    return Map<String, Object?>.from(json['data'] as Map);
  }

  Future<bool> delete(BackupEntry entry) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<bool>('delete', {'id': entry.id}) ??
          false;
    }
    try {
      await File(entry.id).delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _pruneAuto() async {
    final autos = (await list()).where((e) => e.isAuto).toList();
    for (final old in autos.skip(keepAuto)) {
      await delete(old);
    }
  }

  /// Startup hook: an automatic backup when the switch is on and the last
  /// one is a week old. Never prompts — on Android 9- without storage
  /// access (granted when the switch was turned on) it just skips.
  Future<void> maybeAutoBackup() async {
    if (!supported || !_storage.getAutoBackup()) return;
    final last = _storage.getLastAutoBackup();
    if (last != null && DateTime.now().difference(last) < autoInterval) return;
    try {
      if (!await _hasPermission(write: true)) return;
      await create(auto: true);
      await _storage.setLastAutoBackup(DateTime.now());
    } catch (e) {
      debugPrint('Automatic backup failed: $e');
    }
  }
}
