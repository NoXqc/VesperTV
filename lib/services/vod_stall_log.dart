import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import 'subtitle_tracks.dart';
import 'vod_buffering.dart';

/// Puts movie / episode buffering in Send log.
///
/// Viewers of one IPTV server reported buffering on its 4K movies, which
/// average up to 100 Mbit/s (owner, 2026-11-17). The native trace only
/// covers 5 minutes after a start or seek, so a freeze at minute 40 left
/// nothing. This polls the player's stats every 5 s while a movie or episode
/// plays (see [VodStallTracker] for the lines).
class VodStallLog {
  VodStallLog(this._current);

  static const _stats = MethodChannel('vespertv/stats');

  /// The playing controller when it is a movie / episode, else null.
  final VideoPlayerHdrController? Function() _current;
  final _tracker = VodStallTracker();
  Timer? _timer;
  int? _readAheadAsked;

  void start() {
    // The real OS, not defaultTargetPlatform: widget tests run as Android.
    if (kIsWeb || !Platform.isAndroid) return;
    _timer ??= Timer.periodic(VodStallTracker.every, (_) => _poll());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Big files (a 4K remux) download over up to 3 connections when one is
  /// slower than the file (ReadAhead), once per player as soon as the
  /// file's average bitrate is known. Owner's Homatics, 2026-11-21: one
  /// TorBox connection gave 41-65 Mbit/s for an 80 Mbit/s file, three gave
  /// 114. (A 4 GB ring on storage was tried first: the box read it back
  /// from flash at 6 MB/s and froze.)
  Future<void> _readAhead(int id) async {
    final mbps = _tracker.fileMbps;
    if (mbps == null || _readAheadAsked == id) return;
    _readAheadAsked = id;
    if (mbps < VodStallTracker.readAheadMbps) return;
    if (!VodBuffering.readAhead) {
      debugPrint('VodBuffer: read-ahead off (Settings)');
      return;
    }
    final r = await _stats.invokeMapMethod<Object?, Object?>(
        'setReadAhead', {'playerId': id, 'on': true, 'fileMbps': mbps});
    debugPrint(r?['on'] == true
        ? 'VodBuffer: read-ahead on, up to ${r?['windowMb']} MB in memory'
        : 'VodBuffer: read-ahead not used: ${r?['reason'] ?? '?'}');
  }

  Future<void> _poll() async {
    final c = _current();
    if (c == null || !c.value.isInitialized) return;
    final id = SubtitleTracks.playerIdOf(c);
    try {
      final m = await _stats
          .invokeMapMethod<Object?, Object?>('getStats', {'playerId': id});
      if (m == null) return;
      final v = c.value;
      for (final line in _tracker.add(id, m,
          duration: v.duration, position: v.position, playing: v.isPlaying)) {
        debugPrint(line);
      }
      await _readAhead(id);
    } on MissingPluginException {
      dispose();
    } on PlatformException {
      // Player gone between the check and the call.
    }
  }
}

/// The `VodBuffer:` lines, from successive stats of one player. Each holds
/// what tells the causes apart:
/// - the download speed before a freeze against the file's own average
///   bitrate (slower = the source or the network can't keep up);
/// - how much was buffered when it froze (none = starved; seconds of it =
///   the decoder or audio, not the network);
/// - seek waits, failed loads (retried), audio underruns, dropped frames;
/// - a summary every 5 minutes of playing.
class VodStallTracker {
  static const every = Duration(seconds: 5);

  /// Files at least this big a bitrate (average, Mbit/s) may download over
  /// several connections: 4K remuxes; a 4K WEB-DL (~15-25) keeps up on one.
  static const readAheadMbps = 40.0;

  /// The file's average bitrate once known (size over duration).
  double? get fileMbps => _fileMbps;

  int? _player;
  final _samples = <(int, int)>[]; // (nowMs, network bytes)
  int _stalls = 0;
  int _seekWaits = 0;
  int _underruns = 0;
  int _loadErrors = 0;
  int _dropped = 0;
  int _polls = 0;
  bool _headerDone = false;
  double? _fileMbps;
  int _lastUnderrunLineMs = -1 << 40;
  int _lastDropLineMs = -1 << 40;
  String? _readAheadNote;

