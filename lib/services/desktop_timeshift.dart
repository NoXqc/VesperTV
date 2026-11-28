import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../models/channel.dart';
import '../utils/desktop_platform.dart' show isAppleTv;
import 'desktop_recorder.dart' show DesktopRecorder;
import 'live_timeshift.dart';

/// Live pause & rewind on the media_kit player (Windows, Mac, Linux,
/// iPhone / iPad, Apple TV): Android's "Pause & rewind live TV"
/// (dev-notes/live-pause.md) with mpv's own demuxer cache instead of a
/// copy of the stream. Only the full-screen live player arms it (not
/// catch-up, Multiview or the guide's preview).
///
/// What mpv does with these options (measured on the app's Windows libmpv
/// 0.36 against a local live MPEG-TS and HLS, 2026-11-28):
/// - `cache=yes` + `demuxer-seekable-cache=yes`: a live stream mpv calls
///   unseekable (`seekable=no`) still seeks inside what it has cached; a
///   seek outside it is refused ("Cannot seek in this stream") and the
///   picture stays where it was.
/// - `cache-on-disk=yes` + `demuxer-cache-dir` (the app's temporary
///   folder; media_kit's default leaves the folder empty, so the cache
///   was memory only, and macOS / iOS sandboxes can't create mpv's own
///   one): packet data goes to an unlinked temporary file (invisible in
///   the folder, freed when the stream closes, also after a crash). The
///   process stayed at ~100 MiB while the file grew ~0.4 MB/s at 3 Mbit/s.
/// - With the disk cache, `demuxer-max-bytes` / `demuxer-max-back-bytes`
///   limit the packet index in memory only (~19 KB/s at 25 fps + AAC, so
///   ~70 MB an hour). `demuxer-donate-buffer=no`: the back buffer can't
///   borrow the forward limit (128 / 256 MiB), so [indexBytesFor] is what
///   is kept behind the picture.
/// - Paused, mpv keeps reading (the forward index limit is hours), so
///   Play carries on from the paused frame.
/// - The file is append-only: pruned packets don't give space back. A
///   long session grows it by the stream's bit rate, hence [budgetBytes]
///   and the reopen at live past it.
/// - mpv refuses seeks past the newest keyframe of `seekable-ranges` (HLS:
///   ~2 s before `cache-end`) and a negative absolute seek counts from the
///   end: [MpvKeptRange] clamps every target inside the range.
class DesktopTimeshift {
  DesktopTimeshift(this.mpv,
      {DateTime Function()? clock,
      @visibleForTesting Future<Directory?> Function()? dirFor,
      @visibleForTesting int Function(String path)? freeBytesOf})
      : _clock = clock ?? DateTime.now,
        _dirFor = dirFor ?? cacheDir,
        _freeBytesOf = freeBytesOf ?? freeBytes;

  final Future<Directory?> Function() _dirFor;
  final int Function(String path) _freeBytesOf;

  static final _byPlayer = Expando<DesktopTimeshift>('DesktopTimeshift');

  /// The timeshift of [player] (created on first use; follows the player
  /// from full screen to the guide's preview and back).
  static DesktopTimeshift of(Player player) =>
      _byPlayer[player] ??= DesktopTimeshift(PlayerTimeshiftMpv(player));

  /// The full-screen player closes with [player]: timers stop, nothing is
  /// sent to mpv any more (the file goes with the player).
  static void release(Player player) {
    final t = _byPlayer[player];
    if (t == null) return;
    t._stopAll();
    if (t._armed) debugPrint('Timeshift: off (player closed)');
    t._armed = false;
    _byPlayer[player] = null;
    unawaited(sweepLeftovers());
  }

  /// Not Android (its player has `Timeshift.java`) and not the web.
  static bool get supported => !kIsWeb && !Platform.isAndroid;

  final TimeshiftMpv mpv;
  final DateTime Function() _clock;

  /// Where the picture is in what mpv keeps, null while off (Android's
  /// [TimeshiftState]: the bar's tag, -N / +N, LIVE, the timeline).
  final state = ValueNotifier<TimeshiftState?>(null);

  /// While skip presses gather: how far behind live the picture will land.
  final target = ValueNotifier<Duration?>(null);

  MpvKeptRange? _range;

  /// The last read of mpv's cache.
  MpvKeptRange? get range => _range;

  bool _armed = false;
  bool get armed => _armed;

  Channel? _channel;
  int _minutes = LiveTimeshift.defaultMinutes;
  int _budget = 0;
  int _leaveLimit = 0;

