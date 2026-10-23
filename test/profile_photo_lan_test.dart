import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nox_iptv/services/phone_pairing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'real LAN photo session rejects oversized/non-image/corrupt data before delivering',
      () async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
    final session = PhonePairingSession(kind: PairingKind.photo);
    addTearDown(session.stop);
    await session.start();
    if (session.lanUrl == null) {
      markTestSkipped('No private LAN interface');
      return;
    }
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
        await send(
            {'mode': 'photo', 'mime': 'image/png', 'photo': 'A' * 2800000}),
        400);
    expect(
        await send({
          'mode': 'photo',
          'mime': 'image/jpeg',
          'photo': base64Encode([255, 216, 255, 0])
        }),
        400);
    expect(await send({'mode': 'link', 'link': 'https://example.test'}), 400);
    final result = session.results.first;
    final bytes = img.encodePng(img.Image(width: 20, height: 30));
    expect(
        await send({
          'mode': 'photo',
          'mime': 'image/png',
          'photo': base64Encode(bytes)
        }),
        204);
    expect((await result).photo, bytes);
    expect(session.isExpired, true);
  });
}