  List<String> add(int player, Map<Object?, Object?> m,
      {required Duration duration,
      Duration position = Duration.zero,
      bool playing = true}) {
    int n(String key) => (m[key] as num?)?.toInt() ?? 0;
    final now = n('nowMs');
    final lines = <String>[];
    if (player != _player) {
      // A new player: everything it counted so far is news.
      _player = player;
      _samples.clear();
      _stalls = _seekWaits = _underruns = _loadErrors = _dropped = 0;
      _polls = 0;
      _headerDone = false;
      _fileMbps = null;
      _readAheadNote = null;
    }
    _polls++;
    _samples
      ..add((now, n('bytes')))
      ..removeWhere((s) => s.$1 < now - 70000);
    final buffered = _secs(n('bufferedMs'));
    // Read-ahead (several connections, a memory ring): how long its part plays.
    final fileMbps = _fileMbps;
    final conns = n('readAheadConnections');
    final stored = m['readAheadOn'] == true && fileMbps != null && fileMbps > 0
        ? ' + ${_clock(Duration(seconds: (n('readAheadMb') * 8.388608 / fileMbps).round()))} read ahead'
            '${conns > 1 ? ' ($conns connections)' : ''}'
        : '';
    final note = m['readAheadNote'] as String?;
    if (note != null && note != _readAheadNote) {
      lines.add('VodBuffer: read-ahead $note');
    }
    _readAheadNote = note;

    final size = n('fileSizeBytes');
    if (!_headerDone &&
        ((size > 0 && duration > Duration.zero) || _polls >= 3)) {
      _headerDone = true;
      final cap = n('vodBufferMb') > 0
          ? 'buffer cap ${n('vodBufferMb')} MB (movies, heap ${n('heapMb')} MB)'
          : m['smallRam'] == true
              ? 'buffer cap 64 MB (under 2.5 GB RAM)'
              : 'buffer cap media3 default (~140 MB)';
      if (size > 0 && duration > Duration.zero) {
        _fileMbps = size * 8 / duration.inMilliseconds / 1000;
        lines.add('VodBuffer: file ${_mbps(_fileMbps)} Mbit/s average '
            '(${(size / 1e9).toStringAsFixed(1)} GB, ${_clock(duration)}); $cap');
      } else {
        lines.add('VodBuffer: file size unknown; $cap');
      }
    }

    final r10 = _rate(now, 10), r60 = _rate(now, 60);
    final speed = 'download ${_mbps(r10)} Mbit/s last 10 s, '
        '${_mbps(r60)} last 60 s, file ${_mbps(_fileMbps)}';

    final stalls = n('stalls');
    if (stalls > _stalls) {
      final ahead = n('lastStallAheadMs');
      final file = _fileMbps;
      final why = ahead > 3000
          ? 'froze with video buffered: decoder or audio, not the network'
          : r60 != null && file != null && r60 < file * 0.95
              ? 'download slower than the file: source or network'
              : file != null
                  ? 'download kept up on average: a peak or a slow reconnect'
                  : null;
      lines.add(
          'VodBuffer: freeze ${stalls - _stalls > 1 ? '+${stalls - _stalls} ' : ''}'
          '(#$stalls, ${_secs(n('lastStallMs'))} s) at ${_clock(Duration(milliseconds: n('lastStallPosMs')))}, '
          '${_secs(ahead)} s buffered when it began$stored; $speed${why == null ? '' : ' -> $why'}');
      _stalls = stalls;
    }

    final seekWaits = n('seekWaits');
    if (seekWaits > _seekWaits) {
      final wait = n('lastSeekWaitMs');
      if (wait >= 2000) {
        lines.add('VodBuffer: seek took ${_secs(wait)} s to play; $speed');
      }
      _seekWaits = seekWaits;
    }

    final loadErrors = n('loadErrors');
    if (loadErrors > _loadErrors) {
      lines.add('VodBuffer: load error (#$loadErrors, retried) '
          '${m['lastLoadError'] ?? ''}; buffer $buffered s');
      _loadErrors = loadErrors;
    }

    final underruns = n('underruns');
    if (underruns > _underruns && now - _lastUnderrunLineMs >= 30000) {
      lines.add('VodBuffer: audio ran dry +${underruns - _underruns} '
          '(total $underruns); buffer $buffered s');
      _underruns = underruns;
      _lastUnderrunLineMs = now;
    }

    final dropped = n('dropped');
    if (dropped - _dropped > 12 && now - _lastDropLineMs >= 30000) {
      lines.add('VodBuffer: ${dropped - _dropped} frames dropped since the '
          'last check (decoder behind); buffer $buffered s');
      _lastDropLineMs = now;
    }
    _dropped = dropped;

    if (playing && _polls % 60 == 0) {
      lines.add(
          'VodBuffer: at ${_clock(position)}, $speed, buffer $buffered s$stored, '
          'freezes $stalls, seek waits $seekWaits, dropped $dropped, '
          'audio ran dry $underruns, load errors $loadErrors');
    }
    return lines;
  }

  /// Download speed over the last [seconds], in Mbit/s; null until there are
  /// two samples.
  double? _rate(int now, int seconds) {
    if (_samples.length < 2) return null;
    final last = _samples.last;
    var from = _samples.first;
    for (final s in _samples) {
      if (s.$1 > now - seconds * 1000 + 1000) break;
      from = s;
    }
    final ms = last.$1 - from.$1;
    if (ms <= 0) return null;
    return (last.$2 - from.$2) * 8 / ms / 1000;
  }

  static String _mbps(double? v) =>
      v == null ? '?' : v.toStringAsFixed(v < 10 ? 1 : 0);

  static String _secs(int ms) => (ms / 1000).toStringAsFixed(1);

  static String _clock(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}
