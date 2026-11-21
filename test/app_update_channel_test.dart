import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/app_update_service.dart';

/// Weekly stable releases + test builds (owner, 2026-11-21, AMD's
/// suggestion): test builds are GitHub pre-releases tagged
/// `<next version>-dev.<build>`, offered only on Update channel: Test
/// builds; the stable channel keeps reading `/releases/latest`.
Map<String, dynamic> release(String tag,
        {bool pre = false, bool draft = false, bool apk = true}) =>
    {
      'tag_name': tag,
      'prerelease': pre,
      'draft': draft,
      'body': 'Notes for $tag',
      'assets': [
        if (apk)
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://example.com/$tag/app-release.apk',
            'size': 1000,
          },
      ],
    };

int cmp(String a, String b) => AppUpdateService.compareVersions(a, b);

void main() {
  group('compareVersions', () {
    test('numbers per part, like before', () {
      expect(cmp('1.0.73', '1.0.72'), greaterThan(0));
      expect(cmp('1.0.10', '1.0.9'), greaterThan(0));
      expect(cmp('1.0', '1.0.0'), 0);
      expect(cmp('v3.31.0', '3.29.0'), greaterThan(0));
    });

    test('a test build is below its stable and above older test builds', () {
      expect(cmp('1.0.73-dev.951', '1.0.73'), lessThan(0));
      expect(cmp('1.0.73-dev.951', '1.0.72'), greaterThan(0));
      expect(cmp('1.0.73-dev.960', '1.0.73-dev.951'), greaterThan(0));
      expect(cmp('1.0.73-dev.1000', '1.0.73-dev.999'), greaterThan(0),
          reason: 'build numbers compare as numbers');
      expect(cmp('1.0.74-dev.961', '1.0.73'), greaterThan(0));
      expect(cmp('1.0.73-dev.951', '1.0.73-dev.951'), 0);
    });
  });

  group('shouldOffer', () {
    bool offer(String remote, String installed, UpdateChannel c) =>
        AppUpdateService.shouldOffer(remote, installed, c);

    test('stable install, stable channel: any different tag (as before)', () {
      expect(offer('1.0.73', '1.0.72', UpdateChannel.stable), isTrue);
      expect(offer('1.0.72', '1.0.72', UpdateChannel.stable), isFalse);
      // The 1.0.0 restart after the 3.x NoXPlayer versions.
      expect(offer('1.0.0', '3.53.1', UpdateChannel.stable), isTrue);
    });

    test('a test build installed only takes a newer version', () {
      // Back on Stable: 1.0.72 would be a lower build number (Android
      // refuses it); the next weekly 1.0.73 is offered.
      expect(offer('1.0.72', '1.0.73-dev.951', UpdateChannel.stable), isFalse);
      expect(offer('1.0.73', '1.0.73-dev.951', UpdateChannel.stable), isTrue);
      expect(offer('1.0.73-dev.960', '1.0.73-dev.951', UpdateChannel.test),
          isTrue);
      expect(offer('1.0.73-dev.951', '1.0.73-dev.951', UpdateChannel.test),
          isFalse);
    });

    test('test channel on a stable install: newer only', () {
      expect(offer('1.0.73-dev.951', '1.0.72', UpdateChannel.test), isTrue);
      expect(offer('1.0.72', '1.0.72', UpdateChannel.test), isFalse);
      expect(offer('1.0.71', '1.0.72', UpdateChannel.test), isFalse);
    });
  });

  group('pickNewest', () {
    test('highest version with an asset for the device, no drafts', () {
      final picked = AppUpdateService.pickNewest([
        release('1.0.72'),
        release('1.0.73-dev.960', pre: true, apk: false),
        release('1.0.73-dev.955', pre: true),
        release('1.0.73-dev.970', pre: true, draft: true),
        release('1.0.73-dev.951', pre: true),
      ], 'android');
      expect(picked?['tag_name'], '1.0.73-dev.955');
    });

    test('the weekly stable beats the test builds before it', () {
      final picked = AppUpdateService.pickNewest([
        release('1.0.73-dev.955', pre: true),
        release('1.0.73'),
      ], 'android');
      expect(picked?['tag_name'], '1.0.73');
    });
  });

  group('checkForUpdate', () {
    late List<String> asked;
    late Object latest;
    late Object list;

    AppUpdateService service(String installed) => AppUpdateService(
          operatingSystem: 'android',
          installedVersion: () async => installed,
          apiClient: MockClient((r) async {
            asked.add(r.url.path + (r.url.hasQuery ? '?${r.url.query}' : ''));
            final body = r.url.path.endsWith('/latest') ? latest : list;
            return http.Response(jsonEncode(body), 200);
          }),
        );

    setUp(() {
      asked = [];
      // 1.0.72 is listed below newer test builds: renamed in place, its
      // release object is older than they are.
      latest = release('1.0.72');
      list = [
        release('1.0.73-dev.955', pre: true),
        release('1.0.73-dev.951', pre: true),
      ];
    });

    test('stable channel: the latest release only, no list', () async {
      final u = await service('1.0.71').checkForUpdate();
      expect(u?.version, '1.0.72');
      expect(u?.testBuild, isFalse);
      expect(asked, ['/repos/NoXqc/VesperTV/releases/latest']);
    });

    test('test channel: the newest test build', () async {
      final u =
          await service('1.0.72').checkForUpdate(channel: UpdateChannel.test);
      expect(u?.version, '1.0.73-dev.955');
      expect(u?.testBuild, isTrue);
      expect(u?.downloadUrl, endsWith('1.0.73-dev.955/app-release.apk'));
      expect(u?.apkSizeBytes, 1000);
      expect(asked, hasLength(2));
    });

    test('back on stable with a test build installed: wait for the weekly',
        () async {
      expect(await service('1.0.73-dev.955').checkForUpdate(), isNull);
      latest = release('1.0.73');
      expect((await service('1.0.73-dev.955').checkForUpdate())?.version,
          '1.0.73');
    });

    test('up to date on the test channel: nothing', () async {
      expect(
          await service('1.0.73-dev.955')
              .checkForUpdate(channel: UpdateChannel.test),
          isNull);
    });

    test('Linux and macOS: never asked', () async {
      final mac = AppUpdateService(
          operatingSystem: 'macos',
          installedVersion: () async => '1.0.71',
          apiClient: MockClient((r) async => throw StateError('asked')));
      expect(await mac.checkForUpdate(channel: UpdateChannel.test), isNull);
    });
  });

  test('UpdateChannel.parse: anything but "test" is stable', () {
    expect(UpdateChannel.parse('test'), UpdateChannel.test);
    expect(UpdateChannel.parse(null), UpdateChannel.stable);
    expect(UpdateChannel.parse('beta'), UpdateChannel.stable);
  });
}