  /// mpv's values before the first arm, set back by [disarm].
  Map<String, String>? _before;
  Future<Map<String, String>>? _beforeRead;
  Timer? _poll;
  Timer? _commit;
  Timer? _verify;
  bool _reading = false;
  int _reads = 0;
  int _gen = 0;
  DateTime? _restartedAt;
  DateTime? _pausedAt;
  Duration? _nudgeFrom;
  Duration _nudgeDelta = Duration.zero;
  StreamSubscription<PlayerLog>? _logs;
  bool _memoryNoted = false;
  Future<void> Function(DateTime at)? _onCatchup;
  void Function(String why)? _onRestart;

  /// A copy file mpv couldn't write (storage full): no arming for a while.
  static DateTime? _storageFailedAt;
  static const storageBackoff = Duration(minutes: 10);
  static bool _swept = false;

  /// Tests: forgets a storage failure.
  @visibleForTesting
  static void resetStorageFailure() => _storageFailedAt = null;
  static final _said = <String, DateTime>{};

  Duration get _window => Duration(minutes: _minutes);

  // ------------------------------------------------------------ arming

  /// Arms [channel]'s full-screen playback (before its stream opens, or on
  /// a stream already playing: mpv starts the file from then on). Returns
  /// whether it's on. [catchup] plays the live channel from a time (past
  /// what's kept on a catch-up channel), [restart] opens the stream again
  /// at live (the copy file outgrew [budgetBytes], or storage failed).
  Future<bool> arm(Channel channel,
      {required String why,
      required Future<void> Function(DateTime at) catchup,
      required void Function(String why) restart}) async {
    final gen = ++_gen;
    final minutes = LiveTimeshift.minutes;
    String? off;
    if (!supported) {
      off = 'not on this device';
    } else if (!channel.isLive || channel.transientPlayback) {
      off = 'not a live channel';
    } else if (minutes <= 0) {
      off = 'setting off';
    } else if (_storageFailedAt case final at?
        when _clock().difference(at) < storageBackoff) {
      off = 'storage failed ${_clock().difference(at).inMinutes} min ago';
    }
    if (off != null) {
      await disarm(off);
      _say('off:$off', 'Timeshift: off for ${channel.name} ($off)');
      return false;
    }
    final dir = await _dirFor();
    if (gen != _gen) return false;
    if (dir == null) {
      await disarm('no cache folder');
      debugPrint('Timeshift: off (no temporary folder for the copy)');
      return false;
    }
    final free = _freeBytesOf(dir.path);
    final budget =
        budgetBytes(free: free, kind: deviceKind, windows: Platform.isWindows);
    if (budget == null) {
      await disarm('storage');
      debugPrint('Timeshift: off for ${channel.name} (only ${_size(free)} '
          'free on the cache disk)');
      return false;
    }
    // mpv's own values, read once per player before anything is set (two
    // quick zaps must not read each other's): what [disarm] puts back.
    final fresh = _beforeRead == null;
    try {
      final keys = [
        ...optionsFor(minutes: minutes, dir: dir.path).keys,
        'demuxer-max-bytes',
      ];
      _before = await (_beforeRead ??= _read(keys));
      final options = optionsFor(
          minutes: minutes,
          dir: dir.path,
          forwardNow: int.tryParse(_before!['demuxer-max-bytes'] ?? ''));
      for (final e in options.entries) {
        await mpv.set(e.key, e.value);
      }
      if (gen != _gen) return false;
      // What mpv took: an option this libmpv doesn't know is ignored.
      final missed = <String>[];
      for (final e in options.entries) {
        final got = await mpv.get(e.key);
        if (!sameValue(e.value, got)) {
          missed.add('${e.key} asked ${_show(e.key, e.value)} got '
              '${got.isEmpty ? '(none)' : _show(e.key, got)}');
        }
      }
      if (gen != _gen) return false;
      _armed = true;
      _channel = channel;
      _minutes = minutes;
      _budget = budget;
      _leaveLimit = leaveLimitBytes(deviceKind);
      _onCatchup = catchup;
      _onRestart = restart;
      _range = null;
      _reads = 0;
      _memoryNoted = false;
      _restartedAt = null;
      _pausedAt = null;
      _clearNudge();
      state.value = null;
      _startPoll();
      _watchLogs();
      debugPrint('Timeshift: on for ${channel.name} ($why), $minutes min kept'
          ' · ${desktopDeviceKindName(deviceKind)} · cache dir '
          '${shortDir(dir.path)} · free ${_size(free)} · copy limit '
          '${_size(budget)} · mpv ${[
        for (final e in options.entries) '${e.key}=${_show(e.key, e.value)}'
      ].join(' ')}'
          '${missed.isEmpty ? ' (all set)' : ' · NOT TAKEN: ${missed.join(', ')}'}'
          '${fresh ? ' · before: ${_before!.entries.map((e) => '${e.key}=${_show(e.key, e.value)}').join(' ')}' : ''}');
      return true;
    } catch (e) {
      debugPrint('Timeshift: arming failed (${e.runtimeType})');
      return false;
    }
  }

  Future<Map<String, String>> _read(List<String> keys) async =>
      {for (final k in keys) k: await mpv.get(k)};

  /// Back to mpv's values from before (the guide's preview, catch-up,
  /// Multiview). `cache-on-disk=no` in any case: the open stream stops
  /// writing its file at once (measured), its packets go to memory again,
  /// and the file is freed when the stream closes.
  Future<void> disarm(String why) async {
    if (!_armed) return;
    _armed = false;
    _gen++;
    final last = _range;
    _stopAll();
    state.value = null;
    target.value = null;
    _onCatchup = null;
    _onRestart = null;
    final restore = {
      for (final e in (_before ?? const <String, String>{}).entries)
        // An empty folder is a value; an empty number was never read.
        if (e.value.isNotEmpty || e.key == 'demuxer-cache-dir') e.key: e.value,
      'cache-on-disk': 'no',
    };
    try {
      for (final e in restore.entries) {
        await mpv.set(e.key, e.value);
      }
    } catch (e) {
      debugPrint('Timeshift: restoring mpv failed (${e.runtimeType})');
    }
    debugPrint(
        'Timeshift: off ($why) · ${last == null ? 'nothing kept yet' : 'had ${_hms(last.available)} kept, ${_hms(last.behind)} behind live, copy ${_size(last.fileBytes ?? -1)}'}'
        ' (freed when this stream closes) · mpv ${restore.entries.map((e) => '${e.key}=${_show(e.key, e.value)}').join(' ')}');
  }

  /// Full screen hands the stream to the guide's preview: behind live goes
  /// back to live first (the preview has no LIVE button), then [disarm]. A
  /// big copy file ([leaveLimitBytes]) is freed by opening the channel
  /// again at live through [reopen].
  Future<void> leave({required Future<void> Function() reopen}) async {
    if (!_armed) return;
    final r = _range;
    final big = (r?.fileBytes ?? 0) > _leaveLimit;
    if (r != null && !r.atLive && !big) {
      debugPrint('Timeshift: leaving full screen ${_hms(r.behind)} behind '
          'live, back to live first');
      try {
        await mpv.seek(r.liveSeek);
      } catch (_) {}
    }
    await disarm('leaving full screen');
    if (big) {
      debugPrint('Timeshift: copy file ${_size(r!.fileBytes!)} over '
          '${_size(_leaveLimit)}: the preview opens the channel again at '
          'live to free it');
      try {
        await reopen();
      } catch (e) {
        debugPrint('Timeshift: reopen failed (${e.runtimeType})');
      }
    }
  }

  void _stopAll() {
    _poll?.cancel();
    _poll = null;
    _commit?.cancel();
    _commit = null;
    _verify?.cancel();
    _verify = null;
    unawaited(_logs?.cancel());
    _logs = null;
    _clearNudge();
  }

  // ------------------------------------------------------- reading mpv

  void _startPoll() {
    _poll?.cancel();
    _poll =
        Timer.periodic(const Duration(seconds: 1), (_) => unawaited(readNow()));
  }

  /// Reads mpv's cache state now (the 1 s poll; tests call it directly).
  Future<void> readNow() async {
    if (!_armed || _reading) return;
    _reading = true;
    final gen = _gen;
    try {
      final raw = await mpv.get('demuxer-cache-state');
      if (!_armed || gen != _gen) return;
      final r =
          MpvKeptRange.parse(raw, position: mpv.position, window: _window);
      _range = r;
      state.value = r?.state;
      if (_reads++ % 10 == 0) {
        debugPrint(r == null
            ? 'Timeshift: nothing kept yet (mpv: '
                '${raw.length > 140 ? '${raw.substring(0, 140)}…' : raw})'
            : 'Timeshift: kept ${r.describe()} · '
                '${mpv.playing ? 'playing' : 'paused'}');
      }
      if (r != null && r.fileBytes == null && !_memoryNoted && _reads > 5) {
        _memoryNoted = true;
        debugPrint('Timeshift: mpv has no copy file (cache-on-disk not '
            'taken): kept in memory only, ${_size(indexBytesFor(_minutes))} '
            'at most');
      }
      _checkLimit(r);
    } catch (e) {
      _say('read', 'Timeshift: reading mpv failed (${e.runtimeType})');
    } finally {
      _reading = false;
    }
  }

  void _checkLimit(MpvKeptRange? r) {
    final file = r?.fileBytes;
    if (r == null || file == null) return;
    final since = _restartedAt;
    if (since != null &&
        _clock().difference(since) < const Duration(seconds: 30)) {
      return;
    }
    final action = limitAction(
        fileBytes: file,
        budget: _budget,
        atLive: r.atLive,
        playing: mpv.playing);
    if (action == TimeshiftLimit.keep) return;
    _restartedAt = _clock();
    debugPrint('Timeshift: copy file ${_size(file)} is over its '
        '${_size(_budget)} limit (${action == TimeshiftLimit.restartAtLive ? 'at live' : 'hard limit, ${_hms(r.behind)} behind'}): '
        'the channel opens again at live');
    _onRestart?.call('copy limit');
  }

  void _watchLogs() {
    unawaited(_logs?.cancel());
    _logs = mpv.logs.listen((log) {
      if (!_armed) return;
      switch (cacheTrouble(log.prefix, log.text)) {
        case CacheTrouble.write:
          _storageFailedAt = _clock();
          debugPrint('Timeshift: mpv could not write its copy file '
              '(${log.prefix}: ${log.text.trim()}): off for '
              '${storageBackoff.inMinutes} min, the channel opens again at '
              'live');
          final restart = _onRestart;
          unawaited(disarm('storage').then((_) => restart?.call('storage')));
        case CacheTrouble.create:
          _say(
              'create',
              'Timeshift: mpv could not create its copy file '
                  '(${log.prefix}: ${log.text.trim()}): memory only');
        case null:
          if (log.text.contains('Cannot seek')) {
            _say(
                'refused',
                'Timeshift: mpv refused a seek (outside what it '
                    'keeps)');
          }
      }
    });
  }

  // ------------------------------------------------------ pause / play

  /// The viewer paused the live channel.
  void notePause() {
    if (!_armed) return;
    _pausedAt = _clock();
    final r = _range;
    debugPrint('Timeshift: pause at ${r == null ? '?' : _hms(r.behind)} '
        'behind live (kept ${r == null ? '?' : _hms(r.available)})');
  }

  /// Play after a pause: inside what's kept = carries on from the paused
  /// frame; past it (paused longer than the setting's minutes) = catch-up
  /// from the pause on a catch-up channel (Android), else the oldest kept
  /// moment. False when nothing is known yet (the caller plays as before).
  bool resume({required Channel live, DateTime? pausedAt}) {
    final r = _range;
    final at = pausedAt ?? _pausedAt;
    _pausedAt = null;
    if (!_armed || r == null) return false;
    final paused = at == null ? null : _clock().difference(at);
    final pausedFor = paused == null ? '' : 'after ${_hms(paused)} paused, ';
    switch (r.resumeAfterPause(hasCatchup: live.hasCatchup)) {
      case TimeshiftResume.play:
        debugPrint('Timeshift: play $pausedFor${_hms(r.behind)} behind '
            'live (kept ${_hms(r.available)})');
        unawaited(mpv.play());
      case TimeshiftResume.catchup:
        final from = at ?? _clock().subtract(r.behind);
        debugPrint('Timeshift: play $pausedFor'
            'past the $_minutes min kept: catch-up from ${_clockTime(from)}');
        unawaited(_onCatchup?.call(from));
      case TimeshiftResume.fromOldest:
        debugPrint('Timeshift: play $pausedFor'
            'past the $_minutes min kept: carries on from the oldest kept '
            'moment (${_hms(r.available)} behind live)');
        unawaited(_seekThenPlay(r, r.oldest, 'play after pause'));
    }
    return true;
  }

  Future<void> _seekThenPlay(MpvKeptRange r, Duration to, String why) async {
    await _seek(r, to, why);
    await mpv.play();
  }

  // ------------------------------------------------------- skip / jump

  /// A skip press: [delta] back (negative) or ahead. Presses gather for
  /// 700 ms ([target] shows where they land), then one jump, like
  /// Android's `PlaybackService.timeshiftNudge`. On a catch-up channel the
  /// target can go past what's kept (catch-up then plays it).
  void nudge(Duration delta, {required Channel live}) {
    final s = state.value;
    if (!_armed || s == null) return;
    final from = _nudgeFrom ??= s.behind;
    _nudgeDelta += delta;
    final most = live.hasCatchup && live.catchupDays > 0
        ? Duration(days: live.catchupDays)
        : s.available;
    var t = from - _nudgeDelta;
    if (t > most) t = most;
    if (t < Duration.zero) t = Duration.zero;
    _nudgeDelta = from - t;
    target.value = t;
    _say(
        'nudge',
        'Timeshift: skip ${delta.isNegative ? '' : '+'}'
            '${delta.inSeconds} s -> lands ${_hms(t)} behind live (from ${_hms(from)})');
    _commit?.cancel();
    _commit = Timer(const Duration(milliseconds: 700), () {
      final t = target.value;
      _clearNudge();
      if (t != null) unawaited(goTo(t, live: live, why: 'skip'));
    });
  }

  void _clearNudge() {
    _commit?.cancel();
    _commit = null;
    _nudgeFrom = null;
    _nudgeDelta = Duration.zero;
  }

  /// The picture to [behindLive] behind live: inside what's kept, else
  /// catch-up on a catch-up channel, else the oldest kept moment.
  Future<void> goTo(Duration behindLive,
      {required Channel live, required String why}) async {
    _clearNudge();
    final r = _range;
    if (!_armed || r == null) {
      target.value = null;
      debugPrint('Timeshift: $why ignored (nothing kept yet)');
      return;
    }
    final landing = r.landing(behindLive, hasCatchup: live.hasCatchup);
    switch (landing.kind) {
      case TimeshiftLandingKind.catchup:
        target.value = null;
        final at = _clock().subtract(behindLive);
        debugPrint('Timeshift: $why: ${_hms(behindLive)} back is past what '
            'is kept (${_hms(r.available)}): catch-up from ${_clockTime(at)}');
        await _onCatchup?.call(at);
      case TimeshiftLandingKind.live:
      case TimeshiftLandingKind.inRange:
      case TimeshiftLandingKind.oldest:
        await _seek(
            r,
            landing.seekTo,
            '$why${landing.kind == TimeshiftLandingKind.oldest ? ' (past what is kept: the oldest kept moment)' : landing.kind == TimeshiftLandingKind.live ? ' (live)' : ''}');
    }
  }

  /// LIVE: the newest moment kept, playing.
  Future<void> toLive({required String why}) async {
    final live = _channel;
    if (!_armed || live == null) return;
    target.value = null;
    await goTo(Duration.zero, live: live, why: why);
    if (_armed && !mpv.playing) await mpv.play();
  }

  Future<void> _seek(MpvKeptRange r, Duration to, String why) async {
    target.value = null;
    final playing = mpv.playing;
    final started = _clock();
    try {
      await mpv.seek(to);
    } catch (e) {
      debugPrint('Timeshift: $why: seek failed (${e.runtimeType})');
      return;
    }
    debugPrint('Timeshift: $why: ${_hms(r.behind)} -> '
        '${_hms(r.newest - to)} behind live (seek ${_sec(to)} s, kept '
        '${_sec(r.oldest)}-${_sec(r.liveSeek)} s)');
    _verify?.cancel();
    _verify = Timer(const Duration(milliseconds: 900), () {
      if (!_armed) return;
      final ran = playing ? _clock().difference(started) : Duration.zero;
      final expected = to + ran;
      final got = mpv.position;
      final off = got - expected;
      if (off.abs() > const Duration(seconds: 2)) {
        debugPrint('Timeshift: seek landed elsewhere: asked ${_sec(to)} s, '
            'got ${_sec(got)} s (${off.isNegative ? '' : '+'}'
            '${(off.inMilliseconds / 1000).toStringAsFixed(1)} s)');
      }
      unawaited(readNow());
    });
  }

  // -------------------------------------------------------------- disk

  /// The app's temporary folder + `vesper_timeshift` (the macOS / iOS /
  /// tvOS sandboxes allow it; mpv's own default folder failed there).
  /// The first call of the process deletes what a killed app left.
  static Future<Directory?> cacheDir() async {
    Directory base;
    try {
      base = await getTemporaryDirectory();
    } catch (_) {
      base = Directory.systemTemp;
    }
    final dir = Directory('${base.path}${Platform.pathSeparator}'
        'vesper_timeshift');
    try {
      await dir.create(recursive: true);
    } catch (_) {
      return null;
    }
    if (!_swept) {
      _swept = true;
      await _sweep(dir);
    }
    return dir;
  }

  /// Deletes copy files left in the folder (mpv unlinks its file at once,
  /// so normally there are none; an open one can't be deleted on Windows).
  static Future<void> sweepLeftovers() async {
    try {
      final base = await getTemporaryDirectory();
      await _sweep(Directory('${base.path}${Platform.pathSeparator}'
          'vesper_timeshift'));
    } catch (_) {}
  }

  static Future<void> _sweep(Directory dir) async {
    var n = 0, bytes = 0;
    try {
      if (!await dir.exists()) return;
      await for (final f in dir.list()) {
        if (f is! File) continue;
        try {
          final size = await f.length();
          await f.delete();
          n++;
          bytes += size;
        } catch (_) {}
      }
    } catch (_) {}
    if (n > 0) {
      debugPrint(
          'Timeshift: deleted $n leftover copy file(s), ${_size(bytes)}');
    }
  }

  /// Free bytes on the disk holding [path], -1 when unknown. Windows:
  /// GetDiskFreeSpaceExW; macOS / Linux / iOS / tvOS: statvfs.
  static int freeBytes(String path) {
    if (Platform.isWindows) return DesktopRecorder.diskSpace(path).$1;
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isIOS)) return -1;
    try {
      final statvfs = DynamicLibrary.process().lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Uint8>),
          int Function(Pointer<Utf8>, Pointer<Uint8>)>('statvfs');
      final p = path.toNativeUtf8(allocator: calloc);
      final buf = calloc<Uint8>(512);
      try {
        if (statvfs(p, buf) != 0) return -1;
        final data = buf.asTypedList(512).buffer.asByteData();
        // Both: f_bsize, f_frsize (unsigned long) first. Darwin's block
        // counts are 32-bit (f_bavail at 24), 64-bit Linux's 64-bit (at 32).
        final frsize = data.getUint64(8, Endian.host);
        final avail = Platform.isLinux
            ? data.getUint64(32, Endian.host)
            : data.getUint32(24, Endian.host);
        final free = frsize * avail;
        // Garbage (a wrong layout) reads as unknown.
        return frsize > 0 && frsize <= (1 << 24) && free < (1 << 50)
            ? free
            : -1;
      } finally {
        calloc.free(p);
        calloc.free(buf);
      }
    } catch (_) {
      return -1;
    }
  }

  // ----------------------------------------------------------- helpers

  /// One line per [key] a second at most (held keys, repeated mpv lines).
  static void _say(String key, String line) {
    final now = DateTime.now();
    final last = _said[key];
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _said[key] = now;
    debugPrint(line);
  }

  static String _show(String key, String value) =>
      key == 'demuxer-cache-dir' && value.isNotEmpty ? shortDir(value) : value;
}

