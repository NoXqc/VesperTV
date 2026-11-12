import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/backup_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('backup keeps device settings, drops caches, restores exactly',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyLayoutMode: 'tv',
      AppConstants.keyVideoFill: true,
      AppConstants.keyEpgCache: 'huge',
      AppConstants.keyLastAutoBackup: 123,
      'nox_favorites': <String>['a::1', 'b::2'],
    });
    final storage = StorageService();
    await storage.init();
    final backup = storage.exportForBackup();
    expect(backup.keys, contains(AppConstants.keyLayoutMode));
    expect(backup.keys, contains(AppConstants.keyVideoFill));
    expect(backup.keys, isNot(contains(AppConstants.keyEpgCache)));
    expect(backup.keys, isNot(contains(AppConstants.keyLastAutoBackup)));

    // Same file format BackupService writes, read back through decode.
    final file = jsonEncode({'format': 'vespertv-backup', 'data': backup});
    final values = BackupService.decode(file);

    SharedPreferences.setMockInitialValues({
      AppConstants.keyLayoutMode: 'auto',
      'nox_favorites': <String>['other::9'],
      'vesper_left_over': 'x',
    });
    final target = StorageService();
    await target.init();
    await target.importForBackup(values);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.keyLayoutMode), 'tv');
    expect(prefs.getBool(AppConstants.keyVideoFill), true);
    expect(prefs.getStringList('nox_favorites'), ['a::1', 'b::2']);
    expect(prefs.containsKey('vesper_left_over'), isFalse);
  });

  test(
      'Continue Watching history + recording settings travel with a backup / transfer',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final temp = await Directory.systemTemp.createTemp('vesper_history');
    addTearDown(() => temp.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => temp.path);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.writeCacheFile('recently_played', '["main"]');
    await storage.writeCacheFile('recently_played_vp_kid1', '["kid"]');
    await storage.writeCacheFile('live_channels_x', '["cache"]');
    final recordings = File('${temp.path}/recordings.json');
    await recordings.writeAsString(jsonEncode({
      'items': [
        {'id': 'old-box'}
      ],
      'settings': {
        'downloadSpeed': '25',
        'folder': '/storage/USB1/Recordings',
        'network': {'host': '10.0.0.81', 'share': 'Media', 'user': 'me'},
      },
    }));
    final payload = jsonDecode(jsonEncode(
            await storage.withProfilePhotos(storage.exportForTransfer())))
        as Map<String, Object?>;

    await storage.clearCache();
    expect(await storage.readCacheFile('recently_played'), isNull);
    // The new box: its own recordings list and USB folder.
    await recordings.writeAsString(jsonEncode({
      'items': [
        {'id': 'new-box'}
      ],
      'settings': {'folder': '/storage/SD/Recordings'},
    }));
    await storage.importForTransfer(payload);
    expect(await storage.readCacheFile('recently_played'), '["main"]');
    expect(await storage.readCacheFile('recently_played_vp_kid1'), '["kid"]');
    // Only history files: other caches never come back from a payload.
    expect(await storage.readCacheFile('live_channels_x'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('vesper_history_files'), isFalse);
    expect(prefs.containsKey('vesper_recording_settings'), isFalse);
    final after = jsonDecode(await recordings.readAsString()) as Map;
    expect(after['items'], [
      {'id': 'new-box'}
    ]);
    expect(after['settings']['downloadSpeed'], '25');
    expect(after['settings']['network']['share'], 'Media');
    expect(after['settings']['folder'], '/storage/SD/Recordings');
  });

  test('start choices travel with a transfer, never with sync', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyStartSection: 'home',
      AppConstants.keyLaunchWithProfiles: true,
      AppConstants.keyFastStartup: false,
      AppConstants.keyLayoutMode: 'tv',
    });
    final storage = StorageService();
    await storage.init();
    final transfer = storage.exportForTransfer();
    expect(transfer.keys, contains(AppConstants.keyStartSection));
    expect(transfer.keys, contains(AppConstants.keyLaunchWithProfiles));
    // Owner rule: Fast startup never transfers; layout is the device's.
    expect(transfer.keys, isNot(contains(AppConstants.keyFastStartup)));
    expect(transfer.keys, isNot(contains(AppConstants.keyLayoutMode)));
    final sync = storage.exportForSync();
    expect(sync.keys, isNot(contains(AppConstants.keyStartSection)));
    expect(sync.keys, isNot(contains(AppConstants.keyLaunchWithProfiles)));
  });

  test('decode rejects files that are not VesperTV backups', () {
    expect(() => BackupService.decode('not json'), throwsFormatException);
    expect(() => BackupService.decode('{"format":"other","data":{}}'),
        throwsFormatException);
  });
}
