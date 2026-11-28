import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Reads one mpv property as text ('' = mpv doesn't report it now). May
/// throw when the player is gone.
typedef MpvPropertyRead = Future<String> Function(String name);

/// What [MpvFreezeGuard] watches: one open of a live stream ([key]; a new
/// key starts over), its name for Send log ([label], never the address),
/// and media_kit's playing / buffering state.
typedef MpvFreezeTarget = ({
  String key,
  String label,
  bool playing,
  bool buffering
});

/// Android's `LiveFreezeGuard` rules for the media_kit (libmpv) players:
/// computers, iPhone, Apple TV. Driven by `DesktopLiveRecovery` (started in
/// `watch` for a live channel, stopped in `stop` / catch-up / dispose); its
/// reload is DesktopLiveRecovery's own reopen.
///
/// Polls mpv once a second while a live stream is watched. A picture stuck
/// [stuckFor] polls while it plays, after it showed video, with at least a
/// second cached (data came, it isn't a stall): Pause/Play once; still stuck
/// after another [stuckFor]: one reload, at most [maxReloads] per
/// [reloadWindow] (an automatic reopen races the provider's connection
/// limit). Never while paused, while mpv waits for data or restarts
/// (`paused-for-cache`, `core-idle`, media_kit's buffering), before the
/// first picture, for audio-only channels or a picture slower than 1 fps.
/// Also: no new picture for [starvedFor] polls with under a second cached
/// while [starvedBytes] arrived = a reload (same limit), as on Android.
///
/// **Which mpv property says "a new frame was shown"** (checked with the
/// app's own libmpv, v0.36.0-403 / FFmpeg 6.0 from the Windows build, with
/// the render API in software mode, against local live .ts streams,
/// 2026-11-28):
/// * `time-pos` (used): with a video track mpv sets the position from the
///   timestamp of the last frame handed to the video output, so it moves
///   per shown frame and stops with the picture (it followed the video, not
///   the sound, when the two were 11 s apart). Any change counts, a jump
///   back too (a server switch restarts the timestamps; mpv shows it).
/// * `estimated-frame-number` (not used, logged): mpv computes it from
///   `time-pos` x length x `container-fps` (0 / unavailable without a
///   length or a declared rate, which live .ts often lacks): nothing more
///   than `time-pos`.
/// * `frame-drop-count` / `decoder-frame-drop-count` /
///   `vo-delayed-frame-count` (logged only): drops, not shown frames. With
///   the render client not drawing, `time-pos` went on and
///   `frame-drop-count` rose 25 a second; a slow PC drops frames while the
///   picture moves. A reopen can't fix the drawing side either.
///
/// The frozen picture this catches, reproduced there: the audio track
/// went silent while video kept arriving. mpv's picture AND sound stopped
/// (`time-pos`, `audio-pts` still) with `paused-for-cache` no, `core-idle`
/// no and `demuxer-cache-duration` growing (16 s), `demuxer-cache-state`
/// `underrun` true: media_kit said playing, not buffering, so nothing else
/// ever reconnected. Pause/Play didn't help, a reopen did. A video gap or
/// a timestamp jump back / ahead went through `paused-for-cache` (buffering)
/// or a resync instead, never this.
class MpvFreezeGuard {
  MpvFreezeGuard({
    required this.target,
    required this.read,
    required this.nudge,
    required this.reload,
    DateTime Function()? clock,
    void Function(String line)? log,
    this.interval = const Duration(seconds: 1),
    this.stuckFor = 3,
    this.starvedFor = 10,
    this.starvedBytes = 2 * 1024 * 1024,
    this.maxReloads = 2,
    this.reloadWindow = const Duration(minutes: 5),
    this.reportEvery = 10,
  })  : _clock = clock ?? DateTime.now,
        _log = log ?? ((line) => debugPrint(line));

  /// The live stream to watch, null when nothing should be watched
  /// (stopped, catch-up, reconnecting, app in the background).
  final MpvFreezeTarget? Function() target;

  /// One mpv property of that player.
  final MpvPropertyRead read;

  /// Pause/Play on the player.
  final Future<void> Function() nudge;

  /// Reopen the channel (DesktopLiveRecovery's reconnect).
  final Future<void> Function() reload;

  final DateTime Function() _clock;
  final void Function(String line) _log;
  final Duration interval;

  /// Polls without a new picture before acting.
  final int stuckFor;

  /// Polls without a new picture, data arriving, before a reload.
  final int starvedFor;

  /// Bytes that must reach mpv's cache meanwhile (it isn't the network).
  final int starvedBytes;
  final int maxReloads;
  final Duration reloadWindow;

  /// Polls between two `LiveFreeze: watch` lines.
  final int reportEvery;

  Timer? _timer;
  String? _key;
  String _label = '';
  DateTime? _since;
  double? _lastPos;
  bool _hadPicture = false;
  int _stuck = 0;
  int _step = 0;
  int _starved = 0;
  int? _starvedFrom;
  bool _busy = false;
  final List<DateTime> _reloads = [];

  // Send log (per stream).
  DateTime? _lastLineAt;
  final Set<String> _noted = {};
  final Set<String> _saidThisFreeze = {};
  DateTime? _stuckSince;
  double? _audioAtStuck;
  int _polls = 0;
  int _nudges = 0;
  int _reloadsDone = 0;
  _Report? _lastReport;

  bool get running => _timer != null;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(tick()));
  }

  /// Stops polling (the channel stopped, catch-up started, the player is
  /// going away).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _restart(null, why: 'stopped');
  }

  void _restart(String? key, {required String why}) {
    if (_key != null) {
      _say(
          'LiveFreeze: stopped watching "$_label" after '
          '${_secondsSince(_since)} s ($why; $_nudges Pause/Play, '
          '$_reloadsDone reload(s))',
          force: true);
    }
    _key = key;
    _since = key == null ? null : _clock();
    _lastPos = null;
    _hadPicture = false;
    _stuck = 0;
    _step = 0;
    _starved = 0;
    _starvedFrom = null;
    _noted.clear();
    _saidThisFreeze.clear();
    _stuckSince = null;
    _audioAtStuck = null;
    _polls = 0;
    _nudges = 0;
    _reloadsDone = 0;
    _lastReport = null;
    _lastLineAt = null;
  }

  /// One Send-log line, at most one a second per stream ([force]: an
  /// action or the stream's last line, always written). False = left out.
  bool _say(String line, {bool force = false}) {
    final now = _clock();
    final last = _lastLineAt;
    if (!force && last != null && now.difference(last) < interval) {
      return false;
    }
    _lastLineAt = now;
    _log(line);
    return true;
  }

  /// A line said once per freeze (cleared when the picture moves).
  void _sayOnce(String id, String line) {
    if (_saidThisFreeze.contains(id)) return;
    if (_say(line)) _saidThisFreeze.add(id);
  }

  /// A property that read empty or failed: once per stream.
  void _note(String name, String what) {
    final id = '$name $what';
    if (_noted.contains(id)) return;
    if (_say('LiveFreeze: mpv $name $what on "$_label" '
        '(noted once per stream)')) {
      _noted.add(id);
    }
  }

  Future<String> _get(String name) async {
    String value;
    try {
      value = (await read(name)).trim();
    } catch (e) {
      _note(name, 'read failed (${e.runtimeType})');
      return '';
    }
    if (value.isEmpty) _note(name, 'empty');
    return value;
  }

  Future<double?> _num(String name) async => double.tryParse(await _get(name));

  Future<bool?> _flag(String name) async => switch (await _get(name)) {
        'yes' => true,
        'no' => false,
        _ => null,
      };

  /// `demuxer-cache-state` (a JSON map: mpv reports no sub-keys of it).
  Future<({int? fwBytes, bool? underrun, int? inputRate})> _cacheState() async {
    final text = await _get('demuxer-cache-state');
    if (text.isEmpty) return (fwBytes: null, underrun: null, inputRate: null);
    try {
      final map = jsonDecode(text);
      if (map is! Map) throw const FormatException();
      return (
        fwBytes: (map['fw-bytes'] as num?)?.toInt(),
        underrun: map['underrun'] as bool?,
        inputRate: (map['raw-input-rate'] as num?)?.toInt(),
      );
    } catch (_) {
      _note('demuxer-cache-state', 'unreadable');
      return (fwBytes: null, underrun: null, inputRate: null);
    }
  }

  /// A reload unless [maxReloads] happened within [reloadWindow].
  Future<bool> _reload(String why, String values) async {
    final now = _clock();
    _reloads.removeWhere((at) => now.difference(at) > reloadWindow);
    if (_reloads.length >= maxReloads) {
      _say(
          'LiveFreeze: $why on "$_label", $maxReloads reloads in '
          '${reloadWindow.inMinutes} min already, leaving it ($values)',
          force: true);
      return false;
    }
    _reloads.add(now);
    _reloadsDone++;
    _say(
        'LiveFreeze: $why on "$_label", reloading '
        '(reload ${_reloads.length} of $maxReloads in '
        '${reloadWindow.inMinutes} min; $values)',
        force: true);
    await reload();
    _lastPos = null;
    return true;
  }

  @visibleForTesting
  Future<void> tick() async {
    if (_busy) return;
    final t = target();
    if (t == null) {
      if (_key != null) {
        _restart(null, why: 'reconnecting, stopped or in the background');
      }
      return;
    }
    if (t.key != _key) {
      _restart(t.key, why: 'the stream was opened again');
      _label = t.label;
      _say('LiveFreeze: watching "$_label" (mpv time-pos every '
          '${interval.inMilliseconds} ms; Pause/Play after ${stuckFor}s '
          'stuck, reload after ${stuckFor * 2}s, at most $maxReloads per '
          '${reloadWindow.inMinutes} min)');
    }
    _busy = true;
    try {
      await _check(t);
    } finally {
      _busy = false;
    }
  }

  Future<void> _check(MpvFreezeTarget t) async {
    _polls++;
    final pos = await _num('time-pos');
    if (target()?.key != _key) return; // another stream during the read
    if (!t.playing) {
      _stuck = 0;
      _starved = 0;
      _stuckSince = null;
      await _maybeReport(t, pos);
      return;
    }
    final last = _lastPos;
    _lastPos = pos;
    // Nothing shown yet / reopening, or the first reading.
    if (pos == null || last == null) {
      _stuck = 0;
      _starved = 0;
      await _maybeReport(t, pos);
      return;
    }
    if (pos != last) {
      if (!_hadPicture) {
        final h = (await _num('video-params/h'))?.toInt() ?? 0;
        if (h > 0) {
          _hadPicture = true;
          _say('LiveFreeze: first picture on "$_label" after '
              '${_secondsSince(_since)} s (h=$h)');
        }
      }
      final stuckSince = _stuckSince;
      if (stuckSince != null && (_step > 0 || _saidThisFreeze.isNotEmpty)) {
        _say('LiveFreeze: picture moving again on "$_label" after '
            '${_secondsSince(stuckSince)} s stuck'
            '${_step == 1 ? ' (Pause/Play helped)' : ''}');
      }
      _stuck = 0;
      _step = 0;
      _starved = 0;
      _stuckSince = null;
      _audioAtStuck = null;
      _saidThisFreeze.clear();
      await _maybeReport(t, pos);
      return;
    }

    // No new picture since the last poll.
    if (_stuckSince == null) {
      _stuckSince = _clock().subtract(interval);
      _audioAtStuck = await _num('audio-pts');
    }
    final h = (await _num('video-params/h'))?.toInt() ?? 0;
    final cached = await _num('demuxer-cache-duration') ?? 0;
    final pausedForCache = await _flag('paused-for-cache');
    final coreIdle = await _flag('core-idle');
    String state() => 'pos=${_f(pos)} cache=${_f(cached)}s '
        'pausedForCache=${_yn(pausedForCache)} coreIdle=${_yn(coreIdle)} '
        'buffering=${_yn(t.buffering)} h=$h';

    // Stuck waiting while data keeps coming (Android's "starved" rule).
    if (_hadPicture && cached < 1) {
      final cache = await _cacheState();
      final fw = cache.fwBytes;
      if (fw != null) {
        if (_starved++ == 0) {
          _starvedFrom = fw;
          _sayOnce(
              'starved',
              'LiveFreeze: no new picture on "$_label" with under 1 s '
                  'cached, counting what arrives (${state()} '
                  'fw=${fw ~/ 1024}KB underrun=${_yn(cache.underrun)})');
        }
        final arrived = math.max(0, fw - (_starvedFrom ?? fw));
        if (_starved >= starvedFor) {
          _starved = 0;
          if (arrived >= starvedBytes && _step < 2) {
            _step = await _reload(
                    'no picture for ${starvedFor}s while '
                        '${arrived ~/ 1024} KB arrived (player stuck waiting)',
                    '${state()} underrun=${_yn(cache.underrun)}')
                ? 2
                : 3;
            return;
          }
          _say('LiveFreeze: no picture for ${starvedFor}s on "$_label", '
              '${arrived ~/ 1024} KB arrived: left to the reconnect '
              '(${state()})');
        }
      } else {
        _starved = 0;
      }
    } else {
      _starved = 0;
    }

    if (t.buffering || pausedForCache == true || coreIdle == true) {
      _stuck = 0;
      _sayOnce(
          'waiting',
          'LiveFreeze: no new picture on "$_label" while mpv waits for '
              'data or restarts: left to the reconnect (${state()})');
      await _maybeReport(t, pos);
      return;
    }
    if (!_hadPicture || h <= 0 || cached < 1) {
      _stuck = 0;
      final why = !_hadPicture
          ? 'no picture yet'
          : h <= 0
              ? 'no video track'
              : 'under 1 s cached';
      _sayOnce('gate',
          'LiveFreeze: no new picture on "$_label", not acting: $why (${state()})');
      await _maybeReport(t, pos);
      return;
    }
    final fps = await _num('estimated-vf-fps');
    if (fps != null && fps > 0 && fps < 1) {
      _stuck = 0;
      _sayOnce(
          'slow',
          'LiveFreeze: no new picture on "$_label", a ${_f(fps)} fps '
              'picture (a still image): not acting (${state()})');
      await _maybeReport(t, pos);
      return;
    }
    if (++_stuck < stuckFor) {
      await _maybeReport(t, pos);
      return;
    }
    _stuck = 0;
    final audio = await _num('audio-pts');
    final drops = await _get('frame-drop-count');
    final cache = await _cacheState();
    final before = _audioAtStuck;
    final sound = audio == null || before == null
        ? 'sound ?'
        : audio != before
            ? 'sound moved ${_f(audio - before)}s'
            : 'sound stopped too';
    final values = '${state()} fps=${fps == null ? '?' : _f(fps)} $sound '
        'drops=${drops.isEmpty ? '?' : drops} '
        'fw=${cache.fwBytes == null ? '?' : '${cache.fwBytes! ~/ 1024}KB'} '
        'underrun=${_yn(cache.underrun)}';
    if (_step == 0) {
      _step = 1;
      _nudges++;
      _say(
          'LiveFreeze: picture stuck ${_secondsSince(_stuckSince)}s on '
          '"$_label", ${_f(cached)} s cached, Pause/Play ($values)',
          force: true);
      await nudge();
    } else if (_step == 1) {
      _step = await _reload('still stuck after Pause/Play', values) ? 2 : 3;
    } else {
      // Reloaded / limit reached: nothing more until it moves.
      _sayOnce(
          'done',
          'LiveFreeze: still stuck on "$_label" after '
              '${_step == 2 ? 'the reload' : 'the reload limit'}, waiting for '
              'it to move ($values)');
    }
  }

  /// Every [reportEvery] polls: what mpv says, for Send log.
  Future<void> _maybeReport(MpvFreezeTarget t, double? pos) async {
    if (_polls % reportEvery != 0) return;
    final efn = await _num('estimated-frame-number');
    final drops = await _num('frame-drop-count');
    final decoderDrops = await _num('decoder-frame-drop-count');
    final audio = await _num('audio-pts');
    final cached = await _num('demuxer-cache-duration');
    final pausedForCache = await _flag('paused-for-cache');
    final coreIdle = await _flag('core-idle');
    final h = (await _num('video-params/h'))?.toInt();
    final fps = await _num('estimated-vf-fps');
    final now = _Report(pos, efn, drops, decoderDrops, audio);
    final was = _lastReport;
    _lastReport = now;
    String delta(double? a, double? b, {bool whole = false}) {
      if (a == null) return '?';
      if (b == null) return whole ? '${a.round()}' : _f(a);
      final d = a - b;
      return whole ? '+${d.round()}' : '${d >= 0 ? '+' : ''}${_f(d)}';
    }

    // Once every [reportEvery] polls: always written (a property noted
    // empty during these reads would take this second's line).
    final line = 'LiveFreeze: watch "$_label" pos=${delta(pos, was?.pos)}s '
        'frames=${delta(efn, was?.frames, whole: true)} '
        'drops=${delta(drops, was?.drops, whole: true)}/'
        '${delta(decoderDrops, was?.decoderDrops, whole: true)} '
        'sound=${delta(audio, was?.audio)}s '
        'cache=${cached == null ? '?' : _f(cached)}s '
        'pausedForCache=${_yn(pausedForCache)} coreIdle=${_yn(coreIdle)} '
        'playing=${_yn(t.playing)} buffering=${_yn(t.buffering)} '
        'h=${h ?? '?'} fps=${fps == null ? '?' : _f(fps)} '
        'picture=${_hadPicture ? 'yes' : 'not yet'}';
    _say(line, force: true);
  }

  String _secondsSince(DateTime? at) => at == null
      ? '?'
      : (_clock().difference(at).inMilliseconds / 1000).toStringAsFixed(1);

  static String _f(double v) => v.toStringAsFixed(1);
  static String _yn(bool? v) => v == null ? '?' : (v ? 'yes' : 'no');
}

class _Report {
  const _Report(
      this.pos, this.frames, this.drops, this.decoderDrops, this.audio);
  final double? pos;
  final double? frames;
  final double? drops;
  final double? decoderDrops;
  final double? audio;
}