// ------------------------------------------------------------ pure parts

/// What a device gets ([budgetBytes], [leaveLimitBytes]).
enum DesktopDeviceKind { computer, phone, appleTv }

DesktopDeviceKind get deviceKind => isAppleTv
    ? DesktopDeviceKind.appleTv
    : Platform.isIOS
        ? DesktopDeviceKind.phone
        : DesktopDeviceKind.computer;

String desktopDeviceKindName(DesktopDeviceKind k) => switch (k) {
      DesktopDeviceKind.computer => 'computer',
      DesktopDeviceKind.phone => 'iPhone / iPad',
      DesktopDeviceKind.appleTv => 'Apple TV',
    };

const _gib = 1024 * 1024 * 1024;
const _mib = 1024 * 1024;

/// The mpv options for [minutes] kept with the copy file in [dir]. A
/// forward limit ([forwardNow], `demuxer-max-bytes`: the index ahead of the
/// picture with the disk cache) under [indexBytesFor] is raised to it: an
/// iPhone's 32 MiB would stop reading a paused channel after ~25 min.
Map<String, String> optionsFor(
    {required int minutes, required String dir, int? forwardNow}) {
  final index = indexBytesFor(minutes);
  return {
    'cache': 'yes',
    'demuxer-seekable-cache': 'yes',
    'cache-on-disk': 'yes',
    'demuxer-cache-dir': dir,
    'demuxer-donate-buffer': 'no',
    'demuxer-max-back-bytes': '$index',
    if (forwardNow != null && forwardNow < index) 'demuxer-max-bytes': '$index',
  };
}

