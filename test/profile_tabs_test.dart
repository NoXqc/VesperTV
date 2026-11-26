import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-11-25: "Created a profile for my wife. Set her up with
/// minimalist - hide movies hide tv shows - enable media hub. Backed out
/// from the app. Logged in my profile and my profile had those settings
/// too." The Tabs switches and Minimalist are per profile now.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String profiles(List<String> ids) => jsonEncode([
        ViewerProfile.main().toJson(),
        for (final id in ids)
          ViewerProfile(
                  id: id,
                  name: id,
                  colorIndex: 1,
                  isRestricted: false,
                  createdAt: DateTime(2026))
              .toJson(),
      ]);

  String scoped(String key, String id) =>
      '$key${AppConstants.viewerKeySuffix}$id';

  Future<(StorageService, AppPreferences)> start(
      Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    return (storage, prefs);
  }

  Future<void> switchTo(
      StorageService storage, AppPreferences prefs, String id) async {
    await storage.setActiveViewerId(id);
    prefs.reloadPaletteForViewer();
  }

  test("a profile's tabs and Minimalist stay on that profile", () async {
    final (storage, prefs) = await start({
      AppConstants.keyViewerProfiles: profiles(['wife']),
    });
    prefs.setLaunchWithProfiles(true);
    prefs.setKeepGroupsOpen(true);
    prefs.setStartSection('home');

    await switchTo(storage, prefs, 'wife');
    await prefs.setMinimalist(true);
    prefs.setHideMovies(true);
    prefs.setHideShows(true);
    prefs.setHideArchive(false); // she turned the Media Hub back on
    expect(prefs.hideHome, isTrue);
    expect(prefs.effectiveStartSection, 'tv');

    await switchTo(storage, prefs, AppConstants.mainViewerId);
    expect(prefs.minimalist, isFalse);
    expect(prefs.hideMovies, isFalse);
    expect(prefs.hideShows, isFalse);
    expect(prefs.hideHome, isFalse);
    expect(prefs.hideSportsTrak, isFalse);
    expect(prefs.hideArchive, isFalse);
    expect(prefs.hideProfiles, isFalse);
    // The device's own settings: other profiles keep them.
    expect(prefs.launchWithProfiles, isTrue);
    expect(prefs.keepGroupsOpen, isTrue);
    expect(prefs.startSection, 'home');
    expect(prefs.effectiveStartSection, 'home');

    await switchTo(storage, prefs, 'wife');
    expect(prefs.minimalist, isTrue);
    expect(prefs.hideMovies, isTrue);
    expect(prefs.hideShows, isTrue);
    expect(prefs.hideHome, isTrue);
    expect(prefs.hideArchive, isFalse);

    // Off on her profile puts hers back and leaves the device alone.
    await prefs.setMinimalist(false);
    expect(prefs.hideHome, isFalse);
    expect(prefs.launchWithProfiles, isTrue);
    expect(prefs.keepGroupsOpen, isTrue);
    expect(prefs.startSection, 'home');
  });

  test('the old device-wide choice is copied once to existing profiles',
      () async {
    final (storage, prefs) = await start({
      AppConstants.keyViewerProfiles: profiles(['kid']),
      AppConstants.keyHideMoviesShows: true,
      AppConstants.keyHideArchive: true,
      AppConstants.keyMinimalist: true,
      AppConstants.keyMinimalistBefore: '{"hideHome":false}',
    });
    expect(prefs.hideMovies, isTrue); // Main keeps its bare keys
    expect(prefs.hideArchive, isTrue);

    await switchTo(storage, prefs, 'kid');
    expect(prefs.hideMovies, isTrue);
    expect(prefs.hideShows, isTrue);
    expect(prefs.hideArchive, isTrue);
    expect(prefs.minimalist, isTrue);
    expect(storage.getMinimalistBefore(), '{"hideHome":false}');

    // Copied once: a change on Main later stays on Main.
    await switchTo(storage, prefs, AppConstants.mainViewerId);
    prefs.setHideArchive(false);
    await switchTo(storage, prefs, 'kid');
    expect(prefs.hideArchive, isTrue);
  });

  test('a profile made after the update starts with every tab', () async {
    final (storage, prefs) = await start({
      AppConstants.keyViewerProfiles: profiles([]),
      AppConstants.keyHideMovies: true,
    });
    await storage.setViewerProfiles(_list(profiles(['new'])));
    await switchTo(storage, prefs, 'new');
    expect(prefs.hideMovies, isFalse);
    expect(
        (await SharedPreferences.getInstance())
            .containsKey(scoped(AppConstants.keyHideMovies, 'new')),
        isFalse);
  });
}

List<ViewerProfile> _list(String raw) => [
      for (final e in jsonDecode(raw) as List)
        ViewerProfile.fromJson(e as Map<String, dynamic>)
    ];
