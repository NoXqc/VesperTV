import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/profile_copy.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Compact UI is off by default and kept per profile', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyViewerProfiles: jsonEncode([
        ViewerProfile.main().toJson(),
        ViewerProfile(
                id: 'alice',
                name: 'Alice',
                colorIndex: 0,
                isRestricted: false,
                createdAt: DateTime(2026))
            .toJson(),
      ]),
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    expect(prefs.compactUi, isFalse);

    prefs.setCompactUi(true);
    expect(storage.getCompactUi(), isTrue);

    // Another viewer keeps their own (off until they change it)...
    await storage.setActiveViewerId('alice');
    prefs.reloadPaletteForViewer();
    expect(prefs.compactUi, isFalse);
    prefs.setCompactUi(false);

    // ...and Main's choice is still there when switching back.
    await storage.setActiveViewerId(AppConstants.mainViewerId);
    prefs.reloadPaletteForViewer();
    expect(prefs.compactUi, isTrue);

    // Survives a restart.
    final reloaded = AppPreferences(storage);
    await reloaded.init();
    expect(reloaded.compactUi, isTrue);
    reloaded.dispose();
    prefs.dispose();
  });

  test('a new profile copying Main\'s Home settings gets Compact UI too', () {
    expect(copyMainKey(AppConstants.keyCompactUi, {ProfileCopy.home}), isTrue);
    expect(copyMainKey(AppConstants.keyCompactUi, {ProfileCopy.favourites}),
        isFalse);
  });
}
