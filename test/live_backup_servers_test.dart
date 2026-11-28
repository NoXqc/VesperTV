import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/desktop_live_recovery.dart';
import 'package:nox_iptv/services/live_backup_servers.dart';

/// A live channel on the playlist's backup servers: Android's address swap
/// (shared since 2026-11-28) and the order DesktopLiveRecovery tries them
/// in on computers / iPhone / Apple TV.
void main() {
  PlaylistProfile xtream({
    String server = 'http://a.example:8080',
    List<String> backups = const ['http://b.example:8080', 'https://c.example'],
    String? lastWorking,
    String mode = 'xtream',
  }) =>
      PlaylistProfile(
        id: 'p1',
        name: 'Provider',
        mode: mode,
        xtreamServer: server,
        xtreamUsername: 'user',
        xtreamPassword: 'pass',
        sortOrder: 0,
        createdAt: DateTime(2026, 11, 28),
        backupServers: [...backups],
        lastWorkingServer: lastWorking,
      );

  Channel live(String rawId, String name, String url) => Channel(
        id: 'p1::$rawId',
        rawId: rawId,
        playlistId: 'p1',
        name: name,
        group: 'Sports',
        url: url,
      );

  group('address swap (Android and media_kit)', () {
    test('keeps the path and query, only the server changes', () {
      expect(
          LiveBackupServers.swapOrigin(
              'http://a.example:8080/live/user/pass/123.ts',
              'http://b.example:8080'),
          'http://b.example:8080/live/user/pass/123.ts');
      expect(
          LiveBackupServers.swapOrigin(
              'http://a.example:8080/live/user/pass/123.m3u8?token=x',
              ' https://c.example// '),
          'https://c.example/live/user/pass/123.m3u8?token=x');
    });

    test('origin = scheme, host and port only', () {
      expect(LiveBackupServers.originOf('http://a.example:8080/live/u/p/1.ts'),
          'http://a.example:8080');
      expect(LiveBackupServers.originOf('https://c.example/live/u/p/1.ts'),
          'https://c.example');
      expect(LiveBackupServers.originOf('not a url'), 'not a url');
    });
  });

  group('which servers, in which order', () {
    test('last worked first, then the primary, then the backups', () {
      final profile = xtream(lastWorking: 'https://c.example');
      expect(
          LiveBackupServers.candidatesFor(
              profile, 'http://zzz.example/live/user/pass/1.ts'),
          [
            'https://c.example',
            'http://a.example:8080',
            'http://b.example:8080'
          ]);
    });

    test('the server that just failed is left out', () {
      expect(
          LiveBackupServers.candidatesFor(
              xtream(), 'http://a.example:8080/live/user/pass/1.ts'),
          ['http://b.example:8080', 'https://c.example']);
      expect(
          LiveBackupServers.candidatesFor(
              xtream(lastWorking: 'http://b.example:8080'),
              'http://b.example:8080/live/user/pass/1.ts'),
          ['http://a.example:8080', 'https://c.example']);
    });

    test('a "last worked" the user removed since is ignored', () {
      expect(
          LiveBackupServers.candidatesFor(
              xtream(lastWorking: 'http://gone.example'),
              'http://a.example:8080/live/user/pass/1.ts'),
          ['http://b.example:8080', 'https://c.example']);
    });

    test('M3U playlists and unknown playlists have none', () {
      expect(
          LiveBackupServers.candidatesFor(
              xtream(mode: 'm3u'), 'http://a.example:8080/live/u/p/1.ts'),
          isEmpty);
      expect(
          LiveBackupServers.candidatesFor(
              null, 'http://a.example:8080/live/u/p/1.ts'),
          isEmpty);
      expect(
          LiveBackupServers.candidatesFor(
              xtream(backups: const []), 'http://a.example:8080/live/u/p/1.ts'),
          isEmpty);
    });

    test('one pass, fixed at the first ask, then nothing', () {
      final walk = BackupServerWalk();
      final profile = xtream();
      const failed = 'http://a.example:8080/live/user/pass/1.ts';
      expect(walk.total, 0);
      expect(walk.hasNext(profile, failed), isTrue);
      expect(walk.tried, 0, reason: 'hasNext does not use one up');
      expect(walk.next(profile, failed), 'http://b.example:8080');
      // The list doesn't change mid-pass (rememberServer edits the profile).
      profile.lastWorkingServer = 'https://c.example';
      expect(walk.next(profile, 'http://b.example:8080/live/user/pass/1.ts'),
          'https://c.example');
      expect(walk.hasNext(profile, failed), isFalse);
      expect(walk.next(profile, failed), isNull);
      expect((walk.tried, walk.total), (2, 2));
      walk.reset();
      expect(walk.next(profile, failed), 'https://c.example',
          reason: 'a new pass starts with the server that last worked');
    });
  });

  group('DesktopLiveRecovery reconnect ladder', () {
    final espn =
        live('123', 'ESPN', 'http://a.example:8080/live/user/pass/123.ts');
    final espnFhd =
        live('124', 'ESPN FHD', 'http://a.example:8080/live/user/pass/124.ts');

    /// What tries 1..[tries] open, the way DesktopLiveRecovery calls it.
    List<String> ladder(PlaylistProfile? profile, List<Channel> copies,
        {int tries = 7}) {
      final walk = BackupServerWalk();
      final left = [...copies];
      final tried = <String>{};
      Channel? playing = espn;
      String? lastServer;
      final out = <String>[];
      for (var attempt = 1; attempt <= tries; attempt++) {
        final pick = DesktopLiveRecovery.pickTarget(
          channel: espn,
          playing: playing,
          attempt: attempt,
          servers: walk,
          profile: profile,
          lastWasServer: lastServer != null,
          nextCopy: (failed) {
            tried.add(failed.url);
            for (final c in left) {
              if (tried.add(c.url)) return c;
            }
            return null;
          },
        );
        lastServer = pick.server;
        playing = pick.target;
        expect(pick.target.id, espn.id, reason: 'the channel keeps its id');
        out.add(pick.target.url);
      }
      return out;
    }

    test('same address twice, then each server, then the copies', () {
      expect(ladder(xtream(), [espnFhd]), [
        'http://a.example:8080/live/user/pass/123.ts',
        'http://a.example:8080/live/user/pass/123.ts',
        'http://b.example:8080/live/user/pass/123.ts',
        'https://c.example/live/user/pass/123.ts',
        'http://a.example:8080/live/user/pass/124.ts',
        'http://a.example:8080/live/user/pass/124.ts',
        'http://a.example:8080/live/user/pass/124.ts',
      ]);
    });

    test('servers done and no copies: back on its own address', () {
      expect(ladder(xtream(), const [], tries: 6), [
        for (var i = 0; i < 2; i++)
          'http://a.example:8080/live/user/pass/123.ts',
        'http://b.example:8080/live/user/pass/123.ts',
        'https://c.example/live/user/pass/123.ts',
        for (var i = 0; i < 2; i++)
          'http://a.example:8080/live/user/pass/123.ts',
      ]);
    });

    test('no backup servers (M3U): the old ladder, copies from try 3', () {
      expect(ladder(xtream(mode: 'm3u'), [espnFhd], tries: 4), [
        'http://a.example:8080/live/user/pass/123.ts',
        'http://a.example:8080/live/user/pass/123.ts',
        'http://a.example:8080/live/user/pass/124.ts',
        'http://a.example:8080/live/user/pass/124.ts',
      ]);
      expect(ladder(null, const [], tries: 3), [
        for (var i = 0; i < 3; i++)
          'http://a.example:8080/live/user/pass/123.ts',
      ]);
    });

    test('backup servers are 3 s apart (Android), the other waits unchanged',
        () {
      expect(
          DesktopLiveRecovery.waitFor('no video', 3,
              quick: false, server: true),
          3);
      expect(DesktopLiveRecovery.waitFor('no video', 3, quick: false), 8);
      expect(DesktopLiveRecovery.waitFor('frozen', 1, quick: true), 2);
    });

    test('Send log names a server by its place, never its address', () {
      final profile = xtream(lastWorking: 'http://b.example:8080');
      expect(DesktopLiveRecovery.serverRole(profile, 'http://a.example:8080'),
          'primary');
      expect(DesktopLiveRecovery.serverRole(profile, 'http://b.example:8080'),
          'backup 1 of 2, last worked');
      expect(DesktopLiveRecovery.serverRole(profile, 'https://c.example'),
          'backup 2 of 2');
      expect(
          DesktopLiveRecovery.serverRole(null, 'https://c.example'), 'unknown');
    });
  });
}
