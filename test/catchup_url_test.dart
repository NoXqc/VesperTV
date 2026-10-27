import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/services/catchup_url.dart';

void main() {
  final start = DateTime.parse('2026-10-27T23:45:59Z');
  final now = DateTime.parse('2026-10-28T02:45:59Z');
  const span = Duration(hours: 1);
  const live = 'https://provider.example:8443/alice/secret/42.ts';

  String? build(CatchupKind kind,
          {String liveUrl = live,
          String? source,
          DateTime? at,
          Duration length = span,
          Duration? offset = Duration.zero,
          String ext = 'm3u8'}) =>
      catchupUrl(
          kind: kind,
          liveUrl: liveUrl,
          catchupSource: source,
          start: at ?? start,
          span: length,
          now: now,
          serverOffset: offset,
          ext: ext);

  test('missing server offset warns once, without credentials or URL', () {
    final messages = <String>[];
    runZoned(() {
      for (var i = 0; i < 2; i++) {
        expect(build(CatchupKind.xc, offset: null),
            'https://provider.example:8443/timeshift/alice/secret/60/2026-10-27:23-45/42.m3u8');
      }
    },
        zoneSpecification:
            ZoneSpecification(print: (_, __, ___, line) => messages.add(line)));
    expect(messages, ['Catchup: server offset unavailable; using UTC.']);
  });

  group('one golden URL per kind', () {
    test(
        'xc',
        () => expect(build(CatchupKind.xc),
            'https://provider.example:8443/timeshift/alice/secret/60/2026-10-27:23-45/42.m3u8'));
    test(
        'defaultKind absolute source',
        () => expect(
            build(CatchupKind.defaultKind,
                source:
                    'https://replay.example/play?from={utc}&to={utcend}&duration={duration}'),
            'https://replay.example/play?from=1793144759&to=1793148359&duration=3600'));
    test(
        'append',
        () => expect(
            build(CatchupKind.append,
                source: r'?start=${start}&end=${end}&now=${now}'),
            '$live?start=1793144759&end=1793148359&now=1793155559'));
    test(
        'shift',
        () => expect(
            build(CatchupKind.shift), '$live?utc=1793144759&lutc=1793155559'));
    test(
        'flussonic HLS',
        () => expect(
            build(CatchupKind.flussonic,
                liveUrl:
                    'http://provider.example/name/index.m3u8?token=a%2Bb%2F%3D'),
            'http://provider.example/name/index-1793144759-3600.m3u8?token=a%2Bb%2F%3D'));
    test(
        'flussonic TS',
        () => expect(
            build(CatchupKind.flussonicTs,
                liveUrl:
                    'http://provider.example/name/mpegts?token=a%2Bb%2F%3D'),
            'http://provider.example/name/timeshift_abs-1793144759.ts?token=a%2Bb%2F%3D'));
  });

  for (final ext in ['m3u8', 'ts']) {
    for (final entry in <String, Duration?>{
      '2026-10-28:01-45': const Duration(hours: 2),
      '2026-10-27:18-45': const Duration(hours: -5),
      '2026-10-27:23-45': null,
    }.entries) {
      test('xc .$ext offset ${entry.value} floors start to the minute', () {
        expect(build(CatchupKind.xc, offset: entry.value, ext: ext),
            'https://provider.example:8443/timeshift/alice/secret/60/${entry.key}/42.$ext');
      });
    }
  }

  test('xc uses explicit endpoint and credentials without parsing live URL',
      () {
    expect(
        catchupUrl(
            kind: CatchupKind.xc,
            liveUrl: 'not an Xtream URL',
            xtreamServer: 'https://provider.example/panel/',
            user: 'test-user',
            pass: 'test-pass',
            streamId: '123',
            start: start,
            span: span,
            now: now,
            serverOffset: Duration.zero),
        'https://provider.example/panel/timeshift/test-user/test-pass/60/2026-10-27:23-45/123.m3u8');
  });
  test('xc derives bare id, m3u8 and live-prefixed endpoints', () {
    for (final path in [
      'alice/secret/42',
      'alice/secret/42.m3u8',
      'live/alice/secret/42.ts'
    ]) {
      expect(
          build(CatchupKind.xc,
              liveUrl: 'http://provider.example/$path?token=ignored'),
          'http://provider.example/timeshift/alice/secret/60/2026-10-27:23-45/42.m3u8');
    }
  });
  test('xc escapes explicit credentials as individual path segments', () {
    final url = catchupUrl(
        kind: CatchupKind.xc,
        liveUrl: '',
        xtreamServer: 'https://provider.example',
        user: 'user/name@example',
        pass: 'pass ?#/%',
        streamId: '42',
        start: start,
        span: span,
        now: now,
        serverOffset: Duration.zero)!;
    final uri = Uri.parse(url);
    expect(uri.pathSegments, [
      'timeshift',
      'user/name@example',
      'pass ?#/%',
      '60',
      '2026-10-27:23-45',
      '42.m3u8'
    ]);
    expect(uri.hasQuery, isFalse);
    expect(uri.hasFragment, isFalse);
  });
  test('xc span 59.5 minutes rounds up to 60', () {
    expect(build(CatchupKind.xc, length: const Duration(seconds: 3570)),
        contains('/60/2026-10-27:23-45/'));
  });
  test('xc span minimum one minute and fractional minute rounds up', () {
    expect(build(CatchupKind.xc, length: Duration.zero), contains('/1/2026-'));
    expect(
        build(CatchupKind.xc,
            length: const Duration(minutes: 1, microseconds: 1)),
        contains('/2/2026-'));
  });
  test('fixed offsets do not acquire DST or machine-local adjustments', () {
    for (final day in ['2026-03-29', '2026-10-25']) {
      expect(
          build(CatchupKind.xc,
              at: DateTime.parse('${day}T01:30:00Z'),
              offset: const Duration(hours: 2)),
          contains('/$day:03-30/'));
    }
  });
  test('xc input with explicit zone is converted to UTC before server offset',
      () {
    expect(
        build(CatchupKind.xc,
            at: DateTime.parse('2026-10-28T01:45:59+02:00'),
            offset: const Duration(hours: -5)),
        contains('/2026-10-27:18-45/'));
  });
  test('xc rejects unsupported extension or incomplete endpoint', () {
    expect(build(CatchupKind.xc, ext: 'mp4'), isNull);
    expect(build(CatchupKind.xc, liveUrl: 'https://provider.example/channel'),
        isNull);
    expect(
        catchupUrl(
            kind: CatchupKind.xc,
            liveUrl: '',
            xtreamServer: 'https://provider.example',
            user: 'user',
            pass: 'pass',
            start: start,
            span: span,
            now: now),
        isNull);
    expect(
        catchupUrl(
            kind: CatchupKind.xc,
            liveUrl: live,
            user: '',
            start: start,
            span: span,
            now: now),
        isNull);
  });

  for (final entry in <String, Duration?>{
    '2026-10-28:01-45': const Duration(hours: 2),
    '2026-10-27:18-45': const Duration(hours: -5),
    '2026-10-27:23-45': null,
  }.entries) {
    test('catchupPhpUrl with offset ${entry.value}', () {
      expect(
          catchupPhpUrl(
              liveUrl: live,
              start: start,
              span: const Duration(seconds: 3570),
              serverOffset: entry.value),
          'https://provider.example:8443/streaming/timeshift.php?username=alice&password=secret&stream=42&start=${entry.key.replaceAll(':', '%3A')}&duration=60');
    });
  }
  test('catchupPhpUrl explicit credentials encoded and missing stream rejected',
      () {
    final url = catchupPhpUrl(
        liveUrl: '',
        xtreamServer: 'http://provider.example/',
        user: 'user &+',
        pass: 'pass#?',
        streamId: '9',
        start: start,
        span: Duration.zero,
        serverOffset: Duration.zero)!;
    expect(Uri.parse(url).queryParameters, {
      'username': 'user &+',
      'password': 'pass#?',
      'stream': '9',
      'start': '2026-10-27:23-45',
      'duration': '1'
    });
    expect(catchupPhpUrl(liveUrl: '', start: start, span: span), isNull);
  });

  test('absolute default template does not need a parseable live URL', () {
    expect(
        build(CatchupKind.defaultKind,
            liveUrl: '', source: 'https://replay.example?start={utc}'),
        'https://replay.example?start=1793144759');
  });
  test('relative default template is appended rather than URI-resolved', () {
    expect(
        build(CatchupKind.defaultKind,
            source: '?from={utc}&minutes={duration:60}'),
        '$live?from=1793144759&minutes=60');
  });
  test('append preserves existing query and literal template', () {
    expect(
        build(CatchupKind.append,
            liveUrl: '$live?token=keep%2Bme',
            source: '&start={start}&age={offset:60}'),
        '$live?token=keep%2Bme&start=1793144759&age=180');
  });
  test('shift existing query token and fragment are retained', () {
    expect(build(CatchupKind.shift, liveUrl: '$live?token=keep%2Bme#part'),
        '$live?token=keep%2Bme&utc=1793144759&lutc=1793155559#part');
  });
  for (final stem in ['mono', 'video']) {
    test('flussonic $stem HLS rewrites only the filename', () {
      expect(
          build(CatchupKind.flussonic,
              liveUrl:
                  'https://provider.example/a%20b/$stem.m3u8?token=x&sig=a%2Fb#part'),
          'https://provider.example/a%20b/${stem == 'mono' ? 'index' : 'video'}-1793144759-3600.m3u8?token=x&sig=a%2Fb#part');
    });
  }
  test('flussonic unsupported endpoints return null', () {
    expect(
        build(CatchupKind.flussonic,
            liveUrl: 'https://provider.example/other.m3u8'),
        isNull);
    expect(
        build(CatchupKind.flussonicTs,
            liveUrl: 'https://provider.example/index.m3u8'),
        isNull);
  });

  test('all epoch aliases substitute UTC seconds', () {
    expect(
        build(CatchupKind.defaultKind,
            source:
                r'?a={utc}&b=${start}&c={start}&d={utcend}&e=${end}&f={end}&g={lutc}&h=${now}&i=${timestamp}&j={now}'),
        '$live?a=1793144759&b=1793144759&c=1793144759&d=1793148359&e=1793148359&f=1793148359&g=1793155559&h=1793155559&i=1793155559&j=1793155559');
  });
  test('duration and offset divisors use integer seconds', () {
    expect(
        build(CatchupKind.defaultKind,
            length: const Duration(seconds: 3570),
            source:
                '?seconds={duration}&minutes={duration:60}&hours={offset:3600}'),
        '$live?seconds=3570&minutes=59&hours=3');
  });
  test('UTC date parts and formatted date aliases ignore server offset', () {
    expect(
        build(CatchupKind.defaultKind,
            offset: const Duration(hours: 2),
            source:
                r'?parts={Y}-{m}-{d}:{H}-{M}-{S}&utc={utc:Y-m-d:H-M}&start=${start:Y/m/d:H:M:S}&end={end:Y-m-d:H-M}&now={now:Y-m-d:H-M}'),
        '$live?parts=2026-10-27:23-45-59&utc=2026-10-27:23-45&start=2026/10/27:23:45:59&end=2026-10-28:00-45&now=2026-10-28:02-45');
  });
  test('date parts are zero-padded', () {
    expect(
        build(CatchupKind.defaultKind,
            at: DateTime.utc(2026, 1, 2, 3, 4, 5),
            source: '?start={Y}/{m}/{d}-{H}:{M}:{S}'),
        '$live?start=2026/01/02-03:04:05');
  });
  test('unknown and invalid placeholders stay exactly untouched', () {
    const source =
        r'?unknown={provider_token}&dollar=${unsupported}&zero={duration:0}&negative={offset:-1}&format={utc:invalid}';
    expect(build(CatchupKind.defaultKind, source: source), '$live$source');
  });
  test('missing template, malformed live URL and negative span return null',
      () {
    for (final kind in [CatchupKind.defaultKind, CatchupKind.append]) {
      expect(build(kind), isNull);
      expect(build(kind, source: ''), isNull);
    }
    expect(build(CatchupKind.shift, liveUrl: 'not a URL'), isNull);
    expect(
        build(CatchupKind.defaultKind, source: 'ftp://provider.example/file'),
        isNull);
    for (final kind in CatchupKind.values) {
      expect(build(kind, length: const Duration(seconds: -1)), isNull);
    }
  });

  test('catchupUrlForLog contains only scheme, kind and placeholder names', () {
    final log = catchupUrlForLog(
        kind: CatchupKind.xc,
        liveUrl:
            'https://basic-user:basic-pass@private.example/alice/secret/42.ts?token=sensitive',
        catchupSource:
            r'https://private.example/alice/secret?token=sensitive&a={utc}&d={duration:60}&unknown=${sensitive}&format={start:sensitive}');
    expect(log, 'scheme=https kind=xc placeholders=duration,start,unknown,utc');
    for (final secret in [
      'basic-user',
      'basic-pass',
      'private.example',
      'alice',
      'secret',
      'sensitive'
    ]) {
      expect(log, isNot(contains(secret)));
    }
  });
  test(
      'catchupUrlForLog omits query, userinfo and non-HTTP schemes for every kind',
      () {
    for (final kind in CatchupKind.values) {
      final log = catchupUrlForLog(
          kind: kind,
          liveUrl: 'custom-secret://private.example/token-secret',
          catchupSource: '{password-secret}');
      expect(log, 'scheme=unknown kind=${kind.name} placeholders=unknown');
      expect(log, isNot(contains('secret')));
    }
    expect(catchupUrlForLog(kind: CatchupKind.shift, liveUrl: live),
        'scheme=https kind=shift placeholders=');
  });
}
