import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A TV home that can show its live guide (see [GuideKey]).
abstract interface class GuideTarget {
  /// The route the home sits on, to close everything above it.
  ModalRoute<dynamic>? get guideRoute;

  /// TV tab, focus on the playing channel in the guide.
  void openGuide();
}

/// The remote's Guide / EPG button opens the live guide from anywhere in the
/// app (owner, 2026-10-29). Standard remotes send KEYCODE_GUIDE; the
/// Formuler's EPG key is Linux KEY_PROGRAM (scan code 362) but its own key
/// layout turns it into keycode 228 (seen with an on-screen key probe), so
/// both of those count too. The TV homes
/// register themselves; the app root installs the key handler.
class GuideKey {
  GuideKey._();

  static final _targets = <GuideTarget>[];

  /// Set while a home is being opened just for the guide: it opens it as
  /// soon as it registers.
  static bool _pending = false;

  static void register(GuideTarget target) {
    _targets.add(target);
    if (_pending) {
      _pending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => target.openGuide());
    }
  }

  static void unregister(GuideTarget target) => _targets.remove(target);

  /// Opens a TV home when none is open (the Sports Mode root registers its
  /// own "Live TV" page opener).
  static VoidCallback? _opener;
  static Object? _openerOwner;

  static void registerOpener(Object owner, VoidCallback open) {
    _openerOwner = owner;
    _opener = open;
  }

  static void unregisterOpener(Object owner) {
    if (_openerOwner != owner) return;
    _openerOwner = null;
    _opener = null;
  }

  /// [navigator]: the app's; null while the splash / profile selector shows.
  static bool isGuide(KeyEvent event) =>
      event.logicalKey == LogicalKeyboardKey.guide ||
      // Android keys Flutter has no name for: 0x11 << 32 | code.
      event.physicalKey.usbHidUsage == 0x110000016a || // scan code 362
      event.logicalKey.keyId == 0x11000000e4; // Formuler keycode 228

  static bool handle(KeyEvent event, {required NavigatorState? navigator}) {
    if (event is! KeyDownEvent || !isGuide(event) || navigator == null) {
      return false;
    }
    // The newest mounted home (Sports Mode's Live TV sits above its root).
    for (final target in _targets.reversed) {
      final route = target.guideRoute;
      if (route == null || !route.isActive) continue;
      navigator.popUntil((r) => r == route);
      target.openGuide();
      return true;
    }
    final open = _opener;
    if (open == null) return false;
    navigator.popUntil((r) => r.isFirst);
    _pending = true;
    open();
    return true;
  }
}
