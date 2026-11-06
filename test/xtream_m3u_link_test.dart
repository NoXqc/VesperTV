import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/xtream.dart';

void main() {
  test('an Xtream get.php M3U link gives its login', () {
    final login = XtreamHelper.fromM3uUrl(
        'http://line.example.com:8080/get.php?username=abc&password=xyz'
        '&type=m3u_plus&output=ts');
    expect(login?.server, 'http://line.example.com:8080');
    expect(login?.username, 'abc');
    expect(login?.password, 'xyz');
    expect(
        XtreamHelper.fromM3uUrl(
                'https://example.com/GET.PHP?username=a&password=b')
            ?.server,
        'https://example.com');
  });

  test('other links stay M3U', () {
    for (final url in [
      'http://example.com/playlist.m3u',
      'http://example.com/get.php?username=abc',
      'http://example.com/get.php?password=xyz',
      'http://example.com/list.m3u?username=a&password=b',
      'file:///storage/emulated/0/Download/list.m3u',
      '',
    ]) {
      expect(XtreamHelper.fromM3uUrl(url), isNull, reason: url);
    }
  });
}
