import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'first launch enables native surface without changing other video choices',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyVideoMediaOverlay: true,
    });
    final storage = StorageService();
    await storage.init();
    expect(storage.getNativeVideoSurface(), isTrue);
    expect(storage.getVideoMediaOverlay(), isTrue);
  });

  for (final enabled in [false, true]) {
    test('explicit native surface choice $enabled survives restart', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await storage.setNativeVideoSurface(enabled);
      final restarted = StorageService();
      await restarted.init();
      expect(restarted.getNativeVideoSurface(), enabled);
    });
  }
}
