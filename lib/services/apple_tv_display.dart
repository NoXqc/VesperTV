import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import '../utils/desktop_platform.dart';
import 'app_log.dart';
import 'storage_service.dart';

/// Reads one mpv property ('' when it has none yet).
typedef MpvPropertyReader = Future<String> Function(String name);

/// Settings > Playback > Frame rate (Apple TV): the TV follows the video's
/// frame rate, like Android's [DisplayMatch] (owner, 2026-11-23:
/// dev-notes/apple-tv-parity-plan.md, point 1). The full-screen player
/// asks once the stream says its rate; tvOS switches only when the
/// viewer's own Settings > Video and Audio > Match Content > Match Frame
/// Rate is on (`AVDisplayManager.isDisplayCriteriaMatchingEnabled`) and
/// tvOS is 17 or newer (the public `AVDisplayCriteria` initializer).
/// Native side: `VesperDisplay` in tvos/Runner/AppDelegate.swift, channel
/// `vespertv/display`.
///
/// Always asks for SDR: the picture reaches the screen as an 8-bit Flutter
/// texture that mpv has already tone-mapped, so an HDR mode would show
/// wrong colours.
///
/// The mode stays while a channel goes on in the guide's preview (Back
/// from full screen): a reset there would black out the TV for a second
/// every time. [reset] waits [resetDelay] so a new play right after
/// (Stop, then another channel) keeps the mode instead of switching
/// twice; tvOS gives the TV its own mode back when the app leaves.
class AppleTvDisplayMatch {
  AppleTvDisplayMatch._();

  static const _channel = MethodChannel('vespertv/display');

  static const resetDelay = Duration(seconds: 3);

  /// The rate last asked for (null = the TV's own mode).
  static double? _asked;
  static Timer? _pendingReset;
  static int _generation = 0;

  static bool enabled(StorageService storage) =>
      isAppleTv && storage.getMatchFrameRate();

  static bool _listening = false;
  static int? _switchStep;
  static DateTime? _switchStarted;

