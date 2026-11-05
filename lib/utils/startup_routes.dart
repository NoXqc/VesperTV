import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_preferences.dart';
import '../services/storage_service.dart';

/// Resolves the selected destination before the Navigator's first frame.
/// Overlay pages keep the normal TV root underneath for Back navigation.
class StartupRoutes {
  bool _generated = false;
  bool _rootClaimed = false;
  String section = 'tv';
  Timer? _guardTimer;

  /// Only the first root consumes the startup choice. Viewer/language
  /// remounts retain the existing behavior of returning to TV.
  String takeRootSection() {
    if (_rootClaimed) {
      return 'tv';
    }
    _rootClaimed = true;
    return section;
  }

  List<Route<dynamic>> generate({
    required AppPreferences preferences,
    required StorageService storage,
    required WidgetBuilder rootBuilder,
    required Map<String, WidgetBuilder> destinations,
  }) {
    final first = !_generated;
    if (first) {
      // Sports Mode owns the root itself, with no duplicate startup overlay.
      section =
          preferences.sportsMode ? 'tv' : preferences.effectiveStartSection;
      if (preferences.sportsMode && storage.getStartSectionPending()) {
        unawaited(storage.setStartSectionPending(false));
      }
      if (!AppPreferences.startSections.any((entry) => entry.$1 == section)) {
        section = preferences.fallbackStartSection;
      }
      if (section != 'tv') {
        if (storage.getStartSectionPending()) {
          // Home is the safe recovery page when TV is hidden; retrying the
          // first visible browse tab could repeat the startup crash.
          section = preferences.hideLiveTv ? 'home' : 'tv';
          unawaited(storage.setStartSectionPending(false));
        } else {
          unawaited(storage.setStartSectionPending(true));
          _guardTimer = Timer(const Duration(seconds: 15),
              () => unawaited(storage.setStartSectionPending(false)));
        }
      }
      _generated = true;
    }
    return [
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'), builder: rootBuilder),
      if (first &&
          destinations.containsKey(section) &&
          !(section == 'home' && preferences.hideLiveTv))
        MaterialPageRoute<void>(
            settings: RouteSettings(name: '/startup-$section'),
            builder: destinations[section]!),
    ];
  }

  void dispose() => _guardTimer?.cancel();
}
