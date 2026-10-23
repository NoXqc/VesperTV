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
      section = preferences.effectiveStartSection;
      if (!AppPreferences.startSections.any((entry) => entry.$1 == section)) {
        section = 'tv';
      }
      if (section != 'tv') {
        if (storage.getStartSectionPending()) {
          section = 'tv';
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
      if (first && destinations.containsKey(section))
        MaterialPageRoute<void>(
            settings: RouteSettings(name: '/startup-$section'),
            builder: destinations[section]!),
    ];
  }

  void dispose() => _guardTimer?.cancel();
}
