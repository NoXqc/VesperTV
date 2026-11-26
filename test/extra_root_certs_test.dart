import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/extra_root_certs.dart';

/// Discord (2026-11-26): a 2015 Sony Bravia on Android 7.0 showed no posters
/// and only some channel logos; other apps showed them. Android 7.0 lacks
/// Let's Encrypt's roots, so every image host with a Let's Encrypt
/// certificate failed the TLS handshake in Flutter's HTTP client.
void main() {
  test('the bundled roots are exactly Let\'s Encrypt\'s', () {
    for (final e in ExtraRootCerts.certificates.entries) {
      expect(
          ExtraRootCerts.sha256Of(e.value), ExtraRootCerts.fingerprints[e.key],
          reason: e.key);
    }
  });

  test('only devices before Android 7.1.1 get them', () {
    expect(ExtraRootCerts.neededOn(24), isTrue); // Android 7.0
    expect(ExtraRootCerts.neededOn(25), isFalse); // 7.1.1 has ISRG Root X1
    expect(ExtraRootCerts.neededOn(34), isFalse);
    expect(ExtraRootCerts.neededOn(0), isFalse); // unknown: leave it alone
  });

  test('both roots load into a TLS context', () {
    final context = SecurityContext(withTrustedRoots: false);
    expect(ExtraRootCerts.addTo(context), ['ISRG Root X1', 'ISRG Root X2']);
  });

  test('the Android player trusts the same two roots', () {
    for (final name in ['isrg_root_x1', 'isrg_root_x2']) {
      final pem =
          File('android/app/src/main/res/raw/$name.pem').readAsStringSync();
      final key = name == 'isrg_root_x1' ? 'ISRG Root X1' : 'ISRG Root X2';
      expect(ExtraRootCerts.sha256Of(pem), ExtraRootCerts.fingerprints[key]);
    }
    final config =
        File('android/app/src/main/res/xml/network_security_config.xml')
            .readAsStringSync();
    expect(config, contains('cleartextTrafficPermitted="true"'),
        reason: 'plain http IPTV streams must keep working');
    expect(config, contains('src="system"'));
    expect(config, contains('@raw/isrg_root_x1'));
    expect(config, contains('@raw/isrg_root_x2'));
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
        manifest,
        contains(
            'android:networkSecurityConfig="@xml/network_security_config"'));
  });
}