/// The packet index kept behind the picture (memory; the data is on
/// disk): 2 MiB a minute, ~1.7x the ~70 MB an hour measured at 25 fps +
/// AAC, room for 50/60 fps and several audio tracks. At least 16 MiB.
int indexBytesFor(int minutes) => math.max(16 * _mib, minutes * 2 * _mib);

/// How big the copy file may grow before the channel opens again at live
/// (null = not enough free space to arm). Apple TV 6 GiB (32 GB models),
/// iPhone 3 GiB, computers 16 GiB; never more than the free space minus a
/// reserve (4 GiB computers, 2 GiB others) when it is known.
int? budgetBytes(
    {required int free,
    required DesktopDeviceKind kind,
    required bool windows}) {
  final (most, reserve) = switch (kind) {
    DesktopDeviceKind.appleTv => (6 * _gib, 2 * _gib),
    DesktopDeviceKind.phone => (3 * _gib, 2 * _gib),
    DesktopDeviceKind.computer => (16 * _gib, 4 * _gib),
  };
  if (free < 0) return most;
  final room = free - reserve;
  // Only Windows' free space is proven; elsewhere a low reading only
  // shrinks the limit (to 1 GiB), never turns it off.
  if (room < _gib) return windows ? null : _gib;
  return math.min(most, room);
}

