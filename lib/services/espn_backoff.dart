import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown instead of a response while ESPN has told this device to slow
/// down (HTTP 429, or 403 as a block) and the wait hasn't ended. Callers'
/// ordinary failure handling applies: they keep their cached data.
class EspnBackoffException implements Exception {
  EspnBackoffException(this.until);
  final DateTime until;

  @override
  String toString() => 'ESPN asked us to slow down, paused until $until';
}

/// Politeness toward ESPN's unofficial public endpoints (owner, 2026-11-11):
/// when ESPN answers 429 Too Many Requests (or 403, how a block may look),
/// every ESPN request from this device waits instead of knocking again.
///
/// - The wait is the reply's `Retry-After` (seconds), kept between
///   [minWait] and [maxWait]; without the header it starts at [firstWait]
///   and doubles on each repeat, up to [maxWait].
/// - While waiting, [get] throws [EspnBackoffException] without touching
///   the network, so the callers show their cached scores. Nothing changes
///   while ESPN is happy: a 200 resets the repeat count.
/// - Several requests in flight when the first 429 lands count as one
///   strike (the rate limit is per IP, so one block covers every endpoint).
///
/// Only status codes trigger it: a timeout or a 5xx is the user's network
/// or ESPN having a bad day, not a request to slow down. TheSportsDB has
/// its own limiter (`SportsDbSource`).
class EspnBackoff {
  EspnBackoff({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const firstWait = Duration(seconds: 90);
  static const minWait = Duration(seconds: 30);
  static const maxWait = Duration(minutes: 15);

  final DateTime Function() _now;
  DateTime? _until;
  int _strikes = 0;

  /// True while ESPN requests are paused.
  bool get blocked {
    final until = _until;
    return until != null && _now().isBefore(until);
  }

  /// When the pause ends, or null.
  DateTime? get blockedUntil => blocked ? _until : null;

  /// 429 asks for a slower pace; 403 is how a block can be signalled.
  static bool isSlowDown(int status) => status == 429 || status == 403;

  /// GET [url] unless paused; a slow-down reply starts (or extends) the
  /// pause and is thrown as [EspnBackoffException] rather than returned.
  Future<http.Response> get(http.Client client, Uri url,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final until = _until;
    if (until != null && _now().isBefore(until)) {
      throw EspnBackoffException(until);
    }
    final response = await client.get(url).timeout(timeout);
    if (isSlowDown(response.statusCode)) {
      throw EspnBackoffException(_note(response));
    }
    if (response.statusCode == 200) _strikes = 0;
    return response;
  }

  DateTime _note(http.Response response) {
    final already = blocked;
    if (!already) _strikes++;
    final header = int.tryParse(response.headers['retry-after'] ?? '');
    final Duration wait;
    if (header != null) {
      wait =
          Duration(seconds: header.clamp(minWait.inSeconds, maxWait.inSeconds));
    } else {
      wait = Duration(
          seconds: math.min(maxWait.inSeconds,
              firstWait.inSeconds * (1 << math.min(_strikes - 1, 4))));
    }
    var until = _now().add(wait);
    final current = _until;
    if (already && current != null && current.isAfter(until)) until = current;
    _until = until;
    debugPrint('SportsService: ESPN asked us to slow down '
        '(HTTP ${response.statusCode}), pausing ESPN requests for '
        '${wait.inSeconds} s (strike $_strikes)');
    return until;
  }
}
