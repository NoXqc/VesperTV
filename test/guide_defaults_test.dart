import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final saved in [null, 'live', 'timeline']) {
    test('guide startup respects saved choice $saved and fresh-install default',
        () async {
      SharedPreferences.setMockInitialValues({
        if (saved != null) AppConstants.keyGuideViewMode: saved,
      });
      final storage = StorageService();
      await storage.init();
      final preferences = AppPreferences(storage);
      await preferences.init();
      expect(preferences.guideViewMode, saved ?? 'timeline');
      preferences.dispose();
    });
  }
}
