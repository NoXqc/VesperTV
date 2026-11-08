import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/desktop_platform.dart';

/// Leaving the app (owner, 2026-11-05).
///
/// [warm] (Back > Exit): like the remote's Home key. Playback stops, the
/// task goes to the background and Android keeps the process and engine,
/// so opening VesperTV again is instant and lands where it was (TiviMate's
/// "launches in 2 s with the remote responsive at once"). Finishing the
/// activity (`SystemNavigator.pop`, the old exit) destroyed the engine:
/// every launch was a cold start with the splash. A low-memory box can
/// still kill the background process; the next launch is then cold.
///
/// [full] (sidebar Exit VesperTV): the activity finishes, the next launch
/// starts cold.
class AppExit {
  AppExit._();

  static const _device = MethodChannel('com.nox.nox_iptv/device_type');

  /// Set by the app root: stops playback before a warm exit.
  static Future<void> Function()? beforeWarm;

  /// Set by the app root: runs when the app comes back after a warm exit
  /// (the Startup resume-last-channel choice).
  static VoidCallback? afterWarm;

  static bool _warmPending = false;

  /// True on a computer (no warm exit there). Tests run on a computer but
  /// exercise the Android path.
  @visibleForTesting
  static bool isWindows = isDesktop;

  /// Back at the app's root (the TV home's tabs column, Sports Mode, Who's
  /// watching). Android leaves at once with [warm]: reopening is instant,
  /// so the old "Exit VesperTV?" prompt only cost a press (owner,
  /// 2026-11-08). A computer has no warm exit and Back (Esc) would close
  /// the window, so there [confirm] still asks first.
  static Future<void> back(Future<bool> Function() confirm) async {
    if (!isWindows) return warm();
    if (await confirm()) await full();
  }

  static Future<void> warm() async {
    if (isWindows) return full();
    try {
      await beforeWarm?.call();
    } catch (e) {
      debugPrint('AppExit: stop before warm exit failed: $e');
    }
    try {
      final moved = await _device.invokeMethod<bool>('moveTaskToBack');
      if (moved == true) {
        _warmPending = true;
        debugPrint('AppExit: warm exit');
        return;
      }
    } catch (e) {
      debugPrint('AppExit: moveTaskToBack failed: $e');
    }
    await full();
  }

  static Future<void> full() async {
    if (isWindows) {
      await quit();
    } else {
      await SystemNavigator.pop();
    }
  }

  /// Set by the app root on a computer: stops and disposes every media_kit
  /// player (`disposeAllDesktopPlayers`) before the window closes.
  static Future<void> Function()? beforeQuit;

  static bool _quitting = false;

  /// A computer quits: the players first ([beforeQuit], at most 5 s), then
  /// the window. The window's own close button (title bar, Alt+F4, the
  /// Steam / desktop close) comes here too: DesktopWindow sets
  /// preventClose, so window_manager reports the close instead of closing.
  /// Closing with players still open crashed libmpv on Linux (see
  /// `disposeAllDesktopPlayers`).
  static Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      await beforeQuit?.call().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('AppExit: closing players failed: $e');
    }
    // destroy, not close: close would only report the close again.
    await windowManager.destroy();
  }

  @visibleForTesting
  static void resetQuit() => _quitting = false;

  /// The app is on screen again (AppLifecycleState.resumed).
  static void resumed() {
    if (!_warmPending) return;
    _warmPending = false;
    debugPrint('AppExit: back after a warm exit');
    afterWarm?.call();
  }
}
