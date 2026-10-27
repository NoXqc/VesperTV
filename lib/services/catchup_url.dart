import 'dart:async' show Zone;
import 'dart:math' as math;

import '../models/catchup.dart';

/// Builds a provider catch-up request without channel or playback state.
///
/// [start] and [now] are instants. Only Xtream's calendar timestamp uses
/// [serverOffset]; template date parts and all epochs use UTC. Relative source
/// templates are appended literally to [liveUrl], not resolved as sibling paths.
/// An unusable source or incomplete Xtream endpoint returns null.
String? catchupUrl({
  required CatchupKind kind,
  required String liveUrl,
  String? catchupSource,
  String? streamId,
  required DateTime start,
  required Duration span,
  required DateTime now,
  Duration? serverOffset,
  String? xtreamServer,
  String? user,
  String? pass,
  String ext = 'm3u8',
}) {
  if (span.isNegative) return null;
  if (kind == CatchupKind.xc) {
    if (ext != 'm3u8' && ext != 'ts') return null;
    final endpoint = _xcEndpoint(liveUrl, xtreamServer, user, pass, streamId);
    if (endpoint == null) return null;
    return endpoint.server.replace(pathSegments: [
      ..._serverPath(endpoint.server),
      'timeshift',
      endpoint.user,
      endpoint.pass,
      '${_minutes(span)}',
      _date(_xcLocal(start, serverOffset), 'Y-m-d:H-M'),
      '${endpoint.streamId}.$ext',
    ]).toString();
  }
  switch (kind) {
    case CatchupKind.defaultKind:
    case CatchupKind.append:
      if (catchupSource == null || catchupSource.isEmpty) return null;
      final source = _substitute(catchupSource, start, span, now);
      if (kind == CatchupKind.defaultKind && _httpUri(source) != null) {
        return source;
      }
      // A default template with another scheme is not a relative URL.
      if (kind == CatchupKind.defaultKind &&
          (Uri.tryParse(source)?.hasScheme ?? false)) {
        return null;
      }
      if (_httpUri(liveUrl) == null) return null;
      return '$liveUrl$source';
    case CatchupKind.shift:
      if (_httpUri(liveUrl) == null) return null;
      return _appendQuery(liveUrl, 'utc=${_epoch(start)}&lutc=${_epoch(now)}');
    case CatchupKind.flussonic:
    case CatchupKind.flussonicTs:
      final live = _httpUri(liveUrl);
      if (live == null) return null;
      final parts = live.pathSegments.toList();
      if (parts.isEmpty) return null;
      final filename = parts.removeLast();
      if (kind == CatchupKind.flussonicTs) {
        if (filename != 'mpegts') return null;
        parts.add('timeshift_abs-${_epoch(start)}.ts');
      } else {
        if (!const ['index.m3u8', 'mono.m3u8', 'video.m3u8']
            .contains(filename)) {
          return null;
        }
        final stem = filename == 'video.m3u8' ? 'video' : 'index';
        parts.add('$stem-${_epoch(start)}-${span.inSeconds}.m3u8');
      }
      // replace preserves the original query, including signed/encoded tokens.
      return live.replace(pathSegments: parts).toString();
    case CatchupKind.xc:
      // Handled above, including credential and extension validation.
      return null;
  }
}

/// Optional Xtream PHP fallback; uses the same minute/time rule as [catchupUrl].
String? catchupPhpUrl({
  required String liveUrl,
  String? streamId,
  required DateTime start,
  required Duration span,
  Duration? serverOffset,
  String? xtreamServer,
  String? user,
  String? pass,
}) {
  if (span.isNegative) return null;
  final endpoint = _xcEndpoint(liveUrl, xtreamServer, user, pass, streamId);
  if (endpoint == null) return null;
  return endpoint.server.replace(
    pathSegments: [
      ..._serverPath(endpoint.server),
      'streaming',
      'timeshift.php'
    ],
    queryParameters: {
      'username': endpoint.user,
      'password': endpoint.pass,
      'stream': endpoint.streamId,
      'start': _date(_xcLocal(start, serverOffset), 'Y-m-d:H-M'),
      'duration': '${_minutes(span)}',
    },
  ).toString();
}

/// Safe diagnostics: never return a host, path, query value or raw placeholder.
///
/// Only an allowlisted scheme, enum name and recognised placeholder names are
/// returned. Unrecognised names are represented by `unknown`, since a malformed
/// template may put credentials or tokens inside braces too.
String catchupUrlForLog({
  required CatchupKind kind,
  required String liveUrl,
  String? catchupSource,
}) {
  final scheme = _httpUri(liveUrl)?.scheme ?? 'unknown';
  final names = <String>{};
  for (final match in _placeholder.allMatches(catchupSource ?? '')) {
    final name = match[1]!.split(':').first;
    names.add(_placeholderNames.contains(name) ? name : 'unknown');
  }
  final ordered = names.toList()..sort();
  return 'scheme=$scheme kind=${kind.name} placeholders=${ordered.join(',')}';
}

