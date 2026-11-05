import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guide layout is per profile, falling back to the shared value',
      () async {
    // Before 1.0.57+631 the guide layout was one setting for every profile.
    SharedPreferences.setMockInitialValues({
      AppConstants.keyGuideFullVideo: true,
      AppConstants.keyGuideTransparency: 70,
    });
    final storage = StorageService();
    await storage.init();

    // A profile that never changed it keeps what everyone had.
    await storage.setActiveViewerId('wife');
    expect(storage.getGuideFullVideo(), isTrue);
    expect(storage.getGuideTransparency(), 70);

    // The wife's solid guide with the mini player...
    await storage.setGuideFullVideo(false);
    await storage.setGuideTransparency(0);
    expect(storage.getGuideFullVideo(), isFalse);

    // ...doesn't touch Main's see-through full-screen guide.
    await storage.setActiveViewerId(AppConstants.mainViewerId);
    expect(storage.getGuideFullVideo(), isTrue);
    expect(storage.getGuideTransparency(), 70);
  });
}
