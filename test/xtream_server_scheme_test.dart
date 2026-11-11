import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/xtream.dart';

void main() {
  test('a bare host gets http:// (LOG-BP8TW5)', () {
    expect(XtreamHelper.normalizeServer('vpn.example.online'),
        'http://vpn.example.online');
    expect(
        XtreamHelper.normalizeServer(' host.tv:8080/ '), 'http://host.tv:8080');
    expect(Uri.parse('${XtreamHelper.normalizeServer('host.tv:8080')}/x').host,
        'host.tv');
  });

  test('an address with a scheme is kept', () {
    expect(XtreamHelper.normalizeServer('https://host.tv/'), 'https://host.tv');
    expect(
        XtreamHelper.normalizeServer('HTTP://host.tv:80'), 'HTTP://host.tv:80');
    expect(XtreamHelper.normalizeServer(''), '');
  });

  test('the EPG link gets the scheme too', () {
    expect(
        XtreamHelper.buildEpgUrl(
            server: 'host.tv', username: 'u', password: 'p'),
        'http://host.tv/xmltv.php?username=u&password=p');
  });
}
