import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_update_service.dart';

Map<String, dynamic> asset(String name) =>
    {'name': name, 'browser_download_url': 'https://example.com/$name'};

String? pick(List<String> names, String os) =>
    AppUpdateService.pickAsset([for (final n in names) asset(n)], os)['name']
        as String?;

void main() {
  test('each platform takes its own asset', () {
    const names = [
      'VesperTV-macos.zip',
      'app-release.apk',
      'VesperTV-windows-x64.zip',
    ];
    expect(pick(names, 'android'), 'app-release.apk');
    expect(pick(names, 'windows'), 'VesperTV-windows-x64.zip');
    expect(pick(names, 'macos'), 'VesperTV-macos.zip');
  });

  test('Windows never takes the Mac zip, even listed alone', () {
    expect(pick(['VesperTV-macos.zip', 'app-release.apk'], 'windows'), isNull);
  });

  test('macOS never takes the Windows zip', () {
    expect(
        pick(['VesperTV-windows-x64.zip', 'app-release.apk'], 'macos'), isNull);
  });

  test('existing releases (APK + Windows zip) are unchanged', () {
    const names = ['app-release.apk', 'VesperTV-windows-x64.zip'];
    expect(pick(names, 'android'), 'app-release.apk');
    expect(pick(names, 'windows'), 'VesperTV-windows-x64.zip');
  });

  test('names are matched case-insensitively; unknown OS gets nothing', () {
    expect(pick(['VesperTV-MacOS.ZIP'], 'macos'), 'VesperTV-MacOS.ZIP');
    expect(pick(['app-release.apk'], 'linux'), isNull);
  });
}
