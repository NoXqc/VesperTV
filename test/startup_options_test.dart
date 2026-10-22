import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User requests: "option to auto-update content" (per playlist) and
/// "option to select which section to start on" (Settings > Startup).
void main() {
  PlaylistProfile profile({bool? autoSync}) => PlaylistProfile(
        id: 'p1',
        name: 'Main',
        mode: 'xtream',
        sortOrder: 0,
        createdAt: DateTime(2026),
        autoSync: autoSync ?? false,
      );

  test('Update automatically is saved with the playlist, off by default',
      () {
    expect(profile().autoSync, isFalse);
    final on = PlaylistProfile.fromJson(profile(autoSync: true).toJson());
    expect(on.autoSync, isTrue);
    expect(profile().copyWith(autoSync: true).autoSync, isTrue);
    // A playlist saved before the option existed keeps asking.
    final old = profile().toJson()..remove('autoSync');
    expect(PlaylistProfile.fromJson(old).autoSync, isFalse);
  });

  test('Open on: saved choice, hidden section falls back to TV', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    expect(prefs.startSection, 'tv');

    prefs.setStartSection('sports');
    expect(prefs.effectiveStartSection, 'sports');

    prefs.setStartSection('movies');
    expect(prefs.effectiveStartSection, 'movies');
    prefs.setHideMovies(true);
    expect(prefs.effectiveStartSection, 'tv');

    prefs.setStartSection('hub');
    prefs.setHideArchive(true);
    expect(prefs.effectiveStartSection, 'tv');
  });
}