  /// tvOS's own mode switch (Swift `AVDisplayManagerModeSwitchStart` /
  /// `End`): a Send-log line each, and the switch is an [AppLog.step], so a
  /// crash during it is named next session (GitHub #20: the app ended
  /// around the switch on 968, nothing said whether during or after).
  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'modeSwitch') return null;
      onModeSwitch(call.arguments == 'start');
      return null;
    });
  }

  @visibleForTesting
  static void onModeSwitch(bool started) {
    if (started) {
      _switchStarted = DateTime.now();
      final rate = _asked == null ? 'its own mode' : '${_asked!} Hz';
      _switchStep = AppLog.step('DisplayMatch: the TV is switching to $rate');
      debugPrint('DisplayMatch: the TV started switching to $rate');
      return;
    }
    final step = _switchStep;
    if (step != null) AppLog.stepDone(step);
    _switchStep = null;
    final began = _switchStarted;
    _switchStarted = null;
    final took = began == null
        ? ''
        : ' after ${DateTime.now().difference(began).inMilliseconds} ms';
    debugPrint('DisplayMatch: the TV finished switching$took');
  }

  /// Called when the full-screen player starts (or takes over) [player];
  /// [isCurrent] says whether that stream is still the one playing.
  static bool _statusLogged = false;

  /// Once per run, at the first full-screen play: the Apple TV's own Match
  /// Content switch and VesperTV's, for the Send log (GitHub #20 only broke
  /// with both on).
  static Future<void> _logStatusOnce(StorageService storage) async {
    if (!isAppleTv || _statusLogged) return;
    _statusLogged = true;
    try {
      final s = await _channel.invokeMapMethod<String, Object?>('status');
      debugPrint('DisplayMatch: tvOS Match Content '
          '${s?['enabled'] == true ? 'on' : 'off'} (supported '
          '${s?['supported']}), VesperTV Match frame rate '
          '${storage.getMatchFrameRate() ? 'on' : 'off'}, 50/60 only '
          '${storage.getMatch5060Only()}');
    } catch (e) {
      debugPrint('DisplayMatch: status failed ($e)');
    }
  }

  static Future<void> start(
      StorageService storage, Player player, bool Function() isCurrent) async {
    unawaited(_logStatusOnce(storage));
    if (!enabled(storage)) return;
    _listen();
    _pendingReset?.cancel();
    _pendingReset = null;
    final generation = ++_generation;
    final native = player.platform;
    if (native is! NativePlayer) return;
    Future<String> read(String name) async {
      try {
        return (await native.getProperty(name)).trim();
      } catch (_) {
        return '';
      }
    }

    final started = DateTime.now();
    final video = await detect(read,
        () => isCurrent() && generation == _generation && enabled(storage));
    if (video == null) return;
    final wanted = refreshFor(video.fps, only5060: storage.getMatch5060Only());
    final took = DateTime.now().difference(started).inMilliseconds;
    if (wanted == null) {
      debugPrint('DisplayMatch: video ${video.width}x${video.height} '
          '${video.fps.toStringAsFixed(3)} fps after $took ms -> kept');
      return;
    }
    // GitHub #20: on 968 every movie closed the app and the log ended
    // before any DisplayMatch line. The TV switches in the seconds after the
    // answer, so the step stays named for 8 s.
    final step = AppLog.step('DisplayMatch: asked the TV for '
        '${wanted.toStringAsFixed(3)} Hz (video ${video.width}x${video.height} '
        '${video.fps.toStringAsFixed(3)} fps)');
    Timer(const Duration(seconds: 8), () => AppLog.stepDone(step));
    String? answer;
    try {
      answer = await _channel.invokeMethod<String>('match', {
        'fps': wanted,
        'width': video.width,
        'height': video.height,
      });
    } catch (e) {
      answer = 'failed ($e)';
    }
    if (answer != null && answer.startsWith('asked')) _asked = wanted;
    debugPrint('DisplayMatch: video ${video.width}x${video.height} '
        '${video.fps.toStringAsFixed(3)} fps after $took ms -> '
        '${wanted.toStringAsFixed(3)} Hz: $answer');
  }

  /// Send log, once per stream (Apple TV): the sound mpv decodes and what
  /// goes out to the TV / receiver, to tell 5.1 from a stereo downmix
  /// (dev-notes/apple-tv-parity-plan.md point 4).
  static Future<void> logAudio(Player player, bool Function() isCurrent) async {
    if (!isAppleTv) return;
    final native = player.platform;
    if (native is! NativePlayer) return;
    Future<String> read(String name) async {
      try {
        return (await native.getProperty(name)).trim();
      } catch (_) {
        return '';
      }
    }

    final started = DateTime.now();
    while (DateTime.now().difference(started) < const Duration(seconds: 20)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!isCurrent()) return;
      final out = await read('audio-out-params/channel-count');
      if (out.isEmpty) continue;
      final ao = await read('current-ao');
      final codec = await read('audio-codec-name');
      final inCh = await read('audio-params/channel-count');
      final outFormat = await read('audio-out-params/format');
      debugPrint('AppleTvAudio: ao=$ao in=${inCh}ch $codec '
          'out=${out}ch $outFormat');
      return;
    }
  }

  /// Gives the TV its own mode back after [resetDelay], unless a play
  /// starts first. [now]: at once (the setting was switched off).
  static void reset({bool now = false}) {
    if (!isAppleTv || _asked == null) return;
    _pendingReset?.cancel();
    if (now) {
      _doReset();
    } else {
      _pendingReset = Timer(resetDelay, _doReset);
    }
  }

  static void _doReset() {
    _pendingReset = null;
    if (_asked == null) return;
    _asked = null;
    ++_generation;
    unawaited(_channel.invokeMethod<void>('reset').then((_) {
      debugPrint('DisplayMatch: back to the TV\'s mode');
    }, onError: (Object _) {}));
  }

  /// The stream's size and frame rate, once mpv knows them: the declared
  /// rate (`container-fps`) when it is a standard one, else what mpv
  /// measures from the frames (`estimated-vf-fps`, live .ts rarely
  /// declares a rate). Null when the stream ends, changes or says nothing
  /// within the waits.
  @visibleForTesting
  static Future<({int width, int height, double fps})?> detect(
    MpvPropertyReader read,
    bool Function() isCurrent, {
    Duration poll = const Duration(milliseconds: 150),
    Duration openWait = const Duration(seconds: 20),
    Duration measureWait = const Duration(seconds: 4),
  }) async {
    final opened = DateTime.now();
    DateTime? pictureAt;
    while (true) {
      await Future<void>.delayed(poll);
      if (!isCurrent()) return null;
      final now = DateTime.now();
      final width = int.tryParse(await read('video-params/w')) ?? 0;
      final height = int.tryParse(await read('video-params/h')) ?? 0;
      if (width <= 0 || height <= 0) {
        if (now.difference(opened) > openWait) return null;
        continue;
      }
      pictureAt ??= now;
      final declared = double.tryParse(await read('container-fps'));
      if (declared != null && snap(declared) != null) {
        return (width: width, height: height, fps: declared);
      }
      // mpv's estimate needs a second or so of frames to settle.
      if (now.difference(pictureAt) >= const Duration(milliseconds: 1500)) {
        final measured = double.tryParse(await read('estimated-vf-fps'));
        if (measured != null && snap(measured) != null) {
          return (width: width, height: height, fps: measured);
        }
      }
      if (now.difference(pictureAt) > measureWait) return null;
    }
  }

  /// Broadcast and film rates a declared or measured rate snaps to (a
  /// measured 49.87 means 50). Same list as Android's DisplayModes.kt.
  static const standardRates = [
    23.976,
    24.0,
    25.0,
    29.97,
    30.0,
    50.0,
    59.94,
    60.0
  ];

  static double? snap(double fps) {
    if (fps <= 0 || fps.isNaN) return null;
    var best = standardRates.first;
    for (final r in standardRates) {
      if ((r - fps).abs() < (best - fps).abs()) best = r;
    }
    return (best - fps).abs() <= 1.0 ? best : null;
  }

  /// The refresh rate to ask for, Android's rule (DisplayModes.kt): 25 / 50
  /// fps -> 50 Hz and 30 / 60 -> 60 Hz (25 / 30 is usually de-interlaced
  /// 50i / 60i, and many TVs judder at 25 / 30 Hz); films keep 23.976 / 24
  /// unless "Only switch between 50 and 60 Hz" ([only5060]: null = keep
  /// the current mode).
  static double? refreshFor(double fps, {required bool only5060}) {
    final video = snap(fps);
    if (video == null) return null;
    if (video == 25.0 || video == 50.0) return 50.0;
    if (video == 29.97 || video == 59.94) return 59.94;
    if (video == 30.0 || video == 60.0) return 60.0;
    return only5060 ? null : video;
  }
}
