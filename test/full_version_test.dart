import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _info(String version, String build) => PackageInfo(
      appName: 'VesperTV',
      packageName: 'com.nox.nox_iptv',
      version: version,
      buildNumber: build,
    );

void main() {
  test('the Help footer shows the build number the way TestFlight does', () {
    expect(fullVersion(_info('1.0.73', '954')), '1.0.73 (954)');
    expect(fullVersion(_info('1.0.73-dev.961', '961')), '1.0.73-dev.961 (961)');
  });

  test('a platform without a build number shows the version alone', () {
    expect(fullVersion(_info('1.0.73', '')), '1.0.73');
    expect(fullVersion(_info('1.0.73', '  ')), '1.0.73');
  });
}
