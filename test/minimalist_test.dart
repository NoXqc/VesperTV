import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(StorageService, AppPreferences)> setUpPrefs() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    return (storage, prefs);
  }

  test('Minimalist turns the extras off, and off puts them back', () async {
    final (storage, prefs) = await setUpPrefs();
    prefs.setRefinedFinish(true);
    prefs.setGuideViewMode('live');
    prefs.setGuideFullVideo(true);
    prefs.setGuideCompact(false);
    prefs.setKeepGroupsOpen(true);
    prefs.setStartSection('hub');
    prefs.setLaunchWithProfiles(true);
    await prefs.setSportsMode(true);

    await prefs.setMinimalist(true);
    expect(prefs.minimalist, isTrue);
    expect(prefs.refinedFinish, isFalse);
    expect(prefs.guideViewMode, 'timeline');
    expect(prefs.guideFullVideo, isFalse);
    expect(prefs.guideCompact, isTrue);
    expect(prefs.keepGroupsOpen, isFalse);
    expect(prefs.homeHidden, isTrue);
    expect(prefs.hideProfiles, isTrue);
    expect(prefs.hideSportsTrak, isTrue);
    expect(prefs.sportsMode, isFalse);
    expect(prefs.hideArchive, isTrue);
    expect(prefs.launchWithProfiles, isFalse);
    expect(prefs.effectiveStartSection, 'tv');
    // Still separate settings: the viewer can bring one tab back.
    prefs.setHideArchive(false);
    expect(prefs.hideArchive, isFalse);

    await prefs.setMinimalist(false);
    expect(prefs.minimalist, isFalse);
    expect(prefs.refinedFinish, isTrue);
    expect(prefs.guideViewMode, 'live');
    expect(prefs.guideFullVideo, isTrue);
    expect(prefs.guideCompact, isFalse);
    expect(prefs.keepGroupsOpen, isTrue);
    expect(prefs.hideHome, isFalse);
    expect(prefs.hideProfiles, isFalse);
    expect(prefs.hideSportsTrak, isFalse);
    expect(prefs.sportsMode, isTrue);
    expect(prefs.hideArchive, isFalse);
    expect(prefs.launchWithProfiles, isTrue);
    expect(prefs.startSection, 'hub');
    expect(storage.getMinimalistBefore(), isNull);
  });

  test('an unset start section stays unset after a round trip', () async {
    final (storage, prefs) = await setUpPrefs();
    await prefs.setMinimalist(true);
    await prefs.setMinimalist(false);
    expect(storage.getStartSection(), isNull);
    expect(prefs.startSection, 'tv');
  });

  test('Home stays when it is the only page left', () async {
    final (_, prefs) = await setUpPrefs();
    prefs.setHideHome(true);
    expect(prefs.homeHidden, isTrue);
    prefs.setHideLiveTv(true);
    prefs.setHideMovies(true);
    prefs.setHideShows(true);
    expect(prefs.homeHidden, isFalse);
    prefs.setStartSection('home');
    expect(prefs.effectiveStartSection, 'home');
  });
}
