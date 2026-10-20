import 'dart:convert';

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

  test('decode rejects files that are not VesperTV backups', () {
    expect(() => BackupService.decode('not json'), throwsFormatException);
    expect(() => BackupService.decode('{"format":"other","data":{}}'),
        throwsFormatException);
  });
}
