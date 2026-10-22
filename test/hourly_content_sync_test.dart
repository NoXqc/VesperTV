import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  PlaylistProfile profile(
          {int days = 3,
          int? hours,
          String id = 'p',
          String mode = 'xtream',
          bool automatic = false,
          bool enabled = true}) =>
      PlaylistProfile(
          id: id,
          name: id,
          mode: mode,
          sortOrder: 0,
          createdAt: DateTime(2026),
          syncFrequencyDays: days,
          syncFrequencyHours: hours,
          autoSync: automatic,
          enabled: enabled);

  PlaylistSession session(PlaylistProfile p) => PlaylistSession(
      profile: p,
      storage: storage,
      catalogDb: CatalogDatabase(),
      favoriteIds: () => {},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {});

  test('old profiles retain all supported day intervals', () {
    for (final days in [1, 3, 7, 10, 14]) {
      final json = profile(days: days).toJson()..remove('syncFrequencyHours');
      final restored = PlaylistProfile.fromJson(json);
      expect(restored.syncInterval, Duration(days: days));
      expect(restored.copyWith(name: 'Renamed').syncInterval,
          Duration(days: days));
    }
  });

  test(
      'hour intervals survive save, unrelated edits and conversion back to days',
      () {
    for (final hours in AppConstants.syncFrequencyHoursOptions) {
      final p = PlaylistProfile.fromJson(
          profile(hours: hours, automatic: true).toJson());
      expect(p.syncInterval, Duration(hours: hours));
      expect(p.copyWith(name: 'Renamed', autoSync: false).syncIntervalHours,
          hours);
      expect(p.copyWith(syncFrequencyDays: 7).syncInterval,
          const Duration(days: 7));
      expect(p.copyWith(syncFrequencyHours: 24).syncInterval,
          const Duration(days: 1));
    }
    expect(profile(hours: 0).syncInterval, const Duration(days: 3));
  });

  test('each interval becomes due after its elapsed hours', () async {
    for (final hours in AppConstants.syncFrequencyHoursOptions) {
      final s = session(profile(id: 'p$hours', hours: hours));
      expect(s.needsFullSync(), isTrue);
      await storage.setLastFullSyncAt(
          'p$hours',
          DateTime.now()
              .subtract(Duration(hours: hours) - const Duration(minutes: 1)));
      expect(s.needsFullSync(), isFalse);
      await storage.setLastFullSyncAt(
          'p$hours',
          DateTime.now()
              .subtract(Duration(hours: hours) + const Duration(minutes: 1)));
      expect(s.needsFullSync(), isTrue);
    }
    expect(session(profile(mode: 'm3u')).needsFullSync(), isFalse);
  });

  test('prompt/automatic decision uses due hourly playlists and enabled state',
      () async {
    final manager = PlaylistManager(storage, CatalogDatabase());
    addTearDown(manager.dispose);
    await manager.addPlaylist(profile(id: 'hourly', hours: 1, automatic: true));
    await manager.addPlaylist(profile(id: 'daily', days: 1));
    await manager
        .addPlaylist(profile(id: 'disabled', hours: 1, enabled: false));
    await storage.setLastFullSyncAt(
        'hourly', DateTime.now().subtract(const Duration(hours: 2)));
    await storage.setLastFullSyncAt('daily', DateTime.now());
    expect(manager.needsFullSync(), isTrue);
    expect(manager.dueSyncIsAutomatic(), isTrue);
    await manager.updatePlaylist(profile(id: 'hourly', hours: 1));
    expect(manager.dueSyncIsAutomatic(), isFalse);
    await storage.setLastFullSyncAt('hourly', DateTime.now());
    expect(manager.needsFullSync(), isFalse);
  });

  for (final backup in [false, true]) {
    test('hour settings survive ${backup ? 'backup' : 'transfer'} import',
        () async {
      await storage.setPlaylists([profile(hours: 3, automatic: true)]);
      final payload =
          backup ? storage.exportForBackup() : storage.exportForTransfer();
      await storage.setPlaylists([]);
      if (backup) {
        await storage.importForBackup(payload);
      } else {
        await storage.importForTransfer(payload);
      }
      final p = storage.getPlaylists().single;
      expect(p.syncInterval, const Duration(hours: 3));
      expect(p.autoSync, isTrue);
    });
  }
}
