import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/desktop_stream_setup.dart';

void main() {
  test('the mpv player names its own device in the User-Agent', () {
    expect(streamUserAgentDevice('windows'), 'Windows');
    expect(streamUserAgentDevice('linux'), 'Linux');
    expect(streamUserAgentDevice('macos'), 'macOS');
    expect(streamUserAgentDevice('ios'), 'iOS');
    expect(streamUserAgentDevice('tvos'), 'Apple TV');
  });

  test('the User-Agent keeps the Dalvik start IPTV panels accept', () {
    expect(kDesktopStreamUserAgent,
        startsWith('Dalvik/2.1.0 (Linux; U; Android 11; VesperTV '));
    expect(kDesktopStreamUserAgent, endsWith(')'));
  });
}
