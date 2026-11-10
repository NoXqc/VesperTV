import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/phone_pairing_service.dart';

/// Settings > Recordings > Network folder > From phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the phone form: share required, guest login allowed', () {
    final r = PairingResult.fromJson({
      'mode': 'smb',
      'server': r'\\192.168.1.20\Media',
      'name': 'VesperTV',
      'username': 'alex',
      'password': 'p w',
    })!;
    expect(r.server, r'\\192.168.1.20\Media');
    expect(r.name, 'VesperTV');
    expect(r.username, 'alex');
    expect(r.password, 'p w');
    // A guest share: no user name or password.
    expect(
        PairingResult.fromJson({'mode': 'smb', 'server': 'nas/TV'}), isNotNull);
    expect(PairingResult.fromJson({'mode': 'smb', 'server': ''}), isNull);
    expect(PairingKind.networkFolder.isWifiOnly, isTrue);
    expect(PairingKind.networkFolder.mode, 'smb');
  });

  test('the phone page has the network folder form', () async {
    final html = await rootBundle.loadString('assets/pair/pair.html');
    expect(html, contains('id="smb-view"'));
    expect(html, contains('mode: "smb"'));
  });

  test('a real LAN session takes only the network folder form', () async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
    final session = PhonePairingSession(kind: PairingKind.networkFolder);
    addTearDown(session.stop);
    await session.start();
    if (session.lanUrl == null) {
      markTestSkipped('No private LAN interface');
      return;
    }
    expect(session.lanUrl, endsWith('#smb'));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final url = Uri.parse(session.lanUrl!).replace(fragment: '');
    Future<int> send(Map data) async {
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    expect(
        await send({
          'mode': 'server',
          'server': 'http://x',
          'username': 'a',
        }),
        400);
    final result = session.results.first;
    expect(
        await send({
          'mode': 'smb',
          'server': '192.168.1.20/Media',
          'name': 'Films',
          'username': '',
          'password': '',
        }),
        204);
    final r = await result;
    expect(r.server, '192.168.1.20/Media');
    expect(r.name, 'Films');
  });
}