final _placeholder = RegExp(r'\$?\{([^{}]+)\}');
const _placeholderNames = {
  'utc',
  'start',
  'utcend',
  'end',
  'lutc',
  'now',
  'timestamp',
  'duration',
  'offset',
  'Y',
  'm',
  'd',
  'H',
  'M',
  'S',
};

String _substitute(String source, DateTime start, Duration span, DateTime now) {
  final from = start.toUtc();
  final end = from.add(span);
  final current = now.toUtc();
  return source.replaceAllMapped(_placeholder, (match) {
    final body = match[1]!;
    final separator = body.indexOf(':');
    final name = separator < 0 ? body : body.substring(0, separator);
    final argument = separator < 0 ? null : body.substring(separator + 1);
    if (argument != null) {
      if (name == 'duration' || name == 'offset') {
        final divisor = int.tryParse(argument);
        if (divisor == null || divisor <= 0) return match[0]!;
        final seconds = name == 'duration'
            ? span.inSeconds
            : current.difference(from).inSeconds;
        return '${seconds ~/ divisor}';
      }
      final time = switch (name) {
        'utc' || 'start' => from,
        'end' => end,
        'now' => current,
        _ => null,
      };
      if (time != null && RegExp(r'^[YmdHMS\-:/. _]+$').hasMatch(argument)) {
        return _date(time, argument);
      }
      return match[0]!;
    }
    return switch (name) {
      'utc' || 'start' => '${_epoch(from)}',
      'utcend' || 'end' => '${_epoch(end)}',
      'lutc' || 'now' || 'timestamp' => '${_epoch(current)}',
      'duration' => '${span.inSeconds}',
      'Y' || 'm' || 'd' || 'H' || 'M' || 'S' => _date(from, name),
      _ => match[0]!,
    };
  });
}

int _epoch(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
int _minutes(Duration span) =>
    math.max(1, (span.inMicroseconds / Duration.microsecondsPerMinute).ceil());

bool _warnedMissingOffset = false;
DateTime _xcLocal(DateTime start, Duration? offset) {
  if (offset == null && !_warnedMissingOffset) {
    _warnedMissingOffset = true;
    // A once-per-process diagnostic via the caller's zone, with no URL data.
    Zone.current.print('Catchup: server offset unavailable; using UTC.');
  }
  return start.toUtc().add(offset ?? Duration.zero);
}

String _date(DateTime time, String format) {
  final parts = {
    'Y': time.year.toString().padLeft(4, '0'),
    'm': time.month.toString().padLeft(2, '0'),
    'd': time.day.toString().padLeft(2, '0'),
    'H': time.hour.toString().padLeft(2, '0'),
    'M': time.minute.toString().padLeft(2, '0'),
    'S': time.second.toString().padLeft(2, '0'),
  };
  return format.replaceAllMapped(RegExp('[YmdHMS]'), (m) => parts[m[0]]!);
}

Uri? _httpUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

String _appendQuery(String url, String query) {
  final split = url.indexOf('#');
  final head = split < 0 ? url : url.substring(0, split);
  final tail = split < 0 ? '' : url.substring(split);
  final separator = head.endsWith('?') || head.endsWith('&')
      ? ''
      : head.contains('?')
          ? '&'
          : '?';
  return '$head$separator$query$tail';
}

List<String> _serverPath(Uri server) =>
    server.pathSegments.where((p) => p.isNotEmpty).toList();

class _XcEndpoint {
  const _XcEndpoint(this.server, this.user, this.pass, this.streamId);
  final Uri server;
  final String user;
  final String pass;
  final String streamId;
}

_XcEndpoint? _xcEndpoint(String liveUrl, String? server, String? user,
    String? pass, String? streamId) {
  final live = _httpUri(liveUrl);
  var parts = live?.pathSegments.toList() ?? <String>[];
  if (parts.length == 4 && parts.first == 'live') parts = parts.sublist(1);
  final derived = parts.length == 3 &&
      RegExp(r'^\d+(?:\.(?:ts|m3u8))?$').hasMatch(parts.last);
  final resolvedServer = server == null
      ? (derived
          ? Uri(
              scheme: live!.scheme,
              host: live.host,
              port: live.hasPort ? live.port : null)
          : null)
      : _httpUri(server);
  final resolvedUser = user ?? (derived ? parts[0] : null);
  final resolvedPass = pass ?? (derived ? parts[1] : null);
  final resolvedId = streamId ??
      (derived ? parts[2].replaceFirst(RegExp(r'\.(?:ts|m3u8)$'), '') : null);
  if (resolvedServer == null ||
      resolvedUser == null ||
      resolvedUser.isEmpty ||
      resolvedPass == null ||
      resolvedPass.isEmpty ||
      resolvedId == null ||
      resolvedId.isEmpty) {
    return null;
  }
  // Credentials live only in the returned playback URL, never in diagnostics.
  return _XcEndpoint(
      Uri(
          scheme: resolvedServer.scheme,
          userInfo: resolvedServer.userInfo,
          host: resolvedServer.host,
          port: resolvedServer.hasPort ? resolvedServer.port : null,
          pathSegments: resolvedServer.pathSegments),
      resolvedUser,
      resolvedPass,
      resolvedId);
}