/// A copy file bigger than this is freed when full screen hands the
/// stream to the guide's preview (by opening it again at live).
int leaveLimitBytes(DesktopDeviceKind kind) =>
    kind == DesktopDeviceKind.computer ? 4 * _gib : _gib;

enum TimeshiftLimit { keep, restartAtLive, restartNow }

/// Past [budget]: open again at live when the picture is at live and
/// playing (a short reload); a quarter more = now, wherever it is.
TimeshiftLimit limitAction(
    {required int fileBytes,
    required int budget,
    required bool atLive,
    required bool playing}) {
  if (fileBytes <= budget) return TimeshiftLimit.keep;
  if (fileBytes > budget + budget ~/ 4) return TimeshiftLimit.restartNow;
  return atLive && playing ? TimeshiftLimit.restartAtLive : TimeshiftLimit.keep;
}

enum CacheTrouble { write, create }

/// mpv's words for a copy file it can't write (storage full) or create.
CacheTrouble? cacheTrouble(String prefix, String text) {
  final t = text.toLowerCase();
  if (prefix.startsWith('ffmpeg') || !t.contains('cache')) return null;
  if (t.contains('failed to write') || t.contains('write error')) {
    return CacheTrouble.write;
  }
  if (t.contains('failed to create') || t.contains('no cache data')) {
    return CacheTrouble.create;
  }
  return null;
}

