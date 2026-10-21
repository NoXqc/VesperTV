import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/app_log.dart';

void main() {
  final profile = PlaylistProfile(
    id: 'p1',
    name: 'Main',
    mode: 'xtream',
    xtreamServer: 'http://my-provider.tv:8080',
    xtreamUsername: 'johnny42',
    xtreamPassword: 'hunter2pass',
    backupServers: ['backup.example.net'],
    sortOrder: 0,
    createdAt: DateTime(2026),
  );

  test('redact strips urls, ips, accounts and tokens', () {
    const log = '''
Playing http://my-provider.tv:8080/live/johnny42/hunter2pass/123.ts
connect to my-provider.tv failed, trying backup.example.net
EPG https://epg.other.com/xmltv.php?username=johnny42&password=hunter2pass
peer 10.0.0.46:5555 and 192.168.1.33
user johnny42 logged in, mail me@example.com
token=abc123 Authorization: Bearer x
trakt eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefgh
ExoPlaybackException: ERROR_CODE_IO_BAD_HTTP_STATUS [HTTP 404 Not Found]
''';
    final out = AppLog.redact(log, [profile]);
    for (final leak in [
      'my-provider',
      'johnny42',
      'hunter2pass',
      'backup.example',
      'epg.other.com',
      '10.0.0.46',
      '192.168.1.33',
      'me@example.com',
      'abc123',
      'eyJhbGci',
    ]) {
      expect(out, isNot(contains(leak)), reason: leak);
    }
    // What's useful for debugging stays.
    expect(out, contains('ERROR_CODE_IO_BAD_HTTP_STATUS [HTTP 404 Not Found]'));
    expect(out, contains('http://<url>'));
  });

  test('codes look like LOG-XXXXXX without 0/O/1/I', () {
    for (var i = 0; i < 200; i++) {
      expect(AppLog.newCode(), matches(RegExp(r'^LOG-[2-9A-HJ-NP-Z]{6}$')));
    }
  });
}
