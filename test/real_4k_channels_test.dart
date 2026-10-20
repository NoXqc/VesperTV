import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/real_4k_channels.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a channel earns the tag at 2160p and loses it when lower', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    Real4kChannels.init(storage);

    Real4kChannels.record('p::sky4k', 0, 0); // still starting: ignored
    expect(Real4kChannels.contains('p::sky4k'), isFalse);

    Real4kChannels.record('p::sky4k', 3840, 2160);
    expect(Real4kChannels.contains('p::sky4k'), isTrue);
    expect(storage.getReal4kChannels(), {'p::sky4k'});

    // A "4K" channel that's really 1080p: never tagged, or untagged.
    Real4kChannels.record('p::sky4k', 1920, 1080);
    expect(Real4kChannels.contains('p::sky4k'), isFalse);
    expect(storage.getReal4kChannels(), isEmpty);
  });
}
