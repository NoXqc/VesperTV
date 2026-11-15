import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../utils/desktop_platform.dart';

/// The Siri Remote's Menu button at VesperTV's top screen (dev-notes/apple-tv.md).
///
/// The tvOS engine turns every Menu press into Back. At an app's top screen
/// Apple TV expects Menu to leave to its Home screen (App Review checks it),
/// which only happens when the app lets the press go up to the system, a
/// choice the native side makes before Flutter sees the press
/// (`VesperMenu` in tvos/Runner/AppDelegate.swift). So Dart tells it ahead:
///
/// - [setAtRoot]: the TV home reports after each build whether Back would
///   leave the app (tabs column, nothing above it); any new route clears it
///   at once ([observer]), so a stale "true" can't drop a viewer out of a
///   page or dialog.
/// - [armExit]: Back reached a top screen anyway (Sports Mode, Who's
///   watching, or the report was late): the next Menu press within 10 s
///   leaves ([AppExit.warm]).
///
/// No-ops off Apple TV.
class AppleTvMenu {
  static const _channel = MethodChannel('vespertv/tvos');
  static bool _atRoot = false;

  static void setAtRoot(bool atRoot) {
    if (!isAppleTv || atRoot == _atRoot) return;
    _atRoot = atRoot;
    unawaited(_channel.invokeMethod<void>('setMenuExits', atRoot).catchError(
        (Object e) => debugPrint('AppleTvMenu: setMenuExits failed: $e')));
  }

  /// True when the native side armed the next Menu press.
  static Future<bool> armExit() async {
    if (!isAppleTv) return false;
    try {
      return await _channel.invokeMethod<bool>('armMenuExit') ?? false;
    } catch (e) {
      debugPrint('AppleTvMenu: armMenuExit failed: $e');
      return false;
    }
  }

  /// Clears [setAtRoot] whenever a route (page, dialog, menu) opens or the
  /// stack changes; the TV home reports again when it builds.
  static final NavigatorObserver observer = _MenuRouteObserver();
}

class _MenuRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppleTvMenu.setAtRoot(false);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      AppleTvMenu.setAtRoot(false);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppleTvMenu.setAtRoot(false);
}
