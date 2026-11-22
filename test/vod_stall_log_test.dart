import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/vod_stall_log.dart';

/// Send log for movie / episode buffering (owner, 2026-11-17: 4K movies of
/// one IPTV server average up to 100 Mbit/s and viewers report buffering).
void main() {
  const movie = Duration(minutes: 92);
  const size = 67200000000; // 67.2 GB over 92 min = 97.4 Mbit/s

  Map<Object?, Object?> stats(int nowMs, int bytes,
          {int stalls = 0,
          int lastStallMs = 0,
          int lastStallPosMs = 0,
          int lastStallAheadMs = 0,
          int seekWaits = 0,
          int lastSeekWaitMs = 0,
          int underruns = 0,
          int dropped = 0,
          int loadErrors = 0,
          bool smallRam = true,
          int vodBufferMb = 0}) =>
      {
        'vodBufferMb': vodBufferMb,
        'heapMb': 512,
        'nowMs': nowMs,
        'bytes': bytes,
        'fileSizeBytes': size,
        'bufferedMs': 0,
        'stalls': stalls,
        'lastStallMs': lastStallMs,
        'lastStallPosMs': lastStallPosMs,
        'lastStallAheadMs': lastStallAheadMs,
        'seekWaits': seekWaits,
        'lastSeekWaitMs': lastSeekWaitMs,
        'underruns': underruns,
        'dropped': dropped,
        'loadErrors': loadErrors,
        'smallRam': smallRam,
      };

  test('file bitrate, then a freeze while the download was too slow', () {
    final t = VodStallTracker();
    // 50 Mbit/s = 6.25 MB/s = 31.25 MB per 5 s.
    const step = 31250000;
    final first = t.add(1, stats(0, 0), duration: movie);
    expect(first.single,
        'VodBuffer: file 97 Mbit/s average (67.2 GB, 1:32:00); buffer cap 64 MB (under 2.5 GB RAM)');
    var lines = <String>[];
    for (var i = 1; i <= 12; i++) {
      lines = t.add(
          1,
          stats(i * 5000, i * step,
              stalls: i == 12 ? 1 : 0,
              lastStallMs: 6200,
              lastStallPosMs: 41 * 60000 + 12000),
          duration: movie);
    }
    expect(lines, [
      'VodBuffer: freeze (#1, 6.2 s) at 41:12, 0.0 s buffered when it began; '
          'download 50 Mbit/s last 10 s, 50 last 60 s, file 97 '
          '-> download slower than the file: source or network',
    ]);
  });

  test('a freeze with video buffered points at the decoder, seek waits apart',
      () {
    final t = VodStallTracker();
    expect(
        t.add(1, stats(0, 0, smallRam: false, vodBufferMb: 256),
            duration: movie),
        [
          'VodBuffer: file 97 Mbit/s average (67.2 GB, 1:32:00); '
              'buffer cap 256 MB (movies, heap 512 MB)'
        ]);
    final fast = t.add(
        1,
        stats(5000, 75000000, // 120 Mbit/s
            stalls: 1,
            lastStallMs: 1500,
            lastStallPosMs: 600000,
            lastStallAheadMs: 9000,
            seekWaits: 1,
            lastSeekWaitMs: 2600),
        duration: movie);
    expect(fast, [
      'VodBuffer: freeze (#1, 1.5 s) at 10:00, 9.0 s buffered when it began; '
          'download 120 Mbit/s last 10 s, 120 last 60 s, file 97 '
          '-> froze with video buffered: decoder or audio, not the network',
      'VodBuffer: seek took 2.6 s to play; '
          'download 120 Mbit/s last 10 s, 120 last 60 s, file 97',
    ]);
  });

  test('a new player starts over; dropped frames and underruns are throttled',
      () {
    final t = VodStallTracker();
    t.add(1, stats(0, 0), duration: movie);
    expect(
        t.add(2, stats(5000, 0, dropped: 40, underruns: 2), duration: movie), [
      'VodBuffer: file 97 Mbit/s average (67.2 GB, 1:32:00); buffer cap 64 MB (under 2.5 GB RAM)',
      'VodBuffer: audio ran dry +2 (total 2); buffer 0.0 s',
      'VodBuffer: 40 frames dropped since the last check (decoder behind); buffer 0.0 s',
    ]);
    // 10 s later: too soon for another line of either kind.
    expect(
        t.add(2, stats(15000, 0, dropped: 90, underruns: 5), duration: movie),
        isEmpty);
    // 30 s after the first: the underruns since then in one line.
    expect(
        t.add(2, stats(35000, 0, dropped: 90, underruns: 6), duration: movie),
        ['VodBuffer: audio ran dry +4 (total 6); buffer 0.0 s']);
  });

  test('a summary every 5 minutes while playing', () {
    final t = VodStallTracker();
    var lines = <String>[];
    for (var i = 0; i < 60; i++) {
      lines = t.add(1, stats(i * 5000, i * 62500000), // 100 Mbit/s
          duration: movie,
          position: Duration(seconds: i * 5));
    }
    expect(lines, [
      'VodBuffer: at 4:55, download 100 Mbit/s last 10 s, 100 last 60 s, '
          'file 97, buffer 0.0 s, freezes 0, seek waits 0, dropped 0, '
          'audio ran dry 0, load errors 0',
    ]);
  });

  // Owner's Homatics, 2026-11-21: a 65 Mbit/s remux froze when its source
  // slowed for minutes; big files now read ahead onto storage.
  test('read-ahead: big files qualify, the log says how long it covers', () {
    final t = VodStallTracker();
    expect(t.fileMbps, isNull);
    final first = t.add(
        1, {...stats(0, 0), 'readAheadOn': true, 'readAheadMb': 0},
        duration: movie);
    expect(first.single, startsWith('VodBuffer: file 97 Mbit/s'));
    expect(t.fileMbps!, greaterThan(VodStallTracker.readAheadMbps));
    var lines = <String>[];
    for (var i = 1; i < 60; i++) {
      lines = t.add(
          1,
          {
            ...stats(i * 5000, i * 62500000),
            'readAheadOn': true,
            // 3840 MB of a 97.4 Mbit/s file = 5:31 of it.
            'readAheadMb': 3840,
            if (i >= 30) 'readAheadNote': 'HTTP 503, retry 1 in 1 s',
          },
          duration: movie,
          position: Duration(seconds: i * 5));
      if (i == 30) {
        expect(lines, ['VodBuffer: read-ahead HTTP 503, retry 1 in 1 s']);
      }
    }
    expect(lines, [
      'VodBuffer: at 4:55, download 100 Mbit/s last 10 s, 100 last 60 s, '
          'file 97, buffer 0.0 s + 5:31 read ahead, freezes 0, seek waits 0, '
          'dropped 0, audio ran dry 0, load errors 0',
    ]);
  });

  test('read-ahead over more connections says how many', () {
    final t = VodStallTracker();
    t.add(1, stats(0, 0), duration: movie);
    final lines = t.add(
        1,
        {
          ...stats(5000, 31250000,
              stalls: 1, lastStallMs: 4000, lastStallPosMs: 60000),
          'readAheadOn': true,
          'readAheadMb': 0,
          'readAheadConnections': 2,
          'readAheadNote': '45 Mbit/s, the file needs 97: adding connection 2',
        },
        duration: movie);
    expect(lines, [
      'VodBuffer: read-ahead 45 Mbit/s, the file needs 97: adding connection 2',
      'VodBuffer: freeze (#1, 4.0 s) at 1:00, 0.0 s buffered when it began + 0:00 '
          'read ahead (2 connections); download 50 Mbit/s last 10 s, 50 last 60 s, '
          'file 97 -> download slower than the file: source or network',
    ]);
  });
}
