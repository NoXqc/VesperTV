import 'dart:async';

/// With Settings > General > Startup > "Launch with profiles selector" on,
/// Back at the app's root returns to Who's watching instead of asking to
/// exit; Back there asks to exit (owner, 2026-10-29). Off = unchanged.
/// The app root (main.dart) registers how the selector is shown.
class ProfileGate {
  ProfileGate._();

  static bool Function()? _enabled;
  static Future<void> Function()? _show;

  static void register({
    required bool Function() enabled,
    required Future<void> Function() show,
  }) {
    _enabled = enabled;
    _show = show;
  }

  static void unregister() {
    _enabled = null;
    _show = null;
  }

  /// True when Back was handled by opening the selector.
  static bool backToSelector() {
    final show = _show;
    if (show == null || !(_enabled?.call() ?? false)) return false;
    unawaited(show());
    return true;
  }
}
