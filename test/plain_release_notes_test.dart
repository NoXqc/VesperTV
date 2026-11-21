import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/check_updates_screen.dart';

void main() {
  test('release notes lose their Markdown marks', () {
    const notes = '## VesperTV 1.0.72 (beta)\r\n\r\n'
        'Android TV and **Windows** - build 928.\r\n\r\n\r\n'
        '### Sync\r\n'
        '- **Fixed:** a `bug` in [the docs](https://vespertv.app).\r\n';
    expect(
        plainReleaseNotes(notes),
        'VesperTV 1.0.72 (beta)\n\n'
        'Android TV and Windows - build 928.\n\n'
        'Sync\n'
        '• Fixed: a bug in the docs.');
  });
}