/// mpv prints numbers its own way ("yes" / "no", bytes as integers).
bool sameValue(String asked, String got) =>
    asked.trim() == got.trim() ||
    (double.tryParse(asked) != null &&
        double.tryParse(asked) == double.tryParse(got));

/// `<temp>/vesper_timeshift`: the folder without the user's home.
String shortDir(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
  final tail = parts.length <= 2 ? parts : parts.skip(parts.length - 2);
  return '…/${tail.join('/')}';
}

enum TimeshiftLandingKind { live, inRange, oldest, catchup }

enum TimeshiftResume { play, catchup, fromOldest }

/// What mpv keeps of the live stream around the picture, in mpv's stream
/// time (`time-pos`, seconds from the open), read from
/// `demuxer-cache-state`.
@immutable
class MpvKeptRange {
  const MpvKeptRange({
    required this.position,
    required this.start,
    required this.seekEnd,
    required this.newest,
    required this.window,
    this.fileBytes,
    this.indexBytes = 0,
    this.forwardBytes = 0,
  });

  /// [json] = `demuxer-cache-state` as mpv prints it, null when it holds
  /// no seekable range yet.
  static MpvKeptRange? parse(String json,
      {required Duration position, required Duration window}) {
    Object? m;
    try {
      m = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (m is! Map) return null;
    final map = m;
    Duration? secs(Object? v) => v is num && v.isFinite
        ? Duration(microseconds: (v * 1e6).round())
        : null;
    final ranges = <(Duration, Duration)>[];
    final listed = map['seekable-ranges'];
    for (final r in listed is List ? listed : const []) {
      if (r is! Map) continue;
      final s = secs(r['start']), e = secs(r['end']);
      if (s != null && e != null && e >= s) ranges.add((s, e));
    }
    if (ranges.isEmpty) return null;
    // The range the picture is in; else the newest one.
    var pick = ranges.last;
    for (final r in ranges) {
      if (position >= r.$1 - const Duration(seconds: 1) &&
          position <= r.$2 + const Duration(seconds: 30)) {
        pick = r;
      }
    }
    final end = secs(map['cache-end']);
    int? bytes(String k) {
      final v = map[k];
      return v is num ? v.toInt() : null;
    }

    return MpvKeptRange(
      position: position,
      start: pick.$1,
      seekEnd: pick.$2,
      newest: end != null && end > pick.$2 ? end : pick.$2,
      window: window,
      fileBytes: bytes('file-cache-bytes'),
      indexBytes: bytes('total-bytes') ?? 0,
      forwardBytes: bytes('fw-bytes') ?? 0,
    );
  }

  /// The picture (`time-pos`).
  final Duration position;

  /// The oldest seek point mpv keeps (a keyframe).
  final Duration start;

  /// The newest seek point: mpv refuses seeks past it.
  final Duration seekEnd;

  /// The newest packet (`cache-end`): "now" in stream time.
  final Duration newest;

  /// The setting's minutes.
  final Duration window;

  /// The copy file (null = no file: memory only).
  final int? fileBytes;
  final int indexBytes;
  final int forwardBytes;

  /// Seeks land a little after the oldest keyframe (pruning moves it).
  static const startMargin = Duration(milliseconds: 500);

  /// ... and a little before the newest seek point.
  static const endMargin = Duration(milliseconds: 100);

  /// LIVE: the newest point mpv can seek to.
  Duration get liveSeek {
    final s = seekEnd - endMargin;
    return s < start ? start : s;
  }

  /// The oldest moment offered: what mpv keeps, at most the setting's
  /// minutes behind the newest packet.
  Duration get oldest {
    var o = start + startMargin;
    final byWindow = newest - window;
    if (byWindow > o) o = byWindow;
    return o > liveSeek ? liveSeek : o;
  }

  /// The picture is somewhere mpv keeps (a jump in the stream's times or
  /// a fresh open can leave it outside for a moment).
  bool get inSync =>
      position >= start - const Duration(seconds: 5) &&
      position <= newest + const Duration(seconds: 5);

  Duration get behind {
    if (!inSync) return Duration.zero;
    final b = newest - position;
    return b.isNegative ? Duration.zero : b;
  }

  Duration get available {
    if (!inSync) return Duration.zero;
    final a = newest - oldest;
    return a.isNegative ? Duration.zero : a;
  }

  bool get atLive => behind <= TimeshiftState.liveEdge;

  /// Android's state for the bar's widgets.
  TimeshiftState get state => TimeshiftState(
      on: true,
      behind: behind,
      available: available,
      window: window,
      memoryOnly: fileBytes == null);

  /// Where [behindLive] behind live lands (Android's `_timeshiftLand`):
  /// near live = LIVE; more than 5 s past what's kept on a catch-up
  /// channel = catch-up; past it otherwise = the oldest kept moment.
  ({TimeshiftLandingKind kind, Duration seekTo}) landing(Duration behindLive,
      {required bool hasCatchup}) {
    if (behindLive <= TimeshiftState.liveEdge) {
      return (kind: TimeshiftLandingKind.live, seekTo: liveSeek);
    }
    if (hasCatchup && behindLive > available + const Duration(seconds: 5)) {
      return (kind: TimeshiftLandingKind.catchup, seekTo: Duration.zero);
    }
    if (behindLive >= available) {
      return (kind: TimeshiftLandingKind.oldest, seekTo: clampSeek(oldest));
    }
    return (
      kind: TimeshiftLandingKind.inRange,
      seekTo: clampSeek(newest - behindLive)
    );
  }

  /// Every seek stays inside what's kept and is never negative (mpv
  /// counts a negative absolute seek from the end).
  Duration clampSeek(Duration t) {
    var s = t;
    if (s < oldest) s = oldest;
    if (s > liveSeek) s = liveSeek;
    return s.isNegative ? Duration.zero : s;
  }

  /// Play after a pause (Android's `togglePlayPause`): the paused frame is
  /// still kept = play; else catch-up (a catch-up channel) or the oldest
  /// kept moment.
  TimeshiftResume resumeAfterPause({required bool hasCatchup}) {
    if (!inSync || position >= oldest - const Duration(seconds: 1)) {
      return TimeshiftResume.play;
    }
    return hasCatchup ? TimeshiftResume.catchup : TimeshiftResume.fromOldest;
  }

  /// The 10 s Send-log line's middle part.
  String describe() => '${_hms(available)} of ${window.inMinutes} min '
      '(${_sec(start)}-${_sec(newest)} s, seek end ${_sec(seekEnd)} s), '
      'behind ${_hms(behind)}, copy ${_size(fileBytes ?? -1)}'
      '${fileBytes == null ? ' (memory only)' : ''}, index '
      '${_size(indexBytes)} (ahead ${_size(forwardBytes)})';
}

/// Live pause & rewind through mpv: the calls [DesktopTimeshift] makes
/// (a fake in tests).
abstract class TimeshiftMpv {
  Future<String> get(String name);
  Future<void> set(String name, String value);
  Future<void> seek(Duration to);
  Future<void> play();
  Duration get position;
  bool get playing;
  Stream<PlayerLog> get logs;
}

/// [TimeshiftMpv] on a media_kit [Player].
class PlayerTimeshiftMpv implements TimeshiftMpv {
  PlayerTimeshiftMpv(this.player);
  final Player player;

  NativePlayer get _native => player.platform as NativePlayer;

  @override
  Future<String> get(String name) async =>
      (await _native.getProperty(name)).trim();

  @override
  Future<void> set(String name, String value) =>
      _native.setProperty(name, value);

  @override
  Future<void> seek(Duration to) => player.seek(to);

  @override
  Future<void> play() => player.play();

  @override
  Duration get position => player.state.position;

  @override
  bool get playing => player.state.playing;

  @override
  Stream<PlayerLog> get logs => player.stream.log;
}

String _hms(Duration d) {
  final s = d.inSeconds.abs();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.isNegative ? '-' : ''}$h:${two(m)}:${two(sec)}';
}

String _sec(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(1);

String _clockTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

String _size(int bytes) {
  if (bytes < 0) return 'unknown';
  if (bytes >= _gib) return '${(bytes / _gib).toStringAsFixed(1)} GB';
  if (bytes >= _mib) return '${(bytes / _mib).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
