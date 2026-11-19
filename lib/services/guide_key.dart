import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A TV home that can show its live guide (see [GuideKey]).
abstract interface class GuideTarget {
  /// The route the home sits on, to close everything above it.
  ModalRoute<dynamic>? get guideRoute;

  /// TV tab, focus on the playing channel in the guide.
  void openGuide();

  /// The launch's resume: the live guide shows the playing channel's group
  /// (Favourites when it's a favourite, else its own group) instead of the
  /// Favourites the home opens on.
  void showPlayingGroup();

  /// The launch's full-screen resume covers the home: lay it out as after
  /// opening a channel from the guide (columns folded), so Back doesn't
  /// show the tabs and groups first.
  void guideLayoutBehindPlayer();

  /// Vesper AI's "open": 'tv', 'guide', 'movies', 'series', 'home', 'hub',
  /// 'sports', 'search' (with [query]) or 'settings', through the home's own
  /// openers. False when that section is hidden.
  bool openSection(String section, {String? query});
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

  /// The next TV home to mount opens its guide (an opener pushing one).
  static void openGuideOnNextHome() => _pending = true;

  static void register(GuideTarget target) {
    _targets.add(target);
    if (_pending) {
      _pending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => target.openGuide());
    }
    if (_layoutPending) {
      _layoutPending = false;
      target.guideLayoutBehindPlayer();
    }
    if (_groupPending) {
      _groupPending = false;
      // After the frame: the home sets its tab and start group (Favourites)
      // after registering.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => target.showPlayingGroup());
    }
  }

  static bool _groupPending = false;

  /// See [GuideTarget.showPlayingGroup] (owner, 2026-11-19: the launch's
  /// resume opened Favourites, "No channels found", for a channel that
  /// isn't one). The TV home can still be mounting.
  static void showPlayingGroupOnHome() {
    if (_targets.isEmpty) {
      _groupPending = true;
      return;
    }
    _targets.last.showPlayingGroup();
  }

  static bool _layoutPending = false;

  /// See [GuideTarget.guideLayoutBehindPlayer]; the TV home can still be
  /// mounting (the player opens right after the launch's first frame).
  static void guideLayoutBehindPlayer() {
    // Back from it shows the channel's group, not the Favourites the home
    // starts on (owner's phone, +891: "No channels found").
    showPlayingGroupOnHome();
    if (_targets.isEmpty) {
      _layoutPending = true;
      return;
    }
    _targets.last.guideLayoutBehindPlayer();
  }

  static void unregister(GuideTarget target) => _targets.remove(target);

  /// The launch's "Resume last channel with the guide open": the TV home on
  /// screen puts focus on the playing channel's guide row, like Back from
  /// full screen (it stayed on the groups column, owner 2026-11-19).
  /// Nothing when another page covers the home.
  static void focusPlayingOnHome() {
    for (final target in _targets.reversed) {
      final route = target.guideRoute;
      if (route == null || !route.isCurrent) continue;
      target.showPlayingGroup();
      target.openGuide();
      return;
    }
  }

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

  /// Vesper AI: opens [section] on the newest TV home (closing what is
  /// above it). Null when no TV home is open (the Sports Mode root): the
  /// caller then opens the page itself; 'tv' / 'guide' use the opener.
  static bool? openSection(NavigatorState navigator, String section,
      {String? query}) {
    for (final target in _targets.reversed) {
      final route = target.guideRoute;
      if (route == null || !route.isActive) continue;
      navigator.popUntil((r) => r == route);
      return target.openSection(section, query: query);
    }
    final open = _opener;
    if (open != null && (section == 'tv' || section == 'guide')) {
      navigator.popUntil((r) => r.isFirst);
      open();
      return true;
    }
    return null;
  }

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
    open();
    return true;
  }
}
