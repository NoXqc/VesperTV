import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/addon_import.dart';
import 'package:nox_iptv/services/addon_service.dart';
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

ViewerProfile _profile(String id, {bool kids = false}) => ViewerProfile(
    id: id,
    name: id,
    colorIndex: 1,
    isRestricted: kids,
    createdAt: DateTime(2026));

/// Owner, 2026-11-24: people sharing a box want their own add-ons / Stremio
/// import. Adding a source (a link, Import from Stremio) has a Profiles
/// choice, and each source has a Profiles row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const movies = ArchiveSource(
      manifestUrl: 'https://movies.example/manifest.json', name: 'Movies');
  const anime = ArchiveSource(
      manifestUrl: 'https://anime.example/manifest.json', name: 'Anime');

  late StorageService storage;
  late ArchiveService archive;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([movies.toJson()]),
    });
    storage = StorageService();
    await storage.init();
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      _profile('guest'),
      _profile('kid', kids: true),
    ]);
    archive = ArchiveService(storage, cache: _Cache());
    addTearDown(archive.dispose);
  });

  Future<List<String>> onFor(String viewer) async {
    await storage.setActiveViewerId(viewer);
    return [for (final s in archive.enabledSources) s.name];
  }

  test('a source added for one profile is on only there', () async {
    await archive.addCheckedSources([anime], profiles: {'guest'});

    expect(await onFor(AppConstants.mainViewerId), ['Movies']);
    expect(await onFor('guest'), ['Movies', 'Anime']);
    expect(await onFor('kid'), isEmpty);
    expect(archive.profilesWith(anime), {'guest'});

    // A profile made later doesn't get it either.
    await storage
        .setViewerProfiles([...storage.getViewerProfiles(), _profile('later')]);
    expect(await onFor('later'), ['Movies']);
  });

  test('added for every regular profile = the usual default', () async {
    await archive.addCheckedSources([anime],
        profiles: {AppConstants.mainViewerId, 'guest'});
    expect(archive.profilesWith(anime), {AppConstants.mainViewerId, 'guest'});

    await storage
        .setViewerProfiles([...storage.getViewerProfiles(), _profile('later')]);
    expect(await onFor('later'), ['Movies', 'Anime']);
    expect(await onFor('kid'), isEmpty, reason: 'kids profiles stay off');
  });

  test("a source's Profiles row changes every profile at once", () async {
    expect(archive.profilesWith(movies), {AppConstants.mainViewerId, 'guest'});

    await archive.setSourceProfiles([movies.manifestUrl], {'kid'});
    expect(await onFor(AppConstants.mainViewerId), isEmpty);
    expect(await onFor('guest'), isEmpty);
    expect(await onFor('kid'), ['Movies']);

    await archive.setSourceProfiles(
        [movies.manifestUrl], {AppConstants.mainViewerId, 'guest', 'kid'});
    expect(await onFor('guest'), ['Movies']);
    expect(archive.profilesWith(movies),
        {AppConstants.mainViewerId, 'guest', 'kid'});
  });

  test('on a kids profile, the choice made while adding wins', () async {
    await storage.setActiveViewerId('kid');
    await archive
        .addCheckedSources([anime], profiles: {AppConstants.mainViewerId});
    expect(await onFor('kid'), isEmpty);
    expect(await onFor(AppConstants.mainViewerId), ['Movies', 'Anime']);
  });

  test('importing an add-on another profile added turns it on here', () async {
    await archive
        .addCheckedSources([anime], profiles: {AppConstants.mainViewerId});
    await storage.setActiveViewerId('guest');
    expect(archive.hasSource(anime.manifestUrl), isTrue);
    expect(archive.hasSourceOn(anime.manifestUrl), isFalse);

    final importer = AddonImporter(archive, AddonService(storage));
    final result = await importer.importLinks([anime.manifestUrl]);
    expect(result.nowOn, ['anime.example']);
    expect(result.alreadyThere, isEmpty);
    expect(await onFor('guest'), ['Movies', 'Anime']);
    expect(await onFor(AppConstants.mainViewerId), ['Movies', 'Anime'],
        reason: 'still on for the one who added it');

    // Again: nothing to change.
    await storage.setActiveViewerId('guest');
    final again = await importer.importLinks([anime.manifestUrl]);
    expect(again.alreadyThere, ['anime.example']);
    expect(again.nowOn, isEmpty);
  });
}
