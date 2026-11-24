import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cache extends ArchiveCache {
  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;

  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

/// Discord, 2026-11-23: a kids profile's search showed adult titles. A kids
/// profile starts with every Media Hub source off; a parent turns on the
/// ones it may use (its sources page asks the PIN).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const movies = ArchiveSource(
      manifestUrl: 'https://movies.example/manifest.json', name: 'Movies');
  const adult = ArchiveSource(
      manifestUrl: 'https://adult.example/manifest.json', name: 'Adult');

  late StorageService storage;
  late ArchiveService archive;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources:
          jsonEncode([movies.toJson(), adult.toJson()]),
    });
    storage = StorageService();
    await storage.init();
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'kid',
          name: 'Kid',
          colorIndex: 1,
          isRestricted: true,
          createdAt: DateTime(2026)),
      ViewerProfile(
          id: 'guest',
          name: 'Guest',
          colorIndex: 2,
          isRestricted: false,
          createdAt: DateTime(2026)),
    ]);
    archive = ArchiveService(storage, cache: _Cache());
    addTearDown(archive.dispose);
  });

  List<String> on() => [for (final s in archive.enabledSources) s.name];

  test('a kids profile starts with every source off', () async {
    expect(on(), ['Movies', 'Adult']);
    await storage.setActiveViewerId('guest');
    expect(on(), ['Movies', 'Adult'], reason: 'other profiles unchanged');

    await storage.setActiveViewerId('kid');
    expect(archive.isKidsProfile, isTrue);
    expect(on(), isEmpty);
    expect(archive.sources.length, 2, reason: 'listed, to turn on');

    await archive.setEnabled(movies, true);
    expect(on(), ['Movies']);

    await storage.setActiveViewerId(AppConstants.mainViewerId);
    expect(on(), ['Movies', 'Adult']);
  });

  test('a source added on the kids profile is on there only', () async {
    await storage.setActiveViewerId('kid');
    const cartoons = ArchiveSource(
        manifestUrl: 'https://cartoons.example/manifest.json',
        name: 'Cartoons');
    await archive.addCheckedSources([cartoons]);
    expect(on(), ['Cartoons']);

    await storage.setActiveViewerId('guest');
    expect(on(), ['Movies', 'Adult', 'Cartoons']);
  });
}
